import QtQuick
import Quickshell.Networking

Glyph {
    readonly property var dev: Networking.devices.values.find(d => d.connected) ?? null
    anchors.verticalCenter: parent.verticalCenter
    name: !dev ? "wifiOff" : dev.type === DeviceType.Wifi ? "wifi" : "wired"
    color: dev ? Theme.fg : Theme.soft
    // What a screen reader says for it, in the quick settings button's description.
    readonly property string label: !dev ? Tr.t("Not connected")
        : dev.type === DeviceType.Wifi ? Tr.t("Wi-Fi: %1", dev.networks?.values.find(n => n.connected)?.name ?? "") : Tr.t("Wired network")
}
