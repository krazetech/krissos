// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Toasts stack above the tray, bottom right, the way Sonner stacks them: the newest in
// front, older ones peeking out behind it, smaller. Hovering fans the stack out and
// pauses the timers; a swipe to the right dismisses one. While quick settings or the
// calendar is open in that corner, the toasts arrive above it. The bell (or Windows+N) opens
// the notification center, one panel as on Windows: Do not disturb and Clear all, then
// everything not yet dismissed, newest first, grouped by app under the app's name, then the
// month.
PanelWindow {
    id: win

    readonly property bool open: Desktop.notificationsOpen
    // The cards on show, newest first; a card's place in it is its depth. In the open list
    // each app's cards sit together, the app with the newest one first, as on Windows; the
    // list reads from the top, newest first, where the toasts stack up from the bottom.
    readonly property var shown: {
        const list = Notifs.all.filter(n => open || Notifs.isPopup(n)).reverse();
        if (!open) return list;
        const apps = [...new Set(list.map(n => n.appName))];
        return apps.reduce((out, app) => out.concat(list.filter(n => n.appName === app)), []);
    }
    readonly property var shownIds: shown.map(n => n.id)
    readonly property bool expanded: open || hover.hovered
    // Toasts sit above quick settings or the calendar while one is open (Desktop.cornerRoom).
    property real lift: open ? 0 : Desktop.cornerRoom
    Behavior on lift { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
    readonly property int gap: Theme.s2
    readonly property int peek: 14

    // Card heights by id, as each card reports its own.
    property var heights: ({})
    function setHeight(id, h) {
        if (heights[id] === h) return;
        const next = Object.assign({}, heights);
        next[id] = h;
        heights = next;
    }
    function heightAt(depth) { return heights[shownIds[depth]] ?? 0; }
    // Fanned out: how far above the stack's bottom the card at this depth ends.
    function below(depth) {
        let sum = 0;
        for (let d = 0; d < depth; d++) sum += heightAt(d) + gap;
        return sum;
    }
    readonly property real stackHeight: !shownIds.length ? 0
        : expanded ? below(shownIds.length - 1) + heightAt(shownIds.length - 1)
        : heightAt(0) + Math.min(shownIds.length - 1, 2) * peek

    // Sonner's own curve: quick out, a touch of settle at the end.
    readonly property var curve: Theme.settleCurve

    // Stays up while the last cards slide away.
    readonly property bool wanted: shownIds.length > 0 || open
    onWantedChanged: if (!wanted) linger.restart()
    Timer { id: linger; interval: Theme.ms(Theme.slow) }
    visible: wanted || linger.running
    screen: Desktop.screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-notifications"
    exclusionMode: ExclusionMode.Ignore
    // Over the taskbar's tray; in the Mac layout, under the top bar.
    anchors { bottom: !Desktop.mac; top: Desktop.mac; right: true }
    margins { right: Theme.panelGap; bottom: Theme.barHeight + Theme.panelGap; top: Theme.topBarHeight + Theme.panelGap }
    implicitWidth: Theme.dp(380)
    // A fixed size, so the cards can move without the window resizing under them every
    // frame; clicks outside the cards go through to the windows behind.
    implicitHeight: (screen?.height ?? 1080) - Desktop.topRoom - Desktop.bottomRoom - 2 * Theme.panelGap
    mask: Region { item: column }
    color: "transparent"
    // Blur behind the header, the month and each card on show, the cards cut to the list.
    property var cardBlurs: []
    BackgroundEffect.blurRegion: Region {
        Region { item: sheet.visible ? sheet : null; radius: sheet.radius }
        Region { regions: win.cardBlurs.concat([listClip]) }
    }
    // ponytail: a Region follows only its own item's moves, so y (unused next to item) is
    // bound to the scroll to rebuild the blur as the open list scrolls.
    Region { id: listClip; item: scroller; y: scroller.contentY; intersection: Intersection.Intersect }
    // The keyboard while the center is open: Tab walks the header, the cards (top to bottom)
    // and the month; on a card Enter takes its action, Delete dismisses it and the Menu key
    // or Shift+F10 lists all it can do. Esc closes.
    // (Through Desktop.keysTo: this window is often on screen already, with toasts.)

    // A screen reader hears each notification that shows as a toast; critical ones cut in.
    Connections {
        target: Notifs
        function onCame(n) {
            const critical = n.urgency === NotificationUrgency.Critical;
            if (Desktop.dnd && !critical) return;
            const text = !n.body ? n.summary : !n.summary ? n.body : n.summary + (/[.!?…:]$/.test(n.summary) ? " " : ". ") + n.body;
            column.Accessible.announce(Tr.t("Notification from %1: %2", n.appName || Tr.t("an app"), text),
                critical ? Accessible.Assertive : Accessible.Polite);
        }
    }

    // The card at a depth (0 is the newest: the bottom toast, the top of the open list), for the keys.
    function cardAt(depth) {
        for (let i = 0; i < cards.count; i++) if (cards.itemAt(i)?.depth === depth) return cards.itemAt(i);
        return null;
    }
    function focusCard(depth) {
        const c = cardAt(depth);
        if (c) c.focusItem.forceActiveFocus();
        return !!c;
    }
    function cardMenu(card) {
        const n = card.n, out = n.actions.map(a => ({ text: a.text || Tr.t("Open"), run: () => Notifs.invoke(n, a) }));
        if (out.length) out.push({ sep: true });
        out.push({ text: Tr.t("Dismiss"), glyph: "close", run: () => Notifs.dismiss(n) });
        const same = Notifs.all.filter(m => m.appName === n.appName).length;
        if (same > 1) out.push({ text: Tr.t("Clear %1", same), glyph: "trash", run: () => Notifs.clear(n.appName) });
        menu.show(card.focusItem, out, true);
    }
    Menu { id: menu }

    // While the list is open, a click anywhere else (bar aside) or Esc closes it,
    // like the quick settings panel. The toasts sit above it on the overlay layer.
    PanelWindow {
        visible: Desktop.notificationsOpen
        screen: Desktop.screen
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kriss-notifications-close"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        MouseArea {
            Accessible.ignored: true  // pointer only; the keyboard has its own way
            anchors.fill: parent
            onClicked: Desktop.notificationsOpen = false
        }
    }

    // Opening puts the keyboard on the newest card (once the list has regrouped), else on Do not disturb.
    onOpenChanged: {
        if (open) {
            month.reset();
            Desktop.keysTo(column);
            Qt.callLater(() => focusCard(0) || dnd.forceActiveFocus());
        } else {
            column.forceActiveFocus();  // no focus rim left on a toast
            if (Desktop.keysFor === column || Desktop.keysNext === column) Desktop.keysTo(null);
        }
    }

    HoverHandler { id: hover; onHoveredChanged: Notifs.paused = hovered }

    // The center's one panel, behind the header, the list and the month.
    Rectangle {
        id: sheet
        visible: opacity > 0
        opacity: header.opacity
        y: column.y
        width: parent.width
        height: column.height
        radius: Theme.rPanel
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.rim
    }

    Column {
        id: column
        anchors { left: parent.left; right: parent.right }
        y: Desktop.mac ? win.lift : parent.height - height - win.lift
        spacing: win.open ? 0 : win.gap
        Accessible.role: Accessible.Grouping
        Accessible.name: Tr.t("Notifications")
        Keys.onPressed: event => {
            const f = column.Window.activeFocusItem;
            if (event.key === Qt.Key_Escape) Desktop.back("notificationsOpen");
            else if (f && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab))
                f.nextItemInFocusChain(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)).forceActiveFocus();
            else return;
            event.accepted = true;
        }

        // Header while the list is open.
        Rectangle {
            id: header
            visible: opacity > 0
            opacity: win.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.ms(win.open ? Theme.fast : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }
            width: parent.width
            height: Math.max(56, Theme.sp(14) + 36)
            color: "transparent"
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.line }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s2
                Text {
                    Layout.fillWidth: true
                    text: Notifs.all.length ? Tr.t("Notifications") : Tr.t("No new notifications")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.DemiBold }
                }
                MouseArea {
                    id: dnd
                    implicitWidth: 32
                    implicitHeight: 32
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Desktop.dnd = !Desktop.dnd
                    activeFocusOnTab: true
                    Keys.onReturnPressed: Desktop.dnd = !Desktop.dnd
                    Keys.onEnterPressed: Desktop.dnd = !Desktop.dnd
                    Keys.onSpacePressed: Desktop.dnd = !Desktop.dnd
                    Keys.onTabPressed: clearAll.visible ? clearAll.forceActiveFocus() : win.focusCard(0) || month.focusFirst()
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: Tr.t("Do not disturb")
                    Accessible.checkable: true
                    Accessible.checked: Desktop.dnd
                    Accessible.onToggleAction: Desktop.dnd = !Desktop.dnd
                    Accessible.onPressAction: Desktop.dnd = !Desktop.dnd
                    FocusRim { radius: Theme.rControl + 4 }
                    scale: pressed ? Theme.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: Desktop.dnd ? Theme.accent : dnd.containsMouse ? Theme.cardHover : Theme.card
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Glyph { anchors.centerIn: parent; name: "bellOff"; size: 15; color: Desktop.dnd ? Theme.accentInk : Theme.fg }
                }
                MouseArea {
                    id: clearAll
                    visible: Notifs.all.length > 0
                    implicitWidth: clearText.implicitWidth + 24
                    implicitHeight: 32
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clear()
                    activeFocusOnTab: true
                    Keys.onReturnPressed: Notifs.clear()
                    Keys.onEnterPressed: Notifs.clear()
                    Keys.onSpacePressed: Notifs.clear()
                    Keys.onTabPressed: win.focusCard(0) || month.focusFirst()
                    Keys.onBacktabPressed: dnd.forceActiveFocus()
                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.t("Clear all")
                    Accessible.onPressAction: Notifs.clear()
                    onVisibleChanged: if (!visible && activeFocus) dnd.forceActiveFocus()
                    FocusRim { radius: Theme.rControl + 4 }
                    scale: pressed ? Theme.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: clearAll.containsMouse ? Theme.cardHover : Theme.card
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: Tr.t("Clear all")
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                    }
                }
            }
        }

        // Open, a list taller than the room left scrolls, kept at the newest end.
        Flickable {
            id: scroller
            width: parent.width
            height: Math.min(stack.height + (win.open ? 2 * Theme.s3 : 0), win.height - win.lift - (win.open ? header.height + cal.height : 0))
            contentHeight: stack.height + (win.open ? 2 * Theme.s3 : 0)
            contentY: win.open ? 0 : contentHeight - height
            interactive: win.open && contentHeight > height
            clip: win.open
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: stack
                y: win.open ? Theme.s3 : 0
                width: win.width
                height: win.stackHeight
                Behavior on height { NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: win.curve } }

                Repeater {
                    id: cards
                    model: Notifs.model
                    delegate: Item {
                        id: card
                        readonly property alias focusItem: swipe
                        required property var modelData
                        readonly property var n: modelData
                        readonly property var defaultAction: n.actions.find(a => a.identifier === "default")
                        readonly property int depth: win.shownIds.indexOf(n.id)
                        readonly property bool shown: depth >= 0
                        readonly property bool front: depth === 0 || win.expanded
                        // The first card of an app's group in the open list carries the group's
                        // header: the app, how many, and Clear.
                        readonly property bool groupHead: win.open && shown && (depth === 0 || win.shown[depth - 1].appName !== n.appName)
                        readonly property int groupSize: groupHead ? win.shown.filter(m => m.appName === n.appName).length : 0
                        readonly property int headH: groupHead ? Math.max(36, Theme.sp(12) + 22) : 0
                        readonly property real naturalHeight: content.implicitHeight + 28 + headH
                        onNaturalHeightChanged: win.setHeight(n.id, naturalHeight)
                        // Each item in the window costs the window's first frame, hidden or not, and the
                        // history keeps up to 100 cards: a card's contents are taken out of the window
                        // (kept, not destroyed) unless it is on show, and in the open list only if it could
                        // reach the visible part (none is shorter than its 40 px icon and 28 px of padding).
                        // They stay in while the card fades out.
                        readonly property bool wanted: shown && (!win.open || depth * (68 + win.gap) < scroller.contentY + scroller.height)
                        property bool live: false
                        onWantedChanged: if (wanted) live = true; else if (opacity === 0) live = false
                        onOpacityChanged: if (opacity === 0 && !wanted) live = false

                        // Slides up into place when it arrives.
                        property bool arrived: false
                        Component.onCompleted: {
                            live = wanted;
                            win.setHeight(n.id, naturalHeight);
                            arrived = true;
                            win.cardBlurs = win.cardBlurs.concat([blur]);
                        }
                        Component.onDestruction: win.cardBlurs = win.cardBlurs.filter(r => r !== blur)
                        Region { id: blur; item: card.opacity > 0 && !win.open ? card : null; radius: Theme.rPanel }

                        width: stack.width
                        height: front ? naturalHeight : win.heightAt(0)
                        y: !shown || !arrived ? stack.height + 24
                            : win.open ? win.below(depth)
                            : win.expanded ? stack.height - win.below(depth) - naturalHeight
                            : stack.height - win.heightAt(0) - Math.min(depth, 2) * win.peek
                        scale: win.expanded || !shown ? 1 : 1 - Math.min(depth, 2) * 0.05
                        transformOrigin: Item.Top
                        opacity: shown && arrived && (win.expanded || depth < 3) ? 1 : 0
                        z: -depth
                        enabled: shown

                        Behavior on y { NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: win.curve } }
                        Behavior on height { NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: win.curve } }
                        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.slow); easing.type: Easing.BezierSpline; easing.bezierCurve: win.curve } }
                        Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }

                        // Swipe right to dismiss; a click takes the default action.
                        MouseArea {
                            id: swipe
                            anchors.fill: parent
                            cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                            drag.target: face
                            drag.axis: Drag.XAxis
                            drag.minimumX: 0
                            drag.maximumX: card.width
                            onClicked: card.defaultAction ? Notifs.invoke(card.n, card.defaultAction) : Notifs.dismiss(card.n)
                            Accessible.role: Accessible.Notification
                            Accessible.name: card.n.summary || card.n.appName
                            Accessible.description: [card.n.appName, Notifs.ago(card.n), card.n.body,
                                card.n.actions.length ? Tr.t("Menu key for actions") : ""]
                                .map(s => (s ?? "").trim().replace(/[.!?…]+$/, "")).filter(s => s).join(". ")
                            Accessible.onPressAction: if (card.defaultAction) Notifs.invoke(card.n, card.defaultAction)
                            // Up and down (Tab and Shift+Tab) go down and up the list as it looks.
                            Keys.onPressed: event => {
                                const d = card.depth;
                                switch (event.key) {
                                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                                    if (card.defaultAction) Notifs.invoke(card.n, card.defaultAction); else win.cardMenu(card);
                                    break;
                                case Qt.Key_Delete: case Qt.Key_Backspace:
                                    if (!win.focusCard(d + 1) && !win.focusCard(d - 1)) dnd.forceActiveFocus();
                                    Notifs.dismiss(card.n);
                                    break;
                                case Qt.Key_Menu: win.cardMenu(card); break;
                                case Qt.Key_F10: if (event.modifiers & Qt.ShiftModifier) win.cardMenu(card); else return; break;
                                case Qt.Key_Down: case Qt.Key_Tab: if (!win.focusCard(d + 1)) month.focusFirst(); break;
                                case Qt.Key_Up: case Qt.Key_Backtab: if (!win.focusCard(d - 1)) (clearAll.visible ? clearAll : dnd).forceActiveFocus(); break;
                                default: return;
                                }
                                event.accepted = true;
                            }
                            onReleased: {
                                if (face.x > card.width * 0.35) away.start();
                                else face.x = 0;
                            }
                        }
                        NumberAnimation {
                            id: away
                            target: face; property: "x"; to: card.width + 24
                            duration: Theme.ms(Theme.fast); easing.type: Theme.ease
                            onFinished: Notifs.dismiss(card.n)
                        }

                        // The group's header, above its first card; it stays put while a card swipes.
                        RowLayout {
                            parent: card.groupHead && card.live ? card : null
                            x: Theme.s4; width: card.width - Theme.s4 - Theme.s3
                            height: card.headH
                            spacing: Theme.s2
                            IconImage {
                                implicitSize: 16
                                visible: status === Image.Ready
                                source: Quickshell.iconPath(card.n.appIcon || card.n.appName.toLowerCase(), true)
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.preferredWidth: implicitWidth
                                Layout.maximumWidth: implicitWidth
                                text: card.n.appName || Tr.t("Other apps")
                                elide: Text.ElideRight
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                            }
                            Text {
                                visible: card.groupSize > 1
                                text: card.groupSize
                                color: Theme.soft
                                font { family: Theme.sans; pixelSize: Theme.sp(12) }
                            }
                            Item { Layout.fillWidth: true }
                            MouseArea {
                                id: groupHit
                                visible: card.groupSize > 1
                                implicitWidth: clearGroup.implicitWidth + 20
                                implicitHeight: 32
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.clear(card.n.appName)
                                Accessible.role: Accessible.Button
                                Accessible.name: Tr.t("Clear %1", card.groupSize)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.rControl
                                    color: groupHit.containsMouse ? Theme.cardHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                }
                                Text {
                                    id: clearGroup
                                    anchors.centerIn: parent
                                    text: Tr.t("Clear")
                                    color: Theme.accentText
                                    font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                                }
                            }
                        }

                        Item {
                            id: face
                            parent: card.live ? card : null
                            y: card.headH
                            width: card.width
                            height: card.height - card.headH
                            opacity: 1 - Math.max(0, x) / card.width
                            Behavior on x {
                                enabled: !swipe.drag.active && !away.running
                                NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Easing.BezierSpline; easing.bezierCurve: win.curve }
                            }

                            // A toast is its own panel; in the open center a card is a box inside it.
                            readonly property int inset: win.open ? Theme.s3 : 0
                            FocusRim { target: swipe; anchors.margins: 0; anchors.leftMargin: face.inset; anchors.rightMargin: face.inset; radius: box.radius }
                            Rectangle {
                                id: box
                                anchors.fill: parent
                                anchors.leftMargin: face.inset
                                anchors.rightMargin: face.inset
                                radius: win.open ? Theme.rCard : Theme.rPanel
                                color: win.open ? Theme.card : Theme.bar
                                border.width: card.n.urgency === NotificationUrgency.Critical ? 2 : win.open ? 0 : Theme.rimWidth
                                border.color: card.n.urgency === NotificationUrgency.Critical ? Theme.red : Theme.rim
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: face.inset
                                anchors.rightMargin: face.inset
                                clip: true
                                // Cards behind the front one show only their edge.
                                opacity: card.front ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }

                                RowLayout {
                                    id: content
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s3 }
                                    spacing: Theme.s3

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        implicitWidth: 40; implicitHeight: 40; radius: Theme.rControl
                                        color: Theme.card
                                        IconImage {
                                            id: appIcon
                                            anchors.centerIn: parent
                                            implicitSize: 26
                                            visible: status === Image.Ready
                                            source: card.n.image || Quickshell.iconPath(card.n.appIcon || card.n.appName.toLowerCase(), true)
                                        }
                                        Glyph { anchors.centerIn: parent; visible: !appIcon.visible; name: "bell"; size: 20; color: Theme.accentText }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.s0
                                        // App name and when, like the header of a Windows notification;
                                        // in the open center the group's header names the app.
                                        Text {
                                            Layout.fillWidth: true
                                            text: [win.open ? "" : card.n.appName, Notifs.ago(card.n)].filter(s => s).join(" · ")
                                            elide: Text.ElideRight
                                            color: Theme.soft
                                            font { family: Theme.sans; pixelSize: Theme.sp(12) }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.fillWidth: true
                                                text: card.n.summary || card.n.appName
                                                elide: Text.ElideRight
                                                color: Theme.fg
                                                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.DemiBold }
                                            }
                                            MouseArea {
                                                implicitWidth: 22; implicitHeight: 22
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Notifs.dismiss(card.n)
                                                Accessible.role: Accessible.Button
                                                Accessible.name: Tr.t("Dismiss")
                                                Glyph { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.soft }
                                            }
                                        }
                                        Text {
                                            visible: text.length > 0
                                            Layout.fillWidth: true
                                            text: card.n.body
                                            textFormat: Text.PlainText
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
                                            color: Theme.soft
                                            font { family: Theme.sans; pixelSize: Theme.sp(13) }
                                            lineHeight: 1.15
                                        }
                                        Flow {
                                            visible: buttons.count > 0
                                            Layout.fillWidth: true
                                            Layout.topMargin: Theme.s1
                                            spacing: Theme.s1
                                            Repeater {
                                                id: buttons
                                                model: card.n.actions.filter(a => a.identifier !== "default")
                                                delegate: MouseArea {
                                                    id: act
                                                    required property var modelData
                                                    required property int index
                                                    width: actText.implicitWidth + 26
                                                    height: Math.max(30, actText.implicitHeight + 12)
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Notifs.invoke(card.n, modelData)
                                                    Accessible.role: Accessible.Button
                                                    Accessible.name: modelData.text
                                                    scale: pressed ? Theme.pressScale : 1
                                                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                                    // The first action is the one most apps expect you to take.
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: height / 2
                                                        color: act.index === 0 ? (act.containsMouse ? Theme.accentHover : Theme.accent)
                                                            : act.containsMouse ? Theme.cardHover : Theme.card
                                                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                                    }
                                                    Text {
                                                        id: actText
                                                        anchors.centerIn: parent
                                                        text: act.modelData.text
                                                        color: act.index === 0 ? Theme.accentInk : Theme.fg
                                                        font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.DemiBold }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // The month, under the list.
        Rectangle {
            id: cal
            visible: opacity > 0
            opacity: win.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.ms(win.open ? Theme.fast : Theme.fastExit); easing.type: win.open ? Theme.ease : Theme.easeExit } }
            width: parent.width
            height: month.implicitHeight + 36
            color: "transparent"
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.line }
            MouseArea {
                Accessible.ignored: true  // pointer only; the keyboard has its own way
                anchors.fill: parent
                onWheel: wheel => month.page(wheel.angleDelta.y > 0 ? -1 : 1)
            }
            Month {
                id: month
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
                // Shift+Tab from the month goes back to the last card.
                onBackOut: win.focusCard(win.shownIds.length - 1) || (clearAll.visible ? clearAll : dnd).forceActiveFocus()
            }
        }
    }

    // Where the open list is cut, it fades into the panel instead of stopping hard.
    Rectangle {
        visible: win.open && scroller.contentY > 1
        x: Theme.rimWidth; width: parent.width - 2 * Theme.rimWidth
        y: column.y + scroller.y; height: 24
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.bar }
            GradientStop { position: 1; color: Theme.alpha(Theme.bar, 0) }
        }
    }
    Rectangle {
        visible: win.open && scroller.contentY < scroller.contentHeight - scroller.height - 1
        x: Theme.rimWidth; width: parent.width - 2 * Theme.rimWidth
        y: column.y + scroller.y + scroller.height - height; height: 24
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(Theme.bar, 0) }
            GradientStop { position: 1; color: Theme.bar }
        }
    }
}
