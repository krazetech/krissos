import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Snap layouts, as on Windows 11. Windows+Z, or resting the pointer on a window's maximize
// button, shows the layouts by the window: halves, thirds and quarters. Pick a zone and the
// window snaps there. Snap Assist then offers the screen's other windows, as live pictures,
// for each empty zone of that layout; a window snapped by dragging it to an edge or corner, or
// with Windows+arrows, gets Snap Assist for the rest of the screen too. Arrows, Enter and Esc
// work throughout. cosmic-comp draws the drag preview itself; placing windows and the
// maximize button need cosmic-comp-kriss (kriss_snap_v1), so without it nothing shows.
// ponytail: zones start at the screen's top left, so a bar along the top or left would put the
// layouts and Snap Assist off by its size; noticing cosmic-comp's own snaps assumes a bottom taskbar.
Scope {
    id: snap

    // Zones in twelfths of the work area: [x, y, width, height].
    readonly property var layouts: [
        [[0, 0, 6, 12], [6, 0, 6, 12]],
        [[0, 0, 4, 12], [4, 0, 4, 12], [8, 0, 4, 12]],
        [[0, 0, 6, 6], [6, 0, 6, 6], [0, 6, 6, 6], [6, 6, 6, 6]]
    ]
    readonly property var layoutNames: [Tr.t("Halves"), Tr.t("Thirds"), Tr.t("Quarters")]
    // The rest of the screen after cosmic-comp's own snaps (drag or Windows+arrows).
    readonly property var rest: ({
        "0,0,6,12": [[6, 0, 6, 12]], "6,0,6,12": [[0, 0, 6, 12]],
        "0,0,12,6": [[0, 6, 12, 6]], "0,6,12,6": [[0, 0, 12, 6]],
        "0,0,6,6": [[6, 0, 6, 6], [0, 6, 6, 6], [6, 6, 6, 6]],
        "6,0,6,6": [[0, 0, 6, 6], [0, 6, 6, 6], [6, 6, 6, 6]],
        "0,6,6,6": [[0, 0, 6, 6], [6, 0, 6, 6], [6, 6, 6, 6]],
        "6,6,6,6": [[0, 0, 6, 6], [6, 0, 6, 6], [0, 6, 6, 6]]
    })

    // The layouts: for this window, opened by the keyboard (Windows+Z) or the pointer.
    property var pickFor: null
    property bool pickKeys: false
    // Snap Assist: the empty zones still to fill on this screen, the first one on show, and
    // the windows already placed, which it no longer offers.
    property string assistScreen: ""
    property var assistZones: []
    property var placed: []
    readonly property bool assisting: assistZones.length > 0

    function workArea(screen) {
        return Qt.size(screen.width, screen.height - Desktop.topRoom - Desktop.bottomRoom);
    }
    function geoOf(w) {
        return w?.geo?.[w.output] ?? null;
    }

    // Windows+Z: the layouts for the window in front, by the keyboard.
    function layoutsForActive() {
        const w = Windows.list.find(w => w.active && !w.minimized);
        if (!Windows.snapReady || !w || !geoOf(w)) return;
        closeAssist();
        hoverTimer.stop();
        pickKeys = true;
        pickFor = w;
    }
    function closePicker() {
        hoverTimer.stop();
        leaveTimer.stop();
        pickFor = null;
        pickKeys = false;
    }
    function closeAssist() {
        assistZones = [];
        placed = [];
    }

    // Snap the window into zone `z` of layout `l`, then assist with the layout's other zones.
    function pick(l, z) {
        const w = pickFor;
        closePicker();
        if (!w) return;
        place(w.id, layouts[l][z]);
        startAssist(w.output, layouts[l].filter((_, i) => i !== z), [w.id]);
    }
    function place(id, zone) {
        expected[id] = zone.join(",");
        Windows.snap(id, zone);
    }
    function startAssist(screenName, zones, placedIds) {
        // Stock cosmic-comp has no kriss_snap_v1, so nothing could be placed: show nothing.
        if (!Windows.snapReady) return;
        if (!Windows.list.some(w => w.output === screenName && placedIds.indexOf(w.id) < 0)) return;
        assistScreen = screenName;
        placed = placedIds;
        assistZones = zones;
    }
    // Snap Assist's choice for the zone on show: snap it there and go on to the next zone.
    function fill(id) {
        const zone = assistZones[0];
        place(id, zone);
        Windows.activate(id);
        const left = placed.concat([id]);
        const zones = assistZones.slice(1);
        closeAssist();
        startAssist(assistScreen, zones, left);
    }

    // The zone (as "x,y,w,h" in twelfths) each window was last seen in, to notice cosmic-comp's
    // own snaps, and the zones this asked for, so its own snaps don't start Snap Assist again.
    property var zoneOf: ({})
    property var expected: ({})
    function zoneFor(w) {
        const g = geoOf(w), s = Quickshell.screens.find(s => s.name === w.output);
        if (!g || !s) return "";
        const a = workArea(s), tol = 24;
        for (const key of Object.keys(rest)) {
            const [x, y, zw, zh] = key.split(",").map(Number);
            if (Math.abs(g[0] - a.width * x / 12) < tol && Math.abs(g[1] - Desktop.topRoom - a.height * y / 12) < tol
                && Math.abs(g[0] + g[2] - a.width * (x + zw) / 12) < tol
                && Math.abs(g[1] - Desktop.topRoom + g[3] - a.height * (y + zh) / 12) < tol)
                return key;
        }
        return "";
    }
    Connections {
        target: Windows
        function onListChanged() {
            if (snap.pickFor && !Windows.list.some(w => w.id === snap.pickFor.id)) snap.closePicker();
            const seen = {};
            for (const w of Windows.list) {
                const key = w.minimized ? "" : snap.zoneFor(w);
                seen[w.id] = key;
                const mine = snap.expected[w.id] !== undefined;
                if (mine && key === snap.expected[w.id]) delete snap.expected[w.id];
                if (!key || mine || snap.zoneOf[w.id] === undefined || key === snap.zoneOf[w.id] || !w.active || snap.assisting || snap.pickFor) continue;
                snap.startAssist(w.output, snap.rest[key], [w.id]);
            }
            snap.zoneOf = seen;
        }
        function onMaximizeHovered(id, on) {
            if (snap.pickKeys || snap.assisting) return;
            if (on) {
                snap.hoverId = id;
                leaveTimer.stop();
                if (!snap.pickFor) hoverTimer.restart();
            } else {
                hoverTimer.stop();
                if (snap.pickFor) leaveTimer.restart();
            }
        }
    }

    // Resting on the maximize button opens the layouts; leaving both closes them.
    property int hoverId: 0
    Timer {
        id: hoverTimer
        interval: 400
        onTriggered: {
            const w = Windows.list.find(w => w.id === snap.hoverId);
            if (w && snap.geoOf(w)) snap.pickFor = w;
        }
    }
    Timer { id: leaveTimer; interval: 400; onTriggered: snap.closePicker() }

    // Pictures only while Snap Assist shows, at its card size.
    property int thumbPx: 0
    readonly property var offered: assisting ? Windows.byRecent.filter(w => w.output === assistScreen && placed.indexOf(w.id) < 0) : []
    readonly property string captureKey: assisting ? thumbPx + " " + offered.map(w => w.id).join(" ") : ""
    onCaptureKeyChanged: Windows.capture(assisting ? offered.map(w => w.id) : [], assisting ? thumbPx : 0)
    onOfferedChanged: if (assisting && offered.length === 0) closeAssist()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pane
            required property var modelData
            screen: modelData

            readonly property bool picking: snap.pickFor !== null && snap.pickFor.output === modelData.name
            readonly property bool assisting: snap.assisting && snap.assistScreen === modelData.name
            // Its own size once shown: the screen without every exclusive zone.
            readonly property var area: height > 0 ? Qt.size(width, height) : snap.workArea(modelData)
            function zoneRect(z) {
                return Qt.rect(area.width * z[0] / 12, area.height * z[1] / 12, area.width * z[2] / 12, area.height * z[3] / 12);
            }

            visible: picking || assisting || flyout.opacity > 0 || assist.opacity > 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-snap"
            WlrLayershell.keyboardFocus: modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            // Clicks only on the layouts while the pointer opened them, so the window stays usable.
            readonly property bool modal: assisting || (picking && snap.pickKeys)
            mask: modal ? null : picking ? flyoutRegion : noInput
            Region { id: flyoutRegion; item: flyout }
            Region { id: noInput }
            BackgroundEffect.blurRegion: Region {
                Region { item: pane.picking ? flyout : null; radius: flyout.radius }
                Region { item: pane.assisting ? assist : null; radius: assist.radius }
            }

            onPickingChanged: if (picking) { flyout.cur = 0; flyout.forceActiveFocus(); }
            onAssistingChanged: if (assisting) assist.forceActiveFocus()

            // A click beside the layouts or Snap Assist's zone leaves them, as on Windows.
            MouseArea { anchors.fill: parent; enabled: pane.modal; Accessible.ignored: true; onClicked: { snap.closePicker(); snap.closeAssist(); } }

            // The layouts, under the window's top right corner (its maximize button).
            Rectangle {
                id: flyout
                // Zone under the pointer or the keys: [layout, zone], flattened in reading order.
                property int cur: -1
                readonly property var flat: snap.layouts.reduce((a, l, li) => a.concat(l.map((_, zi) => [li, zi])), [])
                readonly property var g: snap.geoOf(snap.pickFor)
                readonly property real tileW: 92
                readonly property real tileH: Math.round(tileW * pane.area.height / Math.max(1, pane.area.width))

                width: tiles.implicitWidth + 24
                height: tiles.implicitHeight + 24
                x: g ? Math.max(Theme.gap, Math.min(pane.width - width - Theme.gap, g[0] + g[2] - 60 - width / 2)) : 0
                y: g ? Math.max(Theme.gap, Math.min(pane.height - height - Theme.gap, g[1] + 40)) : 0
                radius: Theme.rPanel
                color: Theme.bar
                border.width: 1
                border.color: Theme.rim
                opacity: pane.picking ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                transform: Translate { y: pane.picking || Theme.reduceMotion ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } } }

                HoverHandler {
                    onHoveredChanged: if (hovered) leaveTimer.stop(); else if (!snap.pickKeys && pane.picking) leaveTimer.restart()
                }

                // Left and Right go through every zone in turn; Up and Down to the zone above
                // or below in the same layout, else the same zone of the layout before or after.
                function move(dx, dy) {
                    const [l, z] = flat[Math.max(0, cur)] ?? [0, 0];
                    if (dx) { cur = (Math.max(0, cur) + dx + flat.length) % flat.length; return; }
                    const zone = snap.layouts[l][z];
                    const below = snap.layouts[l].findIndex(o => o[0] === zone[0] && o[1] === zone[1] + dy * zone[3]);
                    if (below >= 0) cur = flat.findIndex(f => f[0] === l && f[1] === below);
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) move(1, 0);
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) move(-1, 0);
                    else if (event.key === Qt.Key_Down) move(0, 1);
                    else if (event.key === Qt.Key_Up) move(0, -1);
                    else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && cur >= 0) snap.pick(...flat[cur]);
                    else if (event.key === Qt.Key_Escape) snap.closePicker();
                    else return;
                    event.accepted = true;
                }

                Row {
                    id: tiles
                    anchors.centerIn: parent
                    spacing: Theme.s3

                    Repeater {
                        model: snap.layouts.length

                        Item {
                            id: tile
                            required property int index
                            width: flyout.tileW
                            height: flyout.tileH
                            Accessible.role: Accessible.Grouping
                            Accessible.name: snap.layoutNames[index]

                            Repeater {
                                model: snap.layouts[tile.index]

                                MouseArea {
                                    id: zoneArea
                                    required property var modelData
                                    required property int index
                                    readonly property int flatIndex: flyout.flat.findIndex(f => f[0] === tile.index && f[1] === index)
                                    readonly property bool lit: flyout.cur === flatIndex
                                    x: tile.width * modelData[0] / 12 + 2
                                    y: tile.height * modelData[1] / 12 + 2
                                    width: tile.width * modelData[2] / 12 - 4
                                    height: tile.height * modelData[3] / 12 - 4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: flyout.cur = flatIndex
                                    onClicked: snap.pick(tile.index, index)
                                    Accessible.role: Accessible.Button
                                    Accessible.name: snap.layoutNames[tile.index] + ", " + Tr.t("zone %1", index + 1)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.rSmall
                                        color: zoneArea.lit ? Theme.accent : Theme.card
                                        border.width: 1
                                        border.color: zoneArea.lit ? Theme.accentText : Theme.line
                                        scale: zoneArea.pressed ? Theme.pressScale : 1
                                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Snap Assist: the empty zone, holding the other windows to fill it with.
            Rectangle {
                id: assist
                readonly property var zone: pane.assisting ? snap.assistZones[0] : null
                readonly property rect r: zone ? pane.zoneRect(zone) : Qt.rect(0, 0, 0, 0)
                readonly property var wins: pane.assisting ? snap.offered : []
                property int cur: 0
                // Cards in a grid that keeps windows' 16:10 shape, as large as the zone allows.
                readonly property int pad: 16
                readonly property int head: Math.max(30, Theme.sp(12) + 18)
                readonly property int cols: {
                    const n = Math.max(1, wins.length), w = r.width - pad * 2, h = r.height - pad * 2;
                    let best = 1, size = 0;
                    for (let c = 1; c <= n; c++) {
                        const rows = Math.ceil(n / c);
                        const s = Math.min((w - (c - 1) * 12) / c, ((h - (rows - 1) * 12) / rows - head) * 1.6);
                        if (s > size) { size = s; best = c; }
                    }
                    return best;
                }
                readonly property real cardW: Math.min(280, (r.width - pad * 2 - (cols - 1) * 12) / cols,
                    ((r.height - pad * 2 - (Math.ceil(Math.max(1, wins.length) / cols) - 1) * 12) / Math.ceil(Math.max(1, wins.length) / cols) - head) * 1.6)
                onCardWChanged: if (pane.assisting) snap.thumbPx = Math.ceil(cardW * (pane.modelData.devicePixelRatio ?? 1))
                onWinsChanged: cur = Math.max(0, Math.min(cur, wins.length - 1))
                onZoneChanged: cur = 0

                x: r.x + 8
                y: r.y + 8
                width: Math.max(0, r.width - 16)
                height: Math.max(0, r.height - 16)
                radius: Theme.rPanel
                color: Theme.bar
                border.width: 1
                border.color: Theme.rim
                opacity: pane.assisting ? 1 : 0
                scale: pane.assisting || Theme.reduceMotion ? 1 : 0.98
                Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

                MouseArea { anchors.fill: parent; Accessible.ignored: true } // clicks between cards stay here

                Keys.onPressed: event => {
                    const n = wins.length;
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) cur = (cur + 1) % n;
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) cur = (cur - 1 + n) % n;
                    else if (event.key === Qt.Key_Down && cur + cols < n) cur += cols;
                    else if (event.key === Qt.Key_Up && cur - cols >= 0) cur -= cols;
                    else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && wins[cur]) snap.fill(wins[cur].id);
                    else if (event.key === Qt.Key_Escape) snap.closeAssist();
                    else if (event.key !== Qt.Key_Down && event.key !== Qt.Key_Up) return;
                    event.accepted = true;
                }

                Grid {
                    anchors.centerIn: parent
                    columns: assist.cols
                    spacing: Theme.s3

                    Repeater {
                        // By position, so a title or focus change updates a card instead of rebuilding it.
                        model: assist.wins.length

                        MouseArea {
                            id: card
                            required property int index
                            readonly property var w: assist.wins[index]
                            readonly property var entry: DesktopEntries.heuristicLookup(w?.appId ?? "")
                            readonly property bool lit: assist.cur === index
                            width: assist.cardW
                            height: assist.cardW / 1.6 + assist.head
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: assist.cur = index
                            onClicked: if (w) snap.fill(w.id)
                            Accessible.role: Accessible.Button
                            Accessible.name: w?.title || entry?.name || w?.appId || ""

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -6
                                radius: Theme.rCard
                                color: card.lit ? Theme.card : "transparent"
                                border.width: card.lit ? 2 : 0
                                border.color: Theme.accentText
                                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                            }
                            IconImage {
                                id: icon
                                x: 2; y: 4
                                implicitSize: 18
                                source: Quickshell.iconPath(card.entry?.icon ?? card.w?.appId ?? "", "application-x-executable")
                            }
                            Text {
                                anchors { left: icon.right; leftMargin: Theme.s2; right: parent.right; verticalCenter: icon.verticalCenter }
                                text: card.w?.title || card.entry?.name || card.w?.appId || ""
                                elide: Text.ElideRight
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.Medium }
                            }
                            // The live picture, or the app's icon until there is one.
                            Rectangle {
                                y: assist.head
                                width: parent.width
                                height: parent.height - assist.head
                                radius: Theme.rControl
                                color: Theme.card
                                clip: true
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
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: thumb.status !== Image.Ready
                                    implicitSize: 48
                                    source: icon.source
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
