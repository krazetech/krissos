# KrissOS Shell roadmap

The goal: a shell that feels premium and polished, with Windows 11 as the north star, rebuilt
in the KrissOS look rather than cloned. It must suit a maintainer who uses it every day and
someone fresh from Windows equally. Features come first and polish follows. The biggest wins
are first.

Each item is one branch and one PR. Tick an item and link its PR when it merges.

## Already in the shell

These are the base the items below build on.

- System tray: the icons, click, middle click, scroll and the app's own menu (`TrayIcon.qml`).
- Snapping from the keyboard: halves, then quarters with Win+Shift+Up/Down.
- Workspaces from the keyboard: Win+1…9, and Win+Shift+1…9 to move a window.
- Toasts stacked like Sonner, a bell that lists them, Do not disturb, and a clock calendar.
- Start: a grid of pinned apps and recent files, and cmdk-style search across apps and recent
  files.
- Blur behind the bar, launcher, quick settings and Alt+Tab switcher (`BackgroundEffect`).
- A light shell variant, which follows `color-scheme`.
- A bar on every screen.

## Rules for every PR

- **Translations:** every new string has a Bahasa Melayu translation (`shell/i18n-check`).
- **Theme:** colours and fonts come from `theme/tokens.json`, never hard-coded.
- **Motion:** system surfaces use quick, decelerating transitions (150–250 ms). Drags and
  gestures use springs. Every animation goes through `Theme.ms()`, so reduced motion stops it.
- **Keyboard:** every new surface works by keyboard alone (arrows, Esc, focus trap,
  type-ahead), and every control has an accessible name and role for Orca.
- **Performance:** the PR reports `shell/perf-check` numbers (item 0) and stays inside the
  budget.
- **Offline:** everything works offline. Online features hide when there is no network.
- **Hardware:** test on several monitors, fractional scaling, 120 Hz+ and a laptop when the
  item touches them.

## Performance budget

- **CPU:** close to 0% when idle.
- **Memory:** under 150 MB RSS for `quickshell` and its helpers.
- **Frames:** every animation holds the display's refresh rate, 120 Hz+, on an integrated GPU.

## Roadmap

Size: S is about a day, M a few days, L a week or more. Items in the same wave can run in
parallel sessions when they touch different files.

### Wave 0: boot and the taskbar, exactly like Windows

| # | Item | Branch | Size | Done when |
|---|---|---|---|---|
| A | Plymouth theme fix | `kz/boot-plymouth` | S | `kriss-settings` makes `kriss` the Plymouth theme and rebuilds the initramfs; `kriss migrate` replaces a leftover `Theme=` (such as `cachyos`) in `/etc/plymouth/plymouthd.conf`; no Arch or CachyOS logo shows at boot |
| B | Boot animation | `kz/boot-animation` | M | The keris emblem reveals (disc fades and scales in, the hilt draws on), then breathes slowly until the system is up, and fades into the login screen; the password prompt for an encrypted disk uses the same look; no animation with reduced motion |
| C | Taskbar shape | `kz/shell-taskbar-shape` | S | Full width and attached to the bottom edge, 48 px like Windows 11, with a soft top rim and blur; maximized windows stop at it |
| D | Taskbar behaviour | `kz/shell-taskbar-behaviour` | L | Windows of one app grouped on one button; click focuses, minimizes, or cycles; Ctrl+click cycles; Shift+click and middle click open a new window; running dot and active pill; attention flash and progress; jump lists on right-click (recent files, app actions, pin, close); far-right sliver shows the desktop; Win+T steps through the buttons; Win+1…9 opens or switches to that button's app |
| E | Hover thumbnails | `kz/shell-taskbar-previews` | M | Hovering a button shows a live preview of each of its windows; click one to focus it, close it from its preview |
| F | Search box and taskbar options | `kz/shell-taskbar-options` | M | A search box next to Start opens Start in search mode; options saved in `shell.json`: alignment (centre or left), auto-hide, combine buttons (always, when full, never, with labels when not combined), and the taskbar on all screens with each screen's bar showing its own windows |

### Wave 1: the biggest wins

| # | Item | Branch | Size | Done when |
|---|---|---|---|---|
| 0 | Perf check | `kz/shell-perf-check` | S | `shell/perf-check` prints idle CPU, RSS and dropped frames for a scripted open and close of each surface |
| 1 | System tray, finished | `kz/shell-tray` | M | Win11-style overflow flyout (^) for hidden icons, drag icons between bar and overflow, tooltips, KrissOS-styled menus that work by keyboard, choice saved in `shell.json` |
| 2 | Acrylic surfaces | `kz/shell-acrylic` | S | Toasts, notification center, OSD, menus and lock screen blur too, like the bar and launcher; tints from tokens; solid fallback when blur is off or reduced transparency is on |
| 3 | Fullscreen focus | `kz/shell-fullscreen` | S | A fullscreen window on a screen hides that screen's bar and holds toasts until it leaves fullscreen; held toasts land in the notification center |
| 4 | Notification center | `kz/shell-notif-center` | M | Win+N panel: history grouped by app, clear one, clear all, Do not disturb, calendar with today's date; history survives a shell restart |

