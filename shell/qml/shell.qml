//@ pragma IconTheme {{icon_theme}}
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

    // Open one panel on the focused window's screen, closing the others.
    function toggle(panel) {
        const open = !Desktop[panel];
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = Desktop.taskViewOpen = Desktop.widgetsOpen = false;
        if (open) Desktop.screen = Desktop.focusedScreen();
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
                    const s = "com.system76.CosmicSettings";
                    deskMenu.show(spot, [].concat(
                        open(s + ".Displays", Tr.t("Display settings")),
                        [{ text: Tr.t("Personalise"), glyph: "image", run: () => Desktop.personalise("background") }],
                        [{ sep: true }],
                        open("com.system76.CosmicTerm", Tr.t("Open in Terminal")),
                        open(s, Tr.t("Settings"))), false);
                }
                Item { id: spot; width: 1; height: 1 }
            }

            // The icons, on the first screen as on Windows; the others get the selection box alone.
            DesktopIcons {
                anchors.fill: parent
                showIcons: modelData === Quickshell.screens[0]
            }
        }
    }

    Menu { id: deskMenu }

    Variants {
        id: bars
        model: Desktop.taskbarAllScreens ? Quickshell.screens : Quickshell.screens.slice(0, 1)
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
    Personalise {}

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
        // Windows+B: the tray.
        function tray(): void {
            const b = root.bar();
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

    // `kriss-shell personalise [colours|background|taskbar|pins|text]`: the Personalise window.
    IpcHandler {
        target: "personalise"
        function open(page: string): void { Desktop.personalise(page); }
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
