import QtQuick

// Text whose digits roll to their new value when it changes, like NumberFlow; other
// characters just swap. For the clock, the battery and the volume.
Row {
    id: root

    property string text
    property font font
    property color color: Theme.fg

    // Read out as the text, not the digit columns.
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    // A digit's size, in whole pixels (at a fractional line height the columns drift and clip
    // their tops). From a Text, not FontMetrics, so it follows the font when the text size changes.
    Text { id: zero; visible: false; text: "0"; font: root.font; Accessible.ignored: true }
    readonly property real step: Math.ceil(zero.implicitHeight)

    Repeater {
        model: root.text.length
        delegate: Item {
            id: slot
            required property int index
            readonly property string ch: root.text.charAt(index)
            readonly property bool digit: ch >= "0" && ch <= "9"
            width: digit ? Math.ceil(zero.implicitWidth) : plain.implicitWidth
            height: root.step
            clip: true
            Accessible.ignored: true

            Text { id: plain; visible: !slot.digit; text: slot.ch; font: root.font; color: root.color }

            // 0 to 9 in a column, slid so the current digit shows.
            Column {
                visible: slot.digit
                y: -(slot.digit ? Number(slot.ch) : 0) * root.step
                Behavior on y { NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settleCurve } }
                Repeater {
                    model: 10
                    Text { required property int index; height: root.step; text: index; font: root.font; color: root.color }
                }
            }
        }
    }
}
