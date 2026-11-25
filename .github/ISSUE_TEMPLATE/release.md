---
name: Release
about: Checklist for cutting a KrissOS release (maintainers)
title: "Release <tag>"
labels: release
---

<!-- One issue per release. Set the milestone to the codename (110, 115, MR3).
     The process and the 110 exit criteria are in docs/releasing.md. -->

**Tag:** `<tag>` (for example `110-rc1` or `110`)

### Before tagging

- [ ] Every issue and pull request on the milestone is closed or moved to the next one.
- [ ] Feature freeze announced: fixes only on `main` until the release is out.
- [ ] `main` is green: `packages`, `iso` (boot and install tests) and `image-aarch64`.
- [ ] Last night's `preview` ISO installed on real hardware: clean install and dual-boot next
      to Windows 11, KrissOS Shell and Plasma, network unplugged.
- [ ] Rollback tried: update, boot the previous snapshot from the Limine menu, `kriss rollback`.
- [ ] `shell/perf-check` within budget on the preview ISO.
- [ ] **promote** run after a green nightly (dry run first), so `[kriss]` has what the nightly
      tested: tagged ISOs build from `[kriss]`, and a package missing there stops the build.
- [ ] Signing key in the `KRISS_GPG_KEY` secret is the current one and not near expiry.
- [ ] `CHANGELOG.md`: **Unreleased** renamed to `## <tag>`, read through for plain words, new
      empty **Unreleased** above it. Merged to `main`.

### Tag

- [ ] `git tag -a <tag> -m "KrissOS <tag>" && git push origin <tag>` on the merged commit.
- [ ] The `iso` run for the tag passed every step.

### Check what was published

- [ ] GitHub release exists, notes match the changelog, marked pre-release only if the tag has
      a suffix.
- [ ] `sha256sums.txt` and the `.sig` files are attached and verify with the commands in the
      README (`sha256sum -c`, `gpg --verify`).
- [ ] The ISO is on SourceForge under `releases/<tag>/` and its hash matches.
- [ ] Downloaded ISO boots in a VM.

### After

- [ ] Website download page points at the release (final releases only).
- [ ] `VERSION_CODENAME` in `pkgs/kriss-settings/root/usr/share/kriss/os-release` set to the
      next codename (final releases only).
- [ ] Milestone closed and the next one opened (final releases only).
- [ ] Announcement posted.
