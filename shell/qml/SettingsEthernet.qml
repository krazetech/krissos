import QtQuick
import Quickshell
import Quickshell.Networking

// Settings > Network and internet > Ethernet: each cable port, whether it is connected, and
// COSMIC's page for IP settings.
Column {
    id: page
    spacing: Theme.s3

    readonly property var ports: Networking.devices.values.filter(d => d.type === DeviceType.Wired)

    SettingsUi.Card {
        SettingsUi.Note { visible: page.ports.length === 0; text: Tr.t("This PC has no Ethernet port.") }
        Repeater {
            model: page.ports
            Row {
                required property var modelData
                width: parent.width
                spacing: Theme.s3
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData.name + ": " + (modelData.connected ? Tr.t("Connected") : Tr.t("No cable"))
                Glyph { name: "wired"; size: 20; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    Text {
                        text: modelData.name
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                    }
                    Text {
                        text: modelData.connected ? Tr.t("Connected") : Tr.t("No cable")
                        color: modelData.connected ? Theme.accentText : Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(12) }
                    }
                }
            }
        }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "wired"
            text: Tr.t("More Ethernet options")
            detail: Tr.t("IP address, DNS, metered connection")
            external: true
            onPicked: Quickshell.execDetached(["cosmic-settings", "wired"])
        }
    }
}
