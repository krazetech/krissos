#!/usr/bin/env bash
# Install the ISO onto a blank QEMU disk with iso/test/autoinstall (the installer's own
# steps, unattended), then boot the disk through Limine and wait for the KrissOS login
# screen. No network card at all (-nic none): installing must never need the internet.
# Then the same again with "Encrypt system": the passphrase is typed at boot.
# FIRMWARE=bios does it all under SeaBIOS (QEMU's default firmware) instead of OVMF, so
# the installer takes its legacy BIOS path. Needs qemu-system-x86, ovmf, libarchive-tools
# and socat.
# usage: [FIRMWARE=uefi|bios] iso/install-test.sh ISO OUT_DIR
set -euo pipefail

iso=$1 out=$2
here=$(cd "$(dirname "$0")" && pwd)
fw=(-bios "${OVMF:-/usr/share/ovmf/OVMF.fd}")
[ "${FIRMWARE:-uefi}" = uefi ] || fw=()
mkdir -p "$out"
disk=$out/disk.qcow2
# Lowercase letters only, so sendkey can type it as is.
passphrase=krisskrisskriss
qemu=(qemu-system-x86_64 -name kriss-install-test -enable-kvm -cpu host -smp 4 -m 4096 -device virtio-vga -display none -nic none
      -drive "file=$disk,if=virtio,format=qcow2" -monitor "unix:$out/mon,server,nowait")
mon() { echo "$1" | socat - "UNIX-CONNECT:$out/mon" >/dev/null; }
shot() { mon "screendump $out/$1.png -f png"; }

tmp=$(mktemp -d)
bsdtar -xf "$iso" -C "$tmp" loader/entries/01-krissos.conf 'kriss/boot/x86_64/*'
opts=$(sed -n 's/^options *//p' "$tmp/loader/entries/01-krissos.conf")

# install_disk NAME [LIVE OPTIONS]: live ISO, unattended install onto a new disk. systemd.run=
# runs the script instead of the desktop and powers off when it ends. Log: NAME.log.
install_disk() {
  local name=$1; shift
  rm -f "$disk" "$out/mon"
  qemu-img create -f qcow2 "$disk" 40G
  timeout 30m "${qemu[@]}" "${fw[@]}" -cdrom "$iso" \
    -kernel "$tmp"/kriss/boot/x86_64/vmlinuz-* -initrd "$tmp"/kriss/boot/x86_64/initramfs-*.img \
    -fw_cfg "name=opt/kriss/autoinstall,file=$here/test/autoinstall" \
    -append "$opts $* console=ttyS0,115200 systemd.journald.forward_to_console=1 \
systemd.run=\"/usr/bin/bash /sys/firmware/qemu_fw_cfg/by_name/opt/kriss/autoinstall/raw\" \
systemd.run_success_action=poweroff systemd.run_failure_action=poweroff" \
    -serial "file:$out/$name.log" || true
  if ! grep -q 'kriss-autoinstall: done' "$out/$name.log"; then
    grep -n 'kriss:\|error\|Error\|failed' "$out/$name.log" | tail -40 >&2
    echo "The scripted install failed; see $name.log." >&2
    exit 1
  fi
  grep 'kriss: ' "$out/$name.log" || true
}

# unlock: type the passphrase until the initramfs hands over to systemd. Both ways,
# since the prompt is on the serial console or, with plymouth, on the screen.
unlock() {
  local log=$1 keys=() i
  for (( i = 0; i < ${#passphrase}; i++ )); do keys+=("${passphrase:i:1}"); done
  for _ in $(seq 12); do
    sleep 10
    if grep -q 'systemd\[1\]' "$log"; then return 0; fi
    printf '%s\r' "$passphrase" | socat - "UNIX-CONNECT:$out/serial" >/dev/null || true
    for k in "${keys[@]}" ret; do mon "sendkey $k"; done
  done
}

# boot NAME [QEMU ARGS]: boot the installed disk, screenshot the Limine menu as NAME.png
# and wait up to 5 minutes for the login screen (NAME-login.png). Serial log: NAME.log.
# With LUKS=1, type the passphrase first (NAME-unlock.png shows the prompt).
boot() {
  local name=$1 ok=0; shift
  rm -f "$out/mon" "$out/serial"
  "${qemu[@]}" "${fw[@]}" "$@" \
    -chardev "socket,id=ser,path=$out/serial,server=on,wait=off,logfile=$out/$name.log" -serial chardev:ser &
  pid=$!
  sleep 4
  shot "$name"
  if (( ${LUKS:-0} )); then
    sleep 16
    shot "$name-unlock"
    unlock "$out/$name.log"
  fi
  for _ in $(seq 60); do
    if grep -q 'Started.*Greeter daemon' "$out/$name.log"; then ok=1; break; fi
    sleep 5
  done
  sleep 30  # let the login screen draw
  shot "$name-login"
  kill "$pid" && wait "$pid" || true
  grep -m3 'Linux version\|Failed to start' "$out/$name.log" || true
  (( ok )) || { echo "$name: no login screen within 5 minutes." >&2; return 1; }
}

# 1. Unattended install.
install_disk install

# 2. The installed disk, as firmware boots it: Limine from EFI/BOOT (UEFI) or from the
#    disk's boot sector (BIOS), then KrissOS.
boot limine
# X11 apps (Steam, most games) need Xwayland under cosmic-comp.
if grep -q 'Failed to start Xwayland' "$out/limine.log"; then echo 'cosmic-comp could not start Xwayland.' >&2; exit 1; fi
echo 'The installed system started its login screen.'

# 3. The snapshot entry. Limine reads a config from SMBIOS before the one on disk, so this
#    boots the limine.conf the installer wrote with only default_entry changed to the
#    snapshot. The kriss-snapshot initramfs hook says when it boots one.
sed -n 's/.*kriss-limine-conf: //p' "$out/install.log" | tail -n1 | tr -d '\r' | base64 -d >"$out/limine.conf"
title=$(sed -n 's|^ *///||p' "$out/limine.conf" | head -n1)
esc=${title//\\/\\\\}; esc=${esc//\//\\/}; esc=${esc//#/\\#}
{
  printf 'limine:config:'
  while IFS= read -r line; do
    [[ $line == default_entry:* ]] && line="default_entry: KrissOS/Snapshots/$esc"
    printf '%s\n' "$line"
  done <"$out/limine.conf"
} >"$out/smbios.conf"
boot snapshot -smbios "type=11,path=$out/smbios.conf"
grep -q 'booting a read-only snapshot' "$out/snapshot.log" || {
  echo 'The snapshot entry did not boot the snapshot.' >&2; exit 1; }
echo "The snapshot \"$title\" booted read-only to its login screen."

# 4. "Encrypt system": / in LUKS2, KRISSBOOT plain. The encrypt hook asks for the
#    passphrase, then the system boots to its login screen as before.
install_disk install-luks "kriss_test_luks=$passphrase"
grep -q 'kriss: / is encrypted' "$out/install-luks.log"
LUKS=1 boot luks
echo 'The encrypted install unlocked with its passphrase and started its login screen.'
