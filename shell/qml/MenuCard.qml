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

    width: Math.round(264 * Math.max(1, (1 + Theme.textScale) / 2))
    height: col.implicitHeight + 12
    radius: Theme.rCard
    color: Theme.bar
    border.width: Theme.rimWidth
    border.color: Theme.line
    // Swallows clicks on the card's padding, so they do not reach the layer that closes the menu.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; Accessible.ignored: true }

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
            height: Math.max(30, implicitHeight)
            verticalAlignment: Text.AlignBottom
            bottomPadding: Theme.s1
            leftPadding: Theme.s3
            text: parent.modelData.header
            color: Theme.soft
            font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
        }
    }

    Component {
        id: itemRow
        MouseArea {
            id: row
            readonly property var entry: parent.modelData
            readonly property int index: parent.index
            height: Math.max(36, label.implicitHeight + 14)
            enabled: !entry.off
            Accessible.role: Accessible.MenuItem
            Accessible.name: entry.text
            Accessible.description: entry.sub ? Tr.t("Submenu") : ""
            Accessible.onPressAction: box.picked(index)
            opacity: enabled ? 1 : 0.4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: box.hover(index)
            onExited: box.unhover(index)
            onClicked: box.picked(index)
            Rectangle {
                anchors.fill: parent
                radius: Theme.rControl
                color: row.pressed ? Theme.cardHover : row.index === box.current ? Theme.card : "transparent"
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
            FocusRim { anchors.margins: 0; radius: Theme.rControl; border.width: 1; opacity: 0.6 }
            Text {
                id: label
                anchors.left: parent.left
                anchors.leftMargin: row.entry.icon || row.entry.glyph ? 38 : 12
                anchors.right: parent.right
                anchors.rightMargin: row.entry.sub ? 30 : 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.entry.text
                elide: Text.ElideMiddle
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.Medium }
            }
            Glyph {
                visible: !!row.entry.sub
                anchors.right: parent.right
                anchors.rightMargin: Theme.s2
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron"
                size: 14
                color: Theme.soft
            }
        }
    }
}