### Wave 2: windows and desktops

| # | Item | Branch | Size | Done when |
|---|---|---|---|---|
| 5 | Task View and desktops | `kz/shell-task-view` | L | Win+Tab overview with live window thumbnails and a desktop strip; add, remove and rename desktops; drag a window to a desktop; Win+Ctrl+Left/Right; three-finger swipe sideways switches desktops and up opens Task View |
| 6 | Snap layouts | `kz/shell-snap-layouts` | L | Dragging a window to an edge or corner previews the snap; hovering maximize, or Win+Z, offers layouts (halves, thirds, quarters); after a snap, the rest of the screen offers the other windows to fill it (Snap Assist) |

### Wave 3: Start and everyday tools

| # | Item | Branch | Size | Done when |
|---|---|---|---|---|
| 7 | Search everywhere | `kz/shell-search` | M | Start search also finds settings pages, every local file by name (offline index), inline calculation and unit conversion, commands and `kriss` actions; web search is the last result and only when online |
| 8 | Clipboard and emoji | `kz/shell-clipboard` | M | Win+V: text and image history, pin, delete, clear all, pinned items survive a reboot, items password managers mark as sensitive are never stored; Win+.: emoji and symbol picker searchable in English and Malay |

### Wave 4: make it yours

| # | Item | Branch | Size | Done when |
|---|---|---|---|---|
| 9 | Theme at runtime | `kz/shell-runtime-theme` | M | Theme reads user overrides (accent, light/dark with a schedule) live, with tokens as defaults; changing them needs no rebuild |
| 10 | Personalise | `kz/shell-personalise` | L | A settings surface for the accent, taskbar (alignment, auto-hide, size, tray items), wallpaper, light/dark, and pins in the taskbar and Start; linked from COSMIC Settings and Start search |
| 11 | Dock layout and picker | `kz/shell-dock` | L | A dock layout of the same surfaces; `kriss-welcome` offers both with a live preview; the setting switches between them live |

### Wave 5: finish

| # | Item | Branch | Size | Done when |
|---|---|---|---|---|
| 12 | Lock and login | `kz/shell-lock` | M | macOS-feel lock screen and greeter over a wallpaper whose lighting shifts through the day (one scene, several times of day, all offline) |
| 13 | Widgets | `kz/shell-widgets` | L | Win+W panel: calendar and agenda, clocks, system stats (CPU, GPU, RAM, temperatures), now playing, a prompt to the local AI, weather only when online |
| 14 | Accessibility pass | `kz/shell-a11y` | M | Orca reads every surface, text follows the system scale, a high-contrast token set exists, keyboard-only walk-through of every surface passes |

## Order and dependencies

- **Wave 0 first.** A and B touch only boot files, so they run alongside the taskbar items.
  C, D, E and F all change `Bar.qml`, so they run one after another, in that order.
- **Win+1…9 changes meaning.** They open taskbar apps now, as in Windows. Workspaces move to
  Win+Ctrl+Left/Right (item 5), and Win+Shift+1…9 stops moving windows.
- **E and 5 share code:** both need window thumbnails through `ext-image-copy-capture`. E builds
  it and 5 reuses it.
- **0 runs alongside Wave 0:** every later PR reports against the budget.
- **1–4 together:** they can run at once. 1, 3 and 4 all touch `Bar.qml`, so they merge one
  after another.
- **2:** touches `Theme.qml` and every surface's window, so run it alone or rebase the others
  after it.
- **5 and 6:** run after `cosmic-comp-kriss` (krazetech/krissos#41) merges, since snap previews
  and Snap Assist need compositor changes in that patch set. Task View thumbnails use
  `ext-image-copy-capture`, which cosmic-comp already offers.
- **9 before 10 and 11:** today colours are filled in at build time, so the accent can't change
  without a rebuild.
- **12–14:** can run in any order once 9 is in.

## Open questions

1. **Settings:** where does Personalise live? A KrissOS page in COSMIC Settings, or a small
   window of our own from the shell.
2. **Snap previews:** can a layer-shell overlay draw the snap preview with cosmic-comp's
   existing tiling hooks, or must it go in the compositor patch?
3. **Gestures:** does cosmic-comp let us bind three-finger swipes, or do they need the patch too?
