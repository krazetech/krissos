#!/usr/bin/env bash
# Build the KrissOS aarch64 image (ARCHITECTURE §13): Arch Linux ARM with the asahi-alarm
# and [kriss] repos, booting to the KrissOS Shell. The output is the layout the Asahi
# installer takes: an ESP tree and an ext4 root.img (docs/apple-silicon.md).
# Run as root, from anywhere, in a privileged Arch Linux ARM container (tools/ci/alarm.sh).
#   generic  Arch Linux ARM's linux-aarch64, for UEFI VMs. Also writes a whole GPT disk,
#            krissos-aarch64-generic.img, which aarch64/boot-test.sh boots in QEMU.
#   asahi    The Asahi kernel, m1n1 and U-Boot, for Apple Silicon Macs. Writes
#            krissos-aarch64-asahi.zip for the Asahi installer. Not tested on hardware yet.
# usage: aarch64/build.sh OUT_DIR WORK_DIR generic|asahi
set -euo pipefail

out=$1 work=$2 flavour=$3
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
case $flavour in generic | asahi) ;; *) echo "flavour must be generic or asahi" >&2; exit 1 ;; esac
# Also in rootfs/etc/fstab, rootfs/etc/kernel/cmdline and installer_data.json.
root_uuid=23f2f273-7b37-4e59-9b91-b8a28807e89f esp_id=4B524953
asahi_key=12CE6799A94A3F1B5DDFFE88F576553597FB8FEB
mkdir -p "$out" "$work"
out=$(realpath "$out") work=$(realpath "$work")
root=$work/root

# --- repos -----------------------------------------------------------------------------
# asahi-alarm goes before [core], as asahi-alarm documents, so its builds win; [kriss] last.
add_repos() {
  # shellcheck disable=SC2016 # $arch is pacman's
  sed -i '/^\[core\]/i [asahi-alarm]\nServer = https://github.com/asahi-alarm/asahi-alarm/releases/download/$arch\n' "$1"
  printf '\n[kriss]\nServer = https://github.com/krazetech/krissos/releases/download/repo-aarch64\n' >>"$1"
}
pacman-key --add "$repo/tools/ci/keys/asahi-alarm.asc"
pacman-key --lsign-key "$asahi_key"
# [kriss] (repo-aarch64) is signed with the KrissOS key, like iso/build.sh.
pacman-key --add "$repo/pkgs/kriss-keyring/krissos.gpg"
pacman-key --lsign-key 7C92AE8B599AF81321666CA31317AA31B21C5F87
grep -q '^\[asahi-alarm\]' /etc/pacman.conf || add_repos /etc/pacman.conf
# Until the first publish there is no repo-aarch64 release; build from this checkout alone.
curl -fsIL -o /dev/null https://github.com/krazetech/krissos/releases/download/repo-aarch64/kriss.db \
  || sed -i '/^\[kriss\]/,$d' /etc/pacman.conf
# KRISS_CHANNEL=testing (CI on main and PRs) puts [kriss-testing] ahead of [kriss] for the
# build only, as iso/build.sh does; the image itself keeps [kriss] alone.
testing_url=https://github.com/krazetech/krissos/releases/download/testing-aarch64
if [ "${KRISS_CHANNEL:-stable}" = testing ] && ! grep -q '^\[kriss-testing\]' /etc/pacman.conf \
  && curl -fsIL -o /dev/null "$testing_url/kriss-testing.db"; then
  if grep -q '^\[kriss\]' /etc/pacman.conf; then
    sed -i "/^\[kriss\]/i [kriss-testing]\nServer = $testing_url\n" /etc/pacman.conf
  else
    printf '\n[kriss-testing]\nServer = %s\n' "$testing_url" >>/etc/pacman.conf
  fi
fi
pacman -Syu --noconfirm --needed asahi-alarm-keyring arch-install-scripts dosfstools mtools e2fsprogs gptfdisk

# --- [kriss] from this checkout ----------------------------------------------------------
# Like iso/build.sh: an image built from a branch carries that branch's packages.
local_repo=$work/kriss-local
rm -rf "$local_repo"
(cd "$repo" && "$repo/tools/ci/build-pkgs.sh" "$local_repo" \
  pkgs/kriss-keyring pkgs/kriss-settings pkgs/kriss-theme pkgs/kriss-tools pkgs/kriss-shell pkgs/kriss-welcome pkgs/kriss-store)
