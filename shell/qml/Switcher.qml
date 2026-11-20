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
        if (!panel.activeFocus) settle.restart();
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

    // Once this surface has the keyboard (about 50 ms after Tab), letting go of Alt reaches it,
    // however long Alt is held. Until then a quick Alt+Tab can be over unseen: with no keyboard
    // by now, the keys are already up, so switch.
    // ponytail: Alt let go in the ~50 ms before the keyboard arrives leaves it open until the
    // next key or click (Qt only learns modifiers from key events, so a pointer move can't tell);
    // reading the key state at keyboard enter would close that gap.
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
        radius: Theme.rPanel
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.rim
        clip: true
        focus: true
        // The keyboard taken away while open (another surface grabbed it): no Alt release will come.
        onActiveFocusChanged: if (activeFocus) settle.stop(); else if (win.open) settle.restart()
        Accessible.role: Accessible.Dialog
        Accessible.name: Tr.t("Switch windows")

        opacity: win.open ? 1 : 0
        scale: win.open || Theme.reduceMotion ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.ms(win.open ? Theme.fast : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(win.open ? Theme.fast : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }

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
            spacing: Theme.s2
            interactive: false
            model: win.wins
            currentIndex: win.current
            highlightMoveDuration: Theme.ms(Theme.fast)
            preferredHighlightBegin: width / 2 - 68
            preferredHighlightEnd: width / 2 + 68
            highlightRangeMode: ListView.ApplyRange
            highlight: Rectangle {
                radius: Theme.rCard
                color: Theme.card
                border.width: Theme.focusWidth
                border.color: Theme.accentText
            }

            delegate: MouseArea {
                id: cell
                required property var modelData
                required property int index
                width: Theme.dp(136)
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
                    spacing: Theme.s2
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
