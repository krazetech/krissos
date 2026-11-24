import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "fuzzy.js" as Fuzzy

// The launcher, laid out like the Windows Start menu so people coming from Windows
// find their way: search on top, Pinned (or All apps), Recommended files, then the
// account and power at the bottom. Typing searches straight away, the way cmdk does:
// one field, fuzzy results grouped into Apps, Actions and Files, the first one selected,
// arrows to move, Enter to run, Esc to clear and then to close.
PanelWindow {
    id: win

    // Stays up while the menu fades away, but lets go of the keyboard and the pointer at once.
    visible: Desktop.launcherOpen || panel.opacity > 0
    screen: Desktop.screen

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-launcher"
    WlrLayershell.keyboardFocus: Desktop.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Desktop.launcherOpen ? null : noInput
    Region { id: noInput }
    // Cover the screen above the bar, so a click anywhere else closes the menu.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    property string query: ""
    property bool allApps: false
    property bool powerMenu: false
    // The account menu, from the picture at the bottom left, as on Windows.
    property bool accountMenu: false
    // Whether the guest account is on (`kriss guest on`), checked when the menu opens.
    property bool guestOn: false
    readonly property bool isGuest: Quickshell.env("USER") === "guest"
    readonly property var accountActions: [
        ["user", Tr.t("Change account settings"), () => { close(); SettingsPages.open("users"); }],
        ["lock", Tr.t("Lock"), () => { close(); Desktop.locked = true; }],
        ["signout", Tr.t("Sign out"), () => Qt.quit()],
        ["users", Tr.t("Switch user"), () => { close(); Quickshell.execDetached(["kriss-shell", "switch-user"]); }]
    ].concat(isGuest ? [] : [[guestOn ? "check" : "plus", guestOn ? Tr.t("Turn off the guest account") : Tr.t("Turn on the guest account"),
        () => { guestSwitch.command = ["pkexec", "kriss", "guest", guestOn ? "off" : "on"]; guestSwitch.running = true; }]])
    Process { id: guestCheck; command: ["test", "-e", "/var/lib/kriss/guest"]; onExited: code => win.guestOn = code === 0 }
    Process { id: guestSwitch; onExited: guestCheck.running = true }
    onAccountMenuChanged: if (accountMenu) guestCheck.running = true
    property int current: 0

    // COSMIC Settings is left out: KrissOS Settings replaces it, and opens its pages itself.
    readonly property var everything: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && e.id !== "com.system76.CosmicSettings")
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var installedIds: new Set(everything.map(e => e.id))

    // The grid when nothing is typed.
    readonly property var shown: allApps ? everything : Desktop.pinnedEntries()

    // Commands, with the words people search for them by, in English and Malay. The first
    // five are also the power menu.
    readonly property var actions: [
        ["lock", Tr.t("Lock"), () => { close(); Desktop.locked = true; }, "lock screen;kunci;kunci skrin"],
        ["sleep", Tr.t("Sleep"), () => { close(); Quickshell.execDetached(["systemctl", "suspend"]); }, "suspend;tidur;gantung"],
        ["restart", Tr.t("Restart"), () => Quickshell.execDetached(["systemctl", "reboot"]), "reboot;mula semula;but semula"],
        ["power", Tr.t("Shut down"), () => Quickshell.execDetached(["systemctl", "poweroff"]), "shutdown;power off;turn off;tutup;matikan"],
        // Quitting the shell cleanly ends the session (see kriss-shell).
        ["signout", Tr.t("Sign out"), () => Qt.quit(), "log out;logout;sign off;log keluar;daftar keluar"],
        ["users", Tr.t("Switch user"), () => { close(); Quickshell.execDetached(["kriss-shell", "switch-user"]); }, "switch user;change user;other user;tukar pengguna;pengguna lain"],
        ["sun", Tr.t("Quick settings"), () => { close(); Desktop.quickOpen = true; }, "wifi;volume;brightness;tetapan pantas;kecerahan"],
        ["bell", Tr.t("Notifications"), () => { close(); Desktop.notificationsOpen = true; }, "notification centre;pemberitahuan"],
        [Desktop.dnd ? "bell" : "bellOff", Desktop.dnd ? Tr.t("Turn off do not disturb") : Tr.t("Turn on do not disturb"),
            () => { Desktop.dnd = !Desktop.dnd; close(); }, "do not disturb;dnd;quiet;focus;jangan ganggu;senyap"],
        ["camera", Tr.t("Take a screenshot"), () => { close(); Desktop.screenshot(); },
            "screenshot;screen capture;print screen;snip;snipping tool;tangkapan skrin;cetak skrin"],
        // kriss actions that work offline: a summary of this PC, and whether it can run
        // Windows apps in WinBoat (read-only; WinBoat is x86_64 only).
        ["file", Tr.t("About this PC"), () => { close(); inTerminal("kriss info; kriss version"); },
            "system info;specs;version;kriss info;perihal pc;maklumat sistem;spesifikasi"],
        ...(providers.x86 ? [["check", Tr.t("Check this PC can run Windows apps"), () => { close(); inTerminal("kriss winapps check"); },
            "windows apps;winboat;exe;run windows programs;aplikasi windows;program windows"]] : []),
        // Updates need the internet, so this one is offered only online.
        ...(providers.online ? [["update", Tr.t("Update KrissOS"), () => { close(); inTerminal("pkexec kriss update"); },
            "update;upgrade;windows update;check for updates;kemas kini;naik taraf"]] : [])
    ]

    function inTerminal(cmd) {
        const term = providers.has["xdg-terminal-exec"] ? ["xdg-terminal-exec"]
            : providers.has["cosmic-term"] ? ["cosmic-term", "-e"] : ["konsole", "-e"];
        // The shell stays open after the command, so its output can be read.
        Quickshell.execDetached(term.concat(["sh", "-c", cmd + '; exec "${SHELL:-sh}"']));
    }
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]); }
    // A path as a file: URL, and its folder.
    function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }
    function openFolder(href) { Qt.openUrlExternally(href.slice(0, href.lastIndexOf("/") + 1)); close(); }

    Search {
        id: providers
        query: win.query
        active: Desktop.launcherOpen
    }

    // Search results: rows of {header} or {kind, label, icon, run, sel}, where sel is the
    // row's place among the rows that can be picked. Groups are ordered by Fuzzy.order.
    readonly property var results: {
        const q = query.trim();
        if (!q) return [];
        const ranked = (list, limit) => list.filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score).slice(0, limit);
        let groups;
        if (q.startsWith(">")) {
            // ">" and a command runs it in a terminal, like Run on Windows.
            const cmd = q.slice(1).trim();
            groups = !cmd ? [] : [{ key: "run", title: Tr.t("Commands"), items: [{
                kind: "action", glyph: "terminal", label: Tr.t("Run “%1” in a terminal", cmd), score: 1,
                run: () => { close(); inTerminal(cmd); }
            }] }];
        } else {
            const expr = Fuzzy.calcExpr(q);
            // "install spotify" (online): kriss install, from the safest source that has it, in a
            // terminal so its questions and the password prompt can be answered. First of all.
            const pkg = providers.online && /^(install|pasang)\s+\S/i.test(q) ? q.replace(/^\S+\s+/, "") : "";
            const installRow = pkg ? [{ kind: "action", glyph: "plus", label: Tr.t("Install “%1”", pkg), score: 100000,
                run: () => { close(); inTerminal("kriss install " + pkg.split(/\s+/).map(w => "'" + w.replace(/'/g, "'\\''") + "'").join(" ")); } }] : [];
            // Recent files first, then the rest of home; the same file once.
            const recentRows = recentAll.filter(f => f.href.startsWith("file:")).map(f => {
                const s = Fuzzy.score(f.name, q);
                return { kind: "file", label: f.name, href: f.href, detail: Tr.ago(f.when), score: s >= 600 ? s + 200 : 0 };
            });
            const seen = new Set(recentAll.map(f => f.href));
            const indexRows = (providers.filesFor && q.toLowerCase().includes(providers.filesFor.toLowerCase()) ? providers.files : [])
                .map(p => {
                    const dir = p.endsWith("/");
                    p = dir ? p.slice(0, -1) : p;
                    const name = p.slice(p.lastIndexOf("/") + 1), href = fileUrl(p);
                    return seen.has(href) ? { score: 0 } : {
                        kind: "file", label: name, href: href,
                        // ponytail: plocate doesn't say what's a folder; no dot in the name is a guess.
                        folder: dir || !name.includes("."),
                        detail: p.slice(0, p.lastIndexOf("/")).replace(providers.home, "~") || "/",
                        // The same match nearer home first.
                        score: Fuzzy.score(name, q) && Fuzzy.score(name, q) - p.split("/").length
                    };
                });
            groups = Fuzzy.order([
                { key: "app", title: Tr.t("Apps"), items: ranked(everything.map(e => ({
                    kind: "app", label: e.name, icon: e.icon, entry: e, run: () => launch(e),
                    score: Fuzzy.best([e.name, e.genericName, ...e.keywords], q)
                })), 6) },
                { key: "setting", title: Tr.t("Settings"), items: ranked(providers.settingRows(q, Tr.lang === "ms")
                    .map(r => Object.assign(r, { run: () => { if (r.open) r.open(); else Quickshell.execDetached(r.exec); close(); } })), 4) },
                { key: "action", title: Tr.t("Commands"), items: installRow.concat(ranked(actions.map(a => ({
                    kind: "action", label: a[1], glyph: a[0], run: a[2],
                    // Its words count a little less than its name.
                    score: Math.max(Fuzzy.score(a[1], q), ...a[3].split(";").map(w => Fuzzy.score(w, q) - 100))
                })), 4)) },
                { key: "file", title: Tr.t("Files"), items: ranked(recentRows.concat(indexRows), 6).map(r => Object.assign(r, {
                    run: () => { Qt.openUrlExternally(r.href); close(); },
                    alt: () => openFolder(r.href)
                })) },
                // Apps that are not installed yet: open them in the Store. Not for one letter.
                { key: "store", title: Tr.t("Store"), items: q.length < 2 ? [] : ranked(providers.storeApps
                    .filter(a => !installedIds.has(a.id)).map(a => ({
                        kind: "store", label: a.name, icon: a.icon, detail: Tr.t("Get from the Store"),
                        run: () => { close(); Quickshell.execDetached(["kriss-store", "--app", a.id]); },
                        score: Fuzzy.score(a.name, q)
                    })), 3) },
                { key: "calc", title: Tr.t("Calculator"), items: expr && providers.calcFor === expr && providers.calcResult ? [{
                    kind: "calc", glyph: "calc", label: "= " + providers.calcResult, detail: q, score: 1,
                    run: () => { copy(providers.calcResult); close(); }
                }] : [] },
                { key: "web", title: Tr.t("Web"), items: providers.online ? [{
                    kind: "action", glyph: "globe", label: Tr.t("Search the web for “%1”", q), score: 1,
                    run: () => { Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(q)); close(); }
                }] : [] }
            ]);
        }
        const rows = [];
        let sel = 0;
        for (const g of groups) {
            if (!g.items.length) continue;
            rows.push({ header: g.title });
            for (const r of g.items) { r.sel = sel++; rows.push(r); }
        }
        return rows;
    }
    readonly property int count: query.trim() ? results.filter(r => !r.header).length : Desktop.launcherSearch ? 0 : shown.length

    function close() { Desktop.launcherOpen = false; }
    function launch(entry) { entry.execute(); close(); }
    function run() {
        if (!query.trim()) { if (count && shown[current]) launch(shown[current]); return; }
        const r = results.find(r => r.sel === current);
        if (r) r.run();
    }
    // Ctrl+Enter: a file's folder.
    function runAlt() {
        const r = results.find(r => r.sel === current);
        if (r && r.alt) r.alt();
    }
    // Open, and open its folder, for a file.
    function fileMenuFor(row, item, byKeyboard) {
        appMenu.show(item, [
            { text: Tr.t("Open"), glyph: row.folder ? "folder" : "file", run: row.run },
            { text: Tr.t("Open folder"), glyph: "folder", run: row.alt }
        ], byKeyboard);
    }
    // Open, and pin or unpin, for an app; byKeyboard highlights the first item.
    function appMenuFor(entry, item, byKeyboard) {
        appMenu.show(item, [
            { text: Tr.t("Open"), icon: entry.icon, run: () => launch(entry) },
            Desktop.isPinned(entry.id)
                ? { text: Tr.t("Unpin from taskbar"), glyph: "unpin", run: () => Desktop.togglePin(entry.id) }
                : { text: Tr.t("Pin to taskbar"), glyph: "pin", run: () => Desktop.togglePin(entry.id) }
        ], byKeyboard);
    }
    // The menu key (or Shift+F10) on the selected app, as on Windows.
    function menuForCurrent() {
        if (!query.trim()) {
            const cell = grid.itemAtIndex(current);
            if (count && cell && shown[current]) appMenuFor(shown[current], cell, true);
            return;
        }
        const i = results.findIndex(r => r.sel === current);
        if (i < 0) return;
        if (results[i].kind === "app") appMenuFor(results[i].entry, list.itemAtIndex(i), true);
        else if (results[i].alt) fileMenuFor(results[i], list.itemAtIndex(i), true);
    }
    function move(by) { if (count) current = Math.max(0, Math.min(count - 1, current + by)); }

    // For a screen reader, which stays in the search field: the selected app or result as
    // it changes, and how many results once typing pauses.
    readonly property string currentLabel: query.trim() ? (results.find(r => r.sel === current)?.label ?? "")
        : count ? (shown[current]?.name ?? "") : ""
    onCurrentLabelChanged: if (Desktop.launcherOpen && currentLabel) search.Accessible.announce(currentLabel)
    onCountChanged: if (query.trim()) counted.restart()
    Timer {
        id: counted
        interval: 700
        onTriggered: search.Accessible.announce(win.count === 0 ? Tr.t("No results")
            : win.count === 1 ? Tr.t("1 result") : Tr.t("%1 results", win.count))
    }

    Connections {
        target: Desktop
        function onLauncherOpenChanged() { if (Desktop.launcherOpen) win.reset(); }
    }
    function reset() {
        query = ""; allApps = false; powerMenu = false; accountMenu = false; current = 0;
        search.text = "";
        search.forceActiveFocus();
    }
    onShownChanged: current = 0
    onResultsChanged: current = 0

    readonly property var recentAll: Desktop.recentShown
    readonly property var recent: Desktop.withFolders(recentAll, 4)

    MouseArea {
        Accessible.ignored: true  // pointer only; the keyboard has its own way
        anchors.fill: parent
        onClicked: win.close()
    }
    // Keys the focused control leaves alone: typing goes to the search, Esc closes (the power
    // menu first), as in Windows Start.
    Item {
        id: keyCatch
        anchors.fill: parent
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (win.powerMenu) { win.powerMenu = false; powerBtn.forceActiveFocus(); }
                else if (win.accountMenu) { win.accountMenu = false; accountBtn.forceActiveFocus(); }
                else Desktop.back("launcherOpen");
            } else if (event.text && event.text.trim() && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                search.forceActiveFocus();
                search.insert(search.cursorPosition, event.text);
            } else return;
            event.accepted = true;
        }

    Rectangle {
        id: panel
        Accessible.role: Accessible.Dialog
        Accessible.name: Tr.t("Start")
        // Over Start: at the left, or centred with a centred taskbar. Search in the Mac layout
        // sits high in the middle of the screen, where Spotlight is, and grows downwards.
        readonly property bool spotlight: Desktop.mac && Desktop.launcherSearch
        x: Desktop.taskbarAlignment === "centre" || Desktop.mac ? (parent.width - width) / 2 : Theme.panelGap
        y: spotlight ? Math.round(parent.height * 0.18) : parent.height - height - Theme.panelGap - Desktop.barRoom
        width: Theme.dp(600)
        height: body.implicitHeight + body.anchors.topMargin + body.anchors.bottomMargin + foot.height
        radius: Theme.rPanel
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.rim
        clip: true

        // Fades in and rises a few pixels; going away it does the same backwards.
        opacity: Desktop.launcherOpen ? 1 : 0
        transform: Translate {
            y: Desktop.launcherOpen || Theme.reduceMotion ? 0 : panel.spotlight ? -12 : 12
            Behavior on y { NumberAnimation { duration: Theme.ms(Desktop.launcherOpen ? Theme.normal : Theme.fastExit); easing.type: Desktop.launcherOpen ? Theme.ease : Theme.easeExit } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.ms(Desktop.launcherOpen ? Theme.fast : Theme.fastExit); easing.type: Desktop.launcherOpen ? Theme.ease : Theme.easeExit } }
        // The panel grows and shrinks with the results instead of jumping (cmdk does the same).
        Behavior on height { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

        MouseArea { anchors.fill: parent; onClicked: { win.powerMenu = false; win.accountMenu = false; } Accessible.ignored: true }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Theme.s5
            anchors.topMargin: Theme.s5
            anchors.bottomMargin: Theme.s3
            spacing: Theme.s3

            // Search.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 0
                implicitHeight: 46
                radius: height / 2
                color: Theme.card
                border.width: 2
                border.color: Theme.accentText
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s4
                    anchors.rightMargin: Theme.s4
                    spacing: Theme.s2
                    Glyph { name: "search"; size: 18; color: Theme.soft }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.Medium }
                        Accessible.role: Accessible.EditableText
                        Accessible.name: Tr.t("Search for apps, settings and files")
                        Accessible.description: Tr.t("Arrows choose, Enter opens, Tab moves to the other controls")
                        onTextChanged: win.query = text
                        Text {
                            visible: !search.text
                            text: Tr.t("Search for apps, settings and files")
                            color: Theme.soft
                            font: search.font
                        }
                        Keys.onEscapePressed: if (text) text = ""; else Desktop.back("launcherOpen")
                        Keys.onReturnPressed: event => event.modifiers & Qt.ControlModifier ? win.runAlt() : win.run()
                        Keys.onEnterPressed: event => event.modifiers & Qt.ControlModifier ? win.runAlt() : win.run()
                        // In the grid, left and right step and up and down jump a row; the
                        // result list only goes up and down, so left and right stay in the text.
                        Keys.onLeftPressed: event => { if (win.query) event.accepted = false; else win.move(-1); }
                        Keys.onRightPressed: event => { if (win.query) event.accepted = false; else win.move(1); }
                        Keys.onUpPressed: win.move(win.query ? -1 : -grid.columns)
                        Keys.onDownPressed: win.move(win.query ? 1 : grid.columns)
                        // With results, Tab steps through them as in cmdk; otherwise it goes on to
                        // All apps, Recommended and power, in reading order.
                        Keys.onTabPressed: event => { if (win.query) win.move(1); else event.accepted = false; }
                        Keys.onBacktabPressed: event => { if (win.query) win.move(-1); else event.accepted = false; }
                        activeFocusOnTab: true
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier) win.menuForCurrent();
                            else if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) win.current = 0;
                            else if (event.key === Qt.Key_End && event.modifiers & Qt.ControlModifier) win.current = win.count - 1;
                            else return;
                            event.accepted = true;
                        }
                    }
                }
            }

            // Pinned / All apps header.
            RowLayout {
                visible: !win.query && !Desktop.launcherSearch
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: win.allApps ? Tr.t("All apps") : Tr.t("Pinned")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
                }
                Chip {
                    label: win.allApps ? Tr.t("Back") : Tr.t("All apps")
                    glyph: win.allApps ? "back" : "chevron"
                    onActivated: win.allApps = !win.allApps
                }
            }

            GridView {
                id: grid
                readonly property int columns: 6
                Layout.fillWidth: true
                visible: !win.query && !Desktop.launcherSearch && win.shown.length > 0
                Layout.preferredHeight: Math.min(win.allApps ? 4 : 3, Math.ceil(win.shown.length / columns)) * cellHeight
                cellWidth: width / columns
                cellHeight: 66 + Theme.sp(12) * 2.7  // room for a name on two lines
                highlightMoveDuration: Theme.ms(150)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.shown
                currentIndex: win.current

                delegate: MouseArea {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: win.launch(modelData)
                    hoverEnabled: true
                    onEntered: win.current = index
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) return win.launch(modelData);
                        win.appMenuFor(modelData, cell, false);
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.s0
                        radius: Theme.rCard
                        color: cell.pressed ? Theme.cardHover : cell.index === win.current ? Theme.card : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.s1
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 50; height: 50; radius: Theme.rCard
                            color: cell.index === win.current ? Theme.win : Theme.card
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 32
                                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: grid.cellWidth - 8
                            horizontalAlignment: Text.AlignHCenter
                            // Two lines before it is cut, as on Windows.
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: cell.modelData.name
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.Medium }
                        }
                    }
                }
            }

            // Search results, grouped.
            ListView {
                id: list
                Layout.fillWidth: true
                visible: win.query && win.count > 0
                Layout.preferredHeight: Math.min(contentHeight, 440)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                model: win.results
                // Keep the selected row in view.
                Connections {
                    target: win
                    function onCurrentChanged() {
                        const i = win.results.findIndex(r => r.sel === win.current);
                        if (i >= 0) list.positionViewAtIndex(i, ListView.Contain);
                    }
                }

                delegate: Loader {
                    required property var modelData
                    width: list.width
                    sourceComponent: modelData.header ? groupHeader : resultRow
                    readonly property var row: modelData
                }
            }

            Text {
                visible: win.count === 0 && (win.query || !Desktop.launcherSearch)
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: win.query ? Tr.t("No results for “%1”.", win.query.trim()) : Tr.t("Right-click an app to pin it.")
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(14) }
            }

            // Recommended files.
            RowLayout {
                visible: !win.query && !win.allApps
                Layout.fillWidth: true
                Layout.topMargin: Theme.s1
                Text {
                    Layout.fillWidth: true
                    text: Tr.t("Recommended")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
                }
            }

            GridLayout {
                visible: !win.query && !win.allApps
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.s2
                rowSpacing: Theme.s0

                Repeater {
                    model: win.recent
                    delegate: MouseArea {
                        id: rec
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Math.max(52, recText.implicitHeight + 16)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: open()
                        function open() { Qt.openUrlExternally(modelData.href); win.close(); }
                        activeFocusOnTab: true
                        Keys.onReturnPressed: open()
                        Keys.onEnterPressed: open()
                        Keys.onSpacePressed: open()
                        Accessible.role: Accessible.Button
                        // A folder's href ends in "/": its name is the part before.
                        readonly property string fileName: decodeURIComponent(modelData.href.replace(/\/$/, "").split("/").pop())
                        Accessible.name: fileName
                        Accessible.description: Tr.t("Recommended file, %1", Tr.ago(modelData.when))
                        Accessible.onPressAction: open()
                        FocusRim { radius: Theme.rCard + 2 }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rCard
                            color: rec.pressed ? Theme.cardHover : rec.containsMouse ? Theme.card : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s2
                            anchors.rightMargin: Theme.s2
                            spacing: Theme.s3
                            Rectangle {
                                implicitWidth: 36; implicitHeight: 36; radius: Theme.rControl
                                color: Theme.card
                                IconImage { anchors.centerIn: parent; implicitSize: 24; source: Quickshell.iconPath(Desktop.mimeIcon(rec.modelData)) }
                            }
                            Column {
                                id: recText
                                Layout.fillWidth: true
                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: rec.fileName
                                    color: Theme.fg
                                    font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
                                }
                                // Its folder too, when another file shown has the same name.
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: [rec.modelData.detail, Tr.ago(rec.modelData.when)].filter(s => s).join(" · ")
                                    color: Theme.soft
                                    font { family: Theme.sans; pixelSize: Theme.sp(11) }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: win.recent.length === 0
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    verticalAlignment: Text.AlignVCenter
                    text: Tr.t("Files you open will show up here.")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(13) }
                }
            }
        }

        // Account and power.
        Rectangle {
            id: foot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Theme.dp(64)
            color: "transparent"
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.line }

            // The picture and name: the account menu.
            MouseArea {
                id: accountBtn
                anchors.left: parent.left
                anchors.leftMargin: Theme.s4
                anchors.verticalCenter: parent.verticalCenter
                width: who.implicitWidth + 2 * Theme.s2
                height: Theme.dp(46)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle()
                function toggle() {
                    win.powerMenu = false;
                    win.accountMenu = !win.accountMenu;
                    if (win.accountMenu && activeFocus) powerItems.itemAt(0)?.forceActiveFocus();
                }
                activeFocusOnTab: true
                Keys.onReturnPressed: toggle()
                Keys.onEnterPressed: toggle()
                Keys.onSpacePressed: toggle()
                Accessible.role: Accessible.ButtonMenu
                Accessible.name: Tr.t("Signed in as %1", Desktop.personName)
                Accessible.onPressAction: toggle()
                FocusRim { radius: Theme.rControl }
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rControl
                    color: accountBtn.containsMouse || win.accountMenu ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Row {
                    id: who
                    anchors.centerIn: parent
                    spacing: Theme.s2
                    Avatar {
                        size: Theme.dp(34)
                        name: Desktop.personName
                        faces: Desktop.faces
                        border.color: Theme.line
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Desktop.personName
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.DemiBold }
                    }
                }
            }

            // Settings, next to power, as on Windows 11.
            MouseArea {
                id: settingsBtn
                anchors.right: powerBtn.left
                anchors.rightMargin: Theme.s1
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(38); height: Theme.dp(38)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { win.close(); SettingsPages.open(""); }
                activeFocusOnTab: true
                Keys.onReturnPressed: clicked(null)
                Keys.onEnterPressed: clicked(null)
                Keys.onSpacePressed: clicked(null)
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Settings")
                Accessible.onPressAction: clicked(null)
                FocusRim { radius: height / 2 }
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: settingsBtn.containsMouse ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: "settings"; size: 19 }
            }

            MouseArea {
                id: powerBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.s4
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(38); height: Theme.dp(38)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle()
                function toggle() {
                    win.accountMenu = false;
                    win.powerMenu = !win.powerMenu;
                    if (win.powerMenu && activeFocus) powerItems.itemAt(0)?.forceActiveFocus();
                }
                activeFocusOnTab: true
                Keys.onReturnPressed: toggle()
                Keys.onEnterPressed: toggle()
                Keys.onSpacePressed: toggle()
                Accessible.role: Accessible.ButtonMenu
                Accessible.name: Tr.t("Power")
                Accessible.onPressAction: toggle()
                FocusRim { radius: height / 2 }
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: powerBtn.containsMouse || win.powerMenu ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: "power"; size: 19 }
            }
        }

        // Power menu, above the power button.
        // Or the account menu, above the picture.
        Rectangle {
            visible: win.powerMenu || win.accountMenu
            x: win.accountMenu ? Theme.s3 : parent.width - width - Theme.s3
            anchors.bottom: foot.top
            anchors.bottomMargin: -4
            width: Theme.dp(win.accountMenu ? 260 : 190)
            height: menu.implicitHeight + 12
            radius: Theme.rCard
            color: Theme.card
            border.width: Theme.rimWidth
            border.color: Theme.line

            Column {
                id: menu
                anchors.centerIn: parent
                width: parent.width - 12
                Repeater {
                    id: powerItems
                    model: win.accountMenu ? win.accountActions : win.actions.slice(0, 5)
                    delegate: MouseArea {
                        id: item
                        required property var modelData
                        required property int index
                        width: menu.width
                        height: Math.max(38, Theme.sp(14) + 20)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData[2]()
                        Keys.onReturnPressed: modelData[2]()
                        Keys.onEnterPressed: modelData[2]()
                        Keys.onUpPressed: powerItems.itemAt(Math.max(0, index - 1)).forceActiveFocus()
                        Keys.onDownPressed: powerItems.itemAt(Math.min(powerItems.count - 1, index + 1)).forceActiveFocus()
                        Accessible.role: Accessible.MenuItem
                        Accessible.name: modelData[1]
                        Accessible.onPressAction: modelData[2]()
                        FocusRim { anchors.margins: 0; radius: Theme.rControl; border.width: 1; opacity: 0.6 }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rControl
                            color: item.containsMouse || item.activeFocus ? Theme.win : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.s3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.s3
                            Glyph { name: item.modelData[0]; size: 17 }
                            Text {
                                text: item.modelData[1]
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                            }
                        }
                    }
                }
            }
        }
    }
    }

    Menu { id: appMenu }

    Component {
        id: groupHeader
        Text {
            readonly property var row: parent.row
            height: Math.max(30, Theme.sp(13) + 14)
            verticalAlignment: Text.AlignBottom
            bottomPadding: Theme.s1
            leftPadding: Theme.s3
            text: row.header
            color: Theme.soft
            font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
        }
    }

    Component {
        id: resultRow
        MouseArea {
            id: res
            readonly property var row: parent.row
            readonly property bool selected: row.sel === win.current
            height: Math.max(46, resText.implicitHeight + 12)
            Accessible.role: Accessible.ListItem
            Accessible.name: row.label
            Accessible.description: row.detail ?? ""
            Accessible.selected: selected
            Accessible.onPressAction: row.run()
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // The pointer selects, as in cmdk, so there is only ever one highlight.
            onEntered: win.current = row.sel
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) return row.run();
                if (row.kind === "app") win.appMenuFor(row.entry, res, false);
                else if (row.alt) win.fileMenuFor(row, res, false);
            }
            readonly property bool twoLines: row.kind === "file" || row.kind === "calc"

            Rectangle {
                anchors.fill: parent
                radius: Theme.rCard
                color: res.pressed ? Theme.cardHover : res.selected ? Theme.card : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s2
                spacing: Theme.s3
                Item {
                    implicitWidth: 28; implicitHeight: 28
                    readonly property bool iconic: res.row.kind === "app" || res.row.kind === "setting" || res.row.kind === "store"
                    IconImage {
                        visible: parent.iconic
                        anchors.centerIn: parent
                        implicitSize: 26
                        // A Store row's icon is Flatpak's cached file, when it has one.
                        source: !parent.iconic ? "" : res.row.kind === "store" && res.row.icon ? res.row.icon
                            : Quickshell.iconPath(res.row.icon || "system-software-install", "preferences-system")
                    }
                    Glyph {
                        visible: !parent.iconic
                        anchors.centerIn: parent
                        name: res.row.kind === "file" ? (res.row.folder ? "folder" : "file") : res.row.glyph
                        size: 18
                        color: res.selected ? Theme.accentText : Theme.soft
                    }
                }
                Column {
                    id: resText
                    Layout.fillWidth: true
                    Text {
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: res.row.label
                        color: Theme.fg
                        font.family: res.row.kind === "calc" ? Theme.mono : Theme.sans
                        font.pixelSize: Theme.sp(res.row.kind === "calc" ? 16 : 14)
                        font.weight: res.row.kind === "calc" ? Font.DemiBold : Font.Medium
                    }
                    // A file's folder, or the sum the answer is for.
                    Text {
                        visible: res.twoLines && !!res.row.detail
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: res.row.detail ?? ""
                        color: Theme.soft
                        font.family: res.row.kind === "calc" ? Theme.mono : Theme.sans
                        font.pixelSize: Theme.sp(11)
                    }
                }
                Text {
                    visible: !res.twoLines && !!res.row.detail && !res.selected
                    text: res.row.detail ?? ""
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(12) }
                }
                // A file's second action: its folder (Ctrl+Enter).
                MouseArea {
                    id: folderBtn
                    visible: res.selected && !!res.row.alt
                    implicitWidth: folderRow.implicitWidth + 16
                    implicitHeight: Math.max(28, folderRow.implicitHeight + 8)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: res.row.alt()
                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.t("Open folder")
                    Accessible.onPressAction: res.row.alt()
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rSmall
                        color: folderBtn.containsMouse ? Theme.cardHover : Theme.win
                        border.width: Theme.rimWidth
                        border.color: Theme.line
                    }
                    Row {
                        id: folderRow
                        anchors.centerIn: parent
                        spacing: Theme.s1
                        Glyph { anchors.verticalCenter: parent.verticalCenter; name: "folder"; size: 14; color: Theme.soft }
                        Text {
                            text: Tr.t("Open folder")
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.Medium }
                        }
                    }
                }
                Text {
                    visible: res.selected && res.row.kind === "calc"
                    text: Tr.t("Copy")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(12) }
                }
                // Enter runs the selected row.
                Rectangle {
                    visible: res.selected
                    implicitWidth: Math.max(26, enterKey.implicitWidth + 12); implicitHeight: Math.max(22, enterKey.implicitHeight + 4); radius: Theme.rSmall
                    Accessible.ignored: true
                    color: Theme.win
                    border.width: Theme.rimWidth
                    border.color: Theme.line
                    Text {
                        id: enterKey
                        anchors.centerIn: parent
                        text: "↵"
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                    }
                }
            }
        }
    }

    component Chip: MouseArea {
        id: chip
        property string label
        property string glyph
        implicitWidth: chipRow.implicitWidth + 22
        implicitHeight: Math.max(30, chipRow.implicitHeight + 10)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        signal activated()
        onClicked: activated()
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: activated()
        scale: pressed ? Theme.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.containsMouse ? Theme.cardHover : Theme.card
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        FocusRim { radius: height / 2 }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.s1
            Text {
                text: chip.label
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
            }
            Glyph { anchors.verticalCenter: parent.verticalCenter; name: chip.glyph; size: 14 }
        }
    }
}
