import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.WindowManager
import Quickshell.Services.SystemTray

// The taskbar: full width along the bottom of each screen, 48 px like Windows 11. Keris launcher, this screen's workspaces, pinned and running
// apps on the left; tray icons, power profile, quick settings (network, volume,
// battery), notifications and the clock on the right.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "kriss-bar"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    // Maximized and snapped windows stop at the bar.
    exclusiveZone: Theme.barHeight
    color: "transparent"
    // Frosted glass: cosmic-comp blurs what is behind the bar.
    BackgroundEffect.blurRegion: Region { item: body }

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
        color: Theme.bar

        // A soft rim along the top edge instead of a border.
        Rectangle { width: parent.width; height: 1; color: Theme.rim }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 8

            // Keris: opens the launcher, like the Start button.
            MouseArea {
                id: start
                Layout.preferredWidth: Theme.barButton
                Layout.preferredHeight: Theme.barButton
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("launcherOpen")

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: start.containsMouse || Desktop.launcherOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                // The KrissOS emblem from kriss-theme.
                Image {
                    anchors.centerIn: parent
                    width: Theme.barIcon + 4
                    height: width
                    source: "file:///usr/share/pixmaps/krissos.svg"
                    sourceSize: Qt.size(width * 2, height * 2)
                    scale: parent.pressed ? Theme.pressScale : parent.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
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
                            width: modelData.active ? 22 : 8
                            height: 8
                            radius: 4
                            color: modelData.active ? Theme.accent : (modelData.urgent ? Theme.red : Theme.soft)
                            opacity: modelData.active ? 1 : 0.6
                            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Theme.line }

            Row {
                id: appRow
                spacing: 4
                Repeater {
                    model: bar.apps
                    delegate: AppButton {}
                }
            }

            Item { Layout.fillWidth: true }

            // Tray icons (Steam, Discord...): click to open, right-click for the app's menu.
            Row {
                spacing: 14
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Repeater {
                    model: SystemTray.items
                    delegate: TrayIcon {}
                }
            }

            PowerPill {}

            // Network, volume and battery open quick settings, like on Windows.
            MouseArea {
                id: quick
                implicitWidth: status.implicitWidth + 24
                implicitHeight: Theme.barButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("quickOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: quick.containsMouse || Desktop.quickOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Row {
                    id: status
                    anchors.centerIn: parent
                    spacing: 12
                    NetworkGlyph {}
                    VolumeGlyph {}
                    Battery {}
                }
            }

            MouseArea {
                id: bell
                Layout.preferredWidth: Theme.barButton
                Layout.preferredHeight: Theme.barButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("notificationsOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: bell.containsMouse || Desktop.notificationsOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: Desktop.dnd ? "bellOff" : "bell" }
                Rectangle {
                    visible: Notifs.all.length > 0
                    x: parent.width - width - 4; y: 4
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

            // The clock opens the calendar, as on Windows.
            MouseArea {
                id: clockArea
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: Theme.barButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("calendarOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: clockArea.containsMouse || Desktop.calendarOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Column {
                    id: clockText
                    anchors.centerIn: parent
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    RollingText {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold; features: { "tnum": 1 } }
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
    }

    // Open or close one of the panels on this bar's screen (closing the others).
    function toggle(panel) {
        const open = !(Desktop[panel] && Desktop.screen === bar.screen);
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = false;
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

        width: Theme.barButton
        height: Theme.barButton
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
            radius: Theme.barRadius
            // Lit under the pointer and behind the app in front, clear otherwise.
            color: btn.containsMouse ? (btn.front ? Theme.cardHover : Theme.card) : btn.front ? Theme.card : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            scale: btn.pressed && !btn.dragging ? Theme.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.barIcon
                source: Quickshell.iconPath(btn.modelData.entry?.icon ?? btn.modelData.appId, "application-x-executable")
            }
        }
        Rectangle {
            visible: btn.wins.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: btn.front ? 16 : 6
            height: 3
            radius: 1.5
            color: btn.front ? Theme.accent : Theme.soft
            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        }
    }
}
