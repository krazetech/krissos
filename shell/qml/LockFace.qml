import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// What the lock screen and the login screen share, with a macOS feel: the time-of-day
// wallpaper blurred, a big light clock and the date high up, and the user's picture and
// name low down. Any key or click brings up the password field with a gentle rise; Esc
// puts it away. A wrong password shakes the field (a red rim with reduced motion).
// `host` holds the typed password (shared by every screen) and does the checking.
FocusScope {
    id: face
    // password, message, checking, hint, verb (the submit button's name), userName,
    // faces (picture paths to try), submit()
    required property var host
    readonly property bool ready: wall.ready
    anchors.fill: parent
    focus: true

    // The password field is out: after a key or a click, and while a try is checked.
    property bool asking: false
    onAskingChanged: {
        if (asking) {
            caps.running = true;
            field.forceActiveFocus();
        } else {
            host.password = "";
            catcher.forceActiveFocus();
        }
    }
    function ask(text) {
        asking = true;
        if (text) host.password += text;
    }

    DynamicWallpaper {
        id: wall
        anchors.fill: parent
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.12
    }

    // A click anywhere brings up the field; any key does too (the key is typed into it).
    MouseArea {
        anchors.fill: parent
        Accessible.ignored: true  // any key does the same; the field is named
        onClicked: face.ask("")
    }
    Item {
        id: catcher
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_Escape)
                return;
            face.ask(event.text.length === 1 && event.text >= " " ? event.text : "");
            event.accepted = true;
        }
    }
    Keys.onEscapePressed: asking = false

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: top
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.08)
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleString(Qt.locale(), "dddd, d MMMM")
            color: Theme.alpha(Theme.nightFg, 0.85)
            font { family: Theme.sans; pixelSize: Math.round(time.size * 0.16); weight: Font.DemiBold }
        }
        RollingText {
            id: time
            readonly property int size: Math.round(Math.min(face.height * 0.16, 176))
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.nightFg
            font { family: Theme.sans; pixelSize: time.size; weight: Font.Light }
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        Item { width: 1; height: 18 }

        // What's playing, with its controls, while a player is open.
        Rectangle {
            id: media
            readonly property var p: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values.find(p => p.trackTitle) ?? null
            visible: p !== null && p.trackTitle !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(380); height: Theme.dp(68)
            radius: Theme.rCard
            color: Theme.alpha(Theme.nightFg, 0.12)
            border.width: 1
            border.color: Theme.alpha(Theme.nightFg, 0.1)

            Rectangle {
                id: artBox
                anchors { left: parent.left; leftMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                width: 48; height: 48; radius: Theme.rControl
                color: Theme.alpha(Theme.nightFg, 0.1)
                clip: true
                Glyph { anchors.centerIn: parent; name: "music"; color: Theme.alpha(Theme.nightFg, 0.7); visible: art.status !== Image.Ready }
                Image {
                    id: art
                    anchors.fill: parent
                    source: media.p?.trackArtUrl ?? ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors { left: artBox.right; leftMargin: Theme.s3; right: controls.left; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                spacing: Theme.s0
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: media.p?.trackTitle ?? ""
                    color: Theme.nightFg
                    font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: media.p?.trackArtist || media.p?.identity || ""
                    color: Theme.alpha(Theme.nightFg, 0.7)
                    font { family: Theme.sans; pixelSize: Theme.sp(12) }
                }
            }
            Row {
                id: controls
                anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                spacing: Theme.s0
                LockButton {
                    glyph: "prev"
                    accessibleName: Tr.t("Previous track")
                    enabled: media.p?.canGoPrevious ?? false
                    onClicked: media.p.previous()
                }
                LockButton {
                    glyph: media.p?.isPlaying ? "pause" : "play"
                    accessibleName: media.p?.isPlaying ? Tr.t("Pause") : Tr.t("Play")
                    enabled: media.p?.canTogglePlaying ?? false
                    onClicked: media.p.togglePlaying()
                }
                LockButton {
                    glyph: "next"
                    accessibleName: Tr.t("Next track")
                    enabled: media.p?.canGoNext ?? false
                    onClicked: media.p.next()
                }
            }
        }
    }

    // Battery and network, small, top right.
    Row {
        anchors { top: parent.top; right: parent.right; margins: Theme.s6 }
        spacing: Theme.s4
        Battery {
            tint: Theme.alpha(Theme.nightFg, 0.85)
            Accessible.role: Accessible.StaticText
            Accessible.name: Tr.t("%1% battery", Math.round(dev.percentage * 100))
        }
        NetworkGlyph {
            id: net
            size: 18
            color: Theme.alpha(Theme.nightFg, dev ? 0.85 : 0.5)
            Accessible.role: Accessible.StaticText
            Accessible.name: !dev ? Tr.t("Not connected") : dev.type === DeviceType.Wifi ? Tr.t("Wi-Fi") : Tr.t("Wired")
        }
    }

    // The user, low down, and the password field under them.
    Column {
        id: who
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(96, Math.round(parent.height * 0.1))
        spacing: Theme.s3

        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 76
            name: face.host.userName
            faces: face.host.faces
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.host.userName
            color: Theme.nightFg
            font { family: Theme.sans; pixelSize: Theme.sp(18); weight: Font.DemiBold }
        }

        // The field and the line under it; the room is kept so nothing jumps.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(320)
            height: Theme.dp(40) + Theme.sp(13) + 24

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                opacity: face.asking ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.normal) } }
                text: face.host.hint
                // 4.5:1 on the brightest time of day of the dynamic wallpaper.
                color: Theme.alpha(Theme.nightFg, 0.8)
                font { family: Theme.sans; pixelSize: Theme.sp(14) }
            }

            Item {
                id: entry
                width: parent.width
                height: parent.height
                opacity: face.asking ? 1 : 0
                visible: opacity > 0
                y: face.asking ? 0 : 14
                Behavior on opacity { NumberAnimation { duration: Theme.ms(300); easing.type: Theme.ease } }
                Behavior on y { NumberAnimation { duration: Theme.ms(300); easing.type: Theme.ease } }

                Rectangle {
                    id: box
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.dp(260); height: Theme.dp(40); radius: height / 2
                    color: Theme.alpha(Theme.nightFg, 0.14)
                    border.width: face.host.message && Theme.reduceMotion ? 2 : 1
                    border.color: face.host.message && Theme.reduceMotion ? Theme.red
                        : Theme.alpha(Theme.nightFg, field.activeFocus ? 0.4 : 0.18)

                    // The shake: a few soft swings that settle, like macOS.
                    transform: Translate { id: nudge }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: nudge; property: "x"; to: -12; duration: Theme.ms(50); easing.type: Easing.OutQuad }
                        NumberAnimation { target: nudge; property: "x"; to: 10; duration: Theme.ms(80); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: nudge; property: "x"; to: -7; duration: Theme.ms(80); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: nudge; property: "x"; to: 4; duration: Theme.ms(80); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: nudge; property: "x"; to: 0; duration: Theme.ms(70); easing.type: Easing.OutQuad }
                    }
                    Connections {
                        target: face.host
                        function onMessageChanged() {
                            if (face.host.message && !Theme.reduceMotion) shake.restart();
                            if (face.host.message) face.asking = true;
                        }
                    }

                    TextInput {
                        id: field
                        anchors { left: parent.left; right: go.left; top: parent.top; bottom: parent.bottom; leftMargin: Theme.s4; rightMargin: Theme.s1 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.nightFg
                        clip: true
                        enabled: face.asking && !face.host.checking
                        activeFocusOnTab: enabled
                        font { family: Theme.sans; pixelSize: Theme.sp(16); letterSpacing: 2 }
                        Accessible.name: Tr.t("Password")
                        onTextChanged: face.host.password = text
                        // Keeps every screen's field in step, and empties it after a try.
                        Connections {
                            target: face.host
                            function onPasswordChanged() { if (field.text !== face.host.password) field.text = face.host.password; }
                        }
                        onAccepted: face.host.submit()
                        // Disabled while checking, which drops the focus; take it back for the next try.
                        onEnabledChanged: if (enabled) forceActiveFocus()
                        Keys.onReleased: event => { if (event.key === Qt.Key_CapsLock) caps.running = true; }
                        // A letter typed against Shift also tells caps lock is on.
                        Keys.onPressed: event => {
                            const t = event.text;
                            if (t.length === 1 && t.toUpperCase() !== t.toLowerCase())
                                caps.on = (t === t.toUpperCase()) !== !!(event.modifiers & Qt.ShiftModifier);
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !field.text
                            text: face.host.checking ? Tr.t("Checking…") : Tr.t("Enter password")
                            color: Theme.alpha(Theme.nightFg, 0.6)
                            font { family: Theme.sans; pixelSize: Theme.sp(14) }
                        }
                    }
                    LockButton {
                        id: go
                        anchors { right: parent.right; rightMargin: Theme.s1; verticalCenter: parent.verticalCenter }
                        implicitWidth: 32; implicitHeight: 32
                        glyph: "chevron"
                        primary: true
                        accessibleName: face.host.verb
                        enabled: face.asking && field.text !== "" && !face.host.checking
                        onClicked: face.host.submit()
                    }
                }

                // The keyboard layout, beside the field.
                Rectangle {
                    anchors { left: box.right; leftMargin: Theme.s2; verticalCenter: box.verticalCenter }
                    width: layoutText.implicitWidth + 14; height: 24; radius: Theme.rSmall
                    color: Theme.alpha(Theme.nightFg, 0.1)
                    Accessible.role: Accessible.StaticText
                    Accessible.name: Tr.t("Keyboard layout: %1", xkb.layout)
                    Text {
                        id: layoutText
                        anchors.centerIn: parent
                        text: xkb.layout
                        color: Theme.alpha(Theme.nightFg, 0.75)
                        font { family: Theme.mono; pixelSize: Theme.sp(11); weight: Font.DemiBold }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: box.bottom
                    anchors.topMargin: Theme.s2
                    text: face.host.message || (caps.on ? Tr.t("Caps Lock is on") : "")
                    color: face.host.message ? Theme.red : Theme.alpha(Theme.nightFg, 0.75)
                    font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.Medium }
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: text
                }
            }
        }
    }

    // Caps lock, from the keyboard's light; also corrected from what is typed.
    Process {
        id: caps
        property bool on: false
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) caps.on = /[1-9]/.test(text) }
    }

    // The keyboard layout cosmic-comp starts with (its first), short and in capitals.
    // ponytail: the first layout only; a second one switched to in the session is not shown.
    FileView {
        id: xkbFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cosmic/com.system76.CosmicComp/v1/xkb_config"
        printErrors: false
    }
    QtObject {
        id: xkb
        readonly property string layout: ((/layout:\s*"([^"]*)"/.exec(xkbFile.text() ?? "") ?? [])[1] || "us").split(",")[0].toUpperCase()
    }

    // Sleep, restart, shut down.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        spacing: Theme.s2
        Repeater {
            model: [
                ["sleep", Tr.t("Sleep"), ["systemctl", "suspend"]],
                ["restart", Tr.t("Restart"), ["systemctl", "reboot"]],
                ["power", Tr.t("Shut down"), ["systemctl", "poweroff"]]
            ]
            delegate: LockButton {
                required property var modelData
                glyph: modelData[0]
                label: modelData[1]
                onClicked: Quickshell.execDetached(modelData[2])
            }
        }
    }
}
