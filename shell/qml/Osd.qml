import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// The pop-up for the volume, mic and brightness keys: a small pill above the bar showing
// the new level for a moment. Volume and mute come from PipeWire, so it shows whatever
// changed them. The kernel doesn't announce backlight changes, so the brightness keys go
// through `kriss-shell brightness`, which calls brightness() here.
Scope {
    id: root

    property string glyph: "volume"
    property real level: 0
    property bool shown: false
    readonly property string what: glyph === "sun" ? Tr.t("Brightness") : glyph === "mute" ? Tr.t("Sound muted")
        : glyph === "micOff" ? Tr.t("Microphone muted") : glyph === "mic" ? Tr.t("Microphone") : Tr.t("Volume")

    function show(g, l) {
        // Quick settings has its own sliders; no pill over the top of them.
        if (Desktop.quickOpen || Desktop.locked) return;
        glyph = g;
        level = Math.max(0, Math.min(1, l));
        shown = true;
        pill.Accessible.announce(what + " " + Math.round(level * 100) + "%");
        hide.restart();
    }
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    // PipeWire reports the current values once a node is bound; only changes after that count.
    property bool settled: false
    onSinkChanged: { settled = false; settle.restart(); }
    onSourceChanged: { settled = false; settle.restart(); }
    Timer { id: settle; interval: 500; running: true; onTriggered: root.settled = true }

    function showSink() {
        if (settled && sink?.audio) show(sink.audio.muted ? "mute" : "volume", sink.audio.muted ? 0 : sink.audio.volume);
    }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showSink(); }
        function onMutedChanged() { root.showSink(); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() {
            if (root.settled) root.show(root.source.audio.muted ? "micOff" : "mic", root.source.audio.muted ? 0 : root.source.audio.volume);
        }
    }

    // `kriss-shell brightness 5%+`: brightnessctl sets it and prints the new state, e.g.
    // "intel_backlight,backlight,400,40%,1000".
    Process {
        id: backlight
        stdout: SplitParser { onRead: line => root.show("sun", parseInt(line.split(",")[3]) / 100) }
    }
    IpcHandler {
        target: "osd"
        function brightness(step: string): void {
            backlight.command = ["brightnessctl", "-m", "-c", "backlight", "set", step];
            backlight.running = true;
        }
    }

    PanelWindow {
        id: win
        visible: root.shown || pill.opacity > 0
        screen: Desktop.screen
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kriss-osd"
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        margins.bottom: Theme.barHeight + Theme.gap * 2
        implicitWidth: Math.max(260, Theme.sp(14) * 4 + 200)
        implicitHeight: Math.max(56, Theme.sp(14) + 36)
        color: "transparent"
        mask: Region {}

        Rectangle {
            id: pill
            width: parent.width
            height: parent.height
            radius: height / 2
            color: Theme.bar
            border.color: Theme.rim
            border.width: Theme.rimWidth
            opacity: root.shown ? 1 : 0
            // Read out by a screen reader, as the level changes.
            Accessible.role: Accessible.ProgressBar
            Accessible.name: root.what
            y: root.shown || Theme.reduceMotion ? 0 : 8
            Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            Behavior on y { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

            Glyph {
                id: icon
                name: root.glyph
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                id: track
                anchors.left: icon.right
                anchors.right: value.left
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Theme.line
                Rectangle {
                    width: track.width * root.level
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
            }
            Text {
                id: value
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(34, implicitWidth)
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.level * 100)
                color: Theme.fg
                font.family: Theme.sans
                font.pixelSize: Theme.sp(14)
                font.features: { "tnum": 1 }
            }
        }
    }
}
