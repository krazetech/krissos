import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The desktop layout: the taskbar (the default) or the top bar and dock. Each choice shows a
// small picture of the desktop it gives, and picking one switches the running desktop at once.
ColumnLayout {
    spacing: Kirigami.Units.largeSpacing

    Kirigami.Heading {
        level: 2
        text: qsTr("Desktop layout")
    }
    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Pick the one your hands know. It changes straight away, and you can switch back any time: right-click the taskbar or the dock.")
    }

    Flow {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing * 2
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

    component Choice: QQC2.AbstractButton {
        id: choice
        required property string layout
        required property string title
        required property string detail
        readonly property bool mac: layout === "mac"

        width: Kirigami.Units.gridUnit * 16
        height: column.implicitHeight + Kirigami.Units.largeSpacing * 2
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

        background: Rectangle {
            radius: Kirigami.Units.cornerRadius * 2
            color: choice.checked ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                 : choice.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.05) : "transparent"
            border.width: choice.checked || choice.visualFocus ? 2 : 1
            border.color: choice.checked || choice.visualFocus ? Kirigami.Theme.highlightColor
                        : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }

        contentItem: Item {}
        ColumnLayout {
            id: column
            x: Kirigami.Units.largeSpacing
            y: Kirigami.Units.largeSpacing
            width: choice.width - Kirigami.Units.largeSpacing * 2
            spacing: Kirigami.Units.smallSpacing

            // The picture: a desktop with one window on it.
            Rectangle {
                id: screen
                Layout.fillWidth: true
                Layout.preferredHeight: width * 10 / 16
                radius: Kirigami.Units.cornerRadius
                clip: true
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                readonly property real u: width / 64  // one step of the picture's grid

                // The window, with its three buttons on the right or the left.
                Rectangle {
                    x: screen.u * 12
                    y: screen.u * (choice.mac ? 7 : 5)
                    width: screen.u * 40
                    height: screen.u * 22
                    radius: screen.u
                    color: Kirigami.Theme.backgroundColor
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
                                color: index === 0 ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.35)
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
                    color: Kirigami.Theme.backgroundColor
                    Row {
                        anchors.centerIn: parent
                        spacing: screen.u
                        Repeater {
                            model: 5
                            Rectangle {
                                width: screen.u * 2.6
                                height: width
                                radius: screen.u * 0.6
                                color: index === 0 ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.35)
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
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
                    }
                }

                // The top bar: the system menu and the app at the left, the clock at the right.
                Rectangle {
                    visible: choice.mac
                    width: parent.width
                    height: screen.u * 3
                    color: Kirigami.Theme.backgroundColor
                    Rectangle {
                        x: screen.u * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 1.8
                        height: width
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                    }
                    Rectangle {
                        x: screen.u * 4.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 6
                        height: screen.u * 1.2
                        radius: height / 2
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.5)
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: screen.u * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: screen.u * 9
                        height: screen.u * 1.2
                        radius: height / 2
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
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
                    color: Kirigami.Theme.backgroundColor
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
                                color: index === 0 ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.35)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.topMargin: Kirigami.Units.smallSpacing
                QQC2.RadioButton {
                    // The card is the control; this only shows the state.
                    checked: choice.checked
                    focusPolicy: Qt.NoFocus
                    Accessible.ignored: true
                    onClicked: {
                        checked = Qt.binding(() => choice.checked)
                        choice.clicked()
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: choice.title
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: choice.detail
                wrapMode: Text.WordWrap
                opacity: 0.8
            }
        }
    }
}
