import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.WindowManager
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// The one floating bar: keris launcher, workspaces, pinned and running apps on the
// left; power profile, network, volume, battery, notifications and the clock on the right.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "kriss-bar"
    anchors { bottom: true; left: true; right: true }
    margins { left: Theme.gap * 1.5; right: Theme.gap * 1.5; bottom: Theme.gap }
    implicitHeight: Theme.barHeight
    color: "transparent"
    // Frosted glass: cosmic-comp blurs what is behind the bar.
    BackgroundEffect.blurRegion: Region { item: body; radius: Theme.radius }

    // Pinned apps first, then anything else that has a window open.
    readonly property var apps: {
        const out = [];
        const seen = {};
        for (const e of Desktop.pinnedEntries(6)) {
            out.push({ entry: e, appId: e.id });
            seen[e.id.toLowerCase()] = true;
        }
        for (const w of Windows.list) {
            const key = w.appId.toLowerCase();
            if (!key || seen[key]) continue;
            seen[key] = true;
            out.push({ entry: DesktopEntries.heuristicLookup(w.appId), appId: w.appId });
        }
        return out;
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bar
        border.width: 1
        border.color: Theme.rim

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 14
            spacing: 12

            // Keris: opens the launcher, like the Start button.
            MouseArea {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.leftMargin: 4
                cursorShape: Qt.PointingHandCursor
                onClicked: Desktop.launcherOpen = !Desktop.launcherOpen

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.alpha(Theme.accent, 0.35)
                    visible: Desktop.launcherOpen
                }
                // ponytail: the accent disc shows on its own until kriss-theme ships krissos.svg (PR #8).
                Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.accent }
                Image {
                    anchors.fill: parent
                    source: "file:///usr/share/pixmaps/krissos.svg"
                    sourceSize: Qt.size(76, 76)
                    scale: parent.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                }
                hoverEnabled: true
            }

            // Workspaces: dots, the active one stretched into a cyan pill.
            Row {
                spacing: 6
                Layout.leftMargin: 2
                Repeater {
                    // ponytail: every bar shows every workspace; split per screen if multi-monitor users ask.
                    model: WindowManager.windowsets.filter(w => w.shouldDisplay)
                    delegate: MouseArea {
                        required property var modelData
                        width: dot.width
                        height: 20
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData.canActivate) modelData.activate()
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.active ? 26 : 9
                            height: 9
                            radius: 4.5
                            color: modelData.active ? Theme.accent : (modelData.urgent ? Theme.red : Theme.soft)
                            opacity: modelData.active ? 1 : 0.6
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 2; Layout.preferredHeight: 24; radius: 1; color: Theme.line }

            Row {
                spacing: 10
                Repeater {
                    model: bar.apps
                    delegate: AppButton {}
                }
            }

            Item { Layout.fillWidth: true }

            PowerPill {}

            Row {
                spacing: 14
                Layout.leftMargin: 4
                NetworkGlyph {}
                VolumeGlyph {}
                Battery {}
            }

            MouseArea {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                cursorShape: Qt.PointingHandCursor
                onClicked: Desktop.notificationsOpen = !Desktop.notificationsOpen
                Glyph { anchors.centerIn: parent; name: "bell" }
                Rectangle {
                    visible: Notifs.all.length > 0
                    x: parent.width - 12; y: -2
                    width: Math.max(16, count.implicitWidth + 8); height: 16; radius: 8
                    color: Theme.accent
                    Text {
                        id: count
                        anchors.centerIn: parent
                        text: Notifs.all.length
                        color: Theme.accentInk
                        font { family: Theme.sans; pixelSize: 10; weight: Font.Bold }
                    }
                }
            }

            Column {
                Layout.leftMargin: 4
                SystemClock { id: clock; precision: SystemClock.Minutes }
                Text {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold; features: { "tnum": 1 } }
                }
                Text {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: 11 }
                }
            }
        }
    }

    component AppButton: MouseArea {
        id: btn
        required property var modelData
        readonly property var wins: Windows.list.filter(w => w.appId.toLowerCase() === modelData.appId.toLowerCase())
        readonly property bool front: wins.some(w => w.active && !w.minimized)

        width: 44
        height: 44
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton || !Windows.toggle(modelData.appId)) modelData.entry?.execute();
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.card
            y: btn.containsMouse ? -3 : 0
            Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
            IconImage {
                anchors.centerIn: parent
                implicitSize: 28
                source: Quickshell.iconPath(btn.modelData.entry?.icon ?? btn.modelData.appId, "application-x-executable")
            }
        }
        Rectangle {
            visible: btn.wins.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 3
            width: btn.front ? 16 : 5
            height: 4
            radius: 2
            color: btn.front ? Theme.accent : Theme.soft
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
        }
    }

    component PowerPill: MouseArea {
        id: pp
        readonly property var order: PowerProfiles.hasPerformanceProfile
            ? [PowerProfile.Balanced, PowerProfile.Performance, PowerProfile.PowerSaver]
            : [PowerProfile.Balanced, PowerProfile.PowerSaver]
        readonly property int p: PowerProfiles.profile
        readonly property var look: p === PowerProfile.Performance ? ["performance", "Performance"]
            : p === PowerProfile.PowerSaver ? ["saver", "Power saver"] : ["balanced", "Balanced"]

        implicitWidth: pill.width
        implicitHeight: 34
        cursorShape: Qt.PointingHandCursor
        onClicked: PowerProfiles.profile = order[(order.indexOf(p) + 1) % order.length]

        Rectangle {
            id: pill
            height: parent.height
            width: row.implicitWidth + 26
            radius: height / 2
            color: Theme.card
            border.width: pp.p === PowerProfile.Performance ? 2 : 0
            border.color: Theme.accent
            Row {
                id: row
                anchors.centerIn: parent
                spacing: 7
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: pp.look[0]
                    size: 16
                    color: pp.p === PowerProfile.Performance ? Theme.accent : Theme.fg
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pp.look[1]
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
                }
            }
        }
    }

    component NetworkGlyph: Glyph {
        readonly property var dev: Networking.devices.values.find(d => d.connected) ?? null
        anchors.verticalCenter: parent.verticalCenter
        name: !dev ? "wifiOff" : dev.type === DeviceType.Wifi ? "wifi" : "wired"
        color: dev ? Theme.fg : Theme.soft
    }

    component VolumeGlyph: MouseArea {
        id: vol
        readonly property var sink: Pipewire.defaultAudioSink
        width: 20
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        cursorShape: Qt.PointingHandCursor
        onClicked: if (sink?.audio) sink.audio.muted = !sink.audio.muted
        onWheel: wheel => {
            if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
        }
        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
        Glyph { name: vol.sink?.audio?.muted ? "mute" : "volume" }
    }

    component Battery: Row {
        id: bat
        readonly property var dev: UPower.displayDevice
        visible: dev.isLaptopBattery
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 12; radius: 3.5
            color: "transparent"
            border.width: 2
            border.color: Theme.fg
            Rectangle {
                x: 3; y: 3
                height: 6; radius: 1.5
                width: Math.max(1, 16 * bat.dev.percentage)
                color: bat.dev.percentage < 0.15 ? Theme.red : Theme.fg
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(bat.dev.percentage * 100) + "%"
            color: Theme.fg
            font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold; features: { "tnum": 1 } }
        }
    }
}
