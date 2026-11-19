pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open windows, from kriss-shell-toplevels (cosmic-comp has no protocol Quickshell
// can read windows from directly).
Singleton {
    id: root

    // [{id, appId, title, active, minimized, fullscreen, output, workspace, geo}], as the helper
    // reports them; geo[output] is [x, y, width, height] on that screen.
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

    // Whether a fullscreen window is in front on this screen: the one there used last is
    // fullscreen and not minimized. Its bar hides and toasts wait behind the bell.
    function fullscreenOn(screen) {
        const top = byRecent.find(w => w.output === screen?.name && !w.minimized);
        return !!top?.fullscreen;
    }

    function activate(id) {
        helper.write("activate " + id + "\n");
    }

    // An app's windows, oldest first (the order a click steps through them), out of `among`
    // (one bar's windows) or all of them.
    function forApp(appId, among) {
        const key = appId.toLowerCase();
        return (among ?? list).filter(w => w.appId.toLowerCase() === key).sort((a, b) => a.id - b.id);
    }

    // A taskbar button's click, as on Windows. Nothing open: false, so the caller launches
    // the app. One window: bring it up, or minimize it when it is already in front. Several:
    // bring up the one used last, then, while one of them is in front, the next in turn.
    // cycle (Ctrl+click) only ever steps, never minimizes.
    function activateApp(appId, cycle, among) {
        const wins = forApp(appId, among);
        if (wins.length === 0) return false;
        const front = wins.findIndex(w => w.active && !w.minimized);
        if (front < 0) activate((byRecent.find(w => wins.indexOf(w) >= 0) ?? wins[0]).id);
        else if (wins.length > 1) activate(wins[(front + 1) % wins.length].id);
        else if (!cycle) helper.write("minimize " + wins[front].id + "\n");
        return true;
    }

    // An uncombined button's click: bring the window up, or minimize it when it is in front.
    function toggleWindow(w, cycle) {
        helper.write((w.active && !w.minimized && !cycle ? "minimize " : "activate ") + w.id + "\n");
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

    // Desktops (cosmic-comp's workspaces), every screen's, in order:
    // [{id, name, active, outputs}]. Windows say which one they are on (`workspace`).
    property var workspaces: []

    // One screen's desktops; all of them where the compositor does not say which screen.
    function desktopsOn(screenName) {
        return workspaces.filter(d => d.outputs.length === 0 || d.outputs.indexOf(screenName) >= 0);
    }
    function switchTo(id) {
        helper.write("workspace " + id + "\n");
    }
    function moveTo(winId, deskId) {
        helper.write("move " + winId + " " + deskId + "\n");
    }
    // Windows+Ctrl+D: a new desktop, as on Windows. cosmic-comp can't create one on request,
    // but always keeps an empty one at the end, so switch to that. Nothing when it is the current one.
    function newDesktop(screenName) {
        const desks = desktopsOn(screenName), last = desks[desks.length - 1];
        if (last && !last.active) switchTo(last.id);
    }
    // Close a desktop, as on Windows: its windows move to the one before it (the first
    // desktop's to the one after), which becomes the current one if this one was. cosmic-comp
    // then drops the empty desktop itself. Custom names move along with their desktops.
    function closeDesktop(id) {
        const all = workspaces.find(d => d.id === id);
        if (!all) return;
        const desks = desktopsOn(all.outputs[0] ?? ""), i = desks.findIndex(d => d.id === id);
        const to = desks[i > 0 ? i - 1 : 1];
        if (!to) return;
        for (const w of raw) if (w.workspace === id) moveTo(w.id, to.id);
        if (all.active) switchTo(to.id);
        if (i < Desktop.desktopNames.length) {
            const names = Desktop.desktopNames.slice();
            names.splice(i, 1);
            Desktop.desktopNames = names;
        }
    }

    // Snap layouts, with cosmic-comp-kriss: tile a window into zone [x, y, width, height],
    // in twelfths of its screen's work area. The pointer resting on a window's maximize
    // button (or leaving it) comes as maximizeHovered.
    property bool snapReady: false
    signal maximizeHovered(int id, bool on)
    function snap(id, zone) {
        helper.write("snap " + id + " " + zone.join(" ") + "\n");
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
                    else if (msg.workspaces) root.workspaces = msg.workspaces;
                    else if (msg.snap) root.snapReady = true;
                    else if (msg.hover !== undefined) root.maximizeHovered(msg.hover, msg.on);
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
        onExited: (code, status) => { root.thumbs = {}; root.workspaces = []; root.snapReady = false; restart.start(); }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: helper.running = true
    }
}
