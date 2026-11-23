import QtQuick
import QtQuick.Layouts

// A raised card, as the shell's panels hold them (rCard 14, a hairline rim). Its children
// stack in a column.
Rectangle {
    id: card
    default property alias content: box.data
    property int padding: 16
    property alias spacing: box.spacing
    color: backend.theme.card
    radius: 14
    border.width: 1
    border.color: backend.theme.line
    implicitHeight: box.implicitHeight + padding * 2
    Behavior on color { ColorAnimation { duration: 140 } }

    ColumnLayout {
        id: box
        x: card.padding
        y: card.padding
        width: card.width - card.padding * 2
        spacing: 8
    }
}
