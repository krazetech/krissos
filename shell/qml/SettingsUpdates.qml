import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Updates: update now (`kriss update`, which takes a snapshot first), the update
// channel (`kriss channel stable|testing`), and how to go back to a snapshot. kriss asks for
// the password and shows its progress in a terminal.
Column {
    id: page
    spacing: Theme.s3

    property string channel: ""
    Component.onCompleted: reader.running = true
    Process {
        id: reader
        command: ["kriss", "channel"]
        stdout: StdioCollector { onStreamFinished: page.channel = /testing/.test(text) ? "testing" : "stable" }
    }
    function terminal(args) {
        Quickshell.execDetached(["sh", "-c", 'command -v cosmic-term >/dev/null && exec cosmic-term -- "$@" || exec xdg-terminal-exec "$@"', "sh"].concat(args));
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Updates") }
        SettingsUi.Note { text: Tr.t("Apps, drivers and KrissOS itself update together. A snapshot is taken first, so a bad update can be undone.") }
        SettingsUi.Push { main: true; text: Tr.t("Update now"); onPicked: page.terminal(["kriss", "update"]) }
    }

    SettingsUi.Card {
        visible: page.channel !== ""
        SettingsUi.Choice {
            text: Tr.t("Update channel")
            detail: page.channel === "testing" ? Tr.t("Testing gets updates a few days early, to help catch problems. Going back to Stable can downgrade a few packages, after a snapshot.")
                                               : Tr.t("Stable gets updates once they have been tested.")
            value: page.channel
            options: [["stable", Tr.t("Stable")], ["testing", Tr.t("Testing")]]
            onPicked: v => { if (v !== page.channel) page.terminal(["kriss", "channel", v]); }
        }
        SettingsUi.Push { text: Tr.t("Check again"); onPicked: reader.running = true }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Go back to before an update") }
        SettingsUi.Note { text: Tr.t("Restart, choose KrissOS > Snapshots in the boot menu and pick one from before the update. If it works, open a terminal and run kriss rollback to keep it.") }
    }
}
