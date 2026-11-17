#!/bin/bash
# Self-check for promote.sh: publish to [kriss-testing], promote, and check [kriss] gets
# the same files, split packages move together, and a tampered package stops it.
# Needs pacman (repo-add, vercmp), gpg and bsdtar (any Arch container).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FAKE_GH_ROOT=$tmp/releases GNUPGHOME=$tmp/gnupg
mkdir -m700 "$GNUPGHOME"
mkdir "$FAKE_GH_ROOT" "$tmp/bin" "$tmp/run1" "$tmp/run2"
ln -s "$here/fake-gh" "$tmp/bin/gh"
PATH=$tmp/bin:$PATH

gpg --batch --quiet --passphrase '' --quick-gen-key 'promote-test <test@example.invalid>' ed25519 sign never
KRISS_GPG_KEY=$(gpg --armor --export-secret-keys)
export KRISS_GPG_KEY

mkpkg() { # name version destdir [pkgbase]
  printf 'pkgname = %s\npkgbase = %s\npkgver = %s\npkgdesc = x\nurl = x\nbuilddate = 1\npackager = x\nsize = 1\narch = any\n' \
    "$1" "${4:-$1}" "$2" >"$tmp/.PKGINFO"
  bsdtar -C "$tmp" --zstd -cf "$3/$1-$2-any.pkg.tar.zst" .PKGINFO
}
names() { bsdtar -tf "$FAKE_GH_ROOT/$1/$2.db" | grep /desc | cut -d/ -f1 | sort | paste -sd' '; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# Nothing published yet: nothing to do, no error.
"$here/promote.sh" >/dev/null

mkpkg a 1.0-1 "$tmp/run1"
mkpkg k 6.1-1 "$tmp/run1" k
mkpkg k-headers 6.1-1 "$tmp/run1" k
"$here/publish.sh" "$tmp/run1" >/dev/null

# A dry run changes nothing.
DRY_RUN=1 "$here/promote.sh" >/dev/null
[ ! -e "$FAKE_GH_ROOT/repo-x86_64" ] || fail "dry run published"

# First promotion: everything, byte for byte.
"$here/promote.sh" >/dev/null
[ "$(names repo-x86_64 kriss)" = 'a-1.0-1 k-6.1-1 k-headers-6.1-1' ] || fail "stable has $(names repo-x86_64 kriss)"
cmp "$FAKE_GH_ROOT"/{testing,repo}-x86_64/a-1.0-1-any.pkg.tar.zst || fail "promoted file differs"
gpg --quiet --verify "$FAKE_GH_ROOT/repo-x86_64/kriss.db.sig" "$FAKE_GH_ROOT/repo-x86_64/kriss.db" 2>/dev/null

# New versions in testing; promote only the kernel by one of its names.
mkpkg a 1.1-1 "$tmp/run2"
mkpkg k 6.2-1 "$tmp/run2" k
mkpkg k-headers 6.2-1 "$tmp/run2" k
"$here/publish.sh" "$tmp/run2" >/dev/null
"$here/promote.sh" k-headers >/dev/null
[ "$(names repo-x86_64 kriss)" = 'a-1.0-1 k-6.2-1 k-headers-6.2-1' ] || fail "after k: $(names repo-x86_64 kriss)"
[ "$(names testing-x86_64 kriss-testing)" = 'a-1.1-1 k-6.2-1 k-headers-6.2-1' ] || fail "testing changed"

# Unknown names are an error; promoting again is a no-op.
if "$here/promote.sh" nope 2>/dev/null; then fail "unknown package accepted"; fi
"$here/promote.sh" k >/dev/null

# A package that does not match its signature is never promoted.
printf x >>"$FAKE_GH_ROOT/testing-x86_64/a-1.1-1-any.pkg.tar.zst"
if "$here/promote.sh" a 2>/dev/null; then fail "tampered package promoted"; fi
[ "$(names repo-x86_64 kriss)" = 'a-1.0-1 k-6.2-1 k-headers-6.2-1' ] || fail "stable changed after a failed promote"
echo "promote.sh self-check passed"
