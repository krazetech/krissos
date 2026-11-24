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

- Switch user: click your picture in Start, then Switch user. Your apps stay open behind
  your lock screen while someone else signs in; "Back to" on the login screen returns to you.
- A guest account you can turn on from the same menu: no password, can't change the PC, and
  everything a guest did is gone the next time a guest signs in.
- Secure Boot can stay on, so a PC that dual-boots Windows 11 needs no BIOS change. The
  USB starts through Microsoft-signed shim: the first time, a blue screen (MokManager) asks
  you to pick *Enroll key from disk* and the `KRISSOS.cer` file on the USB. After installing,
  that blue screen comes once more to enroll your PC's own key (password `krissos`); the
  installer tells you the steps. Updates re-sign the boot menu by themselves.
- Reset this PC: `kriss reset --keep-files` removes the apps you added and resets your
  settings but keeps your files; `kriss reset --everything` also deletes your files and saved
  Wi-Fi, so the PC starts like new. Both take a snapshot first and work offline.
- Type in Chinese (Pinyin), Tamil and Jawi out of the box. Windows+Space switches between
  them and English, and the taskbar shows which one is on: EN, 拼, த or ج. Click it to
  switch too.
- Report a problem: `kriss report` gathers what a bug report needs, takes out your name,
  Wi-Fi names and serial numbers, shows you all of it, then opens a GitHub issue for you to
  submit. With no internet it saves the report to a file instead.
- KrissOS Settings: one Settings app with a search that finds single settings, not just
  pages. Display lets you drag your screens into place, pick the main display, and change
  scale, resolution, refresh rate and orientation, with a 15-second undo if a screen goes
  blank. It also has Recovery (Reset this PC) and Report a problem. Pages it doesn't have yet
  open COSMIC Settings at the right place.
- The main display: the full taskbar with the tray, Start and notifications from the
  keyboard, desktop icons, new windows, the sign-in field and fullscreen games all go there.
- Windows+P switches between PC screen only, Duplicate, Extend and Second screen only.
- Right-click the clock, network, sound, battery or bell on the taskbar for their settings.
  Start has a Settings button next to power.
- System sounds, from KDE's Ocean set: a chime with notifications (quiet in do not disturb
  and over full-screen games), a tick when you change the volume, and a sound when you plug
  in or unplug the charger or a USB device. Sounds can be turned off, or another sound theme
  picked, in the settings.
- On-screen keyboard for 2-in-1 laptops and tablets. On a PC with a touch screen, the
  keyboard button in the taskbar brings it up; after that it comes up by itself whenever
  you tap into a text box, until you type on a real keyboard. Chinese, Tamil and Jawi work
  on it too.
- Settings has its own Sound (output, microphone and a volume mixer for each app),
  Notifications (do not disturb, and turning off pop-ups per app), Power and battery, and
  About (rename your PC, see its parts, copy them for a bug report) pages.
- Settings has its own Wi-Fi (connect, enter a password, forget a network), Ethernet,
  Bluetooth (pair, connect, remove, battery level), Mouse and Touchpad pages: pointer speed,
  "Enhance pointer precision", natural scrolling, scrolling speed, swapped buttons, tap to
  click, and the touchpad off while typing or while a mouse is plugged in.
- Settings > Apps: uninstall any app (a snapshot is taken first), choose which app opens web
  links, email, music, video, pictures, PDFs and text, and turn off apps that start when you
  sign in.
- Settings now covers your name and picture, password, date and time zone, English or Bahasa
  Melayu, privacy (what KrissOS sends, which apps use the microphone, clearing history) and
  updates (update now, the Stable or Testing channel, going back to a snapshot).
- Settings > Keyboard: turn Chinese, Tamil and Jawi typing on or off, and set how fast a
  held key repeats.
- The Store: find, install, update and remove apps without a terminal, from Flathub and
  the KrissOS packs (gaming, Windows apps). It is pinned to the taskbar, and searching in
  Start offers "Get … from the Store" for apps you don't have yet. A snapshot is taken
  before every install, removal and update, so you can undo one from the boot menu.
- Window title bars get new round minimise, maximise and close buttons: they light up in your
  accent colour, close turns red, and they are as easy to hit as on Windows 11. They follow
  the side and order set for GTK apps, so the Mac layout puts them on the left.
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

- KrissOS Welcome looks like the rest of KrissOS: the shell's cards, round buttons and side
  panel, your accent colour, and light or dark as your desktop is set.
- The installer looks like the rest of KrissOS: a step list with ticks, round buttons,
  readable cards on the summary page, pictures of each desktop to pick from and new
  install slides. It follows your light or dark setting.
- The mouse pointer is now Breeze, KDE's cursor: dark on the light theme and light on the dark
  one, switching with the theme (also when it changes by time of day) in every app. Its theme
  and size are settings.
- The live USB boots on the generic `linux-kriss-generic` kernel, so it starts on more PCs (#57).
- The boot menu wallpaper is centred at screen size, and the menu appears about 38 s sooner (#63).
- The screen locks before the PC sleeps, and when `loginctl lock-session` is run (#34).
- Shell motion pass: smoother animations, title bar buttons, and no focus ring on click (#38).

### Fixed

- Steam games (World of Tanks and the like) show their own icon and name on the taskbar, in
  Alt+Tab and in Task View, instead of a blank one, and line up with the game you pinned.
- `kriss update` now swaps in the KrissOS builds of COSMIC Settings and the compositor on
  PCs installed before they existed; until now an update kept the old ones.
- `kriss update` adds the Store to PCs installed before it existed, once; if you remove it,
  it stays removed.
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
