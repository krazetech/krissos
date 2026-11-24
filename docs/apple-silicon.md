# Apple Silicon image

The plan is in ARCHITECTURE §13. This page covers how the pieces are built and how the image
will reach a Mac through the Asahi installer.

## What exists

| Piece | Where | Built by |
|---|---|---|
| `[kriss]` for aarch64 | release `repo-aarch64` | `pkgs.yml`, job `build-aarch64` |
| `linux-kriss-asahi` | `pkgs/linux-kriss-asahi` | `kernel-asahi.yml` |
| Image | `aarch64/` | `image-aarch64.yml` |

Everything runs on GitHub's free arm64 runners (`ubuntu-24.04-arm`), natively, in an Arch
Linux ARM container. `tools/ci/alarm.sh` makes that container from the official ALARM rootfs
tarball and checks its signature against the vendored build key in `tools/ci/keys/`.

`repo-aarch64` holds the same architecture-neutral packages as `repo-x86_64`, built and
dependency-checked on Arch Linux ARM: `kriss-keyring`, `kriss-settings`, `kriss-theme`,
`kriss-tools`, `kriss-shell` and `kriss-welcome`, plus `linux-kriss-asahi`. Left out:
`calamares` and `kriss-installer` (the Asahi installer does that job), `kriss-meta-winapps`
and `winpodx` (x86 only here), `kriss-meta-gaming` (its lib32 and Intel/AMD Vulkan packages do not
exist on aarch64), and `linux-kriss`. `kriss winapps` and `kriss-vm` refuse to run on a
non-x86_64 machine.

## The image

`aarch64/build.sh OUT WORK generic|asahi` builds one of two flavours from the same package
list. Repos: Arch Linux ARM, then `[asahi-alarm]` (first, as asahi-alarm documents, so its
builds win) and `[kriss]`. The `[kriss]` packages come from the checkout, like the ISO.

- **generic:** Arch Linux ARM's `linux-aarch64`. Also written as a whole GPT disk,
  `krissos-aarch64-generic.img`, for UTM or QEMU. The CI boot test runs it.
- **asahi:** the Asahi kernel, `asahi-meta` (m1n1, U-Boot, firmware tools) and
  `asahi-desktop-meta` (Mesa, speaker safety, audio). It uses asahi-alarm's `linux-asahi`
  until `linux-kriss-asahi` is in `repo-aarch64`; then it takes ours. Writes
  `krissos-aarch64-asahi.zip` and `installer_data.json`.

Layout, the same in both flavours:

- **ESP** (512 MiB FAT32, volume ID `4B52-4953`, mounted at `/boot/efi`):
  `EFI/BOOT/BOOTAA64.EFI` is a unified kernel image (kernel, initramfs and command line in one
  EFI file). mkinitcpio rebuilds it on every kernel update. UEFI starts it directly, edk2 in
  a VM and U-Boot on a Mac, so there is no boot loader. On a Mac, `m1n1/boot.bin` (m1n1
  stage 2 with the device trees and U-Boot) sits beside it and `update-m1n1` keeps it
  current.
- **Root** (ext4, UUID `23f2f273-…`, label `krissos-root`): grows to fill its partition on
  first boot (`x-systemd.growfs`).

Boot chain on a Mac: iBoot → m1n1 stage 1 (installed by the Asahi installer) → `m1n1/boot.bin`
on the ESP → U-Boot → `EFI/BOOT/BOOTAA64.EFI` → KrissOS.

This is a preview: user `kriss`, password `kriss`, signed in automatically like the live ISO.
A first-boot setup (user, password, language) must replace that before the image is offered
to anyone. asahi-alarm does this with Calamares in first-boot mode
(`asahi-calamares-configs`).

### Trying it

From a CI run's `krissos-aarch64-generic` artifact, on a Mac with Homebrew's qemu:

```bash
FW=$(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd ACCEL=hvf aarch64/boot-test.sh krissos-aarch64-generic.img boot-test
```

Or import `krissos-aarch64-generic.img` into UTM as a raw disk (Virtualize, Linux, UEFI).

## Through the Asahi installer

The Asahi installer runs in macOS. It shrinks the macOS volume, makes a stub macOS
partition that holds m1n1 stage 1, and creates the partitions an OS entry in
`installer_data.json` lists. For KrissOS it will:

1. Make the 512 MiB ESP, format it FAT32 with `volume_id` `0x4b524953` (fstab mounts the ESP
   by that ID), copy the zip's `esp/` into it, and add the Wi-Fi and other firmware it
   extracts from macOS (`copy_firmware`) and its own data (`copy_installer_data`).
2. Write `root.img` into the root partition and grow the partition (`expand`) to the space
   the user gave Linux. The filesystem grows on first boot.
3. Set `m1n1.bin` as the stub's boot object, which then chains to `m1n1/boot.bin` on the ESP.

`aarch64/installer_data.json` is our entry; `build.sh` fills in the root partition size. The
format follows asahi-alarm's
[installer data](https://github.com/asahi-alarm/asahi-installer-data/blob/main/data/installer_data.json).
`supported_fw` lists the macOS firmware versions m1n1 and the kernel support; keep it in step
with asahi-alarm's list.

### Hosting (to do)

The installer itself stays Asahi's. We host three things:

- **`krissos-aarch64-asahi.zip`**, as a release asset (for example a `preview-aarch64`
  release, which `installer_data.json` already points at). GitHub caps release assets at
  2 GiB; a desktop image is close to that, so this moves to the planned R2 bucket with the ISO.
- **`installer_data.json`**, beside the zip.
- **A bootstrap script** for the website, `curl https://<site>/install-mac | sh`: a copy of
  asahi-alarm's `installer-bootstrap.sh` with `INSTALLER_DATA` pointed at our JSON.
  `INSTALLER_BASE` and `VERSION_FLAG` keep pointing at asahi-alarm's build of the installer,
  so we never fork it. `REPORT` and `REPORT_TAG` send install statistics to Asahi; ask them
  before tagging KrissOS installs there, or unset `REPORT`.

Not verified yet, because it needs real hardware and nobody has run it: the U-Boot →
unified kernel image handoff, `update-m1n1` with `linux-kriss-asahi`, firmware loading, and
the installer flow end to end. Installing on a Mac is the user's call.

## Not in this slice

- First-boot setup instead of the preview login.
- btrfs + snapper rollback (the x86 layout); the root is ext4 for now.
- Games: Steam through FEX and muvm (asahi-alarm packages `steam`, `FEX-Emu` and `muvm`).
- `kriss-welcome` still offers Wine/Proton answers, which need FEX on aarch64.
- Publishing the asahi zip and the bootstrap script.
