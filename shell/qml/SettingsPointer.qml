import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Bluetooth and devices > Mouse, and Touchpad: cosmic-comp's input settings
// (com.system76.CosmicComp/v1/input_default and input_touchpad), which it follows at once.
// The page reads the fields it shows from the file and writes them back as one value.
// ponytail: fields it doesn't show (calibration, map_to_output, the scroll button) are not
// kept when it writes; COSMIC Settings sets none of them for a mouse or touchpad either.
Column {
    id: page
    spacing: Theme.s3

    property bool touchpad: false
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/cosmic/com.system76.CosmicComp/v1/" + (touchpad ? "input_touchpad" : "input_default")
    FileView { id: conf; path: page.file; watchChanges: true; printErrors: false; onFileChanged: reload() }

    // What the file says, with libinput's defaults (and Windows' for a touchpad) where it says nothing.
    readonly property string text: conf.text() ?? ""
    function pick(re, fallback) { const m = re.exec(text); return m ? m[1] : fallback; }
    readonly property var cur: ({
        state: pick(/state:\s*(\w+)/, "Enabled"),
        speed: +pick(/speed:\s*(-?[\d.]+)/, "0"),
        flat: pick(/profile:\s*Some\((\w+)\)/, "Adaptive") === "Flat",
        natural: pick(/natural_scroll:\s*Some\((\w+)\)/, touchpad ? "true" : "false") === "true",
        scroll: +pick(/scroll_factor:\s*Some\(([\d.]+)\)/, "1"),
        leftHanded: pick(/left_handed:\s*Some\((\w+)\)/, "false") === "true",
        tap: pick(/tap_config:\s*Some\(\(\s*enabled:\s*(\w+)/, "true") === "true",
        typing: pick(/disable_while_typing:\s*Some\((\w+)\)/, "true") === "true"
    })
    function write(change) {
        const c = Object.assign({}, cur, change), f = v => Number(v).toFixed(2);
        let ron = "(\n    state: " + c.state + ",\n"
            + "    acceleration: Some((profile: Some(" + (c.flat ? "Flat" : "Adaptive") + "), speed: " + f(c.speed) + ")),\n"
            + "    left_handed: Some(" + c.leftHanded + "),\n"
            + "    scroll_config: Some((method: " + (touchpad ? "Some(TwoFinger)" : "None") + ", natural_scroll: Some(" + c.natural + "), scroll_button: None, scroll_factor: Some(" + f(c.scroll) + "))),\n";
        if (touchpad) ron += "    disable_while_typing: Some(" + c.typing + "),\n"
            + "    tap_config: Some((enabled: " + c.tap + ", button_map: Some(LeftRightMiddle), drag: true, drag_lock: false)),\n";
        ron += ")\n";
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1.new" && mv -f "$1.new" "$1"', "sh", file, ron]);
    }

    SettingsUi.Card {
        visible: page.touchpad
        SettingsUi.Choice {
            text: Tr.t("Touchpad")
            value: page.cur.state
            options: [["Enabled", Tr.t("On")], ["DisabledOnExternalMouse", Tr.t("Off when a mouse is connected")], ["Disabled", Tr.t("Off")]]
            onPicked: v => page.write({ state: v })
        }
    }

    SettingsUi.Card {
        SettingsUi.Slider {
            text: page.touchpad ? Tr.t("Touchpad speed") : Tr.t("Mouse pointer speed")
            glyph: "mouse"
            canMute: false
            value: (page.cur.speed + 1) / 2
            onMoved: v => page.write({ speed: v * 2 - 1 })
        }
        SettingsUi.Toggle {
            text: Tr.t("Enhance pointer precision")
            detail: Tr.t("The pointer goes further when you move faster. Off is steadier for games.")
            checked: !page.cur.flat
            onToggled: page.write({ flat: checked })
        }
        SettingsUi.Toggle {
            visible: !page.touchpad
            text: Tr.t("Swap the left and right buttons")
            checked: page.cur.leftHanded
            onToggled: page.write({ leftHanded: !checked })
        }
    }

    SettingsUi.Card {
        SettingsUi.Toggle {
            text: Tr.t("Natural scrolling")
            detail: page.touchpad ? Tr.t("Content moves the way your fingers do, as on a phone.") : Tr.t("The wheel moves the page, not the view, as on a Mac.")
            checked: page.cur.natural
            onToggled: page.write({ natural: !checked })
        }
        SettingsUi.Choice {
            text: Tr.t("Scrolling speed")
            value: String(page.cur.scroll)
            options: [["0.5", Tr.t("Slow")], ["1", Tr.t("Normal")], ["1.5", Tr.t("Fast")], ["2", Tr.t("Faster")]]
            onPicked: v => page.write({ scroll: +v })
        }
    }

    SettingsUi.Card {
        visible: page.touchpad
        SettingsUi.Toggle {
            text: Tr.t("Tap to click")
            detail: Tr.t("Tap with one finger to click, two to right-click.")
            checked: page.cur.tap
            onToggled: page.write({ tap: !checked })
        }
        SettingsUi.Toggle {
            text: Tr.t("Turn off while typing")
            checked: page.cur.typing
            onToggled: page.write({ typing: !checked })
        }
        SettingsUi.Label { text: Tr.t("Gestures") }
        SettingsUi.Note { text: Tr.t("Two fingers scroll. Three fingers: swipe up for Task View, left or right to switch desktops.") }
    }
}
