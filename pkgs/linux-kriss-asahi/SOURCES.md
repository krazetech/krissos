# linux-kriss-asahi sources

The kernel is Asahi Linux's tree, tag `asahi-7.2.12-3` of https://github.com/AsahiLinux/linux
(GPL-2.0), built from source in our CI. No CachyOS patches.

These files are unmodified copies from asahi-alarm's `linux-asahi` package,
https://github.com/asahi-alarm/PKGBUILDs at 254f8f8182582324c900df38433007a2c2e25bab:

- `config`: the kernel config (16K pages, Rust, the Asahi GPU driver).
- `0001-tools-add-128-bit-integer-types.patch`: by Will Deacon, keeps its upstream header.
- `rust-toolchain.toml`: the Rust release the Asahi GPU driver is built with.

`PKGBUILD` is derived from the `linux-asahi` PKGBUILD there. Differences: the package
name, `CONFIG_LOCALVERSION="-kriss-asahi"` (set in `prepare()`, so it installs next to
`linux-asahi`), `provides=linux-asahi` so `asahi-meta` accepts it, and a check that the
GPU driver survives `olddefconfig`.

## Updating

1. Take `_rcver`, `_asahirel` and `_m1n1_version` from the new `linux-asahi/PKGBUILD`, and
   copy `config`, the patches and `rust-toolchain.toml` from the same commit.
2. Set `_asahiver`, `_asahirel` and `_m1n1_version` here, reset `pkgrel=1`, and update the
   checksums (`updpkgsums`) and the commit above.
3. kernel-asahi.yml builds the PR. Merge when it is green.
