import QtQuick
import Quickshell
import Quickshell.Wayland

// The calendar the clock opens, as on Windows (see Month.qml); the mouse wheel pages
// through the months too. A click anywhere else or Esc closes it.
// ponytail: no events or agenda; the shell has no calendar data to show.
PanelWindow {
    id: win

    readonly property bool open: Desktop.calendarOpen
    // Stays up while the card fades away, but lets clicks through to what is behind it.
    visible: open || card.opacity > 0
    mask: open ? null : noInput
    Region { id: noInput }
    screen: Desktop.screen
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-calendar"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Leaves the bar uncovered, so the clock closes it again.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    onOpenChanged: if (open) body.reset()

    MouseArea {
        anchors.fill: parent
        focus: win.open
        onClicked: Desktop.calendarOpen = false
        Keys.onEscapePressed: Desktop.calendarOpen = false
        Keys.onUpPressed: body.page(-1)
        Keys.onDownPressed: body.page(1)
    }

    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.panelGap
        anchors.bottomMargin: Theme.panelGap + Desktop.barRoom
        width: 336
        height: body.implicitHeight + 36
        radius: Theme.radius
        color: Theme.win
        border.width: 1
        border.color: Theme.rim
        // Rises a little as it fades in, like the volume pop-up.
        opacity: win.open ? 1 : 0
        transform: Translate { y: win.open || Theme.reduceMotion ? 0 : 12; Behavior on y { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } } }
        Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }

        // Swallows clicks on the card, so only clicks outside it close the calendar.
        MouseArea {
            anchors.fill: parent
            onWheel: wheel => body.page(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        Month {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        }
    }
}
