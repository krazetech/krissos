import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// The lock screen: blurred wallpaper, the time, and a password field checked by PAM.
// One surface per screen; they share the typed password.
Scope {
    id: root

    property string password: ""
    property string message: ""
    property bool checking: false
    readonly property string hint: Tr.t("Press Enter to unlock")
    readonly property string userName: Quickshell.env("USER") ?? ""

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

    // cosmic-comp 1.11 gives a new lock surface the keyboard only when something else had
    // it just before. On an empty desktop, or right after the launcher closes, nothing
    // does, and typing went nowhere until a click. So a 1 px surface takes the keyboard
    // first, and the lock follows a moment later.
    // ponytail: the lock starts 200 ms after the request; drop this once cosmic-comp
    // focuses lock surfaces itself.
    property bool engaged: false
    Connections {
        target: Desktop
        function onLockedChanged() {
            if (Desktop.locked) engage.restart();
            else { engage.stop(); root.engaged = false; }
        }
    }
    Timer { id: engage; interval: 200; onTriggered: root.engaged = true }

    PanelWindow {
        visible: Desktop.locked && !root.engaged
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kriss-lock-focus"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    }

    WlSessionLock {
        locked: root.engaged

        WlSessionLockSurface {
            color: Theme.night

            LockFace { host: root }
        }
    }
}
