import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.WindowManager
import Quickshell.Services.SystemTray

// The taskbar: full width along the bottom of each screen, 48 px like Windows 11. Widgets, Keris launcher,
// the search box, this screen's workspaces and the pinned and running apps on the left (or centred);
// tray icons, power profile, quick settings (network, volume, battery), notifications and the
// clock on the right. Options come from shell.json (see Desktop.qml).
// The Mac layout ("layout": "mac") uses the same buttons and logic in another shape: the
// launcher and the apps in a centred dock along the bottom, and a slim top bar (the inline
// window `top` below) with the system menu, the app in front, the tray, quick settings,
// notifications and the clock, which move up there from the right of the taskbar.
PanelWindow {
    id: bar
    readonly property bool mac: Desktop.mac

    required property var modelData
    screen: modelData
    // Gone while a fullscreen window is in front on this screen, as on Windows.
    visible: !Windows.fullscreenOn(modelData)

    WlrLayershell.namespace: "kriss-bar"
    // On demand: a surface without the keyboard is never told which modifiers are held, and
    // Shift+click and Ctrl+click need them. Windows+T and Windows+B put the keyboard on the bar
    // through Desktop.keysTo (see focusStep).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { bottom: true; left: true; right: true }
    // The dock floats a little above the screen's edge.
    implicitHeight: mac ? Theme.dockHeight + Theme.dockGap : Theme.barHeight
    // The size of a button and its icon: the taskbar's, or the dock's bigger ones.
    readonly property int button: mac ? Theme.dockButton : Theme.barButton
    readonly property int icon: mac ? Theme.dockIcon : Theme.barIcon
    // Maximized and snapped windows stop at the bar, unless it auto-hides.
    exclusiveZone: Desktop.taskbarAutoHide ? 0 : implicitHeight
    color: "transparent"
    // Frosted glass: cosmic-comp blurs what is behind the bar.
    BackgroundEffect.blurRegion: Region { item: body; radius: body.radius }

    // This bar's windows: the ones on its screen, when every screen has a bar.
    readonly property var wins: Desktop.taskbarAllScreens
        ? Windows.list.filter(w => !w.output || w.output === bar.screen?.name) : Windows.list

    // Pinned apps first, then anything else that has a window open: one button per app.
    readonly property var groups: {
        const out = [];
        const seen = {};
        for (const e of Desktop.pinnedEntries()) {
            out.push({ entry: e, appId: e.id });
            seen[e.id.toLowerCase()] = true;
        }
        for (const w of wins) {
            const key = w.appId.toLowerCase();
            if (!key || seen[key]) continue;
            seen[key] = true;
            out.push({ entry: DesktopEntries.heuristicLookup(w.appId), appId: w.appId });
        }
        return out;
    }
    // Uncombined: a labelled button per window, in place of its app's.
    readonly property var loose: {
        const out = [];
        for (const g of groups) {
            const ws = Windows.forApp(g.appId, wins);
            if (ws.length === 0) out.push(g);
            for (const w of ws) out.push({ entry: g.entry, appId: g.appId, win: w });
        }
        return out;
    }
    // The room for app buttons, left of the tray.
    readonly property real room: right.x - appRow.x - 16
    // What the uncombined buttons need at full width.
    readonly property real looseWidth: loose.reduce((sum, a) => sum + (a.win ? 168 : Theme.barButton) + appRow.spacing, 0)
    // The dock always combines, as on a Mac.
    readonly property bool combined: mac || (Desktop.taskbarCombine === "full" ? looseWidth > room : Desktop.taskbarCombine !== "never")
    // Labelled buttons shrink to fit, as on Windows.
    // ponytail: at 96 px they stop shrinking and run into the tray; scroll them if that matters.
    readonly property real labelWidth: {
        const labels = loose.filter(a => a.win).length;
        const icons = (loose.length - labels) * (Theme.barButton + appRow.spacing);
        return Math.max(96, Math.min(168, (room - icons) / Math.max(1, labels) - appRow.spacing));
    }
    // ponytail: combined buttons have no overflow handling; a long pin list just crowds the bar.
    readonly property var apps: combined ? groups : loose

    // Auto-hide: the bar slides off the bottom edge and comes back when the pointer reaches it,
    // and stays while its menu, one of its panels or the keyboard (Windows+T) is on it.
    readonly property bool near: hover.hovered || edgeHover.hovered
    onNearChanged: if (!near) linger.restart()
    Timer { id: linger; interval: 600 }
    readonly property bool tucked: Desktop.taskbarAutoHide && !near && !linger.running && !menu.visible && !kb
        && !((Desktop.launcherOpen || Desktop.quickOpen || Desktop.notificationsOpen || Desktop.calendarOpen) && Desktop.screen === bar.screen)
    // Clicks beside the dock go through to the windows behind.
    mask: tucked ? edgeRegion : mac ? dockRegion : null
    Region { id: edgeRegion; item: edge }
    Region { id: dockRegion; item: body }
    Item {
        id: edge
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        HoverHandler { id: edgeHover }
    }

    // The app button under the pointer, or null: the one place hover previews hook in.
    property Item previewFor: null
    // The bar has the keyboard (Windows+T, Windows+B): Tab, Shift+Tab and the arrows walk
    // every control in reading order, Esc gives the keyboard back.
    property bool kb: false
    // Which of the bar's windows has it: the taskbar or dock (body), or the Mac top bar.
    property Item kbOn: body
    function takeKeys(on) {
        if (kb && kbOn !== on) kb = false;
        kbOn = on;
        kb = true;
    }
    // Giving the keyboard back also takes the focus off the controls, so no rim stays lit.
    onKbChanged: {
        if (kb) { Desktop.keysTo(kbOn); return; }
        returnTo = null;
        body.forceActiveFocus();
        topBody.forceActiveFocus();
        if ([body, topBody].some(b => Desktop.keysFor === b || Desktop.keysNext === b)) Desktop.keysTo(null);
    }
    // The control that opened a panel from the keyboard: Esc in that panel comes back to it.
    property Item returnTo: null
    readonly property bool anyOpen: Desktop.launcherOpen || Desktop.quickOpen || Desktop.notificationsOpen
        || Desktop.calendarOpen || Desktop.taskViewOpen
    // A panel takes the keyboard from the bar; Esc in it can bring it back (backOut).
    onAnyOpenChanged: if (anyOpen) kb = false; else returnTo = null
    Connections {
        target: Desktop
        function onBackOut() {
            if (!bar.returnTo) return;
            bar.kb = true;
            bar.returnTo.forceActiveFocus();
            bar.returnTo = null;
        }
    }

    // Keys any control on the bar leaves alone: arrows, Home and End move along the bar,
    // Esc gives the keyboard back. Tab and Shift+Tab follow Qt's focus chain, which stays in
    // the window `on` is in (the taskbar or dock, or the Mac top bar).
    function barKeys(event, on) {
        const f = on.Window.activeFocusItem;
        if (!kb || !f) return;
        const last = on === topBody ? clockArea : mac ? appButtons.itemAt(appButtons.count - 1) ?? start : sliver;
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_Up: case Qt.Key_Backtab: f.nextItemInFocusChain(false).forceActiveFocus(); break;
        case Qt.Key_Right: case Qt.Key_Down: f.nextItemInFocusChain(true).forceActiveFocus(); break;
        case Qt.Key_Tab: f.nextItemInFocusChain(!(event.modifiers & Qt.ShiftModifier)).forceActiveFocus(); break;
        case Qt.Key_Home: (on === topBody ? system : start).forceActiveFocus(); break;
        case Qt.Key_End: last.forceActiveFocus(); break;
        case Qt.Key_Escape: kb = false; break;
        // On a control with no menu of its own: the taskbar's menu, as a right-click on the bar.
        case Qt.Key_Menu: barMenu(f, true); break;
        case Qt.Key_F10: if (event.modifiers & Qt.ShiftModifier) barMenu(f, true); else return; break;
        default: return;
        }
        event.accepted = true;
    }

    // The taskbar, or in the Mac layout the dock: as wide as its buttons, centred, floating.
    Rectangle {
        id: body
        width: bar.mac ? tasks.width + 16 : parent.width
        height: bar.mac ? Theme.dockHeight : Theme.barHeight
        x: (parent.width - width) / 2
        y: bar.tucked ? parent.height : 0
        Behavior on y { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        radius: bar.mac ? Theme.rPanel : 0
        color: Theme.bar
        border.width: bar.mac ? Theme.rimWidth : 0
        border.color: Theme.rim
        HoverHandler { id: hover }
        Accessible.role: Accessible.ToolBar
        Accessible.name: bar.mac ? Tr.t("Dock") : Tr.t("Taskbar")
        Keys.onPressed: event => bar.barKeys(event, body)

        // Right-click on the bar itself (between the buttons): the taskbar menu, at the pointer.
        MouseArea {
            Accessible.ignored: true  // pointer only; the keyboard has its own way
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => { spot.x = mouse.x; bar.barMenu(spot, false); }
            Item { id: spot; width: 1; height: parent.height }
        }

        // A soft rim along the top edge instead of a border.
        Rectangle { visible: !bar.mac; width: parent.width; height: Theme.rimWidth; color: Theme.rim }

        // Start, search, workspaces and apps: at the left edge, or centred on the bar as on
        // Windows 11, but never running into the tray.
        RowLayout {
            id: tasks
            x: bar.mac ? 8 : Desktop.taskbarAlignment === "centre" ? Math.max(4, Math.min((bar.width - width) / 2, right.x - width - 8)) : 4
            height: parent.height
            spacing: Theme.s2

            // Widgets, at the far left as on Windows 11 (`taskbarWidgets` in shell.json hides it).
            MouseArea {
                id: widgetsBtn
                visible: Desktop.taskbarWidgets
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Widgets")
                Layout.preferredWidth: bar.button
                Layout.preferredHeight: bar.button
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("widgetsOpen")
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rControl
                    color: widgetsBtn.containsMouse || Desktop.widgetsOpen && Desktop.screen === bar.screen ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: "widgets"; size: bar.mac ? Math.round(bar.icon * 0.6) : 20 }
            }

            // Keris: opens the launcher, like the Start button.
            BarButton {
                id: start
                lit: Desktop.launcherOpen && !Desktop.launcherSearch && Desktop.screen === bar.screen
                name: bar.mac ? Tr.t("Apps") : Tr.t("Start")
                tip: Tr.t("Apps, files and settings. Right-click or the Menu key for more.")
                hasMenu: true
                onActivated: bar.toggle("launcherOpen", false, start)
                onMenuAsked: byKeyboard => bar.startMenu(byKeyboard, start)
                // The KrissOS emblem from kriss-theme; in the dock, a grid of apps (the emblem
                // is the system menu in the top bar).
                Layout.preferredWidth: bar.button
                Layout.preferredHeight: bar.button
                Glyph { visible: bar.mac; anchors.centerIn: parent; name: "apps"; size: Math.round(bar.icon * 0.6) }
                Image {
                    visible: !bar.mac
                    anchors.centerIn: parent
                    width: Theme.barIcon + 4
                    height: width
                    source: "file:///usr/share/pixmaps/krissos.svg"
                    sourceSize: Qt.size(width * 2, height * 2)
                    scale: parent.containsMouse && !parent.pressed ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
            }

            // The search box: opens Start ready to search.
            BarButton {
                id: searchBox
                visible: !bar.mac
                Layout.preferredWidth: Math.max(200, searchRow.implicitWidth + 24)
                Layout.preferredHeight: Theme.barButton - 8
                radius: height / 2
                lit: true
                boxed: true
                litColor: containsMouse || Desktop.launcherOpen && Desktop.launcherSearch && Desktop.screen === bar.screen ? Theme.cardHover : Theme.card
                name: Tr.t("Search")
                onActivated: bar.toggle("launcherOpen", true, searchBox)
                Row {
                    id: searchRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: Theme.s2
                    Glyph { anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; color: Theme.soft }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.t("Search")
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(13) }
                    }
                }
            }

            // Task View, as on Windows 11 (Windows+Tab). `taskbarTaskView` in shell.json hides it.
            BarButton {
                id: taskView
                visible: Desktop.taskbarTaskView && !bar.mac
                lit: Desktop.taskViewOpen && Desktop.screen === bar.screen
                name: Tr.t("Task View")
                tip: Tr.t("Your windows and desktops")
                onActivated: bar.toggle("taskViewOpen", false, taskView)
                Glyph { anchors.centerIn: parent; name: "taskView"; size: 22 }
            }

            // Workspaces: dots, the active one stretched into a cyan pill.
            Row {
                visible: !bar.mac
                spacing: Theme.s1
                Layout.leftMargin: Theme.s0
                Repeater {
                    // This screen's workspaces; all of them if the compositor does not say
                    // which screen a workspace is on.
                    readonly property var mine: WindowManager.screenProjection(bar.screen)?.windowsets ?? []
                    model: (mine.length ? mine : WindowManager.windowsets).filter(w => w.shouldDisplay)
                    delegate: BarButton {
                        id: ws
                        required property var modelData
                        required property int index
                        width: dot.width
                        height: 20
                        litColor: "transparent"
                        name: Desktop.desktopNames[index] || Tr.t("Desktop %1", index + 1)
                        role: Accessible.RadioButton
                        checked: modelData.active
                        onActivated: if (modelData.canActivate) modelData.activate()
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.active ? 22 : 8
                            height: 8
                            radius: height / 2
                            color: modelData.active ? Theme.accentText : (modelData.urgent ? Theme.red : Theme.soft)
                            opacity: modelData.active ? 1 : 0.6
                            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: Theme.rimWidth; Layout.preferredHeight: 20; color: Theme.line }

            Row {
                id: appRow
                spacing: Theme.s1
                Repeater {
                    id: appButtons
                    model: bar.apps
                    delegate: AppButton {}
                }
            }
        }

        // In the Mac layout these move up to the top bar.
        RowLayout {
            id: right
            parent: bar.mac ? topBody : body
            anchors.right: parent.right
            anchors.rightMargin: bar.mac ? 6 : 0
            height: parent.height
            spacing: bar.mac ? Theme.s1 : Theme.s2

            // Tray icons (Steam, Discord...): click to open, right-click for the app's menu.
            // The ^ opens the overflow flyout with the hidden ones; drag an icon onto the ^, or
            // up off the bar, to hide it there. The ^ shows when something is hidden or dragged.
            BarButton {
                id: more
                property bool dragging: false
                readonly property bool open: overflow.visible && overflow.screen === bar.screen
                visible: dragging || SystemTray.items.values.some(i => Desktop.isTrayHidden(i.id))
                Layout.preferredWidth: 28
                lit: open || dragging
                name: Tr.t("Show hidden icons")
                onActivated: open ? overflow.close() : overflow.show(bar.screen, mapToItem(null, width / 2, 0).x, activeFocus)
                Glyph { anchors.centerIn: parent; name: more.open ? "down" : "up"; size: 16 }
            }
            Row {
                id: trayRow
                spacing: Theme.s3
                Layout.rightMargin: Theme.s1
                Repeater {
                    model: SystemTray.items
                    delegate: TrayIcon {
                        visible: !Desktop.isTrayHidden(modelData.id)
                        appMenu: menu
                        onDraggingChanged: more.dragging = dragging
                        onDropped: (x, y) => {
                            const p = more.mapFromItem(null, x, y);
                            if (y < 0 || more.contains(p)) Desktop.setTrayHidden(modelData.id, true);
                        }
                    }
                }
            }

            PowerPill {}

            // Network, volume and battery open quick settings, like on Windows.
            BarButton {
                id: quick
                Layout.preferredWidth: status.implicitWidth + 24
                lit: Desktop.quickOpen && Desktop.screen === bar.screen
                name: Tr.t("Quick settings")
                tip: [network.label, volume.label, battery.visible ? battery.label : ""].filter(s => s).join(", ")
                onActivated: bar.toggle("quickOpen", false, quick)
                Row {
                    id: status
                    anchors.centerIn: parent
                    spacing: Theme.s3
                    NetworkGlyph { id: network }
                    VolumeGlyph { id: volume }
                    Battery { id: battery }
                }
            }

            BarButton {
                id: bell
                lit: Desktop.notificationsOpen && Desktop.screen === bar.screen
                name: Tr.t("Notifications")
                tip: (Notifs.unseen ? Tr.t("%1 new notifications", Notifs.unseen) : Tr.t("No new notifications"))
                    + (Desktop.dnd ? ", " + Tr.t("Do not disturb is on") : "")
                onActivated: bar.toggle("notificationsOpen", false, bell)
                Glyph { anchors.centerIn: parent; name: Desktop.dnd ? "bellOff" : "bell" }
                // New since the center was last open: a count in the button's corner, clear
                // of the bell; a dot past 9.
                Rectangle {
                    readonly property bool dot: Notifs.unseen > 9
                    visible: Notifs.unseen > 0
                    x: parent.width - width - (dot ? 7 : 2); y: dot ? 7 : 2
                    width: dot ? 8 : Math.max(14, count.implicitWidth + 6); height: dot ? 8 : Math.max(14, count.implicitHeight)
                    radius: height / 2
                    color: Theme.accent
                    Text {
                        id: count
                        visible: !parent.dot
                        anchors.centerIn: parent
                        text: Notifs.unseen
                        color: Theme.accentInk
                        font { family: Theme.sans; pixelSize: Theme.sp(10); weight: Font.Bold }
                    }
                }
            }

            // The clock opens the calendar, as on Windows.
            BarButton {
                id: clockArea
                Layout.preferredWidth: clockText.implicitWidth + 20
                lit: Desktop.calendarOpen && Desktop.screen === bar.screen
                name: Qt.formatDateTime(clock.date, "HH:mm") + ", " + clock.date.toLocaleString(Qt.locale(), "dddd d MMMM yyyy")
                tip: Tr.t("Calendar")
                onActivated: bar.toggle("calendarOpen", false, clockArea)
                // Two lines on the taskbar; one in the top bar, the date before the time.
                Grid {
                    id: clockText
                    anchors.centerIn: parent
                    columns: bar.mac ? 2 : 1
                    columnSpacing: Theme.s2
                    layoutDirection: bar.mac ? Qt.RightToLeft : Qt.LeftToRight
                    horizontalItemAlignment: Grid.AlignRight
                    verticalItemAlignment: Grid.AlignVCenter
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    RollingText {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
                    }
                    Text {
                        text: clock.date.toLocaleString(Qt.locale(), "ddd d MMM")
                        color: bar.mac ? Theme.fg : Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(11) }
                    }
                }
            }

            // Show desktop: the thin strip at the far right edge, as on Windows 11. A click
            // minimizes everything, the next brings it back (Windows+D does the same).
            BarButton {
                id: sliver
                visible: !bar.mac
                Layout.preferredWidth: 12
                Layout.fillHeight: true
                Layout.leftMargin: -4
                litColor: "transparent"
                cursorShape: Qt.ArrowCursor
                name: Tr.t("Show desktop")
                onActivated: Windows.showDesktop()
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 20
                    color: Theme.soft
                    opacity: sliver.containsMouse || sliver.activeFocus ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
            }
        }
    }

    // Open or close one of the panels on this bar's screen (closing the others). search: Start
    // from the search box, which switches to plain Start (and back) rather than closing.
    // from: the control that did it from the keyboard, which Esc in the panel comes back to.
    function toggle(panel, search, from) {
        const open = !(Desktop[panel] && Desktop.screen === bar.screen && Desktop.launcherSearch === !!search);
        if (open && from?.activeFocus && kb) { kb = false; returnTo = from; }
        Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = Desktop.taskViewOpen = Desktop.widgetsOpen = false;
        Desktop.screen = bar.screen;
        Desktop.launcherSearch = !!search;
        Desktop[panel] = open;
    }

    Menu { id: menu }
    Previews { id: previews; screen: bar.screen }
    onPreviewForChanged: previews.hover(previewFor)
    TrayFlyout { id: overflow; appMenu: menu }

    // The app in front on this bar's screen, for the Mac top bar's app menu.
    readonly property var frontApp: groups.find(g => Windows.forApp(g.appId, wins).some(w => w.active && !w.minimized)) ?? null

    // The Mac layout's top bar: the KrissOS emblem with the system menu and the name of the
    // app in front with its menu (the same one its dock icon has) on the left; the right of
    // the taskbar (`right`, reparented) on the right.
    PanelWindow {
        id: top
        screen: bar.screen
        visible: bar.mac && bar.visible
        WlrLayershell.namespace: "kriss-topbar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.topBarHeight
        exclusiveZone: Theme.topBarHeight
        color: "transparent"
        BackgroundEffect.blurRegion: Region { item: topBody }

        Rectangle {
            id: topBody
            anchors.fill: parent
            color: Theme.bar
            Accessible.role: Accessible.ToolBar
            Accessible.name: Tr.t("Top bar")
            Keys.onPressed: event => bar.barKeys(event, topBody)
            MouseArea {
                Accessible.ignored: true  // pointer only; the keyboard has its own way
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse => { topSpot.x = mouse.x; bar.barMenu(topSpot, false); }
                Item { id: topSpot; width: 1; height: parent.height }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.rimWidth; color: Theme.rim }

            RowLayout {
                x: 6
                height: parent.height
                spacing: Theme.s0
                BarButton {
                    id: system
                    name: Tr.t("System menu")
                    tip: Tr.t("Settings, power and more")
                    onActivated: bar.startMenu(activeFocus, system)
                    Image {
                        anchors.centerIn: parent
                        width: Theme.topBarHeight - 12
                        height: width
                        source: "file:///usr/share/pixmaps/krissos.svg"
                        sourceSize: Qt.size(width * 2, height * 2)
                    }
                }
                BarButton {
                    id: appName
                    visible: !!bar.frontApp
                    Layout.preferredWidth: appText.implicitWidth + 20
                    name: appText.text
                    tip: Tr.t("App menu")
                    onActivated: bar.appMenu(bar.frontApp, appName, activeFocus)
                    Text {
                        id: appText
                        anchors.centerIn: parent
                        text: bar.frontApp?.entry?.name ?? bar.frontApp?.appId ?? ""
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
                    }
                }
            }
        }
    }

    // A taskbar button: launch the app, or bring up, minimize or step through its windows.
    function activate(i, cycle) {
        const a = apps[i];
        if (a?.win) Windows.toggleWindow(a.win, cycle);
        else if (a && !Windows.activateApp(a.appId, cycle, wins)) a.entry?.execute();
    }
    function newWindow(i) { apps[i]?.entry?.execute(); }

    // Windows+T: the keyboard on the first app button, again to step to the next one.
    function focusStep() {
        const n = apps.length;
        let i = -1;
        for (let j = 0; j < n; j++) if (appButtons.itemAt(j)?.activeFocus) i = j;
        takeKeys(body);
        (n ? appButtons.itemAt((i + 1) % n) : start).forceActiveFocus();
    }
    // Windows+B: the keyboard on the tray, the ^ first, as on Windows.
    function focusTray() {
        takeKeys(mac ? topBody : body);
        const icons = [];
        for (const c of trayRow.children) if (c.visible && c.activeFocusOnTab) icons.push(c);
        (more.visible ? more : icons[0] ?? quick).forceActiveFocus();
    }

    // The jump list, as on Windows 11: the app's recent files and its own tasks (desktop file
    // actions), then the app (a new window), pin or unpin, and close.
    function jumpList(i, byKeyboard) {
        if (apps[i] && appButtons.itemAt(i)) appMenu(apps[i], appButtons.itemAt(i), byKeyboard);
    }
    // The jump list of app `a` (an entry of `groups` or `apps`), at control `btn`.
    function appMenu(a, btn, byKeyboard) {
        const e = a.entry, wins = a.win ? [a.win] : Windows.forApp(a.appId, bar.wins), pinId = e?.id ?? a.appId;
        const out = [];
        const files = Desktop.recentFor(e, 8);
        if (files.length) out.push({ header: Tr.t("Recent") });
        for (const f of files)
            out.push({ text: f.name, detail: f.detail, icon: Desktop.mimeIcon(f), run: () => bar.openWith(e, f.href) });
        const tasks = e?.actions ?? [];
        if (tasks.length) out.push({ header: Tr.t("Tasks") });
        for (const t of tasks) out.push({ text: t.name, icon: t.icon || e.icon, run: () => t.execute() });
        if (out.length) out.push({ sep: true });
        if (e) out.push({ text: e.name, icon: e.icon, run: () => e.execute() });
        out.push(Desktop.isPinned(pinId)
            ? { text: mac ? Tr.t("Remove from dock") : Tr.t("Unpin from taskbar"), glyph: "unpin", run: () => Desktop.togglePin(pinId) }
            : { text: mac ? Tr.t("Keep in dock") : Tr.t("Pin to taskbar"), glyph: "pin", run: () => Desktop.togglePin(pinId) });
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

    // Right-click on the Start button, or Windows+X: the power-user menu. In the Mac layout
    // it hangs from the emblem in the top bar.
    function startMenu(byKeyboard, from) {
        const tm = taskManager();
        const settings = "com.system76.CosmicSettings";
        const system = appEntries([[settings + ".Applications", Tr.t("Installed apps")],
                                   [settings + ".Power", Tr.t("Power options")],
                                   [settings + ".About", Tr.t("System")],
                                   [settings + ".Network", Tr.t("Network connections")]]);
        const tools = appEntries([["com.system76.CosmicTerm", Tr.t("Terminal")]]);
        const apps = (tm ? [{ text: Tr.t("Task Manager"), run: () => tm.execute() }] : [])
            .concat(appEntries([[settings, Tr.t("Settings")], ["com.system76.CosmicFiles", Tr.t("Files")]]))
            .concat([{ text: Tr.t("Search"), run: () => bar.toggle("launcherOpen", true) }]);
        const power = { text: Tr.t("Shut down or sign out"), sub: [
            { text: Tr.t("Sign out"), glyph: "signout", run: () => Qt.quit() },  // the session ends with the shell
            { text: Tr.t("Sleep"), glyph: "sleep", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
            { text: Tr.t("Shut down"), glyph: "power", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
            { text: Tr.t("Restart"), glyph: "restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) }
        ] };
        const out = [];
        for (const group of [system, tools, apps]) if (group.length) out.push(...group, { sep: true });
        out.push(power, { text: Tr.t("Desktop"), run: () => Windows.showDesktop() });
        menu.show(from ?? (mac && top.visible ? system : start), out, byKeyboard);
    }

    // Right-click on an empty part of the bar.
    function barMenu(item, byKeyboard) {
        const tm = taskManager();
        const out = tm ? [{ text: Tr.t("Task Manager"), icon: tm.icon, run: () => tm.execute() }] : [];
        out.push({ text: mac ? Tr.t("Dock settings") : Tr.t("Taskbar settings"), glyph: "sun", run: () => Desktop.personalise("taskbar") });
        // The other layout, live (also on the Personalise page and in kriss-welcome).
        out.push(mac ? { text: Tr.t("Switch to the taskbar"), glyph: "taskView", run: () => Desktop.setLayout("windows") }
                     : { text: Tr.t("Switch to the top bar and dock"), glyph: "apps", run: () => Desktop.setLayout("mac") });
        menu.show(item, out, byKeyboard);
    }

    component AppButton: MouseArea {
        id: btn
        required property var modelData
        required property int index
        readonly property string pinId: modelData.entry?.id ?? modelData.appId
        readonly property bool pinned: Desktop.isPinned(pinId)
        readonly property var wins: modelData.win ? [modelData.win] : Windows.forApp(modelData.appId, bar.wins)
        readonly property bool front: wins.some(w => w.active && !w.minimized)
        // What the app sent over D-Bus: progress, a badge count, a call for attention.
        readonly property var info: Windows.entries[pinId.toLowerCase()] ?? {}
        readonly property bool urgent: !!info.urgent && !front
        readonly property var entryName: modelData.entry?.name ?? modelData.appId
        // Drag a pinned app sideways to reorder the pins.
        property real pressX: 0
        property bool dragging: false
        readonly property real step: width + appRow.spacing

        width: modelData.win ? bar.labelWidth : bar.button
        height: bar.button
        z: dragging ? 1 : 0
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: modelData.win ? (modelData.win.title || entryName) : entryName
        Accessible.description: [wins.length === 0 ? Tr.t("Not running") : wins.length === 1 ? Tr.t("1 window") : Tr.t("%1 windows", wins.length),
            pinned ? Tr.t("Pinned") : "", urgent ? Tr.t("Wants attention") : "",
            info["count-visible"] && info.count > 0 ? Tr.t("%1 new", info.count) : ""].filter(s => s).join(", ")
        Accessible.onPressAction: bar.activate(index, false)
        // Enter opens or switches (Shift+Enter: a new window), the Menu key or Shift+F10 the
        // jump list; the bar moves the focus on.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier) bar.jumpList(index, true);
            else if (event.key === Qt.Key_Up && wins.length) previews.openFrom(btn);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (event.modifiers & Qt.ShiftModifier) bar.newWindow(index); else bar.activate(index, false);
            } else return;
            event.accepted = true;
        }
        // The keyboard on a button shows its previews too, as the pointer does.
        onActiveFocusChanged: {
            if (activeFocus) bar.previewFor = btn;
            else if (bar.previewFor === btn && !containsMouse) bar.previewFor = null;
        }
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
        FocusRim { radius: Theme.rControl + 2 }

        Rectangle {
            id: face
            anchors.fill: parent
            radius: Theme.rControl
            // Lit under the pointer and behind the app in front, clear otherwise.
            color: btn.containsMouse ? (btn.front ? Theme.cardHover : Theme.card) : btn.front ? Theme.card : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
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
                id: icon
                x: btn.modelData.win ? 10 : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: bar.icon
                source: Quickshell.iconPath(btn.modelData.entry?.icon ?? btn.modelData.appId, "application-x-executable")
            }
            // Uncombined: the window's title.
            Text {
                visible: !!btn.modelData.win
                anchors { left: icon.right; right: parent.right; leftMargin: Theme.s2; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                text: btn.modelData.win?.title ?? ""
                elide: Text.ElideRight
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
        // A badge count, top right.
        Rectangle {
            visible: !!btn.info["count-visible"] && btn.info.count > 0
            x: parent.width - width - 2; y: 2
            width: Math.max(16, badge.implicitWidth + 8); height: Math.max(16, badge.implicitHeight); radius: height / 2
            color: Theme.accent
            Text {
                id: badge
                anchors.centerIn: parent
                text: btn.info.count > 99 ? "99+" : (btn.info.count ?? "")
                color: Theme.accentInk
                font { family: Theme.sans; pixelSize: Theme.sp(10); weight: Font.Bold }
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
            radius: height / 2
            color: Theme.line
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, btn.info.progress ?? 0))
                height: parent.height
                radius: parent.radius
                color: Theme.accentText
                Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
            }
        }
        // Running: a short mark; in front: a longer accent pill; wants attention: red.
        // In the dock: a dot, accent for the app in front.
        Rectangle {
            visible: btn.wins.length > 0 && !track.visible
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: bar.mac ? -2 : 1
            width: bar.mac ? 4 : btn.front ? 16 : 6
            height: bar.mac ? 4 : 3
            radius: height / 2
            color: btn.urgent ? Theme.red : btn.front ? Theme.accentText : Theme.soft
            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        }
    }

    // A control on the bar: lit under the pointer or while its panel is open (`lit`, or a
    // colour of its own in `litColor`), gives a little when pressed, and works from the
    // keyboard: Enter or Space is a click, the Menu key or Shift+F10 a right-click (with
    // hasMenu). The bar's own keys move between controls.
    component BarButton: MouseArea {
        id: bb
        property bool lit: false
        property color litColor: containsMouse || lit ? Theme.card : "transparent"
        property int radius: Theme.rControl
        property string name
        property string tip
        property int role: Accessible.Button
        property bool checked: false
        property bool hasMenu: false
        property bool boxed: false       // always drawn as a box (the search pill): outlined in high contrast
        signal activated()
        signal menuAsked(bool byKeyboard)

        Layout.preferredWidth: Theme.barButton
        // Shorter in the slim Mac top bar.
        Layout.preferredHeight: Math.min(Theme.barButton, (parent?.height ?? Theme.barButton) - 4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        acceptedButtons: hasMenu ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onClicked: mouse => mouse.button === Qt.RightButton ? menuAsked(false) : activated()
        scale: pressed ? Theme.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activated();
            else if (hasMenu && (event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier)) menuAsked(true);
            else return;
            event.accepted = true;
        }
        Accessible.role: role
        Accessible.name: name
        Accessible.description: tip
        Accessible.checkable: role === Accessible.RadioButton
        Accessible.checked: checked
        Accessible.onPressAction: activated()

        Rectangle {
            anchors.fill: parent
            radius: bb.radius
            color: bb.litColor
            border.width: Theme.high && bb.boxed ? Theme.rimWidth : 0
            border.color: Theme.line
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        FocusRim { radius: bb.radius + 2 }
    }
}
