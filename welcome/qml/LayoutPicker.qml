import QtQuick
import QtQuick.Controls.Basic as B
import QtQuick.Layouts

// The desktop layout: the taskbar (the default) or the top bar and dock. Each choice shows a
// small picture of the desktop it gives, and picking one switches the running desktop at once.
ColumnLayout {
    spacing: 12

    Txt {
        text: qsTr("Desktop layout")
        size: 18
        bold: true
    }
    Txt {
        Layout.fillWidth: true
        soft: true
        text: qsTr("Pick the one your hands know. It changes straight away, and you can switch back any time: right-click the taskbar or the dock.")
    }

    Flow {
        Layout.fillWidth: true
        spacing: 12 * 2
        Choice {
            layout: "windows"
            title: qsTr("Taskbar")
            detail: qsTr("Like Windows: Start and your apps along the bottom, window buttons on the right.")
        }
        Choice {
            layout: "mac"
            title: qsTr("Top bar and dock")
            detail: qsTr("Like a Mac: a menu bar at the top, a dock at the bottom, window buttons on the left.")
        }
    }

    component Choice: B.AbstractButton {
        id: choice
        required property string layout
        required property string title
        required property string detail
        readonly property bool mac: layout === "mac"

        width: 18 * 16
        height: column.implicitHeight + 12 * 2
        checkable: true
        checked: backend.layout === layout
        // Stays checked until the other is picked, like a radio button.
        onClicked: {
            checked = Qt.binding(() => backend.layout === layout)
            backend.setLayout(layout)
        }
        Accessible.role: Accessible.RadioButton
        Accessible.name: title
        Accessible.description: detail

        hoverEnabled: true
        scale: down ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        background: Rectangle {
            radius: 14
            color: choice.hovered && !choice.checked ? backend.theme.cardHover : backend.theme.card
            border.width: choice.checked || choice.visualFocus ? 2 : 1
            border.color: choice.checked || choice.visualFocus ? backend.theme.accentText : backend.theme.line
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        contentItem: Item {}
        ColumnLayout {
            id: column
            x: 12
            y: 12
            width: choice.width - 12 * 2
            spacing: 6

            // The picture: a desktop with one window on it.
            Rectangle {
                id: screen
                Layout.fillWidth: true
                Layout.preferredHeight: width * 10 / 16
                radius: 10
                clip: true
                color: Qt.tint(backend.theme.win, Qt.alpha(backend.theme.accent, 0.22))
                readonly property real u: width / 64  // one step of the picture's grid

                // The window, with its three buttons on the right or the left.
                Rectangle {
                    x: screen.u * 12
                    y: screen.u * (choice.mac ? 7 : 5)
                    width: screen.u * 40
                    height: screen.u * 22
                    radius: screen.u
                    color: backend.theme.win
                    Row {
                        x: choice.mac ? screen.u * 1.5 : parent.width - width - screen.u * 1.5
                        y: screen.u * 1.5
                        spacing: screen.u
                        layoutDirection: choice.mac ? Qt.LeftToRight : Qt.RightToLeft
                        Repeater {
                            model: 3
                            Rectangle {
                                width: screen.u * 1.6
                                height: width
                                radius: width / 2
                                // The close button stands out, at the corner.
                                color: index === 0 ? backend.theme.accent : Qt.alpha(backend.theme.fg, 0.35)
                            }
                        }
                    }
                }

                // The taskbar: the full width at the bottom, Start and the apps centred.
                Rectangle {
                    visible: !choice.mac
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: screen.u * 4.5
                    color: backend.theme.win
                    Row {
                        anchors.centerIn: parent
                        spacing: screen.u
                        Repeater {
                            model: 5
                            Rectangle {
                                width: screen.u * 2.6
                                height: width
                                radius: screen.u * 0.6
                                color: index === 0 ? backend.theme.accent : Qt.alpha(backend.theme.fg, 0.35)
                            }
                        }
                    }
                    // The clock and tray at the right.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: screen.u * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 7
                        height: screen.u * 1.2
                        radius: height / 2
                        color: Qt.alpha(backend.theme.fg, 0.35)
                    }
                }

                // The top bar: the system menu and the app at the left, the clock at the right.
                Rectangle {
                    visible: choice.mac
                    width: parent.width
                    height: screen.u * 3
                    color: backend.theme.win
                    Rectangle {
                        x: screen.u * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 1.8
                        height: width
                        radius: width / 2
                        color: backend.theme.accent
                    }
                    Rectangle {
                        x: screen.u * 4.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 6
                        height: screen.u * 1.2
                        radius: height / 2
                        color: Qt.alpha(backend.theme.fg, 0.5)
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: screen.u * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 9
                        height: screen.u * 1.2
                        radius: height / 2
                        color: Qt.alpha(backend.theme.fg, 0.35)
                    }
                }

                // The dock: centred, floating a little above the bottom edge.
                Rectangle {
                    visible: choice.mac
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: screen.u
                    width: dock.width + screen.u * 2
                    height: screen.u * 4.5
                    radius: screen.u * 1.2
                    color: backend.theme.win
                    Row {
                        id: dock
                        anchors.centerIn: parent
                        spacing: screen.u
                        Repeater {
                            model: 6
                            Rectangle {
                                width: screen.u * 2.6
                                height: width
                                radius: screen.u * 0.6
                                color: index === 0 ? backend.theme.accent : Qt.alpha(backend.theme.fg, 0.35)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.topMargin: 6
                spacing: 10
                // The card is the control; this only shows the state, as a radio dot.
                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: backend.theme.card
                    border.width: choice.checked ? 6 : 1.5
                    border.color: choice.checked ? backend.theme.accent : backend.theme.soft
                    Behavior on border.width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
                Txt {
                    Layout.fillWidth: true
                    text: choice.title
                    bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }
            Txt {
                Layout.fillWidth: true
                text: choice.detail
                soft: true
            }
        }
    }
}
