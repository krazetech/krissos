pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification daemon. Toasts show for a few seconds; every notification stays
// in the list behind the bell until it is dismissed.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    readonly property int popupMs: 6000
    property var arrived: ({})
    property real now: Date.now()

    function isPopup(n) {
        return n.urgency === NotificationUrgency.Critical || now - (arrived[n.id] ?? 0) < popupMs;
    }

    // Taking an action finishes a notification, as on Windows, unless the app asked
    // for it to stay (resident).
    function invoke(n, action) {
        action.invoke();
        if (!n.resident) n.dismiss();
    }

    function clear() {
        for (const n of all.slice()) n.dismiss();
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
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.all.length > 0
        onTriggered: root.now = Date.now()
    }
}
