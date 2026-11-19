import QtQuick
import Quickshell
import Quickshell.Wayland
import "fuzzy.js" as Fuzzy

// A right-click menu next to an item: menu.show(item, entries, byKeyboard). Entries are
//   {text, run, icon (theme icon) or glyph (Glyph name)}   an item
//   {text, sub: [entries]}                                   a submenu, to the side
//   {header: "Recent"}                                       a small title
//   {sep: true}                                              a line
// and off: true greys an item out.
// It works from the keyboard the way Radix menus do: up and down (Home, End) move one
// highlight that the pointer shares, Enter or Space picks, Right opens a submenu and Left
// or Esc closes it, Tab stays inside, and typing jumps to the item that starts with those
// letters. Opened from the keyboard (byKeyboard), the first item starts highlighted.
//
// The menu is a clear layer over the whole screen with the card drawn on it, so a click
// anywhere else lands on the layer and closes the menu. (It used to be an xdg popup:
// cosmic-comp never tells a popup a click went elsewhere, so the first menu stayed open
// and every later show() on it did nothing.)
PanelWindow {
    id: menu

    property var entries: []
    property var subEntries: []
    property int current: -1
    property int subCurrent: -1
    property int subOf: -1      // the entry whose submenu is open
    property string typed: ""
    // Where the item sits on its screen, which the card is placed against.
    property rect at: Qt.rect(0, 0, 0, 0)

    function show(item, list, byKeyboard) {
        const win = item.QsWindow.window;
        const p = item.mapToItem(null, 0, 0);
        // ponytail: the shell's windows are layer surfaces anchored to edges, so their place on
        // the screen follows from the anchors; a window with margins would need them added.
        const s = win.screen;
        const wx = win.anchors.left ? 0 : win.anchors.right ? s.width - win.width : (s.width - win.width) / 2;
        const wy = win.anchors.top ? 0 : win.anchors.bottom ? s.height - win.height : (s.height - win.height) / 2;
        screen = s;
        at = Qt.rect(wx + p.x, wy + p.y, item.width, item.height);
        entries = list;
        subOf = -1;
        current = byKeyboard ? next(entries, -1, 1) : -1;
        typed = "";
        visible = true;
        card.opacity = 0;
        appear.restart();
        focusRow(card, current);
    }

    function close() {
        if (!visible) return;
        visible = false;
        subOf = -1;
        Desktop.retakeKeys();
    }

    function pickable(e) { return e && !e.header && !e.sep && !e.off; }
    // The next pickable entry from i in direction d, or i if there is none.
    function next(list, i, d) {
        for (let j = i + d; j >= 0 && j < list.length; j += d)
            if (pickable(list[j])) return j;
        return i;
    }

    function openSub(i, byKeyboard) {
        subEntries = entries[i].sub;
        subOf = i;
        subCurrent = byKeyboard ? next(subEntries, -1, 1) : -1;
    }

    function pick(list, i) {
        const e = list[i];
        if (!pickable(e)) return;
        if (e.sub) { openSub(i, true); return; }
        close();
        e.run();
    }

    screen: Quickshell.screens[0]
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    Timer { id: typeReset; interval: 1000; onTriggered: menu.typed = "" }

    // A click anywhere off the card closes the menu, as on Windows.
    MouseArea {
        Accessible.ignored: true  // pointer only; the keyboard has its own way
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
    }

    // The highlighted row has the keyboard focus, so a screen reader follows it; the keys
    // come up to here from it.
    onCurrentChanged: if (subOf < 0 || subCurrent < 0) focusRow(card, current)
    onSubCurrentChanged: if (subOf >= 0) focusRow(side, subCurrent)
    onSubOfChanged: if (subOf < 0) focusRow(card, current)
    function focusRow(c, i) { (c.rowAt(i)?.item ?? keys).forceActiveFocus(); }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Accessible.role: Accessible.PopupMenu
        Accessible.name: Tr.t("Menu")
        Keys.onPressed: event => {
            const inSub = menu.subOf >= 0 && menu.subCurrent >= 0;
            const list = inSub ? menu.subEntries : menu.entries;
            const cur = inSub ? menu.subCurrent : menu.current;
            const set = i => { if (inSub) menu.subCurrent = i; else menu.current = i; };
            const first = menu.next(list, -1, 1), last = menu.next(list, list.length, -1);
            switch (event.key) {
            case Qt.Key_Down: set(cur < 0 ? first : menu.next(list, cur, 1)); break;
            case Qt.Key_Up: set(cur < 0 ? last : menu.next(list, cur, -1)); break;
            case Qt.Key_Home: set(first); break;
            case Qt.Key_End: set(last); break;
            case Qt.Key_Right:
                if (!inSub && list[cur]?.sub) menu.openSub(cur, true);
                break;
            case Qt.Key_Left:
                if (menu.subOf >= 0) menu.subOf = -1;
                break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: menu.pick(list, cur); break;
            case Qt.Key_Escape:
                if (menu.subOf >= 0) menu.subOf = -1; else menu.close();
                break;
            case Qt.Key_Tab: case Qt.Key_Backtab: break;  // the focus stays in the menu
            default:
                if (!event.text || event.text.trim() === "" || event.modifiers & Qt.ControlModifier) return;
                menu.typed += event.text;
                typeReset.restart();
                const i = Fuzzy.typeahead(list.map(e => menu.pickable(e) ? e.text : ""), menu.typed, cur);
                if (i >= 0) set(i);
            }
            event.accepted = true;
        }

    // Above the item (below it when there is no room), centred on it and kept on the screen.
    MenuCard {
        id: card
        entries: menu.entries
        current: menu.current
        x: Math.max(8, Math.min(menu.width - width - 8, menu.at.x + menu.at.width / 2 - width / 2))
        y: menu.at.y - height - 8 >= 8 ? menu.at.y - height - 8 : Math.min(menu.height - height - 8, menu.at.y + menu.at.height + 8)
        onHover: i => { menu.current = i; if (menu.subOf !== i && menu.entries[i]?.sub) menu.openSub(i, false); else if (!menu.entries[i]?.sub) menu.subOf = -1; }
        onUnhover: i => { if (menu.current === i && menu.subOf !== i) menu.current = -1; }
        onPicked: i => menu.pick(menu.entries, i)
        NumberAnimation { id: appear; target: card; property: "opacity"; from: 0; to: 1; duration: Theme.ms(Theme.fast); easing.type: Theme.ease }
    }

    // The submenu: beside its row, on the side with room.
    MenuCard {
        id: side
        visible: menu.subOf >= 0
        entries: menu.subEntries
        current: menu.subCurrent
        width: Math.round(200 * Math.max(1, (1 + Theme.textScale) / 2))
        readonly property real rowY: card.y + (card.rowAt(menu.subOf)?.y ?? 0)  // the row's top, less the card's padding
        x: card.x + card.width + width - 4 <= menu.width - 8 ? card.x + card.width - 4 : card.x - width + 4
        y: Math.max(8, Math.min(card.y + card.height - height, rowY))
        onHover: i => { menu.subCurrent = i; menu.current = menu.subOf; }
        onPicked: i => menu.pick(menu.subEntries, i)
    }
    }
}
