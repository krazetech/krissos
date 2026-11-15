pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open windows, from kriss-shell-toplevels (cosmic-comp has no protocol Quickshell
// can read windows from directly).
Singleton {
    id: root

    // [{id, appId, title, active, minimized}]
    property var list: []

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
                    root.list = JSON.parse(line);
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
