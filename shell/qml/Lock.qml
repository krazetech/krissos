import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.UPower

// The lock screen: blurred wallpaper, the time, and a password field checked by PAM.
// One surface per screen; they share the typed password.
Scope {
    id: root

    property string password: ""
    property string message: ""
    property bool checking: false

    function submit() {
        if (checking || password === "") return;
        checking = true;
        message = "";
        pam.start();
    }

    PamContext {
        id: pam
        onResponseRequiredChanged: if (responseRequired) respond(root.password)
        onCompleted: result => {
            root.checking = false;
            root.password = "";
            if (result === PamResult.Success) {
                Desktop.locked = false;
            } else {
                root.message = Tr.t("That password didn't work. Try again.");
            }
        }
    }

    WlSessionLock {
        locked: Desktop.locked

        WlSessionLockSurface {
            color: Theme.night

            Image {
                id: wall
                anchors.fill: parent
                source: "file:///usr/share/backgrounds/kriss/default.svg"
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blur: 1
                blurMax: 48
                brightness: -0.15
            }

            SystemClock { id: clock; precision: SystemClock.Minutes }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.nightFg
                    font { family: Theme.sans; pixelSize: 132; weight: Font.Light; features: { "tnum": 1 } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.date.toLocaleString(Qt.locale(), "dddd, d MMMM")
                    color: Theme.alpha(Theme.nightFg, 0.8)
                    font { family: Theme.sans; pixelSize: 24; weight: Font.Medium }
                }

                Item { width: 1; height: 40 }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 84; height: 84; radius: 42
                    // The accent disc shows only without kriss-theme's emblem.
                    color: lockLogo.status === Image.Ready ? "transparent" : Theme.accent
                    Image {
                        id: lockLogo
                        anchors.fill: parent
                        source: "file:///usr/share/pixmaps/krissos.svg"
                        sourceSize: Qt.size(168, 168)
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Quickshell.env("USER") ?? ""
                    color: Theme.nightFg
                    font { family: Theme.sans; pixelSize: 20; weight: Font.DemiBold }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 380; height: 54; radius: 27
                    color: Theme.alpha(Theme.nightFg, 0.1)
                    border.width: 2
                    border.color: root.message ? Theme.red : Theme.accent

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.nightFg
                        enabled: !root.checking
                        focus: true
                        font { family: Theme.sans; pixelSize: 20; letterSpacing: 3 }
                        onTextChanged: root.password = text
                        // Keeps every screen's field in step, and empties it after a try.
                        Connections {
                            target: root
                            function onPasswordChanged() { if (field.text !== root.password) field.text = root.password; }
                        }
                        onAccepted: root.submit()
                        Component.onCompleted: forceActiveFocus()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !field.text
                            text: root.checking ? Tr.t("Checking…") : Tr.t("Password")
                            color: Theme.alpha(Theme.nightFg, 0.6)
                            font { family: Theme.sans; pixelSize: 16 }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.message || Tr.t("Press Enter to unlock")
                    color: root.message ? Theme.red : Theme.alpha(Theme.nightFg, 0.7)
                    font { family: Theme.sans; pixelSize: 14 }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 36
                spacing: 28

                Text {
                    visible: UPower.displayDevice.isLaptopBattery
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("%1% battery", Math.round(UPower.displayDevice.percentage * 100))
                    color: Theme.alpha(Theme.nightFg, 0.8)
                    font { family: Theme.sans; pixelSize: 14 }
                }
                Repeater {
                    model: [
                        ["sleep", Tr.t("Sleep"), ["systemctl", "suspend"]],
                        ["restart", Tr.t("Restart"), ["systemctl", "reboot"]],
                        ["power", Tr.t("Shut down"), ["systemctl", "poweroff"]]
                    ]
                    delegate: MouseArea {
                        id: act
                        required property var modelData
                        width: actRow.implicitWidth
                        height: 32
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(modelData[2])
                        Row {
                            id: actRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Glyph { name: act.modelData[0]; size: 16; color: Theme.alpha(Theme.nightFg, 0.8) }
                            Text {
                                text: act.modelData[1]
                                color: Theme.alpha(Theme.nightFg, 0.8)
                                font { family: Theme.sans; pixelSize: 14 }
                            }
                        }
                    }
                }
            }
        }
    }
}
