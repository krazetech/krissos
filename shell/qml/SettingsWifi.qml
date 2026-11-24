import QtQuick
import Quickshell
import Quickshell.Networking

// Settings > Network and internet > Wi-Fi (NetworkManager, through Quickshell.Networking):
// on or off, the networks in range with their signal, connecting (with a password when one
// is needed), and forgetting a saved one. It looks for networks while the page is open.
Column {
    id: page
    spacing: Theme.s3

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    property var asking: null   // the network a password is being typed for
    property bool failed: false
    Binding { when: page.wifi !== null; target: page.wifi; property: "scannerEnabled"; value: page.visible }

    SettingsUi.Card {
        SettingsUi.Note { visible: page.wifi === null; text: Tr.t("This PC has no Wi-Fi.") }
        SettingsUi.Toggle {
            visible: page.wifi !== null
            text: Tr.t("Wi-Fi")
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    SettingsUi.Card {
        visible: page.wifi !== null && Networking.wifiEnabled
        SettingsUi.Label { text: Tr.t("Networks") }
        SettingsUi.Note { visible: !(page.wifi?.networks.values.length); text: Tr.t("Looking for networks…") }
        Repeater {
            model: (page.wifi?.networks.values ?? []).slice()
                .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
            Column {
                id: net
                required property var modelData
                width: parent.width
                spacing: Theme.s1
                readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
                Connections {
                    target: net.modelData
                    function onConnectionFailed(reason) { if (net.secured) { page.asking = net.modelData; page.failed = true; } }
                }
                SettingsUi.Radio {
                    glyph: "wifi"
                    text: net.modelData.name
                    group: Tr.t("Networks")
                    detail: [net.modelData.connected ? Tr.t("Connected") : net.modelData.stateChanging ? Tr.t("Connecting…")
                             : net.modelData.known ? Tr.t("Saved") : net.secured ? Tr.t("Secured") : Tr.t("No password"),
                             Tr.t("Signal %1%", Math.round(net.modelData.signalStrength * 100))].join(" · ")
                    on: net.modelData.connected
                    onPicked: {
                        if (net.modelData.connected) net.modelData.disconnect();
                        else if (net.modelData.known || !net.secured) net.modelData.connect();
                        else { page.asking = net.modelData; page.failed = false; }
                    }
                }
                Row {
                    visible: net.modelData.known
                    spacing: Theme.s2
                    leftPadding: 18 + Theme.s3
                    SettingsUi.Push { text: Tr.t("Forget"); onPicked: net.modelData.forget() }
                }
                Rectangle {
                    visible: page.asking === net.modelData
                    width: parent.width
                    height: Math.max(40, Theme.sp(14) + 24)
                    radius: height / 2
                    color: Theme.win
                    border.width: 2
                    border.color: page.failed ? Theme.red : Theme.accentText
                    TextInput {
                        id: psk
                        anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s4 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(14) }
                        onVisibleChanged: { text = ""; if (visible) forceActiveFocus(); }
                        Keys.onReturnPressed: if (text) { net.modelData.connectWithPsk(text); page.asking = null; }
                        Keys.onEscapePressed: page.asking = null
                        Accessible.role: Accessible.EditableText
                        Accessible.passwordEdit: true
                        Accessible.name: Tr.t("Password for %1", net.modelData.name)
                        Accessible.description: page.failed ? Tr.t("Wrong password. Try again, then Enter") : ""
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !psk.text
                            text: page.failed ? Tr.t("Wrong password. Try again, then Enter") : Tr.t("Network password, then Enter")
                            color: page.failed ? Theme.red : Theme.soft
                            font: psk.font
                        }
                    }
                }
            }
        }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "wifi"
            text: Tr.t("More Wi-Fi options")
            detail: Tr.t("Hidden networks, hotspot, IP settings")
            external: true
            onPicked: Quickshell.execDetached(["cosmic-settings", "wireless"])
        }
    }
}
