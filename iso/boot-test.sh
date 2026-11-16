#!/usr/bin/env bash
# Boot the ISO in QEMU/KVM, screenshot the UEFI boot menu, then boot the "Install KrissOS"
# entry with a serial console and wait until the KrissOS Shell and then the installer
# (Calamares) start. Needs qemu-system-x86, ovmf,
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
bsdtar -xf "$iso" -C "$tmp" loader/entries/02-krissos-install.conf 'kriss/boot/x86_64/*'
# The [kriss] kernel, not Arch's: its version string (uname -r) ends in -kriss-generic.
file "$tmp"/kriss/boot/x86_64/vmlinuz-* | grep -o 'version [^ ]*' | tee /dev/stderr | grep -q -- '-kriss'
opts=$(sed -n 's/^options *//p' "$tmp/loader/entries/02-krissos-install.conf")
rm -f "$out/mon"
"${qemu[@]}" -bios "$ovmf" -kernel "$tmp"/kriss/boot/x86_64/vmlinuz-* -initrd "$tmp"/kriss/boot/x86_64/initramfs-*.img \
  -append "$opts console=ttyS0,115200 systemd.journald.forward_to_console=1" \
  -serial "file:$out/serial.log" &
pid=$!
# wait_for PATTERN TRIES: poll the serial log every 5 s.
wait_for() {
  for _ in $(seq "$2"); do
    grep -q "$1" "$out/serial.log" && return 0
    sleep 5
  done
  return 1
}
shell=0 installer=0
wait_for 'kriss-shell.*KrissOS Shell started' 60 && shell=1
# kriss-install logs Calamares to the journal with the tag calamares.
(( shell )) && wait_for 'calamares.*Window now visible' 24 && installer=1
sleep 15  # let the window draw
shot installer
kill "$pid" && wait "$pid" || true
grep -m1 'Started.*Greeter daemon' "$out/serial.log" || true
grep 'calamares.*\(Calamares version\|ERROR\|FATAL\)' "$out/serial.log" || true
if (( ! shell )); then echo 'The KrissOS Shell did not start within 5 minutes.' >&2; exit 1; fi
echo 'KrissOS Shell started.'
if (( ! installer )); then echo 'The installer did not open within 2 minutes of the Shell.' >&2; exit 1; fi
echo 'Installer (Calamares) started.'
