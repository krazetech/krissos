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
    property int current: 0

    readonly property var everything: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // The grid when nothing is typed.
    readonly property var shown: allApps ? everything : Desktop.pinnedEntries()

    readonly property var actions: [
        ["lock", Tr.t("Lock"), () => { close(); Desktop.locked = true; }],
        ["sleep", Tr.t("Sleep"), () => { close(); Quickshell.execDetached(["systemctl", "suspend"]); }],
        ["restart", Tr.t("Restart"), () => Quickshell.execDetached(["systemctl", "reboot"])],
        ["power", Tr.t("Shut down"), () => Quickshell.execDetached(["systemctl", "poweroff"])],
        // Quitting the shell cleanly ends the session (see kriss-shell).
        ["signout", Tr.t("Sign out"), () => Qt.quit()],
        ["sun", Tr.t("Quick settings"), () => { close(); Desktop.quickOpen = true; }],
        ["bell", Tr.t("Notifications"), () => { close(); Desktop.notificationsOpen = true; }]
    ]

    // Search results: rows of {header} or {kind, label, icon, run, sel}, where sel is the
    // row's place among the rows that can be picked.
    readonly property var results: {
        const q = query.trim();
        if (!q) return [];
        const ranked = (list, limit) => list.filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score).slice(0, limit);
        const groups = [
            [Tr.t("Apps"), ranked(everything.map(e => ({
                kind: "app", label: e.name, icon: e.icon, entry: e, run: () => launch(e),
                score: Fuzzy.best([e.name, e.genericName, ...e.keywords], q)
            })), 7)],
            [Tr.t("Actions"), ranked(actions.map(a => ({
                kind: "action", label: a[1], glyph: a[0], run: a[2], score: Fuzzy.score(a[1], q)
            })), 4)],
            [Tr.t("Files"), ranked(recentAll.map(f => ({
                kind: "file", label: f.name, detail: Tr.ago(f.when),
                run: () => { Qt.openUrlExternally(f.href); close(); }, score: Fuzzy.score(f.name, q)
            })), 4)]
        ];
        const rows = [];
        let sel = 0;
        for (const [title, items] of groups) {
            if (!items.length) continue;
            rows.push({ header: title });
            for (const r of items) { r.sel = sel++; rows.push(r); }
        }
        return rows;
    }
    readonly property int count: query.trim() ? results.filter(r => !r.header).length : shown.length

    function close() { Desktop.launcherOpen = false; }
    function launch(entry) { entry.execute(); close(); }
    function run() {
        if (!query.trim()) { if (shown[current]) launch(shown[current]); return; }
        const r = results.find(r => r.sel === current);
        if (r) r.run();
    }
    // Open, and pin or unpin, for an app; byKeyboard highlights the first item.
    function appMenuFor(entry, item, byKeyboard) {
        appMenu.show(item, [
            [Tr.t("Open"), () => launch(entry)],
            [Desktop.isPinned(entry.id) ? Tr.t("Unpin from taskbar") : Tr.t("Pin to taskbar"), () => Desktop.togglePin(entry.id)]
        ], byKeyboard);
    }
    // The menu key (or Shift+F10) on the selected app, as on Windows.
    function menuForCurrent() {
        if (!query.trim()) {
            const cell = grid.itemAtIndex(current);
            if (cell && shown[current]) appMenuFor(shown[current], cell, true);
            return;
        }
        const i = results.findIndex(r => r.sel === current);
        if (i >= 0 && results[i].entry) appMenuFor(results[i].entry, list.itemAtIndex(i), true);
    }
    function move(by) { if (count) current = Math.max(0, Math.min(count - 1, current + by)); }

    Connections {
        target: Desktop
        function onLauncherOpenChanged() { if (Desktop.launcherOpen) win.reset(); }
    }
    function reset() {
        query = ""; allApps = false; powerMenu = false; current = 0;
        search.text = "";
        search.forceActiveFocus();
        recentFile.reload();
    }
    onShownChanged: current = 0
    onResultsChanged: current = 0

    // Recently used files, from the list GTK and most other apps keep.
    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        printErrors: false
    }

    readonly property var recentAll: {
        const text = recentFile.text() ?? "";
        const out = [];
        const re = /<bookmark\s[^>]*href="([^"]+)"[^>]*modified="([^"]+)"/g;
        let m;
        while ((m = re.exec(text)) !== null)
            out.push({ href: m[1], when: new Date(m[2]), name: decodeURIComponent(m[1].split("/").pop()) });
        // ponytail: regex over the XBEL file; fine for the few hundred entries it holds.
        return out.sort((a, b) => b.when - a.when).slice(0, 200);
    }
    readonly property var recent: recentAll.slice(0, 4)

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.panelGap
        anchors.bottomMargin: Theme.panelGap
        width: 600
        height: body.implicitHeight + body.anchors.topMargin + body.anchors.bottomMargin + foot.height
        radius: Theme.radius + 4
        color: Theme.bar
        border.width: 1
        border.color: Theme.rim
        clip: true

        // Fades in and rises a few pixels; going away it does the same backwards.
        opacity: Desktop.launcherOpen ? 1 : 0
        transform: Translate {
            y: Desktop.launcherOpen || Theme.reduceMotion ? 0 : 12
            Behavior on y { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        // The panel grows and shrinks with the results instead of jumping (cmdk does the same).
        Behavior on height { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

        MouseArea { anchors.fill: parent; onClicked: win.powerMenu = false }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 22
            anchors.topMargin: 22
            anchors.bottomMargin: 14
            spacing: 14

            // Search.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 0
                implicitHeight: 46
                radius: height / 2
                color: Theme.card
                border.width: 2
                border.color: Theme.accent
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10
                    Glyph { name: "search"; size: 18; color: Theme.soft }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font { family: Theme.sans; pixelSize: 15; weight: Font.Medium }
                        onTextChanged: win.query = text
                        Text {
                            visible: !search.text
                            text: Tr.t("Search for apps, settings and files")
                            color: Theme.soft
                            font: search.font
                        }
                        Keys.onEscapePressed: if (text) text = ""; else win.close()
                        Keys.onReturnPressed: win.run()
                        Keys.onEnterPressed: win.run()
                        // In the grid, left and right step and up and down jump a row; the
                        // result list only goes up and down, so left and right stay in the text.
                        Keys.onLeftPressed: event => { if (win.query) event.accepted = false; else win.move(-1); }
                        Keys.onRightPressed: event => { if (win.query) event.accepted = false; else win.move(1); }
                        Keys.onUpPressed: win.move(win.query ? -1 : -grid.columns)
                        Keys.onDownPressed: win.move(win.query ? 1 : grid.columns)
                        Keys.onTabPressed: win.move(1)
                        Keys.onBacktabPressed: win.move(-1)
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
                visible: !win.query
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: win.allApps ? Tr.t("All apps") : Tr.t("Pinned")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold }
                }
                Chip {
                    label: win.allApps ? Tr.t("Back") : Tr.t("All apps")
                    glyph: win.allApps ? "back" : "chevron"
                    onClicked: win.allApps = !win.allApps
                }
            }

            GridView {
                id: grid
                readonly property int columns: 6
                Layout.fillWidth: true
                visible: !win.query && win.shown.length > 0
                Layout.preferredHeight: Math.min(win.allApps ? 4 : 3, Math.ceil(win.shown.length / columns)) * cellHeight
                cellWidth: width / columns
                cellHeight: 92
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
                        anchors.margins: 2
                        radius: Theme.radiusSmall
                        color: cell.pressed ? Theme.cardHover : cell.index === win.current ? Theme.card : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 50; height: 50; radius: 14
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
                            elide: Text.ElideRight
                            text: cell.modelData.name
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: 12; weight: Font.Medium }
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
                visible: win.count === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: win.query ? Tr.t("No results for “%1”.", win.query.trim()) : Tr.t("Right-click an app to pin it.")
                color: Theme.soft
                font { family: Theme.sans; pixelSize: 14 }
            }

            // Recommended files.
            RowLayout {
                visible: !win.query && !win.allApps
                Layout.fillWidth: true
                Layout.topMargin: 4
                Text {
                    Layout.fillWidth: true
                    text: Tr.t("Recommended")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold }
                }
            }

            GridLayout {
                visible: !win.query && !win.allApps
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 2

                Repeater {
                    model: win.recent
                    delegate: MouseArea {
                        id: rec
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 52
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Qt.openUrlExternally(modelData.href); win.close(); }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: rec.pressed ? Theme.cardHover : rec.containsMouse ? Theme.card : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12
                            Rectangle {
                                implicitWidth: 36; implicitHeight: 36; radius: 10
                                color: Theme.card
                                Glyph { anchors.centerIn: parent; name: "file"; size: 18; color: Theme.accent }
                            }
                            Column {
                                Layout.fillWidth: true
                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: decodeURIComponent(rec.modelData.href.split("/").pop())
                                    color: Theme.fg
                                    font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
                                }
                                Text {
                                    text: Tr.ago(rec.modelData.when)
                                    color: Theme.soft
                                    font { family: Theme.sans; pixelSize: 11 }
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
                    font { family: Theme.sans; pixelSize: 13 }
                }
            }
        }

        // Account and power.
        Rectangle {
            id: foot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 64
            color: "transparent"
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.line }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase()
                        color: Theme.accentInk
                        font { family: Theme.sans; pixelSize: 15; weight: Font.Bold }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Quickshell.env("USER") ?? ""
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
                }
            }

            MouseArea {
                id: powerBtn
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.powerMenu = !win.powerMenu
                scale: pressed ? Theme.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Rectangle {
                    anchors.fill: parent
                    radius: 19
                    color: powerBtn.containsMouse || win.powerMenu ? Theme.card : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph { anchors.centerIn: parent; name: "power"; size: 19 }
            }
        }

        // Power menu, above the power button.
        Rectangle {
            visible: win.powerMenu
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: foot.top
            anchors.bottomMargin: -4
            width: 190
            height: menu.implicitHeight + 12
            radius: Theme.radiusSmall + 2
            color: Theme.card
            border.width: 1
            border.color: Theme.line

            Column {
                id: menu
                anchors.centerIn: parent
                width: parent.width - 12
                Repeater {
                    model: win.actions.slice(0, 5)
                    delegate: MouseArea {
                        id: item
                        required property var modelData
                        width: menu.width
                        height: 38
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData[2]()
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: item.containsMouse ? Theme.win : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Glyph { name: item.modelData[0]; size: 17 }
                            Text {
                                text: item.modelData[1]
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: 14; weight: Font.Medium }
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
            height: 30
            verticalAlignment: Text.AlignBottom
            bottomPadding: 6
            leftPadding: 12
            text: row.header
            color: Theme.soft
            font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
        }
    }

    Component {
        id: resultRow
        MouseArea {
            id: res
            readonly property var row: parent.row
            readonly property bool selected: row.sel === win.current
            height: 46
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // The pointer selects, as in cmdk, so there is only ever one highlight.
            onEntered: win.current = row.sel
            onClicked: row.run()

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: res.pressed ? Theme.cardHover : res.selected ? Theme.card : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12
                Item {
                    implicitWidth: 28; implicitHeight: 28
                    IconImage {
                        visible: row.kind === "app"
                        anchors.centerIn: parent
                        implicitSize: 26
                        source: row.kind === "app" ? Quickshell.iconPath(row.icon, "application-x-executable") : ""
                    }
                    Glyph {
                        visible: row.kind !== "app"
                        anchors.centerIn: parent
                        name: row.kind === "file" ? "file" : row.glyph
                        size: 18
                        color: res.selected ? Theme.accent : Theme.soft
                    }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: row.label
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 14; weight: Font.Medium }
                }
                Text {
                    visible: !!row.detail && !res.selected
                    text: row.detail ?? ""
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: 12 }
                }
                // Enter runs the selected row.
                Rectangle {
                    visible: res.selected
                    implicitWidth: 26; implicitHeight: 22; radius: 6
                    color: Theme.win
                    border.width: 1
                    border.color: Theme.line
                    Text {
                        anchors.centerIn: parent
                        text: "↵"
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold }
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
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        scale: pressed ? Theme.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        Rectangle {
            anchors.fill: parent
            radius: 15
            color: chip.containsMouse ? Theme.cardHover : Theme.card
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            Text {
                text: chip.label
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
            }
            Glyph { anchors.verticalCenter: parent.verticalCenter; name: chip.glyph; size: 14 }
        }
    }
}
