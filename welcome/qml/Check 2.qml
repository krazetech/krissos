import QtQuick
import QtQuick.Controls.Basic as B

// A check box, as the shell's: a rounded square that fills with the accent and a tick.
B.CheckBox {
    id: c
    readonly property var t: backend.theme
    spacing: 10
    font.family: t.sans
    font.pixelSize: 14
    indicator: Rectangle {
        x: c.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; radius: 6
        color: c.checked ? c.t.accent : c.t.card
        border.width: c.checked ? 0 : 1.5
        border.color: c.hovered ? c.t.accentText : c.t.soft
        Behavior on color { ColorAnimation { duration: 140 } }
        Glyph {
            anchors.centerIn: parent
            name: "check"
            size: 14
            stroke: 2.5
            color: c.t.accentInk
            scale: c.checked ? 1 : 0.4
            opacity: c.checked ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }
    contentItem: Text {
        leftPadding: c.indicator.width + c.spacing
        text: c.text
        font: c.font
        color: c.t.fg
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
}
