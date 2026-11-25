import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Time and language > Date and time (timedatectl): set the time automatically
// over the internet, and the time zone, picked from a searchable list.
Column {
    id: page
    spacing: Theme.s3

    property string zone: ""
    property bool ntp: true
    property var zones: []
    function read() { reader.running = true; }
    Component.onCompleted: { read(); lister.running = true; }
    Process {
        id: reader
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.zone = /Timezone=(.*)/.exec(text)?.[1] ?? "";
                page.ntp = /NTP=yes/.test(text);
            }
        }
    }
    Process {
        id: lister
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: page.zones = text.split("\n").filter(z => z) }
    }
    Process {
        id: setter
        onExited: page.read()
    }
    function run(args) { setter.command = ["timedatectl"].concat(args); setter.running = true; }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    SettingsUi.Card {
        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.fg
            font { family: Theme.sans; pixelSize: Theme.sp(36); weight: Font.DemiBold }
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
        SettingsUi.Note { text: clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat) }
        SettingsUi.Toggle {
            text: Tr.t("Set the time automatically")
            detail: Tr.t("From the internet, so the clock stays right.")
            checked: page.ntp
            onToggled: page.run(["set-ntp", String(!checked)])
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Time zone") }
        SettingsUi.Note { text: page.zone.replace(/_/g, " ") }
        Rectangle {
            width: parent.width
            height: Math.max(40, Theme.sp(14) + 24)
            radius: height / 2
            color: Theme.win
            border.width: find.activeFocus ? Theme.focusWidth : Theme.rimWidth
            border.color: find.activeFocus ? Theme.accentText : Theme.line
            TextInput {
                id: find
                anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s4 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(14) }
                activeFocusOnTab: true
                Accessible.role: Accessible.EditableText
                Accessible.name: Tr.t("Find a city or region")
                Text { visible: !parent.text; text: Tr.t("Find a city or region"); color: Theme.soft; font: parent.font }
            }
        }
        Repeater {
            // The first matches only; the list has some 600.
            model: find.text.length < 2 ? [] : page.zones.filter(z => z.toLowerCase().replace(/_/g, " ").includes(find.text.toLowerCase())).slice(0, 12)
            SettingsUi.Radio {
                required property string modelData
                glyph: "globe"
                text: modelData.replace(/_/g, " ")
                group: Tr.t("Time zone")
                on: modelData === page.zone
                onPicked: { page.run(["set-timezone", modelData]); find.text = ""; }
            }
        }
    }
}
