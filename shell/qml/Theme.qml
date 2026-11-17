// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colours and fonts come from theme/tokens.json: theme/generate.py fills in every
// placeholder below when kriss-shell is built. Edit the tokens, not the values here.
Singleton {
    id: root

    // Follows the desktop-wide preference that GTK and Qt apps read too, so the shell
    // and the windows switch together.
    property bool dark: true

    readonly property color accent: "{{accent}}"
    readonly property color accentInk: "{{bg}}"
    readonly property color red: "{{color1}}"
    readonly property color green: "{{color2}}"

    // Window and panel surfaces.
    readonly property color win: dark ? "{{surface}}" : "{{light_bg}}"
    readonly property color fg: dark ? "{{fg}}" : "{{light_fg}}"
    readonly property color card: dark ? Qt.tint("{{surface}}", alpha("{{fg}}", 0.06)) : "{{light_surface}}"
    // Secondary text is the main text colour softened, because the muted token is too dim
    // on raised cards (3.8:1 against the 4.5:1 that body text needs).
    readonly property color soft: Qt.tint(card, alpha(fg, 0.66))
    readonly property color line: alpha(fg, dark ? 0.10 : 0.12)
    // Nearly opaque, so panels stay readable where the compositor does not blur behind them.
    readonly property color bar: alpha(dark ? "{{surface}}" : "{{light_bg}}", dark ? 0.9 : 0.96)
    readonly property color rim: dark ? alpha("{{fg}}", 0.08) : alpha("{{light_surface}}", 0.6)

    // The lock screen and wallpaper are always dark.
    readonly property color night: "{{bg}}"
    readonly property color nightFg: "{{fg}}"

    readonly property string sans: "{{font_sans}}"
    readonly property string mono: "{{font_mono}}"

    // Geometry is not a token: it only lives here.
    readonly property int barHeight: 60
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
    readonly property color cardHover: Qt.tint(card, alpha(fg, 0.12))
    readonly property real pressScale: 0.95

    // Switches the shell, GTK and Qt apps (through the GNOME setting) and COSMIC apps and
    // the compositor (through COSMIC's own theme mode) together.
    function setDark(on) {
        dark = on;
        Quickshell.execDetached(["sh", "-c",
            'gsettings set org.gnome.desktop.interface color-scheme "$1"; ' +
            'd="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTheme.Mode/v1"; ' +
            'mkdir -p "$d" && printf %s "$2" > "$d/is_dark"',
            "sh", on ? "prefer-dark" : "default", on ? "true" : "false"]);
    }

    function alpha(c, a) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: line => root.dark = line.indexOf("light") < 0 && line.indexOf("default") < 0
        }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: line => root.dark = line.indexOf("light") < 0 && line.indexOf("default") < 0
        }
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
