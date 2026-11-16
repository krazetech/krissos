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
    property bool locked: false

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

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/kriss/shell.json"
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
        }
    }

    function isPinned(id) {
        return pinned.indexOf(id) >= 0;
    }

    function togglePin(id) {
        pinned = isPinned(id) ? pinned.filter(p => p !== id) : pinned.concat([id]);
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
