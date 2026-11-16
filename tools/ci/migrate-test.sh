#!/bin/bash
# Checks kriss migrate's detection and rewrites on fixtures shaped like a CachyOS install.
set -euo pipefail
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
# shellcheck source=/dev/null # tools/kriss-migrate is linted on its own
. "$(dirname "$0")/../kriss-migrate"

fail() { echo "FAIL: $*"; exit 1; }

# Which systems it takes.
osr() { printf '%s\n' "$@" >"$t/os-release"; }
osr ID=arch; arch_based "$t/os-release" || fail "Arch refused"
osr ID=cachyos ID_LIKE=arch; arch_based "$t/os-release" || fail "CachyOS refused"
osr ID=endeavouros 'ID_LIKE="arch"'; arch_based "$t/os-release" || fail "EndeavourOS refused"
osr ID=krissos ID_LIKE=arch; arch_based "$t/os-release" || fail "a second run on KrissOS refused"
osr ID=manjaro ID_LIKE=arch; ! arch_based "$t/os-release" || fail "Manjaro taken"
osr ID=fedora; ! arch_based "$t/os-release" || fail "Fedora taken"

# The CachyOS repos go; [claude], commented repos, comments and Arch's repos stay.
cat >"$t/pacman.conf" <<'EOF'
[options]
SigLevel    = Required DatabaseOptional

#<disabled_v3>[cachyos-core-v3]
#<disabled_v3>Include = /etc/pacman.d/cachyos-v3-mirrorlist

[claude]
SigLevel = Optional TrustAll
Server = file:///srv/pkgrepo/claude

[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

# The testing repositories are disabled by default.
#[core-testing]
#Include = /etc/pacman.d/mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

Include = /etc/pacman.d/vibepollo.conf
EOF
out=$(strip_cachyos "$t/pacman.conf")
! grep -q '^\[cachyos\|cachyos-v3-mirrorlist $\|^Include = /etc/pacman.d/cachyos-mirrorlist' <<<"$out" || fail "a CachyOS repo is left: $out"
for keep in '[claude]' 'Server = file:///srv/pkgrepo/claude' '#<disabled_v3>[cachyos-core-v3]' \
  '#[core-testing]' '[core]' 'Include = /etc/pacman.d/mirrorlist' 'Include = /etc/pacman.d/vibepollo.conf'; do
  grep -qxF "$keep" <<<"$out" || fail "lost '$keep'"
done

# CachyOS's system pieces go; its app builds and everything else stay.
for p in cachyos-settings cachyos-hello chwd cachy-update limine-mkinitcpio-hook limine-snapper-sync; do
  infra_pkg "$p" || fail "$p should be removed"
done
for p in limine snapper heroic-games-launcher firefox-wayland-cachy-hg proton-cachyos-slr linux-cachyos; do
  ! infra_pkg "$p" || fail "$p should stay (kernels go in their own step)"
done

# Kernel command lines.
cl='BOOT_IMAGE=/vmlinuz quiet nowatchdog splash amdgpu.ppfeaturemask=0xffffffff rw rootflags=subvol=/@ root=UUID=1553924a'
[[ $(boot_cmdline "$cl") == 'quiet nowatchdog splash amdgpu.ppfeaturemask=0xffffffff rw rootflags=subvol=@ root=UUID=1553924a zswap.enabled=0' ]] ||
  fail "cmdline: $(boot_cmdline "$cl")"
[[ $(boot_cmdline 'root=UUID=x rootflags=subvol=@,compress=zstd zswap.enabled=1') == 'root=UUID=x rootflags=subvol=@,compress=zstd zswap.enabled=1 splash' ]] ||
  fail "cmdline kept: $(boot_cmdline 'root=UUID=x rootflags=subvol=@,compress=zstd zswap.enabled=1')"
[[ $(fallback_cmdline "$cl") == 'quiet nowatchdog splash amdgpu.ppfeaturemask=0xffffffff rw rootflags=subvol=/@before-kriss-migrate root=UUID=1553924a' ]] ||
  fail "fallback cmdline: $(fallback_cmdline "$cl")"
[[ $(fallback_cmdline 'rootflags=subvol=@,ssd') == 'rootflags=subvol=/@before-kriss-migrate,ssd' ]] || fail "fallback with options"

# fstab: the / line becomes the /.snapshots line, and the old system's points at its copy.
root='UUID=1553 /              btrfs   subvol=/@,defaults,noatime,compress=zstd:1 0 0'
[[ $(fstab_as "$root" @snapshots /.snapshots) == 'UUID=1553 /.snapshots              btrfs   subvol=/@snapshots,defaults,noatime,compress=zstd:1 0 0' ]] ||
  fail "fstab: $(fstab_as "$root" @snapshots /.snapshots)"
[[ $(fstab_as 'UUID=1 / btrfs rw,subvolid=256,subvol=/@ 0 0' @snapshots /.snapshots) == 'UUID=1 /.snapshots btrfs rw,subvol=/@snapshots 0 0' ]] ||
  fail "fstab subvolid: $(fstab_as 'UUID=1 / btrfs rw,subvolid=256,subvol=/@ 0 0' @snapshots /.snapshots)"
[[ $(fstab_as 'UUID=1 /home btrfs subvol=/@home 0 0' @snapshots /.snapshots) == 'UUID=1 /home btrfs subvol=/@home 0 0' ]] ||
  fail "fstab touched /home"

# Initramfs hooks.
[[ $(hooks_line 0 0) == 'HOOKS=(base udev autodetect microcode modconf kriss-kms plymouth keyboard keymap consolefont block filesystems fsck kriss-snapshot)' ]] ||
  fail "hooks: $(hooks_line 0 0)"
[[ $(hooks_line 1 1) == 'HOOKS=(base udev autodetect microcode modconf plymouth keyboard keymap consolefont block btrfs filesystems fsck kriss-snapshot)' ]] ||
  fail "hooks multi-device NVIDIA: $(hooks_line 1 1)"

# Shell configs that still load CachyOS's removed shell config packages.
printf '%s\n' 'source /usr/share/cachyos-fish-config/cachyos-config.fish' 'set -x EDITOR nano' >"$t/config.fish"
printf '%s\n' '# source /usr/share/cachyos-zsh-config/cachyos-config.zsh' 'alias ls=eza' >"$t/zshrc"
[[ $(stale_shell_refs "$t/config.fish" "$t/zshrc" "$t/missing") == "$t/config.fish:1:source /usr/share/cachyos-fish-config/cachyos-config.fish" ]] ||
  fail "shell refs: $(stale_shell_refs "$t/config.fish" "$t/zshrc" "$t/missing")"

echo "migrate-test: ok"
