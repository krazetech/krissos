pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "theme.js" as T

// Colours and fonts come from theme/tokens.json: theme/generate.py fills in every
// placeholder below when kriss-shell is built. Edit the tokens, not the values here.
// The accent and light or dark are the user's, from shell.json (Desktop.qml), with the
// tokens as defaults; everything below follows them live.
Singleton {
    id: root

    // "dark", "light", "system" (follows color-scheme, which GTK and Qt apps read too) or
    // "auto" (light from themeLight until themeDark, HH:MM). Anything else is "system".
    readonly property string mode: T.isMode(Desktop.theme) ? Desktop.theme : "system"
    property bool systemDark: true
    property int now: minutesNow()  // minutes after midnight, for "auto"
    function minutesNow() { const d = new Date(); return d.getHours() * 60 + d.getMinutes(); }
    readonly property bool dark: mode === "dark" || mode === "system" && systemDark
        || mode === "auto" && !T.lightAt(now, Desktop.themeLight, Desktop.themeDark)

    // High contrast ("contrast": "high" in shell.json): pure black and white, a stronger
    // accent, solid surfaces with no see-through, and thicker rims. The hc_ tokens.
    readonly property bool high: Desktop.contrast === "high"
    readonly property int rimWidth: high ? 2 : 1     // panel and card borders
    readonly property int focusWidth: high ? 3 : 2   // the keyboard focus rim (FocusRim.qml)

    // The desktop-wide text size (GNOME's text-scaling-factor, which GTK apps follow; COSMIC
    // has no setting of its own yet). Every font size goes through sp().
    property real textScale: 1
    function sp(px) { return Math.round(px * textScale); }
    // Panel widths and other room around text grow half as fast as the text, never shrink:
    // at 150% text a 336 px panel is 420 px, so labels fit without the panels taking over.
    function dp(px) { return Math.round(px * Math.max(1, (1 + textScale) / 2)); }

    // The accent the user picked (any colour; Sky Cyan by default) and its shades, from
    // theme.js. `accent` fills tiles, chips and switches in the picked colour, with
    // `accentInk` (black or white) on it. `accentText` is for the accent on a card or the
    // page: text, links, icons and thin rims, deepened or lightened to 4.5:1 for this mode.
    readonly property string chosenAccent: T.parseColor(Desktop.accent) ?? T.parseColor("{{accent}}")
    readonly property var shade: T.shades(chosenAccent, dark, T.surfaces(dark, {
        bg: "{{bg}}", surface: "{{surface}}", fg: "{{fg}}",
        light_bg: "{{light_bg}}", light_surface: "{{light_surface}}", light_fg: "{{light_fg}}" }))
    readonly property color accent: high ? "{{hc_accent}}" : shade.accent
    readonly property color accentText: high ? "{{hc_accent}}" : shade.text
    readonly property color accentInk: high ? "{{bg}}" : shade.ink
    readonly property color accentHover: high ? "{{hc_accent}}" : shade.hover
    readonly property color accentPressed: high ? "{{hc_accent}}" : shade.pressed
    // KrissOS-safe accents for the settings page: each one passes shell/theme-check.
    readonly property var accents: [
        { name: Tr.t("Sky Cyan"), color: "{{accent}}" },
        { name: Tr.t("Teal"), color: "#2EC4A9" },
        { name: Tr.t("Green"), color: "#57C785" },
        { name: Tr.t("Amber"), color: "#E8B04B" },
        { name: Tr.t("Coral"), color: "#F07A73" },
        { name: Tr.t("Rose"), color: "#EE6FA0" },
        { name: Tr.t("Violet"), color: "#B98CF0" },
        { name: Tr.t("Blue"), color: "#5A9BF0" }
    ]
    readonly property color red: high ? "{{hc_red}}" : "{{color1}}"
    readonly property color green: "{{color2}}"

    // Window and panel surfaces.
    readonly property color win: high ? "{{hc_bg}}" : dark ? "{{surface}}" : "{{light_bg}}"
    readonly property color fg: high ? "{{hc_fg}}" : dark ? "{{fg}}" : "{{light_fg}}"
    readonly property color card: high ? "{{hc_card}}" : dark ? Qt.tint("{{surface}}", alpha("{{fg}}", 0.06)) : "{{light_surface}}"
    // Secondary text is the main text colour softened, because the muted token is too dim
    // on raised cards (3.8:1 against the 4.5:1 that body text needs).
    readonly property color soft: high ? "{{hc_fg}}" : Qt.tint(card, alpha(fg, 0.66))
    readonly property color line: high ? "{{hc_fg}}" : alpha(fg, dark ? 0.10 : 0.12)
    // A slider's or meter's empty track: unlike a hairline, it must show 3:1.
    readonly property color track: high ? "{{hc_fg}}" : alpha(fg, T.trackAlpha)
    // Acrylic: the tint every shell surface puts over the compositor's blur (the bar, Start,
    // panels, toasts, the OSD, menus). Nearly opaque, so it stays readable where the
    // compositor does not blur. Solid with high contrast or "transparency": false in shell.json.
    readonly property bool solid: high || !Desktop.transparency
    readonly property color bar: solid ? win : alpha(dark ? "{{surface}}" : "{{light_bg}}", dark ? 0.9 : 0.96)
    readonly property color rim: high ? "{{hc_fg}}" : dark ? alpha("{{fg}}", 0.08) : alpha("{{light_surface}}", 0.6)

    // The lock screen and wallpaper are always dark.
    readonly property color night: "{{bg}}"
    readonly property color nightFg: "{{fg}}"

    // kriss-theme's wallpapers. KRISS_WALLPAPERS points elsewhere, for a nested test of a
    // theme/generate.py build that is not installed yet.
    readonly property string wallpapers: Quickshell.env("KRISS_WALLPAPERS") || "/usr/share/backgrounds/kriss"

    readonly property string sans: "{{font_sans}}"
    readonly property string mono: "{{font_mono}}"

    // Geometry is not a token: it only lives here.
    // The taskbar, sized like Windows 11's: 48 tall, 40 px buttons, 24 px icons.
    // They grow half as fast as the text, so the two-line clock still fits at large text sizes.
    // Small and large scale all three, from Personalise's taskbar size.
    readonly property real barScale: ({ small: 0.84, large: 1.17 })[Desktop.taskbarSize] ?? 1
    readonly property int barHeight: Math.round(48 * barScale * Math.max(1, (1 + textScale) / 2))
    readonly property int barButton: Math.round(40 * barScale * Math.max(1, (1 + textScale) / 2))
    readonly property int barIcon: Math.round(24 * barScale)
    readonly property int trayIcon: 18
    // The Mac layout: the slim top bar, and the room between the dock and the screen's edge.
    readonly property int topBarHeight: Math.round(32 * Math.max(1, (1 + textScale) / 2))
    readonly property int dockGap: 8
    // The dock is bigger than the taskbar, as a dock is: 60 tall, 52 px buttons, 40 px icons,
    // with the same Small, Medium and Large and the same growth with the text.
    readonly property int dockHeight: Math.round(60 * barScale * Math.max(1, (1 + textScale) / 2))
    readonly property int dockButton: Math.round(52 * barScale * Math.max(1, (1 + textScale) / 2))
    readonly property int dockIcon: Math.round(40 * barScale)
    // Between the bar and the panels that open from it, and from the screen's edge.
    readonly property int panelGap: 12
    readonly property int gap: 16
    // The radius scale. Every shape uses one of these, or height / 2 for a pill or a dot
    // (shell/theme-check fails on a literal radius). A shape inside another follows the
    // outer one: rPanel around rCard, rCard around rControl.
    readonly property int rPanel: 22    // Start, quick settings, the calendar, notifications
    readonly property int rCard: 14     // menus, previews, notification and widget cards
    readonly property int rControl: 10  // rows, buttons, bar hovers, tiles' insides
    readonly property int rSmall: 6     // key caps, close buttons, chips inside a row
    // The spacing scale, on a 4 px grid (s0 is the hairline between two lines of text).
    readonly property int s0: 2
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 20
    readonly property int s6: 24

    // Reduced motion: the desktop-wide "animations off" switch (GNOME's enable-animations,
    // which COSMIC and GTK apps follow too). Every duration goes through ms().
    property bool reduceMotion: false
    function ms(duration) { return reduceMotion ? 0 : duration; }

    // Motion: every animation takes its length from these, through ms().
    readonly property int fast: 140    // hover, press, fades, small moves
    readonly property int normal: 220  // a panel opening, a list growing
    readonly property int slow: 500    // the quick settings sheet (Vaul's length)
    // And one set of curves: an ease out for anything arriving, hover and press; Vaul's
    // long soft ease out for the sheet; Sonner's, with a touch of settle, for the toasts.
    readonly property int ease: Easing.OutCubic
    // Leaving is quicker than arriving, and eases in: a panel gets out of the way.
    readonly property int easeExit: Easing.InCubic
    readonly property int fastExit: Math.round(fast * 0.8)
    readonly property var sheetCurve: [0.32, 0.72, 0, 1, 1, 1]
    readonly property var settleCurve: [0.21, 1.02, 0.73, 1, 1, 1]
    // Hover and press: a control lights up a little and gives slightly under the pointer.
    readonly property color cardHover: high ? "{{hc_hover}}" : Qt.tint(card, alpha(fg, 0.12))
    readonly property real pressScale: 0.95

    // The quick settings switch: picks light or dark outright, leaving "system" and "auto".
    function setDark(on) {
        Desktop.theme = on ? "dark" : "light";
    }

    // `theme set accent "#hex"` / `theme set mode dark|light|system|auto`, for the settings
    // page. Saves to shell.json; the bindings above and the watchers below do the rest.
    function set(key, value) {
        if (key === "accent" && T.parseColor(value)) Desktop.accent = T.parseColor(value);
        else if (key === "mode" && T.isMode(value)) Desktop.theme = value;
        else if (key === "cursor" && /^[A-Za-z0-9_.+-]*$/.test(value)) Desktop.cursorTheme = value;
        else if (key === "cursorSize" && +value >= 16 && +value <= 128) Desktop.cursorSize = Math.round(+value);
        else return "error: expected accent #RRGGBB, mode dark|light|system|auto, cursor NAME (empty for Breeze) or cursorSize 16-128";
        return "ok";
    }

    // Switches GTK and Qt apps (through the GNOME setting, which the Flatpak portal reads
    // too) and COSMIC apps and the compositor (through COSMIC's own theme mode) with the
    // shell. In "system" the GNOME setting leads, so only COSMIC's mode is written.
    // One write, once mode and dark have both settled: a change to mode fires both handlers,
    // and two writers racing could leave COSMIC on the old value. The file is replaced in one
    // step, as cosmic-config does, and COSMIC's own sunrise switch is turned off, since the
    // shell's "auto" decides.
    function syncMode() { syncLater.restart(); }
    Timer {
        id: syncLater
        interval: 50
        onTriggered: Quickshell.execDetached(["sh", "-c",
            '[ "$3" = system ] || gsettings set org.gnome.desktop.interface color-scheme "$1"; ' +
            'd="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTheme.Mode/v1"; mkdir -p "$d" || exit; ' +
            '[ "$(cat "$d/auto_switch" 2>/dev/null)" = false ] || { printf false > "$d/.auto_switch.new" && mv -f "$d/.auto_switch.new" "$d/auto_switch"; }; ' +
            '[ "$(cat "$d/is_dark" 2>/dev/null)" = "$2" ] || { printf %s "$2" > "$d/.is_dark.new" && mv -f "$d/.is_dark.new" "$d/is_dark"; }',
            "sh", root.dark ? "prefer-dark" : "default", root.dark ? "true" : "false", root.mode])
    }
    onDarkChanged: syncMode()
    onModeChanged: syncMode()

    // The mouse pointer: Breeze, its dark cursor on the light theme and its light one on the
    // dark theme (also as "auto" turns), unless the user picked a theme ("cursorTheme").
    // Written for the compositor (org.krissos.Cursor, read live by cosmic-comp-kriss, which
    // also hands it to XWayland), GTK (the GNOME setting and settings.ini; Flatpak through the
    // portal), Qt and KDE apps (kcminputrc), and apps that only know the "default" theme.
    readonly property string cursorTheme: Desktop.cursorTheme !== "" ? Desktop.cursorTheme
        : dark ? "{{cursor_theme}}" : "{{cursor_theme_light}}"
    readonly property int cursorSize: Desktop.cursorSize >= 16 && Desktop.cursorSize <= 128 ? Desktop.cursorSize : 24
    onCursorThemeChanged: syncCursorLater.restart()
    onCursorSizeChanged: syncCursorLater.restart()
    Component.onCompleted: syncCursorLater.restart()
    Timer {
        id: syncCursorLater
        interval: 50
        onTriggered: Quickshell.execDetached(["sh", "-c", `
            c=\${XDG_CONFIG_HOME:-$HOME/.config}
            put() { mkdir -p "$1" && printf %s "$3" > "$1/.$2.new" && mv -f "$1/.$2.new" "$1/$2"; }
            put "$c/cosmic/org.krissos.Cursor/v1" theme "\\"$1\\""
            put "$c/cosmic/org.krissos.Cursor/v1" size "$2"
            gsettings set org.gnome.desktop.interface cursor-theme "$1"
            gsettings set org.gnome.desktop.interface cursor-size "$2"
            for f in "$c/gtk-3.0/settings.ini" "$c/gtk-4.0/settings.ini"; do
                [ -f "$f" ] || continue
                sed -i -e "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$1/" -e '/^gtk-cursor-theme-size=/d' "$f"
                sed -i "/^gtk-cursor-theme-name=/a gtk-cursor-theme-size=$2" "$f"
            done
            command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$1" && kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize "$2"
            mkdir -p "$HOME/.icons/default" && printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$1" > "$HOME/.icons/default/index.theme"`,
            "sh", root.cursorTheme, String(root.cursorSize)])
    }
    // COSMIC builds its own accent shades with libcosmic's ThemeBuilder.
    onChosenAccentChanged: Quickshell.execDetached(["kriss-cosmic-theme", "--accent", chosenAccent])

    Timer {
        running: true
        interval: 60000
        repeat: true
        onTriggered: root.now = root.minutesNow()
    }

    function alpha(c, a) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: line => root.systemDark = line.indexOf("light") < 0 && line.indexOf("default") < 0
        }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: line => root.systemDark = line.indexOf("light") < 0 && line.indexOf("default") < 0
        }
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "text-scaling-factor"]
        running: true
        stdout: SplitParser { onRead: line => root.textScale = Math.max(0.5, Math.min(3, parseFloat(line) || 1)) }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "text-scaling-factor"]
        running: true
        stdout: SplitParser { onRead: line => root.textScale = Math.max(0.5, Math.min(3, parseFloat(line.split(":").pop()) || 1)) }
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        running: true
        stdout: SplitParser { onRead: line => root.reduceMotion = line.trim() === "false" }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "enable-animations"]
        running: true
        stdout: SplitParser { onRead: line => root.reduceMotion = line.indexOf("false") >= 0 }
    }
}
