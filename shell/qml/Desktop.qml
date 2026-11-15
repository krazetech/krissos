pragma Singleton

import QtQuick
import Quickshell

// What the bar, launcher, notifications and lock screen share.
Singleton {
    property bool launcherOpen: false
    property bool notificationsOpen: false
    property bool locked: false

    // Pinned apps, as desktop file ids. The bar shows the first six, the launcher all of them.
    // ponytail: fixed list, missing apps are skipped. Add pin/unpin from the menu when asked for.
    readonly property var pinned: [
        "firefox", "org.gnome.Nautilus", "org.kde.dolphin", "kitty", "org.wezfurlong.wezterm",
        "code", "steam", "winboat", "thunderbird", "org.gnome.Calendar", "org.gnome.Loupe",
        "org.kde.elisa", "com.github.th_ch.youtube_music", "org.gnome.Settings", "systemsettings"
    ]

    function pinnedEntries(limit) {
        const out = [];
        for (const id of pinned) {
            const entry = DesktopEntries.byId(id);
            if (entry && !entry.noDisplay) out.push(entry);
            if (out.length === limit) break;
        }
        return out;
    }
}
