import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// One tray icon, in the bar or the overflow flyout: click to open, middle click, scroll, and
// right-click for the app's menu (drawn by Menu.qml, so it looks like ours and works by
// keyboard). Drag it and let go: dropped(x, y) says where, in window coordinates.
MouseArea {
    id: tray
    required property SystemTrayItem modelData
    required property var appMenu       // the Menu to open the app's menu in
    property bool kbFocused: false
    signal used()                       // opened the app or its menu item
    signal dropped(real x, real y)

    property point press
    property bool dragging: false

    width: Theme.trayIcon
    height: Theme.trayIcon
    anchors.verticalCenter: parent.verticalCenter
    z: dragging ? 1 : 0
    hoverEnabled: true
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    scale: pressed && !dragging ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    // Window coordinates: mouse.x moves with the Translate below, so it would undo the drag.
    onPressed: mouse => { press = mapToItem(null, mouse.x, mouse.y); dragging = false; tipUp = false; }
    onPositionChanged: mouse => {
        const p = mapToItem(null, mouse.x, mouse.y);
        if (pressed && pressedButtons & Qt.LeftButton && Math.hypot(p.x - press.x, p.y - press.y) > 10) dragging = true;
        if (dragging) { shift.x = p.x - press.x; shift.y = p.y - press.y; }
    }
    onReleased: mouse => {
        if (!dragging) return;
        const p = mapToItem(null, mouse.x, mouse.y);
        shift.x = shift.y = 0;
        dropped(p.x, p.y);
    }
    onClicked: mouse => {
        if (dragging) { dragging = false; return; }
        if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate();
        else if (mouse.button === Qt.RightButton || modelData.onlyMenu) openMenu(false);
        else { modelData.activate(); used(); }
    }
    onVisibleChanged: dragging = false
    onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)
    // On the bar's focus chain: Enter opens the app, the Menu key or Shift+F10 its menu.
    // (In the overflow flyout the flyout keeps the keyboard and moves kbFocused instead.)
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier) openMenu(true);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (modelData.onlyMenu) openMenu(true); else { modelData.activate(); used(); }
        } else return;
        event.accepted = true;
    }
    Accessible.role: Accessible.Button
    Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
    Accessible.description: modelData.tooltipDescription
    Accessible.onPressAction: modelData.onlyMenu ? openMenu(true) : (modelData.activate(), used())
    Accessible.focused: kbFocused

    transform: Translate { id: shift }

    function openMenu(byKeyboard) {
        if (modelData.hasMenu) appMenu.show(tray, entries(opener.children.values, subs), byKeyboard);
    }

    // The app's DBus menu as Menu entries. Submenus go one level deep, as in Menu.qml.
    function entries(list, openers) {
        return list.map((e, i) => {
            if (e.isSeparator) return { sep: true };
            const checked = e.buttonType !== QsMenuButtonType.None && e.checkState === Qt.Checked;
            const out = { text: e.text.replace(/_(?!_)/g, ""), off: !e.enabled,
                          run: () => { e.triggered(); tray.used(); } };
            if (checked) out.glyph = "check";
            else if (e.icon) out.icon = e.icon;
            if (e.hasChildren && openers) out.sub = entries(openers.objectAt(i)?.children.values ?? [], null);
            return out;
        });
    }
    // Kept open so the app's menu, and its submenus, are loaded before the right-click.
    QsMenuOpener { id: opener; menu: tray.modelData.menu }
    Instantiator {
        id: subs
        model: opener.children
        delegate: QsMenuOpener { required property var modelData; menu: modelData.hasChildren ? modelData : null }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -7
        radius: Theme.barRadius
        color: tray.containsMouse || tray.kbFocused || tray.activeFocus ? Theme.card : "transparent"
        border.width: tray.kbFocused || tray.activeFocus ? Theme.focusWidth : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    }
    IconImage { anchors.fill: parent; source: tray.modelData.icon }

    // The app's tooltip above the icon, after a short rest, as on Windows.
    property bool tipUp: false
    onContainsMouseChanged: { tipUp = false; if (containsMouse) rest.restart(); else rest.stop(); }
    Timer { id: rest; interval: 500; onTriggered: tray.tipUp = !tray.pressed }
    PopupWindow {
        visible: tray.tipUp && tip.text !== ""
        anchor.item: tray
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -24  // clear of the bar
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        Rectangle {
            id: card
            width: Math.min(300, tip.implicitWidth + 20)
            height: tip.implicitHeight + 12
            radius: 8
            color: Theme.card
            border.width: Theme.rimWidth
            border.color: Theme.line
            Text {
                id: tip
                x: 10; y: 6
                width: parent.width - 20
                text: [tray.modelData.tooltipTitle || tray.modelData.title, tray.modelData.tooltipDescription]
                    .filter(s => s).join("\n")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
    }
}
