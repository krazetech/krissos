#!/usr/bin/env bash
# Build the KrissOS live ISO. Run as root on Arch (CI runs it in a privileged
# archlinux container).
# usage: iso/build.sh OUT_DIR WORK_DIR
set -euo pipefail

# ponytail: Arch's kernel until linux-kriss-generic is published in [kriss]; then set
# this to linux-kriss-generic. The live image takes the baseline x86-64 build so it
# boots on CPUs without x86-64-v3.
kernel=linux

here=$(cd "$(dirname "$0")" && pwd)
out=$1 work=$2
mkdir -p "$out" "$work"

pacman -Syu --noconfirm --needed archiso
# Trust the [kriss] key from this checkout. The live system trusts it through
# kriss-keyring and `pacman-key --populate` in pacman-init.service.
pacman-key --init
pacman-key --add "$here/../pkgs/kriss-keyring/krissos.gpg"
pacman-key --lsign-key 7C92AE8B599AF81321666CA31317AA31B21C5F87

profile="$work/profile"
rm -rf "$profile"
cp -a "$here/." "$profile"

# Build the small [kriss] packages from this checkout and put them ahead of the
# published repo, so an ISO from a branch carries that branch's theme and tools.
pacman -S --noconfirm --needed base-devel python librsvg python-pywayland wayland wayland-protocols
id builder >/dev/null 2>&1 || useradd -m builder
src="$work/src" local_repo="$work/kriss-local"
rm -rf "$src" "$local_repo"
mkdir -p "$src" "$local_repo"
cp -a "$here/../pkgs" "$here/../theme" "$here/../tools" "$here/../shell" "$here/../installer" "$src/"
chown -R builder "$src" "$local_repo"
for p in kriss-keyring kriss-settings kriss-theme kriss-tools kriss-shell kriss-installer; do
  su builder -c "cd '$src/pkgs/$p' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
done
# Calamares takes a while to compile: build it only when [kriss] lacks this version.
cal=$src/pkgs/calamares
want=$(source "$cal/PKGBUILD" && echo "$pkgver-$pkgrel")
pacman --config "$here/pacman.conf" -Sy
have=$(pacman --config "$here/pacman.conf" -Sl kriss | awk '$2 == "calamares" {print $3}')
if [ "$want" != "$have" ]; then
  echo "Building calamares $want ([kriss] has '${have:-none}')"
  (source "$cal/PKGBUILD" && pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}")
  su builder -c "cd '$cal' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
fi
repo-add "$local_repo/kriss-local.db.tar.zst" "$local_repo"/*.pkg.tar.zst
# The installer installs from this copy first, so the installed system gets the same
# [kriss] packages as the ISO (see installer/lib/pacstrap).
mkdir -p "$profile/airootfs/opt"
cp -a "$local_repo" "$profile/airootfs/opt/kriss-local"
# sed -i replaces the pacman.conf symlink with a file, so the live system's copy keeps
# only the published repo.
sed -i "/^\[kriss\]/i [kriss-local]\nSigLevel = Optional TrustAll\nServer = file://$local_repo\n" \
  "$profile/pacman.conf"

# BIOS boot menu background: the logo above the menu (systemd-boot shows no images).
python "$here/../theme/generate.py" "$here/../theme/templates/usr/share/pixmaps" "$work/logo"
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"><rect width="640" height="480"/>'
  echo '<svg x="264" y="24" width="112" height="112" viewBox="0 0 569 569">'
  sed '1,/<svg /d' "$work/logo/krissos.svg"  # the logo's shapes and its closing </svg>
  echo '</svg>'
} | rsvg-convert -o "$profile/syslinux/splash.png"

sed -i "s/^linux\$/$kernel/" "$profile/packages.x86_64"
sed -i "s/vmlinuz-linux/vmlinuz-$kernel/; s/initramfs-linux\./initramfs-$kernel./" \
  "$profile"/efiboot/loader/entries/*.conf "$profile"/syslinux/*.cfg
mkarchiso -v -r -w "$work/mkarchiso" -o "$out" "$profile"
