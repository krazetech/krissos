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
case $ACCEL in tcg) cpu=max,pauth-impdef=on tries=240 ;; *) cpu=host tries=60 ;; esac
echo "Accelerator: $ACCEL"
mkdir -p "$out"
rm -f "$out/mon"

# Boot a copy: the first boot grows the root filesystem and writes a machine-id.
cp --sparse=always "$disk" "$out/disk.img" 2>/dev/null || cp "$disk" "$out/disk.img"
# systemd-stub appends this SMBIOS string to the image's kernel command line, so the test
# gets a serial console with the journal on it without changing the image.
qemu-system-aarch64 -machine virt -accel "$ACCEL" -cpu "$cpu" -smp 4 -m 4096 -bios "$fw" \
  -drive "file=$out/disk.img,if=virtio,format=raw" \
  -device virtio-gpu-pci -device qemu-xhci -device usb-kbd -device usb-tablet \
  -nic user,model=virtio-net-pci -display none \
  -smbios 'type=11,value=io.systemd.stub.kernel-cmdline-extra=console=ttyAMA0 systemd.journald.forward_to_console=1' \
  -serial "file:$out/serial.log" -monitor "unix:$out/mon,server,nowait" &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT

ok=0 died=0
for _ in $(seq "$tries"); do
  if grep -q 'kriss-shell.*KrissOS Shell started' "$out/serial.log" 2>/dev/null; then ok=1; break; fi
  kill -0 "$pid" 2>/dev/null || { died=1; break; }
  sleep 5
done
sleep 30 # let the Shell draw
echo "screendump $out/shell.png -f png" | socat - "UNIX-CONNECT:$out/mon" >/dev/null || true
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
