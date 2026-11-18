pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// What the bar, launcher, panels and lock screen share, and the user's shell settings.
Singleton {
    id: root

    property bool launcherOpen: false
    property bool notificationsOpen: false
    property bool quickOpen: false
    property bool calendarOpen: false
    property bool taskViewOpen: false
    property bool locked: false
    // Start opened from the bar's search box: the search field and Recommended, no Pinned.
    property bool launcherSearch: false

    // The screen the launcher, notifications and quick settings open on. A click on a
    // bar sets it to that bar's screen; a key press uses the screen of the focused window.
    property var screen: Quickshell.screens[0]

    // The media player the keys and quick settings control: one that is playing, else the
    // first one open.
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    function focusedScreen() {
        const out = Windows.list.find(w => w.active && !w.minimized)?.output;
        return Quickshell.screens.find(s => s.name === out) ?? screen ?? Quickshell.screens[0];
    }

    // ~/.config/kriss/shell.json. Missing keys keep the defaults below.
    property alias pinned: config.pinned
    property alias dnd: config.dnd
    property alias taskbarAlignment: config.taskbarAlignment
    property alias taskbarAutoHide: config.taskbarAutoHide
    property alias taskbarCombine: config.taskbarCombine
    property alias taskbarAllScreens: config.taskbarAllScreens
    // What the launcher, quick settings and calendar leave below them for an auto-hidden bar,
    // which reserves no room of its own.
    readonly property int barRoom: taskbarAutoHide ? Theme.barHeight : 0
    property alias trayHidden: config.trayHidden
    property alias taskbarTaskView: config.taskbarTaskView
    property alias desktopNames: config.desktopNames

    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/kriss/shell.json"
    FileView {
        path: root.configFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: config
            // Pinned apps, as desktop file ids, in taskbar order. Missing apps are skipped.
            property list<string> pinned: [
                "firefox", "com.system76.CosmicFiles", "com.system76.CosmicTerm", "code", "steam",
                "winboat", "thunderbird", "com.github.th_ch.youtube_music", "com.system76.CosmicSettings"
            ]
            // Do not disturb: no toasts, notifications still collect behind the bell.
            property bool dnd: false
            // Taskbar: "left" or "centre" (Start, search and the apps centred, as on Windows 11).
            property string taskbarAlignment: "centre"
            // Slide the bar off the bottom edge until the pointer reaches it.
            property bool taskbarAutoHide: false
            // Combine an app's windows on one button: "always", "full" (when the bar runs out
            // of room) or "never". Uncombined buttons are one per window, with its title.
            property string taskbarCombine: "always"
            // A bar on every screen, each with the windows on that screen; false: one bar,
            // on the first screen, with every window.
            property bool taskbarAllScreens: true
            // Tray icons kept in the overflow flyout (^), by the id the app gives its icon.
            property list<string> trayHidden: []
            // The Task View button on the taskbar, after Start.
            property bool taskbarTaskView: true
            // Desktop names given in Task View, by position ("" keeps "Desktop N").
            property list<string> desktopNames: []
        }
    }

    function isPinned(id) {
        return pinned.indexOf(id) >= 0;
    }

    function togglePin(id) {
        pinned = isPinned(id) ? pinned.filter(p => p !== id) : pinned.concat([id]);
    }

    function isTrayHidden(id) {
        return trayHidden.indexOf(id) >= 0;
    }

    function setTrayHidden(id, hide) {
        if (hide !== isTrayHidden(id)) trayHidden = hide ? trayHidden.concat([id]) : trayHidden.filter(t => t !== id);
    }

    // Drag to reorder: pinned app `id` takes the place of pinned app `target`.
    function movePin(id, target) {
        const list = pinned.slice();
        const from = list.indexOf(id), to = list.indexOf(target);
        if (from < 0 || to < 0 || from === to) return;
        list.splice(from, 1);
        list.splice(to, 0, id);
        pinned = list;
    }

    // Recently used files, newest first, from the list GTK and most other apps keep:
    // [{href, when, name, mime, apps}], apps being the programs (command names) that used it.
    readonly property var recent: {
        const text = recentFile.text() ?? "";
        const out = [];
        // ponytail: regex over the XBEL file; fine for the few hundred entries it holds.
        const re = /<bookmark\s[^>]*href="([^"]+)"[^>]*modified="([^"]+)"[^>]*>([\s\S]*?)<\/bookmark>/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            const apps = [];
            const appRe = /<bookmark:application name="([^"]*)" exec="([^"]*)"/g;
            let a;
            while ((a = appRe.exec(m[3])) !== null) {
                const cmd = a[2].replace(/&apos;|'|"/g, "").split(" ")[0];
                apps.push(cmd.split("/").pop().toLowerCase(), a[1].toLowerCase());
            }
            out.push({ href: m[1], when: new Date(m[2]), name: decodeURIComponent(m[1].split("/").pop()),
                       mime: /mime-type type="([^"]+)"/.exec(m[3])?.[1] ?? "", apps: apps });
        }
        return out.sort((a, b) => b.when - a.when).slice(0, 200);
    }

    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // An app's recent files, for its jump list: those it opened, by command or app name.
    function recentFor(entry, limit) {
        if (!entry) return [];
        const names = [entry.command[0]?.split("/").pop().toLowerCase(), entry.id.toLowerCase(), entry.name.toLowerCase()];
        return recent.filter(f => f.href.startsWith("file:") && f.apps.some(a => a && names.indexOf(a) >= 0)).slice(0, limit);
    }

    function pinnedEntries(limit) {
        // Read the app list so bindings that call this re-run once Quickshell has
        // finished scanning desktop files (byId returns null until then).
        DesktopEntries.applications.values;
        const out = [];
        for (const id of pinned) {
            const entry = DesktopEntries.byId(id);
            if (entry && !entry.noDisplay) out.push(entry);
            if (out.length === limit) break;
        }
        return out;
    }
}
