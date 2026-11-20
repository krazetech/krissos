#!/usr/bin/env bash
# Build the KrissOS live ISO. Run as root on Arch (CI runs it in a privileged
# archlinux container).
# usage: iso/build.sh OUT_DIR WORK_DIR
# env: KRISS_CHANNEL  stable (the default): packages from [kriss], as for a release.
#                     testing: [kriss-testing] ahead of [kriss], so nightly and PR ISOs test
#                     what is about to be promoted. Only the build sees it: the live system
#                     and installs keep [kriss] alone (`kriss channel testing` opts in).
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
pacman -S --noconfirm --needed base-devel python librsvg python-pywayland wayland wayland-protocols rust qt6-shadertools
id builder >/dev/null 2>&1 || useradd -m builder
src="$work/src" local_repo="$work/kriss-local"
rm -rf "$src" "$local_repo"
mkdir -p "$src" "$local_repo"
cp -a "$here/../pkgs" "$here/../theme" "$here/../tools" "$here/../shell" "$here/../installer" "$src/"
chown -R builder "$src" "$local_repo"
for p in kriss-keyring kriss-settings kriss-theme kriss-tools kriss-shell kriss-installer; do
  su builder -c "cd '$src/pkgs/$p' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
done
# The repos this build installs from. Until the first publish there is no [kriss-testing].
conf=$work/pacman.conf
cp "$here/pacman.conf" "$conf"
testing_url=https://github.com/krazetech/krissos/releases/download/testing-x86_64
add_testing() { sed -i "/^\[kriss\]/i [kriss-testing]\nSigLevel = Required\nServer = $testing_url\n" "$1"; }
if [ "${KRISS_CHANNEL:-stable}" = testing ]; then
  if curl -fsIL -o /dev/null "$testing_url/kriss-testing.db"; then
    add_testing "$conf"
  else
    echo "There is no [kriss-testing] yet; building from [kriss]."
  fi
fi
# Calamares, cosmic-comp-kriss and cosmic-settings-kriss take a while to compile: build them only when the repos
# lack this version. pacman lists repos in order, so [kriss-testing] wins when it is there.
pacman --config "$conf" -Sy
for p in calamares cosmic-comp-kriss cosmic-settings-kriss; do
  dir=$src/pkgs/$p
  want=$(source "$dir/PKGBUILD" && echo "$pkgver-$pkgrel")
  have=$(pacman --config "$conf" -Sl | awk -v p="$p" '$2 == p {print $3; exit}')
  if [ "$want" != "$have" ]; then
    echo "Building $p $want (the repos have '${have:-none}')"
    (source "$dir/PKGBUILD" && pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}")
    su builder -c "cd '$dir' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
  fi
done
repo-add "$local_repo/kriss-local.db.tar.zst" "$local_repo"/*.pkg.tar.zst
# sed -i replaces the pacman.conf symlink with a file, so the live system's copy keeps
# only the published [kriss]. Order: this checkout, then [kriss-testing], then [kriss].
sed -i "/^\[kriss\]/i [kriss-local]\nSigLevel = Optional TrustAll\nServer = file://$local_repo\n" \
  "$profile/pacman.conf"
if grep -q '^\[kriss-testing\]' "$conf"; then add_testing "$profile/pacman.conf"; fi

# BIOS boot menu background: the logo above the menu (systemd-boot shows no images).
python "$here/../theme/generate.py" "$here/../theme/templates/usr/share/pixmaps" "$work/logo"
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"><rect width="640" height="480"/>'
  echo '<svg x="264" y="24" width="112" height="112" viewBox="0 0 569 569">'
  sed '1,/<svg /d' "$work/logo/krissos.svg"  # the logo's shapes and its closing </svg>
  echo '</svg>'
} | rsvg-convert -o "$profile/syslinux/splash.png"

mkarchiso -v -r -w "$work/mkarchiso" -o "$out" "$profile"
