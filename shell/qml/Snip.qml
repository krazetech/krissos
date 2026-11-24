import QtQuick
import Quickshell
import Quickshell.Wayland

// Windows+Shift+S: the snipping bar, as on Windows. Draw a box for a screenshot, take the
// whole screen, or record the screen (Desktop.record). At the top of the main display;
// Esc or a click outside closes it. While a recording runs, its button stops it.
PanelWindow {
    id: win

    property bool open: false
    property int at: 0
    readonly property var choices: [
        ["region", "region", Tr.t("Rectangle")],
        ["screen", "display", Tr.t("Full screen")],
        ["record", Desktop.recording ? "stop" : "record", Desktop.recording ? Tr.t("Stop recording") : Tr.t("Record the screen")]
    ]
    function toggle() {
        open = !open;
        at = 0;
        if (open) Desktop.opened(true);
    }
    function pick(i) {
        open = false;
        const what = choices[i][0];
        if (what === "record") Desktop.record();
        // After the bar has gone, so it is not in the picture.
        else Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec kriss-shell screenshot " + (what === "region" ? "area" : "")]);
    }

    screen: Desktop.primary
    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-snip"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // The screen dims a little, as on Windows.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("black", 0.25)
        MouseArea {
            anchors.fill: parent
            Accessible.ignored: true  // a click outside closes; Esc does the same
            onClicked: win.open = false
        }
    }

    Rectangle {
        id: panel
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Desktop.topRoom + Theme.s4 }
        width: row.implicitWidth + 2 * Theme.s2
        height: row.implicitHeight + 2 * Theme.s2
        radius: Theme.rCard
        color: Theme.bar
        border.width: Theme.rimWidth
        border.color: Theme.line
        Accessible.role: Accessible.ToolBar
        Accessible.name: Tr.t("Snipping")
        focus: win.open
        Keys.onEscapePressed: win.open = false
        Keys.onLeftPressed: win.at = (win.at + win.choices.length - 1) % win.choices.length
        Keys.onRightPressed: win.at = (win.at + 1) % win.choices.length
        Keys.onTabPressed: win.at = (win.at + 1) % win.choices.length
        Keys.onReturnPressed: win.pick(win.at)
        Keys.onEnterPressed: win.pick(win.at)
        Keys.onSpacePressed: win.pick(win.at)
        Row {
            id: row
            x: Theme.s2
            y: Theme.s2
            spacing: Theme.s1
            Repeater {
                model: win.choices
                MouseArea {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool lit: win.at === index
                    readonly property bool rec: modelData[0] === "record"
                    width: label.implicitWidth + 56
                    height: Theme.dp(44)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.at = index
                    onClicked: win.pick(index)
                    scale: pressed ? Theme.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData[2]
                    Accessible.focused: lit
                    Accessible.onPressAction: win.pick(index)
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: btn.lit ? Theme.cardHover : "transparent"
                        border.width: btn.lit && Desktop.keyNav ? Theme.focusWidth : 0
                        border.color: Theme.accentText
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.s2
                        Glyph { anchors.verticalCenter: parent.verticalCenter; name: btn.modelData[1]; size: 20; color: btn.rec ? Theme.red : Theme.fg }
                        Text {
                            id: label
                            anchors.verticalCenter: parent.verticalCenter
                            text: btn.modelData[2]
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                        }
                    }
                }
            }
        }
    }
}
