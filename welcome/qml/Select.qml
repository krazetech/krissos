import QtQuick
import QtQuick.Controls.Basic as B

// A drop-down: a raised card with a chevron, its list a card of rows.
B.ComboBox {
    id: s
    readonly property var t: backend.theme
    implicitHeight: 40
    font.family: t.sans
    font.pixelSize: 14
    contentItem: Text {
        leftPadding: 14
        rightPadding: 36
        text: s.displayText
        font: s.font
        color: s.t.fg
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Glyph {
        x: s.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron"
        size: 16
        rotation: s.popup.visible ? -90 : 90
        color: s.t.soft
        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    background: Rectangle {
        radius: 12
        color: s.hovered ? s.t.cardHover : s.t.card
        border.width: s.visualFocus ? 2 : 1
        border.color: s.visualFocus ? s.t.accentText : s.t.line
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    delegate: B.ItemDelegate {
        required property int index
        required property var modelData
        width: s.width - 8
        x: 4
        highlighted: s.highlightedIndex === index
        contentItem: Text {
            text: modelData
            font: s.font
            color: s.t.fg
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { radius: 10; color: highlighted ? s.t.cardHover : "transparent" }
    }
    popup.background: Rectangle {
        radius: 14
        color: s.t.card
        border.width: 1
        border.color: s.t.line
    }
}
