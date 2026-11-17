import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.WindowManager
import Quickshell.Services.SystemTray

// The taskbar: full width along the bottom of each screen, 48 px like Windows 11. Keris launcher, this screen's workspaces, pinned and running
// apps on the left; tray icons, power profile, quick settings (network, volume,
// battery), notifications and the clock on the right.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "kriss-bar"
    // Windows+T puts the keyboard on the app buttons (see focusStep). Otherwise on demand: a
    // surface without the keyboard is never told which modifiers are held, and Shift+click
    // and Ctrl+click need them.
    WlrLayershell.keyboardFocus: kbIndex >= 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    // Maximized and snapped windows stop at the bar.
    exclusiveZone: Theme.barHeight
    color: "transparent"
    // Frosted glass: cosmic-comp blurs what is behind the bar.
    BackgroundEffect.blurRegion: Region { item: body }

    // Pinned apps first, then anything else that has a window open.
    readonly property var apps: {
        const out = [];
        const seen = {};
        // ponytail: no overflow handling; a long pin list just crowds the bar.
        for (const e of Desktop.pinnedEntries()) {
            out.push({ entry: e, appId: e.id });
            seen[e.id.toLowerCase()] = true;
        }
        for (const w of Windows.list) {
            const key = w.appId.toLowerCase();
            if (!key || seen[key]) continue;
            seen[key] = true;
            out.push({ entry: DesktopEntries.heuristicLookup(w.appId), appId: w.appId });
        }
        return out;
    }

    // The app button under the pointer, or null: the one place hover previews hook in.
    property Item previewFor: null
    // The app button the keyboard is on after Windows+T, or -1 when the bar has no keyboard.
    property int kbIndex: -1

    Rectangle {
        id: body
        anchors.fill: parent
        color: Theme.bar

        // Right-click on the bar itself (between the buttons): the taskbar menu, at the pointer.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => { spot.x = mouse.x; bar.barMenu(spot, false); }
            Item { id: spot; width: 1; height: parent.height }
        }

        // Windows+T: arrows move, Enter opens, Shift+Enter opens a new window, the Menu key or
        // Shift+F10 opens the jump list, Esc gives the keyboard back.
        Item {
            id: keys
            focus: true
            Keys.onPressed: event => {
                const n = bar.apps.length, i = bar.kbIndex;
                if (i < 0) return;
                const menuKey = event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier;
                if (menuKey) bar.jumpList(i, true);
                else switch (event.key) {
                case Qt.Key_Left: case Qt.Key_Up: bar.kbIndex = Math.max(0, i - 1); break;
                case Qt.Key_Right: case Qt.Key_Down: bar.kbIndex = Math.min(n - 1, i + 1); break;
                case Qt.Key_Home: bar.kbIndex = 0; break;
                case Qt.Key_End: bar.kbIndex = n - 1; break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                    bar.kbIndex = -1;
                    if (event.modifiers & Qt.ShiftModifier) bar.newWindow(i); else bar.activate(i, false);
                    break;
                case Qt.Key_Escape: bar.kbIndex = -1; break;
                default: return;
                }
                event.accepted = true;
            }
        }

        // A soft rim along the top edge instead of a border.
        Rectangle { width: parent.width; height: 1; color: Theme.rim }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            spacing: 8

            // Keris: opens the launcher, like the Start button.
            MouseArea {
                id: start
                Layout.preferredWidth: Theme.barButton
                Layout.preferredHeight: Theme.barButton
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => mouse.button === Qt.RightButton ? bar.startMenu(false) : bar.toggle("launcherOpen")

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: start.containsMouse || Desktop.launcherOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                // The KrissOS emblem from kriss-theme.
                Image {
                    anchors.centerIn: parent
                    width: Theme.barIcon + 4
                    height: width
                    source: "file:///usr/share/pixmaps/krissos.svg"
                    sourceSize: Qt.size(width * 2, height * 2)
                    scale: parent.pressed ? Theme.pressScale : parent.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                hoverEnabled: true
            }

            // Workspaces: dots, the active one stretched into a cyan pill.
            Row {
                spacing: 6
                Layout.leftMargin: 2
                Repeater {
                    // This screen's workspaces; all of them if the compositor does not say
                    // which screen a workspace is on.
                    readonly property var mine: WindowManager.screenProjection(bar.screen)?.windowsets ?? []
                    model: (mine.length ? mine : WindowManager.windowsets).filter(w => w.shouldDisplay)
                    delegate: MouseArea {
                        required property var modelData
                        width: dot.width
                        height: 20
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData.canActivate) modelData.activate()
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.active ? 22 : 8
                            height: 8
                            radius: 4
                            color: modelData.active ? Theme.accent : (modelData.urgent ? Theme.red : Theme.soft)
                            opacity: modelData.active ? 1 : 0.6
                            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Theme.line }

            Row {
                id: appRow
                spacing: 4
                Repeater {
                    id: appButtons
                    model: bar.apps
                    delegate: AppButton {}
                }
            }

            Item { Layout.fillWidth: true }

            // Tray icons (Steam, Discord...): click to open, right-click for the app's menu.
            Row {
                spacing: 14
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Repeater {
                    model: SystemTray.items
                    delegate: TrayIcon {}
                }
            }

            PowerPill {}

            // Network, volume and battery open quick settings, like on Windows.
            MouseArea {
                id: quick
                implicitWidth: status.implicitWidth + 24
                implicitHeight: Theme.barButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("quickOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: quick.containsMouse || Desktop.quickOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Row {
                    id: status
                    anchors.centerIn: parent
                    spacing: 12
                    NetworkGlyph {}
                    VolumeGlyph {}
                    Battery {}
                }
            }

            MouseArea {
                id: bell
                Layout.preferredWidth: Theme.barButton
                Layout.preferredHeight: Theme.barButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("notificationsOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: bell.containsMouse || Desktop.notificationsOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: Desktop.dnd ? "bellOff" : "bell" }
                Rectangle {
                    visible: Notifs.all.length > 0
                    x: parent.width - width - 4; y: 4
                    width: Math.max(16, count.implicitWidth + 8); height: 16; radius: 8
                    color: Theme.accent
                    Text {
                        id: count
                        anchors.centerIn: parent
                        text: Notifs.all.length
                        color: Theme.accentInk
                        font { family: Theme.sans; pixelSize: 10; weight: Font.Bold }
                    }
                }
            }

            // The clock opens the calendar, as on Windows.
            MouseArea {
                id: clockArea
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: Theme.barButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("calendarOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: clockArea.containsMouse || Desktop.calendarOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Column {
                    id: clockText
                    anchors.centerIn: parent
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    RollingText {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold; features: { "tnum": 1 } }
                    }
                    Text {
                        anchors.right: parent.right
                        text: clock.date.toLocaleString(Qt.locale(), "ddd d MMM")
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: 11 }
                    }
                }
            }

            // Show desktop: the thin strip at the far right edge, as on Windows 11. A click
            // minimizes everything, the next brings it back (Windows+D does the same).
            MouseArea {
                id: sliver
                Layout.preferredWidth: 12
                Layout.fillHeight: true
                Layout.leftMargin: -4
                hoverEnabled: true
                onClicked: Windows.showDesktop()
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 20
                    color: Theme.soft
                    opacity: sliver.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
            }
        }
    }

    // Open or close one of the panels on this bar's screen (closing the others).
    function toggle(panel) {
        const open = !(Desktop[panel] && Desktop.screen === bar.screen);
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = false;
        Desktop.screen = bar.screen;
        Desktop[panel] = open;
    }

    Menu { id: menu }

    // A taskbar button: launch the app, or bring up, minimize or step through its windows.
    function activate(i, cycle) {
        const a = apps[i];
        if (a && !Windows.activateApp(a.appId, cycle)) a.entry?.execute();
    }
    function newWindow(i) { apps[i]?.entry?.execute(); }

    // Windows+T, again to step to the next button.
    function focusStep() {
        kbIndex = apps.length ? (kbIndex + 1) % apps.length : -1;
        keys.forceActiveFocus();
    }

    // The jump list, as on Windows 11: the app's recent files and its own tasks (desktop file
    // actions), then the app (a new window), pin or unpin, and close.
    function jumpList(i, byKeyboard) {
        const a = apps[i], btn = appButtons.itemAt(i);
        if (!a || !btn) return;
        const e = a.entry, wins = Windows.forApp(a.appId), pinId = e?.id ?? a.appId;
        const out = [];
        const files = Desktop.recentFor(e, 8);
        if (files.length) out.push({ header: Tr.t("Recent") });
        for (const f of files)
            out.push({ text: f.name, icon: f.mime === "inode/directory" ? "folder" : f.mime.replace("/", "-"), run: () => bar.openWith(e, f.href) });
        const tasks = e?.actions ?? [];
        if (tasks.length) out.push({ header: Tr.t("Tasks") });
        for (const t of tasks) out.push({ text: t.name, icon: t.icon || e.icon, run: () => t.execute() });
        if (out.length) out.push({ sep: true });
        if (e) out.push({ text: e.name, icon: e.icon, run: () => e.execute() });
        out.push(Desktop.isPinned(pinId)
            ? { text: Tr.t("Unpin from taskbar"), glyph: "unpin", run: () => Desktop.togglePin(pinId) }
            : { text: Tr.t("Pin to taskbar"), glyph: "pin", run: () => Desktop.togglePin(pinId) });
        if (wins.length)
            out.push({ text: wins.length > 1 ? Tr.t("Close all windows") : Tr.t("Close window"), glyph: "close",
                       run: () => wins.forEach(w => Windows.close(w.id)) });
        menu.show(btn, out, byKeyboard);
    }

    // A recent file, in the app whose jump list it is in.
    function openWith(entry, href) {
        const path = href.startsWith("file://") ? decodeURIComponent(href.slice(7)) : href;
        if (entry) Quickshell.execDetached(entry.command.concat([path]));
        else Qt.openUrlExternally(href);
    }

    // The first system monitor installed stands in for Task Manager.
    function taskManager() {
        for (const id of ["io.missioncenter.MissionCenter", "org.gnome.SystemMonitor", "gnome-system-monitor",
                          "org.kde.plasma-systemmonitor", "net.nokyan.Resources"]) {
            const e = DesktopEntries.byId(id);
            if (e) return e;
        }
        return null;
    }

    // Entries that open an app, for the apps that are installed.
    function appEntries(list) {
        return list.map(([id, text]) => [DesktopEntries.byId(id), text]).filter(([e]) => e)
            .map(([e, text]) => ({ text: text, run: () => e.execute() }));
    }

    // Right-click on the Start button, or Windows+X: the power-user menu.
    function startMenu(byKeyboard) {
        const tm = taskManager();
        const settings = "com.system76.CosmicSettings";
        const system = appEntries([[settings + ".Applications", Tr.t("Installed apps")],
                                   [settings + ".Power", Tr.t("Power options")],
                                   [settings + ".About", Tr.t("System")],
                                   [settings + ".Network", Tr.t("Network connections")]]);
        const tools = appEntries([["com.system76.CosmicTerm", Tr.t("Terminal")]]);
        const apps = (tm ? [{ text: Tr.t("Task Manager"), run: () => tm.execute() }] : [])
            .concat(appEntries([[settings, Tr.t("Settings")], ["com.system76.CosmicFiles", Tr.t("Files")]]))
            .concat([{ text: Tr.t("Search"), run: () => bar.toggle("launcherOpen") }]);
        const power = { text: Tr.t("Shut down or sign out"), sub: [
            { text: Tr.t("Sign out"), glyph: "signout", run: () => Qt.quit() },  // the session ends with the shell
            { text: Tr.t("Sleep"), glyph: "sleep", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
            { text: Tr.t("Shut down"), glyph: "power", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
            { text: Tr.t("Restart"), glyph: "restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) }
        ] };
        const out = [];
        for (const group of [system, tools, apps]) if (group.length) out.push(...group, { sep: true });
        out.push(power, { text: Tr.t("Desktop"), run: () => Windows.showDesktop() });
        menu.show(start, out, byKeyboard);
    }

    // Right-click on an empty part of the bar.
    // ponytail: Taskbar settings opens shell.json until a Personalise page exists.
    function barMenu(item, byKeyboard) {
        const tm = taskManager();
        const out = tm ? [{ text: Tr.t("Task Manager"), icon: tm.icon, run: () => tm.execute() }] : [];
        // In a text editor if one is installed: the system's choice for JSON can be anything.
        const editor = ["com.system76.CosmicEdit", "org.gnome.TextEditor", "org.kde.kate", "org.kde.kwrite", "org.xfce.mousepad"]
            .map(id => DesktopEntries.byId(id)).find(e => e) ?? null;
        out.push({ text: Tr.t("Taskbar settings"), glyph: "sun", run: () => bar.openWith(editor, "file://" + Desktop.configFile) });
        menu.show(item, out, byKeyboard);
    }

    component AppButton: MouseArea {
        id: btn
        required property var modelData
        required property int index
        readonly property string pinId: modelData.entry?.id ?? modelData.appId
        readonly property bool pinned: Desktop.isPinned(pinId)
        readonly property var wins: Windows.forApp(modelData.appId)
        readonly property bool front: wins.some(w => w.active && !w.minimized)
        // What the app sent over D-Bus: progress, a badge count, a call for attention.
        readonly property var info: Windows.entries[pinId.toLowerCase()] ?? {}
        readonly property bool urgent: !!info.urgent && !front
        readonly property bool kbFocused: bar.kbIndex === index
        // Drag a pinned app sideways to reorder the pins.
        property real pressX: 0
        property bool dragging: false
        readonly property real step: width + appRow.spacing

        width: Theme.barButton
        height: Theme.barButton
        z: dragging ? 1 : 0
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onContainsMouseChanged: {
            if (containsMouse) bar.previewFor = btn;
            else if (bar.previewFor === btn) bar.previewFor = null;
        }
        // Window coordinates: mouse.x moves with the Translate below, so it would undo the drag.
        onPressed: mouse => { pressX = mapToItem(null, mouse.x, 0).x; dragging = false; }
        onPositionChanged: mouse => {
            const dx = mapToItem(null, mouse.x, 0).x - pressX;
            if (pressed && pinned && pressedButtons & Qt.LeftButton && Math.abs(dx) > 10) dragging = true;
            if (dragging) shift.x = dx;
        }
        onReleased: {
            if (!dragging) return;
            const to = Math.max(0, Math.min(bar.apps.length - 1, index + Math.round(shift.x / step)));
            const target = bar.apps[to];
            Desktop.movePin(pinId, target.entry?.id ?? target.appId);
            shift.x = 0;
        }
        // As on Windows: right-click opens the jump list, Shift+click and middle click open a
        // new window, Ctrl+click steps through the app's windows.
        onClicked: mouse => {
            if (dragging) { dragging = false; return; }
            if (mouse.button === Qt.RightButton) bar.jumpList(index, false);
            else if (mouse.button === Qt.MiddleButton || mouse.modifiers & Qt.ShiftModifier) bar.newWindow(index);
            else bar.activate(index, mouse.modifiers & Qt.ControlModifier);
        }
        transform: Translate { id: shift }

        Rectangle {
            id: face
            anchors.fill: parent
            radius: Theme.barRadius
            // Lit under the pointer and behind the app in front, clear otherwise.
            color: btn.containsMouse ? (btn.front ? Theme.cardHover : Theme.card) : btn.front ? Theme.card : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            border.width: btn.kbFocused ? 2 : 0
            border.color: Theme.accent
            scale: btn.pressed && !btn.dragging ? Theme.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            // Wants attention: a red wash that pulses a few times, then stays until the app is in front.
            Rectangle {
                id: wash
                anchors.fill: parent
                radius: parent.radius
                color: Theme.alpha(Theme.red, 0.4)
                visible: btn.urgent
                SequentialAnimation on opacity {
                    running: btn.urgent
                    loops: 3
                    NumberAnimation { from: 1; to: 0.25; duration: Theme.ms(450); easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 1; duration: Theme.ms(450); easing.type: Easing.InOutSine }
                }
            }
            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.barIcon
                source: Quickshell.iconPath(btn.modelData.entry?.icon ?? btn.modelData.appId, "application-x-executable")
            }
        }
        // A badge count, top right.
        Rectangle {
            visible: !!btn.info["count-visible"] && btn.info.count > 0
            x: parent.width - width - 2; y: 2
            width: Math.max(16, badge.implicitWidth + 8); height: 16; radius: 8
            color: Theme.accent
            Text {
                id: badge
                anchors.centerIn: parent
                text: btn.info.count > 99 ? "99+" : (btn.info.count ?? "")
                color: Theme.accentInk
                font { family: Theme.sans; pixelSize: 10; weight: Font.Bold; features: { "tnum": 1 } }
            }
        }
        // Progress the app reports, along the bottom in place of the running mark.
        Rectangle {
            id: track
            visible: !!btn.info["progress-visible"]
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: parent.width - 12
            height: 3
            radius: 1.5
            color: Theme.line
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, btn.info.progress ?? 0))
                height: parent.height
                radius: parent.radius
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
            }
        }
        // Running: a short mark; in front: a longer accent pill; wants attention: red.
        Rectangle {
            visible: btn.wins.length > 0 && !track.visible
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: btn.front ? 16 : 6
            height: 3
            radius: 1.5
            color: btn.urgent ? Theme.red : btn.front ? Theme.accent : Theme.soft
            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        }
    }
}
