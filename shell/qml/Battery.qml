import QtQuick
import Quickshell.Services.UPower

Row {
    id: bat
    readonly property var dev: UPower.displayDevice
    visible: dev.isLaptopBattery
    spacing: 6
    anchors.verticalCenter: parent.verticalCenter
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 22; height: 12; radius: 3.5
        color: "transparent"
        border.width: 2
        border.color: Theme.fg
        Rectangle {
            x: 3; y: 3
            height: 6; radius: 1.5
            width: Math.max(1, 16 * bat.dev.percentage)
            color: bat.dev.percentage < 0.15 ? Theme.red : Theme.fg
        }
    }
    // Plugged in: a bolt, as on Windows.
    Glyph {
        visible: !UPower.onBattery
        anchors.verticalCenter: parent.verticalCenter
        name: "charging"
        size: 13
        color: Theme.fg
    }
    RollingText {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(bat.dev.percentage * 100) + "%"
        color: Theme.fg
        font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold; features: { "tnum": 1 } }
    }
}
