#!/bin/bash
# Checks kriss channel: testing adds [kriss-testing] right above [kriss], stable takes it out
# again (the file comes back byte for byte) and downgrades through pacman -Syuu.
# Runs as root (CI's Arch container), against a fixture pacman.conf and stub pacman.
set -euo pipefail
kriss=$(realpath "$(dirname "$0")/../kriss")
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir "$t/etc" "$t/bin"
printf '#!/bin/sh\necho "pacman $*" >> "%s/log"\n' "$t" >"$t/bin/pacman"
chmod +x "$t/bin/pacman"
export KRISS_ETC=$t/etc PATH=$t/bin:$PATH
fail() { echo "FAIL: $*" >&2; exit 1; }

cat >"$t/etc/pacman.conf" <<'CONF'
[options]
SigLevel    = Required DatabaseOptional

[core]
Include = /etc/pacman.d/mirrorlist

# The key ships in kriss-keyring.
[kriss]
SigLevel = Required
Server = https://github.com/krazetech/krissos/releases/download/repo-x86_64

[multilib]
Include = /etc/pacman.d/mirrorlist
CONF
cp "$t/etc/pacman.conf" "$t/orig"

[ "$("$kriss" channel)" = stable ] || fail "fresh install is not on stable"
"$kriss" channel stable | grep -q 'already on stable' || fail "stable to stable"

"$kriss" channel testing >/dev/null
[ "$("$kriss" channel)" = testing ] || fail "not on testing after switching"
# [kriss-testing] must come before [kriss] so its newer packages win.
order=$(grep '^\[' "$t/etc/pacman.conf" | paste -sd' ')
[ "$order" = '[options] [core] [kriss-testing] [kriss] [multilib]' ] || fail "repo order: $order"
# shellcheck disable=SC2016 # pacman expands $arch
grep -qxF 'Server = https://github.com/krazetech/krissos/releases/download/testing-$arch' "$t/etc/pacman.conf" \
  || fail "testing server line"
[ ! -e "$t/log" ] || fail "switching to testing ran pacman"

"$kriss" channel stable >/dev/null
cmp -s "$t/orig" "$t/etc/pacman.conf" || { diff "$t/orig" "$t/etc/pacman.conf"; fail "stable did not restore pacman.conf"; }
[ "$(cat "$t/log")" = 'pacman -Syuu' ] || fail "stable ran: $(cat "$t/log")"

if "$kriss" channel beta 2>/dev/null; then fail "unknown channel accepted"; fi
grep -v '^\[kriss\]' "$t/orig" >"$t/etc/pacman.conf"
if "$kriss" channel testing 2>/dev/null; then fail "switched without a [kriss] repo"; fi
echo 'channel: ok'
