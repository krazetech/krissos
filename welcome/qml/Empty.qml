import QtQuick
import QtQuick.Layouts

// What a page shows when it has nothing to list: a glyph, a line and why, and maybe a button.
ColumnLayout {
    id: e
    property string glyph
    property string text
    property string explanation
    property string action: ""
    signal triggered()
    spacing: 10
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        width: 64; height: 64; radius: 32
        color: backend.theme.card
        border.width: 1
        border.color: backend.theme.line
        Glyph { anchors.centerIn: parent; name: e.glyph; size: 28; color: backend.theme.accentText }
    }
    Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: e.text; size: 18; bold: true }
    Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: e.explanation; soft: true }
    Pill {
        visible: e.action !== ""
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        text: e.action
        glyph: "globe"
        onClicked: e.triggered()
    }
}
