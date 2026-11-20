#!/bin/bash
# Checks kriss reset on a fixture tree: which apps go, what happens to each home, the marker.
set -euo pipefail
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export KRISS_ETC=$t/etc KRISS_PROC=$t/proc KRISS_HOMES=$t/home \
  KRISS_RESET_PENDING=$t/pending KRISS_INSTALL_LIST=$t/install-packages
# shellcheck source=/dev/null # tools/kriss is linted on its own
. "$(dirname "$0")/../kriss"

fail() { echo "FAIL: $*"; exit 1; }
log=$t/log
pacman() {
  case $1 in
    -Qqe) printf '%s\n' base firefox steam cosmic-settings-kriss linux-kriss nvidia-580xx-utils gimp ;;
    -Slq) echo cosmic-settings-kriss ;;
    *) echo "pacman $*" >>"$log" ;;
  esac
}
has_snapper() { false; }
install() { mkdir -p "${@: -1}"; }
chown() { :; }
id() { echo users; }
command() { [[ $2 != flatpak ]] && builtin command "$@"; }

mkdir -p "$t/etc/skel" "$t/proc" "$t/etc/NetworkManager/system-connections"
echo 'quiet' >"$t/proc/cmdline"
printf 'root:x:0:0::/root:/bin/bash\nana:x:1000:1000::%s/ana:/bin/bash\n' "$t/home" >"$t/etc/passwd"
echo '# skel' >"$t/etc/skel/.bashrc"
printf '%s\n' base firefox cosmic-settings linux-kriss >"$t/install-packages"
home() {
  rm -rf "${t:?}/home"; mkdir -p "$t/home/ana/Documents" "$t/home/ana/.config/app" "$t/home/ana/.ssh"
  touch "$t/home/ana/Documents/cv.odt" "$t/home/ana/.bashrc" "$t/home/ana/.config/app/x"
  touch "$t/etc/NetworkManager/system-connections/Home.nmconnection"
}

[[ $(reset_added_apps | paste -sd' ' -) == 'gimp steam' ]] || fail "added apps: $(reset_added_apps)"
plan=$(reset_plan keep-files)
[[ $plan == *"Removes 2 app(s) added since KrissOS was installed: gimp steam"* ]] || fail "plan: $plan"
[[ $plan == *"cannot be undone"* ]] || fail "no snapper should say it cannot be undone"
mv "$t/install-packages" "$t/list"
[[ $(reset_plan keep-files) == *"Keeps installed apps"* ]] || fail "without the installer's list, apps stay"
mv "$t/list" "$t/install-packages"

home; : >"$log"
echo 'keep-files 20261121-1000' >"$t/pending"
reset_finish >/dev/null
[[ ! -e $t/pending ]] || fail "the marker should be gone"
[[ $(<"$log") == 'pacman -Rns --noconfirm gimp steam' ]] || fail "removal: $(<"$log")"
old=$t/home/ana/old-settings-20261121-1000
[[ -f $t/home/ana/Documents/cv.odt && -d $t/home/ana/.ssh ]] || fail "files and keys stay"
[[ -f $old/.config/app/x && -f $old/.bashrc && ! -e $t/home/ana/.config ]] || fail "settings move aside"
[[ $(<"$t/home/ana/.bashrc") == '# skel' ]] || fail "a fresh .bashrc from skel"
[[ -f $t/etc/NetworkManager/system-connections/Home.nmconnection ]] || fail "keep-files keeps Wi-Fi"

home
echo 'everything 20261121-1000' >"$t/pending"
reset_finish >/dev/null
[[ $(find "$t/home/ana" -mindepth 1 | sed "s|$t/home/ana/||") == .bashrc ]] || fail "everything empties the home"
[[ -z $(ls "$t/etc/NetworkManager/system-connections") ]] || fail "everything forgets Wi-Fi"

home
echo 'everything 1' >"$t/pending"
echo 'quiet kriss_snapshot=1' >"$t/proc/cmdline"
reset_finish >/dev/null
[[ -f $t/pending && -f $t/home/ana/Documents/cv.odt ]] || fail "nothing happens in a snapshot"
echo "reset-test: ok"
