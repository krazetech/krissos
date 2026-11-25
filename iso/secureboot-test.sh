#!/usr/bin/env bash
# Secure Boot on, with the keys a PC ships with (Microsoft's, as enrolled by virt-firmware's
# --enroll-redhat), in QEMU with OVMF's Secure Boot build:
#  1. The live ISO without its key trusted: shim (Microsoft-signed) starts, refuses the
#     unknown systemd-boot and opens MokManager, so nothing unsigned runs.
#  2. The live ISO with KRISSOS.cer in db, as after the one-time "Enroll key from disk":
#     shim -> systemd-boot -> kernel, and the live system says Secure Boot is enabled.
#  3. An install (iso/test/autoinstall) with Secure Boot on: the installer makes the PC's
#     key and queues it for MokManager. The first start of the disk goes through
#     MokManager as a person would (Enroll MOK, Continue, Yes, password, Reboot), then
#     shim -> Limine (signed with that key) -> KrissOS's login screen, Secure Boot enabled.
# Needs qemu-system-x86, ovmf (Ubuntu's OVMF_CODE_4M.secboot.fd and OVMF_VARS_4M.fd),
# python3-venv, libarchive-tools, openssl and socat.
# usage: iso/secureboot-test.sh ISO OUT_DIR
set -euo pipefail

iso=$1 out=$2
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"
code=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.secboot.fd}
blank=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
disk=$out/disk.qcow2
# shellcheck disable=SC2054 # QEMU's own commas
qemu=(qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -device virtio-vga -display none -nic none
      -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on
      -drive "if=pflash,format=raw,unit=0,file=$code,readonly=on"
      -monitor "unix:$out/mon,server,nowait")
mon() { echo "$1" | socat - "UNIX-CONNECT:$out/mon" >/dev/null; }
shot() { mon "screendump $out/$1.png -f png"; }
# wait_for PATTERN FILE TRIES: poll FILE every 5 s.
wait_for() {
  for _ in $(seq "$3"); do
    grep -aq "$1" "$2" 2>/dev/null && return 0
    sleep 5
  done
  return 1
}
stop() { kill "$pid" 2>/dev/null && wait "$pid" 2>/dev/null || true; }

if ! command -v virt-fw-vars >/dev/null; then
  python3 -m venv "$out/venv"
  "$out/venv/bin/pip" install -q virt-firmware
  PATH=$out/venv/bin:$PATH
fi
tmp=$(mktemp -d)
bsdtar -xf "$iso" -C "$tmp" KRISSOS.cer loader/entries/01-krissos.conf 'kriss/boot/x86_64/*'
openssl x509 -inform der -in "$tmp/KRISSOS.cer" -out "$tmp/krissos.pem"
openssl x509 -in "$tmp/krissos.pem" -noout -subject
# vars FILE [CERT]: Secure Boot on, Microsoft's keys, plus CERT in db.
vars() {
  local extra=()
  [ -z "${2:-}" ] || extra=(--add-db 0d50f1a0-5b2c-4ff8-8a5c-2d3b9bd0b8f1 "$2")
  virt-fw-vars --input "$blank" --output "$1" --enroll-redhat --secure-boot "${extra[@]}" >/dev/null
}

# 1. Key not trusted: MokManager, and no kernel.
vars "$out/vars-untrusted.fd"
rm -f "$out/mon"
"${qemu[@]}" -drive "if=pflash,format=raw,unit=1,file=$out/vars-untrusted.fd" -cdrom "$iso" \
  -serial "file:$out/untrusted.log" &
pid=$!
sleep 30
shot untrusted
stop
if grep -aq 'Linux version' "$out/untrusted.log"; then
  echo 'untrusted: a kernel started although its key is not trusted.' >&2; exit 1
fi
echo 'untrusted: shim refused the live ISO until its key is enrolled.'

# 2. The live ISO as firmware starts it, with its key trusted. Its boot entries have no
#    serial console, so a unit handed over as SMBIOS credentials reports to ttyS0.
vars "$out/vars-live.fd" "$tmp/krissos.pem"
# $$ is systemd's literal $.
# shellcheck disable=SC2016
unit='[Service]
Type=oneshot
StandardOutput=tty
TTYPath=/dev/ttyS0
ExecStart=/bin/sh -c '"'"'echo "kriss-sb-test: $$(mokutil --sb-state)"; journalctl -k -b -o cat | grep -i "secure boot"'"'"''
dropin='[Unit]
Wants=kriss-sb-test.service'
cred() { printf 'type=11,value=io.systemd.credential.binary:%s=%s' "$1" "$(printf '%s\n' "$2" | base64 -w0)"; }
rm -f "$out/mon"
"${qemu[@]}" -drive "if=pflash,format=raw,unit=1,file=$out/vars-live.fd" -cdrom "$iso" \
  -smbios "$(cred systemd.extra-unit.kriss-sb-test.service "$unit")" \
  -smbios "$(cred systemd.unit-dropin.multi-user.target "$dropin")" \
  -serial "file:$out/live.log" &
