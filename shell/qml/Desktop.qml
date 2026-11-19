pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// What the bar, launcher, panels and lock screen share, and the user's shell settings.
Singleton {
    id: root

    property bool launcherOpen: false
    property bool notificationsOpen: false
    property bool quickOpen: false
    property bool calendarOpen: false
    property bool taskViewOpen: false
    // The Personalise window's open page ("colours", "background", "taskbar", "pins" or
    // "text"); empty while it is closed.
    property string personalisePage: ""
    function personalise(page) {
        personalisePage = ["colours", "background", "taskbar", "pins", "text"].indexOf(page) >= 0 ? page : "colours";
    }
    property bool locked: false
    // Start opened from the bar's search box: the search field and Recommended, no Pinned.
    property bool launcherSearch: false

    // The screen the launcher, notifications and quick settings open on. A click on a
    // bar sets it to that bar's screen; a key press uses the screen of the focused window.
    property var screen: Quickshell.screens[0]

    // The media player the keys and quick settings control: one that is playing, else the
    // first one open.
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    // Esc in a panel: the bar that opened it from the keyboard takes the focus back (see
    // Bar.returnTo), then the panel closes.
    signal backOut()
    function back(panel) {
        backOut();
        root[panel] = false;
    }

    // The keyboard for a surface that is already on screen (the bar after Windows+T, the open
    // notification center, previews opened from the keyboard). cosmic-comp hands the keyboard
    // to a layer surface only as it appears, never when one already showing asks for it, so a
    // 1 px surface appears instead, takes the keyboard and passes every key to the item with the
    // focus in `keysFor` and up its parents, as if they had the keyboard. null gives it back.
    // ponytail: a workaround; drop it once cosmic-comp focuses a layer surface that turns exclusive.
    property Item keysFor: null
    property Item keysNext: null
    function keysTo(item) {
        // Hidden first, so showing it takes the keyboard even if something else had it since.
        keysFor = null;
        keysNext = item;
        if (item) keysShow.restart();
    }
    Timer {
        id: keysShow
        interval: 0
        onTriggered: {
            const item = root.keysNext;
            if (!item) return;
            keyProxy.screen = item.QsWindow.window?.screen ?? root.screen;
            if (item.Window.contentItem) item.Window.contentItem.focus = true;  // a window that lost the keyboard drops its focus
            root.keysFor = item;
        }
    }
    // After a menu or flyout that took the keyboard closes, cosmic-comp gives it to the window
    // behind, not back to keysFor: show the proxy anew so it takes it again.
    function retakeKeys() { if (keysFor) keysTo(keysFor); }
    PanelWindow {
        id: keyProxy
        visible: root.keysFor !== null
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; left: true }
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kriss-keys"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Item {
            focus: true
            Accessible.ignored: true
            Keys.forwardTo: {
                const out = [];
                for (let i = root.keysFor?.Window.activeFocusItem ?? null; i; i = i.parent) out.push(i);
                return out;
            }
        }
    }

    function focusedScreen() {
        const out = Windows.list.find(w => w.active && !w.minimized)?.output;
        return Quickshell.screens.find(s => s.name === out) ?? screen ?? Quickshell.screens[0];
    }

    // ~/.config/kriss/shell.json. Missing keys keep the defaults below.
    property alias pinned: config.pinned
    property alias dnd: config.dnd
    property alias trayHidden: config.trayHidden
    property alias taskbarAlignment: config.taskbarAlignment
    property alias taskbarAutoHide: config.taskbarAutoHide
    property alias taskbarCombine: config.taskbarCombine
    property alias taskbarAllScreens: config.taskbarAllScreens
    property alias taskbarSize: config.taskbarSize
    // What the launcher, quick settings and calendar leave below them for an auto-hidden bar,
    // which reserves no room of its own.
    readonly property int barRoom: taskbarAutoHide ? bottomRoom : 0
    property alias taskbarTaskView: config.taskbarTaskView
    property alias desktopNames: config.desktopNames
    property alias accent: config.accent
    property alias theme: config.theme
    property alias themeLight: config.themeLight
    property alias themeDark: config.themeDark
    property alias wallpaper: config.wallpaper
    property alias contrast: config.contrast
    property alias transparency: config.transparency
    property alias layout: config.layout
    // The Mac layout: a slim top bar and a centred dock in place of the taskbar (see Bar.qml).
    readonly property bool mac: layout === "mac"
    // What the bars take at the top and bottom of a screen: the taskbar, or the top bar and dock.
    readonly property int topRoom: mac ? Theme.topBarHeight : 0
    readonly property int bottomRoom: Theme.barHeight + (mac ? Theme.dockGap : 0)
    // `kriss-shell layout windows|mac`, kriss-welcome and the Personalise page.
    function setLayout(name) {
        if (name !== "windows" && name !== "mac") return "error: expected windows or mac";
        layout = name;
        return "ok";
    }
    // Window buttons follow the layout: on the left as on a Mac. GTK apps and Qt apps with the
    // Adwaita decorations read this; COSMIC apps keep theirs. Going to the Mac layout keeps the
    // user's own button layout in ~/.local/state/kriss/window-buttons, and going back restores it.
    // Also when shell.json is changed by hand or by kriss-welcome.
    onLayoutChanged: Quickshell.execDetached(["sh", "-c", `
        mac=close,minimize,maximize:appmenu
        saved=\${XDG_STATE_HOME:-$HOME/.local/state}/kriss/window-buttons
        if [ "$1" = mac ]; then
            own=$(gsettings get org.gnome.desktop.wm.preferences button-layout | tr -d "'")
            [ -n "$own" ] && [ "$own" != "$mac" ] && mkdir -p "\${saved%/*}" && printf '%s\n' "$own" > "$saved"
            buttons=$mac
        elif [ -s "$saved" ]; then
            buttons=$(cat "$saved")
            rm -f "$saved"
        else
            # Nothing saved: leave the user's own layout alone, undo only the Mac one.
            [ "$(gsettings get org.gnome.desktop.wm.preferences button-layout | tr -d "'")" = "$mac" ] || exit 0
            buttons=appmenu:minimize,maximize,close
        fi
        gsettings set org.gnome.desktop.wm.preferences button-layout "$buttons"
        for f in "\${XDG_CONFIG_HOME:-$HOME/.config}"/gtk-3.0/settings.ini "\${XDG_CONFIG_HOME:-$HOME/.config}"/gtk-4.0/settings.ini; do
            [ -f "$f" ] && sed -i "s/^gtk-decoration-layout=.*/gtk-decoration-layout=$buttons/" "$f"
        done`, "sh", layout])

    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/kriss/shell.json"
    FileView {
        path: root.configFile
        watchChanges: true
        printErrors: false
        blockLoading: true  // the theme is right from the first frame
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
            // Tray icons kept in the overflow flyout (^), by the id the app gives its icon.
            property list<string> trayHidden: []
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
            // "small", "medium" or "large": the bar's height and its icons (Theme.barScale).
            property string taskbarSize: "medium"
            // The Task View button on the taskbar, after Start.
            property bool taskbarTaskView: true
            // Desktop names given in Task View, by position ("" keeps "Desktop N").
            property list<string> desktopNames: []
            // Theme.qml: the accent ("#RRGGBB", empty for Sky Cyan), "dark", "light",
            // "system" or "auto", and when "auto" turns light and dark.
            property string accent: ""
            property string theme: "system"
            property string themeLight: "07:00"
            property string themeDark: "19:00"
            // "dynamic": the time-of-day wallpaper; a path ("/..."): that picture; anything
            // else: the plain one for the light or dark theme.
            property string wallpaper: "dynamic"
            // "high": the high-contrast colours (see Theme.qml), for low vision.
            property string contrast: "normal"
            // false: solid shell surfaces, no see-through (Windows' "Transparency effects").
            property bool transparency: true
            // "windows": the taskbar along the bottom. "mac": a top bar (the app's menu, the
            // tray, quick settings and the clock) and a centred dock. Switches live.
            property string layout: "windows"
        }
    }

    // A path as a file: URL, safe for spaces and #.
    function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }

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
