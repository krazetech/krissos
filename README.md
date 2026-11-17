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

CI builds every package on each push to `main` and publishes the signed repo to the
`repo-x86_64` GitHub release. KrissOS installs come with the keyring already set up. To use
the repo on plain Arch, trust the signing key first:

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
