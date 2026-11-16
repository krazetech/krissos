pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification daemon. Toasts show for a few seconds on the focused screen; every
// notification stays in the list behind the bell until it is dismissed. Do not disturb
// stops the toasts, except critical ones (a low battery, say).
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    // The same list as a model, so the stack keeps its cards (and their motion) when one comes or goes.
    readonly property var model: server.trackedNotifications
    readonly property int popupMs: 6000
    property var arrived: ({})
    property real now: Date.now()

    // Hovering the toasts pauses their timers, as in Sonner; they pick up where they were.
    property bool paused: false
    property real pausedAt: 0
    onPausedChanged: {
        if (paused) { pausedAt = Date.now(); return; }
        const held = Date.now() - pausedAt;
        for (const id in arrived) arrived[id] += held;
        now = Date.now();
    }

    function isPopup(n) {
        if (n.urgency === NotificationUrgency.Critical) return true;
        return !Desktop.dnd && now - (arrived[n.id] ?? 0) < popupMs;
    }

    // Taking an action finishes a notification, as on Windows, unless the app asked
    // for it to stay (resident).
    function invoke(n, action) {
        action.invoke();
        if (!n.resident) n.dismiss();
    }

    function clear(appName) {
        for (const n of all.slice()) if (appName === undefined || n.appName === appName) n.dismiss();
    }

    // When it came, as "Just now" or "5 min ago"; "" for one kept over a shell reload.
    // ponytail: arrival times live only in memory, so a reload forgets them.
    function ago(n) {
        const t = arrived[n.id];
        return t === undefined ? "" : Tr.ago(new Date(t), now);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            root.arrived[n.id] = Date.now();
            root.now = Date.now();
            // Follow the focused window's screen, unless a panel is open on another one.
            if (!Desktop.launcherOpen && !Desktop.notificationsOpen && !Desktop.quickOpen && !Desktop.calendarOpen)
                Desktop.screen = Desktop.focusedScreen();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.all.length > 0 && !root.paused
        onTriggered: root.now = Date.now()
    }
}
