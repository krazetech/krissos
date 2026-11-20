# KrissOS

**Arch Linux made ready for everyday people: offline install, Windows-familiar, built for
work, gaming and local AI.**

KrissOS is for people coming from Windows. It installs from a USB stick with no internet
needed, and it can sit next to Windows. The Windows key opens the launcher, the taskbar is at
the bottom and close is at the top right, in KrissOS's own calm look. If an update goes wrong,
you start an earlier snapshot from the boot menu.

Under the hood it is a thin, signed overlay on Arch Linux by Kraze Tech. See
[ARCHITECTURE.md](ARCHITECTURE.md) for the design, starting with §0, and
[krazetech.github.io/krissos](https://krazetech.github.io/krissos/) for the site.
What changed in each release is in [CHANGELOG.md](CHANGELOG.md), and how releases are
cut is in [docs/releasing.md](docs/releasing.md).

## Layout

| Path | Contents |
|---|---|
| `pkgs/` | One PKGBUILD per package in the `[kriss]` repo |
| `tools/` | Source for `kriss` and the other `kriss-*` tools |
| `welcome/` | Source for `kriss-welcome`, the first-boot app, and its data |
| `.github/workflows/` | CI that builds, signs and publishes the repo |

## Building a package locally

On an Arch machine:

```bash
cd pkgs/kriss-tools && makepkg -si
```

## Package repo

There are two signed pacman repos, each a GitHub release:

| Repo | Release | What lands there |
|---|---|---|
| `[kriss]` (stable) | `repo-x86_64`, `repo-aarch64` | Packages promoted from testing. Every KrissOS install updates from here. |
| `[kriss-testing]` | `testing-x86_64`, `testing-aarch64` | Every package CI builds on a push to `main`. |

Nightly and PR ISOs are built from `[kriss-testing]`, so their boot and install tests run on
what is about to ship. Tagged release ISOs are built from `[kriss]`.

**Promoting to stable.** Run the **promote** workflow from the Actions tab. It defaults to a
dry run that lists what would move; untick *dry run* to do it. Leave *packages* empty to
promote everything newer in testing, or name packages to move only those (a split package
such as `linux-kriss` moves with its headers). It copies the exact files that were tested and
checks their signatures; nothing is rebuilt. Promote before tagging a release.

**Trying testing on your PC.** `kriss channel testing` adds `[kriss-testing]` above `[kriss]`
and `kriss update` then pulls it in. `kriss channel stable` takes it out again and, after a
snapshot, downgrades anything that came from testing.

KrissOS installs come with the keyring already set up. To use the repo on plain Arch, trust
the signing key first:

```bash
curl -fsSL https://raw.githubusercontent.com/krazetech/krissos/main/pkgs/kriss-keyring/krissos.gpg | sudo pacman-key --add -
```

```bash
sudo pacman-key --lsign-key 7C92AE8B599AF81321666CA31317AA31B21C5F87
```

Then add this to `/etc/pacman.conf`:

```ini
[kriss]
Server = https://github.com/krazetech/krissos/releases/download/repo-x86_64
```

For testing as well, put this above `[kriss]`:

```ini
[kriss-testing]
Server = https://github.com/krazetech/krissos/releases/download/testing-x86_64
```

## Verify your download

Each release ships the ISO with `sha256sums.txt` and a `.sig` signature for both. Put
them in one folder, then check the hash:

```bash
sha256sum -c sha256sums.txt
```

Then check the signatures. Import the signing key, and make sure `gpg` reports a good
signature from `7C92AE8B599AF81321666CA31317AA31B21C5F87`:

```bash
curl -fsSL https://raw.githubusercontent.com/krazetech/krissos/main/pkgs/kriss-keyring/krissos.gpg | gpg --import
```

```bash
gpg --verify sha256sums.txt.sig sha256sums.txt
```

```bash
gpg --verify krissos-*.iso.sig krissos-*.iso
```

### Signing key

Packages are signed by `KrissOS Packages`, fingerprint
`7C92AE8B599AF81321666CA31317AA31B21C5F87`.

- **Where the private key lives:** in the `KRISS_GPG_KEY` repository secret, and in the
  maintainer's local GnuPG keyring, with an offline backup.
- **Where the public key lives:** it ships in the `kriss-keyring` package.
- **Rotating or revoking the key:** follow [docs/signing-key.md](docs/signing-key.md). A
  rotation takes two keyring releases a couple of weeks apart, so installs that update rarely
  are not locked out.
- **CI without the key:** publishing packages and tagged ISO releases fail instead of shipping
  unsigned. Only the nightly `preview` ISO and forks carry on with a warning.

## License

GPL-3.0-or-later. Kernel patches keep their upstream licenses and credits.
