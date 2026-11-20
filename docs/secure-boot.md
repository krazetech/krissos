# Secure Boot

KrissOS starts with Secure Boot on and the keys the PC came with, so a Windows 11 PC needs
no change in its firmware settings.

## The chain

| Starts | What | Signed by | Trusted because |
|---|---|---|---|
| Firmware | `BOOTX64.EFI`: shim (Fedora's build, package `shim-signed`) | Microsoft UEFI CA | in the firmware's db on every Windows PC |
| shim | `grubx64.efi`: Limine on installs, systemd-boot on the USB | this PC's key / the ISO's key | in shim's MOK list, enrolled once in MokManager |
| Limine | kernel, initramfs, wallpaper | BLAKE2b hashes in `limine.conf` | the config's hash is enrolled in the signed Limine binary |
| systemd-boot (USB) | kernel | the ISO's key | shim checks it |

shim refuses a binary without an `.sbat` section, and Limine has none, so
`kriss-limine-update` adds one (`objcopy`, placed at `SizeOfImage`: Limine's `.data` runs
past its file size, so placing it at the end of the file overlaps memory and shim rejects
it with "Unsupported").

## Keys

- **The USB.** `iso/build.sh` makes a key for that build only, signs systemd-boot, the
  kernel and memtest with it, puts `KRISSOS.cer` at the top of the USB and deletes the private
  half. Nothing else can ever be signed with it, and no project key exists that could leak.
  The ISO's GPG signature vouches for the certificate. On first start with Secure Boot on,
  shim says verification failed and opens MokManager: *Enroll key from disk*, the USB,
  `KRISSOS.cer`, *Continue*, *Yes*, *Reboot*. A new ISO has a new key, so it asks again.
- **The installed PC.** `kriss-secureboot` (installer, `kriss migrate`) runs
  `sbctl create-keys` offline and `mokutil --import` with the password `krissos`. MokManager
  asks once at the next start: *Enroll MOK*, *Continue*, *Yes*, `krissos`, *Reboot*.
  Calamares' *Restart now* shows these steps first (`installer/lib/restart`). The key stays
  on the PC (`/var/lib/sbctl/keys`), and `kriss-limine-update` re-signs Limine with it after
  every kernel, initramfs, Limine, shim or snapshot change.
- **Secure Boot off at install time:** nothing is signed. To turn it on later:
  `sudo kriss-secureboot --enroll`, restart and enroll the key in MokManager, then turn
  Secure Boot on in the firmware settings.
- **Own keys in Setup Mode** (`sbctl enroll-keys`): `kriss migrate` keeps them and leaves
  shim out, since such firmware may not trust Microsoft's CA; Limine is signed with them.

## Why shim and MOK, not sbctl in Setup Mode

sbctl with user keys needs the firmware in Setup Mode: clearing the keys in the BIOS menu,
which differs on every PC, is easy to get wrong, and can stop Windows or a GPU's option
ROM from starting if Microsoft's keys are left out. A live USB signed with our own keys can
never start on a PC with its stock keys. shim is signed by Microsoft, so it starts
everywhere Windows does; MokManager's blue screen is the only extra step, and it needs no
BIOS. Getting our own shim signed by Microsoft (shim-review) is the way to drop even that
step for the USB, and can come later.

## Not covered

- The initramfs on the USB is not checked (as on Arch's own ISO); on installs Limine hashes it.
- The kernel does not force module signatures or lockdown, so DKMS modules (NVIDIA) load
  unsigned.
- 32-bit UEFI and legacy BIOS have no Secure Boot; both start as before.

CI: `iso/secureboot-test.sh` boots the ISO in OVMF with Secure Boot on and Microsoft's
keys, checks that shim refuses it until its key is trusted, installs with Secure Boot on
and goes through MokManager by keyboard to the login screen.
