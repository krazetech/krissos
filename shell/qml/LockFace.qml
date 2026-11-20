import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// What the lock screen and the login screen share, with a phone's feel: the picture (Personalise >
// Lock screen's, else the background's, else the time-of-day scene) sharp and a little dimmed,
// the big glass clock (LockClock.qml) and the date, and the user's picture and name low down.
// With the depth effect the picture's subject stands in front of the clock, unless it would
// hide the time: then the clock shrinks a step or moves to a free place, or goes in front. Any
// key or click frosts the picture and brings up the password field with a gentle rise; Esc
// puts it away. A wrong password shakes the field (a red rim with reduced motion).
// `host` holds the typed password (shared by every screen) and does the checking.
FocusScope {
    id: face
    // password, message, checking, hint, verb (the submit button's name), userName,
    // faces (picture paths to try), submit(); optionally lockClock, the clock's settings
    // (the login screen's copy of its user's), else Desktop.lockClock.
    required property var host
    readonly property var opts: host.lockClock ?? Desktop.lockClock
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

    // The wallpaper, sharp and hidden: the blur below and the depth effect's subject use it.
    Item {
        id: wall
        readonly property bool picture: !face.host.lockClock && Desktop.lockPicture !== ""
        readonly property bool ready: picture ? pic.status === Image.Ready || pic.status === Image.Error : dyn.ready
        anchors.fill: parent
        visible: false
        layer.enabled: true
        DynamicWallpaper { id: dyn; anchors.fill: parent; visible: !wall.picture }
        Image {
            id: pic
            anchors.fill: parent
            visible: wall.picture
            source: wall.picture ? Desktop.fileUrl(Desktop.lockPicture) : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    // Frosted: what the glass clock bends, and the whole screen while the password field is up.
    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.12
        autoPaddingEnabled: false  // else the picture shrinks into a black frame
    }
    // The picture as it is, a little dimmed, as on a phone, over the frost until a key or click.
    // ponytail: plain layers, not a MultiEffect: one draws the picture a little inset, and the
    // depth effect's subject must sit exactly on it.
    Item {
        anchors.fill: parent
        opacity: face.asking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.ms(300); easing.type: Theme.ease } }
        ShaderEffectSource { id: sharpPicture; anchors.fill: parent; sourceItem: wall }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: face.dim }
    }
    // Dimmed more on a light picture, so the white time, date and name always read.
    readonly property real dim: Math.min(0.45, 0.1 + Math.max(0, light - 0.35) * 0.8)
    // How light the picture is, 0 to 1: its average, from a tiny copy, when it is ready and
    // every few minutes (the time-of-day scene lightens at dawn).
    property real light: 0
    // ponytail: through a tiny file, as Canvas cannot read a grab's own URL. One file for every
    // screen: they show the same picture.
    readonly property string lightFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kriss-lock-light.png"
    function measure() {
        sharpPicture.grabToImage(r => {
            if (!r.saveToFile(face.lightFile)) return;
            if (lightProbe.src) lightProbe.unloadImage(lightProbe.src);
            lightProbe.src = "file://" + face.lightFile;
            lightProbe.loadImage(lightProbe.src);
        }, Qt.size(16, 9));
    }
    Connections { target: wall; function onReadyChanged() { if (wall.ready) face.measure(); } }
    Component.onCompleted: if (wall.ready) measure()
    Timer { interval: 300000; repeat: true; running: face.visible; onTriggered: face.measure() }
    Canvas {
        id: lightProbe
        width: 16
        height: 9
        opacity: 0  // painted, never seen
        property string src: ""
        onImageLoaded: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!src || !isImageLoaded(src)) return;
            ctx.drawImage(src, 0, 0, width, height);
            const d = ctx.getImageData(0, 0, width, height).data;
            let sum = 0;
            for (let i = 0; i < d.length; i += 4) sum += 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
            face.light = sum / (d.length / 4) / 255;
        }
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

    // Where the clock goes: the place and size chosen, or the nearest ones the depth effect's
    // subject leaves free (see placeFor below).
    readonly property var place: placeFor(opts.position, opts.size)
    Column {
        id: top
        x: face.place.position === "left" ? Math.round(face.width * 0.07) : Math.round((face.width - width) / 2)
        y: face.yFor(face.place.position, height)
        spacing: 0

        LockClock {
            id: lockClock
            anchors.horizontalCenter: face.place.position === "left" ? undefined : parent.horizontalCenter
            opts: Object.assign({}, face.opts, { size: face.place.size })
            backdrop: blurred
            screenHeight: face.height
            screenWidth: face.width
            now: clock.date
        }

        Item { width: 1; height: 18 }

        // What's playing, with its controls, while a player is open.
        Rectangle {
            id: media
            readonly property var p: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values.find(p => p.trackTitle) ?? null
            visible: face.opts.widgets !== false && p !== null && p.trackTitle !== ""
            anchors.horizontalCenter: face.place.position === "left" ? undefined : parent.horizontalCenter
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

    // The depth effect: the wallpaper's subject, sharp, in front of the clock. The mask comes
    // from kriss-wallpaper-mask (Desktop.wallpaperMask); with none yet, there is no depth.
    readonly property bool depthWanted: opts.depth !== false && Desktop.wallpaperMask !== ""
    Image {
        id: maskImage
        anchors.fill: parent
        visible: false
        source: face.depthWanted ? "file://" + Desktop.wallpaperMask : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    // The picture again, at its exact size, cut to the subject.
    Item {
        anchors.fill: parent
        visible: face.place.depth && opacity > 0
        opacity: face.asking ? 0 : 1  // the subject goes back into the frost with the picture
        Behavior on opacity { NumberAnimation { duration: Theme.ms(300); easing.type: Theme.ease } }
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskImage
            maskThresholdMin: 0.5  // the mask's edge is soft already; nothing shows where it is 0
            maskSpreadAtMin: 0.2
        }
        ShaderEffectSource { anchors.fill: parent; sourceItem: wall }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: face.dim }
    }
    // The mask, small, to tell how much of the clock the subject would hide.
    Canvas {
        id: probe
        width: 160
        height: Math.max(1, Math.round(160 * face.height / Math.max(1, face.width)))
        opacity: 0  // painted, never seen
        property var cells: null
        readonly property string src: maskImage.status === Image.Ready ? String(maskImage.source) : ""
        onSrcChanged: { cells = null; if (src) loadImage(src); }
        onImageLoaded: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!src || !isImageLoaded(src)) return;
            // Cropped to fill, as the wallpaper is.
            const iw = maskImage.implicitWidth, ih = maskImage.implicitHeight;
            const k = Math.max(width / iw, height / ih);
            ctx.drawImage(src, (width - iw * k) / 2, (height - ih * k) / 2, iw * k, ih * k);
            const d = ctx.getImageData(0, 0, width, height).data, out = new Uint8Array(width * height);
            for (let i = 0; i < out.length; i++) out[i] = d[i * 4 + 3];
            cells = out;
        }
    }
    // How much of rect r (in this face's pixels) the subject covers, 0 to 1.
    function covered(r) {
        const c = probe.cells;
        if (!c) return 0;
        const k = probe.width / width;
        const x0 = Math.max(0, Math.floor(r.x * k)), x1 = Math.min(probe.width, Math.ceil((r.x + r.width) * k));
        const y0 = Math.max(0, Math.floor(r.y * k)), y1 = Math.min(probe.height, Math.ceil((r.y + r.height) * k));
        let n = 0, on = 0;
        for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) { n++; if (c[y * probe.width + x] > 128) on++; }
        return n ? on / n : 0;
    }
    // The clock's top for a place, given its height: high up, in the middle, at the left or
    // low (just above the user).
    function yFor(position, h) {
        if (position === "centre" || position === "left") return Math.round(height * 0.4 - h / 2);
        if (position === "bottom") return Math.round(who.y - h - Theme.s6 * 2);
        return Math.round(height * 0.08);
    }
    // The clock's box for a place and size, scaled from the chosen size's.
    readonly property var shares: ({ s: 0.18, m: 0.22, l: 0.26, xl: 0.32 })
    function rectFor(position, size) {
        const k = shares[size] / (shares[opts.size] ?? 0.26);
        const w = sizer.implicitWidth * k, h = sizer.implicitHeight * k;
        return Qt.rect(position === "left" ? width * 0.07 : (width - w) / 2, yFor(position, h), w, h);
    }
    // Free: the subject hides at most a fifth of the clock and under half of any digit, so
    // the time always reads at a glance.
    function free(r) {
        if (covered(r) > 0.2) return false;
        const stacked = opts.stack !== "line", boxes = [];
        for (let i = 0; i < 4; i++)
            boxes.push(stacked ? Qt.rect(r.x + (i % 2) * r.width / 2, r.y + r.height * 0.15 + Math.floor(i / 2) * r.height * 0.425, r.width / 2, r.height * 0.425)
                               : Qt.rect(r.x + i * r.width / 4, r.y, r.width / 4, r.height));
        return !boxes.some(b => covered(b) > 0.4);
    }
    function placeFor(position, size) {
        const chosen = { position: position, size: size, depth: false, note: "" };
        if (!depthWanted || !probe.cells || !sizer.implicitWidth) return chosen;
        const order = ({ top: ["top", "centre", "left", "bottom"], centre: ["centre", "top", "left", "bottom"],
                         left: ["left", "centre", "top", "bottom"], bottom: ["bottom", "centre", "left", "top"] })[position] ?? ["top", "centre", "left", "bottom"];
        const sizes = ["xl", "l", "m", "s"].slice(["xl", "l", "m", "s"].indexOf(size));
        // The size chosen or one smaller in each place first, so the clock stays big; then smaller.
        const tries = [];
        for (const p of order) for (const s of sizes.slice(0, 2)) tries.push([p, s]);
        for (const s of sizes.slice(2)) for (const p of order) tries.push([p, s]);
        for (const [p, s] of tries)
            if (free(rectFor(p, s))) return { position: p, size: s, depth: true, note: p === position && s === size ? "" : Tr.t("The clock moved so the picture's subject does not cover the time.") };
        return Object.assign(chosen, { note: Tr.t("The subject would cover the time, so the clock stays in front.") });
    }
    readonly property string depthNote: place.note
    // The chosen clock, measured, never drawn.
    LockClock {
        id: sizer
        visible: false
        opts: face.opts
        screenHeight: face.height
        screenWidth: face.width
    }

    // Battery and network, small, top right.
    Row {
        visible: face.opts.widgets !== false
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

    // The user, low down, and the password field under them: on the main display only, as on
    // Windows; the others show the picture and the clock.
    property bool main: true
    Column {
        id: who
        visible: face.main
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
