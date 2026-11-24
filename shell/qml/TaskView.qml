import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Task View (Windows+Tab), as on Windows 11: each screen's windows as live pictures over the
// blurred desktop, and that screen's desktops along the bottom. Click a window or press Enter
// to switch to it; arrows move between windows; Esc or a click on the background leaves.
// Rest the pointer on a desktop to see its windows, click it to switch, drag a window onto it
// to move the window there, right-click it to rename or close it. From the keyboard, Tab
// moves between the windows and the desktops; on a desktop Enter switches, F2 renames,
// Delete closes and the Menu key opens its menu. Pictures are captured only
// while Task View is open, by kriss-shell-toplevels.
Scope {
    id: tv

    readonly property bool open: Desktop.taskViewOpen

    // One capture list for every screen: the windows each one shows, at the largest card size.
    readonly property var capturing: open ? panes.instances.reduce((a, p) => a.concat(p.wins.map(w => w.id)), []) : []
    readonly property int capturePx: open ? Math.max(0, ...panes.instances.map(p => p.thumbPx)) : 0
    readonly property string captureKey: capturePx + " " + capturing.join(" ")
    onCaptureKeyChanged: Windows.capture(capturing, capturePx)

    // Cards for these aspect ratios (width / height of the picture) in rows of one height
    // inside w × h, each with a `head` tall title above it: the row count that gives the
    // biggest pictures wins. [{x, y, w, h}], h including the title.
    function layout(aspects, w, h, head, gap) {
        const n = aspects.length;
        let best = null;
        for (let rows = 1; rows <= n; rows++) {
            const per = Math.ceil(n / rows), lines = [];
            for (let i = 0; i < n; i += per) lines.push(aspects.slice(i, i + per));
            let size = Math.min(h * 0.6, (h - (lines.length - 1) * gap) / lines.length - head);
            for (const l of lines)
                size = Math.min(size, (w - (l.length - 1) * gap) / l.reduce((s, a) => s + a, 0));
            if (!best || size > best.size) best = { size: size, lines: lines };
        }
        if (!best) return [];
        const out = [], rowH = best.size + head;
        let y = (h - best.lines.length * rowH - (best.lines.length - 1) * gap) / 2;
        for (const l of best.lines) {
            let x = (w - l.reduce((s, a) => s + a * best.size, 0) - (l.length - 1) * gap) / 2;
            for (const a of l) {
                out.push({ x: x, y: y, w: a * best.size, h: rowH });
                x += a * best.size + gap;
            }
            y += rowH + gap;
        }
        return out;
    }

    Variants {
        id: panes
        model: Quickshell.screens

        PanelWindow {
            id: pane
            required property var modelData
            screen: modelData

            // This screen's desktops. cosmic-comp keeps one empty desktop at the end, ready to
            // use: it stays out of the strip until "New desktop" shows it or it is in use.
            readonly property var desks: Windows.desktopsOn(screen.name)
            property bool revealed: false
            readonly property var strip: {
                const last = desks[desks.length - 1];
                const spare = last && !last.active && !revealed && !Windows.list.some(w => w.workspace === last.id);
                return spare ? desks.slice(0, -1) : desks;
            }
            readonly property bool canAdd: strip.length < desks.length
            // The desktop whose windows show: the one last pointed at in the strip, else the current one.
            property int pointed: 0
            readonly property int shown: desks.some(d => d.id === pointed) ? pointed : (desks.find(d => d.active)?.id ?? 0)
            // Its windows, most recently used first. Without desktops from the compositor: the screen's.
            readonly property var wins: Windows.byRecent.filter(w => shown ? w.workspace === shown : w.output === screen.name)

            property int current: 0
            property int renaming: -1
            // The keyboard is on the desktops strip, at deskCurrent.
            property bool inDesks: false
            property int deskCurrent: 0
            readonly property int deskCount: strip.length + (canAdd ? 1 : 0)
            // A screen reader stays on the key catcher; it hears the window or desktop picked.
            readonly property string spoken: inDesks
                ? (deskCurrent >= strip.length ? Tr.t("New desktop") : deskName(deskCurrent) + (strip[deskCurrent]?.active ? ", " + Tr.t("current") : ""))
                : (wins[current]?.title || wins[current]?.appId || "")
            onSpokenChanged: if (tv.open && spoken) keys.Accessible.announce(spoken)
            // Enter, or the Menu key (menu), on desktop i.
            function deskAct(i, asMenu, from) {
                const add = i >= strip.length, d = add ? desks[desks.length - 1] : strip[i];
                if (add) { revealed = true; return; }
                if (asMenu) {
                    menu.show(from, [
                        { text: Tr.t("Rename"), glyph: "edit", run: () => renaming = i },
                        { text: Tr.t("Close desktop"), glyph: "close", off: strip.length < 2, run: () => Windows.closeDesktop(d.id) }
                    ], from === keys);
                    return;
                }
                if (d) Windows.switchTo(d.id);
                Desktop.taskViewOpen = false;
            }
            property var aspects: ({})
            readonly property int head: 36
            readonly property var boxes: tv.layout(wins.map(w => aspects[w.id] ?? 1.6), grid.width, grid.height, head, 24)
            readonly property int thumbPx: Math.ceil(Math.max(0, ...boxes.map(b => b.w)) * (screen?.devicePixelRatio ?? 1))

            function setAspect(id, a) {
                if (Math.abs((aspects[id] ?? 0) - a) < 0.02) return;
                aspects = Object.assign({}, aspects, { [id]: Math.max(0.5, Math.min(2.6, a)) });
            }
            function pick(w) {
                if (w) Windows.activate(w.id);
                Desktop.taskViewOpen = false;
            }
            // Up and down: the card in the next row whose middle is closest.
            function vertical(d) {
                const b = boxes[current];
                if (!b) return;
                let best = -1, dist = 1e9;
                boxes.forEach((o, i) => {
                    if (d * (o.y - b.y) <= 0) return;
                    const s = Math.abs(o.y - b.y) * 4 + Math.abs(o.x + o.w / 2 - b.x - b.w / 2);
                    if (s < dist) { dist = s; best = i; }
                });
                if (best >= 0) current = best;
            }
            function deskName(i) {
                return Desktop.desktopNames[i] || Tr.t("Desktop %1", i + 1);
            }
            function rename(i, text) {
                const names = Desktop.desktopNames.slice();
                while (names.length <= i) names.push("");
                names[i] = text.trim();
                while (names.length && !names[names.length - 1]) names.pop();
                Desktop.desktopNames = names;
                renaming = -1;
                keys.forceActiveFocus();
            }

            Connections {
                target: tv
                function onOpenChanged() {
                    pane.pointed = 0;
                    pane.revealed = false;
                    pane.renaming = -1;
                    pane.inDesks = false;
                    pane.current = Math.max(0, pane.wins.findIndex(w => w.active && !w.minimized));
                    if (tv.open && Desktop.screen === pane.screen) keys.forceActiveFocus();
                }
            }
            onWinsChanged: current = Math.max(0, Math.min(current, wins.length - 1))

            visible: tv.open || backdrop.opacity > 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-taskview"
            WlrLayershell.keyboardFocus: tv.open && Desktop.screen === screen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Above everything but the taskbar, which stays usable, as on Windows.
            exclusionMode: ExclusionMode.Normal
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: tv.open ? null : noInput
            Region { id: noInput }
            BackgroundEffect.blurRegion: Region { item: backdrop }

            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Theme.high ? Theme.night : Theme.alpha(Theme.night, Theme.dark ? 0.55 : 0.35)
                opacity: tv.open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(tv.open ? Theme.normal : Theme.fastExit); easing.type: tv.open ? Theme.ease : Theme.easeExit } }
            }

            MouseArea {
                Accessible.ignored: true  // pointer only; the keyboard has its own way
                anchors.fill: parent
                onClicked: Desktop.taskViewOpen = false
            }

            Item {
                id: content
                anchors.fill: parent
                opacity: backdrop.opacity
                scale: tv.open || Theme.reduceMotion ? 1 : 0.96
                Behavior on scale { NumberAnimation { duration: Theme.ms(tv.open ? Theme.normal : Theme.fastExit); easing.type: tv.open ? Theme.ease : Theme.easeExit } }

                Item {
                    id: keys
                    focus: true
                    Accessible.role: Accessible.Dialog
                    Accessible.name: Tr.t("Task View")
                    Accessible.description: Tr.t("Arrows choose a window, Enter switches to it, Tab goes to the desktops")
                    Keys.onPressed: event => {
                        const n = pane.wins.length;
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            pane.inDesks = !pane.inDesks || n === 0;
                            if (pane.inDesks) pane.deskCurrent = Math.max(0, pane.strip.findIndex(d => d.active));
                            event.accepted = true;
                            return;
                        }
                        if (pane.inDesks) {
                            const m = pane.deskCount, i = pane.deskCurrent;
                            const menuKey = event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier;
                            if (menuKey) pane.deskAct(i, true, keys);
                            else switch (event.key) {
                            case Qt.Key_Escape: Desktop.back("taskViewOpen"); break;
                            case Qt.Key_Left: pane.deskCurrent = Math.max(0, i - 1); break;
                            case Qt.Key_Right: pane.deskCurrent = Math.min(m - 1, i + 1); break;
                            case Qt.Key_Home: pane.deskCurrent = 0; break;
                            case Qt.Key_End: pane.deskCurrent = m - 1; break;
                            case Qt.Key_Up: if (n) pane.inDesks = false; break;
                            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: pane.deskAct(i, false); break;
                            case Qt.Key_F2: if (i < pane.strip.length) pane.renaming = i; break;
                            case Qt.Key_Delete: if (i < pane.strip.length && pane.strip.length > 1) Windows.closeDesktop(pane.strip[i].id); break;
                            default: return;
                            }
                            deskRow.positionViewAtIndex(pane.deskCurrent, ListView.Contain);
                            event.accepted = true;
                            return;
                        }
                        switch (event.key) {
                        case Qt.Key_Escape: Desktop.back("taskViewOpen"); break;
                        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: pane.pick(pane.wins[pane.current]); break;
                        case Qt.Key_Right: pane.current = Math.min(n - 1, pane.current + 1); break;
                        case Qt.Key_Left: pane.current = Math.max(0, pane.current - 1); break;
                        case Qt.Key_Down: { const c = pane.current; pane.vertical(1); if (c === pane.current) pane.inDesks = true; break; }
                        case Qt.Key_Up: pane.vertical(-1); break;
                        case Qt.Key_Home: pane.current = 0; break;
                        case Qt.Key_End: pane.current = Math.max(0, n - 1); break;
                        case Qt.Key_Delete: if (pane.wins[pane.current]) Windows.close(pane.wins[pane.current].id); break;
                        default: return;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.centerIn: grid
                    visible: pane.wins.length === 0
                    text: Tr.t("No windows open on this desktop")
                    color: Theme.nightFg
                    opacity: 0.7
                    font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.Medium }
                }

                Item {
                    id: grid
                    z: 1  // a card being dragged passes over the desktops
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: deskRow.top }
                    anchors.margins: 48
                    anchors.bottomMargin: 32

                    Repeater {
                        // By position, so a title or focus change updates a card instead of rebuilding it.
                        model: pane.wins.length

                        delegate: Item {
                            id: card
                            required property int index
                            readonly property var w: pane.wins[index]
                            readonly property var box: pane.boxes[index] ?? { x: 0, y: 0, w: 0, h: 0 }
                            readonly property var entry: Windows.entryFor(w?.appId ?? "")
                            readonly property bool lit: pane.current === index && !pane.inDesks
                            Accessible.role: Accessible.ListItem
                            Accessible.name: w?.title || entry?.name || w?.appId || ""
                            Accessible.description: entry?.name ?? ""
                            Accessible.selected: lit
                            Accessible.onPressAction: pane.pick(w)

                            x: box.x; y: box.y; width: box.w; height: box.h
                            z: drag.drag.active ? 10 : 0
                            Behavior on x { enabled: tv.open; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                            Behavior on y { enabled: tv.open; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                            Behavior on width { enabled: tv.open; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                            Behavior on height { enabled: tv.open; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }

                            MouseArea {
                                Accessible.ignored: true  // pointer only; the keyboard has its own way
                                id: drag
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                drag.target: body
                                onEntered: pane.current = card.index
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) { if (card.w) Windows.close(card.w.id); }
                                    else pane.pick(card.w);
                                }
                                onReleased: {
                                    if (body.Drag.active) body.Drag.drop();
                                    body.x = body.y = 0;
                                }
                            }

                            Rectangle {
                                id: body
                                readonly property int wid: card.w?.id ?? 0
                                width: parent.width
                                height: parent.height
                                radius: Theme.rCard
                                color: drag.pressed || drag.containsMouse ? Theme.cardHover : Theme.card
                                border.width: Theme.focusWidth
                                border.color: card.lit ? Theme.accentText : Theme.high ? Theme.rim : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                Behavior on x { enabled: !drag.drag.active; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                                Behavior on y { enabled: !drag.drag.active; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
                                // Picked up, the card shrinks to about a desktop's size.
                                scale: drag.drag.active ? Math.min(1, 200 / Math.max(1, width)) : 1
                                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                Drag.active: drag.drag.active
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                IconImage {
                                    id: icon
                                    x: 12; y: (pane.head - implicitSize) / 2 + 2
                                    implicitSize: 18
                                    source: Quickshell.iconPath(card.entry?.icon ?? card.w?.appId ?? "", "application-x-executable")
                                }
                                Text {
                                    anchors { left: icon.right; leftMargin: Theme.s2; right: close.left; rightMargin: Theme.s1; verticalCenter: icon.verticalCenter }
                                    text: card.w?.title || card.entry?.name || card.w?.appId || ""
                                    elide: Text.ElideRight
                                    color: Theme.fg
                                    font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.Medium }
                                }
                                MouseArea {
                                    id: close
                                    x: parent.width - width - 4; y: 4
                                    width: 28; height: 28
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    opacity: drag.containsMouse || containsMouse ? 1 : 0
                                    enabled: opacity > 0
                                    onClicked: if (card.w) Windows.close(card.w.id)
                                    Accessible.role: Accessible.Button
                                    Accessible.name: Tr.t("Close window")
                                    Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.rSmall
                                        color: close.containsMouse ? Theme.red : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                    }
                                    Glyph { anchors.centerIn: parent; name: "close"; size: 14; color: close.containsMouse ? Theme.nightFg : Theme.fg }
                                }

                                // The live picture, or the app's icon until there is one.
                                Item {
                                    x: 6; y: pane.head
                                    width: parent.width - 12
                                    height: parent.height - pane.head - 6
                                    Image {
                                        id: thumb
                                        anchors.fill: parent
                                        source: card.w ? Windows.thumbs[card.w.id] ?? "" : ""
                                        fillMode: Image.PreserveAspectFit
                                        cache: false
                                        asynchronous: false
                                        smooth: true
                                        mipmap: true
                                        opacity: card.w?.minimized ? 0.6 : 1
                                        onStatusChanged: if (status === Image.Ready && card.w && implicitHeight > 0)
                                            pane.setAspect(card.w.id, implicitWidth / implicitHeight)
                                    }
                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: thumb.status !== Image.Ready
                                        implicitSize: Math.min(64, parent.height / 2)
                                        source: icon.source
                                    }
                                }
                            }
                        }
                    }
                }

                // The desktops.
                ListView {
                    id: deskRow
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.s6 }
                    width: Math.min(contentWidth, parent.width - 96)
                    height: 140
                    orientation: ListView.Horizontal
                    spacing: Theme.s3
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: pane.strip.length + (pane.canAdd ? 1 : 0)
                    readonly property real tileW: 176
                    readonly property real tileH: Math.round(tileW * (pane.screen?.height ?? 9) / Math.max(1, pane.screen?.width ?? 16))

                    delegate: DropArea {
                        id: desk
                        required property int index
                        readonly property bool add: index >= pane.strip.length
                        // "New desktop" stands for the spare desktop cosmic-comp keeps at the end.
                        readonly property var d: add ? pane.desks[pane.desks.length - 1] : pane.strip[index]
                        readonly property var deskWins: Windows.list.filter(w => d && w.workspace === d.id)
                        width: deskRow.tileW + 16
                        height: deskRow.height

                        onDropped: drop => { if (d && drop.source?.wid) Windows.moveTo(drop.source.wid, d.id); }

                        MouseArea {
                            id: deskArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!desk.add && desk.d) pane.pointed = desk.d.id
                            onClicked: mouse => pane.deskAct(desk.index, mouse.button === Qt.RightButton, tile)
                            Accessible.role: Accessible.ListItem
                            Accessible.name: desk.add ? Tr.t("New desktop") : pane.deskName(desk.index)
                            Accessible.description: desk.add ? "" : desk.deskWins.length === 1 ? Tr.t("1 window") : Tr.t("%1 windows", desk.deskWins.length)
                            Accessible.selected: !desk.add && (desk.d?.active ?? false)
                            Accessible.onPressAction: pane.deskAct(desk.index, false)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rCard
                            color: deskArea.containsMouse || desk.containsDrag ? Theme.card : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }

                        // The keyboard's place on the strip (outside the tile, which clips).
                        Rectangle {
                            x: tile.x - 5; y: tile.y - 5
                            width: tile.width + 10; height: tile.height + 10
                            radius: tile.radius + 4
                            color: "transparent"
                            border.width: Theme.focusWidth
                            border.color: Theme.accentText
                            visible: pane.inDesks && pane.deskCurrent === desk.index
                        }
                        Rectangle {
                            id: tile
                            x: 8; y: 8
                            width: deskRow.tileW
                            height: deskRow.tileH
                            radius: Theme.rControl
                            color: desk.add ? Theme.card : Theme.night
                            border.width: 2
                            border.color: !desk.add && desk.d?.active ? Theme.accentText : desk.containsDrag ? Theme.soft : Theme.rim

                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: Theme.s0
                                visible: !desk.add
                                source: "file:///usr/share/backgrounds/kriss/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"
                                sourceSize: Qt.size(deskRow.tileW * 2, deskRow.tileH * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            // Up to five of its windows' icons.
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.s1
                                visible: !desk.add
                                Repeater {
                                    model: desk.deskWins.slice(0, 5)
                                    delegate: IconImage {
                                        required property var modelData
                                        implicitSize: 24
                                        source: Quickshell.iconPath(Windows.entryFor(modelData.appId)?.icon ?? modelData.appId, "application-x-executable")
                                    }
                                }
                            }
                            Glyph { anchors.centerIn: parent; visible: desk.add; name: "plus"; size: 28; color: Theme.fg }

                            MouseArea {
                                id: deskClose
                                x: parent.width - width - 4; y: 4
                                width: 24; height: 24
                                visible: !desk.add && pane.strip.length > 1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                opacity: deskArea.containsMouse || containsMouse ? 1 : 0
                                enabled: opacity > 0
                                onClicked: Windows.closeDesktop(desk.d.id)
                                Accessible.role: Accessible.Button
                                Accessible.name: Tr.t("Close desktop")
                                Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                Rectangle { anchors.fill: parent; radius: Theme.rSmall; color: deskClose.containsMouse ? Theme.red : Theme.alpha(Theme.night, 0.6) }
                                Glyph { anchors.centerIn: parent; name: "close"; size: 12; color: Theme.nightFg }
                            }
                        }

                        Text {
                            anchors { top: tile.bottom; topMargin: Theme.s2; horizontalCenter: tile.horizontalCenter }
                            width: tile.width
                            visible: pane.renaming !== desk.index
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: desk.add ? Tr.t("New desktop") : pane.deskName(desk.index)
                            color: Theme.nightFg
                            font { family: Theme.sans; pixelSize: Theme.sp(13); weight: !desk.add && desk.d?.active ? Font.DemiBold : Font.Medium }
                        }
                        Rectangle {
                            anchors { top: tile.bottom; topMargin: Theme.s1; horizontalCenter: tile.horizontalCenter }
                            width: tile.width; height: Math.max(26, Theme.sp(13) + 12)
                            radius: Theme.rControl
                            visible: pane.renaming === desk.index
                            color: Theme.win
                            border.width: Theme.rimWidth
                            border.color: Theme.accentText
                            TextInput {
                                id: nameInput
                                anchors.fill: parent
                                anchors.margins: Theme.s1
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                color: Theme.fg
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentInk
                                font { family: Theme.sans; pixelSize: Theme.sp(13) }
                                clip: true
                                Accessible.role: Accessible.EditableText
                                Accessible.name: Tr.t("Desktop name")
                                onVisibleChanged: if (visible) { text = pane.deskName(desk.index); selectAll(); forceActiveFocus(); }
                                Keys.onReturnPressed: pane.rename(desk.index, text)
                                Keys.onEnterPressed: pane.rename(desk.index, text)
                                Keys.onEscapePressed: { pane.renaming = -1; keys.forceActiveFocus(); }
                                onActiveFocusChanged: if (!activeFocus && visible) pane.rename(desk.index, text)
                            }
                        }
                    }
                }
            }

            Menu { id: menu }
        }
    }
}
