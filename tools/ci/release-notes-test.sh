#!/bin/bash
# Self-check for release-notes.sh.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/CHANGELOG.md" <<'MD'
# Changelog

## Unreleased

## 110

### Added

- One thing.

## 110-rc1

- Older thing.
MD

out=$("$here/release-notes.sh" 110 "$tmp/CHANGELOG.md")
[ "$out" = $'### Added\n\n- One thing.' ] \
  || { echo "FAIL: wrong section for 110:"; printf '%s\n' "$out"; exit 1; }
[ "$("$here/release-notes.sh" 110-rc1 "$tmp/CHANGELOG.md")" = '- Older thing.' ] \
  || { echo 'FAIL: wrong section for 110-rc1'; exit 1; }
if "$here/release-notes.sh" Unreleased "$tmp/CHANGELOG.md" 2>/dev/null; then
  echo 'FAIL: an empty section passed'; exit 1
fi
if "$here/release-notes.sh" 115 "$tmp/CHANGELOG.md" 2>/dev/null; then
  echo 'FAIL: a missing section passed'; exit 1
fi
"$here/release-notes.sh" 0.1-alpha >/dev/null || { echo 'FAIL: the real CHANGELOG.md lacks 0.1-alpha'; exit 1; }
echo 'release-notes: ok'
