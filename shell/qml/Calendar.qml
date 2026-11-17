// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The calendar the clock opens, as on Windows: today's date, then the month with today
// marked; the arrows (or the mouse wheel) page through the months and the month's name
// goes back to this one. A click anywhere else or Esc closes it.
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

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date today: clock.date

    // The month on show; it goes back to this month each time the calendar opens.
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
    onOpenChanged: if (open) { month = today.getMonth(); year = today.getFullYear(); }

    MouseArea {
        anchors.fill: parent
        focus: win.open
        onClicked: Desktop.calendarOpen = false
        Keys.onEscapePressed: Desktop.calendarOpen = false
        Keys.onUpPressed: win.page(-1)
        Keys.onDownPressed: win.page(1)
    }

    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.gap * 1.5
        anchors.bottomMargin: Theme.gap
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
            onWheel: wheel => win.page(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: win.today.toLocaleString(Qt.locale(), "dddd, d MMMM yyyy")
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
                    onClicked: win.page((win.today.getFullYear() - win.year) * 12 + win.today.getMonth() - win.month)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        text: new Date(win.year, win.month, 1).toLocaleString(Qt.locale(), "MMMM yyyy")
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
                        onClicked: win.page(modelData[1])
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
                month: win.month
                year: win.year
                locale: Qt.locale()
                spacing: 0
                // A short slide and fade in the direction of the page.
                ParallelAnimation {
                    id: turn
                    NumberAnimation { target: grid; property: "opacity"; from: 0.3; to: 1; duration: Theme.ms(Theme.normal); easing.type: Theme.ease }
                    NumberAnimation { target: shift; property: "y"; from: win.dir * 16; to: 0; duration: Theme.ms(Theme.normal); easing.type: Theme.ease }
                }
                transform: Translate { id: shift }

                delegate: Item {
                    id: day
                    required property var model
                    readonly property bool isToday: model.today
                    readonly property bool inMonth: model.month === win.month
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
    }
}
