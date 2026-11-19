#!/bin/bash
# Merge packages into a published pacman repo (a GitHub release).
# usage: publish.sh <dir with *.pkg.tar.zst>
# env: KRISS_GPG_KEY (armored secret key), GH_TOKEN,
#      CHANNEL  testing (the default): [kriss-testing] on the testing-ARCH release.
#               Every merge to main lands here.
#               stable: [kriss] on the repo-ARCH release. Only promote.sh publishes here.
#      ARCH     x86_64 (the default) or aarch64
#
# Callers must share one workflow concurrency group per repo (testing-ARCH or repo-ARCH):
# two overlapping runs would each download the same db and the second upload would drop
# the first run's packages.
set -euo pipefail

arch=${ARCH:-x86_64}
case ${CHANNEL:-testing} in
  testing) tag=testing-$arch name=kriss-testing ;;
  stable) tag=repo-$arch name=kriss ;;
  *) echo "publish.sh: CHANNEL must be testing or stable, not '$CHANNEL'" >&2; exit 2 ;;
esac
db=$name.db.tar.zst
files=$name.files.tar.zst

if [ -z "${KRISS_GPG_KEY:-}" ]; then
  echo "::warning::KRISS_GPG_KEY is not set; packages were built but not published."
  exit 0
fi
printf '%s\n' "$KRISS_GPG_KEY" | gpg --batch --import

cd "$1"
gh release view "$tag" >/dev/null 2>&1 \
  || gh release create "$tag" --title "KrissOS package repo [$name] ($arch)" \
       --notes "Signed [$name] pacman repository. Updated by CI." --latest=false

# Start from the published db. On the very first publish there is none.
verify=()
if gh release download "$tag" --clobber -p "$db" -p "$db.sig" -p "$files" -p "$files.sig"; then
  verify=(--verify)
fi

for pkg in *.pkg.tar.zst; do
  gpg --batch --yes --detach-sign "$pkg"
done
repo-add "${verify[@]}" --sign "$db" ./*.pkg.tar.zst

# Release assets cannot be symlinks; pacman fetches NAME.db and NAME.files.
for f in "$name.db" "$name.files"; do
  cp --remove-destination "$f.tar.zst" "$f"
  cp --remove-destination "$f.tar.zst.sig" "$f.sig"
done

# Packages first, then the db, then delete what the db no longer references, so a
# client syncing mid-publish never sees a db entry without its package.
gh release upload "$tag" --clobber ./*.pkg.tar.zst ./*.pkg.tar.zst.sig
gh release upload "$tag" --clobber "$name".{db,files}{,.sig,.tar.zst,.tar.zst.sig}

keep=$(bsdtar -xOf "$db" '*/desc' | grep -A1 '^%FILENAME%$' | grep '\.pkg\.tar\.')
gh release view "$tag" --json assets --jq '.assets[].name' | grep '\.pkg\.tar\.' \
  | while read -r asset; do
      grep -qxF "${asset%.sig}" <<<"$keep" || gh release delete-asset "$tag" "$asset" --yes </dev/null
    done