pid=$!
ok=0
wait_for 'kriss-sb-test: SecureBoot enabled' "$out/live.log" 60 && ok=1
shot live
stop
grep -a 'kriss-sb-test\|[Ss]ecure boot' "$out/live.log" || true
(( ok )) || { echo 'live: the live ISO did not start with Secure Boot on within 5 minutes.' >&2; exit 1; }
echo 'live: shim -> systemd-boot -> kernel; the live system runs with Secure Boot enabled.'

# 3. Install with Secure Boot on. The live kernel starts directly (OVMF checks its
#    signature against db), runs the scripted install and powers off. The PC's own
#    vars file carries the MOK request over to the next start, as NVRAM would.
vars "$out/vars-pc.fd" "$tmp/krissos.pem"
opts=$(sed -n 's/^options *//p' "$tmp/loader/entries/01-krissos.conf")
qemu-img create -f qcow2 "$disk" 40G
rm -f "$out/mon"
timeout 30m "${qemu[@]}" -drive "if=pflash,format=raw,unit=1,file=$out/vars-pc.fd" -cdrom "$iso" \
  -drive "file=$disk,if=virtio,format=qcow2" \
  -kernel "$tmp"/kriss/boot/x86_64/vmlinuz-* -initrd "$tmp"/kriss/boot/x86_64/initramfs-*.img \
  -fw_cfg "name=opt/kriss/autoinstall,file=$here/test/autoinstall" \
  -append "$opts console=ttyS0,115200 systemd.journald.forward_to_console=1 \
systemd.run=\"/usr/bin/bash /sys/firmware/qemu_fw_cfg/by_name/opt/kriss/autoinstall/raw\" \
systemd.run_success_action=poweroff systemd.run_failure_action=poweroff" \
  -serial "file:$out/install.log" || true
grep -a 'kriss: ' "$out/install.log" || true
if ! grep -aq 'kriss-autoinstall: Secure Boot key queued for MokManager' "$out/install.log" ||
  ! grep -aq 'kriss-autoinstall: done' "$out/install.log"; then
  grep -an 'kriss:\|error\|Error\|failed' "$out/install.log" | tail -40 >&2
  echo 'install: the scripted install with Secure Boot on failed; see install.log.' >&2
  exit 1
fi

# The first start: MokManager, driven as a person would. OVMF mirrors the screen to the
# serial log, so each step waits for its words there; a screenshot records each screen.
rm -f "$out/mon"
"${qemu[@]}" -drive "if=pflash,format=raw,unit=1,file=$out/vars-pc.fd" \
  -drive "file=$disk,if=virtio,format=qcow2" \
  -smbios "$(cred systemd.extra-unit.kriss-sb-test.service "$unit")" \
  -smbios "$(cred systemd.unit-dropin.multi-user.target "$dropin")" \
  -serial "file:$out/disk.log" &
pid=$!
step() {  # step NAME PATTERN KEYS...: wait for PATTERN, screenshot, press KEYS
  local name=$1 pattern=$2 k; shift 2
  wait_for "$pattern" "$out/disk.log" 12 || { shot "mok-$name"; stop; echo "MokManager: no \"$pattern\" on screen." >&2; exit 1; }
  sleep 1
  shot "mok-$name"
  for k in "$@"; do mon "sendkey $k"; sleep 0.5; done
  sleep 2
}
step any 'Press any key' ret
step menu 'Enroll MOK' down ret
step view 'View key' down ret
step confirm 'Enroll the key' down ret
step password 'Password' k r i s s o s ret
step reboot 'Reboot' ret
ok=0
for _ in $(seq 60); do
  if grep -aqE 'Started.*Greeter daemon|greetd\[[0-9]+\]: pam_unix\(greetd:session\): session opened for user greeter' \
    "$out/disk.log"; then ok=1; break; fi
  sleep 5
done
sleep 20
shot installed
stop
grep -a 'kriss-sb-test\|[Ss]ecure boot\|Failed to start' "$out/disk.log" || true
(( ok )) || { echo 'installed: no login screen within 5 minutes of MokManager.' >&2; exit 1; }
# The installed kernel runs with quiet, so its own "Secure boot enabled" never reaches
# the serial log; the same unit as the live test reports it instead.
grep -aq 'kriss-sb-test: SecureBoot enabled' "$out/disk.log" ||
  { echo 'installed: the kernel does not report Secure Boot as enabled.' >&2; exit 1; }
echo 'installed: MokManager enrolled the PC key; shim -> Limine -> KrissOS with Secure Boot enabled.'
