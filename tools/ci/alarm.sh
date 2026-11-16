#!/bin/bash
# Make a local Docker image named `alarm` from the official Arch Linux ARM rootfs. Run on
# an arm64 host (GitHub's ubuntu-24.04-arm): Arch publishes no aarch64 container image,
# and we take no third-party one.
# usage: tools/ci/alarm.sh
set -euo pipefail

keys=$(cd "$(dirname "$0")/keys" && pwd)
url=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 3 -o "$tmp/rootfs.tar.gz" "$url"
curl -fsSL --retry 3 -o "$tmp/rootfs.tar.gz.sig" "$url.sig"
# The download is plain HTTP (the HTTPS certificate does not match the host), so check
# the signature against the vendored Arch Linux ARM build key.
gpg --dearmor <"$keys/archlinuxarm.asc" >"$tmp/alarm.gpg"
gpgv --keyring "$tmp/alarm.gpg" "$tmp/rootfs.tar.gz.sig" "$tmp/rootfs.tar.gz"

docker import "$tmp/rootfs.tar.gz" alarm:rootfs
docker build -t alarm - <<'EOF'
FROM alarm:rootfs
# pacman's Landlock sandbox cannot be applied inside Docker; this container is throwaway.
RUN sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf \
 && pacman-key --init && pacman-key --populate archlinuxarm \
 && pacman -Syu --noconfirm --needed base-devel git \
 && pacman -Scc --noconfirm
EOF
