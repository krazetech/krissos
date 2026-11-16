# NVIDIA 580xx legacy driver: sources

Pinned builds of two AUR packages, so `kriss-welcome` can offer the NVIDIA 580 driver to
Maxwell, Pascal and Volta GPUs (for example the GeForce MX150) from `[kriss]`, with no AUR
helper. NVIDIA moved these GPUs to the 580 branch, which gets long-term fixes but no new
features. Turing and newer use `nvidia-open-dkms` from Arch instead. The installer never
installs this driver: it stays an optional, online extra.

| Directory | AUR package base | AUR commit | Version | Makes |
|---|---|---|---|---|
| `pkgs/nvidia-580xx-utils` | [nvidia-580xx-utils](https://aur.archlinux.org/pkgbase/nvidia-580xx-utils) | `0b45a07013d6cc1d19dbf61c110f9b97d6fc429b` (2026-10-23) | 580.196.07-1 | `nvidia-580xx-utils`, `nvidia-580xx-dkms`, `opencl-nvidia-580xx` |
| `pkgs/lib32-nvidia-580xx-utils` | [lib32-nvidia-580xx-utils](https://aur.archlinux.org/pkgbase/lib32-nvidia-580xx-utils) | `489271acfd01c91bc07201300e6b63f3d2a8e2ba` (2026-10-23) | 580.196.07-1 | `lib32-nvidia-580xx-utils`, `lib32-opencl-nvidia-580xx` |

- **Driver:** `NVIDIA-Linux-x86_64-580.196.07.run` from download.nvidia.com, pinned by the
  checksums in each PKGBUILD (sha256 `0aab0518…69ce`, checked against a fresh download).
- **Maintainers:** Vasiliy Stelmachenok (CachyOS) maintains both AUR packages. The
  Contributor lines in each PKGBUILD credit the Arch packagers they come from. They are kept
  as they are.

## Licences

- **The driver** is under the NVIDIA Software License (`license=('custom')`), installed as
  `/usr/share/licenses/nvidia-utils/LICENSE` and, for the DKMS sources,
  `/usr/share/licenses/nvidia-580xx-dkms/LICENSE`. It allows redistributing the driver as
  distributions package it, the same way Arch, CachyOS and RPM Fusion do.
- **The PKGBUILDs, patches and config files** come from the AUR, whose package sources are
  under 0BSD.

## Changes from the AUR

- **`nvidia-580xx-utils`:** none, apart from the header comment.
- **`lib32-nvidia-580xx-utils`:** the AUR links `/usr/share/licenses/lib32-nvidia-580xx-utils`
  to itself. Ours links it to `nvidia-utils`, where `nvidia-580xx-utils` puts the licence.

## Which GPUs

The 580 driver's own `supported-gpus/supported-gpus.json` lists pre-Turing device ids from
`0x1340` (Maxwell GM108) to `0x1df6` (Volta), with no older-branch (470 and below) GPU in that
range. Turing starts at `0x1e00`. So `kriss nvidia` offers the driver for
`0x1340 <= id < 0x1e00`. The branch is frozen, so the range will not move.

## Bumping

1. Copy the new AUR PKGBUILD and files over the old ones (`git clone` both AUR repos), and
   keep the header comment and the lib32 licence-link change above.
2. Update the table: commit, date and version.
3. Bump both packages together: `nvidia-580xx-dkms` needs `nvidia-580xx-utils` of the same
   version.

CI skips a pinned package whose exact version is already published, so a bump must change
`pkgver` or `pkgrel` to be rebuilt.
