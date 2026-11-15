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

    function forApp(appId) {
        return list.filter(w => w.appId === appId);
    }

    // Windows-taskbar behaviour: click a background app to bring it up, click the
    // app in front to minimize it.
    function toggle(appId) {
        const wins = forApp(appId);
        if (wins.length === 0) return false;
        const front = wins.find(w => w.active && !w.minimized);
        helper.write((front ? "minimize " + front.id : "activate " + wins[wins.length - 1].id) + "\n");
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

    Process {
        id: helper
        command: ["kriss-shell-toplevels"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.raw = JSON.parse(line);
                } catch (e) {
                    console.warn("kriss-shell-toplevels:", line);
                }
            }
        }
        // ponytail: restart forever with a fixed delay; a crash loop only costs a log line every 2 s.
        onExited: (code, status) => restart.start()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: helper.running = true
    }
}
