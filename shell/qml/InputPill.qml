import QtQuick
import Quickshell

// The input method in the taskbar, as on Windows: EN, 拼, த or ج (see Ime.qml; not "InputMethod", which is a QtQuick type).
MouseArea {
    id: ip
    readonly property var look: Ime.look
    visible: Ime.shown
    function next(step) { Ime.next(step); }

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 16)
    implicitHeight: Math.min(Theme.barButton, (parent?.height ?? Theme.barButton) - 4)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    scale: pressed ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    onClicked: next(1)
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        next(1);
        event.accepted = true;
    }
    Accessible.role: Accessible.Button
    Accessible.name: Tr.t("Input method: %1", look[1])
    Accessible.description: Tr.t("Switches to the next input method")
    Accessible.onPressAction: next(1)
    onLookChanged: if (activeFocus) Accessible.announce(look[1])

    Rectangle {
        anchors.fill: parent
        radius: Theme.rControl
        color: ip.containsMouse ? Theme.card : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        FocusRim { radius: parent.radius + 2 }
        Text {
            id: label
            anchors.centerIn: parent
            text: ip.look[0]
            color: Theme.fg
            font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
        }
    }

    // The input method's name above the label after a short rest, like the power mode's.
    property bool tipUp: false
    onContainsMouseChanged: { tipUp = false; if (containsMouse) rest.restart(); else rest.stop(); }
    Timer { id: rest; interval: 500; onTriggered: ip.tipUp = !ip.pressed }
    PopupWindow {
        visible: ip.tipUp
        anchor.item: ip
        anchor.edges: Desktop.mac ? Edges.Bottom : Edges.Top
        anchor.gravity: Desktop.mac ? Edges.Bottom : Edges.Top
        anchor.margins.top: Desktop.mac ? 0 : -Theme.s6
        anchor.margins.bottom: Desktop.mac ? -Theme.s3 : 0
        implicitWidth: tip.implicitWidth + 20
        implicitHeight: tip.implicitHeight + 12
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: Theme.rControl
            color: Theme.card
            border.width: Theme.rimWidth
            border.color: Theme.line
            Text {
                id: tip
                anchors.centerIn: parent
                text: ip.look[1]
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
    }
}
