# Signing key: rotation and revocation

Every package in `[kriss]`, the repo database and every release ISO are signed by one key:

```
KrissOS Packages
7C92AE8B599AF81321666CA31317AA31B21C5F87   ed25519, sign + certify, no expiry, no subkeys
```

Installs trust it because `kriss-keyring` ships it in `krissos-trusted` and runs
`pacman-key --populate krissos` on every install and upgrade. ISO users check it by hand
against the fingerprint in the README. CI refuses to publish packages or tag an ISO
release without it (`tools/ci/publish.sh`, the Sign step in `iso.yml`).

## Where things stand today, and the weak spot

The full secret key, primary included, sits in the `KRISS_GPG_KEY` Actions secret. Anyone who
gets that secret can sign packages that every KrissOS install will accept, and can sign a
"new" keyring that hands trust to a key of their choosing. There is also no second trusted
key, so if this one is lost or leaked, the only key installs trust to deliver the fix is the
bad one.

The plan fixes that once (sections 1 and 2) and then leaves routine rotation cheap (section 3).

## 1. Prepare now (one afternoon, offline)

Do this on an offline machine or a live USB with no network.

1. **Make the new primary key, certify only, no expiry.** It never goes near CI.
   `gpg --quick-gen-key 'KrissOS Packages 2027' ed25519 cert never`
2. **Add two signing subkeys,** each with a two-year expiry:
   - **CI subkey**, which goes into `KRISS_GPG_KEY`.
   - **Spare subkey**, kept offline, used only to sign the fix after a CI leak (section 4).
   `gpg --quick-add-key <new-fpr> ed25519 sign 2y` (twice)
3. **Make a revocation certificate** for the new primary and print it.
   GnuPG writes one to `openpgp-revocs.d/` at creation, so copy that out.
4. **Back up** the primary secret key and the revocation certificate on two encrypted USB
   sticks, held by two different people. Write the passphrase down on paper and keep it with
   the second holder, not the stick. Note in this file who holds them (names only).
5. **Make a revocation certificate for the current key** (`7C92AE8B…5F87`) too, and back it up
   the same way, so it can still be revoked if the CI copy is all that is left.
6. **Export only the CI subkey** for CI:
   `gpg --armor --export-secret-subkeys <ci-subkey-fpr>!` (the `!` matters: it exports that one
   subkey, with the primary as a stub). Check with `gpg --show-keys` that the primary shows `sec#`.

## 2. Planned rotation to the new key

Two keyring releases, at least two weeks apart, so installs that update rarely are not
stranded. Nothing is revoked here: packages and ISOs signed with the old key stay valid.

**Release A: trust both keys.** CI still signs with the old key.

1. Append the new public key (primary plus both subkeys) to `pkgs/kriss-keyring/krissos.gpg`.
2. Add `<new-fpr>:4:` to `krissos-trusted`, keeping the old line.
3. Bump `pkgver` and merge. CI signs this keyring with the old key, which installs already trust.
4. Update the README and the website's Download page to list both fingerprints.

**Wait** at least two weeks. `kriss-keyring` is in the base install, so a normal update picks it
up. Installs that do not update in that window (and ISOs older than release A) will fail on
release B with an unknown-key error. For them, save the release-A keyring package somewhere
that lasts (attach it to a GitHub release of its own: `publish.sh` prunes superseded packages
from `repo-x86_64`), and put the one-line fix in the release-B note:
`sudo pacman -U <url of kriss-keyring release A>`. It is signed with the old key, which those
installs still trust.

**Release B: switch CI to the new key, retire the old one.**

1. Replace `KRISS_GPG_KEY` with the CI subkey export from section 1, step 6.
2. Change the fingerprint in the Sign step of `.github/workflows/iso.yml`, and in the README
   and on the website, to the new primary's.
3. Remove `7C92AE8B…5F87` from `krissos-trusted` and list it in `krissos-revoked`, then bump
   `pkgver` and merge. `pacman-key --populate` then disables it locally. Keep its public key in
   `krissos.gpg` so old ISO signatures still verify by hand.
4. Run `pkgs.yml` by hand (workflow_dispatch) so every package in the repo is re-signed with the
   new subkey. Without this, packages published before the switch still carry old-key signatures
   and fail on installs that have revoked it. Check: `pacman -Syu` on a fresh VM from the
   current ISO, then on a VM made from the 0.1-alpha ISO.
5. Delete the old key's secret from the maintainer keyring once a tagged ISO has been built
   and verified with the new key.

Write a short release note for both A and B. Users verifying ISOs need to know the fingerprint
changed and why.

## 3. Routine rotation after that

Once CI holds only a subkey, rotation is a subkey swap and installs need nothing but a
keyring update:

- **Every year** (subkeys expire after two, so there is slack): add a new CI subkey offline,
  ship the updated public key in `kriss-keyring` (signed by the current CI subkey), wait two
  weeks, then replace `KRISS_GPG_KEY` and re-run `pkgs.yml`. The fingerprint users check
  (the primary's) does not change.
- **Extend the spare subkey's expiry** at the same time, and test it signs a throwaway file.
- **Before any subkey expires**, check its date: `gpg --show-keys pkgs/kriss-keyring/krissos.gpg`.
  An expired signing key fails every pacman update, so put the date in the calendar.

## 4. If the key leaks (revocation)

Signs of a leak: the `KRISS_GPG_KEY` secret shows in a log, a workflow change you did not
expect touched it, a repo admin account is compromised, or a signature appears on something
CI did not build.

**First hour**

1. Rotate every GitHub secret and token with access to the repo, and check the audit log
   (Settings, Audit log) and recent workflow runs for anything that read the secret.
2. Delete `KRISS_GPG_KEY` so nothing more gets signed. CI will now fail on publish and on tags,
   which is the point.
3. Open a GitHub security advisory and post a short notice on the website: what happened, the
   fingerprint affected, and "do not update until the fix is out" if the leak is confirmed.

**Ship the fix** (same day if possible)

- **After section 1 and 2 are done** (CI holds only a subkey): revoke the leaked CI subkey
  offline with the primary, add a new CI subkey, and ship the updated public key in
  `kriss-keyring` signed with the **spare subkey**. Installs already trust the primary, so they
  accept it. Then set the new subkey in CI and re-run `pkgs.yml` to re-sign everything.
- **Today, before section 1 is done** (CI holds the only key): there is no clean fix. The least
  bad path is to make the new key as in section 1, ship a keyring that trusts the new key and
  revokes the old one, and sign that one keyring with the old key one last time. Then publish the
  old key's revocation certificate to keys.openpgp.org and in the keyring. An attacker holding
  the old key could race this with a keyring of their own, so pair it with the notice above and
  tell users to compare the new fingerprint against the website and the advisory before trusting
  it. This is the main reason to do section 1 soon.

**Afterwards**

- Re-sign the ISOs of every supported release with the new key and replace their `.sig` files
  on SourceForge and the GitHub release. Say in the release notes that the old signatures no
  longer count.
- Write up what happened in the advisory once it is fixed.

## Checklist for a maintainer handover

- [ ] Both backup holders can each produce the primary key and its revocation certificate.
- [ ] The spare subkey signs a test file.
- [ ] No subkey expires in the next six months.
- [ ] `KRISS_GPG_KEY` holds a subkey only (`sec#` for the primary).
