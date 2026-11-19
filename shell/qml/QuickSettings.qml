import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Quick settings, like the Windows Action Center: Wi-Fi, Bluetooth, Do not disturb, light
// or dark and the power mode as tiles, then volume, microphone and brightness sliders. The arrow on a
// tile, or next to the volume, opens its list (networks, devices, speakers) in place.
// It opens as a sheet, the way Vaul does: it slides up over a dimmed backdrop, and can be
// dragged by its handle (or anywhere that isn't a control) down to a peek that shows only
// the tiles, or further down to close; a quick flick down closes it too.
// ponytail: no night light; cosmic-comp 1.11 has no gamma-control protocol to drive one.
PanelWindow {
    id: win

    // Stays up while the sheet slides away, but lets clicks through to what is behind it.
    visible: Desktop.quickOpen || panel.y < sheet.closed - 0.5
    mask: Desktop.quickOpen ? null : noInput
    Region { id: noInput }
    screen: Desktop.screen

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-quick-settings"
    // The keyboard while open: Tab walks the controls, Esc closes.
    WlrLayershell.keyboardFocus: Desktop.quickOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Blur only behind the part of the sheet that is showing.
    BackgroundEffect.blurRegion: Region {
        item: sheet
        Region { item: panel; radius: panel.radius; intersection: Intersection.Intersect }
    }

    // "" or the open list: "wifi", "bluetooth" or "output".
    property string page: ""
    property var askPsk: null
    // The password just tried for askPsk didn't work.
    property bool pskFailed: false

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function close() { Desktop.quickOpen = false; }

    // Seconds as "2 h 5 min" or "40 min".
    function span(sec) {
        const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60);
        return h > 0 ? Tr.t("%1 h %2 min", h, m) : Tr.t("%1 min", Math.max(1, m));
    }

    // Snap points: the whole sheet, or a peek with only the tiles showing.
    property bool peek: false
    readonly property real peekOffset: panel.height - (tiles.y + tiles.height + body.anchors.topMargin + 20)
    readonly property real target: !Desktop.quickOpen ? sheet.closed : peek ? peekOffset : 0

    Connections {
        target: Desktop
        function onQuickOpenChanged() {
            if (!Desktop.quickOpen) return;
            win.page = "";
            win.askPsk = null;
            win.pskFailed = false;
            win.peek = false;
            backlight.running = true;
            // The keyboard on the first control (the media buttons or the first tile).
            Qt.callLater(() => panel.nextItemInFocusChain(true)?.forceActiveFocus());
        }
    }

    PwObjectTracker { objects: [win.sink, win.source] }

    // Scan for networks and devices only while their list is open.
    Binding { when: win.wifi !== null; target: win.wifi; property: "scannerEnabled"; value: win.visible && win.page === "wifi" }
    Binding { when: win.adapter !== null; target: win.adapter; property: "discovering"; value: win.visible && win.page === "bluetooth" }

    // Screen brightness through brightnessctl (it goes through logind, so no root needed).
    property int brightness: -1
    Process {
        id: backlight
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        // e.g. "intel_backlight,backlight,400,40%,1000"
        stdout: SplitParser { onRead: line => win.brightness = parseInt(line.split(",")[3]) }
    }

    // The backdrop: dims as the sheet comes up, and follows a drag.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.night, 0.3)
        opacity: Math.max(0, 1 - panel.y / sheet.closed)
        MouseArea {
            Accessible.ignored: true  // pointer only; the keyboard has its own way
            anchors.fill: parent
            onClicked: win.close()
        }
    }

    // The sheet slides inside this, so it disappears below its resting place, not over the bar.
    Item {
        id: sheet
        readonly property real closed: panel.height + 24
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.panelGap
        anchors.bottomMargin: Theme.panelGap + Desktop.barRoom
        width: panel.width
        height: panel.height
        clip: true

        Rectangle {
            id: panel
            // Vaul's curve: a long, soft ease out.
            y: dragger.dragging ? dragger.pos : win.target
            Behavior on y {
                enabled: !dragger.dragging
                NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sheetCurve }
            }
            // Wider with larger text, so the tile labels still fit.
            width: Math.round(400 * Math.max(1, (1 + Theme.textScale) / 2))
            height: body.implicitHeight + 50
            radius: Theme.radius + 4
            color: Theme.bar
            border.width: Theme.rimWidth
            border.color: Theme.rim
            focus: true
            Keys.onEscapePressed: Desktop.back("quickOpen")
            Accessible.role: Accessible.Dialog
            Accessible.name: Tr.t("Quick settings")

            // Drags the sheet; also keeps clicks on the sheet from closing it.
            MouseArea {
                Accessible.ignored: true  // pointer only; the keyboard has its own way
                id: dragger
                anchors.fill: parent
                property bool dragging: false
                property real pos: 0
                property real startY: 0
                property real startOffset: 0
                property real lastY: 0
                property real lastT: 0
                property real speed: 0  // px per ms, down is positive
                function pointer(mouse) { return mapToItem(null, mouse.x, mouse.y).y; }
                onPressed: mouse => {
                    startY = lastY = pointer(mouse);
                    startOffset = panel.y;
                    lastT = Date.now();
                    speed = 0;
                }
                onPositionChanged: mouse => {
                    const p = pointer(mouse), t = Date.now();
                    if (!dragging && Math.abs(p - startY) < 6) return;
                    dragging = true;
                    const off = startOffset + p - startY;
                    // Past the top it resists, like pulling on a rubber band.
                    pos = off < 0 ? -Math.sqrt(-off) * 2 : off;
                    if (t > lastT) speed = 0.7 * speed + 0.3 * (p - lastY) / (t - lastT);
                    lastY = p; lastT = t;
                }
                onReleased: {
                    if (!dragging) return;
                    // A flick down closes; otherwise it settles on the nearest snap point.
                    const points = [0, win.peekOffset, sheet.closed];
                    const near = speed > 0.8 ? sheet.closed
                        : points.reduce((a, b) => Math.abs(b - pos) < Math.abs(a - pos) ? b : a);
                    win.peek = near === win.peekOffset;
                    if (near === sheet.closed) win.close();
                    dragging = false;
                }
            }

            // The handle.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 9
                width: 40; height: 5; radius: 2.5
                color: Theme.alpha(Theme.fg, 0.25)
            }

            ColumnLayout {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 30 }
                spacing: 14

                // What's playing, with the controls the media keys also reach.
                ClippingRectangle {
                    id: media
                    readonly property var p: Desktop.player
                    visible: p !== null && p.trackTitle !== ""
                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: Theme.radiusSmall
                    color: Theme.card
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12
                        ClippingRectangle {
                            implicitWidth: 52
                            implicitHeight: 52
                            radius: 10
                            color: Theme.win
                            Glyph { anchors.centerIn: parent; name: "music"; color: Theme.soft; visible: art.status !== Image.Ready }
                            Image {
                                id: art
                                anchors.fill: parent
                                source: media.p?.trackArtUrl ?? ""
                                sourceSize: Qt.size(104, 104)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: media.p?.trackTitle ?? ""
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: media.p?.trackArtist || media.p?.identity || ""
                                color: Theme.soft
                                font { family: Theme.sans; pixelSize: Theme.sp(12) }
                            }
                        }
                        Repeater {
                            model: ["prev", "play", "next"]
                            delegate: MouseArea {
                                id: mb
                                required property string modelData
                                readonly property bool primary: modelData === "play"
                                implicitWidth: 36
                                implicitHeight: 36
                                hoverEnabled: true
                                function press() { modelData === "prev" ? media.p.previous() : modelData === "next" ? media.p.next() : media.p.togglePlaying(); }
                                activeFocusOnTab: true
                                Keys.onReturnPressed: press()
                                Keys.onEnterPressed: press()
                                Keys.onSpacePressed: press()
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData === "prev" ? Tr.t("Previous") : modelData === "next" ? Tr.t("Next")
                                    : media.p?.isPlaying ? Tr.t("Pause") : Tr.t("Play")
                                Accessible.onPressAction: press()
                                FocusRim { radius: width / 2 + 2 }
                                enabled: modelData === "prev" ? media.p?.canGoPrevious ?? false
                                    : modelData === "next" ? media.p?.canGoNext ?? false : media.p?.canTogglePlaying ?? false
                                cursorShape: Qt.PointingHandCursor
                                opacity: enabled ? 1 : 0.35
                                onClicked: press()
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: mb.primary ? Theme.accent : mb.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                                    scale: mb.pressed ? Theme.pressScale : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                }
                                Glyph {
                                    anchors.centerIn: parent
                                    name: mb.primary && media.p?.isPlaying ? "pause" : mb.modelData
                                    size: 16
                                    color: mb.primary ? Theme.accentInk : Theme.fg
                                }
                            }
                        }
                    }
                }

                GridLayout {
                    id: tiles
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    Tile {
                        visible: win.wifi !== null
                        glyph: Networking.wifiEnabled ? "wifi" : "wifiOff"
                        label: win.wifi?.connected ? (win.wifi.networks.values.find(n => n.connected)?.name ?? Tr.t("Wi-Fi")) : Tr.t("Wi-Fi")
                        name: Tr.t("Wi-Fi")
                        on: Networking.wifiEnabled
                        list: "wifi"
                        listTitle: Tr.t("Wi-Fi networks")
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                    Tile {
                        visible: win.adapter !== null
                        glyph: "bluetooth"
                        label: Tr.t("Bluetooth")
                        on: win.adapter?.enabled ?? false
                        list: "bluetooth"
                        listTitle: Tr.t("Bluetooth devices")
                        onToggled: win.adapter.enabled = !win.adapter.enabled
                    }
                    Tile {
                        glyph: "bellOff"
                        label: Tr.t("Do not disturb")
                        on: Desktop.dnd
                        onToggled: Desktop.dnd = !Desktop.dnd
                    }
                    Tile {
                        glyph: Theme.dark ? "sleep" : "sun"
                        label: Theme.dark ? Tr.t("Dark mode") : Tr.t("Light mode")
                        name: Tr.t("Dark mode")
                        on: Theme.dark
                        onToggled: Theme.setDark(!Theme.dark)
                    }
                    Tile {
                        // Only with power-profiles-daemon (or tuned-ppd), as in the bar.
                        visible: ppd.loaded
                        readonly property var order: PowerProfiles.hasPerformanceProfile
                            ? [PowerProfile.Balanced, PowerProfile.Performance, PowerProfile.PowerSaver]
                            : [PowerProfile.Balanced, PowerProfile.PowerSaver]
                        readonly property int p: PowerProfiles.profile
                        glyph: p === PowerProfile.Performance ? "performance" : p === PowerProfile.PowerSaver ? "saver" : "balanced"
                        label: p === PowerProfile.Performance ? Tr.t("Performance") : p === PowerProfile.PowerSaver ? Tr.t("Power saver") : Tr.t("Balanced")
                        name: Tr.t("Power mode: %1", label)
                        cycles: true
                        on: p !== PowerProfile.Balanced
                        onToggled: PowerProfiles.profile = order[(order.indexOf(p) + 1) % order.length]
                        FileView {
                            id: ppd
                            path: "/usr/share/dbus-1/system-services/net.hadess.PowerProfiles.service"
                            printErrors: false
                        }
                    }
                }

                // Wi-Fi networks.
                ListBox {
                    visible: win.page === "wifi"
                    title: Tr.t("Wi-Fi networks")
                    empty: Networking.wifiEnabled ? Tr.t("Looking for networks…") : Tr.t("Wi-Fi is off.")
                    model: (win.wifi?.networks.values ?? []).slice()
                        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
                    delegate: Column {
                        id: net
                        required property var modelData
                        width: parent?.width ?? 0
                        readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
                        // A wrong or changed password: ask for it (again), and say why.
                        Connections {
                            target: net.modelData
                            function onConnectionFailed(reason) {
                                if (!net.secured) return;
                                win.askPsk = net.modelData;
                                win.pskFailed = true;
                            }
                        }
                        Row_ {
                            glyph: "wifi"
                            text: net.modelData.name
                            detail: net.modelData.connected ? Tr.t("Connected")
                                : net.modelData.stateChanging ? Tr.t("Connecting…")
                                : net.secured ? Tr.t("Secured") : Tr.t("No password")
                            current: net.modelData.connected
                            onClicked: {
                                if (net.modelData.connected) net.modelData.disconnect();
                                else if (net.modelData.known || !net.secured) net.modelData.connect();
                                else { win.askPsk = net.modelData; win.pskFailed = false; }
                            }
                        }
                        // Password for a new secured network.
                        Rectangle {
                            visible: win.askPsk === net.modelData
                            width: parent.width
                            height: 42
                            radius: 21
                            color: Theme.card
                            border.width: 2
                            border.color: Theme.accent
                            TextInput {
                                id: psk
                                Accessible.role: Accessible.EditableText
                                Accessible.passwordEdit: true
                                Accessible.name: Tr.t("Password for %1", net.modelData.name)
                                Accessible.description: win.pskFailed ? Tr.t("Wrong password. Try again, then Enter") : ""
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: Theme.sp(14) }
                                onVisibleChanged: { text = ""; if (visible) forceActiveFocus(); }
                                Keys.onReturnPressed: { if (text) { net.modelData.connectWithPsk(text); win.askPsk = null; } }
                                Keys.onEscapePressed: win.askPsk = null
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !psk.text
                                    text: win.pskFailed ? Tr.t("Wrong password. Try again, then Enter") : Tr.t("Network password, then Enter")
                                    color: win.pskFailed ? Theme.red : Theme.soft
                                    font: psk.font
                                }
                            }
                        }
                    }
                }

                // Bluetooth devices: paired ones first.
                ListBox {
                    visible: win.page === "bluetooth"
                    title: Tr.t("Bluetooth devices")
                    empty: win.adapter?.enabled ? Tr.t("Looking for devices…") : Tr.t("Bluetooth is off.")
                    model: (win.adapter?.devices.values ?? []).filter(d => d.name).slice()
                        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
                    delegate: Row_ {
                        required property var modelData
                        glyph: "bluetooth"
                        text: modelData.name
                        detail: modelData.connected ? Tr.t("Connected") : modelData.pairing ? Tr.t("Pairing…")
                            : modelData.paired ? Tr.t("Paired") : Tr.t("Click to pair")
                        current: modelData.connected
                        // ponytail: a new device is paired on the first click and connected on the
                        // second; Windows does both at once.
                        onClicked: modelData.connected ? modelData.disconnect() : modelData.paired ? modelData.connect() : modelData.pair()
                    }
                }

                // Speakers and headphones.
                ListBox {
                    visible: win.page === "output"
                    title: Tr.t("Sound output")
                    empty: Tr.t("No sound devices.")
                    model: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
                    delegate: Row_ {
                        required property var modelData
                        glyph: "volume"
                        text: modelData.description || modelData.nickname || modelData.name
                        current: modelData === win.sink
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }

                Slider {
                    visible: win.sink?.audio !== undefined
                    name: Tr.t("Volume")
                    muted: win.sink?.audio?.muted ?? false
                    listTitle: Tr.t("Sound output")
                    glyph: win.sink?.audio?.muted ? "mute" : "volume"
                    value: win.sink?.audio?.volume ?? 0
                    list: "output"
                    onGlyphClicked: win.sink.audio.muted = !win.sink.audio.muted
                    onMoved: v => { win.sink.audio.muted = false; win.sink.audio.volume = v; }
                }
                Slider {
                    visible: win.source?.audio !== undefined
                    name: Tr.t("Microphone")
                    muted: win.source?.audio?.muted ?? false
                    glyph: win.source?.audio?.muted ? "micOff" : "mic"
                    value: win.source?.audio?.volume ?? 0
                    onGlyphClicked: win.source.audio.muted = !win.source.audio.muted
                    onMoved: v => { win.source.audio.muted = false; win.source.audio.volume = v; }
                }
                Slider {
                    visible: win.brightness >= 0
                    name: Tr.t("Brightness")
                    canMute: false
                    glyph: "sun"
                    value: win.brightness / 100
                    onMoved: v => {
                        // Not below 1%: a black screen is hard to turn back up.
                        win.brightness = Math.max(1, Math.round(v * 100));
                        Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", win.brightness + "%"]);
                    }
                }

                Text {
                    visible: UPower.displayDevice.isLaptopBattery
                    Layout.fillWidth: true
                    text: {
                        const d = UPower.displayDevice, pct = Math.round(d.percentage * 100);
                        if (d.state === UPowerDeviceState.FullyCharged) return Tr.t("%1% battery, fully charged", pct);
                        if (d.state === UPowerDeviceState.Charging)
                            return d.timeToFull > 0 ? Tr.t("%1% battery, full in %2", pct, win.span(d.timeToFull)) : Tr.t("%1% battery, charging", pct);
                        if (!UPower.onBattery) return Tr.t("%1% battery, plugged in", pct);
                        return d.timeToEmpty > 0 ? Tr.t("%1% battery, %2 left", pct, win.span(d.timeToEmpty)) : Tr.t("%1% battery", pct);
                    }
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.Medium }
                }
            }
        }
    }

    // A toggle tile; the arrow on the right opens its list.
    component Tile: Rectangle {
        id: tile
        property string glyph
        property string label
        property bool on
        property string list: ""
        property string listTitle
        property string name: label    // what a screen reader calls it, when the label is a state
        property bool cycles: false     // steps through modes rather than turning on and off
        signal toggled()
        // Read out when it changes from the keyboard (a pointer user sees it).
        onOnChanged: if (main.activeFocus) main.Accessible.announce(cycles ? label : on ? Tr.t("%1 on", name) : Tr.t("%1 off", name))
        onLabelChanged: if (cycles && main.activeFocus) main.Accessible.announce(label)

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: Math.max(64, tileText.implicitHeight + 23 + 16)
        radius: Theme.radiusSmall
        readonly property bool hovered: main.containsMouse || arrow.containsMouse
        color: on ? (hovered ? Theme.accentHover : Theme.accent) : hovered ? Theme.cardHover : Theme.card
        readonly property color ink: on ? Theme.accentInk : Theme.fg
        // High contrast outlines an off tile, which is otherwise near black on black.
        border.width: Theme.high && !on ? Theme.rimWidth : 0
        border.color: Theme.line
        scale: main.pressed || arrow.pressed ? Theme.pressScale : 1
        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

        MouseArea {
            id: main
            hoverEnabled: true
            anchors.fill: parent
            anchors.rightMargin: tile.list ? 30 : 0
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
            activeFocusOnTab: true
            Keys.onReturnPressed: tile.toggled()
            Keys.onEnterPressed: tile.toggled()
            Keys.onSpacePressed: tile.toggled()
            Accessible.role: Accessible.Button
            Accessible.name: tile.name
            Accessible.description: tile.label !== tile.name && !tile.cycles ? tile.label : ""
            Accessible.checkable: !tile.cycles
            Accessible.checked: !tile.cycles && tile.on
            Accessible.onPressAction: tile.toggled()
            Accessible.onToggleAction: tile.toggled()
            FocusRim { anchors.rightMargin: tile.list ? -32 : -2; radius: Theme.radiusSmall + 2 }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16
                spacing: 5
                Glyph { name: tile.glyph; size: 18; color: tile.ink }
                Text {
                    id: tileText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: tile.label
                    color: tile.ink
                    font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                }
            }
        }
        MouseArea {
            id: arrow
            hoverEnabled: true
            visible: tile.list !== ""
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 30
            cursorShape: Qt.PointingHandCursor
            onClicked: win.page = win.page === tile.list ? "" : tile.list
            activeFocusOnTab: visible
            Keys.onReturnPressed: clicked(null)
            Keys.onEnterPressed: clicked(null)
            Keys.onSpacePressed: clicked(null)
            Accessible.role: Accessible.Button
            Accessible.name: tile.listTitle
            Accessible.expandable: true
            Accessible.expanded: win.page === tile.list
            Accessible.onPressAction: clicked(null)
            FocusRim { anchors.margins: 1; radius: 8 }
            Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 32; color: Theme.alpha(tile.ink, 0.2) }
            Glyph { anchors.centerIn: parent; name: win.page === tile.list ? "up" : "down"; size: 16; stroke: 1.75; color: tile.ink }
        }
    }

    // A glyph you can click, a slider, and optionally an arrow that opens a list.
    component Slider: RowLayout {
        id: sl
        property string glyph
        property real value
        property string list: ""
        property string listTitle
        property string name
        property bool muted: false
        property bool canMute: true
        signal moved(real v)
        signal glyphClicked()
        function nudge(d) { moved(Math.max(0, Math.min(1, Math.round((value + d) * 100) / 100))); }
        onValueChanged: if (track.activeFocus) track.Accessible.announce(Math.round(value * 100) + "%")

        Layout.fillWidth: true
        spacing: 10
        MouseArea {
            implicitWidth: 32; implicitHeight: 32
            cursorShape: Qt.PointingHandCursor
            onClicked: sl.glyphClicked()
            activeFocusOnTab: sl.canMute
            Keys.onReturnPressed: sl.glyphClicked()
            Keys.onEnterPressed: sl.glyphClicked()
            Keys.onSpacePressed: sl.glyphClicked()
            Accessible.role: sl.canMute ? Accessible.Button : Accessible.Graphic
            Accessible.name: sl.canMute ? Tr.t("Mute %1", sl.name) : sl.name
            Accessible.checkable: sl.canMute
            Accessible.checked: sl.muted
            Accessible.onPressAction: if (sl.canMute) sl.glyphClicked()
            FocusRim { radius: 18 }
            Glyph { anchors.centerIn: parent; name: sl.glyph; size: 19 }
        }
        MouseArea {
            id: track
            Layout.fillWidth: true
            implicitHeight: 28
            cursorShape: Qt.PointingHandCursor
            function set(x) { sl.moved(Math.max(0, Math.min(1, x / width))); }
            // A slider to a screen reader, in percent; arrows move it 5%, Page Up and Down 10%.
            readonly property real value: Math.round(sl.value * 100)
            readonly property real minimumValue: 0
            readonly property real maximumValue: 100
            readonly property real stepSize: 5
            activeFocusOnTab: true
            Accessible.role: Accessible.Slider
            Accessible.name: sl.name
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
            FocusRim { anchors.margins: -1; radius: 14 }
            onPressed: mouse => set(mouse.x)
            onPositionChanged: mouse => { if (pressed) set(mouse.x); }
            onWheel: wheel => sl.moved(Math.max(0, Math.min(1, sl.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3
                color: Theme.card
                border.width: Theme.high ? 1 : 0
                border.color: Theme.line
                Rectangle { width: parent.width * Math.min(1, sl.value); height: parent.height; radius: 3; color: Theme.accent }
            }
            Rectangle {
                x: track.width * Math.min(1, sl.value) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: 9
                color: Theme.fg
                border.width: 4
                border.color: Theme.accent
            }
        }
        // Right-aligned in a fixed width, so the slider doesn't shift as the digits change.
        Item {
            Layout.preferredWidth: Math.max(34, pct.implicitWidth)
        Layout.minimumWidth: Layout.preferredWidth
            implicitHeight: pct.height
            RollingText {
                id: pct
                anchors.right: parent.right
                text: Math.round(sl.value * 100)
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold; features: { "tnum": 1 } }
                Accessible.ignored: true
            }
        }
        MouseArea {
            visible: sl.list !== ""
            implicitWidth: 24; implicitHeight: 32
            cursorShape: Qt.PointingHandCursor
            onClicked: win.page = win.page === sl.list ? "" : sl.list
            activeFocusOnTab: visible
            Keys.onReturnPressed: clicked(null)
            Keys.onEnterPressed: clicked(null)
            Keys.onSpacePressed: clicked(null)
            Accessible.role: Accessible.Button
            Accessible.name: sl.listTitle
            Accessible.expandable: true
            Accessible.expanded: win.page === sl.list
            Accessible.onPressAction: clicked(null)
            FocusRim { radius: 8 }
            Glyph { anchors.centerIn: parent; name: win.page === sl.list ? "up" : "down"; size: 16; stroke: 1.75; color: Theme.soft }
        }
    }

    // An open list under the tiles.
    component ListBox: Rectangle {
        id: box
        property string title
        property string empty
        property alias model: rep.model
        property alias delegate: rep.delegate

        Layout.fillWidth: true
        implicitHeight: Math.min(col.implicitHeight, 300) + 20
        radius: Theme.radiusSmall
        color: Theme.win
        border.width: Theme.rimWidth
        border.color: Theme.line
        Accessible.role: Accessible.List
        Accessible.name: title

        Flickable {
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                width: parent.width
                spacing: 2
                Text {
                    text: box.title
                    color: Theme.fg
                    bottomPadding: 6
                    font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
                }
                Text {
                    visible: rep.count === 0
                    text: box.empty
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(13) }
                }
                Repeater { id: rep }
            }
        }
    }

    // One row in a list.
    component Row_: MouseArea {
        id: row
        property string glyph
        property string text
        property string detail
        property bool current

        width: parent?.width ?? 0
        height: Math.max(44, Theme.sp(13) + 26)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        Keys.onReturnPressed: clicked(null)
        Keys.onEnterPressed: clicked(null)
        Keys.onSpacePressed: clicked(null)
        Accessible.role: Accessible.ListItem
        Accessible.name: text
        Accessible.description: detail
        Accessible.checkable: true
        Accessible.checked: current
        Accessible.onPressAction: clicked(null)
        // Keep the row in view as the keyboard reaches it: scroll the list it is in.
        onActiveFocusChanged: {
            if (!activeFocus) return;
            for (let f = parent; f; f = f.parent) {
                if (f.contentY === undefined) continue;
                const y = mapToItem(f.contentItem, 0, 0).y;
                if (y < f.contentY) f.contentY = y;
                else if (y + height > f.contentY + f.height) f.contentY = y + height - f.height;
                break;
            }
        }
        onDetailChanged: if (activeFocus && detail) Accessible.announce(detail)
        FocusRim { anchors.margins: 0; radius: 10 }
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: row.pressed ? Theme.cardHover : row.containsMouse ? Theme.card : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Glyph { name: row.glyph; size: 17; color: row.current ? Theme.accent : Theme.fg }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: row.text
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(13); weight: row.current ? Font.DemiBold : Font.Medium }
            }
            Text {
                text: row.detail
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(11) }
            }
            Glyph { visible: row.current; name: "check"; size: 15; color: Theme.accent }
        }
    }
}
