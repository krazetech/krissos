pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open windows, from kriss-shell-toplevels (cosmic-comp has no protocol Quickshell
// can read windows from directly).
Singleton {
    id: root

    // [{id, appId, title, active, minimized, output}], as the helper reports them.
    property var raw: []
    // The same, with each appId swapped for the pinned app it belongs to. A window's id
    // can name another desktop file for the same program (KDE System Settings runs as
    // "kdesystemsettings", the pin is "systemsettings"), so a pin with the same command counts.
    readonly property var list: {
        DesktopEntries.applications.values; // re-run once desktop files are scanned
        const pins = Desktop.pinned;
        const cmd = id => DesktopEntries.byId(id)?.command.join(" ");
        return raw.map(w => {
            const c = DesktopEntries.heuristicLookup(w.appId)?.command.join(" ");
            const pin = pins.find(p => p.toLowerCase() === w.appId.toLowerCase() || c && cmd(p) === c);
            return pin ? Object.assign({}, w, { appId: pin }) : w;
        });
    }
    // Windows that Show desktop minimized, to bring back on the second press.
    property var hidden: []
    // Window ids, the most recently focused first, for Alt+Tab.
    property var recent: []
    onRawChanged: {
        const ids = raw.map(w => w.id);
        const now = raw.find(w => w.active && !w.minimized)?.id;
        const kept = recent.filter(id => id !== now && ids.indexOf(id) >= 0);
        const fresh = ids.filter(id => id !== now && kept.indexOf(id) < 0);
        recent = (now !== undefined ? [now] : []).concat(kept, fresh);
    }
    // The open windows in Alt+Tab order.
    readonly property var byRecent: recent.map(id => list.find(w => w.id === id)).filter(w => w)

    // Window id -> the latest preview picture's URL. Kept after a preview hides, so a
    // window minimized since still shows its last picture.
    property var thumbs: ({})

    // Capture these windows' previews at about size pixels on the long edge, and only these;
    // an empty list stops capturing.
    function capture(ids, size) {
        helper.write("thumbs " + Math.round(size) + " " + ids.join(" ") + "\n");
    }

    function activate(id) {
        helper.write("activate " + id + "\n");
    }

    // An app's windows, oldest first (the order a click steps through them).
    function forApp(appId) {
        const key = appId.toLowerCase();
        return list.filter(w => w.appId.toLowerCase() === key).sort((a, b) => a.id - b.id);
    }

    // A taskbar button's click, as on Windows. Nothing open: false, so the caller launches
    // the app. One window: bring it up, or minimize it when it is already in front. Several:
    // bring up the one used last, then, while one of them is in front, the next in turn.
    // cycle (Ctrl+click) only ever steps, never minimizes.
    function activateApp(appId, cycle) {
        const wins = forApp(appId);
        if (wins.length === 0) return false;
        const front = wins.findIndex(w => w.active && !w.minimized);
        if (front < 0) activate((byRecent.find(w => wins.indexOf(w) >= 0) ?? wins[0]).id);
        else if (wins.length > 1) activate(wins[(front + 1) % wins.length].id);
        else if (!cycle) helper.write("minimize " + wins[front].id + "\n");
        return true;
    }

    // Windows+D: minimize everything; pressing it again restores what it minimized.
    function showDesktop() {
        const shown = list.filter(w => !w.minimized);
        if (shown.length > 0) {
            // The focused window last, so it ends up in front again on restore.
            hidden = shown.sort((a, b) => a.active - b.active).map(w => w.id);
            for (const w of shown) helper.write("minimize " + w.id + "\n");
        } else {
            for (const id of hidden) helper.write("activate " + id + "\n");
            hidden = [];
        }
    }

    function close(id) {
        helper.write("close " + id + "\n");
    }

    // Progress, badge counts and "needs attention" that apps send the way Ubuntu's dock reads
    // them (com.canonical.Unity.LauncherEntry, on the session bus), by lower-case desktop file
    // id: {"firefox": {"progress": 0.4, "progress-visible": true, "count": 3, "urgent": false}}.
    property var entries: ({})
    property string entryApp: ""
    property string entryKey: ""
    // dbus-monitor prints each Update signal as an app URI, then key and variant lines.
    function readEntry(line) {
        const t = line.trim();
        let m;
        if (t.startsWith("signal ")) { entryApp = entryKey = ""; return; }
        if (!entryApp) {
            if ((m = /^string "application:\/\/(.+?)(\.desktop)?"$/.exec(t))) entryApp = m[1].toLowerCase();
        } else if ((m = /^string "(.+)"$/.exec(t))) {
            entryKey = m[1];
        } else if (entryKey && (m = /^variant\s+\S+\s+(\S+)$/.exec(t))) {
            const all = Object.assign({}, entries);
            all[entryApp] = Object.assign({}, all[entryApp]);
            all[entryApp][entryKey] = m[1] === "true" ? true : m[1] === "false" ? false : Number(m[1]);
            entries = all;
            entryKey = "";
        }
    }

    Process {
        command: ["dbus-monitor", "--session", "type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'"]
        running: true
        stdout: SplitParser { onRead: line => root.readEntry(line) }
    }

    Process {
        id: helper
        command: ["kriss-shell-toplevels"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    // Newer helpers also send other messages as objects; only the window list is an array.
                    const msg = JSON.parse(line);
                    if (Array.isArray(msg)) root.raw = msg;
                    else if (msg.thumb !== undefined) root.thumbs = Object.assign({}, root.thumbs, { [msg.thumb]: msg.url });
                } catch (e) {
                    console.warn("kriss-shell-toplevels:", line);
                }
            }
        }
        // Its errors, such as a traceback from a Wayland event it could not handle, go to the
        // shell log (`qs log`), one log line per line.
        stderr: SplitParser { onRead: line => console.warn("kriss-shell-toplevels:", line) }
        // ponytail: restart forever with a fixed delay; a crash loop only costs a log line every 2 s.
        onExited: (code, status) => { root.thumbs = {}; restart.start(); }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: helper.running = true
    }
}
