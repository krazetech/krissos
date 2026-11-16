#!/usr/bin/env bash
# Boot the generic aarch64 disk in a QEMU `virt` VM with UEFI firmware (edk2), as firmware
# boots it: edk2 starts the unified kernel image at EFI/BOOT/BOOTAA64.EFI. Wait until the
# KrissOS Shell starts, then screenshot it. Apple hardware cannot be emulated; this checks
# the image, the [kriss] packages and the Shell on aarch64.
# Needs qemu-system-aarch64, the edk2 aarch64 firmware and socat.
# usage: aarch64/boot-test.sh DISK OUT_DIR
# env: FW (edk2 firmware; default: Debian/Ubuntu's), ACCEL (kvm, hvf or tcg; default: kvm
#      when /dev/kvm is usable, else tcg). On a Mac with Homebrew's qemu:
#      FW=$(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd ACCEL=hvf aarch64/boot-test.sh ...
set -euo pipefail

disk=$1 out=$2
fw=${FW:-/usr/share/qemu-efi-aarch64/QEMU_EFI.fd}
if [ -z "${ACCEL:-}" ]; then
  if [ -w /dev/kvm ]; then ACCEL=kvm; else ACCEL=tcg; fi
fi
# Not -cpu max under TCG: the kernel's memset uses FEAT_MOPS, which Ubuntu 24.04's QEMU 8.2
# emulates wrongly (an oops in module loading). Neoverse N1 (Armv8.2) has no MOPS.
case $ACCEL in tcg) cpu=neoverse-n1 tries=240 ;; *) cpu=host tries=60 ;; esac
echo "Accelerator: $ACCEL"
mkdir -p "$out"
rm -f "$out/mon" "$out/ser"

# Boot a copy: the first boot grows the root filesystem and writes a machine-id.
cp --sparse=always "$disk" "$out/disk.img" 2>/dev/null || cp "$disk" "$out/disk.img"
# systemd-stub appends this SMBIOS string to the image's kernel command line, so the test
# gets a serial console with the journal on it without changing the image.
qemu-system-aarch64 -machine virt -accel "$ACCEL" -cpu "$cpu" -smp 4 -m 4096 -bios "$fw" \
  -drive "file=$out/disk.img,if=virtio,format=raw" \
  -device virtio-gpu-pci -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic user,model=virtio-net-pci -display none \
  -smbios 'type=11,value=io.systemd.stub.kernel-cmdline-extra=console=ttyAMA0 systemd.journald.forward_to_console=1 panic=1' -no-reboot \
  -chardev "socket,id=ser,path=$out/ser,server=on,wait=off,logfile=$out/serial.log" -serial chardev:ser -monitor "unix:$out/mon,server,nowait" &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT

ok=0 died=0
for _ in $(seq "$tries"); do
  if grep -q 'kriss-shell.*KrissOS Shell started' "$out/serial.log" 2>/dev/null; then ok=1; break; fi
  kill -0 "$pid" 2>/dev/null || { died=1; break; }
  sleep 5
done
# kriss-shell logs that line once cosmic-comp is up, before Quickshell starts. So also wait
# until something is drawn. ponytail: a blank screen saves as a ~5 KB PNG; the bar and the
# wallpaper make it far bigger. Use a pixel check if this ever misjudges.
drawn=0
if ((ok)); then
  for _ in $(seq "$((tries / 2))"); do
    echo "screendump $out/scanout.png -f png" | socat - "UNIX-CONNECT:$out/mon" >/dev/null || true
    sleep 2
    if [ "$(wc -c <"$out/scanout.png" 2>/dev/null || echo 0)" -gt 50000 ]; then drawn=1; break; fi
    sleep 8
  done
fi
# QEMU's virtio-gpu scanout sticks at an early frame (the wallpaper alone), though cosmic-comp
# goes on drawing the bar and windows. So for the record, log in on the serial console (getty
# on ttyAMA0), save Quickshell's log (kept in the runtime dir, not the journal) and grab what
# the compositor shows with grim, sent back as base64 over serial.
if ((drawn)); then
  for line in kriss kriss 'export WAYLAND_DISPLAY=wayland-1; qs log -p /usr/share/kriss-shell/qml 2>&1 | tail -150' \
    'grim -s 0.5 - | base64 -w 76 | sed s/^/B64:/'; do
    printf '%s\r' "$line" | socat - "UNIX-CONNECT:$out/ser" >/dev/null || true
    sleep 20
  done
  sleep 40
  tr -d '\r' <"$out/serial.log" | sed -n 's/^B64://p' | base64 -d >"$out/shell.png" 2>/dev/null || true
fi
kill "$pid" 2>/dev/null && wait "$pid" || true
rm -f "$out/disk.img"

grep -m3 'Linux version\|Failed to start\|Kernel panic' "$out/serial.log" || true
if ((!ok)); then
  tail -40 "$out/serial.log" >&2
  if ((died)); then echo 'QEMU exited before the KrissOS Shell started.' >&2
  else echo "The KrissOS Shell did not start within $((tries * 5 / 60)) minutes." >&2; fi
  exit 1
fi
echo 'KrissOS Shell started.'
if ((!drawn)); then echo 'The KrissOS Shell did not draw anything.' >&2; exit 1; fi
echo 'KrissOS Shell drawn (see shell.png; scanout.png is QEMU'"'"'s stale view).'
