# Changelog

What changed in each KrissOS release, written for the people who install it. Releases are
tagged with Modenas Kriss codenames (`110` is 1.0); see [docs/releasing.md](docs/releasing.md)
for how tags, pre-releases and this file fit together.

Add a line under **Unreleased** in the same pull request as the change, in plain words a
Windows switcher would understand. Group lines under Added, Changed, Fixed, Removed or
Security. Internal-only changes (CI, refactors, docs for maintainers) can be left out.

When a release is tagged, the section for that tag becomes the GitHub release notes, so the
heading must match the tag exactly (`## 110-rc1`, `## 110`).

## Unreleased

### Added

- Windows apps: WinBoat, with `kriss winapps check` and `kriss winapps setup` to see whether
  a Windows app will run and set it up (#26).
- The installer works with no internet at all: everything it needs is on the USB stick (#30).
- Boot menu: KrissOS look, an entry for each installed kernel, and snapshots you can start
  from the menu to roll back a bad update (#28).
- Boot splash: the keris pulses, then opens into the login screen (#64).
- Shell: Alt+Tab, media keys, battery state, and the power button puts the PC to sleep (#36).
- Shell: a pop-up for the volume, mic and brightness keys (#35).
- Shell: notifications are grouped by app and time, and the clock opens a calendar (#40).
- Shell: windows fade and scale as they open and close (#41).
- Shell: a full-width 48 px taskbar attached to the bottom of the screen (#46).
- kriss-welcome shows which local AI models fit this PC (#59).
- `kriss migrate` turns an existing Arch or CachyOS install into KrissOS in place (#42).
- COSMIC apps, icons, cursor, Flatpak apps, the console and the UEFI menu all follow the
  KrissOS theme (#29).
- Older NVIDIA cards (before Turing, such as GTX 900 and 10 series) get the 580 driver they
  need (#33).
- Apple Silicon preview image, first slice: tested in a VM only (#27, #37, #39).
- A friendlier website in English and Malay (#58).

### Changed

- The live USB boots on the generic `linux-kriss-generic` kernel, so it starts on more PCs (#57).
- The boot menu wallpaper is centred at screen size, and the menu appears about 38 s sooner (#63).
- The screen locks before the PC sleeps, and when `loginctl lock-session` is run (#34).
- Shell motion pass: smoother animations, title bar buttons, and no focus ring on click (#38).

### Fixed

- Booting no longer loads nouveau's GSP firmware into the initramfs (#32).
- kriss-vm boot entries and kriss-welcome pages (#33).

## 0.1-alpha

Released 2026-11-16 as a pre-release. Tested in virtual machines only, not on real hardware.

### Added

- Live ISO that boots straight into the KrissOS Shell (#9, #19).
- Calamares installer: dual-boot next to Windows, btrfs with snapper snapshots, Limine, and
  a choice of KrissOS Shell or KDE Plasma (#14, #22).
- KrissOS Shell on cosmic-comp: taskbar, launcher on the Windows key, notifications, quick
  settings and lock screen (#11, #16, #17, #18).
- `linux-kriss` kernel, built and published by CI (#7).
- kriss-welcome: game checker, Bring your apps, Copy from Windows, Drivers and extras (#13, #21).
- `kriss update` and an update notice (#21).
- `kriss tune` and the gaming pack, `kriss-meta-gaming` (#20).
- `kriss-vm`: pass the GPU through to a Windows VM, on desktops (#23).
- KrissOS theme and settings for Plasma, light and dark wallpapers (#1, #8, #9).
- Signed `[kriss]` package repository with `kriss-keyring`.

### Fixed

- X11 apps run in the KrissOS Shell (#24).
