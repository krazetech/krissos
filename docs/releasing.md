# Releasing KrissOS

How a KrissOS release is named, what has to be true before `110` ships, and the steps to
cut one. The per-release checklist is the **Release** issue template
(`.github/ISSUE_TEMPLATE/release.md`): open one issue per release and tick it off there.

## Names and tags

- **Codenames are versions.** Releases follow the Modenas Kriss line: `110` is 1.0, then
  `115`, then `MR3` (ARCHITECTURE.md, top). The tag is the codename, and `iso.yml` builds any
  tag that starts with a digit or `MR`.
- **Pre-releases** add a suffix: `110-beta1`, `110-rc1`, `110-rc2`. Any tag with a `-` is
  published as a GitHub pre-release. `0.1-alpha` came before this scheme and stays as it is.
- **Fixes after a release** (an ISO respin for a bad installer bug, say) are `110.1`, `110.2`.
  Packages keep rolling between releases: every merge lands in `[kriss-testing]`, and the
  **promote** workflow moves it to `[kriss]` once the nightly ISO's tests pass (README,
  "Package repo"). A tag is a snapshot of the ISO, not a freeze of the repo.
- **`/etc/os-release`** carries the codename in `VERSION_CODENAME`
  (`pkgs/kriss-settings/root/usr/share/kriss/os-release`). Set it to the next codename right
  after a release ships, so nightlies say what they are heading towards.
- **`preview`** stays the rolling nightly from `main`. It is never a release.

## Release notes

`CHANGELOG.md` is the single source. Every user-visible pull request adds a line under
**Unreleased**. Before tagging, rename **Unreleased** to the tag (`## 110-rc1`) and start a new
empty **Unreleased** above it. `iso.yml` stops a tag in its first step if that section is
missing or empty (`tools/ci/release-notes.sh`), and uses the section as the release notes.

## The `110` milestone

`110` is the first **stable** KrissOS release: the one we tell people leaving Windows to
install on their own PC, without us in the room. It has no date. It ships when every line
below is true, and not before. Anything not on this list waits for `115`.

Track it with the GitHub milestone **110**. Every issue and pull request that blocks it gets
that milestone; nothing else does. Milestone description:

> First stable KrissOS release, for people switching from Windows. Ships when ready, no date.
> Exit criteria: docs/releasing.md#the-110-milestone

### Roadmap (ARCHITECTURE.md §12)

- [x] 0. Repo, CI, signing key, `[kriss]` repo.
- [x] 1. `linux-kriss` builds in CI and boots.
- [x] 2. `kriss-theme`, `kriss-settings`, a live ISO that boots to the KrissOS Shell.
- [x] 3. Calamares installer with the desktop picker, btrfs + snapper, Limine, offline install.
- [x] 4. `kriss tune` and the gaming pack.
- [x] 5. `kriss-vm` on desktops. Laptops with no MUX switch move to `115`; on `110`,
      `kriss-vm` keeps its "not supported yet" warning on them.
- [x] 6. WinBoat tier and the AI setup.

### Shell: everything in

- [x] Every shell feature on the shell roadmap is merged, including the open pull requests
      (taskbar buttons and previews, Start search, Task View, snap layouts, widgets, desktop icons,
      fullscreen focus, clipboard history, notification
      center, system tray, lock and login, accent and dark mode, accessibility, Personalise).
      None is moved to `115`.
- [ ] `shell/perf-check` passes the performance budget on the release ISO with all of it in.

### Installs and boots everywhere it should

- [x] **Legacy BIOS:** the live ISO boots and installs on BIOS (CSM) PCs as well as UEFI
      (pull request #74).
- [ ] **Encrypted installs:** the installer offers full-disk encryption (LUKS), and an encrypted
      install boots, unlocks and rolls back from a snapshot.
- [ ] **Offline install:** the release ISO installs with the network unplugged, both desktops,
      on real hardware as well as in the QEMU install test.

### The promises hold on real hardware (ARCHITECTURE.md §0)

- [ ] **At least two physical PCs:** a clean install and a dual-boot next to Windows 11 pass on
      at least two different real machines. (`0.1-alpha` was VM-only.)
- [ ] **Everything can be undone:** on those PCs, an update is rolled back from the boot menu
      snapshot, and `kriss rollback` works.
- [ ] **Honest hardware numbers:** on those PCs, kriss-welcome's game, driver and AI-model
      checks match what the machine really does.

### Safe to ship

- [x] **Signed or not at all:** tagged releases fail without a good signature (the signing
      change, `docs/signing-key.md`), and the key's rotation plan is written down.
- [x] **Testing channel:** updates reach a testing repo before everyone, so a bad package is
      caught before it lands on `110` installs (`[kriss-testing]` and `promote.yml`, #79).
- [x] **Security policy:** `SECURITY.md` says how to report a vulnerability, and bugs are
      tracked in GitHub Issues.
- [x] **Installer defaults:** no one-character passwords.
- [x] **Licence:** the tooling licence (ARCHITECTURE.md §11.2) is decided and `LICENSE`
      matches it.
- [x] No open issue or pull request left on the `110` milestone.

## Cutting a release

The short version; the issue template has the full checklist.

1. **Freeze.** Open a Release issue from the template, set its milestone, and stop merging
   features for that milestone. Fixes only.
2. **Release candidate.** Run **promote** (dry run first) so `[kriss]` has what the nightly
   tested, since tagged ISOs build from `[kriss]`. Rename **Unreleased** in `CHANGELOG.md` to
   `110-rc1`, merge, then tag `main`: `git tag -a 110-rc1 -m "KrissOS 110-rc1" && git push origin 110-rc1`. CI builds, boot-tests,
   install-tests, signs and publishes the pre-release.
3. **Test the candidate** on real hardware against the milestone list above. Each bug found is
   an issue on the milestone; fix, then `110-rc2`.
4. **Release.** When an `rc` passes with no changes needed, add a `## 110` section (it can
   repeat the rc notes), tag `110` on the same commit, and check the published release.
5. **After.** Point the website's download link at the release, bump `VERSION_CODENAME` to the
   next codename, close the milestone and open the next one.