repo-add "$local_repo/kriss-local.db.tar.zst" "$local_repo"/*.pkg.tar.zst
# pacstrap -K fills the image's keyring from the keyrings installed here.
pacman -U --noconfirm "$local_repo"/kriss-keyring-*.pkg.tar.zst
conf=$work/pacman.conf
sed "/^\[core\]/i [kriss-local]\nSigLevel = Optional TrustAll\nServer = file://$local_repo\n" /etc/pacman.conf >"$conf"
pacman --config "$conf" -Sy

# --- the system ----------------------------------------------------------------------------
pkgs=(base mkinitcpio sudo nano man-db networkmanager bluez bluez-utils flatpak
      pipewire pipewire-alsa pipewire-pulse wireplumber firefox noto-fonts noto-fonts-emoji
      kriss-keyring kriss-settings kriss-theme kriss-tools kriss-welcome kriss-store
      kriss-shell greetd cosmic-files cosmic-terminal cosmic-settings
      xdg-desktop-portal-cosmic power-profiles-daemon upower libnotify)
case $flavour in
generic) pkgs+=(linux-aarch64) hooks="base udev modconf keyboard keymap consolefont block filesystems fsck" ;;
asahi)
  # ponytail: asahi-alarm's linux-asahi until linux-kriss-asahi is in [kriss]; then
  # asahi-meta takes ours (it provides linux-asahi).
  kernel=linux-asahi
  if pacman --config "$conf" -Si linux-kriss-asahi >/dev/null 2>&1; then kernel=linux-kriss-asahi; fi
  pkgs+=("$kernel" asahi-meta asahi-desktop-meta)
  hooks="base asahi udev modconf kms keyboard keymap consolefont block filesystems fsck" ;;
esac

rm -rf "$root"
# The ESP is a plain directory at /boot/efi until it is packed below. m1n1's pacman hook
# writes m1n1/boot.bin there when the directory exists.
mkdir -p "$root/boot/efi/m1n1"
# -M: the image keeps Arch Linux ARM's own mirrorlist, not the CI one (tools/ci/alarm.sh).
pacstrap -C "$conf" -K -M "$root" "${pkgs[@]}"
gpgconf --homedir "$root/etc/pacman.d/gnupg" --kill all 2>/dev/null || true

cp -a "$here/rootfs/." "$root/"
add_repos "$root/etc/pacman.conf"
chr() { arch-chroot "$root" "$@"; }
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' "$root/etc/locale.gen"
chr locale-gen
ln -sf /usr/share/zoneinfo/UTC "$root/etc/localtime"
# No autodetect: the image is built in a container, not on the machine it boots.
echo "HOOKS=($hooks)" >"$root/etc/mkinitcpio.conf.d/kriss.conf"
# One unified kernel image at the firmware's fallback path, rebuilt on every kernel update:
# UEFI (QEMU's edk2, the Mac's U-Boot) starts it directly, so there is no boot loader.
# ponytail: no menu and no fallback initramfs; add a loader when snapshots need a menu.
for p in "$root"/etc/mkinitcpio.d/*.preset; do
  { grep '^ALL_kver=' "$p"; echo "PRESETS=('default')"; echo 'default_uki="/boot/efi/EFI/BOOT/BOOTAA64.EFI"'; } >"$p.new"
  mv "$p.new" "$p"
done
rm -f "$root"/boot/initramfs-*.img
mkdir -p "$root/boot/efi/EFI/BOOT"
chr mkinitcpio -P
# update-m1n1 looks for device trees under linux-asahi's *-ARCH modules only; point it at ours.
if [ "${kernel:-}" = linux-kriss-asahi ]; then
  mkdir -p "$root/etc/default"
  # shellcheck disable=SC2016 # expanded by update-m1n1, which sources this file
  echo 'DTBS=$(ls -d /lib/modules/*-kriss-asahi | sort -rV | head -1)/dtbs/*.dtb' >"$root/etc/default/update-m1n1"
fi
if [ "$flavour" = asahi ]; then chr update-m1n1 /boot/efi/m1n1/boot.bin; else rmdir "$root/boot/efi/m1n1"; fi

# ponytail: preview login, password `kriss`; see rootfs/etc/greetd/config.toml.
chr useradd -m -G wheel -c KrissOS -s /bin/bash kriss
echo kriss:kriss | chr chpasswd
chr systemctl enable NetworkManager bluetooth greetd systemd-timesyncd
# A new machine-id on first boot; systemd-firstboot asks nothing (see its drop-in).
echo uninitialized >"$root/etc/machine-id"
rm -rf "$root"/var/cache/pacman/pkg/* "$root"/var/lib/pacman/sync/*

# --- pack ------------------------------------------------------------------------------------
img=$work/img
rm -rf "$img" && mkdir -p "$img/esp"
mv "$root"/boot/efi/* "$img/esp/"
mb=$(du -sm "$root" | cut -f1)
truncate -s $((mb + mb / 4 + 512))M "$img/root.img"
mkfs.ext4 -q -d "$root" -U "$root_uuid" -L krissos-root "$img/root.img"
ls -lh "$img/root.img"; du -sh "$img/esp"

case $flavour in
asahi)
  [ -s "$img/esp/m1n1/boot.bin" ] || { echo 'm1n1/boot.bin is missing' >&2; exit 1; }
  rm -f "$out/krissos-aarch64-asahi.zip"
  (cd "$img" && bsdtar --format zip -cf "$out/krissos-aarch64-asahi.zip" esp root.img)
  sed "s/@ROOT_SIZE@/$(stat -c %s "$img/root.img")/" "$here/installer_data.json" >"$out/installer_data.json"
  ;;
generic)
  # GPT: a 512 MiB ESP (the Asahi installer's size) and the root filesystem.
  esp=$work/esp.img disk=$out/krissos-aarch64-generic.img
  rm -f "$esp" "$disk"
  mkfs.fat -F 32 -i "$esp_id" -n KRISSOS -C "$esp" $((512 * 1024)) >/dev/null
  mcopy -s -i "$esp" "$img"/esp/* ::
  root_mb=$(($(stat -c %s "$img/root.img") / 1048576))
  truncate -s $((1 + 512 + root_mb + 1))M "$disk"
  sgdisk -n 1:1M:+512M -t 1:ef00 -c 1:EFI -n 2:0:0 -t 2:8304 -c 2:KrissOS "$disk" >/dev/null
  dd if="$esp" of="$disk" bs=1M seek=1 conv=notrunc,sparse status=none
  dd if="$img/root.img" of="$disk" bs=1M seek=513 conv=notrunc,sparse status=none
  ;;
esac
ls -lh "$out"
