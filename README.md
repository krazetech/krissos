# KrissOS

A Linux distribution by Kraze Tech, built as a thin overlay on Arch Linux for
productivity, gaming and local AI. See [ARCHITECTURE.md](ARCHITECTURE.md) for the design.

## Layout

| Path | Contents |
|---|---|
| `pkgs/` | One PKGBUILD per package in the `[kriss]` repo |
| `tools/` | Source for `kriss` and the other `kriss-*` tools |
| `.github/workflows/` | CI that builds, signs and publishes the repo |

## Building a package locally

On an Arch machine:

```bash
cd pkgs/kriss-tools && makepkg -si
```

## Package repo

CI builds every package on each push to `main` and publishes the signed repo to the
`repo-x86_64` GitHub release. To use it, add this to `/etc/pacman.conf`:

```ini
[kriss]
Server = https://github.com/krazetech/krissos/releases/download/repo-x86_64
```

### Signing key (one-time setup)

CI only publishes when a signing key is configured. Create a key with no passphrase,
dedicated to package signing:

```bash
gpg --quick-gen-key "KrissOS Packages <packages@krisstech.invalid>" ed25519 sign never
```

Then:

1. Export the private key with `gpg --armor --export-secret-keys <KEYID>` and save it as the
   repository secret `KRISS_GPG_KEY`.
2. Keep an offline backup of the private key. If it is lost, every user has to trust a new key.
3. The public half goes into the `kriss-keyring` package, which is not written yet.

## License

GPL-3.0-or-later. Kernel patches keep their upstream licenses and credits.
