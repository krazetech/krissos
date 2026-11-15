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
pacman -S --noconfirm --needed base-devel python
id builder >/dev/null 2>&1 || useradd -m builder
src="$work/src" local_repo="$work/kriss-local"
rm -rf "$src" "$local_repo"
mkdir -p "$src" "$local_repo"
cp -a "$here/../pkgs" "$here/../theme" "$here/../tools" "$src/"
chown -R builder "$src" "$local_repo"
for p in kriss-keyring kriss-settings kriss-theme kriss-tools; do
  su builder -c "cd '$src/pkgs/$p' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
done
repo-add "$local_repo/kriss-local.db.tar.zst" "$local_repo"/*.pkg.tar.zst
# sed -i replaces the pacman.conf symlink with a file, so the live system's copy keeps
# only the published repo.
sed -i "/^\[kriss\]/i [kriss-local]\nSigLevel = Optional TrustAll\nServer = file://$local_repo\n" \
  "$profile/pacman.conf"

sed -i "s/^linux\$/$kernel/" "$profile/packages.x86_64"
sed -i "s/vmlinuz-linux/vmlinuz-$kernel/; s/initramfs-linux\./initramfs-$kernel./" \
  "$profile"/efiboot/loader/entries/*.conf "$profile"/syslinux/*.cfg
mkarchiso -v -r -w "$work/mkarchiso" -o "$out" "$profile"
