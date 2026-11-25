#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
# Make a local Docker image named `alarm` from the official Arch Linux ARM rootfs. Run on
# an arm64 host (GitHub's ubuntu-24.04-arm): Arch publishes no aarch64 container image,
# and we take no third-party one.
# usage: tools/ci/alarm.sh
set -euo pipefail

ci=$(cd "$(dirname "$0")" && pwd)
url=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --retry backs off (1s, 2s, 4s...); a transfer that stalls under 1 kB/s for a minute
# counts as a timeout, so it is retried too.
get() { curl -fsSL --retry 5 --connect-timeout 30 -Y 1024 -y 60 -o "$1" "$2"; }
get "$tmp/rootfs.tar.gz" "$url"
get "$tmp/rootfs.tar.gz.sig" "$url.sig"
# The download is plain HTTP (the HTTPS certificate does not match the host), so check
# the signature against the vendored Arch Linux ARM build key.
gpg --dearmor <"$ci/keys/archlinuxarm.asc" >"$tmp/alarm.gpg"
gpgv --keyring "$tmp/alarm.gpg" "$tmp/rootfs.tar.gz.sig" "$tmp/rootfs.tar.gz"

docker import "$tmp/rootfs.tar.gz" alarm:rootfs
# The build context is tools/ci, for pacman-retry.
docker build -t alarm -f - "$ci" <<'EOF'
FROM alarm:rootfs
# Several mirrors in a fixed order, not the geo redirect: pacman takes each file from the
# first and moves on to the next when one stalls (its 10 s low-speed timeout stays on, as
# that is what makes it move on). Builds only; aarch64/build.sh keeps this list out of the
# image (pacstrap -M). Checked 2026-11; drop a mirror here when it goes away.
RUN printf 'Server = http://%s.archlinuxarm.org/$arch/$repo\n' \
      fl.us.mirror ca.us.mirror nj.us.mirror de.mirror de4.mirror hu.mirror dk.mirror \
      >/etc/pacman.d/mirrorlist
# pacman's Landlock sandbox cannot be applied inside Docker; this container is throwaway.
RUN sed -i '/^#\?ParallelDownloads/d; /^\[options\]/a DisableSandbox\nParallelDownloads = 5' /etc/pacman.conf
# Network failures are tried again (pacman-retry); /usr/local/bin is ahead of /usr/bin.
COPY pacman-retry /usr/local/bin/pacman
RUN pacman-key --init && pacman-key --populate archlinuxarm \
 && pacman -Syu --noconfirm --needed base-devel git \
 && pacman -Scc --noconfirm
EOF
