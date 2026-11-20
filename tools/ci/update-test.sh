#!/bin/bash
# Checks kriss update's pacman steps: keyrings first, then one retry, with a fake pacman.
set -euo pipefail
# shellcheck source=/dev/null # tools/kriss is linted on its own
. "$(dirname "$0")/../kriss"

fail() { echo "FAIL: $*"; exit 1; }
log=$(mktemp)
trap 'rm -f "$log"' EXIT
installed='archlinux-keyring kriss-keyring'
syu_fails=0 # how many -Syu runs fail before one works
pacman() {
  case $1 in
    -Q) [[ " $installed " == *" $2 "* ]] ;;
    -Syu) echo "$*" >>"$log"; ((syu_fails-- <= 0)) ;;
    *) echo "$*" >>"$log" ;;
  esac
}
die() { echo "die: $*" >>"$log"; return 1; }
run() { : >"$log"; update_system || true; cat "$log"; }

want=$'-Sy --noconfirm --needed archlinux-keyring kriss-keyring\n-Syu --noconfirm'
[[ $(run) == "$want" ]] || fail "plain update: $(run)"

syu_fails=1
want=$'-Sy --noconfirm --needed archlinux-keyring kriss-keyring\n-Syu --noconfirm\n-Syu --noconfirm'
[[ $(run) == "$want" ]] || fail "a failed -Syu is tried once more"

syu_fails=2
[[ $(run) == *"die: the update did not finish"* ]] || fail "two failures should stop with a message"

syu_fails=0 installed='archlinux-keyring'
[[ $(run) == $'-Sy --noconfirm --needed archlinux-keyring\n-Syu --noconfirm' ]] ||
  fail "only installed keyrings are refreshed: $(run)"

installed=''
[[ $(run) == '-Syu --noconfirm' ]] || fail "no keyrings installed: $(run)"
echo "update-test: ok"
