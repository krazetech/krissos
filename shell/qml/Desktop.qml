pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// What the bar, launcher, panels and lock screen share, and the user's shell settings.
Singleton {
    id: root

    property bool launcherOpen: false
    property bool notificationsOpen: false
    property bool quickOpen: false
    property bool calendarOpen: false
    property bool taskViewOpen: false
    property bool widgetsOpen: false
    // The height of quick settings or the calendar while one is open in the toasts' corner,
    // so toasts arrive above it instead of on top of it (set by those panels).
    property int cornerRoom: 0

    // The focus rim (FocusRim.qml) shows only once a key has moved the focus, as on Windows
    // and macOS. Opening a panel puts the focus in it without a rim, and the pointer taking
    // over a highlight hides it again. Focus that moves after a panel has settled was moved
    // by a key (Tab, the arrows): the shell moves it from code only as a panel opens, or
    // when the pointer is over a row, which calls pointed().
    property bool keyNav: false
    property real settling: 0
    function opened(byKeyboard) { keyNav = !!byKeyboard; settling = Date.now() + 250; }
    function pointed() { keyNav = false; settling = Date.now() + 50; }
    function focusMoved() { if (Date.now() > settling) keyNav = true; }
    onLauncherOpenChanged: if (launcherOpen) opened()
    onNotificationsOpenChanged: if (notificationsOpen) opened()
    onQuickOpenChanged: if (quickOpen) opened()
    onCalendarOpenChanged: if (calendarOpen) opened()
    onTaskViewOpenChanged: if (taskViewOpen) opened()
    onWidgetsOpenChanged: if (widgetsOpen) opened()
    property bool locked: false
    // Start opened from the bar's search box: the search field and Recommended, no Pinned.
    property bool launcherSearch: false

    // The main display (Settings > Display; see Displays.qml): the full taskbar, Start and the
    // notifications from the keyboard, the desktop icons and the sign-in field are there. The
    // first screen until cosmic-randr has answered, or when it names none.
    readonly property var primary: Quickshell.screens.find(s => s.name === Displays.primary) ?? Quickshell.screens[0]

    // The screen the launcher, notifications and quick settings open on. A click on a
    // bar sets it to that bar's screen; their keys open them on the main display.
    property var screen: primary
    // An unplugged screen is not one to open on.
    Connections {
        target: Quickshell
        function onScreensChanged() { if (Quickshell.screens.indexOf(root.screen) < 0) root.screen = root.primary; }
    }

    // The media player the keys and quick settings control: one that is playing, else the
    // first one open.
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    // COSMIC's screenshot tool or KDE's when installed, else the whole screen into
    // Pictures/Screenshots with grim. It waits for Start or quick settings to fade first.
    function screenshot() {
        Quickshell.execDetached(["sh", "-c", `sleep 0.4
            for t in cosmic-screenshot spectacle; do command -v $t >/dev/null && exec $t; done
            d="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
            mkdir -p "$d" && f="$d/$(date +%F_%H-%M-%S).png" && grim "$f" && notify-send -i "$f" "$1" "$f"`,
            "sh", Tr.t("Screenshot saved")]);
    }
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
        return Quickshell.screens.find(s => s.name === out) ?? screen ?? primary;
    }

    // ~/.config/kriss/shell.json. Missing keys keep the defaults below.
    property alias pinned: config.pinned
    property alias dnd: config.dnd
    property alias mainChosen: config.mainChosen
    property alias sounds: config.sounds
    property alias soundTheme: config.soundTheme

    // Plays a freedesktop sound by its name (message-new-instant, audio-volume-change, ...):
    // the first of the names given found in the sound theme (Ocean unless the user picked
    // another), then in freedesktop's, played with PipeWire's pw-play. libcanberra only if
    // neither has it or pw-play is missing. Quiet when sounds are off.
    function sound(...ids) {
        if (sounds) Quickshell.execDetached(["sh", "-c", `
            theme=$1; shift
            dirs="\${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            for id; do for t in "$theme" freedesktop; do
                IFS=:; for d in $dirs; do unset IFS
                    for f in "$d/sounds/$t/stereo/$id.oga" "$d/sounds/$t/stereo/$id.ogg" "$d/sounds/$t/stereo/$id.wav"; do
                        [ -f "$f" ] || continue
                        # To the default output, as Windows does: WirePlumber otherwise sends every
                        # Notification-role stream where one was last moved (on cachyos-pc, a
                        # headset), which is why canberra was silent in the session.
                        out=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'"' '/node.name =/ { print $2; exit }')
                        command -v pw-play >/dev/null && exec pw-play --media-role=Notification --target="\${out:-auto}" "$f"
                        exec canberra-gtk-play -f "$f"
                    done
                done
            done; done
            exec canberra-gtk-play -i "$1"`, "sh", soundTheme || "ocean", ...ids]);
    }
    // Signing in: once a session, not when the shell comes back after a crash.
    Process {
        id: loginCheck
        command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/kriss-shell-signed-in"; [ -e "$f" ] && exit 1; : > "$f"']
        onExited: code => { if (code === 0) root.sound("desktop-login", "service-login"); }
    }
    // Low battery, as Windows warns: at 15% and again at 5%, once each until it is charged.
    property int batteryWarned: 0
    readonly property real batteryLevel: UPower.displayDevice?.percentage ?? 1
    onBatteryLevelChanged: {
        if (!UPower.onBattery || !UPower.displayDevice?.isLaptopBattery) batteryWarned = 0;
        else if (batteryLevel <= 0.05 && batteryWarned < 2) { batteryWarned = 2; sound("battery-caution", "battery-low", "dialog-warning"); }
        else if (batteryLevel <= 0.15 && batteryWarned < 1) { batteryWarned = 1; sound("battery-low", "dialog-warning"); }
    }
    // The theme for every app too: GTK and canberra read the GNOME setting, KDE apps
    // kdeglobals.
    function syncSound() {
        Quickshell.execDetached(["sh", "-c", `
            gsettings set org.gnome.desktop.sound theme-name "$1"
            gsettings set org.gnome.desktop.sound event-sounds "$2"
            command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kdeglobals --group Sounds --key Theme "$1"
            exit 0`, "sh", soundTheme || "ocean", String(sounds)]);
    }
    onSoundsChanged: syncSound()
    onSoundThemeChanged: syncSound()

    // Plug and unplug: the charger (UPower) and USB devices (udev, one line per device).
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.sound(UPower.onBattery ? "power-unplug" : "power-plug");
            if (!UPower.onBattery) root.batteryWarned = 0;
        }
    }
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device"]
        stdout: SplitParser {
            onRead: line => {
                if (/^UDEV.* add /.test(line)) root.sound("device-added");
                else if (/^UDEV.* remove /.test(line)) root.sound("device-removed");
            }
        }
    }
    property alias quietApps: config.quietApps
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
    property alias taskbarSearch: config.taskbarSearch
    property alias taskbarTransparency: config.taskbarTransparency
    property alias startLayout: config.startLayout
    property alias startRecommended: config.startRecommended
    property alias desktopNames: config.desktopNames
    property alias accent: config.accent
    property alias theme: config.theme
    property alias themeLight: config.themeLight
    property alias themeDark: config.themeDark
    property alias wallpaper: config.wallpaper
    property alias contrast: config.contrast
    property alias transparency: config.transparency
    property alias nightLight: config.nightLight
    property alias layout: config.layout
    property alias cursorTheme: config.cursorTheme
    property alias cursorSize: config.cursorSize
    // The Mac layout: a slim top bar and a centred dock in place of the taskbar (see Bar.qml).
    readonly property bool mac: layout === "mac"
    // What the bars take at the top and bottom of a screen: the taskbar, or the top bar and dock.
    readonly property int topRoom: mac ? Theme.topBarHeight : 0
    readonly property int bottomRoom: mac ? Theme.dockHeight + Theme.dockGap : Theme.barHeight
    // `kriss-shell layout windows|mac`, kriss-welcome and Settings > Personalise > Taskbar.
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
    // The compositor's title bar buttons follow the same GNOME button-layout, live: mirrored
    // to window_buttons in com.system76.CosmicTk, which cosmic-comp-kriss reads.
    Process {
        running: true
        command: ["sh", "-c", `
            put() {
                d=\${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTk/v1
                mkdir -p "$d" && printf '"%s"' "$1" > "$d/.window_buttons.new" && mv -f "$d/.window_buttons.new" "$d/window_buttons"
            }
            put "$(gsettings get org.gnome.desktop.wm.preferences button-layout | tr -d "'")"
            gsettings monitor org.gnome.desktop.wm.preferences button-layout | while read -r _ v; do put "$(printf %s "$v" | tr -d "'")"; done`]
    }
    property alias taskbarWidgets: config.taskbarWidgets
    property alias widgets: config.widgets
    property alias widgetsHidden: config.widgetsHidden
    property alias worldClocks: config.worldClocks
    property alias weatherCity: config.weatherCity
    property alias aiModel: config.aiModel

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
                "firefox", "com.system76.CosmicFiles", "org.krissos.Store", "com.system76.CosmicTerm", "code", "steam",
                "winboat", "thunderbird", "com.github.th_ch.youtube_music", "org.krissos.Settings"
            ]
            // Do not disturb: no toasts, notifications still collect behind the bell.
            property bool dnd: false
            // The user picked the main display in Settings (else cosmic-comp picked it).
            property bool mainChosen: false
            // System sounds (Desktop.sound): on or off, and the freedesktop sound theme
            // (/usr/share/sounds/NAME) they come from. KDE's Ocean by default.
            property bool sounds: true
            property string soundTheme: "ocean"
            // Apps whose notifications go straight to the center, with no pop-up (Settings >
            // Notifications), by the name they send.
            property list<string> quietApps: []
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
            // on the main display, with every window.
            property bool taskbarAllScreens: true
            // "small", "medium" or "large": the bar's height and its icons (Theme.barScale).
            property string taskbarSize: "medium"
            // The Task View button on the taskbar, after Start.
            property bool taskbarTaskView: true
            // Search on the taskbar: "box" (the pill with the word), "icon" or "hidden".
            property string taskbarSearch: "box"
            // How much shows through the taskbar and top bar: "none", "normal" or "more".
            // Only with transparency effects on (Colours).
            property string taskbarTransparency: "normal"
            // Start: "pins" (more rows of pins), "default" or "recommended" (more recent
            // files), and whether Recommended shows at all.
            property string startLayout: "default"
            property bool startRecommended: true
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
            // A warm tint over every screen, kinder to the eyes at night (quick settings).
            property bool nightLight: false
            // "windows": the taskbar along the bottom. "mac": a top bar (the app's menu, the
            // tray, quick settings and the clock) and a centred dock. Switches live.
            property string layout: "windows"
            // The mouse pointer (Theme.qml): a cursor theme's name, or "" for Breeze, dark on
            // the light theme and light on the dark one; and its size in px (24, 32, 48...).
            property string cursorTheme: ""
            property int cursorSize: 24
            // The widgets button at the far left of the taskbar (Windows+W opens the panel either way).
            property bool taskbarWidgets: true
            // The widgets panel: card order, the cards hidden from it, the world clocks (tz
            // names), the city the weather is for, and the local AI model.
            property list<string> widgets: ["calendar", "clocks", "system", "media", "ai", "weather"]
            property list<string> widgetsHidden: []
            property list<string> worldClocks: []
            property string weatherCity: ""
            property string aiModel: ""
            // The lock screen's clock (Settings > Personalise > Lock screen): position top, centre, left or
            // bottom; stack stacked or line; size s, m, l or xl; weight regular, semibold, bold
            // or heavy; font inter-display, rounded, condensed or serif; style glass, solid or
            // outline; the date, the row under it (media, battery, network) and the depth effect;
            // the picture: "desktop" (the background's), "dynamic", "static" or a path.
            property JsonObject lockClock: JsonObject {
                property string wallpaper: "desktop"
                property string position: "top"
                property string stack: "stacked"
                property string size: "l"
                property string weight: "bold"
                property string font: "inter-display"
                property string style: "glass"
                property bool date: true
                property bool widgets: true
                property bool depth: true
            }
        }
    }
    readonly property var lockClock: config.lockClock
    // A copy the login screen can read before anyone signs in (greeter.qml), in the folder
    // kriss-settings makes for it; the login screen shows the clock the way its user set it.
    // The main display goes in it too, for where the login screen shows its field.
    function setLockClock(key, value) {
        config.lockClock[key] = value;
        writeLockCopy();
    }
    Connections {
        target: Displays
        function onPrimaryChanged() { if (Displays.primary) root.writeLockCopy(); }
    }
    function writeLockCopy() {
        const o = config.lockClock, copy = { primary: Displays.primary };
        for (const k of ["position", "stack", "size", "weight", "font", "style", "date", "widgets", "depth"]) copy[k] = o[k];
        Quickshell.execDetached(["sh", "-c", 'd=/var/lib/kriss/lock-clock; [ -w "$d" ] && printf %s "$1" > "$d/.$2.json" && mv -f "$d/.$2.json" "$d/$2.json"',
            "sh", JSON.stringify(copy), Quickshell.env("USER") ?? "user"]);
    }

    // The lock screen's picture: a path, or "" for the time-of-day scene. The background's
    // unless Personalise > Lock screen picks another.
    readonly property string lockPicture: {
        const w = !config.lockClock.wallpaper || config.lockClock.wallpaper === "desktop" ? wallpaper : config.lockClock.wallpaper;
        return w.startsWith("/") ? w : w === "dynamic" ? "" : Theme.wallpapers + "/kriss-" + (Theme.dark ? "dark" : "light") + ".svg";
    }
    // KrissOS's own pictures, wherever they were picked from, and kriss-theme's mask for each:
    // the time-of-day scene ("") is the Sungai Petani photo pair, the plain ones the keris.
    function stockMask(path) {
        if (path === "" || /\/backgrounds\/kriss\/sungai-petani-[a-z]+\.jpg$/.test(path))
            return Theme.wallpapers + "/sungai-petani.mask.png";
        return /\/backgrounds\/kriss\/kriss-[a-z]+\.svg$/.test(path) ? Theme.wallpapers + "/kriss-scene.mask.png" : "";
    }

    // The subject of the lock picture, as a mask, for the lock clock's depth effect: kriss-theme's
    // own for its scene, else one kriss-wallpaper-mask makes (once, in the background, never on
    // the way to locking) for the user's picture. Empty until there is one.
    property string pictureMask: ""
    readonly property string wallpaperMask: stockMask(lockPicture) || pictureMask
    onLockPictureChanged: findMask()
    Component.onCompleted: { findMask(); syncSound(); loginCheck.running = true; }
    function findMask() {
        pictureMask = "";
        if (stockMask(lockPicture) !== "") return;
        maskMaker.command = ["sh", "-c", 'command -v kriss-wallpaper-mask >/dev/null && exec nice kriss-wallpaper-mask --cached "$1"', "sh", lockPicture];
        maskMaker.running = true;
    }
    Process {
        id: maskMaker
        stdout: StdioCollector { onStreamFinished: root.pictureMask = text.trim() }
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

    // The recent files fit to show in Start and the jump lists: local files that are still
    // there, not hidden or in a cache, and not a name that is really a web address or a token
    // (a browser's sign-in callback once showed its access token in Recommended).
    // A folder recorded twice (with and without its closing "/") shows once.
    readonly property var recentShown: recent.filter((f, i) => recentThere[f.href] && fitToShow(f)
        && recent.findIndex(g => pathOf(g) === pathOf(f)) === i)
        .map(f => Object.assign({}, f, { name: pathOf(f).split("/").pop(), folder: recentThere[f.href] === "d" }))
    function pathOf(f) { return decodeURIComponent(f.href.replace(/^file:\/\//, "").replace(/\/$/, "")); }
    function fitToShow(f) {
        if (!f.href.startsWith("file:")) return false;
        const path = pathOf(f), name = path.split("/").pop();
        if (/\/\./.test(path) || path.startsWith(Quickshell.env("HOME") + "/.cache/")) return false;
        if (/[?=&]/.test(name)) return false;
        return !(name.length > 24 && !/\s/.test(name) && !/\.[A-Za-z0-9]{1,5}$/.test(name));
    }
    // Which recent files still exist, by href ("d" for a folder, "f" otherwise), checked in
    // one go whenever the list changes.
    property var recentThere: ({})
    onRecentChanged: {
        recentCheck.files = recent.filter(f => f.href.startsWith("file:")).map(pathOf);
        recentCheck.running = true;
    }
    Process {
        id: recentCheck
        property var files: []
        command: ["sh", "-c", 'for p; do if [ -d "$p" ]; then printf "d%s\\n" "$p"; elif [ -e "$p" ]; then printf "f%s\\n" "$p"; fi; done', "sh"].concat(files)
        stdout: StdioCollector {
            onStreamFinished: {
                const kind = {}, out = {};
                for (const line of text.split("\n")) if (line) kind[line.slice(1)] = line[0];
                for (const f of root.recent) if (f.href.startsWith("file:") && kind[root.pathOf(f)]) out[f.href] = kind[root.pathOf(f)];
                root.recentThere = out;
            }
        }
    }
    // A theme icon for a recent file: its type's own, else its kind's, else a page.
    function mimeIcon(f) {
        if (f.folder || f.mime === "inode/directory" || f.href.endsWith("/")) return "folder";
        const top = f.mime.split("/")[0];
        for (const name of [f.mime.replace("/", "-"), top + "-x-generic"])
            if (f.mime && Quickshell.iconPath(name, true)) return name;
        return "text-x-generic";
    }
    // Where a file is, to tell files of the same name apart: its folder's name ("Home" for home).
    function folderOf(f) {
        const dir = pathOf(f).split("/").slice(0, -1).join("/");
        return dir === Quickshell.env("HOME") ? Tr.t("Home") : dir.split("/").pop() || "/";
    }
    // The first `limit` of `files`, each with `detail`: its folder when another has the same name.
    function withFolders(files, limit) {
        const list = files.slice(0, limit);
        return list.map(f => Object.assign({}, f, {
            detail: list.filter(g => g.name === f.name).length > 1 ? folderOf(f) : "" }));
    }

    // An app's recent files, for its jump list: those it opened, by command or app name.
    function recentFor(entry, limit) {
        if (!entry || !startRecommended) return [];
        const names = [entry.command[0]?.split("/").pop().toLowerCase(), entry.id.toLowerCase(), entry.name.toLowerCase()];
        return withFolders(recentShown.filter(f => f.apps.some(a => a && names.indexOf(a) >= 0)), limit);
    }

    // The person, as Start and the lock screen show them: the full name from the account
    // (GECOS, which kriss-welcome fills in), else the login name; and their picture.
    property string fullName: ""
    readonly property string personName: fullName || (Quickshell.env("USER") ?? "")
    readonly property var faces: [Quickshell.env("HOME") + "/.face", "/var/lib/AccountsService/icons/" + (Quickshell.env("USER") ?? "")]
    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1']
        stdout: StdioCollector { onStreamFinished: root.fullName = text.trim() }
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
