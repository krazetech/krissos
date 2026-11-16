//@ pragma IconTheme {{icon_theme}}
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

// KrissOS Shell: wallpaper, one floating bottom bar per screen, the launcher,
// notifications, quick settings, the lock screen and the volume and brightness pop-up.
ShellRoot {
    id: root

    // Open one panel on the focused window's screen, closing the others.
    function toggle(panel) {
        const open = !Desktop[panel];
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = false;
        if (open) Desktop.screen = Desktop.focusedScreen();
        Desktop[panel] = open;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "kriss-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.night

            Image {
                anchors.fill: parent
                // kriss-theme's wallpaper for the current light or dark theme.
                source: "file:///usr/share/backgrounds/kriss/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"
                sourceSize: Qt.size(parent.width, parent.height)
                fillMode: Image.PreserveAspectCrop
            }
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Launcher {}
    Notifications {}
    QuickSettings {}
    Lock {}
    Switcher { id: switcher }
    Osd {}

    // KRISS_SHELL_FPS=1: for a second after a panel opens or closes, counts the frames and
    // logs the rate and the slowest frame (read it with `qs log`), to check motion on real hardware.
    FrameAnimation {
        id: fps
        readonly property bool wanted: Quickshell.env("KRISS_SHELL_FPS") === "1"
        property string what
        property real worst: 0
        onTriggered: worst = Math.max(worst, frameTime)
        function measure(name) {
            if (!wanted) return;
            what = name; worst = 0;
            reset(); start(); fpsDone.restart();
        }
    }
    Timer {
        id: fpsDone
        interval: 1000
        onTriggered: {
            fps.stop();
            console.log("fps:", fps.what, Math.round(fps.currentFrame / fps.elapsedTime), "fps,",
                fps.currentFrame, "frames, slowest", Math.round(fps.worst * 1000), "ms");
        }
    }
    Connections {
        target: Desktop
        function onLauncherOpenChanged() { fps.measure("launcher " + (Desktop.launcherOpen ? "open" : "close")); }
        function onQuickOpenChanged() { fps.measure("quick " + (Desktop.quickOpen ? "open" : "close")); }
        function onNotificationsOpenChanged() { fps.measure("notifications " + (Desktop.notificationsOpen ? "open" : "close")); }
    }

    // cosmic-comp runs `kriss-shell COMMAND` for the Windows-key shortcuts, which calls these.
    // `kriss-shell launcher|quick|notifications`: Windows, Windows+A and Windows+N.
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle("launcherOpen"); }
    }

    IpcHandler {
        target: "quick"
        function toggle(): void { root.toggle("quickOpen"); }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.toggle("notificationsOpen"); }
    }

    IpcHandler {
        target: "desktop"
        function toggle(): void { Windows.showDesktop(); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Desktop.locked = true; }
    }

    IpcHandler {
        target: "switcher"
        function next(): void { switcher.step(1); }
        function previous(): void { switcher.step(-1); }
    }

    // The media keys.
    IpcHandler {
        target: "media"
        function playPause(): void { if (Desktop.player?.canTogglePlaying) Desktop.player.togglePlaying(); }
        function next(): void { if (Desktop.player?.canGoNext) Desktop.player.next(); }
        function previous(): void { if (Desktop.player?.canGoPrevious) Desktop.player.previous(); }
    }

    // Low battery, as on Windows: a warning at 10% and again at 5%, while it isn't charging.
    // Critical, so it shows through Do not disturb.
    Connections {
        target: UPower.displayDevice
        property int warned: 100
        function onPercentageChanged() {
            const dev = UPower.displayDevice, pct = Math.round(dev.percentage * 100);
            if (!dev.isLaptopBattery || !UPower.onBattery) { warned = 100; return; }
            const level = pct <= 5 ? 5 : pct <= 10 ? 10 : 100;
            if (level >= warned) return;
            warned = level;
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", Tr.t("Battery"), "-i", "battery-caution",
                Tr.t("Battery low: %1%", pct), Tr.t("Plug in the charger soon.")]);
        }
    }
}
