import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Windows+V and Windows+., as on Windows 11: one panel near the pointer with three tabs,
// emoji, symbols and the clipboard history. Picking an item puts it on the clipboard and
// pastes it into the window that had the keyboard (kriss-shell-clipboard presses Ctrl+V,
// or Ctrl+Shift+V in a terminal).
//
// Keys: arrows move, Enter picks, Esc closes, Tab and Shift+Tab switch tabs. In the history,
// Delete removes an item and P pins it. In emoji, Shift+Enter, the Menu key, a long press or
// a right-click opens the skin tones; the tone picked stays for every emoji that has them.
//
// The history comes from `kriss-shell-clipboard watch` (wl-paste --watch), which sleeps
// until the clipboard changes. The list is re-read only while the panel is open.
PanelWindow {
    id: win

    property bool open: false
    property string tab: "clipboard"     // "emoji", "symbols" or "clipboard"
    property int current: 0
    property string query: ""
    property var items: []               // the history, newest first
    property bool stale: true            // the history changed while the panel was closed
    property var target: null            // the window that had the keyboard
    property bool placed: false
    // The first time, the emoji fill in once the panel has finished opening: reading them and
    // building the grid takes a few frames, which the opening animation should not wait for.
    // Both are kept after that (about 3 MB), so the panel opens at once from then on.
    property bool ready: false
    property int toneFor: -1             // the emoji whose skin tones are showing
    property int toneCurrent: 0

    readonly property var tabs: ["emoji", "symbols", "clipboard"]
    readonly property int cols: 8
    readonly property int cell: 40

    function show(which) {
        if (open && tab === which) { close(); return; }
        if (!open) {
            target = Windows.list.find(w => w.active && !w.minimized) ?? null;
            Desktop.launcherOpen = Desktop.notificationsOpen = Desktop.quickOpen = Desktop.calendarOpen = false;
            screen = Desktop.focusedScreen();
            placed = false;
            fallback.restart();
        }
        setTab(which);
        if (!open && !ready) settle.restart();
        open = true;
        if (stale) refresh();
    }

    function close() {
        open = false;
        toneFor = -1;
        keys.forceActiveFocus();  // no blinking text cursor while hidden
    }

    function setTab(which) {
        tab = which;
        current = 0;
        toneFor = -1;
        search.text = "";
        if (which !== "clipboard") emojiFile.wanted = true;
        (which === "clipboard" ? keys : search).forceActiveFocus();
    }

    // A screen reader stays on the search field or the key catcher: it hears the tab, the
    // item or emoji the keys reach, and the skin tone.
    readonly property string spoken: !open ? ""
        : toneFor >= 0 ? Tr.t("Skin tone %1 of 6", toneCurrent + 1)
        : tab === "clipboard" ? (items[current] ? (items[current].text?.trim() || Tr.t("Picture")) + (items[current].pinned ? ", " + Tr.t("pinned") : "") : Tr.t("Nothing here yet"))
        : view.flat[current]?.[1] ?? ""
    onSpokenChanged: if (spoken) (tab === "clipboard" ? keys : search).Accessible.announce(spoken)
    onTabChanged: if (open) (tab === "clipboard" ? keys : search).Accessible.announce(tab === "emoji" ? Tr.t("Emoji") : tab === "symbols" ? Tr.t("Symbols") : Tr.t("Clipboard history"))

    function stepTab(by) {
        setTab(tabs[(tabs.indexOf(tab) + by + tabs.length) % tabs.length]);
    }

    // Near the pointer, as Windows puts it near the text cursor (which no Wayland client can
    // see). Without a pointer position, above the middle of the taskbar.
    function place(x, y) {
        if (placed) return;
        placed = true;
        panel.x = Math.max(Theme.gap, Math.min(width - panel.width - Theme.gap, x === undefined ? (width - panel.width) / 2 : x - panel.width / 2));
        panel.y = y === undefined ? height - Desktop.bottomRoom - Theme.panelGap - panel.height
            : y + 24 + panel.height <= height - Desktop.bottomRoom ? y + 24 : Math.max(Theme.gap, y - panel.height - 24);
    }

    readonly property string helperCmd: "kriss-shell-clipboard"

    function refresh() {
        stale = false;
        lister.running = true;
    }

    function run(...args) {
        Quickshell.execDetached([helperCmd, ...args]);
    }

    // Close first, so the keyboard goes back to the window, then paste into it.
    function paste(copy, args) {
        const t = win.target;
        close();
        const term = t && /term|kitty|alacritty|foot|konsole|wezterm|ghostty|tilix|terminator/i.test(t.appId);
        const pasteCmd = t ? ' && sleep 0.15 && "$0" paste' + (term ? " terminal" : "") : "";
        Quickshell.execDetached(["sh", "-c", copy + pasteCmd, helperCmd, ...args]);
    }

    function pickItem(i) {
        const it = items[i];
        if (it) paste('"$0" copy "$1"', [it.id]);
    }

    function pickEmoji(i, tone) {
        const e = view.flat[i];
        if (!e) return;
        if (tone !== undefined) saved.tone = tone;
        const ch = e[3] ? toned(e[0], saved.tone) : e[0];
        saved.recent = [e[0]].concat(saved.recent.filter(r => r !== e[0])).slice(0, 24);
        paste('wl-copy -- "$1"', [ch]);
    }

    function remove(i) {
        const it = items[i];
        if (!it) return;
        items = items.filter(x => x !== it);
        current = Math.min(current, items.length - 1);
        run("delete", it.id);
    }

    function togglePin(i) {
        const it = items[i];
        if (!it) return;
        items = items.map(x => x === it ? Object.assign({}, x, { pinned: !x.pinned }) : x);
        run(it.pinned ? "unpin" : "pin", it.id);
    }

    function clearAll() {
        items = items.filter(x => x.pinned);
        current = 0;
        run("clear");
    }

    // An emoji with a skin tone: the modifier goes after the first character (gemoji's rule),
    // taking the place of a variation selector there.
    readonly property var tones: ["", "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"]
    function toned(ch, t) {
        if (!t) return ch;
        const first = String.fromCodePoint(ch.codePointAt(0));
        const rest = ch.slice(first.length);
        return first + tones[t] + (rest[0] === "\uFE0F" ? rest.slice(1) : rest);
    }

    readonly property var groupNames: ({
        "Smileys & Emotion": Tr.t("Smileys & Emotion"),
        "People & Body": Tr.t("People & Body"),
        "Animals & Nature": Tr.t("Animals & Nature"),
        "Food & Drink": Tr.t("Food & Drink"),
        "Travel & Places": Tr.t("Travel & Places"),
        "Activities": Tr.t("Activities"),
        "Objects": Tr.t("Objects"),
        "Symbols": Tr.t("Symbols"),
        "Flags": Tr.t("Flags"),
        "Arrows": Tr.t("Arrows"),
        "Currency": Tr.t("Currency"),
        "Maths": Tr.t("Maths"),
        "Latin": Tr.t("Letters with accents"),
        "Punctuation": Tr.t("Punctuation")
    })

    // The emoji or symbol grid: rows of a header or up to `cols` cells, the cells in one flat
    // list (what `current` counts), and each cell's row and column for up and down.
    property var emoji: []  // emoji.json: [[group, [[char, name, " words", tones], ...]], ...]
    readonly property var view: {
        const rows = [], flat = [], pos = [];
        if (tab === "clipboard" || !emoji.length) return { rows, flat, pos };
        const groups = tab === "emoji" ? emoji.slice(0, 9) : emoji.slice(9);
        const every = [].concat(...groups.map(g => g[1]));  // Qt's JavaScript has no flatMap
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        const add = (name, list) => {
            if (!list.length) return;
            if (name) rows.push({ header: name });
            for (let i = 0; i < list.length; i += cols) {
                const row = list.slice(i, i + cols).map((e, c) => {
                    pos.push({ row: rows.length, col: c });
                    flat.push(e);
                    return { e, i: flat.length - 1 };
                });
                rows.push({ cells: row });
            }
        };
        if (words.length) {
            // Each word matches the start of one of its words (they are stored " a b c").
            add("", every.filter(e => words.every(w => e[2].includes(" " + w))));
        } else {
            if (tab === "emoji") {
                const byChar = new Map(every.map(e => [e[0], e]));
                add(Tr.t("Recently used"), saved.recent.map(c => byChar.get(c)).filter(e => e));
            }
            for (const g of groups) add(groupNames[g[0]] ?? g[0], g[1]);
        }
        return { rows, flat, pos };
    }
    readonly property int count: tab === "clipboard" ? items.length : view.flat.length

    // Arrows: across the grid, or down the history.
    function move(dx, dy) {
        if (count === 0) return;
        if (tab === "clipboard" || dy === 0) {
            current = Math.max(0, Math.min(count - 1, current + dx + dy));
        } else {
            const p = view.pos[current];
            let r = p.row + dy;
            while (view.rows[r] && view.rows[r].header) r += dy;
            const row = view.rows[r];
            if (!row) return;
            current = row.cells[Math.min(p.col, row.cells.length - 1)].i;
        }
        if (tab === "clipboard") history.positionViewAtIndex(current, ListView.Contain);
        else grid.positionViewAtIndex(Math.max(0, view.pos[current].row - (dy < 0 && view.rows[view.pos[current].row - 1]?.header ? 1 : 0)), ListView.Contain);
    }

    function showTones(i) {
        if (!view.flat[i]?.[3]) return;
        current = i;
        toneFor = i;
        toneCurrent = saved.tone;
    }

    // Recent emoji and the skin tone, in $XDG_STATE_HOME/kriss/emoji.json.
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/kriss/emoji.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: saved
            property list<string> recent: []
            property int tone: 0
        }
    }

    // The emoji data, read the first time an emoji or symbol tab opens.
    FileView {
        id: emojiFile
        property bool wanted: false
        path: wanted ? Quickshell.shellPath("emoji.json") : ""
        printErrors: false
        onLoaded: win.emoji = JSON.parse(text())
    }

    Process {
        id: watcher
        command: [win.helperCmd, "watch"]
        running: true
        stdout: SplitParser {
            onRead: _ => { if (win.open) win.refresh(); else win.stale = true; }
        }
        // ponytail: restart forever with a fixed delay, like kriss-shell-toplevels.
        onExited: (code, status) => restartWatcher.start()
    }
    Timer { id: restartWatcher; interval: 2000; onTriggered: watcher.running = true }

    Process {
        id: lister
        command: [win.helperCmd, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.items = JSON.parse(text);
                } catch (e) {
                    console.warn("kriss-shell-clipboard list:", text);
                }
                win.current = Math.min(win.current, Math.max(0, win.items.length - 1));
            }
        }
    }

    Timer { id: fallback; interval: 60; onTriggered: win.place() }
    Timer { id: settle; interval: Theme.ms(Theme.normal) + 60; onTriggered: win.ready = true }

    visible: open
    screen: Desktop.screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-clipboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    // A click off the panel closes it; the first pointer position places it.
    MouseArea {
        Accessible.ignored: true  // pointer only; the keyboard has its own way
        anchors.fill: parent
        hoverEnabled: !win.placed
        acceptedButtons: Qt.AllButtons
        onPositionChanged: mouse => win.place(mouse.x, mouse.y)
        onPressed: win.close()
    }

    Rectangle {
        id: panel
        width: win.cols * win.cell + 32
        height: 460
        radius: Theme.rPanel
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.rim
        clip: true
        Accessible.role: Accessible.Dialog
        Accessible.name: Tr.t("Clipboard, emoji and symbols")

        opacity: win.open && win.placed ? 1 : 0
        scale: win.open && win.placed || Theme.reduceMotion ? 1 : 0.96
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.ms(win.open ? Theme.fast : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(win.open ? Theme.normal : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; Accessible.ignored: true }

        // The history's keys. The emoji tabs take theirs in the search field.
        Item {
            id: keys
            Accessible.role: Accessible.List
            Accessible.name: Tr.t("Clipboard history")
            Accessible.description: Tr.t("Enter pastes, Delete removes, P pins, Tab changes tab")
            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                switch (event.key) {
                case Qt.Key_Up: win.move(-1, 0); break;
                case Qt.Key_Down: win.move(1, 0); break;
                case Qt.Key_Home: win.current = 0; history.positionViewAtBeginning(); break;
                case Qt.Key_End: win.current = Math.max(0, win.count - 1); history.positionViewAtEnd(); break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.pickItem(win.current); break;
                case Qt.Key_Delete: case Qt.Key_Backspace: win.remove(win.current); break;
                case Qt.Key_P: if (!ctrl) win.togglePin(win.current); break;
                case Qt.Key_Escape: win.close(); break;
                case Qt.Key_Tab: win.stepTab(1); break;
                case Qt.Key_Backtab: win.stepTab(-1); break;
                default: return;
                }
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s4
            spacing: Theme.s3

            // The tabs.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s1
                Repeater {
                    model: [["emoji", "smile", Tr.t("Emoji")], ["symbols", "omega", Tr.t("Symbols")], ["clipboard", "clipboard", Tr.t("Clipboard")]]
                    delegate: MouseArea {
                        id: tabBtn
                        required property var modelData
                        readonly property bool on: win.tab === modelData[0]
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 36
                        hoverEnabled: true
                        onClicked: win.setTab(modelData[0])
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData[2]
                        Accessible.selected: on
                        Accessible.onPressAction: win.setTab(modelData[0])
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rControl
                            color: tabBtn.on || tabBtn.containsMouse ? Theme.cardHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast) } }
                        }
                        Glyph { anchors.centerIn: parent; name: tabBtn.modelData[1]; size: 20; color: tabBtn.on ? Theme.accent : Theme.fg }
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.s0 }
                            width: tabBtn.on ? 16 : 0
                            height: 3
                            radius: height / 2
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: !clearBtn.visible
                    text: win.tab === "emoji" ? Tr.t("Emoji") : win.tab === "symbols" ? Tr.t("Symbols") : Tr.t("Clipboard history")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
                }
                MouseArea {
                    id: clearBtn
                    visible: win.tab === "clipboard" && win.items.some(x => !x.pinned)
                    implicitWidth: clearText.implicitWidth + 24
                    implicitHeight: Math.max(30, clearText.implicitHeight + 10)
                    hoverEnabled: true
                    onClicked: win.clearAll()
                    Accessible.onPressAction: win.clearAll()
                    Accessible.role: Accessible.Button
                    Accessible.name: clearText.text
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: clearBtn.containsMouse ? Theme.cardHover : Theme.card
                        scale: clearBtn.pressed ? Theme.pressScale : 1
                        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: Tr.t("Clear all")
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.Medium }
                    }
                }
            }

            // Search, for emoji and symbols.
            Rectangle {
                visible: win.tab !== "clipboard"
                Layout.fillWidth: true
                implicitHeight: Math.max(40, search.implicitHeight + 16)
                radius: height / 2
                color: Theme.card
                border.width: search.activeFocus ? Theme.focusWidth : Theme.rimWidth
                border.color: search.activeFocus ? Theme.accent : Theme.line
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s3
                    anchors.rightMargin: Theme.s3
                    spacing: Theme.s2
                    Glyph { name: "search"; size: 16; color: Theme.soft }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.fg
                        clip: true
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                        Accessible.role: Accessible.EditableText
                        Accessible.name: win.tab === "emoji" ? Tr.t("Search emoji") : Tr.t("Search symbols")
                        Accessible.description: Tr.t("Arrows choose, Enter pastes, Tab changes tab")
                        onTextChanged: { win.query = text; win.current = 0; win.toneFor = -1; grid.positionViewAtBeginning(); }
                        Text {
                            visible: !search.text
                            text: win.tab === "emoji" ? Tr.t("Search emoji") : Tr.t("Search symbols")
                            color: Theme.soft
                            font: search.font
                        }
                        Keys.onPressed: event => {
                            const t = win.toneFor >= 0;
                            switch (event.key) {
                            case Qt.Key_Left: if (t) win.toneCurrent = Math.max(0, win.toneCurrent - 1); else win.move(-1, 0); break;
                            case Qt.Key_Right: if (t) win.toneCurrent = Math.min(5, win.toneCurrent + 1); else win.move(1, 0); break;
                            case Qt.Key_Up: if (!t) win.move(0, -1); break;
                            case Qt.Key_Down: if (!t) win.move(0, 1); break;
                            case Qt.Key_Return: case Qt.Key_Enter:
                                if (t) win.pickEmoji(win.toneFor, win.toneCurrent);
                                else if (event.modifiers & Qt.ShiftModifier && win.view.flat[win.current]?.[3]) win.showTones(win.current);
                                else win.pickEmoji(win.current);
                                break;
                            case Qt.Key_Menu: win.showTones(win.current); break;
                            case Qt.Key_Escape:
                                if (t) win.toneFor = -1; else if (search.text) search.text = ""; else win.close();
                                break;
                            case Qt.Key_Tab: win.stepTab(1); break;
                            case Qt.Key_Backtab: win.stepTab(-1); break;
                            default: return;
                            }
                            event.accepted = true;
                        }
                    }
                }
            }

            // Emoji and symbols.
            ListView {
                id: grid
                visible: win.tab !== "clipboard"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.ready ? win.view.rows : []
                cacheBuffer: 200
                delegate: Item {
                    id: row
                    required property var modelData
                    width: grid.width
                    height: modelData.header ? Math.max(30, Theme.sp(12) + 16) : win.cell
                    Text {
                        visible: !!row.modelData.header
                        anchors { left: parent.left; leftMargin: Theme.s1; bottom: parent.bottom; bottomMargin: Theme.s1 }
                        text: row.modelData.header ?? ""
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                    }
                    Row {
                        visible: !row.modelData.header
                        Repeater {
                            model: row.modelData.cells ?? []
                            delegate: MouseArea {
                                id: cellBtn
                                required property var modelData
                                readonly property bool on: win.current === modelData.i
                                width: win.cell
                                height: win.cell
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.e[1]
                                Accessible.selected: on
                                Accessible.onPressAction: win.pickEmoji(modelData.i)
                                onEntered: if (win.toneFor < 0) win.current = modelData.i
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) win.showTones(modelData.i);
                                    else win.pickEmoji(modelData.i);
                                }
                                onPressAndHold: win.showTones(modelData.i)
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Theme.s0
                                    radius: Theme.rControl
                                    color: cellBtn.on ? Theme.cardHover : "transparent"
                                    border.width: cellBtn.on && search.activeFocus ? Theme.focusWidth : 0
                                    border.color: Theme.accent
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: cellBtn.modelData.e[3] ? win.toned(cellBtn.modelData.e[0], saved.tone) : cellBtn.modelData.e[0]
                                    color: Theme.fg
                                    font { family: win.tab === "emoji" ? "Noto Color Emoji" : Theme.sans; pixelSize: win.tab === "emoji" ? 24 : 20 }
                                    scale: cellBtn.pressed ? Theme.pressScale : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: win.emoji.length > 0 && win.view.flat.length === 0
                    text: Tr.t("No results")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(14) }
                }
            }

            // The clipboard history.
            ListView {
                id: history
                visible: win.tab === "clipboard"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.s2
                boundsBehavior: Flickable.StopAtBounds
                model: win.items
                currentIndex: win.current
                highlightFollowsCurrentItem: false

                delegate: MouseArea {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool on: win.current === index
                    width: history.width
                    height: Math.max(48, (modelData.image ? thumb.height : body.implicitHeight) + 24)
                    hoverEnabled: true
                    onEntered: win.current = index
                    onClicked: win.pickItem(index)
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.text ?? Tr.t("Picture")
                    Accessible.description: modelData.pinned ? Tr.t("pinned") : ""
                    Accessible.selected: on
                    Accessible.onPressAction: win.pickItem(index)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rCard
                        color: entry.on ? Theme.cardHover : Theme.card
                        border.width: entry.on ? Theme.focusWidth : Theme.high ? Theme.rimWidth : 0
                        border.color: entry.on ? Theme.accent : Theme.line
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast) } }
                    }
                    Text {
                        id: body
                        visible: !entry.modelData.image
                        anchors { left: parent.left; right: tools.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.s3; rightMargin: Theme.s2 }
                        text: (entry.modelData.text ?? "").trim()
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(13) }
                    }
                    Image {
                        id: thumb
                        visible: !!entry.modelData.image
                        anchors { left: parent.left; top: parent.top; margins: Theme.s3 }
                        width: Math.min(implicitWidth, parent.width - 24 - tools.width)
                        height: Math.min(implicitHeight, 110)
                        source: entry.modelData.image ? "file://" + entry.modelData.image : ""
                        sourceSize.height: 220
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignLeft
                        asynchronous: true
                        smooth: true
                    }
                    Row {
                        id: tools
                        anchors { right: parent.right; top: parent.top; margins: Theme.s2 }
                        spacing: Theme.s0
                        Repeater {
                            model: [
                                [entry.modelData.pinned ? "unpin" : "pin", entry.modelData.pinned ? Tr.t("Unpin") : Tr.t("Pin"), () => win.togglePin(entry.index)],
                                ["trash", Tr.t("Delete"), () => win.remove(entry.index)]
                            ]
                            delegate: MouseArea {
                                id: tool
                                required property var modelData
                                width: 32
                                height: 32
                                hoverEnabled: true
                                // The pin stays shown on a pinned item; the rest only on the current one.
                                opacity: entry.on || index === 0 && entry.modelData.pinned ? 1 : 0
                                required property int index
                                onClicked: modelData[2]()
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData[1]
                                Accessible.onPressAction: modelData[2]()
                                Rectangle { anchors.fill: parent; radius: Theme.rControl; color: tool.containsMouse ? Theme.cardHover : "transparent" }
                                Glyph {
                                    anchors.centerIn: parent
                                    name: tool.index === 0 ? "pin" : "trash"
                                    size: 16
                                    color: tool.index === 0 && entry.modelData.pinned ? Theme.accent : Theme.fg
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    visible: win.items.length === 0
                    spacing: Theme.s2
                    Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: "clipboard"; size: 32; color: Theme.soft }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Tr.t("Nothing here yet")
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: Tr.t("Copy text or a picture and it shows up here.")
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(13) }
                    }
                }
            }
        }

        // Skin tones for one emoji, over the grid.
        Rectangle {
            visible: win.toneFor >= 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.s4
            width: toneRow.implicitWidth + 16
            height: win.cell + 16
            radius: Theme.rCard
            color: Theme.card
            border.width: Theme.rimWidth
            border.color: Theme.line
            Accessible.role: Accessible.Grouping
            Accessible.name: Tr.t("Skin tone")
            Row {
                id: toneRow
                anchors.centerIn: parent
                Repeater {
                    model: 6
                    delegate: MouseArea {
                        id: toneBtn
                        required property int index
                        width: win.cell
                        height: win.cell
                        hoverEnabled: true
                        onEntered: win.toneCurrent = index
                        onClicked: win.pickEmoji(win.toneFor, index)
                        Accessible.role: Accessible.Button
                        Accessible.name: Tr.t("Skin tone %1 of 6", index + 1)
                        Accessible.onPressAction: win.pickEmoji(win.toneFor, index)
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Theme.s0
                            radius: Theme.rControl
                            color: win.toneCurrent === toneBtn.index ? Theme.cardHover : "transparent"
                            border.width: win.toneCurrent === toneBtn.index ? Theme.focusWidth : 0
                            border.color: Theme.accent
                        }
                        Text {
                            anchors.centerIn: parent
                            text: win.toneFor >= 0 ? win.toned(win.view.flat[win.toneFor]?.[0] ?? "", toneBtn.index) : ""
                            font { family: "Noto Color Emoji"; pixelSize: 24 }
                        }
                    }
                }
            }
        }
    }
}
