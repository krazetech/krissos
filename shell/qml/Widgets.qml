import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import "fuzzy.js" as Fuzzy

// The widgets panel, as on Windows 11 (Windows+W, or the button at the far left of the
// taskbar): a tall card that slides in from the left with the calendar, clocks, system
// load, what's playing, a local AI prompt and the weather. Drag a card by its title to
// move it; its ⋯ menu hides it. Tab or the arrows move between cards, Enter goes into a
// card's text field, Alt+Up / Alt+Down move the card, Esc or a click outside closes.
// Nothing here runs while the panel is closed: every timer, file read and request is
// gated on `open`.
PanelWindow {
    id: win

    readonly property bool open: Desktop.widgetsOpen
    visible: open || panel.opacity > 0
    mask: open ? null : noInput
    Region { id: noInput }
    screen: Desktop.screen
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-widgets"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Leaves the bar uncovered, so its button closes the panel again.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    readonly property var all: ["calendar", "clocks", "system", "media", "ai", "weather"]
    readonly property var titles: ({ calendar: Tr.t("Calendar"), clocks: Tr.t("Clocks"), system: Tr.t("System"),
                                     media: Tr.t("Now playing"), ai: Tr.t("Local AI"), weather: Tr.t("Weather") })
    // The saved order, with any card it doesn't name yet at the end.
    readonly property var order: {
        const o = Array.from(Desktop.widgets).filter(id => all.indexOf(id) >= 0);
        for (const id of all) if (o.indexOf(id) < 0) o.push(id);
        return o;
    }
    // Weather needs the internet, so it is only there while NetworkManager reports it.
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full
    readonly property var shown: order.filter(id => Desktop.widgetsHidden.indexOf(id) < 0 && (id !== "weather" || online))
    readonly property var hidden: order.filter(id => Desktop.widgetsHidden.indexOf(id) >= 0)

    function close() { Desktop.widgetsOpen = false; }
    function card(id) { cards.count; return cards.itemAt(all.indexOf(id)); }
    // Where the k-th shown card goes in the column.
    function offset(k) {
        let y = 0;
        for (let i = 0; i < k && i < shown.length; i++) y += (card(shown[i])?.height ?? 0) + 12;
        return y;
    }
    // Card `id` takes the place of the shown card at `to`.
    function move(id, to) {
        const target = shown[Math.max(0, Math.min(shown.length - 1, to))];
        const list = order.slice(), from = list.indexOf(id), at = list.indexOf(target);
        if (from < 0 || at < 0 || from === at) return;
        list.splice(from, 1);
        list.splice(at, 0, id);
        Desktop.widgets = list;
    }
    function setHidden(id, hide) {
        const h = Array.from(Desktop.widgetsHidden).filter(x => x !== id);
        if (hide) h.push(id);
        Desktop.widgetsHidden = h;
    }
    function focusCard(k) {
        if (!shown.length) return;
        const c = card(shown[(k + shown.length) % shown.length]);
        c.forceActiveFocus();
        // Scrolls only as far as it takes to show the whole card.
        if (c.y < flick.contentY) flick.contentY = c.y;
        else if (c.y + c.height > flick.contentY + flick.height) flick.contentY = Math.min(c.y, c.y + c.height - flick.height);
    }

    onOpenChanged: if (open) root.forceActiveFocus()

    // A click beside the panel closes it.
    MouseArea {
        anchors.fill: parent
        Accessible.ignored: true
        onClicked: win.close()
    }

    Menu { id: menu }

    Rectangle {
        id: panel
        x: Theme.panelGap
        y: Theme.panelGap
        width: 420
        height: parent.height - 2 * Theme.panelGap
        radius: Theme.rPanel
        color: Theme.bar
        border.width: 1
        border.color: Theme.rim
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.ms(win.open ? Theme.normal : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }
        // Slides in from the left edge.
        transform: Translate {
            x: win.open || Theme.reduceMotion ? 0 : -48
            Behavior on x { NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sheetCurve } }
        }

        // Keeps clicks on the panel from closing it.
        MouseArea { anchors.fill: parent; Accessible.ignored: true }

        // Has the keyboard when no card does: Tab or Down goes to the first card.
        Item {
            id: root
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape: win.close(); break;
                case Qt.Key_Tab: case Qt.Key_Down: case Qt.Key_Right: win.focusCard(0); break;
                case Qt.Key_Backtab: case Qt.Key_Up: case Qt.Key_Left: win.focusCard(-1); break;
                default: return;
                }
                event.accepted = true;
            }
        }

        RowLayout {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            Text {
                Layout.fillWidth: true
                text: Tr.t("Widgets")
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 17; weight: Font.DemiBold }
            }
            // Brings back a hidden card.
            Btn {
                id: addBtn
                visible: win.hidden.length > 0
                glyph: "plus"
                label: Tr.t("Add widgets")
                onClicked: menu.show(addBtn, win.hidden.map(id => ({ text: win.titles[id], glyph: "plus", run: () => win.setHidden(id, false) })), false)
            }
        }

        Flickable {
            id: flick
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: Theme.s3; topMargin: Theme.s3 }
            contentHeight: win.offset(win.shown.length)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Repeater {
                id: cards
                model: win.all
                delegate: Card {}
            }
        }
    }

    // A small rounded button with a glyph and an optional label.
    component Btn: MouseArea {
        id: b
        property string glyph
        property string label
        // What a screen reader says; the label, or set it for a glyph-only button.
        property string name: label
        property bool primary: false
        Accessible.role: Accessible.Button
        Accessible.name: name
        implicitWidth: label ? row.implicitWidth + 20 : 32
        implicitHeight: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: enabled ? 1 : 0.4
        scale: pressed ? Theme.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: b.primary ? Theme.accent : b.containsMouse ? Theme.cardHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.s1
            Glyph { name: b.glyph; size: 16; stroke: b.glyph === "more" ? 3 : 2; color: b.primary ? Theme.accentInk : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
            Text {
                visible: !!b.label
                text: b.label
                color: b.primary ? Theme.accentInk : Theme.fg
                font { family: Theme.sans; pixelSize: 12; weight: Font.Medium }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // A one-line text field with a placeholder.
    component Field: Rectangle {
        id: f
        property alias text: input.text
        property alias input: input
        property string placeholder
        signal accepted()
        implicitHeight: 38
        radius: Theme.rCard
        color: Theme.win
        border.width: 1
        border.color: input.activeFocus ? Theme.accentText : Theme.line
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: Theme.s3; rightMargin: Theme.s3 }
            Accessible.name: f.placeholder
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentInk
            clip: true
            font { family: Theme.sans; pixelSize: 13 }
            onAccepted: f.accepted()
            Text {
                visible: !input.text
                anchors.verticalCenter: parent.verticalCenter
                text: f.placeholder
                color: Theme.soft
                font: input.font
            }
        }
    }

    // A line chart of the last minute of samples (0 to 1), the newest at the right.
    // The Shape sits in a plain Item: a Shape in a layout takes its size from the path, and
    // the path from its size, which loops forever.
    component Spark: Item {
        id: sp
        property var values: []
        implicitHeight: 28
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.accentText
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: sp.values.map((v, i) => Qt.point(sp.width * (60 - sp.values.length + i) / 59, sp.height - 1 - v * (sp.height - 2)))
                }
            }
        }
    }

    component Small: Text {
        color: Theme.soft
        elide: Text.ElideRight
        font { family: Theme.sans; pixelSize: 12 }
    }

    // One widget: a rounded card with its title (drag it to move the card) and a ⋯ menu.
    component Card: Rectangle {
        id: c
        required property string modelData
        required property int index
        readonly property string wid: modelData
        readonly property int pos: win.shown.indexOf(wid)
        readonly property bool dragging: grip.dragging
        // The card's text field, which Enter goes into.
        property Item input: body.item?.input ?? null

        visible: pos >= 0
        width: flick.width
        height: visible ? col.implicitHeight + 28 : 0
        y: win.offset(pos)
        Behavior on y { enabled: !c.dragging; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        z: dragging ? 1 : 0
        radius: Theme.rCard
        color: Theme.card
        border.width: activeFocus ? 2 : 1
        border.color: activeFocus ? Theme.accentText : Theme.line
        transform: Translate { id: shift }

        function menuEntries() {
            const out = (body.item?.menu ?? []).slice();
            if (out.length) out.push({ sep: true });
            out.push({ text: Tr.t("Hide this widget"), glyph: "close", run: () => win.setHidden(c.wid, true) });
            return out;
        }

        Keys.onPressed: event => {
            const alt = event.modifiers & Qt.AltModifier;
            const menuKey = event.key === Qt.Key_Menu || event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier;
            if (menuKey) menu.show(more, menuEntries(), true);
            else switch (event.key) {
            case Qt.Key_Escape: win.close(); break;
            case Qt.Key_Tab: win.focusCard(pos + 1); break;
            case Qt.Key_Backtab: win.focusCard(pos - 1); break;
            case Qt.Key_Down: case Qt.Key_Right:
                if (alt) { win.move(wid, pos + 1); c.forceActiveFocus(); } else win.focusCard(pos + 1);
                break;
            case Qt.Key_Up: case Qt.Key_Left:
                if (alt) { win.move(wid, pos - 1); c.forceActiveFocus(); } else win.focusCard(pos - 1);
                break;
            case Qt.Key_Return: case Qt.Key_Enter:
                if (c.activeFocus && body.item?.enter) body.item.enter();
                else if (c.activeFocus && c.input?.visible && c.input.enabled) c.input.forceActiveFocus();
                else return;
                break;
            default: return;
            }
            event.accepted = true;
        }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s3 }
            spacing: Theme.s2

            RowLayout {
                Layout.fillWidth: true
                MouseArea {
                    id: grip
                    Layout.fillWidth: true
                    Accessible.ignored: true // a drag handle; Alt+Up / Alt+Down move the card
                    implicitHeight: 28
                    property real pressY: 0
                    property bool dragging: false
                    preventStealing: true
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => { pressY = mapToItem(null, 0, mouse.y).y; dragging = false; }
                    onPositionChanged: mouse => {
                        const dy = mapToItem(null, 0, mouse.y).y - pressY;
                        if (!dragging && Math.abs(dy) > 8) dragging = true;
                        if (dragging) shift.y = dy;
                    }
                    onReleased: {
                        if (!dragging) return;
                        // The new place: after every other card whose middle is above this one's.
                        const mid = c.y + shift.y + c.height / 2;
                        const to = win.shown.filter(id => id !== c.wid && win.card(id).y + win.card(id).height / 2 < mid).length;
                        dragging = false;
                        shift.y = 0;
                        win.move(c.wid, to);
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.titles[c.wid]
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: 12; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 0.6 }
                    }
                }
                Btn {
                    id: more
                    glyph: "more"
                    name: Tr.t("Widget options")
                    onClicked: menu.show(more, c.menuEntries(), false)
                }
            }

            Loader {
                id: body
                Layout.fillWidth: true
                sourceComponent: ({ calendar: calendarW, clocks: clocksW, system: systemW, media: mediaW, ai: aiW, weather: weatherW })[c.wid]
            }
        }
    }

    // ---- Calendar and agenda ----
    // Events come from Evolution Data Server's local calendars (the "On this computer" ones
    // GNOME Calendar and Evolution keep), read from their files each time the panel opens.
    Component {
        id: calendarW
        ColumnLayout {
            id: cal
            spacing: Theme.s1
            SystemClock { id: clk; precision: SystemClock.Minutes; enabled: win.open }
            readonly property date today: clk.date
            property var events: []

            // ponytail: one-off events only; RRULE repeats are skipped. Use EDS's D-Bus
            // calendar views if repeating events matter.
            function parse(text) {
                const lines = text.replace(/\r?\n[ \t]/g, "").split(/\r?\n/);
                const out = [];
                const from = new Date(today.getFullYear(), today.getMonth(), today.getDate());
                const to = new Date(from.getTime() + 7 * 86400000);
                let ev = null;
                for (const l of lines) {
                    if (l === "BEGIN:VEVENT") ev = {};
                    else if (l === "END:VEVENT") {
                        if (ev && ev.start && !ev.rrule && ev.start >= from && ev.start < to) out.push(ev);
                        ev = null;
                    } else if (ev) {
                        const i = l.indexOf(":");
                        const key = l.slice(0, i).split(";")[0], val = l.slice(i + 1);
                        if (key === "SUMMARY") ev.title = val.replace(/\\n/g, " ").replace(/\\(.)/g, "$1");
                        else if (key === "RRULE") ev.rrule = true;
                        else if (key === "DTSTART") {
                            const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?/.exec(val);
                            if (!m) continue;
                            ev.allDay = !m[4];
                            ev.start = m[7] ? new Date(Date.UTC(+m[1], m[2] - 1, +m[3], +m[4], +m[5]))
                                : new Date(+m[1], m[2] - 1, +m[3], +(m[4] ?? 0), +(m[5] ?? 0));
                        }
                    }
                }
                return out.sort((a, b) => a.start - b.start);
            }

            Process {
                id: ics
                command: ["sh", "-c", 'cat "${XDG_DATA_HOME:-$HOME/.local/share}"/evolution/calendar/*/calendar.ics 2>/dev/null; true']
                stdout: StdioCollector { onStreamFinished: cal.events = cal.parse(text) }
            }

            Connections {
                target: win
                function onOpenChanged() { if (win.open) ics.running = true; }
            }

            Text {
                text: cal.today.toLocaleString(Qt.locale(), "dddd, d MMMM")
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold }
            }
            C.DayOfWeekRow {
                Layout.fillWidth: true
                locale: grid.locale
                delegate: Text {
                    required property string shortName
                    text: shortName.slice(0, 2)
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: 11; weight: Font.DemiBold }
                }
            }
            C.MonthGrid {
                id: grid
                Layout.fillWidth: true
                implicitHeight: 6 * 32
                month: cal.today.getMonth()
                year: cal.today.getFullYear()
                locale: Qt.locale()
                spacing: 0
                delegate: Item {
                    id: day
                    required property var model
                    implicitHeight: 32
                    readonly property bool busy: cal.events.some(e => e.start.toDateString() === day.model.date.toDateString())
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 28; radius: width / 2
                        color: day.model.today ? Theme.accent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: day.model.day
                        color: day.model.today ? Theme.accentInk : day.model.month === grid.month ? Theme.fg : Theme.alpha(Theme.soft, 0.7)
                        font { family: Theme.sans; pixelSize: 12; weight: day.model.today ? Font.Bold : Font.Normal }
                    }
                    Rectangle {
                        visible: day.busy && !day.model.today
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 4; height: 4; radius: width / 2
                        color: Theme.accentText
                    }
                }
            }
            // The next seven days' events, when there is a local calendar.
            Repeater {
                model: cal.events.slice(0, 5)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    Rectangle { implicitWidth: 3; implicitHeight: 30; radius: implicitWidth / 2; color: Theme.accentText }
                    Column {
                        Layout.fillWidth: true
                        Text {
                            width: parent.width
                            text: modelData.title ?? ""
                            elide: Text.ElideRight
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: 13; weight: Font.Medium }
                        }
                        Small {
                            width: parent.width
                            text: modelData.start.toLocaleString(Qt.locale(), "ddd d MMM") +
                                  (modelData.allDay ? " · " + Tr.t("All day") : " · " + Qt.formatTime(modelData.start, "HH:mm"))
                        }
                    }
                }
            }
        }
    }

    // ---- Clocks ----
    // World clocks are tz names from tzdata; their UTC offsets come from `date` each time the
    // panel opens, so summer time is right without a time zone library.
    Component {
        id: clocksW
        ColumnLayout {
            id: clocks
            spacing: Theme.s2
            SystemClock { id: now; precision: SystemClock.Minutes; enabled: win.open }
            property var offsets: ({})   // tz name: minutes east of UTC
            property bool adding: false
            property int pick: 0
            readonly property alias input: add.input
            readonly property var menu: Array.from(Desktop.worldClocks).map(z => ({
                text: Tr.t("Remove %1", city(z)), glyph: "close",
                run: () => Desktop.worldClocks = Array.from(Desktop.worldClocks).filter(x => x !== z) }))

            function city(z) { return z.split("/").pop().replace(/_/g, " "); }
            function at(z) {
                const off = offsets[z];
                if (off === undefined) return null;
                const d = now.date;
                return new Date(d.getTime() + (d.getTimezoneOffset() + off) * 60000);
            }
            // "+7 h", "−2 h 30" or "Same time", against the local clock.
            function diff(z) {
                const m = (offsets[z] ?? 0) + now.date.getTimezoneOffset();
                if (!m) return Tr.t("Same time");
                const h = Math.trunc(Math.abs(m) / 60), r = Math.abs(m) % 60;
                return (m > 0 ? "+" : "−") + h + " h" + (r ? " " + r : "");
            }

            Connections {
                target: win
                function onOpenChanged() { if (win.open) zoneOffsets.running = Desktop.worldClocks.length > 0; }
            }
            Connections {
                target: Desktop
                function onWorldClocksChanged() { if (win.open) zoneOffsets.running = Desktop.worldClocks.length > 0; }
            }
            Process {
                id: zoneOffsets
                command: ["sh", "-c", 'for z; do printf "%s %s\\n" "$z" "$(TZ=$z date +%z)"; done', "sh"].concat(Array.from(Desktop.worldClocks))
                stdout: SplitParser {
                    onRead: line => {
                        const [z, o] = line.split(" ");
                        const m = (o[0] === "-" ? -1 : 1) * (parseInt(o.slice(1, 3)) * 60 + parseInt(o.slice(3, 5)));
                        const next = Object.assign({}, clocks.offsets);
                        next[z] = m;
                        clocks.offsets = next;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                RollingText {
                    text: Qt.formatTime(now.date, "HH:mm")
                    font { family: Theme.sans; pixelSize: 34; weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                Small { text: Tr.t("Local time") }
            }

            Repeater {
                model: Desktop.worldClocks
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text {
                            text: clocks.city(modelData)
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: 13; weight: Font.Medium }
                        }
                        Small {
                            readonly property date t: clocks.at(modelData) ?? now.date
                            text: clocks.diff(modelData) + " · " + (t.getDate() === now.date.getDate() ? Tr.t("Today")
                                : t > now.date ? Tr.t("Tomorrow") : Tr.t("Yesterday"))
                        }
                    }
                    RollingText {
                        text: clocks.at(modelData) ? Qt.formatTime(clocks.at(modelData), "HH:mm") : "--:--"
                        font { family: Theme.sans; pixelSize: 18; weight: Font.DemiBold }
                    }
                }
            }

            // Add a city: type its name, pick from tzdata's list.
            FileView {
                id: zones
                path: clocks.adding ? "/usr/share/zoneinfo/zone1970.tab" : ""
                printErrors: false
            }
            readonly property var matches: {
                if (!adding || !add.text.trim()) return [];
                const all = (zones.text() ?? "").split("\n").filter(l => l && l[0] !== "#").map(l => l.split("\t")[2]);
                return all.map(z => [z, Fuzzy.best([city(z), z], add.text)]).filter(m => m[1] > 0)
                    .sort((a, b) => b[1] - a[1]).slice(0, 5).map(m => m[0]);
            }
            // Enter on the card starts adding a city.
            function enter() { adding = true; add.input.forceActiveFocus(); }
            function choose(z) {
                if (z && Desktop.worldClocks.indexOf(z) < 0) Desktop.worldClocks = Array.from(Desktop.worldClocks).concat([z]);
                add.text = "";
                adding = false;
            }
            Btn {
                visible: !clocks.adding
                glyph: "plus"
                label: Tr.t("Add a city")
                onClicked: clocks.enter()
            }
            Field {
                id: add
                visible: clocks.adding
                Layout.fillWidth: true
                placeholder: Tr.t("City name, e.g. Tokyo")
                onAccepted: clocks.choose(clocks.matches[clocks.pick])
                input.onTextChanged: clocks.pick = 0
                input.onActiveFocusChanged: if (!add.input.activeFocus && !add.text) clocks.adding = false
                input.Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) clocks.pick = Math.min(clocks.matches.length - 1, clocks.pick + 1);
                    else if (event.key === Qt.Key_Up) clocks.pick = Math.max(0, clocks.pick - 1);
                    else if (event.key === Qt.Key_Escape) { add.text = ""; clocks.adding = false; }
                    else return;
                    event.accepted = true;
                }
            }
            Repeater {
                model: clocks.matches
                delegate: MouseArea {
                    id: m
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 32
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData
                    onClicked: clocks.choose(modelData)
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: m.index === clocks.pick || m.containsMouse ? Theme.cardHover : "transparent"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: clocks.city(m.modelData) + "  "
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: 13 }
                        Small { anchors.left: parent.right; anchors.verticalCenter: parent.verticalCenter; text: m.modelData }
                    }
                }
            }
        }
    }

    // ---- System ----
    // Once a second while the panel is open: CPU from /proc/stat, RAM from /proc/meminfo, the
    // CPU and GPU temperature and GPU load from hwmon/sysfs (amdgpu) or nvidia-smi, the disk
    // of / from df when it opens.
    Component {
        id: systemW
        ColumnLayout {
            id: sys
            spacing: Theme.s2
            property var cpuHist: []
            property var gpuHist: []
            property var ramHist: []
            property var lastCpu: null
            property real cpu: -1
            property real gpu: -1
            property real cpuTemp: -1
            property real gpuTemp: -1
            property real ramUsed: 0
            property real ramTotal: 0
            property real diskUsed: 0
            property real diskTotal: 0
            // Found once: the hwmon files to read, and whether nvidia-smi is there.
            property string cpuTempFile
            property string gpuTempFile
            property string gpuBusyFile
            property bool nvidia: false
            property bool found: false

            function push(list, v) { const l = list.concat([Math.max(0, Math.min(1, v))]); return l.length > 60 ? l.slice(-60) : l; }
            function gb(b) { return (b / 1073741824).toFixed(1); }

            Process {
                id: probe
                command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do echo "hwmon $h $(cat $h/name)"; done; command -v nvidia-smi >/dev/null && echo nvidia; true']
                stdout: SplitParser {
                    onRead: line => {
                        const [kind, dir, name] = line.split(" ");
                        if (kind === "nvidia") sys.nvidia = true;
                        else if (["k10temp", "coretemp", "zenpower", "cpu_thermal"].indexOf(name) >= 0 && !sys.cpuTempFile) sys.cpuTempFile = dir + "/temp1_input";
                        else if (name === "amdgpu" && !sys.gpuTempFile) { sys.gpuTempFile = dir + "/temp1_input"; sys.gpuBusyFile = dir + "/device/gpu_busy_percent"; }
                    }
                }
                onExited: sys.found = true
            }
            Process {
                id: disk
                command: ["df", "-B1", "--output=size,used", "/"]
                stdout: SplitParser {
                    onRead: line => {
                        const [size, used] = line.trim().split(/\s+/).map(Number);
                        if (size) { sys.diskTotal = size; sys.diskUsed = used; }
                    }
                }
            }
            Process {
                running: win.open && sys.nvidia
                command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits", "-l", "1"]
                stdout: SplitParser {
                    onRead: line => {
                        const [u, t] = line.split(",").map(s => parseFloat(s));
                        sys.gpu = u / 100; sys.gpuTemp = t;
                    }
                }
            }
            FileView { id: stat; path: win.open ? "/proc/stat" : ""; blockLoading: true; printErrors: false }
            FileView { id: mem; path: win.open ? "/proc/meminfo" : ""; blockLoading: true; printErrors: false }
            FileView { id: ctemp; path: win.open ? sys.cpuTempFile : ""; blockLoading: true; printErrors: false }
            FileView { id: gtemp; path: win.open ? sys.gpuTempFile : ""; blockLoading: true; printErrors: false }
            FileView { id: gbusy; path: win.open ? sys.gpuBusyFile : ""; blockLoading: true; printErrors: false }

            Timer {
                interval: 1000
                running: win.open && sys.found
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    for (const f of [stat, mem, ctemp, gtemp, gbusy]) if (f.path) f.reload();
                    const t = (stat.text() ?? "").split("\n")[0].split(/\s+/).slice(1).map(Number);
                    if (t.length > 4) {
                        const idle = t[3] + t[4], total = t.reduce((a, b) => a + b, 0);
                        if (sys.lastCpu) sys.cpu = 1 - (idle - sys.lastCpu[0]) / Math.max(1, total - sys.lastCpu[1]);
                        sys.lastCpu = [idle, total];
                    }
                    const mi = mem.text() ?? "";
                    const kb = k => parseInt((new RegExp(k + ":\\s+(\\d+)")).exec(mi)?.[1] ?? 0) * 1024;
                    sys.ramTotal = kb("MemTotal");
                    sys.ramUsed = sys.ramTotal - kb("MemAvailable");
                    if (ctemp.path) sys.cpuTemp = parseInt(ctemp.text()) / 1000;
                    if (gtemp.path) sys.gpuTemp = parseInt(gtemp.text()) / 1000;
                    if (gbusy.path) sys.gpu = parseInt(gbusy.text()) / 100;
                    if (sys.cpu >= 0) sys.cpuHist = sys.push(sys.cpuHist, sys.cpu);
                    if (sys.gpu >= 0) sys.gpuHist = sys.push(sys.gpuHist, sys.gpu);
                    if (sys.ramTotal) sys.ramHist = sys.push(sys.ramHist, sys.ramUsed / sys.ramTotal);
                }
            }
            Connections {
                target: win
                function onOpenChanged() {
                    if (win.open) { disk.running = true; if (!sys.found) probe.running = true; }
                    else { sys.cpuHist = []; sys.gpuHist = []; sys.ramHist = []; sys.lastCpu = null; sys.cpu = sys.gpu = -1; }
                }
            }

            Meter {
                label: Tr.t("CPU")
                value: sys.cpu >= 0 ? Math.round(sys.cpu * 100) + "%" + (sys.cpuTemp > 0 ? " · " + Math.round(sys.cpuTemp) + " °C" : "") : "…"
                values: sys.cpuHist
            }
            Meter {
                visible: sys.gpu >= 0 || sys.gpuTemp > 0
                label: Tr.t("GPU")
                value: (sys.gpu >= 0 ? Math.round(sys.gpu * 100) + "%" : "") + (sys.gpu >= 0 && sys.gpuTemp > 0 ? " · " : "")
                       + (sys.gpuTemp > 0 ? Math.round(sys.gpuTemp) + " °C" : "")
                values: sys.gpuHist
            }
            Meter {
                label: Tr.t("Memory")
                value: Tr.t("%1 of %2 GB", sys.gb(sys.ramUsed), sys.gb(sys.ramTotal))
                values: sys.ramHist
            }
            // The disk: a bar, since it barely moves.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s1
                RowLayout {
                    Text { text: Tr.t("Disk (/)"); color: Theme.fg; font { family: Theme.sans; pixelSize: 13; weight: Font.Medium } }
                    Item { Layout.fillWidth: true }
                    Small { text: sys.diskTotal ? Tr.t("%1 of %2 GB", sys.gb(sys.diskUsed), sys.gb(sys.diskTotal)) : "…" }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: height / 2
                    color: Theme.track
                    Rectangle {
                        width: parent.width * (sys.diskTotal ? sys.diskUsed / sys.diskTotal : 0)
                        height: parent.height
                        radius: height / 2
                        color: Theme.accentText
                    }
                }
            }
        }
    }

    component Meter: ColumnLayout {
        property string label
        property string value
        property alias values: line.values
        Layout.fillWidth: true
        spacing: Theme.s0
        RowLayout {
            Text { text: label; color: Theme.fg; font { family: Theme.sans; pixelSize: 13; weight: Font.Medium } }
            Item { Layout.fillWidth: true }
            Small { text: value }
        }
        Spark { id: line; Layout.fillWidth: true }
    }

    // ---- Now playing ----
    Component {
        id: mediaW
        Item {
            implicitHeight: Desktop.player?.trackTitle ? 72 : idle.implicitHeight
            MediaCard {
                anchors.fill: parent
                visible: !!Desktop.player?.trackTitle
                color: Theme.win
            }
            Small {
                id: idle
                visible: !Desktop.player?.trackTitle
                text: Tr.t("Nothing is playing.")
            }
        }
    }

    // ---- Local AI ----
    // Ollama on this machine only (127.0.0.1:11434): the models from /api/tags, the answer
    // streamed from /api/generate. Nothing is sent anywhere else.
    Component {
        id: aiW
        ColumnLayout {
            id: ai
            spacing: Theme.s2
            readonly property string api: "http://127.0.0.1:11434"
            property string status: "checking"   // checking, down, up
            property var models: []
            readonly property string model: models.indexOf(Desktop.aiModel) >= 0 ? Desktop.aiModel : models[0] ?? ""
            property string answer: ""
            property string asked: ""
            property var xhr: null
            readonly property alias input: prompt.input
            readonly property var menu: models.map(m => ({ text: m, glyph: m === model ? "check" : "ai", run: () => Desktop.aiModel = m }))

            function check() {
                const x = new XMLHttpRequest();
                x.onreadystatechange = () => {
                    if (x.readyState !== XMLHttpRequest.DONE) return;
                    try {
                        ai.models = x.status === 200 ? JSON.parse(x.responseText).models.map(m => m.name) : [];
                        ai.status = x.status === 200 ? "up" : "down";
                    } catch (e) { ai.status = "down"; }
                };
                x.open("GET", api + "/api/tags");
                x.send();
            }
            // `think: false` keeps a reasoning model's thinking out of the answer; a model that
            // can't think refuses the flag, so that one is asked again without it.
            function ask(text, plain) {
                if (!text.trim() || !model) return;
                stop();
                asked = text;
                answer = "";
                prompt.text = "";
                const x = new XMLHttpRequest();
                let seen = 0, buf = "";
                // Each line of the stream is one JSON object with the next piece in `response`.
                let error = "";
                const take = done => {
                    buf += x.responseText.slice(seen);
                    seen = x.responseText.length;
                    const lines = buf.split("\n");
                    buf = done ? "" : lines.pop();
                    for (const l of lines) {
                        try { const o = JSON.parse(l); ai.answer += o.response ?? ""; if (o.error) error = o.error; } catch (e) {}
                    }
                };
                x.onreadystatechange = () => {
                    if (x.readyState === XMLHttpRequest.LOADING) take(false);
                    else if (x.readyState === XMLHttpRequest.DONE && ai.xhr === x) {
                        take(true);
                        ai.xhr = null;
                        if (x.status === 0) ai.check();
                        else if (error && !plain && /think/i.test(error)) ai.ask(text, true);
                        else if (error) ai.answer = error;
                    }
                };
                xhr = x;
                x.open("POST", api + "/api/generate");
                x.send(JSON.stringify(plain ? { model: model, prompt: text } : { model: model, prompt: text, think: false }));
            }
            function stop() {
                const x = xhr;
                xhr = null;
                x?.abort();
            }
            Connections {
                target: win
                function onOpenChanged() { if (win.open) ai.check(); }
            }

            Small {
                visible: ai.status === "down"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Tr.t("Ollama isn't running on this computer.")
            }
            RowLayout {
                visible: ai.status === "up"
                Layout.fillWidth: true
                spacing: Theme.s1
                Field {
                    id: prompt
                    Layout.fillWidth: true
                    placeholder: ai.models.length ? Tr.t("Ask %1…", ai.model) : Tr.t("No models installed.")
                    input.enabled: ai.models.length > 0
                    onAccepted: ai.ask(text)
                    input.Keys.onEscapePressed: event => { if (ai.xhr) ai.stop(); else event.accepted = false; }
                }
                Btn {
                    glyph: ai.xhr ? "stop" : "send"
                    name: ai.xhr ? Tr.t("Stop") : Tr.t("Send")
                    primary: true
                    enabled: ai.xhr !== null || prompt.text.trim() !== ""
                    onClicked: ai.xhr ? ai.stop() : ai.ask(prompt.text)
                }
            }
            Btn {
                id: pickModel
                visible: ai.status === "up" && ai.models.length > 1
                glyph: "ai"
                label: ai.model
                onClicked: menu.show(pickModel, ai.menu, false)
            }
            Small {
                visible: ai.asked !== ""
                Layout.fillWidth: true
                text: ai.asked
                font.weight: Font.DemiBold
            }
            Flickable {
                visible: ai.asked !== ""
                Layout.fillWidth: true
                implicitHeight: Math.min(answerText.implicitHeight, 260)
                contentHeight: answerText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Follows the answer as it grows.
                contentY: Math.max(0, contentHeight - height)
                TextEdit {
                    id: answerText
                    width: parent.width
                    Accessible.name: Tr.t("Answer")
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.Wrap
                    text: ai.answer || (ai.xhr ? Tr.t("Thinking…") : "")
                    color: ai.answer ? Theme.fg : Theme.soft
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentInk
                    font { family: Theme.sans; pixelSize: 13 }
                }
            }
        }
    }

    // ---- Weather ----
    // Open-Meteo (no key): the city from its geocoding API, then the forecast. Kept in
    // ~/.cache/kriss-weather.json and fetched at most every 30 minutes, only while the panel
    // is open and NetworkManager reports the internet.
    Component {
        id: weatherW
        ColumnLayout {
            id: wx
            spacing: Theme.s2
            property var cache: ({})
            readonly property bool fresh: cache.query === Desktop.weatherCity && Date.now() - (cache.fetched ?? 0) < 30 * 60000
            readonly property var cur: cache.query === Desktop.weatherCity ? cache.data?.current ?? null : null
            readonly property var daily: cache.query === Desktop.weatherCity ? cache.data?.daily ?? null : null
            property string error: ""
            property bool editing: false
            readonly property alias input: city.input
            readonly property var menu: [{ text: Tr.t("Change city"), glyph: "search", run: () => { wx.editing = true; city.input.forceActiveFocus(); } }]

            function kind(code) {
                return code === 0 ? ["sun", Tr.t("Clear")] : code <= 2 ? ["cloud", Tr.t("Partly cloudy")] : code === 3 ? ["cloud", Tr.t("Cloudy")]
                    : code <= 48 ? ["fog", Tr.t("Fog")] : code <= 57 ? ["rain", Tr.t("Drizzle")] : code <= 67 ? ["rain", Tr.t("Rain")]
                    : code <= 77 ? ["snow", Tr.t("Snow")] : code <= 82 ? ["rain", Tr.t("Showers")] : code <= 86 ? ["snow", Tr.t("Snow")]
                    : ["storm", Tr.t("Thunderstorm")];
            }
            function get(url, done) {
                const x = new XMLHttpRequest();
                x.onreadystatechange = () => {
                    if (x.readyState !== XMLHttpRequest.DONE) return;
                    try { if (x.status !== 200) throw x.status; done(JSON.parse(x.responseText)); }
                    catch (e) { wx.error = Tr.t("Couldn't get the weather."); }
                };
                x.open("GET", url);
                x.send();
            }
            function refresh() {
                const q = Desktop.weatherCity;
                if (!win.open || !win.online || !q || fresh) return;
                error = "";
                const forecast = place => get("https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude
                        + "&current=temperature_2m,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4",
                    data => {
                        wx.cache = { query: q, place: place, fetched: Date.now(), data: data };
                        file.setText(JSON.stringify(wx.cache));
                    });
                if (cache.query === q && cache.place) forecast(cache.place);
                else get("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(q), r => {
                    const p = r.results?.[0];
                    if (!p) { wx.error = Tr.t("No place called %1.", q); return; }
                    forecast({ name: p.name, country: p.country ?? "", latitude: p.latitude, longitude: p.longitude });
                });
            }

            FileView {
                id: file
                path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/kriss-weather.json"
                printErrors: false
                onLoaded: { try { wx.cache = JSON.parse(text()); } catch (e) {} wx.refresh(); }
            }
            Timer {
                interval: 30 * 60000
                running: win.open && win.online && Desktop.weatherCity !== ""
                repeat: true
                onTriggered: wx.refresh()
            }
            Connections {
                target: win
                function onOpenChanged() { wx.refresh(); }
                function onOnlineChanged() { wx.refresh(); }
            }
            Connections {
                target: Desktop
                function onWeatherCityChanged() { wx.refresh(); }
            }

            Field {
                id: city
                visible: !Desktop.weatherCity || wx.editing
                Layout.fillWidth: true
                placeholder: Tr.t("Type a city for the weather")
                onAccepted: { if (text.trim()) Desktop.weatherCity = text.trim(); text = ""; wx.editing = false; }
                input.Keys.onEscapePressed: event => { if (wx.editing) { wx.editing = false; event.accepted = true; } else event.accepted = false; }
            }
            Small { visible: wx.error !== ""; text: wx.error }
            RowLayout {
                visible: wx.cur !== null
                Layout.fillWidth: true
                spacing: Theme.s3
                Glyph { name: wx.kind(wx.cur?.weather_code ?? 0)[0]; size: 40; stroke: 1.6; color: Theme.accentText }
                Column {
                    Layout.fillWidth: true
                    Text {
                        text: Math.round(wx.cur?.temperature_2m ?? 0) + " °C"
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: 30; weight: Font.DemiBold }
                    }
                    Small { text: wx.kind(wx.cur?.weather_code ?? 0)[1] + " · " + Tr.t("Wind %1 km/h", Math.round(wx.cur?.wind_speed_10m ?? 0)) }
                }
                Small {
                    Layout.alignment: Qt.AlignTop
                    horizontalAlignment: Text.AlignRight
                    text: (wx.cache.place?.name ?? "") + "\n" + (wx.cache.place?.country ?? "")
                }
            }
            // Today and the next three days.
            RowLayout {
                visible: wx.daily !== null
                Layout.fillWidth: true
                Repeater {
                    model: wx.daily?.time?.length ?? 0
                    delegate: Column {
                        required property int index
                        Layout.fillWidth: true
                        spacing: Theme.s1
                        Small {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: index === 0 ? Tr.t("Today") : new Date(wx.daily.time[index] + "T12:00").toLocaleString(Qt.locale(), "ddd")
                        }
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: wx.kind(wx.daily.weather_code[index])[0]; size: 20; color: Theme.fg }
                        Small {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(wx.daily.temperature_2m_max[index]) + "° " + Math.round(wx.daily.temperature_2m_min[index]) + "°"
                        }
                    }
                }
            }
        }
    }
}
