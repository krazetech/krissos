import QtQuick
import Quickshell
import "fuzzy.js" as Fuzzy

// A small right-click menu above an item: menu.show(item, [[label, action], ...]).
// It works from the keyboard the way Radix menus do: up and down (Home, End) move one
// highlight that the pointer shares, Enter or Space picks, Esc closes, Tab stays inside,
// and typing jumps to the item that starts with those letters. A click anywhere else
// closes it. Opened from the keyboard (byKeyboard), the first item starts highlighted.
PopupWindow {
    id: menu

    property var items: []
    property int current: -1
    property string typed: ""

    function show(item, list, byKeyboard) {
        items = list;
        current = byKeyboard ? 0 : -1;
        typed = "";
        anchor.item = item;
        visible = true;
        keys.forceActiveFocus();
    }

    function pick(i) {
        if (i < 0 || i >= items.length) return;
        visible = false;
        items[i][1]();
    }

    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -6
    grabFocus: true
    color: "transparent"
    implicitWidth: 230
    implicitHeight: col.implicitHeight + 12

    Timer { id: typeReset; interval: 1000; onTriggered: menu.typed = "" }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const n = menu.items.length;
            switch (event.key) {
            case Qt.Key_Down: menu.current = Math.min(n - 1, menu.current + 1); break;
            case Qt.Key_Up: menu.current = menu.current < 0 ? n - 1 : Math.max(0, menu.current - 1); break;
            case Qt.Key_Home: menu.current = 0; break;
            case Qt.Key_End: menu.current = n - 1; break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: menu.pick(menu.current); break;
            case Qt.Key_Escape: menu.visible = false; break;
            case Qt.Key_Tab: case Qt.Key_Backtab: break;  // the focus stays in the menu
            default:
                if (!event.text || event.text.trim() === "" || event.modifiers & Qt.ControlModifier) return;
                menu.typed += event.text;
                typeReset.restart();
                const i = Fuzzy.typeahead(menu.items.map(it => it[0]), menu.typed, menu.current);
                if (i >= 0) menu.current = i;
            }
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall + 2
        color: Theme.card
        border.width: 1
        border.color: Theme.line

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - 12
            Repeater {
                model: menu.items
                delegate: MouseArea {
                    id: row
                    required property var modelData
                    required property int index
                    width: col.width
                    height: 36
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: menu.current = index
                    onExited: if (menu.current === index) menu.current = -1
                    onClicked: menu.pick(index)
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: row.pressed ? Theme.cardHover : row.index === menu.current ? Theme.win : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData[0]
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: 13; weight: Font.Medium }
                    }
                }
            }
        }
    }
}
