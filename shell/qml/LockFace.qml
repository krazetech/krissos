import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// What the lock screen and the login screen share: blurred wallpaper, the time, the
// user's picture, a name and a password field, plus sleep, restart and shut down. `host` holds
// the typed password (shared by every screen) and does the checking.
FocusScope {
    id: face
    // password, message, checking, hint, userName, faces (picture paths to try), submit()
    required property var host
    anchors.fill: parent
    focus: true  // a FocusScope, so the password field inside gets the keys

    Image {
        id: wall
        anchors.fill: parent
        // Always the dark one: the lock screen is dark in both themes.
        source: "file:///usr/share/backgrounds/kriss/kriss-dark.svg"
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

        // The user's picture, or their initial on an accent disc, as in the launcher.
        Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: 48
            color: Theme.accent
            border.width: 5
            border.color: Theme.alpha(Theme.nightFg, 0.15)
            // The first of host.faces that exists, found up front so a missing ~/.face is not
            // logged (and a failed load does not feed back into the path).
            property string path: ""
            Process {
                id: finder
                command: ["sh", "-c", 'for f; do [ -r "$f" ] && { echo "$f"; exit; }; done', "sh"].concat(face.host.faces)
                stdout: StdioCollector { onStreamFinished: avatar.path = text.trim() }
            }
            Component.onCompleted: finder.running = true
            Connections {
                target: face.host
                function onFacesChanged() { avatar.path = ""; finder.running = true; }
            }

            Text {
                anchors.centerIn: parent
                visible: pic.status !== Image.Ready
                text: host.userName.charAt(0).toUpperCase()
                color: Theme.accentInk
                font { family: Theme.sans; pixelSize: 40; weight: Font.Bold }
            }
            Image {
                id: pic
                anchors.fill: parent
                anchors.margins: avatar.border.width
                source: avatar.path ? "file://" + avatar.path : ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            Rectangle { id: round; anchors.fill: pic; radius: width / 2; visible: false; layer.enabled: true }
            MultiEffect {
                anchors.fill: pic
                visible: pic.status === Image.Ready
                source: pic
                maskEnabled: true
                maskSource: round
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: host.userName
            color: Theme.nightFg
            font { family: Theme.sans; pixelSize: 20; weight: Font.DemiBold }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380; height: 54; radius: 27
            color: Theme.alpha(Theme.nightFg, 0.1)
            border.width: 2
            border.color: host.message ? Theme.red : Theme.accent

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.nightFg
                enabled: !host.checking
                focus: true
                font { family: Theme.sans; pixelSize: 20; letterSpacing: 3 }
                onTextChanged: host.password = text
                // Keeps every screen's field in step, and empties it after a try.
                Connections {
                    target: host
                    function onPasswordChanged() { if (field.text !== host.password) field.text = host.password; }
                }
                onAccepted: host.submit()
                Component.onCompleted: forceActiveFocus()
                // Disabled while checking, which drops the focus; take it back for the next try.
                onEnabledChanged: if (enabled) forceActiveFocus()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !field.text
                    text: host.checking ? Tr.t("Checking…") : Tr.t("Password")
                    color: Theme.alpha(Theme.nightFg, 0.6)
                    font { family: Theme.sans; pixelSize: 16 }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: host.message || host.hint
            color: host.message ? Theme.red : Theme.alpha(Theme.nightFg, 0.7)
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
