#!/bin/bash
# Prints the CHANGELOG.md section for a release tag, for use as the GitHub release notes.
# Fails when the section is missing or empty, so a tag can't ship without notes.
#   tools/ci/release-notes.sh 110 [CHANGELOG.md]
set -euo pipefail

tag=${1:?usage: release-notes.sh <tag> [changelog]}
file=${2:-$(cd "$(dirname "$0")/../.." && pwd)/CHANGELOG.md}

notes=$(awk -v want="## $tag" '
  $0 == want { on = 1; next }
  on && /^## / { exit }
  on { print }
' "$file" | sed -e '/./,$!d')   # drop leading blank lines

if [ -z "${notes//[[:space:]]/}" ]; then
  echo "::error::CHANGELOG.md has no '## $tag' section. Rename 'Unreleased' to '$tag' before tagging." >&2
  exit 1
fi
printf '%s\n' "$notes"
