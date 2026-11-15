# KrissOS

A Linux distribution by Kraze Tech, built as a thin overlay on Arch Linux for
productivity, gaming and local AI. See [ARCHITECTURE.md](ARCHITECTURE.md) for the design.

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
- **Rotating the key:**
  1. Add the new key to `pkgs/kriss-keyring/`.
  2. Move the old fingerprint to `krissos-revoked`.
  3. Bump the package version and replace the secret.

## License

GPL-3.0-or-later. Kernel patches keep their upstream licenses and credits.
