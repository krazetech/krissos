#!/bin/bash
# Build [kriss] packages from this checkout. Run as root in an Arch Linux (x86_64) or
# Arch Linux ARM (aarch64) container, from the repo root; makepkg itself runs as a
# throwaway user because it refuses root.
# usage: tools/ci/build-pkgs.sh OUT_DIR PKG_DIR...
set -euo pipefail

out=$(realpath -m "$1")
shift
id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' >/etc/sudoers.d/builder
chown -R builder .
mkdir -p "$out" && chown builder "$out"
for dir; do
  echo "::group::$dir"
  deps=--syncdeps
  # Metapackages are only a dependency list: check every name resolves, then
  # package without installing the lot.
  case $dir in pkgs/kriss-meta-*)
    # shellcheck disable=SC1091,SC2154 # depends comes from the PKGBUILD
    (. "$dir/PKGBUILD" && pacman -Sp "${depends[@]}" >/dev/null)
    deps=--nodeps ;;
  esac
  # Arch Linux ARM's makepkg.conf defaults to .pkg.tar.xz; the repo tooling expects zst.
  su builder -c "cd '$dir' && PKGDEST='$out' PKGEXT=.pkg.tar.zst makepkg $deps --noconfirm --cleanbuild"
  echo "::endgroup::"
done
ls -l "$out"
