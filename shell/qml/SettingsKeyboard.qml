import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Bluetooth and devices > Keyboard: the languages Windows+Space steps through
// (fcitx5's profile, set through fcitx5 so it takes effect at once), how keys repeat when held
// (cosmic-comp's xkb_config, which it follows at once), and a link to the shortcuts.
Column {
    id: page
    spacing: Theme.s3

    // The input methods KrissOS ships, in Windows+Space order. English stays on.
    readonly property var known: [
        ["keyboard-us", Tr.t("English"), Tr.t("The keys as printed")],
        ["pinyin", Tr.t("Chinese (Pinyin)"), Tr.t("Type the sound, pick the character")],
        ["m17n_ta_phonetic", Tr.t("Tamil"), Tr.t("Type \"vanakkam\" for வணக்கம்")],
        ["keyboard-my-phonetic", Tr.t("Jawi"), Tr.t("Each letter on the Latin key that sounds like it")]
    ]
    function setLanguage(name, on) {
        // Keep KrissOS's order, then anything else the user added in fcitx5's own settings.
        const ids = known.map(k => k[0]);
        const want = ids.filter(n => n === "keyboard-us" || (n === name ? on : Ime.list.includes(n)))
            .concat(Ime.list.filter(n => !ids.includes(n)));
        const args = ["busctl", "--user", "call", "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1",
                      "SetInputMethodGroupInfo", "ssa(ss)", "Default", "us", String(want.length)];
        for (const n of want) args.push(n, "");
        Quickshell.execDetached(args);
    }

    readonly property string xkbFile: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/cosmic/com.system76.CosmicComp/v1/xkb_config"
    FileView { id: xkb; path: page.xkbFile; watchChanges: true; printErrors: false; onFileChanged: reload() }
    readonly property string text: xkb.text() ?? ""
    function pick(re, fallback) { const m = re.exec(text); return m ? m[1] : fallback; }
    // cosmic-comp's defaults where the file says nothing.
    readonly property int delay: +pick(/repeat_delay:\s*(\d+)/, "600")
    readonly property int rate: +pick(/repeat_rate:\s*(\d+)/, "25")
    function writeXkb(delay, rate) {
        const q = s => JSON.stringify(s);
        const opts = pick(/options:\s*Some\(("(?:[^"\\]|\\.)*")\)/, "");
        const ron = "(\n"
            + "    rules: " + q(JSON.parse(pick(/rules:\s*("(?:[^"\\]|\\.)*")/, '""'))) + ",\n"
            + "    model: " + q(JSON.parse(pick(/model:\s*("(?:[^"\\]|\\.)*")/, '"pc105"'))) + ",\n"
            + "    layout: " + q(JSON.parse(pick(/layout:\s*("(?:[^"\\]|\\.)*")/, '"us"'))) + ",\n"
            + "    variant: " + q(JSON.parse(pick(/variant:\s*("(?:[^"\\]|\\.)*")/, '""'))) + ",\n"
            + "    options: " + (opts ? "Some(" + opts + ")" : "None") + ",\n"
            + "    repeat_delay: " + Math.round(delay) + ",\n"
            + "    repeat_rate: " + Math.round(rate) + ",\n)\n";
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1.new" && mv -f "$1.new" "$1"', "sh", xkbFile, ron]);
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Languages") }
        SettingsUi.Note {
            text: Ime.sni ? Tr.t("Windows+Space switches between the ones that are on.")
                          : Tr.t("The input method isn't running, so languages can't be changed now.")
        }
        Repeater {
            model: page.known
            SettingsUi.Toggle {
                required property var modelData
                visible: modelData[0] !== "keyboard-us"
                enabled: Ime.sni !== null
                text: modelData[1]
                detail: modelData[2]
                checked: Ime.list.includes(modelData[0])
                onToggled: page.setLanguage(modelData[0], !checked)
            }
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Typing") }
        SettingsUi.Slider {
            text: Tr.t("Repeat delay")
            glyph: "keyboard"
            canMute: false
            // 200 ms (short) to 1000 ms (long).
            value: (page.delay - 200) / 800
            onMoved: v => page.writeXkb(200 + v * 800, page.rate)
        }
        SettingsUi.Note { text: Tr.t("How long to hold a key before it repeats: %1 ms", page.delay) }
        SettingsUi.Slider {
            text: Tr.t("Repeat rate")
            glyph: "keyboard"
            canMute: false
            // 10 to 60 a second.
            value: (page.rate - 10) / 50
            onMoved: v => page.writeXkb(page.delay, 10 + v * 50)
        }
        SettingsUi.Note { text: Tr.t("How fast a held key repeats: %1 a second", page.rate) }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "keyboard"
            text: Tr.t("Keyboard shortcuts")
            detail: Tr.t("See and change the shortcuts")
            external: true
            onPicked: Quickshell.execDetached(["cosmic-settings", "keyboard"])
        }
    }
}
