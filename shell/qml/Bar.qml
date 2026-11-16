import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.WindowManager
import Quickshell.Services.SystemTray

// The one floating bar: keris launcher, this screen's workspaces, pinned and running
// apps on the left; tray icons, power profile, quick settings (network, volume,
// battery), notifications and the clock on the right.
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
        // ponytail: no overflow handling; a long pin list just crowds the bar.
        for (const e of Desktop.pinnedEntries()) {
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
                onClicked: bar.toggle("launcherOpen")

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.alpha(Theme.accent, 0.35)
                    visible: Desktop.launcherOpen && Desktop.screen === bar.screen
                }
                // The KrissOS emblem from kriss-theme.
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
                    // This screen's workspaces; all of them if the compositor does not say
                    // which screen a workspace is on.
                    readonly property var mine: WindowManager.screenProjection(bar.screen)?.windowsets ?? []
                    model: (mine.length ? mine : WindowManager.windowsets).filter(w => w.shouldDisplay)
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
                id: appRow
                spacing: 10
                Repeater {
                    model: bar.apps
                    delegate: AppButton {}
                }
            }

            Item { Layout.fillWidth: true }

            // Tray icons (Steam, Discord...): click to open, right-click for the app's menu.
            Row {
                spacing: 8
                Repeater {
                    model: SystemTray.items
                    delegate: TrayIcon {}
                }
            }

            PowerPill {}

            // Network, volume and battery open quick settings, like on Windows.
            MouseArea {
                id: quick
                Layout.leftMargin: 4
                implicitWidth: status.implicitWidth + 20
                implicitHeight: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("quickOpen")
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: quick.containsMouse || Desktop.quickOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                }
                Row {
                    id: status
                    anchors.centerIn: parent
                    spacing: 14
                    NetworkGlyph {}
                    VolumeGlyph {}
                    Battery {}
                }
            }

            MouseArea {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("notificationsOpen")
                Glyph { anchors.centerIn: parent; name: Desktop.dnd ? "bellOff" : "bell" }
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
                RollingText {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold; features: { "tnum": 1 } }
                }
                Text {
                    anchors.right: parent.right
                    text: clock.date.toLocaleString(Qt.locale(), "ddd d MMM")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: 11 }
                }
            }
        }
    }

    // Open or close one of the panels on this bar's screen (closing the others).
    function toggle(panel) {
        const open = !(Desktop[panel] && Desktop.screen === bar.screen);
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = false;
        Desktop.screen = bar.screen;
        Desktop[panel] = open;
    }

    Menu { id: menu }

    component AppButton: MouseArea {
        id: btn
        required property var modelData
        required property int index
        readonly property string pinId: modelData.entry?.id ?? modelData.appId
        readonly property bool pinned: Desktop.isPinned(pinId)
        readonly property var wins: Windows.list.filter(w => w.appId.toLowerCase() === modelData.appId.toLowerCase())
        readonly property bool front: wins.some(w => w.active && !w.minimized)
        // Drag a pinned app sideways to reorder the pins.
        property real pressX: 0
        property bool dragging: false
        readonly property real step: width + appRow.spacing

        width: 44
        height: 44
        z: dragging ? 1 : 0
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        // Window coordinates: mouse.x moves with the Translate below, so it would undo the drag.
        onPressed: mouse => { pressX = mapToItem(null, mouse.x, 0).x; dragging = false; }
        onPositionChanged: mouse => {
            const dx = mapToItem(null, mouse.x, 0).x - pressX;
            if (pressed && pinned && pressedButtons & Qt.LeftButton && Math.abs(dx) > 10) dragging = true;
            if (dragging) shift.x = dx;
        }
        onReleased: {
            if (!dragging) return;
            const to = Math.max(0, Math.min(bar.apps.length - 1, index + Math.round(shift.x / step)));
            const target = bar.apps[to];
            Desktop.movePin(pinId, target.entry?.id ?? target.appId);
            shift.x = 0;
        }
        onClicked: mouse => {
            if (dragging) { dragging = false; return; }
            if (mouse.button === Qt.RightButton) {
                const items = [[pinned ? Tr.t("Unpin from taskbar") : Tr.t("Pin to taskbar"), () => Desktop.togglePin(pinId)]];
                if (modelData.entry) items.push([Tr.t("New window"), () => modelData.entry.execute()]);
                if (wins.length) items.push([wins.length > 1 ? Tr.t("Close all windows") : Tr.t("Close window"),
                                             () => wins.forEach(w => Windows.close(w.id))]);
                menu.show(btn, items);
            } else if (mouse.button === Qt.MiddleButton || !Windows.toggle(modelData.appId)) {
                modelData.entry?.execute();
            }
        }
        transform: Translate { id: shift }

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
}
