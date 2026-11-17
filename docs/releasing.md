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
  Packages in `[kriss]` keep rolling between releases as they do now; a tag is a snapshot of
  the ISO, not a freeze of the repo.
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

`110` is the first release we would hand to someone leaving Windows without being in the room.
It is done when every line below is true. Anything not on this list can ship in `115`.

Track it with the GitHub milestone **110** (description: *First stable KrissOS release, for
people switching from Windows. Exit criteria: docs/releasing.md#the-110-milestone.*). Every
issue and pull request that blocks it gets that milestone; nothing else does.

### Roadmap (ARCHITECTURE.md §12)

- [x] 0. Repo, CI, signing key, `[kriss]` repo.
- [x] 1. `linux-kriss` builds in CI and boots.
- [x] 2. `kriss-theme`, `kriss-settings`, a live ISO that boots to the KrissOS Shell.
- [x] 3. Calamares installer with the desktop picker, btrfs + snapper, Limine, offline install.
- [x] 4. `kriss tune` and the gaming pack.
- [ ] 5. `kriss-vm`: desktop done; **laptops with no MUX switch still warn "not supported"**.
      Decide: finish it for `110`, or ship `110` with the warning and move it to `115`.
- [x] 6. WinBoat tier and the AI setup.

### The promises hold (ARCHITECTURE.md §0)

- [ ] **Offline install:** the release ISO installs with the network unplugged, both desktops,
      on real hardware as well as in the QEMU install test.
- [ ] **Everything can be undone:** an update is rolled back from the boot menu snapshot on a
      real install, and `kriss rollback` works.
- [ ] **Honest hardware numbers:** kriss-welcome's game, driver and AI-model checks are tried on
      at least one AMD, one Intel and one NVIDIA (pre-Turing and current) machine.
- [ ] **Real hardware:** a clean install and a dual-boot next to Windows 11 on at least three
      different physical PCs, one of them a laptop. (`0.1-alpha` was VM-only.)
- [ ] **Legacy BIOS:** in or out for `110` is decided (pull request #74 adds it).

### Safe to ship

- [ ] Tagged releases fail without a good signature (the signing thread's change, see
      `docs/signing-key.md` once it lands), and the key's rotation plan is written down.
- [ ] Updates reach a testing channel before everyone (the update testing channel work), so a
      bad package can be caught before it lands on `110` installs.
- [ ] `SECURITY.md` exists and says how to report a vulnerability; bugs are tracked in GitHub
      Issues.
- [ ] Installer security defaults are settled: disk encryption offered, no one-character
      passwords.
- [ ] The tooling licence (ARCHITECTURE.md §11.2) is decided and `LICENSE` matches it.
- [ ] No open issue labelled as a blocker on the `110` milestone.

### Shell

- [ ] The shell feature pull requests in the queue are merged or moved to `115`, so `110`
      freezes on a known set.
- [ ] `shell/perf-check` passes the performance budget on the release ISO.

## Cutting a release

The short version; the issue template has the full checklist.

1. **Freeze.** Open a Release issue from the template, set its milestone, and stop merging
   features for that milestone. Fixes only.
2. **Release candidate.** Rename **Unreleased** in `CHANGELOG.md` to `110-rc1`, merge, then
   tag `main`: `git tag -a 110-rc1 -m "KrissOS 110-rc1" && git push origin 110-rc1`. CI builds, boot-tests,
   install-tests, signs and publishes the pre-release.
3. **Test the candidate** on real hardware against the milestone list above. Each bug found is
   an issue on the milestone; fix, then `110-rc2`.
4. **Release.** When an `rc` passes with no changes needed, add a `## 110` section (it can
   repeat the rc notes), tag `110` on the same commit, and check the published release.
5. **After.** Point the website's download link at the release, bump `VERSION_CODENAME` to the
   next codename, close the milestone and open the next one.
