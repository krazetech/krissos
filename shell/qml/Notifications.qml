import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Toasts stack above the tray, bottom right. The bell opens the same stack with
// everything not yet dismissed.
PanelWindow {
    id: win

    readonly property var items: Desktop.notificationsOpen ? Notifs.all : Notifs.all.filter(n => Notifs.isPopup(n))

    visible: items.length > 0 || Desktop.notificationsOpen
    screen: Quickshell.screens[0]
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-notifications"
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; right: true }
    margins { right: Theme.gap * 1.5; bottom: Theme.gap * 2 + Theme.barHeight }
    implicitWidth: 380
    implicitHeight: Math.min(stack.implicitHeight, 640)
    color: "transparent"

    ColumnLayout {
        id: stack
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 10

        // Header while the list is open.
        RowLayout {
            visible: Desktop.notificationsOpen
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Text {
                Layout.fillWidth: true
                text: Notifs.all.length ? "Notifications" : "No new notifications"
                color: Theme.nightFg
                style: Text.Raised
                styleColor: Theme.alpha(Theme.night, 0.6)
                font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
            }
            MouseArea {
                visible: Notifs.all.length > 0
                implicitWidth: clearText.implicitWidth + 20
                implicitHeight: 28
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clear()
                Rectangle { anchors.fill: parent; radius: 14; color: Theme.bar; border.width: 1; border.color: Theme.rim }
                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }

        Repeater {
            model: win.items
            delegate: MouseArea {
                id: card
                required property var modelData
                readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default")
                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + 28
                cursorShape: defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: defaultAction ? defaultAction.invoke() : modelData.dismiss()

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: Theme.bar
                    border.width: card.modelData.urgency === NotificationUrgency.Critical ? 2 : 1
                    border.color: card.modelData.urgency === NotificationUrgency.Critical ? Theme.red : Theme.rim
                }

                RowLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 40; implicitHeight: 40; radius: 12
                        color: Theme.card
                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            implicitSize: 26
                            visible: status === Image.Ready
                            source: card.modelData.image || Quickshell.iconPath(card.modelData.appIcon || card.modelData.appName.toLowerCase(), true)
                        }
                        Glyph { anchors.centerIn: parent; visible: !appIcon.visible; name: "bell"; size: 20; color: Theme.accent }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary || card.modelData.appName
                                elide: Text.ElideRight
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
                            }
                            MouseArea {
                                implicitWidth: 22; implicitHeight: 22
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.modelData.dismiss()
                                Glyph { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.soft }
                            }
                        }
                        Text {
                            visible: text.length > 0
                            Layout.fillWidth: true
                            text: card.modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: Theme.soft
                            font { family: Theme.sans; pixelSize: 13 }
                            lineHeight: 1.15
                        }
                        Flow {
                            visible: buttons.count > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 6
                            Repeater {
                                id: buttons
                                model: card.modelData.actions.filter(a => a.identifier !== "default")
                                delegate: MouseArea {
                                    id: act
                                    required property var modelData
                                    required property int index
                                    width: actText.implicitWidth + 26
                                    height: 30
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.invoke()
                                    // The first action is the one most apps expect you to take.
                                    Rectangle { anchors.fill: parent; radius: 15; color: act.index === 0 ? Theme.accent : Theme.card }
                                    Text {
                                        id: actText
                                        anchors.centerIn: parent
                                        text: act.modelData.text
                                        color: act.index === 0 ? Theme.accentInk : Theme.fg
                                        font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
