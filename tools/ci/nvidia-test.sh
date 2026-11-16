#!/bin/bash
# Checks kriss nvidia's GPU range and config edits on fixture /sys and /etc trees.
set -euo pipefail
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export KRISS_SYS=$t/sys KRISS_ETC=$t/etc
# shellcheck source=/dev/null # tools/kriss is linted on its own
. "$(dirname "$0")/../kriss"

fail() { echo "FAIL: $*"; exit 1; }
pci() { # pci ADDR VENDOR DEVICE CLASS [BOOT_VGA]
  local d=$t/sys/bus/pci/devices/$1
  mkdir -p "$d"
  echo "$2" >"$d/vendor"; echo "$3" >"$d/device"; echo "$4" >"$d/class"
  [[ -z ${5:-} ]] || echo "$5" >"$d/boot_vga"
}

# The 580 range: Maxwell GM108 (0x1340) up to Turing (0x1e00), not Kepler or Turing.
for id in 0x1340 0x1d10 0x1db1 0x1df6; do
  rm -rf "$t/sys"; pci 0000:01:00.0 0x10de "$id" 0x030200
  [[ $(nvidia_legacy_gpu) == 0000:01:00.0 ]] || fail "$id should be offered the 580 driver"
done
for id in 0x1287 0x1e04 0x2504; do
  rm -rf "$t/sys"; pci 0000:01:00.0 0x10de "$id" 0x030000
  ! nvidia_legacy_gpu >/dev/null || fail "$id should not be offered the 580 driver"
done
rm -rf "$t/sys"; pci 0000:01:00.1 0x10de 0x1d10 0x040300  # the GPU's audio function
! nvidia_legacy_gpu >/dev/null || fail "audio function taken for a GPU"

# A desktop: no iGPU, so only the initramfs and command line change.
rm -rf "$t/sys"; pci 0000:01:00.0 0x10de 0x1c03 0x030000 1
mkdir -p "$t/etc/mkinitcpio.conf.d" "$t/etc/kernel"
echo 'HOOKS=(base udev autodetect microcode modconf kms keyboard keymap block filesystems fsck)' \
  >"$t/etc/mkinitcpio.conf.d/kriss.conf"
echo 'root=UUID=x rw quiet' >"$t/etc/kernel/cmdline"
nvidia_configure
[[ $(<"$t/etc/mkinitcpio.conf.d/kriss.conf") == 'HOOKS=(base udev autodetect microcode modconf keyboard keymap block filesystems fsck)' ]] ||
  fail "kms hook not dropped: $(<"$t/etc/mkinitcpio.conf.d/kriss.conf")"
[[ $(<"$t/etc/kernel/cmdline") == 'root=UUID=x rw quiet nvidia_drm.modeset=1' ]] || fail "cmdline: $(<"$t/etc/kernel/cmdline")"
[[ ! -e $t/etc/environment ]] || fail "desktop got a render device"

# A hybrid laptop (UHD 620 + MX150): the compositor goes to the iGPU. Twice changes nothing more.
pci 0000:00:02.0 0x8086 0x5917 0x030000 1
echo 0 >"$t/sys/bus/pci/devices/0000:01:00.0/boot_vga"
echo 'LANG=ms_MY.UTF-8' >"$t/etc/environment"
nvidia_configure
before=$(cat "$t"/etc/environment "$t"/etc/kernel/cmdline "$t"/etc/mkinitcpio.conf.d/kriss.conf)
nvidia_configure
[[ $(cat "$t"/etc/environment "$t"/etc/kernel/cmdline "$t"/etc/mkinitcpio.conf.d/kriss.conf) == "$before" ]] ||
  fail "second run changed something"
[[ $(<"$t/etc/environment") == $'LANG=ms_MY.UTF-8\nCOSMIC_RENDER_DEVICE=/dev/dri/by-path/pci-0000:00:02.0-render' ]] ||
  fail "environment: $(<"$t/etc/environment")"
echo 'nvidia: ok'
