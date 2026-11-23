import QtQuick
import Quickshell
import Quickshell.Io

// Settings > System > Report a problem, through `kriss report`: it gathers the logs and this
// PC's parts with names, Wi-Fi names and serial numbers taken out. The page shows all of it
// first (`--print`), then opens it as a GitHub issue to submit (`--open`) or saves it to a
// file (`--save`), for when there is no internet.
Column {
    id: page
    spacing: Theme.s3

    property string report: ""
    property string saved: ""
    function args() { return what.text.trim() ? [what.text.trim()] : []; }
    Process {
        id: printer
        command: ["kriss", "report", "--print"].concat(page.args())
        stdout: StdioCollector { onStreamFinished: page.report = text.trim() }
    }
    Process {
        id: saver
        stdout: StdioCollector { onStreamFinished: page.saved = text.trim().replace(/^kriss: /, "") }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Report a problem") }
        SettingsUi.Note { text: Tr.t("Collects the logs and a summary of this PC, so the KrissOS team can see what went wrong. Your name, Wi-Fi names and serial numbers are taken out, and you see it all before anything is sent.") }
        Rectangle {
            width: parent.width
            height: Math.max(36, Theme.sp(14) + 20)
            radius: Theme.rControl
            color: Theme.win
            border.width: what.activeFocus ? Theme.focusWidth : Theme.rimWidth
            border.color: what.activeFocus ? Theme.accentText : Theme.line
            TextInput {
                id: what
                anchors.fill: parent
                anchors.margins: Theme.s2
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentInk
                clip: true
                font { family: Theme.sans; pixelSize: Theme.sp(14) }
                activeFocusOnTab: true
                onAccepted: printer.running = true
                Accessible.role: Accessible.EditableText
                Accessible.name: Tr.t("What went wrong?")
                Text {
                    visible: !parent.text
                    text: Tr.t("What went wrong? (optional)")
                    color: Theme.soft
                    font: parent.font
                }
            }
        }
        SettingsUi.Push {
            text: printer.running ? Tr.t("Collecting…") : Tr.t("Show the report")
            main: page.report === ""
            onPicked: if (!printer.running) printer.running = true
        }
    }

    SettingsUi.Card {
        visible: page.report !== ""
        SettingsUi.Label { text: Tr.t("This is everything that goes in the report") }
        Rectangle {
            width: parent.width
            height: Math.min(Theme.dp(320), body.implicitHeight + 2 * Theme.s2)
            radius: Theme.rControl
            color: Theme.win
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.s2
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: body
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: page.report
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentInk
                    font { family: Theme.mono; pixelSize: Theme.sp(12) }
                    Accessible.role: Accessible.StaticText
                    Accessible.name: Tr.t("The report")
                }
            }
        }
        Row {
            spacing: Theme.s2
            SettingsUi.Push {
                main: true
                text: Tr.t("Open as a GitHub issue")
                onPicked: Quickshell.execDetached(["kriss", "report", "--open"].concat(page.args()))
            }
            SettingsUi.Push {
                text: Tr.t("Save to a file")
                onPicked: {
                    saver.command = ["kriss", "report", "--save", (Quickshell.env("XDG_DOWNLOAD_DIR") || Quickshell.env("HOME") + "/Downloads")
                        + "/kriss-report-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".md"].concat(page.args());
                    saver.running = true;
                }
            }
        }
        SettingsUi.Note { text: Tr.t("Nothing is sent until you press Submit on GitHub.") + (page.saved ? " " + page.saved : "") }
    }
}
