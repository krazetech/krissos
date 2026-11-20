import QtQuick
import QtQuick.Controls.Basic as B

// A text field: a raised card that takes an accent rim when focused.
B.TextField {
    id: f
    property string glyph: ""
    readonly property var t: backend.theme
    implicitHeight: 42
    leftPadding: glyph ? 40 : 14
    rightPadding: 14
    color: t.fg
    placeholderTextColor: t.soft
    selectionColor: t.accent
    selectedTextColor: t.accentInk
    font.family: t.sans
    font.pixelSize: 15
    background: Rectangle {
        radius: 12
        color: f.t.card
        border.width: f.activeFocus ? 2 : 1
        border.color: f.activeFocus ? f.t.accentText : f.t.line
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Glyph {
            visible: f.glyph !== ""
            name: f.glyph
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            size: 18
            color: f.t.soft
        }
    }
}
