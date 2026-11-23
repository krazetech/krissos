import QtQuick
import Quickshell
import Quickshell.Io

// Settings > System > Recovery: Reset this PC, through `kriss reset`. The page shows what it
// will do (`--dry-run`); the reset itself runs in a terminal, where kriss asks for the
// password and for "reset" to be typed, takes a snapshot, and finishes at the next start.
// ponytail: a terminal for the confirmation and progress; move in if kriss reset gets a
// non-interactive mode that polkit can authorise.
Column {
    id: page
    spacing: Theme.s3

    property string mode: "keep-files"
    property string plan: ""
    onModeChanged: planner.running = true
    Component.onCompleted: planner.running = true
    Process {
        id: planner
        command: ["kriss", "reset", "--" + page.mode, "--dry-run"]
        stdout: StdioCollector { onStreamFinished: page.plan = text.trim() }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Reset this PC") }
        SettingsUi.Note { text: Tr.t("Puts KrissOS back the way it was installed. A snapshot is taken first, so you can still go back from the boot menu.") }
        SettingsUi.Choice {
            text: Tr.t("Your files")
            value: page.mode
            options: [["keep-files", Tr.t("Keep my files")], ["everything", Tr.t("Remove everything")]]
            onPicked: v => page.mode = v
        }
        SettingsUi.Note { text: page.mode === "keep-files" ? Tr.t("Apps you added and your settings go. Your files in Home stay.") : Tr.t("Apps you added, your settings, every file in Home and saved Wi-Fi go.") }
        Text {
            visible: page.plan !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: page.plan
            color: Theme.fg
            font { family: Theme.mono; pixelSize: Theme.sp(12) }
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
        SettingsUi.Push {
            text: Tr.t("Reset this PC")
            onPicked: Quickshell.execDetached(["sh", "-c", 'command -v cosmic-term >/dev/null && exec cosmic-term -- "$@" || exec xdg-terminal-exec "$@"',
                "sh", "kriss", "reset", "--" + page.mode])
        }
    }
}
