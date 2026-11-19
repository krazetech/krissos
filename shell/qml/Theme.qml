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

    // The accent the user picked (any colour; Sky Cyan by default), adjusted per mode so
    // it stands out 3:1 from light windows too, and its shades. Black or white text on it.
    readonly property string chosenAccent: T.parseColor(Desktop.accent) ?? T.parseColor("{{accent}}")
    readonly property var shade: T.shades(chosenAccent, dark, "{{surface}}", "{{light_bg}}")
    readonly property color accent: high ? "{{hc_accent}}" : shade.accent
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
    // Nearly opaque, so panels stay readable where the compositor does not blur behind them.
    readonly property color bar: high ? "{{hc_bg}}" : alpha(dark ? "{{surface}}" : "{{light_bg}}", dark ? 0.9 : 0.96)
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
    readonly property int barRadius: 10    // hover and active backgrounds in the bar
    readonly property int trayIcon: 18
    // Between the bar and the panels that open from it, and from the screen's edge.
    readonly property int panelGap: 12
    readonly property int gap: 16
    readonly property int radius: 22
    readonly property int radiusSmall: 14

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
        else return "error: expected accent #RRGGBB or mode dark|light|system|auto";
        return "ok";
    }

    // Switches GTK and Qt apps (through the GNOME setting, which the Flatpak portal reads
    // too) and COSMIC apps and the compositor (through COSMIC's own theme mode) with the
    // shell. In "system" the GNOME setting leads, so only COSMIC's mode is written.
    function syncMode() {
        Quickshell.execDetached(["sh", "-c",
            '[ "$3" = system ] || gsettings set org.gnome.desktop.interface color-scheme "$1"; ' +
            'd="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTheme.Mode/v1"; ' +
            '[ "$(cat "$d/is_dark" 2>/dev/null)" = "$2" ] || { mkdir -p "$d" && printf %s "$2" > "$d/is_dark"; }',
            "sh", dark ? "prefer-dark" : "default", dark ? "true" : "false", mode]);
    }
    onDarkChanged: syncMode()
    onModeChanged: syncMode()
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
