import QtQuick

// A progress track, as the shell's sliders: the accent over a 3:1 track. With no value yet
// (indeterminate) a short piece slides along it.
Rectangle {
    id: m
    property real value: 0
    property bool indeterminate: false
    readonly property var t: backend.theme
    implicitHeight: 6
    radius: 3
    color: t.line
    clip: true
    Rectangle {
        height: parent.height
        radius: 3
        color: m.t.accent
        width: m.indeterminate ? m.width * 0.3 : m.width * Math.max(0, Math.min(1, m.value))
        Behavior on width { enabled: !m.indeterminate; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        SequentialAnimation on x {
            running: m.indeterminate && m.visible
            loops: Animation.Infinite
            NumberAnimation { from: -m.width * 0.3; to: m.width; duration: 1200; easing.type: Easing.InOutCubic }
        }
    }
}
