import QtQuick
import QtQuick.Controls.Basic as B

// The shell's button: a round pill that lights up under the pointer and gives a little when
// pressed. highlighted is the one that goes on (the accent); flat has no fill until hovered.
B.Button {
    id: b
    property string glyph: ""
    readonly property var t: backend.theme
    implicitHeight: 36
    leftPadding: glyph ? 14 : 18
    rightPadding: 18
    font.family: t.sans
    font.pixelSize: 14
    font.weight: highlighted ? Font.DemiBold : Font.Medium
    scale: down ? 0.95 : 1
    opacity: enabled ? 1 : 0.5
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140 } }
    contentItem: Row {
        spacing: 8
        Glyph {
            visible: b.glyph !== ""
            name: b.glyph
            size: 16
            anchors.verticalCenter: parent.verticalCenter
            color: label.color
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: b.text
            font: b.font
            color: b.highlighted ? b.t.accentInk : b.flat ? b.t.accentText : b.t.fg
        }
    }
    background: Rectangle {
        radius: height / 2
        color: b.highlighted ? (b.hovered ? b.t.accentHover : b.t.accent)
             : b.flat ? (b.hovered ? b.t.cardHover : "transparent")
             : b.hovered ? b.t.cardHover : b.t.card
        border.width: b.highlighted || b.flat ? 0 : 1
        border.color: b.t.line
        Behavior on color { ColorAnimation { duration: 140 } }
        // The keyboard focus rim, as the shell's FocusRim.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: b.t.accentText
            visible: b.visualFocus
        }
    }
}
