import QtQuick

// A soft round button for the lock and login screens: a glyph, and a label when one is
// given. Reached with Tab; Enter or Space presses it.
Rectangle {
    id: btn
    property string glyph
    property string label
    property string accessibleName: label
    property int glyphSize: 16
    property bool primary: false
    signal clicked

    implicitWidth: label ? row.implicitWidth + 28 : 36
    implicitHeight: 36
    radius: height / 2
    color: primary ? Theme.accent
        : Theme.alpha(Theme.nightFg, area.pressed ? 0.22 : area.containsMouse || activeFocus ? 0.16 : 0.0)
    border.width: activeFocus ? 2 : 0
    border.color: Theme.alpha(Theme.nightFg, 0.7)
    scale: area.pressed ? Theme.pressScale : 1
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast) } }
    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

    activeFocusOnTab: visible && enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: clicked()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            clicked();
            event.accepted = true;
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Glyph {
            visible: btn.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: btn.glyph
            size: btn.glyphSize
            color: btn.primary ? Theme.accentInk : Theme.alpha(Theme.nightFg, 0.9)
        }
        Text {
            visible: btn.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            color: Theme.alpha(Theme.nightFg, 0.9)
            font { family: Theme.sans; pixelSize: 14; weight: Font.Medium }
        }
    }
}
