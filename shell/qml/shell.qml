//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

// KrissOS Shell: wallpaper, the taskbar on each screen, the launcher,
// notifications, quick settings, the lock screen and the volume and brightness pop-up.
ShellRoot {
    id: root

    // Open one panel from its key, closing the others: on the main display, where the full
    // taskbar is, as on Windows; Task View on the focused window's screen.
    function toggle(panel) {
        const open = !Desktop[panel];
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = Desktop.taskViewOpen = Desktop.widgetsOpen = false;
        if (open) Desktop.screen = panel === "taskViewOpen" ? Desktop.focusedScreen() : Desktop.primary;
        // In the Mac layout the Start key opens search at the top, where Spotlight is; the dock's
        // Apps button opens the full grid.
        Desktop.launcherSearch = panel === "launcherOpen" && Desktop.mac;
        Desktop[panel] = open;
    }

    // Night light: a warm tint over each screen that clicks pass through.
    // ponytail: an overlay, since cosmic-comp has no gamma or colour-temperature control yet;
    // it tints screenshots too. Move to the compositor's night light when it has one.
    Variants {
        model: Desktop.nightLight ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-night-light"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}
            color: Qt.rgba(1, 0.55, 0.1, 0.13)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallWin
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "kriss-wallpaper"
            // A click on the desktop gives it the keyboard, for the icons' keys.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.night

            readonly property bool dynamic: Desktop.wallpaper === "dynamic"
            Loader {
                anchors.fill: parent
                active: wallWin.dynamic
                sourceComponent: DynamicWallpaper {}
            }
            Image {
                anchors.fill: parent
                // The user's picture, else kriss-theme's wallpaper for the current light or dark theme.
                source: wallWin.dynamic ? "" : Desktop.wallpaper.startsWith("/") ? Desktop.fileUrl(Desktop.wallpaper)
                    : "file://" + Theme.wallpapers + "/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"
                asynchronous: true
                sourceSize: Qt.size(parent.width, parent.height)
                fillMode: Image.PreserveAspectCrop
            }

            // Right-click on the desktop: display settings, personalise, a terminal, as on Windows.
            MouseArea {
                Accessible.ignored: true  // pointer only; the keyboard has its own way
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    spot.x = mouse.x; spot.y = mouse.y;
                    const open = (id, text) => {
                        const e = DesktopEntries.byId(id);
                        return e ? [{ text: text, icon: e.icon, run: () => e.execute() }] : [];
                    };
                    deskMenu.show(spot, [].concat(
                        [{ text: Tr.t("Display settings"), glyph: "display", run: () => SettingsPages.open("display") }],
                        [{ text: Tr.t("Personalise"), glyph: "image", run: () => SettingsPages.open("background") }],
                        [{ sep: true }],
                        open("com.system76.CosmicTerm", Tr.t("Open in Terminal")),
                        [{ text: Tr.t("Settings"), glyph: "settings", run: () => SettingsPages.open("") }]), false);
                }
                Item { id: spot; width: 1; height: 1 }
            }

            // The icons, on the main display as on Windows; the others get the selection box alone.
            DesktopIcons {
                anchors.fill: parent
                showIcons: modelData === Desktop.primary
            }
        }
    }

    Menu { id: deskMenu }

    Variants {
        id: bars
        model: Desktop.taskbarAllScreens ? Quickshell.screens : [Desktop.primary]
        Bar {}
    }

    // The bar on the focused window's screen, for the taskbar keys.
    function bar() {
        const s = Desktop.focusedScreen();
        return bars.instances.find(b => b.screen === s) ?? bars.instances[0];
    }

    Launcher {}
    Notifications {}
    QuickSettings {}
    Calendar {}
    Widgets {}
    Lock {}
    Switcher { id: switcher }
    TaskView {}
    Snap { id: snapLayouts }
    Clipboard { id: clipboard }
    Osd {}
    Settings {}
    DisplaySwitch { id: project }
    Snip { id: snip }

    // KRISS_SHELL_FPS=1: for a second after a panel opens or closes, counts the frames and
    // logs the rate and the slowest frame (read it with `qs log`), to check motion on real hardware.
    FrameAnimation {
        id: fps
        readonly property bool wanted: Quickshell.env("KRISS_SHELL_FPS") === "1"
        property string what
        property real worst: 0
        onTriggered: worst = Math.max(worst, frameTime)
        function measure(name) {
            if (!wanted) return;
            what = name; worst = 0;
            reset(); start(); fpsDone.restart();
        }
    }
    Timer {
        id: fpsDone
        interval: 1000
        onTriggered: {
            fps.stop();
            console.log("fps:", fps.what, Math.round(fps.currentFrame / fps.elapsedTime), "fps,",
                fps.currentFrame, "frames, slowest", Math.round(fps.worst * 1000), "ms");
        }
    }
    Connections {
        target: Desktop
        function onLauncherOpenChanged() { fps.measure("launcher " + (Desktop.launcherOpen ? "open" : "close")); }
        function onQuickOpenChanged() { fps.measure("quick " + (Desktop.quickOpen ? "open" : "close")); }
        function onNotificationsOpenChanged() { fps.measure("notifications " + (Desktop.notificationsOpen ? "open" : "close")); }
        function onTaskViewOpenChanged() { fps.measure("taskview " + (Desktop.taskViewOpen ? "open" : "close")); }
        function onWidgetsOpenChanged() { fps.measure("widgets " + (Desktop.widgetsOpen ? "open" : "close")); }
        // Locking closes what is open, as on Windows; nothing is left to come back, or to act, after.
        function onLockedChanged() {
            if (!Desktop.locked) return;
            Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = Desktop.taskViewOpen = Desktop.widgetsOpen = false;
            switcher.finish(false);
            if (clipboard.open) clipboard.close();
            snapLayouts.closePicker();
            snapLayouts.closeAssist();
        }
    }

    // cosmic-comp runs `kriss-shell COMMAND` for the Windows-key shortcuts, which calls these.
    // `kriss-shell launcher|quick|notifications`: Windows, Windows+A and Windows+N; `calendar`: Windows+Alt+D; `widgets`: Windows+W.
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle("launcherOpen"); }
    }

    IpcHandler {
        target: "quick"
        function toggle(): void { root.toggle("quickOpen"); }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.toggle("notificationsOpen"); }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { root.toggle("calendarOpen"); }
    }

    // Windows+W.
    IpcHandler {
        target: "widgets"
        function toggle(): void { root.toggle("widgetsOpen"); }
    }

    IpcHandler {
        target: "desktop"
        function toggle(): void { Windows.showDesktop(); }
    }

    // `kriss-shell taskview`: Windows+Tab. `kriss-shell desktops new|close`: Windows+Ctrl+D and
    // Windows+Ctrl+F4, on the focused window's screen.
    IpcHandler {
        target: "taskview"
        function toggle(): void { root.toggle("taskViewOpen"); }
    }

    IpcHandler {
        target: "desktops"
        function add(): void { Windows.newDesktop(Desktop.focusedScreen().name); }
        function close(): void {
            const d = Windows.desktopsOn(Desktop.focusedScreen().name).find(d => d.active);
            if (d) Windows.closeDesktop(d.id);
        }
    }

    // `kriss-shell taskbar ACTION [N]`: Windows+T steps through the app buttons, Windows+B goes
    // to the tray, Windows+1…9
    // opens or switches to the Nth app, Windows+Shift+1…9 opens a new window of it,
    // Windows+Alt+1…9 opens its jump list, Windows+X the Start button's menu.
    IpcHandler {
        target: "taskbar"
        function focus(): void {
            const b = root.bar();
            for (const o of bars.instances) if (o !== b) o.kb = false;
            b.focusStep();
        }
        // Windows+B: the tray, on the main display's bar.
        function tray(): void {
            const b = bars.instances.find(o => o.screen === Desktop.primary) ?? root.bar();
            for (const o of bars.instances) if (o !== b) o.kb = false;
            b.focusTray();
        }
        function open(n: int): void { root.bar().activate(n - 1, false); }
        function newWindow(n: int): void { root.bar().newWindow(n - 1); }
        function jumpList(n: int): void { root.bar().jumpList(n - 1, true); }
        function startMenu(): void { root.bar().startMenu(true); }
    }

    // `kriss-shell snap`: Windows+Z, the snap layouts for the window in front.
    IpcHandler {
        target: "snap"
        function layouts(): void { snapLayouts.layoutsForActive(); }
    }

    // `kriss-shell clipboard` and `kriss-shell emoji`: Windows+V and Windows+.
    IpcHandler {
        target: "clipboard"
        function history(): void { clipboard.show("clipboard"); }
        function emoji(): void { clipboard.show("emoji"); }
    }

    // `qs ipc call theme set accent "#24B1E6"`, `qs ipc call theme set mode auto`.
    IpcHandler {
        target: "theme"
        function set(key: string, value: string): string { return Theme.set(key, value); }
    }

    // `kriss-shell settings [PAGE]`: the Settings window at a page (SettingsPages.qml has
    // their ids: display, sound, colours, taskbar...). `kriss-shell personalise [PAGE]` opens
    // Personalise, at colours unless another of its pages is named.
    IpcHandler {
        target: "settings"
        function open(page: string): void { SettingsPages.open(page); }
    }
    // `kriss-shell project`: Windows+P.
    IpcHandler {
        target: "project"
        function toggle(): void { project.toggle(); }
    }
    // `kriss-shell screenshot region` (Windows+Shift+S) and `kriss-shell record` (Windows+Alt+R).
    IpcHandler {
        target: "snip"
        function toggle(): void { snip.toggle(); }
        function record(): void { Desktop.record(); }
    }
    IpcHandler {
        target: "personalise"
        function open(page: string): void { SettingsPages.open(SettingsPages.find(page)?.group === "personalise" ? page : "colours"); }
    }

    // `kriss-shell layout windows|mac`: the taskbar, or the top bar and dock. Saved to shell.json.
    IpcHandler {
        target: "layout"
        function set(name: string): string { return Desktop.setLayout(name); }
        function get(): string { return Desktop.layout; }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Desktop.locked = true; }
    }

    IpcHandler {
        target: "switcher"
        function next(): void { switcher.step(1); }
        function previous(): void { switcher.step(-1); }
    }

    // The media keys.
    IpcHandler {
        target: "media"
        function playPause(): void { if (Desktop.player?.canTogglePlaying) Desktop.player.togglePlaying(); }
        function next(): void { if (Desktop.player?.canGoNext) Desktop.player.next(); }
        function previous(): void { if (Desktop.player?.canGoPrevious) Desktop.player.previous(); }
    }

    // Low battery, as on Windows: a warning at 10% and again at 5%, while it isn't charging.
    // Critical, so it shows through Do not disturb.
    Connections {
        target: UPower.displayDevice
        property int warned: 100
        function onPercentageChanged() {
            const dev = UPower.displayDevice, pct = Math.round(dev.percentage * 100);
            if (!dev.isLaptopBattery || !UPower.onBattery) { warned = 100; return; }
            const level = pct <= 5 ? 5 : pct <= 10 ? 10 : 100;
            if (level >= warned) return;
            warned = level;
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", Tr.t("Battery"), "-i", "battery-caution",
                Tr.t("Battery low: %1%", pct), Tr.t("Plug in the charger soon.")]);
        }
    }
}
