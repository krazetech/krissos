import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Window previews above a taskbar app, as on Windows 11: rest the pointer on a running app
// for a moment and its windows show as live pictures. Click one to switch to it, × or a
// middle click closes it. Moving along the bar swaps the previews straight away; they leave
// a moment after the pointer does. With the pointer on them, the arrows move, Enter switches,
// Delete closes and Esc leaves. Pictures are captured only while this is shown, at its size,
// by kriss-shell-toplevels.
// ponytail: no "peek" (showing the hovered window alone on the desktop); cosmic-comp has no
// way to do it without raising the window and changing the focus order.
PanelWindow {
    id: win

    // The bar calls hover() as the pointer enters and leaves its app buttons (Bar.previewFor).
    function hover(btn) {
        hovered = btn;
        if (!btn || btn.wins.length === 0) {
            showTimer.stop();
            if (open) hideTimer.restart();
            return;
        }
        // The button itself can be rebuilt while the timer runs, so keep what it says now.
        pending = { app: btn.modelData, x: btn.mapToItem(null, btn.width / 2, 0).x };
        if (open) take();
        else showTimer.restart();
    }
    function hide() {
        showTimer.stop();
        hideTimer.stop();
        open = false;
        // The keyboard goes back to the bar's button.
        if (byKeyboard) { byKeyboard = false; Desktop.keysTo(keysBack); }
    }
    // Up on a taskbar button from the keyboard: its previews, with the keyboard on them; Esc
    // gives it back to the button.
    property bool byKeyboard: false
    property Item keysBack: null
    function openFrom(btn) {
        if (!btn || btn.wins.length === 0) return;
        pending = { app: btn.modelData, x: btn.mapToItem(null, btn.width / 2, 0).x };
        take();
        byKeyboard = true;
        current = 0;
        panel.forceActiveFocus();
        keysBack = Desktop.keysFor;
        Desktop.keysTo(panel);
    }
    // A screen reader hears the window as the keyboard moves.
    onCurrentChanged: if (byKeyboard && wins[current]) panel.Accessible.announce(wins[current].title || wins[current].appId)
    function take() {
        hideTimer.stop();
        app = pending.app;
        anchorX = pending.x;
        current = -1;
        open = true;
    }

    // The button under the pointer: pressing it puts the previews away, as on Windows.
    property Item hovered: null
    Connections {
        target: win.hovered
        function onPressedChanged() { if (win.hovered.pressed) win.hide(); }
    }

    property var pending: null
    property var app: null
    property real anchorX: 0
    property bool open: false
    property int current: -1
    readonly property var wins: app ? Windows.forApp(app.appId) : []
    onWinsChanged: {
        if (wins.length === 0) hide();
        current = Math.min(current, wins.length - 1);
    }

    // `qs ipc call previews open APP X`: the previews of APP as if its button were at X, for
    // testing without a pointer (perf-check, nested sessions); `close` puts them away.
    IpcHandler {
        target: "previews"
        enabled: win.screen === Quickshell.screens[0]
        function open(appId: string, x: int): void {
            win.pending = { app: { appId: appId, entry: DesktopEntries.heuristicLookup(appId) }, x: x };
            win.take();
        }
        function close(): void { win.hide(); }
    }

    Timer { id: showTimer; interval: 400; onTriggered: win.take() }
    Timer { id: hideTimer; interval: 300; onTriggered: win.open = false }

    // Cards share the screen's width: full size, then narrower, then they scroll.
    readonly property int pad: 8
    readonly property int cardW: Math.max(150, Math.min(216, Math.floor((width - Theme.gap * 2 - pad * 2 + pad) / Math.max(1, wins.length)) - pad))
    readonly property int thumbW: cardW - 16
    readonly property int thumbH: Math.round(thumbW * 0.6)
    readonly property int cardH: thumbH + 48

    // Capture exactly the windows on show, at their size on this screen; nothing when hidden.
    // ponytail: one capture list for all screens; moving straight from one screen's previews
    // to another's can leave the second without pictures until its next change.
    readonly property string capturing: open ? Math.ceil(thumbW * (screen?.devicePixelRatio ?? 1)) + " " + wins.map(w => w.id).join(" ") : ""
    onCapturingChanged: Windows.capture(open ? wins.map(w => w.id) : [], open ? Math.ceil(thumbW * (screen?.devicePixelRatio ?? 1)) : 0)

    visible: open || panel.opacity > 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-previews"
    // The keyboard only while the pointer is on the previews, so resting on the bar never
    // takes it from the app being typed in.
    WlrLayershell.keyboardFocus: open && pointer.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { bottom: true; left: true; right: true }
    implicitHeight: cardH + pad * 2 + Theme.panelGap
    color: "transparent"
    // Clicks only on the panel, and none while it fades out.
    mask: open ? panelRegion : noInput
    Region { id: panelRegion; item: panel }
    Region { id: noInput }
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    Rectangle {
        id: panel
        width: Math.min(list.contentWidth, win.width - Theme.gap * 2 - win.pad * 2) + win.pad * 2
        height: win.cardH + win.pad * 2
        x: Math.max(Theme.gap, Math.min(win.width - width - Theme.gap, win.anchorX - width / 2))
        y: win.height - height - Theme.panelGap
        radius: Theme.radiusSmall + win.pad
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.rim
        focus: true
        Accessible.role: Accessible.List
        Accessible.name: Tr.t("Window previews")

        // Slides along the bar to the next app, but appears in place.
        Behavior on x { enabled: panel.opacity > 0; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        Behavior on width { enabled: panel.opacity > 0; NumberAnimation { duration: Theme.ms(Theme.normal); easing.type: Theme.ease } }
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        transform: Translate { y: win.open || Theme.reduceMotion ? 0 : 8; Behavior on y { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } } }

        HoverHandler {
            id: pointer
            onHoveredChanged: if (hovered) hideTimer.stop(); else if (win.open && !win.byKeyboard) hideTimer.restart()
        }

        Keys.onPressed: event => {
            const n = win.wins.length, w = win.wins[win.current];
            if (event.key === Qt.Key_Right) win.current = Math.min(n - 1, win.current + 1);
            else if (event.key === Qt.Key_Left) win.current = Math.max(0, win.current - 1);
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && w) { Windows.activate(w.id); win.hide(); }
            else if (event.key === Qt.Key_Delete && w) Windows.close(w.id);
            else if (event.key === Qt.Key_Escape) win.hide();
            else return;
            list.positionViewAtIndex(Math.max(0, win.current), ListView.Contain);
            event.accepted = true;
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: win.pad
            orientation: ListView.Horizontal
            spacing: win.pad
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // By position, so a title or focus change updates a card instead of rebuilding it.
            model: win.wins.length

            delegate: MouseArea {
                id: card
                required property int index
                readonly property var w: win.wins[index]
                readonly property var entry: win.app?.entry ?? DesktopEntries.heuristicLookup(w?.appId ?? "")
                readonly property bool lit: win.current === index

                width: win.cardW
                height: win.cardH
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onEntered: win.current = index
                Accessible.role: Accessible.ListItem
                Accessible.name: w?.title || entry?.name || w?.appId || ""
                Accessible.selected: lit
                Accessible.onPressAction: if (w) { Windows.activate(w.id); win.hide(); }
                onClicked: mouse => {
                    if (!w) return;
                    if (mouse.button === Qt.MiddleButton) { Windows.close(w.id); return; }
                    Windows.activate(w.id);
                    win.hide();
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: card.pressed ? Theme.cardHover : card.lit ? Theme.card : "transparent"
                    border.width: Theme.focusWidth
                    border.color: card.lit && win.byKeyboard ? Theme.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }

                IconImage {
                    id: icon
                    x: 10; y: 10
                    implicitSize: 16
                    source: Quickshell.iconPath(card.entry?.icon ?? card.w?.appId ?? "", "application-x-executable")
                }
                Text {
                    anchors { left: icon.right; leftMargin: 8; right: close.left; rightMargin: 4; verticalCenter: icon.verticalCenter }
                    text: card.w?.title || card.entry?.name || card.w?.appId || ""
                    elide: Text.ElideRight
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(12); weight: card.w?.active && !card.w?.minimized ? Font.DemiBold : Font.Medium }
                }
                MouseArea {
                    id: close
                    x: parent.width - width - 4; y: 4
                    width: 28; height: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    opacity: card.lit ? 1 : 0
                    enabled: card.lit
                    onClicked: if (card.w) Windows.close(card.w.id)
                    Accessible.role: Accessible.Button
                    Accessible.name: Tr.t("Close window")
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: close.containsMouse ? Theme.red : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Glyph { anchors.centerIn: parent; name: "close"; size: 14; color: close.containsMouse ? Theme.nightFg : Theme.fg }
                }

                // The live picture, or the app's icon until there is one (a window minimized
                // before it was ever previewed has none).
                Item {
                    x: 8; y: 40
                    width: win.thumbW
                    height: win.thumbH
                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: card.w ? Windows.thumbs[card.w.id] ?? "" : ""
                        fillMode: Image.PreserveAspectFit
                        // A new file each frame, small enough to load in place without a blank frame.
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
