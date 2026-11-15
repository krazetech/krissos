import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Quick settings, like the Windows Action Center: Wi-Fi, Bluetooth, Do not disturb and
// the power mode as tiles, then volume, microphone and brightness sliders. The arrow on a
// tile, or next to the volume, opens its list (networks, devices, speakers) in place.
// ponytail: no night light; cosmic-comp 1.11 has no gamma-control protocol to drive one.
PanelWindow {
    id: win

    visible: Desktop.quickOpen
    screen: Desktop.screen

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-quick-settings"
    // On demand, so the Wi-Fi password field can take keys.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    // "" or the open list: "wifi", "bluetooth" or "output".
    property string page: ""
    property var askPsk: null

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function close() { Desktop.quickOpen = false; }

    onVisibleChanged: {
        page = "";
        askPsk = null;
        if (visible) backlight.running = true;
    }

    PwObjectTracker { objects: [win.sink, win.source] }

    // Scan for networks and devices only while their list is open.
    Binding { when: win.wifi !== null; target: win.wifi; property: "scannerEnabled"; value: win.visible && win.page === "wifi" }
    Binding { when: win.adapter !== null; target: win.adapter; property: "discovering"; value: win.visible && win.page === "bluetooth" }

    // Screen brightness through brightnessctl (it goes through logind, so no root needed).
    property int brightness: -1
    Process {
        id: backlight
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        // e.g. "intel_backlight,backlight,400,40%,1000"
        stdout: SplitParser { onRead: line => win.brightness = parseInt(line.split(",")[3]) }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.gap * 1.5
        anchors.bottomMargin: Theme.gap
        width: 400
        height: body.implicitHeight + 40
        radius: Theme.radius + 4
        color: Theme.bar
        border.width: 1
        border.color: Theme.rim
        focus: true
        Keys.onEscapePressed: win.close()

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 14

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8

                Tile {
                    visible: win.wifi !== null
                    glyph: Networking.wifiEnabled ? "wifi" : "wifiOff"
                    label: win.wifi?.connected ? (win.wifi.networks.values.find(n => n.connected)?.name ?? Tr.t("Wi-Fi")) : Tr.t("Wi-Fi")
                    on: Networking.wifiEnabled
                    list: "wifi"
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }
                Tile {
                    visible: win.adapter !== null
                    glyph: "bluetooth"
                    label: Tr.t("Bluetooth")
                    on: win.adapter?.enabled ?? false
                    list: "bluetooth"
                    onToggled: win.adapter.enabled = !win.adapter.enabled
                }
                Tile {
                    glyph: "bellOff"
                    label: Tr.t("Do not disturb")
                    on: Desktop.dnd
                    onToggled: Desktop.dnd = !Desktop.dnd
                }
                Tile {
                    // Only with power-profiles-daemon, as in the bar.
                    visible: ppd.loaded
                    readonly property var order: PowerProfiles.hasPerformanceProfile
                        ? [PowerProfile.Balanced, PowerProfile.Performance, PowerProfile.PowerSaver]
                        : [PowerProfile.Balanced, PowerProfile.PowerSaver]
                    readonly property int p: PowerProfiles.profile
                    glyph: p === PowerProfile.Performance ? "performance" : p === PowerProfile.PowerSaver ? "saver" : "balanced"
                    label: p === PowerProfile.Performance ? Tr.t("Performance") : p === PowerProfile.PowerSaver ? Tr.t("Power saver") : Tr.t("Balanced")
                    on: p !== PowerProfile.Balanced
                    onToggled: PowerProfiles.profile = order[(order.indexOf(p) + 1) % order.length]
                    FileView {
                        id: ppd
                        path: "/usr/share/dbus-1/system-services/net.hadess.PowerProfiles.service"
                        printErrors: false
                    }
                }
            }

            // Wi-Fi networks.
            ListBox {
                visible: win.page === "wifi"
                title: Tr.t("Wi-Fi networks")
                empty: Networking.wifiEnabled ? Tr.t("Looking for networks…") : Tr.t("Wi-Fi is off.")
                model: (win.wifi?.networks.values ?? []).slice()
                    .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
                delegate: Column {
                    id: net
                    required property var modelData
                    width: parent?.width ?? 0
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
                    Row_ {
                        glyph: "wifi"
                        text: net.modelData.name
                        detail: net.modelData.connected ? Tr.t("Connected")
                            : net.modelData.stateChanging ? Tr.t("Connecting…")
                            : net.secured ? Tr.t("Secured") : Tr.t("No password")
                        current: net.modelData.connected
                        onClicked: {
                            if (net.modelData.connected) net.modelData.disconnect();
                            else if (net.modelData.known || !net.secured) net.modelData.connect();
                            else win.askPsk = net.modelData;
                        }
                    }
                    // Password for a new secured network.
                    Rectangle {
                        visible: win.askPsk === net.modelData
                        width: parent.width
                        height: 42
                        radius: 21
                        color: Theme.card
                        border.width: 2
                        border.color: Theme.accent
                        TextInput {
                            id: psk
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: 14 }
                            onVisibleChanged: { text = ""; if (visible) forceActiveFocus(); }
                            Keys.onReturnPressed: { net.modelData.connectWithPsk(text); win.askPsk = null; }
                            Keys.onEscapePressed: win.askPsk = null
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !psk.text
                                text: Tr.t("Network password, then Enter")
                                color: Theme.soft
                                font: psk.font
                            }
                        }
                    }
                }
            }

            // Bluetooth devices: paired ones first.
            ListBox {
                visible: win.page === "bluetooth"
                title: Tr.t("Bluetooth devices")
                empty: win.adapter?.enabled ? Tr.t("Looking for devices…") : Tr.t("Bluetooth is off.")
                model: (win.adapter?.devices.values ?? []).filter(d => d.name).slice()
                    .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
                delegate: Row_ {
                    required property var modelData
                    glyph: "bluetooth"
                    text: modelData.name
                    detail: modelData.connected ? Tr.t("Connected") : modelData.pairing ? Tr.t("Pairing…")
                        : modelData.paired ? Tr.t("Paired") : Tr.t("Click to pair")
                    current: modelData.connected
                    // ponytail: a new device is paired on the first click and connected on the
                    // second; Windows does both at once.
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.paired ? modelData.connect() : modelData.pair()
                }
            }

            // Speakers and headphones.
            ListBox {
                visible: win.page === "output"
                title: Tr.t("Sound output")
                empty: Tr.t("No sound devices.")
                model: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
                delegate: Row_ {
                    required property var modelData
                    glyph: "volume"
                    text: modelData.description || modelData.nickname || modelData.name
                    current: modelData === win.sink
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            Slider {
                visible: win.sink?.audio !== undefined
                glyph: win.sink?.audio?.muted ? "mute" : "volume"
                value: win.sink?.audio?.volume ?? 0
                list: "output"
                onGlyphClicked: win.sink.audio.muted = !win.sink.audio.muted
                onMoved: v => { win.sink.audio.muted = false; win.sink.audio.volume = v; }
            }
            Slider {
                visible: win.source?.audio !== undefined
                glyph: win.source?.audio?.muted ? "micOff" : "mic"
                value: win.source?.audio?.volume ?? 0
                onGlyphClicked: win.source.audio.muted = !win.source.audio.muted
                onMoved: v => { win.source.audio.muted = false; win.source.audio.volume = v; }
            }
            Slider {
                visible: win.brightness >= 0
                glyph: "sun"
                value: win.brightness / 100
                onMoved: v => {
                    // Not below 1%: a black screen is hard to turn back up.
                    win.brightness = Math.max(1, Math.round(v * 100));
                    Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", win.brightness + "%"]);
                }
            }

            Text {
                visible: UPower.displayDevice.isLaptopBattery
                Layout.fillWidth: true
                text: Tr.t("%1% battery", Math.round(UPower.displayDevice.percentage * 100))
                color: Theme.soft
                font { family: Theme.sans; pixelSize: 12; weight: Font.Medium }
            }
        }
    }

    // A toggle tile; the arrow on the right opens its list.
    component Tile: Rectangle {
        id: tile
        property string glyph
        property string label
        property bool on
        property string list: ""
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 64
        radius: Theme.radiusSmall
        color: on ? Theme.accent : Theme.card
        readonly property color ink: on ? Theme.accentInk : Theme.fg

        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: tile.list ? 30 : 0
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16
                spacing: 5
                Glyph { name: tile.glyph; size: 18; color: tile.ink }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tile.label
                    color: tile.ink
                    font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }
        MouseArea {
            visible: tile.list !== ""
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 30
            cursorShape: Qt.PointingHandCursor
            onClicked: win.page = win.page === tile.list ? "" : tile.list
            Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 32; color: Theme.alpha(tile.ink, 0.2) }
            Glyph { anchors.centerIn: parent; name: win.page === tile.list ? "back" : "chevron"; size: 14; color: tile.ink; rotation: 90 }
        }
    }

    // A glyph you can click, a slider, and optionally an arrow that opens a list.
    component Slider: RowLayout {
        id: sl
        property string glyph
        property real value
        property string list: ""
        signal moved(real v)
        signal glyphClicked()

        Layout.fillWidth: true
        spacing: 10
        MouseArea {
            implicitWidth: 32; implicitHeight: 32
            cursorShape: Qt.PointingHandCursor
            onClicked: sl.glyphClicked()
            Glyph { anchors.centerIn: parent; name: sl.glyph; size: 19 }
        }
        MouseArea {
            id: track
            Layout.fillWidth: true
            implicitHeight: 28
            cursorShape: Qt.PointingHandCursor
            function set(x) { sl.moved(Math.max(0, Math.min(1, x / width))); }
            onPressed: mouse => set(mouse.x)
            onPositionChanged: mouse => { if (pressed) set(mouse.x); }
            onWheel: wheel => sl.moved(Math.max(0, Math.min(1, sl.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3
                color: Theme.card
                Rectangle { width: parent.width * Math.min(1, sl.value); height: parent.height; radius: 3; color: Theme.accent }
            }
            Rectangle {
                x: track.width * Math.min(1, sl.value) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: 9
                color: Theme.fg
                border.width: 4
                border.color: Theme.accent
            }
        }
        Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(sl.value * 100)
            color: Theme.soft
            font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold; features: { "tnum": 1 } }
        }
        MouseArea {
            visible: sl.list !== ""
            implicitWidth: 24; implicitHeight: 32
            cursorShape: Qt.PointingHandCursor
            onClicked: win.page = win.page === sl.list ? "" : sl.list
            Glyph { anchors.centerIn: parent; name: "chevron"; size: 14; rotation: win.page === sl.list ? -90 : 90 }
        }
    }

    // An open list under the tiles.
    component ListBox: Rectangle {
        id: box
        property string title
        property string empty
        property alias model: rep.model
        property alias delegate: rep.delegate

        Layout.fillWidth: true
        implicitHeight: Math.min(col.implicitHeight, 300) + 20
        radius: Theme.radiusSmall
        color: Theme.win
        border.width: 1
        border.color: Theme.line

        Flickable {
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                width: parent.width
                spacing: 2
                Text {
                    text: box.title
                    color: Theme.fg
                    bottomPadding: 6
                    font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
                }
                Text {
                    visible: rep.count === 0
                    text: box.empty
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: 13 }
                }
                Repeater { id: rep }
            }
        }
    }

    // One row in a list.
    component Row_: MouseArea {
        id: row
        property string glyph
        property string text
        property string detail
        property bool current

        width: parent?.width ?? 0
        height: 44
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle { anchors.fill: parent; radius: 10; color: row.containsMouse ? Theme.card : "transparent" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Glyph { name: row.glyph; size: 17; color: row.current ? Theme.accent : Theme.fg }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: row.text
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 13; weight: row.current ? Font.DemiBold : Font.Medium }
            }
            Text {
                text: row.detail
                color: Theme.soft
                font { family: Theme.sans; pixelSize: 11 }
            }
            Glyph { visible: row.current; name: "check"; size: 15; color: Theme.accent }
        }
    }
}
