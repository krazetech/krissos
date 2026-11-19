import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Alt+Tab, as on Windows: the open windows, most recently used first, with the previous one
// selected. Tab (or Alt+Tab again) moves on, Shift goes back, letting go of Alt switches,
// Esc cancels. cosmic-comp runs `kriss-shell switcher next|previous` for the key.
PanelWindow {
    id: win

    property bool open: false
    property int current: 0
    // Taken when it opens, so the order doesn't shift under the selection.
    property var wins: []

    function step(by) {
        if (!open) {
            wins = Windows.byRecent.slice();
            if (wins.length === 0) return;
            current = 0;
            Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = Desktop.taskViewOpen = Desktop.widgetsOpen = false;
            // Its own screen, set once: a notification or a bar click moving Desktop.screen
            // must not move the switcher while it is up.
            screen = Desktop.focusedScreen();
            open = true;
        }
        // cosmic-comp keeps Alt+Tab for itself, so each Tab comes here, never as a key: Alt is still held.
        settle.restart();
        current = (current + by + wins.length) % wins.length;
    }
    // A screen reader stays on the panel; it hears each window as the selection moves.
    onCurrentChanged: if (open && wins[current]) panel.Accessible.announce(wins[current].title || wins[current].appId)
    function finish(switchTo) {
        if (!open) return;
        open = false;
        settle.stop();
        if (switchTo && wins[current]) Windows.activate(wins[current].id);
    }

    // A quick Alt+Tab can be over before this surface gets the keyboard, and then no Alt
    // release ever reaches it. With no key at all by now, the keys are already up: switch.
    // ponytail: a fixed wait; someone holding Alt still has let go of Tab by then, which counts.
    Timer { id: settle; interval: 600; onTriggered: win.finish(true) }

    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    MouseArea { anchors.fill: parent; onClicked: win.finish(false); Accessible.ignored: true }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(row.implicitWidth + 32, parent.width - Theme.gap * 4)
        height: row.implicitHeight + 32
        radius: Theme.radius + 4
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.rim
        clip: true
        focus: true
        Accessible.role: Accessible.Dialog
        Accessible.name: Tr.t("Switch windows")

        opacity: win.open ? 1 : 0
        scale: win.open || Theme.reduceMotion ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

        Keys.onPressed: event => {
            settle.stop();
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) win.step(1);
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) win.step(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) win.finish(true);
            else if (event.key === Qt.Key_Escape) win.finish(false);
            event.accepted = true;
        }
        Keys.onReleased: event => {
            settle.stop();
            // Alt let go, or a key let go with Alt no longer held.
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L
                || !(event.modifiers & (Qt.AltModifier | Qt.MetaModifier)))
                win.finish(true);
        }

        ListView {
            id: row
            anchors.centerIn: parent
            width: parent.width - 32
            implicitWidth: count * 136 + (count - 1) * spacing
            implicitHeight: Math.max(132, 86 + Theme.sp(12) * 2.6)
            height: implicitHeight
            orientation: ListView.Horizontal
            spacing: 8
            interactive: false
            model: win.wins
            currentIndex: win.current
            highlightMoveDuration: Theme.ms(Theme.fast)
            preferredHighlightBegin: width / 2 - 68
            preferredHighlightEnd: width / 2 + 68
            highlightRangeMode: ListView.ApplyRange
            highlight: Rectangle {
                radius: Theme.radiusSmall + 2
                color: Theme.card
                border.width: Theme.focusWidth
                border.color: Theme.accent
            }

            delegate: MouseArea {
                id: cell
                required property var modelData
                required property int index
                width: 136
                height: row.height
                hoverEnabled: true
                onClicked: { win.current = index; win.finish(true); }
                readonly property var entry: DesktopEntries.heuristicLookup(modelData.appId)
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.title || entry?.name || modelData.appId
                Accessible.description: entry?.name ?? ""
                Accessible.selected: index === win.current
                Accessible.onPressAction: { win.current = index; win.finish(true); }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 10
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 56
                        source: Quickshell.iconPath(cell.entry?.icon ?? cell.modelData.appId, "application-x-executable")
                        opacity: cell.modelData.minimized ? 0.6 : 1
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        text: cell.modelData.title || cell.entry?.name || cell.modelData.appId
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(12); weight: cell.index === win.current ? Font.DemiBold : Font.Medium }
                    }
                }
            }
        }
    }
}
