# KrissOS Shell

The KrissOS desktop: a full-width taskbar along the bottom edge of each screen with a system tray, a
Windows-style launcher, quick settings, notifications and a lock screen, written in QML for
[Quickshell](https://quickshell.org) and running on `cosmic-comp`. Packaged as `pkgs/kriss-shell`;
SDDM lists it as **KrissOS Shell**.

| Path | What it is |
|---|---|
| `qml/` | The shell. `shell.qml` is the entry point. Colours and fonts are `{{token}}` placeholders filled from `theme/tokens.json` at build time |
| `qml/i18n/` | Translations, one `<lang>.json` per language (`ms` is Bahasa Melayu). See below |
| `fuzzy-check` | Tests the launcher's fuzzy ranking and the menus' type-ahead: `node shell/fuzzy-check` |
| `i18n-check` | Checks every shell string has a translation; `--list` prints them all |
| `kriss-shell-toplevels` | Python helper that lists open windows (and the screen each is on), focuses, minimizes or closes them, and captures the taskbar's window previews while they are shown. Quickshell can't read or capture windows from cosmic-comp directly |
| `toplevels-check` | Run inside a cosmic-comp session: checks `kriss-shell-toplevels` still sees a new window after Python's garbage collector runs (`shell/toplevels-check alacritty`; cosmic-term by default) |
| `protocols/` | COSMIC protocol files the helper's bindings are generated from |
| `session/kriss-shell` | Starts the session and the login screen, and handles the commands the shortcuts below run |
| `cosmic/` | Defaults copied key by key into `~/.config/cosmic` (same layout) on first start: the shortcuts below, the KrissOS theme builder keys (accent, backgrounds, corners), no coloured ring around the focused window, Papirus icons and the COSMIC Terminal colours. Existing user values are left alone |
| `cosmic-theme/` | Builds the full COSMIC dark and light themes from those builder keys with libcosmic's own ThemeBuilder, at package build time |
| `mockup/index.html` | The approved concept |

## Run it nested for development

On a Linux desktop (Wayland or X11), cosmic-comp opens as a window, and the shell runs inside it.
You need `cosmic-comp quickshell python-pywayland wayland-protocols` installed.

```bash
dev=/tmp/kriss-shell-dev
python theme/generate.py shell/qml "$dev/qml"
python theme/generate.py shell/cosmic "$dev/config/cosmic"
XDG_CONFIG_HOME=$dev/config cargo run --release --manifest-path shell/cosmic-theme/Cargo.toml
ln -sfn config/cosmic "$dev/cosmic"
python -m pywayland.scanner -o "$dev/lib/kriss_protocols" -i /usr/share/wayland/wayland.xml \
  /usr/share/wayland-protocols/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml \
  /usr/share/wayland-protocols/staging/ext-workspace/ext-workspace-v1.xml \
  /usr/share/wayland-protocols/staging/ext-image-capture-source/ext-image-capture-source-v1.xml \
  /usr/share/wayland-protocols/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml shell/protocols/*.xml
touch "$dev/lib/kriss_protocols/__init__.py"
KRISS_SHELL_DATA=$dev KRISS_SHELL_LIB=$dev/lib PATH="$PWD/shell:$PWD/shell/session:$PATH" \
  cosmic-comp shell/session/kriss-shell --inside
```

Nested like this, cosmic-comp runs in kiosk mode, which turns its keyboard shortcuts off, so the
Windows key does nothing there. A real session (`kriss-shell` with no arguments, which SDDM runs)
starts cosmic-comp normally and copies the `cosmic/` defaults into `~/.config/cosmic`.

After editing a QML file, re-run the first `generate.py` line. Quickshell reloads most
changes on its own; restart cosmic-comp if a change doesn't show. Logs: `qs log -p "$dev/qml"`.

To try a surface without the keyboard shortcuts, run these from a terminal inside the nested
session:

```bash
kriss-shell launcher
```
```bash
kriss-shell lock
```
```bash
qs -p "$dev/qml" ipc call previews open Alacritty 400
```
```bash
notify-send -A ok=Update "14 updates ready" "A snapshot is taken first."
```
```bash
gsettings set org.gnome.desktop.interface color-scheme default
```

The `previews` line shows the window previews of an app (by its app id) as if its taskbar
button were 400 px from the left; `ipc call previews close` hides them. The nested session has no
way to move a pointer there otherwise. The last one switches to the light variant;
`prefer-dark` switches back.

## Performance check

`shell/perf-check` measures the running shell against the budget: idle CPU over 10 seconds and
memory (RSS and PSS) for `qs` and every process it started, then frame pacing for each surface.
For the frames it opens a nested cosmic-comp window running the same QML with Qt's render timing,
opens and closes the launcher, quick settings, notifications, the calendar and Show desktop
through their IPC commands, and sends a toast. A frame fails if it arrives a refresh late in the
nested window (60 Hz), or takes longer to build than one refresh of your fastest monitor.

```bash
shell/perf-check
```

It prints one line per check and exits 1 on any FAIL. `--json` prints the numbers for a pull
request, and `--no-frames` skips the nested window. A surface that drew nothing (Show desktop
with no windows open) is SKIP.

## Login screen

`qml/greeter.qml` is the login screen. It looks like the lock screen, lists other users at the
bottom left and the desktop to start at the bottom right. [greetd](https://sr.ht/~kennylevinsen/greetd/)
runs it on cosmic-comp. To use it, put this in `/etc/greetd/config.toml` and enable `greetd`
in place of SDDM:

```toml
[terminal]
vt = 1

[default_session]
command = "kriss-shell greeter"
user = "greeter"
```

## Motion and keyboard

The behaviour follows four web references, rebuilt in QML: the launcher search works
like [cmdk](https://cmdk.paco.me), notifications stack like [Sonner](https://sonner.emilkowal.ski),
quick settings is a sheet like [Vaul](https://vaul.emilkowal.ski), and the clock, battery and
volume digits roll like [NumberFlow](https://number-flow.barvian.me). Menus follow Radix's
keyboard rules. Every animation goes through `Theme.ms()`, which is 0 when
`org.gnome.desktop.interface enable-animations` is off.

## Settings

Pinned apps (in taskbar order) and Do not disturb are kept in `~/.config/kriss/shell.json`.
Right-click an app on the bar or in the launcher to pin or unpin it; drag a pinned app along the
bar to move it. Without the file, the defaults in `qml/Desktop.qml` apply. **Taskbar settings**
(right-click an empty part of the bar) opens this file until a Personalise page exists.

| Key | Default | Does |
|---|---|---|
| `pinned` | Firefox, Files, Terminal… | Pinned apps, as desktop file ids, in taskbar order |
| `dnd` | `false` | Do not disturb |
| `taskbarAlignment` | `"left"` | `"centre"` centres Start, search and the apps, and Start opens above them, as on Windows 11 |
| `taskbarAutoHide` | `false` | The bar slides off the bottom edge and comes back when the pointer reaches it |
| `taskbarCombine` | `"always"` | `"always"`: one button per app. `"never"`: one button per window, with its title. `"full"`: per window until the bar runs out of room |
| `taskbarAllScreens` | `true` | A bar on every screen, each with the windows on that screen; `false`: one bar, on the first screen, with every window |

## Taskbar

It behaves like Windows 11's. Each app has one button, pinned or not, with all its windows on it.

| Do | Does |
|---|---|
| Click | Opens the app; with one window, brings it up, or minimizes it when it is in front; with several, brings up the last one used, then steps through the others |
| Ctrl+click | Steps through the app's windows (never minimizes) |
| Shift+click, middle click | A new window |
| Right-click an app | Jump list: recent files for the app, its own tasks (desktop file actions), the app, pin or unpin, close window or close all windows |
| Right-click Start, Windows+X | Installed apps, power options, system, network, Terminal, Task Manager, Settings, Files, Search, Shut down or sign out, Desktop |
| The search box | Start, ready to search: the search field and Recommended files |
| Right-click the bar | Task Manager (the first system monitor installed) and Taskbar settings |
| The strip right of the clock | Show the desktop; again to bring the windows back |

Under each button: a short mark for a running app and a longer accent pill for the app in front.
Apps that send Unity launcher entries over D-Bus (the way Ubuntu's dock reads them) also get a
badge count, a progress bar and a red flash when they want attention. Menus work from the
keyboard the way Radix menus do (arrows, Home, End, Enter, Esc, Right and Left for submenus,
type a letter to jump). `Bar.previewFor` is the app button under the pointer, for hover previews.

## Windows shortcuts

| Keys | Does |
|---|---|
| Windows | Launcher |
| Windows+A | Quick settings |
| Windows+N | Notifications |
| Windows+Alt+D | Calendar |
| Windows+D | Show the desktop; again to bring the windows back |
| Windows+E | COSMIC Files |
| Windows+L | Lock |
| Menu key, Shift+F10 | In the launcher or on a taskbar button, its menu |
| Windows+T | Put the keyboard on the taskbar buttons, again to step to the next; arrows move, Enter opens, Shift+Enter opens a new window, Esc leaves |
| Windows+X | The Start button's menu |
| Windows+Left / Right | Snap the window to that half (Windows+Shift+Up / Down then makes it a quarter) |
| Windows+Up / Down | Maximize / minimize |
| Windows+1…9 | Open the app on that taskbar button, or switch to it; again to step through its windows |
| Windows+Shift+1…9 | A new window of the app on that taskbar button |
| Windows+Alt+1…9 | That taskbar button's jump list |
| Windows+Ctrl+Left / Right | Previous / next workspace (Windows+Ctrl+Shift+Left / Right takes the window along) |
| Print Screen | Screenshot of everything, to `~/Pictures/Screenshots` and the clipboard |
| Windows+Shift+S | Screenshot of a dragged region |
| Alt+Tab, Alt+Shift+Tab | Switch windows, most recent first; let go of Alt to switch, Esc to cancel |
| Play/Pause, Next, Previous | The media player that is playing; quick settings shows it too |
| Power button | Sleep (hold it to shut down), from `/usr/lib/systemd/logind.conf.d/50-kriss-shell.conf` |
| Alt+F4 | cosmic-comp's own |

## Translations

Quickshell installs no Qt translator, so `qsTr()` would always return English. Shell strings go
through `Tr.t("English text")` instead, which looks the text up in `qml/i18n/<lang>.json` for the
language in `LANGUAGE`, `LC_ALL`, `LC_MESSAGES` or `LANG`. To add a language, save the output of
`shell/i18n-check --list` as `qml/i18n/<lang>.json`, turn the list into
`{"English": "translation"}`, and run `shell/i18n-check` until it is quiet (the package build
runs it too).
