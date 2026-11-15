#!/usr/bin/env bash
# Boot the ISO in QEMU/KVM, screenshot the UEFI boot menu, then boot it again with a
# serial console and wait until the KrissOS Shell starts. Needs qemu-system-x86, ovmf,
# libarchive-tools (bsdtar) and socat.
# usage: iso/boot-test.sh ISO OUT_DIR
set -euo pipefail

iso=$1 out=$2
ovmf=${OVMF:-/usr/share/ovmf/OVMF.fd}
mkdir -p "$out"
qemu=(qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 4096 -device virtio-vga
      -display none -cdrom "$iso" -monitor "unix:$out/mon,server,nowait")
shot() { echo "screendump $out/$1.png -f png" | socat - "UNIX-CONNECT:$out/mon" >/dev/null; }

# 1. The ISO exactly as UEFI firmware boots it: the systemd-boot menu.
rm -f "$out/mon"
"${qemu[@]}" -bios "$ovmf" &
sleep 8
shot uefi-menu
kill $! && wait $! || true

# 2. Same kernel, initramfs and options, plus a serial console with the journal on it.
tmp=$(mktemp -d)
bsdtar -xf "$iso" -C "$tmp" loader/entries/01-krissos.conf 'kriss/boot/x86_64/*'
opts=$(sed -n 's/^options *//p' "$tmp/loader/entries/01-krissos.conf")
rm -f "$out/mon"
"${qemu[@]}" -kernel "$tmp"/kriss/boot/x86_64/vmlinuz-* -initrd "$tmp"/kriss/boot/x86_64/initramfs-*.img \
  -append "$opts console=ttyS0,115200 systemd.journald.forward_to_console=1" \
  -serial "file:$out/serial.log" &
pid=$!
ok=0
for _ in $(seq 60); do
  if grep -q 'kriss-shell.*KrissOS Shell started' "$out/serial.log"; then ok=1; break; fi
  sleep 5
done
sleep 20  # let the desktop draw
shot desktop
kill "$pid" && wait "$pid" || true
grep -m1 'Started.*Greeter daemon' "$out/serial.log" || true
if (( ok )); then echo 'KrissOS Shell started.'; else echo 'The KrissOS Shell did not start within 5 minutes.' >&2; exit 1; fi
