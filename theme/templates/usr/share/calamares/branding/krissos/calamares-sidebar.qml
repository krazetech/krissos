// The installer's step list, as a KrissOS Shell panel: one raised card with the emblem, the
// steps (done ones ticked, the current one lit) and how far along you are.
// Rendered from theme/tokens.json, once per light and dark (theme/generate.py).
// ponytail: no About or Debug buttons; kriss-install runs `calamares -d` only for the log.
import io.calamares.ui 1.0
import QtQuick 2.15

Rectangle {
    id: root
    color: "{{ui_win}}"

    readonly property int current: ViewManager.currentStepIndex
    readonly property int count: steps.count

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        anchors.rightMargin: 0
        radius: 22
        color: "{{ui_card}}"
        border.width: 1
        border.color: "{{ui_line}}"

        Column {
            id: header
            x: 20; y: 22
            spacing: 10
            Image {
                source: "file:" + Branding.imagePath(Branding.ProductLogo)
                width: 40; height: 40
                sourceSize.width: 80; sourceSize.height: 80
            }
            Column {
                Text {
                    text: Branding.string(Branding.ProductName)
                    color: "{{fg}}"
                    font.family: "{{font_sans}}"; font.pixelSize: 17; font.weight: Font.DemiBold
                }
                Text {
                    text: "Installer · Pemasang"
                    color: "{{ui_soft}}"
                    font.family: "{{font_sans}}"; font.pixelSize: 12
                }
            }
        }

        Item {
            id: list
            anchors.top: header.bottom
            anchors.topMargin: 24
            x: 10
            width: parent.width - 20
            height: steps.count * 40

            // The lit row slides to the current step, like the shell's hover.
            Rectangle {
                y: root.current * 40
                width: parent.width; height: 36
                radius: 10
                color: "{{ui_hover}}"
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Repeater {
                id: steps
                model: ViewManager
                Item {
                    readonly property bool done: index < root.current
                    readonly property bool now: index === root.current
                    y: index * 40
                    width: list.width; height: 36

                    Rectangle {
                        id: dot
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 11
                        color: done ? "{{accent}}" : "transparent"
                        border.width: done ? 0 : 1.5
                        border.color: now ? "{{ui_accent_text}}" : "{{ui_line}}"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            anchors.centerIn: parent
                            text: done ? "✓" : index + 1
                            color: done ? "{{bg}}" : now ? "{{ui_accent_text}}" : "{{ui_soft}}"
                            font.family: "{{font_sans}}"; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        anchors.left: dot.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: display
                        elide: Text.ElideRight
                        color: now ? "{{fg}}" : "{{ui_soft}}"
                        font.family: "{{font_sans}}"; font.pixelSize: 14
                        font.weight: now ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }

        // How far along: a thin accent track at the bottom of the card.
        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            x: 20
            width: parent.width - 40
            spacing: 8
            Text {
                text: (root.current + 1) + " / " + root.count
                color: "{{ui_soft}}"
                font.family: "{{font_mono}}"; font.pixelSize: 12
            }
            Rectangle {
                width: parent.width; height: 4; radius: 2
                color: "{{ui_line}}"
                Rectangle {
                    width: root.count > 1 ? parent.width * root.current / (root.count - 1) : 0
                    height: parent.height; radius: 2
                    color: "{{accent}}"
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
