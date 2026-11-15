import QtQuick
import Quickshell

// A small right-click menu above an item: menu.show(item, [[label, action], ...]).
// A click anywhere else closes it.
PopupWindow {
    id: menu

    property var items: []

    function show(item, list) {
        items = list;
        anchor.item = item;
        visible = true;
    }

    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -6
    grabFocus: true
    color: "transparent"
    implicitWidth: 230
    implicitHeight: col.implicitHeight + 12

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
                    width: col.width
                    height: 36
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { menu.visible = false; modelData[1](); }
                    Rectangle { anchors.fill: parent; radius: 10; color: row.containsMouse ? Theme.win : "transparent" }
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
