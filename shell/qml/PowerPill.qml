import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

MouseArea {
    id: pp
    // Only with power-profiles-daemon installed; without it the pill would show a
    // profile that nothing applies.
    visible: ppd.loaded
    FileView {
        id: ppd
        path: "/usr/share/dbus-1/system-services/net.hadess.PowerProfiles.service"
        printErrors: false
    }
    readonly property var order: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.Balanced, PowerProfile.Performance, PowerProfile.PowerSaver]
        : [PowerProfile.Balanced, PowerProfile.PowerSaver]
    readonly property int p: PowerProfiles.profile
    readonly property var look: p === PowerProfile.Performance ? ["performance", Tr.t("Performance")]
        : p === PowerProfile.PowerSaver ? ["saver", Tr.t("Power saver")] : ["balanced", Tr.t("Balanced")]

    // Quiet: an icon in the bar's ink, lit only under the pointer. The mode's name is in the
    // tooltip. Only Power saver on battery takes the accent, since that one changes how the PC runs.
    readonly property bool loud: p === PowerProfile.PowerSaver && UPower.onBattery
    implicitWidth: implicitHeight
    implicitHeight: Math.min(Theme.barButton, (parent?.height ?? Theme.barButton) - 4)  // slimmer in the Mac top bar
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    scale: pressed ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    onClicked: next()
    function next() { PowerProfiles.profile = order[(order.indexOf(p) + 1) % order.length]; }
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        next();
        event.accepted = true;
    }
    Accessible.role: Accessible.Button
    Accessible.name: Tr.t("Power mode: %1", look[1])
    Accessible.description: Tr.t("Switches to the next power mode")
    Accessible.onPressAction: next()
    onPChanged: if (activeFocus) Accessible.announce(look[1])

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.rControl
        color: pp.containsMouse ? Theme.card : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        FocusRim { radius: parent.radius + 2 }
        Glyph {
            anchors.centerIn: parent
            name: pp.look[0]
            size: 18
            color: pp.loud ? Theme.accentText : Theme.fg
        }
    }

    // The mode's name above the icon after a short rest, like the tray's tooltips.
    property bool tipUp: false
    onContainsMouseChanged: { tipUp = false; if (containsMouse) rest.restart(); else rest.stop(); }
    Timer { id: rest; interval: 500; onTriggered: pp.tipUp = !pp.pressed }
    PopupWindow {
        visible: pp.tipUp
        anchor.item: pp
        anchor.edges: Desktop.mac ? Edges.Bottom : Edges.Top
        anchor.gravity: Desktop.mac ? Edges.Bottom : Edges.Top
        anchor.margins.top: Desktop.mac ? 0 : -Theme.s6  // clear of the bar
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
                text: pp.look[1]
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
    }
}
