import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

// The overflow flyout above the ^ in the bar, as on Windows 11: the tray icons kept out of
// the bar (Desktop.trayHidden). Drag an icon out of it onto the bar to show it there. Arrows
// move between the icons, Enter opens one, the Menu key or Shift+F10 opens its menu, Esc
// closes. Like Menu.qml, it is a clear layer over the screen, so a click off the card closes it.
PanelWindow {
    id: fly

    required property var appMenu
    readonly property var items: SystemTray.items.values.filter(i => Desktop.isTrayHidden(i.id))
    property real at: 0     // the ^'s centre, from the screen's left edge
    property int current: -1

    function show(s, x, byKeyboard) {
        screen = s;
        at = x;
        current = byKeyboard && items.length ? 0 : -1;
        Desktop.opened(byKeyboard);
        visible = true;
        card.opacity = 0;
        appear.restart();
        focusCurrent();
    }
    function close() { if (visible) { visible = false; Desktop.retakeKeys(); } }
    // The icon picked from the keyboard has the focus, so a screen reader follows it; it
    // takes Enter and the Menu key itself, the card the rest.
    onCurrentChanged: focusCurrent()
    function focusCurrent() { (icons.itemAt(current)?.icon ?? card).forceActiveFocus(); }
    onItemsChanged: { if (!items.length) close(); current = Math.min(current, items.length - 1); }

    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-tray"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

    MouseArea {
        Accessible.ignored: true  // pointer only; the keyboard has its own way
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: fly.close()
    }

    Rectangle {
        id: card
        width: grid.width + 16
        height: grid.height + 16
        x: Math.max(8, Math.min(fly.width - width - 8, fly.at - width / 2))
        // Above the ^ on the taskbar, below it in the Mac top bar.
        y: Desktop.mac ? Theme.topBarHeight + 8 : fly.height - Theme.barHeight - height - 8
        radius: Theme.rCard
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.line
        Accessible.role: Accessible.Grouping
        Accessible.name: Tr.t("Hidden icons")
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; Accessible.ignored: true }
        Keys.onPressed: event => {
            const n = fly.items.length, i = fly.current;
            switch (event.key) {
            case Qt.Key_Left: case Qt.Key_Up: case Qt.Key_Backtab: fly.current = Math.max(0, i - 1); break;
            case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_Tab: fly.current = Math.min(n - 1, i + 1); break;
            case Qt.Key_Home: fly.current = 0; break;
            case Qt.Key_End: fly.current = n - 1; break;
            case Qt.Key_Escape: fly.close(); break;
            default: return;
            }
            event.accepted = true;
        }
        NumberAnimation { id: appear; target: card; property: "opacity"; from: 0; to: 1; duration: Theme.ms(Theme.fast); easing.type: Theme.ease }

        Grid {
            id: grid
            x: 8; y: 8
            columns: Math.max(1, Math.min(5, fly.items.length))
            Repeater {
                id: icons
                model: fly.items
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property alias icon: icon
                    width: 40; height: 40
                    TrayIcon {
                        id: icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        modelData: cell.modelData
                        appMenu: fly.appMenu
                        kbFocused: fly.current === cell.index
                        onUsed: fly.close()
                        // Let go off the card, onto the bar: the icon goes back on the bar.
                        onDropped: (x, y) => {
                            if (!card.contains(card.mapFromItem(null, x, y))) Desktop.setTrayHidden(cell.modelData.id, false);
                        }
                    }
                }
            }
        }
    }
}
