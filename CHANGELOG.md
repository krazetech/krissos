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

- Reset this PC: `kriss reset --keep-files` removes the apps you added and resets your
  settings but keeps your files; `kriss reset --everything` also deletes your files and saved
  Wi-Fi, so the PC starts like new. Both take a snapshot first and work offline.
- The Store: find, install, update and remove apps without a terminal, from Flathub and
  the KrissOS packs (gaming, Windows apps). It is pinned to the taskbar, and searching in
  Start offers "Get … from the Store" for apps you don't have yet. A snapshot is taken
  before every install, removal and update, so you can undo one from the boot menu.
- A new terminal opens with the KrissOS emblem and a summary of your PC, instead of a bare
  prompt or fish's welcome text.
- Updates go through a testing channel first, so a bad package is caught before it reaches
  you. To try updates early, run `kriss channel testing`; `kriss channel stable` takes you
  back (#79).
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
- The live USB boots and installs on older PCs with legacy BIOS (CSM), not only UEFI (#74).
- `kriss install` finds and installs apps from the KrissOS and Arch repos, Flathub and the
  AUR in one command, trying the safest source first (#82).
- Taskbar: buttons that behave like Windows 11's, live window previews, a search box and
  taskbar options (#50, #51, #55).
- Shell: a system tray with a Windows 11 style overflow flyout (#54).
- Shell: desktop icons, a selection box and a right-click menu (#52).
- Shell: in fullscreen apps and games the taskbar hides and notifications wait (#53).

### Changed

- The installer looks like the rest of KrissOS: a step list with ticks, round buttons,
  readable cards on the summary page, pictures of each desktop to pick from and new
  install slides. It follows your light or dark setting.
- The live USB boots on the generic `linux-kriss-generic` kernel, so it starts on more PCs (#57).
- The boot menu wallpaper is centred at screen size, and the menu appears about 38 s sooner (#63).
- The screen locks before the PC sleeps, and when `loginctl lock-session` is run (#34).
- Shell motion pass: smoother animations, title bar buttons, and no focus ring on click (#38).

### Fixed

- `loginctl unlock-session` unlocks the lock screen again, so remote and admin tools can
  unlock it.
- Updates no longer stop at "invalid or corrupted package" when the signing keys are out
  of date: `kriss update` refreshes the keys first and tries once more if a download fails.
- The password prompt for installing and changing things comes back on its own if it
  closes, instead of silently never appearing again.
- Booting no longer loads nouveau's GSP firmware into the initramfs (#32).
- kriss-vm boot entries and kriss-welcome pages (#33).
- A stray duplicate file that stopped the shell from starting (#70).

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
