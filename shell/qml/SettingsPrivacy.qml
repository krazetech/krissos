import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Settings > Privacy: what KrissOS keeps and sends (nothing, past what you see here), the apps
// listening to the microphone right now, and clearing recent files and the clipboard history.
Column {
    id: page
    spacing: Theme.s3

    // Apps recording sound now (PipeWire capture streams).
    readonly property var listening: Pipewire.nodes.values.filter(n => n.audio && n.isStream && !n.isSink)
    property string done: ""

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("KrissOS sends nothing about you") }
        SettingsUi.Note { text: Tr.t("No account, no ads and no usage data. The only things that go out are updates you install, the weather for the city you typed, and a problem report when you choose to send one.") }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Microphone") }
        SettingsUi.Note { text: page.listening.length ? Tr.t("These apps are listening right now:") : Tr.t("No app is listening right now.") }
        Repeater {
            model: page.listening
            SettingsUi.Note {
                required property var modelData
                text: "• " + (modelData.properties?.["application.name"] || modelData.description || modelData.name)
            }
        }
        SettingsUi.LinkRow {
            glyph: "mic"
            text: Tr.t("Sound settings")
            onPicked: SettingsPages.open("sound")
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("History") }
        SettingsUi.Note { text: Tr.t("Start shows the files you opened lately, and Windows+V keeps what you copied. Both stay on this PC.") }
        Row {
            spacing: Theme.s2
            SettingsUi.Push {
                text: Tr.t("Clear recent files")
                onPicked: {
                    Quickshell.execDetached(["sh", "-c", 'f="$HOME/.local/share/recently-used.xbel"; [ -f "$f" ] && printf "%s\\n" "<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>" "<xbel version=\\"1.0\\"></xbel>" > "$f"; true']);
                    page.done = Tr.t("Recent files cleared.");
                }
            }
            SettingsUi.Push {
                text: Tr.t("Clear clipboard history")
                onPicked: {
                    Quickshell.execDetached(["kriss-shell-clipboard", "clear"]);
                    page.done = Tr.t("Clipboard history cleared. Pinned items stay.");
                }
            }
        }
        SettingsUi.Note { visible: page.done !== ""; text: page.done }
    }
}
