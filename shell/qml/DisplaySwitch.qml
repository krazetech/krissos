import QtQuick
import Quickshell
import Quickshell.Wayland

// Windows+P: how the displays work together, as on Windows. PC screen only, Duplicate,
// Extend or Second screen only (Displays.project). Opens at the right of the main display;
// Windows+P again or the arrows move along, Enter picks, Esc or a click outside closes.
PanelWindow {
    id: win

    property bool open: false
    property int at: 0
    readonly property var choices: [["pc", Tr.t("PC screen only")], ["duplicate", Tr.t("Duplicate")],
                                    ["extend", Tr.t("Extend")], ["second", Tr.t("Second screen only")]]
    function toggle() {
        if (open) { at = (at + 1) % choices.length; return; }
        at = Math.max(0, choices.findIndex(c => c[0] === Displays.projection));
        open = true;
        Desktop.opened(true);
    }
    function pick(i) {
        open = false;
        Displays.project(choices[i][0]);
    }

    screen: Desktop.primary
    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kriss-project"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        Accessible.ignored: true  // a click outside closes; Esc does the same
        onClicked: win.open = false
    }

    Rectangle {
        id: panel
        anchors { right: parent.right; rightMargin: Theme.s3; bottom: parent.bottom; bottomMargin: Desktop.bottomRoom + Theme.s3 }
        width: Theme.dp(320)
        height: list.implicitHeight + 2 * Theme.s3
        radius: Theme.rPanel
        color: Theme.card
        border.width: Theme.rimWidth
        border.color: Theme.line
        Accessible.role: Accessible.List
        Accessible.name: Tr.t("Project")
        focus: win.open
        Keys.onEscapePressed: win.open = false
        Keys.onUpPressed: win.at = (win.at + win.choices.length - 1) % win.choices.length
        Keys.onDownPressed: win.at = (win.at + 1) % win.choices.length
        Keys.onReturnPressed: win.pick(win.at)
        Keys.onEnterPressed: win.pick(win.at)
        Keys.onSpacePressed: win.pick(win.at)
        Column {
            id: list
            x: Theme.s3
            y: Theme.s3
            width: parent.width - 2 * Theme.s3
            spacing: Theme.s1
            Text {
                text: Tr.t("Project")
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
                bottomPadding: Theme.s1
            }
            Repeater {
                model: win.choices
                MouseArea {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool lit: win.at === index
                    readonly property bool now: Displays.projection === modelData[0]
                    width: parent.width
                    height: Math.max(48, Theme.sp(14) + 28)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.at = index
                    onClicked: win.pick(index)
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData[1]
                    Accessible.checkable: true
                    Accessible.checked: now
                    Accessible.focused: lit
                    Accessible.onPressAction: win.pick(index)
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: row.lit ? Theme.cardHover : "transparent"
                        border.width: row.lit && Desktop.keyNav ? Theme.focusWidth : 0
                        border.color: Theme.accentText
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Row {
                        x: Theme.s3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.s3
                        Glyph { name: "display"; size: 20; anchors.verticalCenter: parent.verticalCenter; color: row.now ? Theme.accentText : Theme.fg }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData[1]
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: Theme.sp(14); weight: row.now ? Font.DemiBold : Font.Medium }
                        }
                    }
                    Glyph { visible: row.now; name: "check"; size: 16; color: Theme.accentText; anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter } }
                }
            }
        }
    }
}
