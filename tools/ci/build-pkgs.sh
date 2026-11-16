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
published=""
for dir; do
  echo "::group::$dir"
  # Pinned builds of other people's packages are large (the NVIDIA driver is ~400 MB) and
  # change only on a bump, so skip one whose exact version is already published.
  case ${dir%/} in pkgs/winboat | pkgs/nvidia-580xx-utils | pkgs/lib32-nvidia-580xx-utils)
    : "${published:=$(curl -fsSL "https://github.com/${GITHUB_REPOSITORY:-krazetech/krissos}/releases/download/repo-$(uname -m)/kriss.db" \
      | bsdtar -tf - 2>/dev/null | cut -d/ -f1 | sort -u || true)}"
    # shellcheck disable=SC1091,SC2154 # pkgname, pkgver and pkgrel come from the PKGBUILD
    v=$(. "$dir/PKGBUILD" && echo "${pkgname[0]}-$pkgver-$pkgrel")
    if grep -qxF "$v" <<<"$published"; then
      echo "$v is already in [kriss]; skipped"
      echo "::endgroup::"
      continue
    fi ;;
  esac
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
