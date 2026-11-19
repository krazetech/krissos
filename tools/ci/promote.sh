#!/bin/bash
# Promote packages from [kriss-testing] to [kriss]: the exact files that were tested,
# signatures checked, never rebuilt.
# usage: promote.sh [PKGNAME...]
#   With no names, every package whose [kriss-testing] version is newer than [kriss].
#   A name brings the rest of its split package along (linux-kriss and its headers).
# env: KRISS_GPG_KEY (armored secret key), GH_TOKEN, ARCH (x86_64, the default, or aarch64),
#      DRY_RUN=1 to list what would move and stop.
#
# Run in the repo-ARCH concurrency group, like every other writer to [kriss].
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
arch=${ARCH:-x86_64}
testing=testing-$arch

if [ -z "${KRISS_GPG_KEY:-}" ]; then
  echo "::error::KRISS_GPG_KEY is not set; nothing was promoted." >&2
  exit 1
fi
printf '%s\n' "$KRISS_GPG_KEY" | gpg --batch --quiet --import

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work"/{testing,stable,pkgs}

# fetch TAG NAME DIR: the repo db, verified, unpacked into DIR. Fails when there is none.
fetch() {
  (cd "$work" && gh release download "$1" --clobber -p "$2.db" -p "$2.db.sig") || return 1
  gpg --batch --quiet --verify "$work/$2.db.sig" "$work/$2.db" 2>/dev/null \
    || { echo "::error::$2.db on $1 has a bad signature." >&2; exit 1; }
  bsdtar -xf "$work/$2.db" -C "$3" || exit 1
}
# Lines of NAME BASE VERSION FILENAME, one per package in an unpacked db.
list() {
  local d
  for d in "$1"/*/; do
    [ -f "$d/desc" ] || continue
    awk 'p == "%NAME%" {n = $0} p == "%BASE%" {b = $0} p == "%VERSION%" {v = $0}
         p == "%FILENAME%" {f = $0} {p = $0} END {print n, (b ? b : n), v, f}' "$d/desc"
  done
}

fetch "$testing" kriss-testing "$work/testing" \
  || { echo "There is no [kriss-testing] for $arch yet; nothing to promote."; exit 0; }
# On the very first promotion there is no [kriss] either.
fetch "repo-$arch" kriss "$work/stable" || true
list "$work/testing" >"$work/testing.list"
list "$work/stable" >"$work/stable.list"

stable_ver() { awk -v n="$1" '$1 == n {print $3}' "$work/stable.list"; }
newer() { # NAME TESTING_VERSION: true when it is not in [kriss] or is older there
  local s
  s=$(stable_ver "$1")
  [ -z "$s" ] || [ "$(vercmp "$2" "$s")" -gt 0 ]
}

# Which pkgbases move: the named ones (a package name or a base), or all that changed.
bases=()
if [ $# -eq 0 ]; then
  mapfile -t bases < <(while read -r n b v _; do newer "$n" "$v" && echo "$b"; done <"$work/testing.list" | sort -u)
else
  for want; do
    b=$(awk -v w="$want" '$1 == w || $2 == w {print $2; exit}' "$work/testing.list")
    [ -n "$b" ] || { echo "::error::$want is not in [kriss-testing] for $arch." >&2; exit 1; }
    bases+=("$b")
  done
fi

moves=()
summary="| Package | [kriss] now | Promoted |"$'\n'"|---|---|---|"
while read -r n b v f; do
  printf '%s\n' "${bases[@]}" | grep -qxF "$b" || continue
  if newer "$n" "$v"; then
    moves+=("$f")
    summary+=$'\n'"| $n | $(stable_ver "$n" | grep . || echo '(new)') | $v |"
  else
    echo "$n $v is already in [kriss]."
  fi
done <"$work/testing.list"

if [ ${#moves[@]} -eq 0 ]; then
  echo "Nothing to promote for $arch: [kriss] already has what [kriss-testing] has."
  exit 0
fi
echo "Promoting to [kriss] ($arch):"
printf '  %s\n' "${moves[@]}"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '### %s%s\n\n%s\n' "$arch" "${DRY_RUN:+ (dry run)}" "$summary" >>"$GITHUB_STEP_SUMMARY"
fi
[ -z "${DRY_RUN:-}" ] || exit 0

cd "$work/pkgs"
for f in "${moves[@]}"; do
  gh release download "$testing" --clobber -p "$f" -p "$f.sig"
  gpg --batch --quiet --verify "$f.sig" "$f" 2>/dev/null \
    || { echo "::error::$f on $testing has a bad signature; nothing was promoted." >&2; exit 1; }
done
CHANNEL=stable ARCH=$arch "$here/publish.sh" "$work/pkgs"
