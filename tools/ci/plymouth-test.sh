#!/bin/bash
# Checks which Theme= lines kriss-plymouth replaces with kriss, and that the rest of
# plymouthd.conf stays as it was.
set -euo pipefail
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
script=$(dirname "$0")/../../pkgs/kriss-settings/root/usr/share/libalpm/scripts/kriss-plymouth
fail() { echo "FAIL: $*"; exit 1; }
mkdir -p "$t/etc/plymouth"
for th in kriss spinner bgrt; do
  mkdir -p "$t/usr/share/plymouth/themes/$th"
  touch "$t/usr/share/plymouth/themes/$th/$th.plymouth"
done
run() { printf '%s' "$1" >"$t/etc/plymouth/plymouthd.conf"; KRISS_ROOT=$t sh "$script" >/dev/null; cat "$t/etc/plymouth/plymouthd.conf"; }
expect() { [[ $(run "$1") == "$2" ]] || fail "$3: $(run "$1")"; }

# A migrated CachyOS: the theme went with CachyOS's packages. Other settings stay.
expect $'[Daemon]\nTheme=cachyos\nShowDelay=2\n' $'[Daemon]\nTheme=kriss\nShowDelay=2' 'cachyos'
# Arch's stock file: everything commented out.
expect $'# Administrator customizations go in this file\n#[Daemon]\n#Theme=fade-in\n' \
  $'# Administrator customizations go in this file\n#[Daemon]\n#Theme=fade-in\n[Daemon]\nTheme=kriss' 'stock'
expect $'[Daemon]\nDeviceTimeout=8\n' $'[Daemon]\nTheme=kriss\nDeviceTimeout=8' 'no Theme line'
expect $'[Daemon]\nTheme = gone\n' $'[Daemon]\nTheme=kriss' 'missing theme'
expect $'[Daemon]\nTheme=arch-glow\n' $'[Daemon]\nTheme=kriss' 'another distro'
# The admin's choice of an installed theme stays, and kriss stays kriss.
expect $'[Daemon]\nTheme=spinner\n' $'[Daemon]\nTheme=spinner' 'spinner kept'
expect $'[Daemon]\nTheme=bgrt\n' $'[Daemon]\nTheme=bgrt' 'explicit bgrt kept'
expect $'[Daemon]\nTheme=kriss\n' $'[Daemon]\nTheme=kriss' 'kriss'
rm "$t/etc/plymouth/plymouthd.conf"
KRISS_ROOT=$t sh "$script" >/dev/null
[[ $(cat "$t/etc/plymouth/plymouthd.conf") == $'[Daemon]\nTheme=kriss' ]] || fail "no file"
files=("$t"/etc/plymouth/*)
((${#files[@]} == 1)) || fail "stray files: ${files[*]}"
echo "plymouth-test: ok"
