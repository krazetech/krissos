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

    WlSessionLock {
        locked: Desktop.locked

        WlSessionLockSurface {
            color: Theme.night

            LockFace { host: root }
        }
    }
}
