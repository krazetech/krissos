//@ pragma IconTheme {{icon_theme}}
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// KrissOS Shell: wallpaper, one floating bottom bar per screen, the launcher,
// notifications and the lock screen.
ShellRoot {
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
    Lock {}

    // `kriss-shell launcher` and `kriss-shell lock` call these; cosmic-comp binds them
    // to the Windows key and Windows+L.
    IpcHandler {
        target: "launcher"
        function toggle(): void { Desktop.launcherOpen = !Desktop.launcherOpen; }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Desktop.locked = true; }
    }
}
