#!/bin/bash
# Merge freshly built packages into the published [kriss] repo (a GitHub release).
# usage: publish.sh <dir with *.pkg.tar.zst>
# env: KRISS_GPG_KEY (armored secret key), GH_TOKEN, RELEASE_TAG (default repo-x86_64)
#
# Callers must share one workflow concurrency group: two overlapping runs would each
# download the same db and the second upload would drop the first run's packages.
set -euo pipefail

tag=${RELEASE_TAG:-repo-x86_64}
db=kriss.db.tar.zst
files=kriss.files.tar.zst

if [ -z "${KRISS_GPG_KEY:-}" ]; then
  echo "::warning::KRISS_GPG_KEY is not set; packages were built but not published."
  exit 0
fi
printf '%s\n' "$KRISS_GPG_KEY" | gpg --batch --import

cd "$1"
gh release view "$tag" >/dev/null 2>&1 \
  || gh release create "$tag" --title 'KrissOS package repo (x86_64)' \
       --notes 'Signed [kriss] pacman repository. Updated by CI.' --latest=false

# Start from the published db. On the very first publish there is none.
verify=()
if gh release download "$tag" --clobber -p "$db" -p "$db.sig" -p "$files" -p "$files.sig"; then
  verify=(--verify)
fi

for pkg in *.pkg.tar.zst; do
  gpg --batch --yes --detach-sign "$pkg"
done
repo-add "${verify[@]}" --sign "$db" ./*.pkg.tar.zst

# Release assets cannot be symlinks; pacman fetches kriss.db and kriss.files.
for f in kriss.db kriss.files; do
  cp --remove-destination "$f.tar.zst" "$f"
  cp --remove-destination "$f.tar.zst.sig" "$f.sig"
done

# Packages first, then the db, then delete what the db no longer references, so a
# client syncing mid-publish never sees a db entry without its package.
gh release upload "$tag" --clobber ./*.pkg.tar.zst ./*.pkg.tar.zst.sig
gh release upload "$tag" --clobber kriss.{db,files}{,.sig,.tar.zst,.tar.zst.sig}

keep=$(bsdtar -xOf "$db" '*/desc' | grep -A1 '^%FILENAME%$' | grep '\.pkg\.tar\.')
gh release view "$tag" --json assets --jq '.assets[].name' | grep '\.pkg\.tar\.' \
  | while read -r asset; do
      grep -qxF "${asset%.sig}" <<<"$keep" || gh release delete-asset "$tag" "$asset" --yes </dev/null
    done
