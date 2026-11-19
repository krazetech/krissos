import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io

// The lock screen (LockFace) with a password checked by PAM. One surface per screen; they
// share the typed password. Unlocking fades and scales the lock away over the desktop.
Scope {
    id: root

    property string password: ""
    property string message: ""
    property bool checking: false
    readonly property string hint: Tr.t("Press any key to unlock")
    readonly property string verb: Tr.t("Unlock")
    readonly property string userName: Desktop.personName
    // Where the user's picture may be: their own, then the one COSMIC Settings sets.
    readonly property var faces: Desktop.faces

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
                root.unlock();
            } else {
                root.message = Tr.t("That password didn't work. Try again.");
            }
        }
    }

    // The unlock: the session lock hides the desktop until it ends, so each screen's lock is
    // pictured first, the picture goes up over the desktop (under the lock, unseen), and once
    // the lock ends the picture fades and grows away. Reduced motion just unlocks.
    signal picture
    property var pictures: ({})  // screen name: grabToImage result (its url lives as long as it)
    property bool fading: false
    function unlock() {
        if (Theme.reduceMotion) { Desktop.locked = false; return; }
        pictures = {};
        picture();
        handover.restart();
    }
    Timer {
        id: handover
        interval: 150  // the pictures are taken and their windows drawn
        onTriggered: { root.fading = true; Desktop.locked = false; fadeEnd.restart(); }
    }
    Timer { id: fadeEnd; interval: 360; onTriggered: { root.fading = false; root.pictures = {}; } }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: ghost
            required property var modelData
            screen: modelData
            readonly property var shot: root.pictures[modelData.name] ?? null
            visible: shot !== null
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-unlock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            Image {
                anchors.fill: parent
                source: ghost.shot?.url ?? ""
                opacity: root.fading ? 0 : 1
                scale: root.fading ? 1.06 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.ms(300); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.ms(300); easing.type: Easing.OutCubic } }
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

    // Lock when the laptop is about to sleep, and when logind asks this session to
    // (`loginctl lock-session`). gdbus prints one line per login1 signal, such as
    //   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
    //   /org/freedesktop/login1/session/_33: org.freedesktop.login1.Session.Lock ()
    // login1 escapes a session id's leading digit (and any other character that isn't
    // a letter or digit) as _XX hex.
    readonly property string sessionPath: "/org/freedesktop/login1/session/" +
        (Quickshell.env("XDG_SESSION_ID") ?? "").replace(/^[0-9]|[^A-Za-z0-9]/g,
            c => "_" + c.charCodeAt(0).toString(16))
    Process {
        id: login1
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(".Manager.PrepareForSleep (true")
                    || line.startsWith(root.sessionPath + ": org.freedesktop.login1.Session.Lock ("))
                    Desktop.locked = true;
            }
        }
        // ponytail: restart with a fixed delay, as kriss-shell-toplevels does.
        onExited: (code, status) => relogin1.start()
    }
    Timer { id: relogin1; interval: 2000; onTriggered: login1.running = true }

    // Hold off sleep until the lock is up, so the desktop never shows on resume. logind
    // waits for this delay inhibitor (up to InhibitDelayMaxSec, 5 s) and the shell lets go
    // once the lock surface has had a moment to draw. cat exits when its stdin closes.
    Timer { id: drawn; interval: 300 }
    Process {
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=KrissOS Shell",
                  "--why=Lock the screen first", "cat"]
        stdinEnabled: true
        running: !root.engaged && !drawn.running
    }
    onEngagedChanged: if (engaged) drawn.restart()

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
            id: surface
            color: Theme.night

            LockFace {
                id: lockFace
                host: root
                Connections {
                    target: root
                    function onPicture() {
                        const name = surface.screen?.name ?? "";
                        lockFace.grabToImage(r => root.pictures = Object.assign({}, root.pictures, { [name]: r }));
                    }
                }
            }
        }
    }
}
