import QtQuick
import QtQuick.Layouts

// A message on the page: a card with a coloured glyph. kind is info, good, warn or bad.
Rectangle {
    id: note
    property string text
    property string kind: "info"
    readonly property var t: backend.theme
    readonly property color tone: kind === "good" ? t.green : kind === "warn" ? t.amber
                                : kind === "bad" ? t.red : t.accentText
    color: Qt.tint(t.card, Qt.alpha(tone, 0.10))
    radius: 14
    border.width: 1
    border.color: Qt.alpha(tone, 0.35)
    implicitHeight: row.implicitHeight + 24
    RowLayout {
        id: row
        x: 14; y: 12
        width: note.width - 28
        spacing: 12
        Glyph {
            Layout.alignment: Qt.AlignTop
            name: note.kind === "good" ? "check" : note.kind === "info" ? "info" : "warn"
            color: note.tone
        }
        Txt { Layout.fillWidth: true; text: note.text }
    }
}
