# KrissOS Shell

The KrissOS desktop: one floating bottom bar, a Windows-style launcher, notifications and a
lock screen, written in QML for [Quickshell](https://quickshell.org) and running on
`cosmic-comp`. Packaged as `pkgs/kriss-shell`; SDDM lists it as **KrissOS Shell**.

| Path | What it is |
|---|---|
| `qml/` | The shell. `shell.qml` is the entry point. Colours and fonts are `{{token}}` placeholders filled from `theme/tokens.json` at build time |
| `kriss-shell-toplevels` | Python helper that lists open windows and focuses, minimizes or closes them. Quickshell can't read windows from cosmic-comp directly |
| `protocols/` | COSMIC protocol files the helper's bindings are generated from |
| `session/kriss-shell` | Starts the session, and handles `kriss-shell launcher` / `kriss-shell lock` |
| `cosmic/` | Defaults copied into `~/.config/cosmic` on first start: the Windows key opens the launcher, Windows+L locks, and the focused window gets the Sky Cyan ring. Existing user values are left alone |
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
