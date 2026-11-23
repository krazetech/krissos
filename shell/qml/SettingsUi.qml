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
}
