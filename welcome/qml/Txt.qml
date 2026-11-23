import QtQuick

// Text in the shell's type: Inter, the main colour or softened, wrapping by default.
Text {
    property bool soft: false
    property int size: 14
    property bool bold: false
    color: soft ? backend.theme.soft : backend.theme.fg
    font.family: backend.theme.sans
    font.pixelSize: size
    font.weight: bold ? Font.DemiBold : Font.Normal
    wrapMode: Text.WordWrap
    lineHeight: size > 18 ? 1.1 : 1.25
}
