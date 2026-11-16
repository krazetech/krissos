# KrissOS Shell

The KrissOS desktop: one floating bottom bar with a system tray, a Windows-style launcher,
quick settings, notifications and a lock screen, written in QML for [Quickshell](https://quickshell.org) and running on
`cosmic-comp`. Packaged as `pkgs/kriss-shell`; SDDM lists it as **KrissOS Shell**.

| Path | What it is |
|---|---|
| `qml/` | The shell. `shell.qml` is the entry point. Colours and fonts are `{{token}}` placeholders filled from `theme/tokens.json` at build time |
| `qml/i18n/` | Translations, one `<lang>.json` per language (`ms` is Bahasa Melayu). See below |
| `fuzzy-check` | Tests the launcher's fuzzy ranking and the menus' type-ahead: `node shell/fuzzy-check` |
| `i18n-check` | Checks every shell string has a translation; `--list` prints them all |
| `kriss-shell-toplevels` | Python helper that lists open windows (and the screen each is on) and focuses, minimizes or closes them. Quickshell can't read windows from cosmic-comp directly |
| `protocols/` | COSMIC protocol files the helper's bindings are generated from |
| `session/kriss-shell` | Starts the session and the login screen, and handles the commands the shortcuts below run |
| `cosmic/` | Defaults copied into `~/.config/cosmic` on first start: the shortcuts below, and the Sky Cyan ring on the focused window. Existing user values are left alone |
| `mockup/index.html` | The approved concept |

## Run it nested for development

On a Linux desktop (Wayland or X11), cosmic-comp opens as a window, and the shell runs inside it.
You need `cosmic-comp quickshell python-pywayland wayland-protocols` installed.

```bash
dev=/tmp/kriss-shell-dev
python theme/generate.py shell/qml "$dev/qml"
python theme/generate.py shell/cosmic "$dev/cosmic"
python -m pywayland.scanner -o "$dev/lib/kriss_protocols" -i /usr/share/wayland/wayland.xml \
  /usr/share/wayland-protocols/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml \
  /usr/share/wayland-protocols/staging/ext-workspace/ext-workspace-v1.xml shell/protocols/*.xml
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
notify-send -A ok=Update "14 updates ready" "A snapshot is taken first."
```
```bash
gsettings set org.gnome.desktop.interface color-scheme default
```

The last one switches to the light variant; `prefer-dark` switches back.

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
bar to move it. Without the file, the defaults in `qml/Desktop.qml` apply.

## Windows shortcuts

| Keys | Does |
|---|---|
| Windows | Launcher |
| Windows+A | Quick settings |
| Windows+N | Notifications |
| Windows+D | Show the desktop; again to bring the windows back |
| Windows+E | COSMIC Files |
| Windows+L | Lock |
| Menu key, Shift+F10 | In the launcher, the selected app's menu |
| Windows+Left / Right | Snap the window to that half (Windows+Shift+Up / Down then makes it a quarter) |
| Windows+Up / Down | Maximize / minimize |
| Windows+1…9 | Go to that workspace |
| Windows+Shift+1…9 | Move the window to that workspace |
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
