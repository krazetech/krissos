//@ pragma IconTheme {{icon_theme}}
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// KrissOS Shell: wallpaper, one floating bottom bar per screen, the launcher,
// notifications, quick settings and the lock screen.
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
                source: "file:///usr/share/backgrounds/kriss/default.svg"
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
}
