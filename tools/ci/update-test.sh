#!/bin/bash
# Checks kriss update's pacman steps: keyrings first, then one retry, with a fake pacman.
# shellcheck disable=SC2329 # the fakes are called by the kriss functions under test
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
# replace_from_kriss: [kriss] packages whose replaces= names an installed package.
slq() { echo cosmic-settings-kriss; echo kriss-tools; echo cosmic-comp-kriss; }
pacman() {
  case $1 in
    -Slq) [[ $2 == kriss ]] && slq ;;
    -Si) printf 'Name            : cosmic-settings-kriss\nReplaces        : cosmic-settings\n\n'
         printf 'Name            : kriss-tools\nReplaces        : None\n\n'
         printf 'Name            : cosmic-comp-kriss\nReplaces        : cosmic-comp<2  old-comp\n\n' ;;
    -Q) [[ " $installed " == *" $2 "* ]] ;;
    *) echo "$*" >>"$log" ;;
  esac
}
swap() { : >"$log"; replace_from_kriss >/dev/null; cat "$log"; }
installed='cosmic-settings cosmic-comp kriss-tools'
[[ $(swap) == '-S --noconfirm --ask 4 -- cosmic-comp-kriss cosmic-settings-kriss' ]] || fail "swap: $(swap)"
installed='cosmic-settings-kriss cosmic-comp-kriss'
[[ -z $(swap) ]] || fail "nothing to swap once replaced: $(swap)"
installed='old-comp cosmic-settings-kriss'
[[ $(swap) == '-S --noconfirm --ask 4 -- cosmic-comp-kriss' ]] || fail "second replaces name: $(swap)"
slq() { :; }
[[ -z $(swap) ]] || fail "no [kriss] repo: $(swap)"
echo "update-test: ok"
