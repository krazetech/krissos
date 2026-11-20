import QtQuick
import "reveal.js" as Reveal

// The controls the Settings pages are built from: Settings.qml and its pages in their own
// files (SettingsDisplay.qml) use them as SettingsUi.Card, SettingsUi.Toggle and so on.
QtObject {
    // A group of settings on a raised card.
    component Card: Rectangle {
        default property alias content: inner.data
        width: parent?.width ?? 0
        implicitHeight: inner.implicitHeight + 32
        radius: Theme.rCard
        color: Theme.card
        border.width: Theme.high ? Theme.rimWidth : 0
        border.color: Theme.line
        Column {
            id: inner
            x: 16
            y: 16
            width: parent.width - 32
            spacing: Theme.s3
        }
    }

    component Label: Text {
        width: parent?.width ?? 0
        wrapMode: Text.WordWrap
        color: Theme.fg
        font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
    }

    component Note: Text {
        width: parent?.width ?? 0
        wrapMode: Text.WordWrap
        color: Theme.soft
        font { family: Theme.sans; pixelSize: Theme.sp(13) }
    }

    // One of a few choices, as a row of buttons; a screen reader hears radio buttons.
    component Choice: Column {
        id: choice
        property string text
        property string detail
        property var options    // [[value, label]]
        property string value
        signal picked(string v)
        width: parent?.width ?? 0
        spacing: Theme.s2
        Label { text: choice.text }
        Note { visible: text !== ""; text: choice.detail }
        Flow {
            width: parent.width
            spacing: Theme.s2
            Repeater {
                model: choice.options
                MouseArea {
                    id: opt
                    required property var modelData
                    readonly property bool on: choice.value === modelData[0]
                    width: optText.implicitWidth + 32
                    height: Math.max(36, Theme.sp(13) + 20)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    onClicked: choice.picked(modelData[0])
                    Keys.onSpacePressed: clicked(null)
                    Keys.onReturnPressed: clicked(null)
                    Keys.onEnterPressed: clicked(null)
                    onActiveFocusChanged: if (activeFocus) Reveal.show(opt)
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData[1]
                    Accessible.description: choice.text
                    Accessible.checkable: true
                    Accessible.checked: on
                    Accessible.onPressAction: clicked(null)
                    FocusRim { radius: height / 2 + 4 }
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: opt.on ? (opt.containsMouse ? Theme.accentHover : Theme.accent) : opt.containsMouse ? Theme.cardHover : Theme.win
                        border.width: opt.on ? 0 : Theme.rimWidth
                        border.color: Theme.line
                        scale: opt.pressed ? Theme.pressScale : 1
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: opt.modelData[1]
                        color: opt.on ? Theme.accentInk : Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(13); weight: opt.on ? Font.DemiBold : Font.Medium }
                    }
                }
            }
        }
    }

    // A setting that is on or off: the whole row is the switch.
    component Toggle: MouseArea {
        id: tg
        property string text
        property string detail
        property bool checked
        signal toggled()
        width: parent?.width ?? 0
        height: Math.max(48, words.implicitHeight + 16)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: toggled()
        Keys.onSpacePressed: toggled()
        Keys.onReturnPressed: toggled()
        Keys.onEnterPressed: toggled()
        onActiveFocusChanged: if (activeFocus) Reveal.show(tg)
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        Accessible.description: detail
        Accessible.checkable: true
        Accessible.checked: checked
        Accessible.onPressAction: toggled()
        Accessible.onToggleAction: toggled()
        FocusRim { anchors.margins: -4; radius: Theme.rControl + 4 }
        Column {
            id: words
            anchors.left: parent.left
            anchors.right: track.left
            anchors.rightMargin: Theme.s4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s0
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: tg.text
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
            }
            Text {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: tg.detail
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
        Rectangle {
            id: track
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: height / 2
            color: tg.checked ? (tg.containsMouse ? Theme.accentHover : Theme.accent) : Theme.win
            border.width: tg.checked ? 0 : Theme.rimWidth + 1
            border.color: Theme.soft
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            Rectangle {
                width: 16
                height: 16
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                x: tg.checked ? parent.width - width - 4 : 4
                color: tg.checked ? Theme.accentInk : Theme.soft
                Behavior on x { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
        }
    }

    // A button with words.
    component Push: MouseArea {
        id: push
        property string text
        property bool main
        signal picked()
        width: pushText.implicitWidth + 40
        height: Math.max(36, Theme.sp(13) + 20)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: picked()
        Keys.onSpacePressed: picked()
        Keys.onReturnPressed: picked()
        onActiveFocusChanged: if (activeFocus) Reveal.show(push)
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: picked()
        FocusRim { radius: height / 2 + 4 }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: push.main ? (push.containsMouse ? Theme.accentHover : Theme.accent) : push.containsMouse ? Theme.cardHover : Theme.win
            border.width: push.main ? 0 : Theme.rimWidth
            border.color: Theme.line
            scale: push.pressed ? Theme.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        Text {
            id: pushText
            anchors.centerIn: parent
            text: push.text
            color: push.main ? Theme.accentInk : Theme.fg
            font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
        }
    }

    // One of a list, as a row with a tick (a sound device, a Wi-Fi network): for choices
    // with long names, where Choice's row of buttons would not fit.
    component Radio: MouseArea {
        id: radio
        property string text
        property string detail
        property string glyph
        property string group  // what the choice is for, for screen readers
        property bool on
        signal picked()
        width: parent?.width ?? 0
        height: Math.max(44, words.implicitHeight + 16)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: picked()
        Keys.onSpacePressed: picked()
        Keys.onReturnPressed: picked()
        onActiveFocusChanged: if (activeFocus) Reveal.show(radio)
        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.description: group
        Accessible.checkable: true
        Accessible.checked: on
        Accessible.onPressAction: picked()
        FocusRim { anchors.margins: -4; radius: Theme.rControl + 4 }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: Theme.rControl
            color: radio.containsMouse ? Theme.cardHover : "transparent"
        }
        Glyph { id: rg; visible: radio.glyph !== ""; name: radio.glyph; size: 18; anchors.verticalCenter: parent.verticalCenter }
        Column {
            id: words
            anchors { left: rg.visible ? rg.right : parent.left; leftMargin: rg.visible ? Theme.s3 : 0; right: tick.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: radio.text
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: radio.on ? Font.DemiBold : Font.Medium }
            }
            Text {
                visible: text !== ""
                width: parent.width
                elide: Text.ElideRight
                text: radio.detail
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
        Glyph { id: tick; opacity: radio.on ? 1 : 0; name: "check"; size: 16; color: Theme.accentText; anchors { right: parent.right; verticalCenter: parent.verticalCenter } }
    }

    // A level from 0 to 1 (a volume): a mute button with its glyph, the track, the percent.
    component Slider: Item {
        id: sl
        property string text
        property string glyph
        property real value
        property bool muted
        property bool canMute: true
        signal moved(real v)
        signal muteClicked()
        function nudge(d) { moved(Math.max(0, Math.min(1, Math.round((value + d) * 100) / 100))); }
        width: parent?.width ?? 0
        height: 40
        MouseArea {
            id: mute
            width: 36; height: 36
            anchors.verticalCenter: parent.verticalCenter
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: sl.canMute
            onClicked: sl.muteClicked()
            Keys.onSpacePressed: sl.muteClicked()
            Keys.onReturnPressed: sl.muteClicked()
            Accessible.role: sl.canMute ? Accessible.Button : Accessible.Graphic
            Accessible.name: sl.canMute ? Tr.t("Mute %1", sl.text) : sl.text
            Accessible.checkable: sl.canMute
            Accessible.checked: sl.muted
            Accessible.onPressAction: if (sl.canMute) sl.muteClicked()
            FocusRim { radius: height / 2 }
            Glyph { anchors.centerIn: parent; name: sl.glyph; size: 19 }
        }
        MouseArea {
            id: track
            anchors { left: mute.right; leftMargin: Theme.s2; right: pct.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            height: 28
            cursorShape: Qt.PointingHandCursor
            function set(x) { sl.moved(Math.max(0, Math.min(1, x / width))); }
            // A slider to a screen reader, in percent; arrows move it 5%, Page Up and Down 10%.
            readonly property real value: Math.round(sl.value * 100)
            readonly property real minimumValue: 0
            readonly property real maximumValue: 100
            readonly property real stepSize: 5
            activeFocusOnTab: true
            onActiveFocusChanged: if (activeFocus) Reveal.show(sl)
            Accessible.role: Accessible.Slider
            Accessible.name: sl.text
            Accessible.onIncreaseAction: sl.nudge(0.05)
            Accessible.onDecreaseAction: sl.nudge(-0.05)
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Right: case Qt.Key_Up: sl.nudge(0.05); break;
                case Qt.Key_Left: case Qt.Key_Down: sl.nudge(-0.05); break;
                case Qt.Key_PageUp: sl.nudge(0.1); break;
                case Qt.Key_PageDown: sl.nudge(-0.1); break;
                case Qt.Key_Home: sl.moved(0); break;
                case Qt.Key_End: sl.moved(1); break;
                default: return;
                }
                event.accepted = true;
            }
            FocusRim { anchors.margins: -1; radius: Theme.rCard }
            onPressed: mouse => set(mouse.x)
            onPositionChanged: mouse => { if (pressed) set(mouse.x); }
            onWheel: wheel => sl.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: height / 2
                color: Theme.track
                border.width: Theme.high ? 1 : 0
                border.color: Theme.line
                Rectangle { width: parent.width * Math.min(1, sl.value); height: parent.height; radius: height / 2; color: sl.muted ? Theme.soft : Theme.accentText }
            }
            Rectangle {
                x: track.width * Math.min(1, sl.value) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: width / 2
                color: Theme.fg
                border.width: 4
                border.color: sl.muted ? Theme.soft : Theme.accentText
            }
        }
        Text {
            id: pct
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: Math.max(36, implicitWidth)
            horizontalAlignment: Text.AlignRight
            text: Math.round(sl.value * 100)
            color: Theme.soft
            font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
            Accessible.ignored: true
        }
    }

    // A row that goes to a page: glyph, name, what is on it, and an arrow (another window's
    // arrow for a COSMIC Settings page).
    component LinkRow: MouseArea {
        id: link
        property string glyph
        property string text
        property string detail
        property bool external
        signal picked()
        width: parent?.width ?? 0
        height: Math.max(56, words.implicitHeight + 20)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: picked()
        Keys.onReturnPressed: picked()
        Keys.onSpacePressed: picked()
        onActiveFocusChanged: if (activeFocus) Reveal.show(link)
        Accessible.role: Accessible.Link
        Accessible.name: text
        Accessible.description: detail
        Accessible.onPressAction: picked()
        FocusRim { anchors.margins: -4; radius: Theme.rControl + 4 }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: Theme.rControl
            color: link.containsMouse ? Theme.cardHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        Glyph { id: lg; name: link.glyph; size: 20; anchors.verticalCenter: parent.verticalCenter }
        Column {
            id: words
            anchors { left: lg.right; leftMargin: Theme.s3; right: arrow.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            spacing: Theme.s0
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: link.text
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
            }
            Text {
                visible: text !== ""
                width: parent.width
                elide: Text.ElideRight
                text: link.detail
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
        Glyph { id: arrow; name: link.external ? "external" : "chevron"; size: 16; color: Theme.soft; anchors { right: parent.right; verticalCenter: parent.verticalCenter } }
    }
}
