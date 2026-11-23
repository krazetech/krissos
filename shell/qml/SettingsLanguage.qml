import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Time and language > Language and region: English or Bahasa Melayu for KrissOS
// and the apps that have it, and the formats for dates and numbers. Written to your own
// ~/.config/locale.conf, which the login reads (/etc/profile.d/locale.sh); it takes effect at
// the next sign-in. Both locales are generated on every KrissOS install.
Column {
    id: page
    spacing: Theme.s3

    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/locale.conf"
    FileView { id: conf; path: page.file; watchChanges: true; printErrors: false; onFileChanged: reload() }
    readonly property string lang: (/^LANG=(\w+)/m.exec(conf.text() ?? "")?.[1] ?? Tr.lang) .startsWith("ms") ? "ms" : "en"
    readonly property string formats: /^LC_TIME=(\w+)/m.exec(conf.text() ?? "")?.[1] ?? (Qt.locale().name.startsWith("ms") ? "ms_MY" : "en_US")
    property bool changed: false
    function write(lang, formats) {
        const l = lang === "ms" ? "ms_MY.UTF-8" : "en_US.UTF-8", f = formats + ".UTF-8";
        const text = "LANG=" + l + "\nLANGUAGE=" + (lang === "ms" ? "ms:en" : "en") + "\n"
            + ["LC_TIME", "LC_NUMERIC", "LC_MONETARY", "LC_PAPER", "LC_MEASUREMENT"].map(k => k + "=" + f).join("\n") + "\n";
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1.new" && mv -f "$1.new" "$1"', "sh", file, text]);
        changed = true;
    }

    SettingsUi.Card {
        SettingsUi.Choice {
            text: Tr.t("Language")
            detail: Tr.t("For KrissOS and the apps that have it.")
            value: page.lang
            options: [["en", "English"], ["ms", "Bahasa Melayu"]]
            onPicked: v => page.write(v, page.formats)
        }
        SettingsUi.Choice {
            text: Tr.t("Regional format")
            detail: Tr.t("Dates, times, numbers and money.")
            value: page.formats
            options: [["ms_MY", Tr.t("Malaysia")], ["en_US", Tr.t("United States")]]
            onPicked: v => page.write(page.lang, v)
        }
        SettingsUi.Note { visible: page.changed; text: Tr.t("Sign out and back in to see the change.") }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "keyboard"
            text: Tr.t("Typing in other languages")
            detail: Tr.t("Chinese, Tamil and Jawi; Windows+Space switches")
            onPicked: SettingsPages.open("keyboard")
        }
    }
}
