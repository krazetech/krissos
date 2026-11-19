#!/usr/bin/env bash
# Build the KrissOS live ISO. Run as root on Arch (CI runs it in a privileged
# archlinux container).
# usage: iso/build.sh OUT_DIR WORK_DIR
set -euo pipefail

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
pacman -S --noconfirm --needed base-devel python librsvg python-pywayland wayland wayland-protocols rust
id builder >/dev/null 2>&1 || useradd -m builder
src="$work/src" local_repo="$work/kriss-local"
rm -rf "$src" "$local_repo"
mkdir -p "$src" "$local_repo"
cp -a "$here/../pkgs" "$here/../theme" "$here/../tools" "$here/../shell" "$here/../installer" "$src/"
chown -R builder "$src" "$local_repo"
for p in kriss-keyring kriss-settings kriss-theme kriss-tools kriss-shell kriss-installer; do
  su builder -c "cd '$src/pkgs/$p' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
done
# Calamares, cosmic-comp-kriss and cosmic-settings-kriss take a while to compile: build them only when [kriss]
# lacks this version.
pacman --config "$here/pacman.conf" -Sy
for p in calamares cosmic-comp-kriss cosmic-settings-kriss; do
  dir=$src/pkgs/$p
  want=$(source "$dir/PKGBUILD" && echo "$pkgver-$pkgrel")
  have=$(pacman --config "$here/pacman.conf" -Sl kriss | awk -v p="$p" '$2 == p {print $3}')
  if [ "$want" != "$have" ]; then
    echo "Building $p $want ([kriss] has '${have:-none}')"
    (source "$dir/PKGBUILD" && pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}")
    su builder -c "cd '$dir' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
  fi
done
repo-add "$local_repo/kriss-local.db.tar.zst" "$local_repo"/*.pkg.tar.zst
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

mkarchiso -v -r -w "$work/mkarchiso" -o "$out" "$profile"
