#!/usr/bin/env bash
# Install the ISO onto a blank QEMU disk with iso/test/autoinstall (the installer's own
# pacstrap and configure steps, unattended), then boot the disk through Limine and wait
# for the KrissOS login screen. Needs qemu-system-x86, ovmf, libarchive-tools and socat.
# usage: iso/install-test.sh ISO OUT_DIR
set -euo pipefail

iso=$1 out=$2
here=$(cd "$(dirname "$0")" && pwd)
ovmf=${OVMF:-/usr/share/ovmf/OVMF.fd}
mkdir -p "$out"
disk=$out/disk.qcow2
qemu-img create -f qcow2 "$disk" 40G
qemu=(qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -device virtio-vga -display none
      -drive "file=$disk,if=virtio,format=qcow2" -monitor "unix:$out/mon,server,nowait")
shot() { echo "screendump $out/$1.png -f png" | socat - "UNIX-CONNECT:$out/mon" >/dev/null; }

# 1. Live ISO, unattended install. systemd.run= runs the script instead of the desktop
#    and powers off when it ends.
tmp=$(mktemp -d)
bsdtar -xf "$iso" -C "$tmp" loader/entries/01-krissos.conf 'kriss/boot/x86_64/*'
opts=$(sed -n 's/^options *//p' "$tmp/loader/entries/01-krissos.conf")
rm -f "$out/mon"
timeout 30m "${qemu[@]}" -bios "$ovmf" -cdrom "$iso" \
  -kernel "$tmp"/kriss/boot/x86_64/vmlinuz-* -initrd "$tmp"/kriss/boot/x86_64/initramfs-*.img \
  -fw_cfg "name=opt/kriss/autoinstall,file=$here/test/autoinstall" \
  -append "$opts console=ttyS0,115200 systemd.journald.forward_to_console=1 \
systemd.run=\"/usr/bin/bash /sys/firmware/qemu_fw_cfg/by_name/opt/kriss/autoinstall/raw\" \
systemd.run_success_action=poweroff systemd.run_failure_action=poweroff" \
  -serial "file:$out/install.log" || true
if ! grep -q 'kriss-autoinstall: done' "$out/install.log"; then
  grep -n 'kriss:\|error\|Error\|failed' "$out/install.log" | tail -40 >&2
  echo 'The scripted install failed; see install.log.' >&2
  exit 1
fi
grep 'kriss: ' "$out/install.log" || true

# 2. The installed disk, as firmware boots it: Limine from EFI/BOOT, then KrissOS.
rm -f "$out/mon"
"${qemu[@]}" -bios "$ovmf" -serial "file:$out/installed.log" &
pid=$!
sleep 3
shot limine
ok=0
for _ in $(seq 60); do
  if grep -q 'Started.*Greeter daemon' "$out/installed.log"; then ok=1; break; fi
  sleep 5
done
sleep 30  # let the login screen draw
shot login
kill "$pid" && wait "$pid" || true
grep -m3 'Linux version\|Failed to start' "$out/installed.log" || true
if (( ok )); then echo 'The installed system started its login screen.'; else
  echo 'The installed system did not reach the login screen within 5 minutes.' >&2; exit 1; fi
