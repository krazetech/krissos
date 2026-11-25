import QtQuick
import Quickshell
import Quickshell.Wayland
import "reveal.js" as Reveal

// Settings > System > Display: the screens side by side (drag one to move it), which one is
// the main display, and the chosen one's scale, resolution, refresh rate and turning, through
// cosmic-randr (Displays.qml). A change that can leave a screen blank (resolution, refresh,
// scale, orientation) goes back on its own after 15 seconds unless it is kept, as on Windows.
Column {
    id: page
    spacing: Theme.s3

    // The display the settings below are for: the one picked above, else the main one.
    property string sel: ""
    readonly property var outs: Displays.outputs.filter(o => o.enabled && !o.mirroring)
    readonly property var o: Displays.outputs.find(x => x.name === sel) ?? Displays.outputs.find(x => x.primary) ?? outs[0] ?? null
    // Numbers as Identify shows them: left to right, then top to bottom.
    readonly property var order: outs.slice().sort((a, b) => a.x - b.x || a.y - b.y).map(x => x.name)
    function number(name) { return order.indexOf(name) + 1; }

    // The change waiting to be kept: {name, mode, scale, transform} as it was before.
    property var undo: null
    property int secondsLeft: 0
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: if (--page.secondsLeft <= 0) page.revert()
    }
    function change(name, mode, extra) {
        const before = Displays.outputs.find(x => x.name === name);
        if (!before) return;
        page.undo = { name: name, mode: { w: before.w, h: before.h, r: before.r }, scale: before.scale, transform: before.transform };
        Displays.setMode(name, mode, extra, ok => {
            if (!ok) { page.undo = null; return; }
            page.secondsLeft = 15;
            countdown.restart();
        });
    }
    function keep() { countdown.stop(); undo = null; }
    function revert() {
        countdown.stop();
        const u = undo;
        undo = null;
        if (u) Displays.setMode(u.name, u.mode, { scale: u.scale, transform: u.transform });
    }

    SettingsUi.Card {
        visible: page.undo !== null
        SettingsUi.Label { text: Tr.t("Keep these display settings?") }
        SettingsUi.Note { text: Tr.t("Going back to the old ones in %1 seconds.", page.secondsLeft) }
        Row {
            spacing: Theme.s2
            SettingsUi.Push { text: Tr.t("Keep changes"); main: true; onPicked: page.keep() }
            SettingsUi.Push { text: Tr.t("Revert"); onPicked: page.revert() }
        }
    }

    // Which display is the main one, said plainly, and choosing it.
    readonly property var main: Displays.outputs.find(x => x.primary) ?? null
    // cosmic-comp picks the display at the top-left corner by itself; any other main display,
    // or one picked here, was the user's choice.
    readonly property bool picked: Desktop.mainChosen || (main !== null && (main.x !== 0 || main.y !== 0))
    function where(o) {
        const s = Displays.side(o);
        return s === "left" ? Tr.t("on the left") : s === "right" ? Tr.t("on the right") : s === "above" ? Tr.t("on top")
            : s === "below" ? Tr.t("at the bottom") : s === "middle" ? Tr.t("in the middle") : "";
    }
    function makeMain(name) { Desktop.mainChosen = true; Displays.setPrimary(name); }
    SettingsUi.Card {
        visible: page.main !== null
        SettingsUi.Label { text: Tr.t("Main display") }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: page.main ? [Displays.fullName(page.main), page.main.name, page.where(page.main)].filter(t => t).join(" · ") : ""
            color: Theme.fg
            font { family: Theme.sans; pixelSize: Theme.sp(16); weight: Font.DemiBold }
            Accessible.role: Accessible.StaticText
            Accessible.name: Tr.t("Main display") + ": " + text
        }
        SettingsUi.Note {
            text: page.outs.length > 1 && !page.picked
                ? Tr.t("Chosen automatically, because it sits at the top left. The full taskbar, Start, notifications, new windows, the sign-in screen and fullscreen games go here.")
                : Tr.t("The full taskbar, Start, notifications, new windows, the sign-in screen and fullscreen games go here.")
        }
        SettingsUi.Choice {
            visible: page.outs.length > 1
            text: Tr.t("Choose the main display")
            value: page.main?.name ?? ""
            options: page.outs.map(x => [x.name, Tr.t("Display %1: %2", page.number(x.name), Displays.fullName(x))])
            onPicked: v => page.makeMain(v)
        }
    }

    // The screens, to scale; drag one next to another to move it there.
    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Rearrange your displays") }
        SettingsUi.Note {
            text: page.outs.length > 1 ? Tr.t("Drag a display to where it sits on your desk; its edges snap to the others. Pick one to change it below.")
                                       : Tr.t("Only one display is on.")
        }
        Item {
            id: map
            width: parent.width
            height: Theme.dp(200)
            // Every screen's box on the desktop, and the scale that fits them all here.
            readonly property var box: {
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                for (const o of page.outs) {
                    const l = Displays.logical(o);
                    x0 = Math.min(x0, o.x); y0 = Math.min(y0, o.y);
                    x1 = Math.max(x1, o.x + l.w); y1 = Math.max(y1, o.y + l.h);
                }
                return page.outs.length ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 };
            }
            readonly property real k: Math.min((width - 24) / box.w, (height - 24) / box.h)
            readonly property real ox: (width - box.w * k) / 2
            readonly property real oy: (height - box.h * k) / 2

            // Where a dropped screen goes: against the nearest side of the nearest other screen,
            // sharing some of that side, and lined up with its edges or middle when it is within a
            // few pixels here of them, as Windows does. Never on top of a third screen.
            function snap(name, x, y) {
                const me = Displays.logical(page.outs.find(o => o.name === name));
                const near = 12 / k;
                const others = page.outs.filter(o => o.name !== name).map(o => Object.assign({ name: o.name, x: o.x, y: o.y }, Displays.logical(o)));
                const along = (v, lo, len, mine) => {
                    v = Math.max(lo - mine + 1, Math.min(v, lo + len - 1));
                    for (const a of [lo, lo + len - mine, lo + (len - mine) / 2])
                        if (Math.abs(v - a) < near) return Math.round(a);
                    return Math.round(v);
                };
                const hits = c => others.some(o => c[0] < o.x + o.w && c[0] + me.w > o.x && c[1] < o.y + o.h && c[1] + me.h > o.y);
                let best = null;
                for (const o of others) {
                    const cy = along(y, o.y, o.h, me.h), cx = along(x, o.x, o.w, me.w);
                    for (const c of [[o.x - me.w, cy], [o.x + o.w, cy], [cx, o.y - me.h], [cx, o.y + o.h]]) {
                        const d = Math.hypot(c[0] - x, c[1] - y);
                        if (!hits(c) && (!best || d < best.d)) best = { x: c[0], y: c[1], d: d };
                    }
                }
                return best;
            }
            // Puts a screen there, and moves the whole layout so its top-left corner is 0,0.
            function place(name, p) {
                const at = page.outs.map(o => o.name === name ? { name: name, x: p.x, y: p.y, was: o } : { name: o.name, x: o.x, y: o.y, was: o });
                const x0 = Math.min(...at.map(a => a.x)), y0 = Math.min(...at.map(a => a.y));
                for (const a of at) { a.x -= x0; a.y -= y0; }
                Displays.setPositions(at.filter(a => a.x !== a.was.x || a.y !== a.was.y));
            }
            // The arrow keys: a tenth of the screen that way, or, stuck against a side, round to
            // the far side of the others.
            function nudge(name, dx, dy) {
                const o = page.outs.find(x => x.name === name), l = Displays.logical(o);
                let p = snap(name, o.x + dx * l.w / 10, o.y + dy * l.h / 10);
                if (!p || p.x === o.x && p.y === o.y) {
                    const others = page.outs.filter(x => x.name !== name);
                    const x0 = Math.min(...others.map(x => x.x)), y0 = Math.min(...others.map(x => x.y));
                    const x1 = Math.max(...others.map(x => x.x + Displays.logical(x).w)), y1 = Math.max(...others.map(x => x.y + Displays.logical(x).h));
                    p = snap(name, dx < 0 ? x0 - l.w : dx > 0 ? x1 : o.x, dy < 0 ? y0 - l.h : dy > 0 ? y1 : o.y);
                }
                if (p && (p.x !== o.x || p.y !== o.y)) place(name, p);
            }

            Repeater {
                model: page.outs
                MouseArea {
                    id: tile
                    required property var modelData
                    readonly property var l: Displays.logical(modelData)
                    readonly property bool on: page.o?.name === modelData.name
                    x: map.ox + (modelData.x - map.box.x) * map.k
                    y: map.oy + (modelData.y - map.box.y) * map.k
                    width: l.w * map.k - 4
                    height: l.h * map.k - 4
                    hoverEnabled: true
                    cursorShape: page.outs.length > 1 ? Qt.OpenHandCursor : Qt.PointingHandCursor
                    activeFocusOnTab: true
                    drag.target: page.outs.length > 1 ? tile : null
                    onPressed: page.sel = modelData.name
                    onReleased: {
                        if (!drag.active && Math.abs(x - (map.ox + (modelData.x - map.box.x) * map.k)) < 2) return;
                        const p = map.snap(modelData.name, (x - map.ox) / map.k + map.box.x, (y - map.oy) / map.k + map.box.y);
                        // Put back where it was until cosmic-randr says where it is now.
                        x = Qt.binding(() => map.ox + (modelData.x - map.box.x) * map.k);
                        y = Qt.binding(() => map.oy + (modelData.y - map.box.y) * map.k);
                        if (p) map.place(modelData.name, p);
                    }
                    Keys.onSpacePressed: page.sel = modelData.name
                    Keys.onReturnPressed: page.sel = modelData.name
                    Keys.onPressed: e => {
                        const d = { [Qt.Key_Left]: [-1, 0], [Qt.Key_Right]: [1, 0], [Qt.Key_Up]: [0, -1], [Qt.Key_Down]: [0, 1] }[e.key];
                        if (!d || page.outs.length < 2) return;
                        page.sel = modelData.name;
                        map.nudge(modelData.name, d[0], d[1]);
                        e.accepted = true;
                    }
                    onActiveFocusChanged: if (activeFocus) Reveal.show(map)
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: Tr.t("Display %1: %2", page.number(modelData.name), Displays.label(modelData))
                    Accessible.description: [modelData.primary ? Tr.t("Main display") : "", page.where(modelData), page.outs.length > 1 ? Tr.t("The arrow keys move it") : ""].filter(t => t).join(". ")
                    Accessible.checkable: true
                    Accessible.checked: on
                    Accessible.onPressAction: page.sel = modelData.name
                    FocusRim { radius: Theme.rControl + 4 }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: tile.on ? Theme.accent : tile.containsMouse ? Theme.cardHover : Theme.win
                        border.width: tile.on ? 0 : Theme.rimWidth
                        border.color: Theme.line
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: page.number(tile.modelData.name)
                            color: tile.on ? Theme.accentInk : Theme.fg
                            font { family: Theme.sans; pixelSize: Theme.sp(24); weight: Font.DemiBold }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: tile.modelData.primary ? "★ " + Tr.t("Main display") : Displays.label(tile.modelData)
                            color: tile.on ? Theme.accentInk : Theme.soft
                            font { family: Theme.sans; pixelSize: Theme.sp(11) }
                        }
                    }
                }
            }
        }
        SettingsUi.Push { text: Tr.t("Identify"); onPicked: identify.restart() }
    }

    // Identify: each screen's number, big, for three seconds.
    Timer { id: identify; interval: 3000 }
    Variants {
        model: identify.running ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-identify"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; bottom: true }
            margins { left: 48; bottom: 48 + Desktop.bottomRoom }
            implicitWidth: Theme.dp(160)
            implicitHeight: Theme.dp(160)
            color: "transparent"
            mask: Region {}
            Rectangle {
                anchors.fill: parent
                radius: Theme.rPanel
                color: Theme.card
                Text {
                    anchors.centerIn: parent
                    text: page.number(modelData.name)
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.dp(96); weight: Font.DemiBold }
                }
            }
        }
    }

    SettingsUi.Card {
        visible: page.o !== null
        SettingsUi.Label {
            text: Tr.t("Display %1: %2", page.number(page.o?.name ?? ""), page.o ? Displays.fullName(page.o) : "")
                + (page.o?.primary ? " · " + Tr.t("Main display") : "")
        }
        SettingsUi.Toggle {
            text: Tr.t("Make this my main display")
            detail: Tr.t("The full taskbar, Start, notifications, new windows, the sign-in screen and fullscreen games go here.")
            checked: page.o?.primary ?? false
            onToggled: if (!checked && page.o) page.makeMain(page.o.name)
        }
        SettingsUi.Toggle {
            visible: Displays.outputs.length > 1
            text: Tr.t("Use this display")
            detail: Tr.t("Off: the display stays dark and windows move to the others.")
            checked: page.o?.enabled ?? false
            // The last display that is on stays on.
            onToggled: if (page.o && (checked ? page.outs.length > 1 : true)) Displays.setEnabled(page.o.name, !checked)
        }
    }

    SettingsUi.Card {
        visible: page.o !== null && page.o.enabled
        SettingsUi.Choice {
            text: Tr.t("Scale")
            detail: Tr.t("Makes text, apps and the taskbar bigger on this display.")
            value: String(Math.round((page.o?.scale ?? 1) * 100))
            options: {
                const now = Math.round((page.o?.scale ?? 1) * 100);
                const list = [100, 125, 150, 175, 200, 225, 250, 300];
                if (list.indexOf(now) < 0) list.push(now);
                return list.sort((a, b) => a - b).map(v => [String(v), v + "%"]);
            }
            onPicked: v => page.change(page.o.name, page.o, { scale: v / 100 })
        }
        // ponytail: every size as a button, not a drop-down; sizes under 1024 wide are left out.
        SettingsUi.Choice {
            text: Tr.t("Display resolution")
            readonly property var best: page.o?.modes.find(m => m.preferred) ?? null
            value: page.o ? page.o.w + "x" + page.o.h : ""
            options: {
                const seen = {}, out = [];
                for (const m of page.o?.modes ?? []) {
                    const k = m.w + "x" + m.h;
                    if (seen[k] || m.w < 1024) continue;
                    seen[k] = true;
                    out.push([k, m.w + " × " + m.h + (best && best.w === m.w && best.h === m.h ? " " + Tr.t("(recommended)") : "")]);
                }
                return out;
            }
            onPicked: v => {
                const [w, h] = v.split("x").map(Number);
                // The fastest refresh rate at that size.
                const m = page.o.modes.filter(m => m.w === w && m.h === h).sort((a, b) => b.r - a.r)[0];
                if (m) page.change(page.o.name, m);
            }
        }
        SettingsUi.Choice {
            text: Tr.t("Refresh rate")
            detail: Tr.t("Higher is smoother, for games and scrolling.")
            value: String(page.o?.r ?? 0)
            options: (page.o?.modes ?? []).filter(m => m.w === page.o.w && m.h === page.o.h)
                .sort((a, b) => b.r - a.r).map(m => [String(m.r), Tr.t("%1 Hz", (m.r / 1000).toFixed(m.r % 1000 ? 2 : 0))])
            onPicked: v => page.change(page.o.name, { w: page.o.w, h: page.o.h, r: +v })
        }
        SettingsUi.Choice {
            text: Tr.t("Orientation")
            value: page.o?.transform ?? "normal"
            options: [["normal", Tr.t("Landscape")], ["rotate90", Tr.t("Portrait")], ["rotate180", Tr.t("Landscape (flipped)")], ["rotate270", Tr.t("Portrait (flipped)")]]
            onPicked: v => page.change(page.o.name, page.o, { transform: v })
        }
        SettingsUi.Toggle {
            visible: page.o?.vrrSupport ?? false
            text: Tr.t("Variable refresh rate")
            detail: Tr.t("Smoother games on displays with FreeSync or G-Sync. Turn it off if the display flickers.")
            checked: page.o?.vrr ?? false
            onToggled: Displays.setMode(page.o.name, page.o, { vrr: checked ? "false" : "automatic" })
        }
    }

    SettingsUi.Card {
        SettingsUi.Toggle {
            text: Tr.t("Night light")
            detail: Tr.t("Warmer colours on every display, kinder to the eyes at night.")
            checked: Desktop.nightLight
            onToggled: Desktop.nightLight = !Desktop.nightLight
        }
    }
}
