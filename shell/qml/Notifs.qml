pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon. Toasts show for a few seconds on the focused screen; every
// notification stays in the notification center until it is dismissed, shell restarts
// included. Do not disturb stops the toasts, except critical ones (a low battery, say). So does
// a fullscreen window on the toasts' screen: what arrives meanwhile only goes in the center, and
// never pops up later.
Singleton {
    id: root

    // The notification center, oldest first: what is left from before the shell started
    // (plain records, without actions), then the live notifications.
    readonly property var live: server.trackedNotifications.values
    property var saved: []
    readonly property var all: saved.concat(live)
    // The same list as a model, so the stack keeps its cards (and their motion) when one comes or goes.
    readonly property ScriptModel model: ScriptModel { values: root.all }
    readonly property int popupMs: 6000
    property var arrived: ({})
    property var held: ({}) // ids that came while a fullscreen window was in front
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
        if (n.saved) return false;
        if (n.urgency === NotificationUrgency.Critical) return true;
        return !Desktop.dnd && !held[n.id] && !Windows.fullscreenOn(Desktop.screen) && now - (arrived[n.id] ?? 0) < popupMs;
    }

    // Taking an action finishes a notification, as on Windows, unless the app asked
    // for it to stay (resident).
    function invoke(n, action) {
        action.invoke();
        if (!n.resident) n.dismiss();
    }

    function dismiss(n) {
        if (n.saved) saved = saved.filter(s => s !== n);
        else n.dismiss();
    }

    function clear(appName) {
        for (const n of all.slice()) if (appName === undefined || n.appName === appName) dismiss(n);
    }

    // When it came, as "Just now" or "5 min ago".
    function ago(n) {
        const t = n.saved ? n.time : arrived[n.id];
        return t === undefined ? "" : Tr.ago(new Date(t), now);
    }

    // The history in $XDG_STATE_HOME/kriss/notifications.json, newest 100. Image data an
    // app sent inline is not kept, only images and icons it named.
    function record(n) {
        if (n.saved) return { appName: n.appName, appIcon: n.appIcon, image: n.image, summary: n.summary, body: n.body, urgency: n.urgency, time: n.time };
        const image = /^(\/|file:)/.test(n.image) ? n.image : "";
        return { appName: n.appName, appIcon: n.appIcon, image, summary: n.summary, body: n.body, urgency: n.urgency, time: arrived[n.id] ?? Date.now() };
    }
    FileView {
        id: store
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/kriss/notifications.json"
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        let list = [];
        try { list = JSON.parse(store.text() || "[]"); } catch (e) {}
        saved = list.map((r, i) => Object.assign(r, { id: "s" + i, saved: true, actions: [], resident: false }));
        dedupe();
        ready = true;
    }
    property bool ready: false
    // Written a moment after a change, so a shell quitting (its live list emptying) leaves the file be.
    onAllChanged: if (ready) save.restart()
    Timer { id: save; interval: 1000; onTriggered: store.setText(JSON.stringify(root.all.slice(-100).map(root.record))) }

    // Over a reload the live notifications stay and are in the file too: drop the copies,
    // keeping their time.
    onLiveChanged: if (ready) dedupe()
    function dedupe() {
        const same = (a, b) => a.appName === b.appName && a.summary === b.summary && a.body === b.body;
        const keep = saved.filter(s => {
            const n = live.find(l => same(l, s));
            if (n && arrived[n.id] === undefined) arrived[n.id] = s.time;
            return !n;
        });
        if (keep.length !== saved.length) saved = keep;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: n => {
            root.arrived[n.id] = Date.now();
            n.tracked = true;
            root.now = Date.now();
            // Follow the focused window's screen, unless a panel is open on another one.
            if (!Desktop.launcherOpen && !Desktop.notificationsOpen && !Desktop.quickOpen && !Desktop.calendarOpen)
                Desktop.screen = Desktop.focusedScreen();
            if (Windows.fullscreenOn(Desktop.screen)) root.held[n.id] = true;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.all.length > 0 && !root.paused
        onTriggered: root.now = Date.now()
    }
}
