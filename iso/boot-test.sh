#!/usr/bin/env bash
# Boot the ISO in QEMU/KVM, screenshot the UEFI boot menu, then boot the "Install KrissOS"
# entry with a serial console and wait until the KrissOS Shell and then the installer
# (Calamares) start. Then the same under SeaBIOS (legacy BIOS), through the ISO's own
# syslinux menu. Needs qemu-system-x86, ovmf, libarchive-tools (bsdtar) and socat.
# usage: iso/boot-test.sh ISO OUT_DIR
set -euo pipefail

iso=$1 out=$2
ovmf=${OVMF:-/usr/share/ovmf/OVMF.fd}
mkdir -p "$out"
qemu=(qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 4096 -device virtio-vga
      -display none -cdrom "$iso" -monitor "unix:$out/mon,server,nowait")
mon() { echo "$1" | socat - "UNIX-CONNECT:$out/mon" >/dev/null; }
shot() { mon "screendump $out/$1.png -f png"; }
# keys TEXT: type TEXT on the VM's keyboard.
keys() {
  local i c
  for ((i = 0; i < ${#1}; i++)); do
    c=${1:i:1}
    case $c in
    ' ') c=spc ;; =) c=equal ;; ,) c=comma ;; .) c='dot' ;; -) c=minus ;; _) c=shift-minus ;;
    esac
    mon "sendkey $c"
  done
}
console=' console=ttyS0,115200 systemd.journald.forward_to_console=1'

# live NAME: wait for the Shell and then the installer in NAME.log, screenshot the
# installer as NAME.png, stop the VM ($pid).
live() {
  local log=$out/$1.log shell=0 installer=0 i
  # wait_for PATTERN TRIES: poll the serial log every 5 s.
  wait_for() {
    for i in $(seq "$2"); do
      grep -q "$1" "$log" 2>/dev/null && return 0
      sleep 5
    done
    return 1
  }
  wait_for 'kriss-shell.*KrissOS Shell started' 60 && shell=1
  # kriss-install logs Calamares to the journal with the tag calamares.
  (( shell )) && wait_for 'calamares.*Window now visible' 24 && installer=1
  sleep 15  # let the window draw
  shot "$1"
  kill "$pid" && wait "$pid" || true
  grep -m1 'Started.*Greeter daemon' "$log" || true
  grep 'calamares.*\(Calamares version\|ERROR\|FATAL\)' "$log" || true
  if (( ! shell )); then echo "$1: the KrissOS Shell did not start within 5 minutes." >&2; return 1; fi
  echo "$1: KrissOS Shell started."
  if (( ! installer )); then echo "$1: the installer did not open within 2 minutes of the Shell." >&2; return 1; fi
  echo "$1: installer (Calamares) started."
}

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
  -append "$opts$console" -serial "file:$out/serial.log" &
pid=$!
live serial
mv "$out/serial.png" "$out/installer.png"

# 3. Legacy BIOS: SeaBIOS (QEMU's default firmware) boots the ISO's syslinux menu. Pick
#    "Install KrissOS (BIOS)", the second entry, and add the serial console to its line
#    (Tab edits it).
rm -f "$out/mon"
"${qemu[@]}" -serial "file:$out/bios.log" &
pid=$!
sleep 6
shot bios-menu
mon 'sendkey down'
mon 'sendkey tab'
keys "$console"
mon 'sendkey ret'
live bios
