import QtQuick

// Text whose digits roll to their new value when it changes, like NumberFlow; other
// characters just swap. For the clock, the battery and the volume.
Row {
    id: root

    property string text
    property font font
    property color color: Theme.fg

    FontMetrics { id: fm; font: root.font }

    Repeater {
        model: root.text.length
        delegate: Item {
            id: slot
            required property int index
            readonly property string ch: root.text.charAt(index)
            readonly property bool digit: ch >= "0" && ch <= "9"
            width: digit ? fm.advanceWidth("0") : plain.implicitWidth
            height: fm.height
            clip: true

            Text { id: plain; visible: !slot.digit; text: slot.ch; font: root.font; color: root.color }

            // 0 to 9 in a column, slid so the current digit shows.
            Column {
                visible: slot.digit
                y: -(slot.digit ? Number(slot.ch) : 0) * fm.height
                Behavior on y { NumberAnimation { duration: Theme.ms(450); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.21, 1.02, 0.73, 1, 1, 1] } }
                Repeater {
                    model: 10
                    Text { required property int index; height: fm.height; text: index; font: root.font; color: root.color }
                }
            }
        }
    }
}
