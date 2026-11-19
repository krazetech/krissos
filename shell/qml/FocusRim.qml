import QtQuick

// The keyboard focus mark: a soft accent rim just outside the item, with a hair of space
// between, so it shows on accent-filled controls too; shown while the item has the keyboard.
// Put one inside any control that takes focus; `radius` follows its shape.
Rectangle {
    property Item target: parent
    anchors.fill: parent
    anchors.margins: -4
    radius: Theme.rControl + 4
    color: "transparent"
    border.width: Theme.focusWidth
    border.color: Theme.accentText
    visible: target.activeFocus
}
