#!/bin/bash
# Self-check for publish.sh: two publishes to [kriss-testing] against a directory standing
# in for the GitHub release, and one to [kriss] that must leave testing alone.
# Needs pacman's repo-add, gpg and bsdtar (any Arch container).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FAKE_GH_ROOT=$tmp/releases GNUPGHOME=$tmp/gnupg
mkdir -m700 "$GNUPGHOME"
mkdir "$FAKE_GH_ROOT" "$tmp/bin" "$tmp/run1" "$tmp/run2" "$tmp/run3"
ln -s "$here/fake-gh" "$tmp/bin/gh"
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
mkpkg c 1.0-1 "$tmp/run3"

# The default channel is testing.
"$here/publish.sh" "$tmp/run1" >/dev/null
"$here/publish.sh" "$tmp/run2" >/dev/null
CHANNEL=stable "$here/publish.sh" "$tmp/run3" >/dev/null

# The second run must keep b, replace a, and leave a signed db.
rel=$FAKE_GH_ROOT/testing-x86_64
want='a-1.1-1-any.pkg.tar.zst a-1.1-1-any.pkg.tar.zst.sig b-1.0-1-any.pkg.tar.zst b-1.0-1-any.pkg.tar.zst.sig kriss-testing.db kriss-testing.db.sig kriss-testing.db.tar.zst kriss-testing.db.tar.zst.sig kriss-testing.files kriss-testing.files.sig kriss-testing.files.tar.zst kriss-testing.files.tar.zst.sig'
got=$(cd "$rel" && echo *)
[ "$got" = "$want" ] || { echo "testing release has: $got" >&2; exit 1; }
[ "$(bsdtar -tf "$rel/kriss-testing.db" | grep -c /desc)" = 2 ]
gpg --quiet --verify "$rel/kriss-testing.db.sig" "$rel/kriss-testing.db" 2>/dev/null

# The stable publish went to its own release and db.
got=$(cd "$FAKE_GH_ROOT" && echo *)
[ "$got" = 'repo-x86_64 testing-x86_64' ] || { echo "releases: $got" >&2; exit 1; }
[ "$(bsdtar -tf "$FAKE_GH_ROOT/repo-x86_64/kriss.db" | grep /desc)" = c-1.0-1/desc ]

if CHANNEL=beta "$here/publish.sh" "$tmp/run3" 2>/dev/null; then echo 'unknown channel accepted' >&2; exit 1; fi
echo "publish.sh self-check passed"
