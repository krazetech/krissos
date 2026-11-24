import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Settings > Bluetooth and devices > Bluetooth (BlueZ): on or off, your devices, and pairing a
// new one. It looks for devices while the page is open.
Column {
    id: page
    spacing: Theme.s3

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.name)
    Binding { when: page.adapter !== null; target: page.adapter; property: "discovering"; value: page.visible && (page.adapter?.enabled ?? false) }

    SettingsUi.Card {
        SettingsUi.Note { visible: page.adapter === null; text: Tr.t("This PC has no Bluetooth, or it is turned off in the firmware.") }
        SettingsUi.Toggle {
            visible: page.adapter !== null
            text: Tr.t("Bluetooth")
            detail: page.adapter?.enabled ? Tr.t("Other devices can find this PC as “%1”.", page.adapter?.name ?? "") : ""
            checked: page.adapter?.enabled ?? false
            onToggled: page.adapter.enabled = !page.adapter.enabled
        }
    }

    Repeater {
        // Your devices, then the ones nearby that could be paired.
        model: page.adapter?.enabled ? [[Tr.t("Your devices"), page.devices.filter(d => d.paired)],
                                        [Tr.t("Add a device"), page.devices.filter(d => !d.paired)]] : []
        SettingsUi.Card {
            required property var modelData
            SettingsUi.Label { text: modelData[0] }
            SettingsUi.Note {
                visible: modelData[1].length === 0
                text: modelData[0] === Tr.t("Your devices") ? Tr.t("Nothing is paired yet.") : Tr.t("Looking for devices… Put the device in pairing mode.")
            }
            Repeater {
                model: modelData[1].slice().sort((a, b) => b.connected - a.connected)
                Column {
                    id: dev
                    required property var modelData
                    width: parent.width
                    SettingsUi.Radio {
                        glyph: "bluetooth"
                        text: dev.modelData.name
                        group: Tr.t("Bluetooth")
                        detail: dev.modelData.connected ? Tr.t("Connected") + (dev.modelData.batteryAvailable ? " · " + Tr.t("Battery %1%", Math.round(dev.modelData.battery * 100)) : "")
                            : dev.modelData.pairing ? Tr.t("Pairing…") : dev.modelData.paired ? Tr.t("Not connected") : Tr.t("Click to pair")
                        on: dev.modelData.connected
                        // A new device pairs, then connects once paired (below).
                        onPicked: dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.paired ? dev.modelData.connect() : dev.modelData.pair()
                    }
                    Connections {
                        target: dev.modelData
                        function onPairedChanged() { if (dev.modelData.paired && !dev.modelData.connected) dev.modelData.connect(); }
                    }
                    Row {
                        visible: dev.modelData.paired
                        spacing: Theme.s2
                        leftPadding: 18 + Theme.s3
                        SettingsUi.Push { text: Tr.t("Remove device"); onPicked: dev.modelData.forget() }
                    }
                }
            }
        }
    }
}
