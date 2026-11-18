import QtQuick
import Quickshell
import Quickshell.Widgets

// One card of a Menu (the menu itself, or a submenu beside it): rows of entries, one
// highlighted. See Menu.qml for what the entries can be.
Rectangle {
    id: box
    property var entries: []
    property int current: -1
    signal hover(int i)
    signal unhover(int i)
    signal picked(int i)
    function rowAt(i) { return rows.itemAt(i); }

    width: 264
    height: col.implicitHeight + 12
    radius: Theme.radiusSmall + 2
    color: Theme.card
    border.width: 1
    border.color: Theme.line
    // Swallows clicks on the card's padding, so they do not reach the layer that closes the menu.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Column {
        id: col
        x: 6
        y: 6
        width: parent.width - 12
        Repeater {
            id: rows
            model: box.entries
            delegate: Loader {
                required property var modelData
                required property int index
                width: col.width
                sourceComponent: modelData.sep ? sepRow : modelData.header ? headerRow : itemRow
            }
        }
    }

    Component {
        id: sepRow
        Item {
            height: 9
            Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.line }
        }
    }

    Component {
        id: headerRow
        Text {
            height: 30
            verticalAlignment: Text.AlignBottom
            bottomPadding: 6
            leftPadding: 12
            text: parent.modelData.header
            color: Theme.soft
            font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
        }
    }

    Component {
        id: itemRow
        MouseArea {
            id: row
            readonly property var entry: parent.modelData
            readonly property int index: parent.index
            height: 36
            enabled: !entry.off
            opacity: enabled ? 1 : 0.4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: box.hover(index)
            onExited: box.unhover(index)
            onClicked: box.picked(index)
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: row.pressed ? Theme.cardHover : row.index === box.current ? Theme.win : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
            IconImage {
                id: icon
                visible: !!row.entry.icon
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                // A theme icon name, or a URL or path (tray menus send those).
                source: !row.entry.icon ? "" : row.entry.icon.includes("/") ? row.entry.icon
                    : Quickshell.iconPath(row.entry.icon, true) || Quickshell.iconPath("text-x-generic")
            }
            Glyph {
                visible: !!row.entry.glyph
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                name: row.entry.glyph ?? ""
                size: 17
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: row.entry.icon || row.entry.glyph ? 38 : 12
                anchors.right: parent.right
                anchors.rightMargin: row.entry.sub ? 30 : 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.entry.text
                elide: Text.ElideMiddle
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 13; weight: Font.Medium }
            }
            Glyph {
                visible: !!row.entry.sub
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron"
                size: 14
                color: Theme.soft
            }
        }
    }
}
