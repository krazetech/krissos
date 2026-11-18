import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Today's date, then the month with today marked; the arrows page through the months and
// the month's name goes back to this one. The calendar under the clock and the
// notification center show it.
ColumnLayout {
    id: root
    spacing: 10

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date today: clock.date

    // The month on show; reset() goes back to this one.
    property int month: today.getMonth()
    property int year: today.getFullYear()
    // -1 or 1: which way the last page went, for the slide.
    property int dir: 0
    function page(step) {
        const d = new Date(year, month + step, 1);
        dir = step > 0 ? 1 : step < 0 ? -1 : 0;
        month = d.getMonth();
        year = d.getFullYear();
        if (dir) turn.restart();
    }
    function reset() { month = today.getMonth(); year = today.getFullYear(); }

    Text {
        Layout.fillWidth: true
        text: root.today.toLocaleString(Qt.locale(), "dddd, d MMMM yyyy")
        elide: Text.ElideRight
        color: Theme.fg
        font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        MouseArea {
            id: title
            Layout.fillWidth: true
            implicitHeight: 32
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.page((root.today.getFullYear() - root.year) * 12 + root.today.getMonth() - root.month)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                text: new Date(root.year, root.month, 1).toLocaleString(Qt.locale(), "MMMM yyyy")
                color: title.containsMouse ? Theme.accent : Theme.fg
                font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
        }
        Repeater {
            model: [["up", -1], ["down", 1]]
            delegate: MouseArea {
                id: arrow
                required property var modelData
                implicitWidth: 32; implicitHeight: 32
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.page(modelData[1])
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: arrow.containsMouse ? Theme.cardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: arrow.modelData[0]; size: 18 }
            }
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: grid.locale
        delegate: Text {
            required property string shortName
            text: shortName.slice(0, 2)
            horizontalAlignment: Text.AlignHCenter
            color: Theme.soft
            font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
        }
    }

    MonthGrid {
        id: grid
        Layout.fillWidth: true
        implicitHeight: 6 * 40
        month: root.month
        year: root.year
        locale: Qt.locale()
        spacing: 0
        // A short slide and fade in the direction of the page.
        ParallelAnimation {
            id: turn
            NumberAnimation { target: grid; property: "opacity"; from: 0.3; to: 1; duration: Theme.ms(Theme.normal); easing.type: Theme.ease }
            NumberAnimation { target: shift; property: "y"; from: root.dir * 16; to: 0; duration: Theme.ms(Theme.normal); easing.type: Theme.ease }
        }
        transform: Translate { id: shift }

        delegate: Item {
            id: day
            required property var model
            readonly property bool isToday: model.today
            readonly property bool inMonth: model.month === root.month
            implicitHeight: 40
            Rectangle {
                anchors.centerIn: parent
                width: 34; height: 34; radius: 17
                color: day.isToday ? Theme.accent : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: day.model.day
                color: day.isToday ? Theme.accentInk : day.inMonth ? Theme.fg : Theme.alpha(Theme.soft, 0.5)
                font { family: Theme.sans; pixelSize: 13; weight: day.isToday ? Font.Bold : Font.Normal; features: { "tnum": 1 } }
            }
        }
    }
}
