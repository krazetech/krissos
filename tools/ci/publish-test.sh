#!/bin/bash
# Self-check for publish.sh: two publishes against a directory standing in for the
# GitHub release. Needs pacman's repo-add, gpg and bsdtar (any Arch container).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export REL=$tmp/release GNUPGHOME=$tmp/gnupg
mkdir -m700 "$GNUPGHOME"
mkdir "$REL" "$tmp/bin" "$tmp/run1" "$tmp/run2"

cat >"$tmp/bin/gh" <<'STUB'
#!/bin/bash
[ "$1" = release ] || exit 2
cmd=$2
shift 3
case $cmd in
  view) if [ "${1:-}" = --json ]; then ls "$REL"; fi ;;
  download)
    while [ $# -gt 0 ]; do
      if [ "$1" = -p ]; then cp "$REL/$2" . || exit 1; shift; fi
      shift
    done ;;
  upload) for f; do [ "$f" = --clobber ] || cp "$f" "$REL/"; done ;;
  delete-asset) rm "$REL/$1" ;;
esac
STUB
chmod +x "$tmp/bin/gh"
PATH=$tmp/bin:$PATH

gpg --batch --quiet --passphrase '' --quick-gen-key 'publish-test <test@example.invalid>' ed25519 sign never
KRISS_GPG_KEY=$(gpg --armor --export-secret-keys)
export KRISS_GPG_KEY

mkpkg() { # name version destdir
  printf 'pkgname = %s\npkgver = %s\npkgdesc = x\nurl = x\nbuilddate = 1\npackager = x\nsize = 1\narch = any\n' \
    "$1" "$2" >"$tmp/.PKGINFO"
  bsdtar -C "$tmp" --zstd -cf "$3/$1-$2-any.pkg.tar.zst" .PKGINFO
}
mkpkg a 1.0-1 "$tmp/run1"
mkpkg b 1.0-1 "$tmp/run1"
mkpkg a 1.1-1 "$tmp/run2"

"$here/publish.sh" "$tmp/run1" >/dev/null
"$here/publish.sh" "$tmp/run2" >/dev/null

# The second run must keep b, replace a, and leave a signed db.
want='a-1.1-1-any.pkg.tar.zst a-1.1-1-any.pkg.tar.zst.sig b-1.0-1-any.pkg.tar.zst b-1.0-1-any.pkg.tar.zst.sig kriss.db kriss.db.sig kriss.db.tar.zst kriss.db.tar.zst.sig kriss.files kriss.files.sig kriss.files.tar.zst kriss.files.tar.zst.sig'
got=$(cd "$REL" && echo *)
[ "$got" = "$want" ] || { echo "release has: $got" >&2; exit 1; }
[ "$(bsdtar -tf "$REL/kriss.db" | grep -c /desc)" = 2 ]
gpg --quiet --verify "$REL/kriss.db.sig" "$REL/kriss.db" 2>/dev/null
echo "publish.sh self-check passed"
