import QtQuick
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

    implicitWidth: pill.width
    implicitHeight: 34
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    scale: pressed ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    onClicked: PowerProfiles.profile = order[(order.indexOf(p) + 1) % order.length]

    Rectangle {
        id: pill
        height: parent.height
        width: row.implicitWidth + 26
        radius: height / 2
        color: pp.containsMouse ? Theme.cardHover : Theme.card
        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        border.width: pp.p === PowerProfile.Performance ? 2 : 0
        border.color: Theme.accent
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: pp.look[0]
                size: 16
                color: pp.p === PowerProfile.Performance ? Theme.accent : Theme.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pp.look[1]
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
            }
        }
    }
}
