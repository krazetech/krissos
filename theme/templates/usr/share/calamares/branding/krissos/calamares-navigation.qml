// The installer's buttons, as the shell draws them: round pills, the one that goes on in
// the accent, Cancel quiet at the left. Rendered from theme/tokens.json per light and dark.
// The labels keep Calamares' & mnemonics, so Alt+N, Alt+B and Alt+C still work.
import io.calamares.ui 1.0
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "{{ui_win}}"
    height: 68
    // On the last page Done is the one button left, so it moves to the right in the accent.
    readonly property bool last: ViewManager.currentStepIndex === ViewManager.rowCount() - 1

    component Pill: Button {
        id: b
        property bool primary: false
        property bool quiet: false
        height: 38
        leftPadding: 22; rightPadding: 22
        font.family: "{{font_sans}}"
        font.pixelSize: 14
        font.weight: primary ? Font.DemiBold : Font.Medium
        scale: down ? 0.95 : 1
        opacity: enabled ? 1 : 0.45
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        contentItem: Text {
            text: b.text.replace("&", "")
            font: b.font
            color: b.primary ? "{{bg}}" : b.quiet && !b.hovered ? "{{ui_soft}}" : "{{fg}}"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: b.primary ? (b.hovered ? "{{color14}}" : "{{accent}}")
                 : b.quiet ? (b.hovered ? "{{ui_card}}" : "transparent")
                 : b.hovered ? "{{ui_hover}}" : "{{ui_card}}"
            border.width: b.primary || b.quiet ? 0 : 1
            border.color: "{{ui_line}}"
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    Pill {
        x: root.last ? root.width - width - 20 : 20
        anchors.verticalCenter: parent.verticalCenter
        quiet: !root.last
        primary: root.last
        text: ViewManager.quitLabel
        enabled: ViewManager.quitEnabled
        visible: ViewManager.quitVisible
        ToolTip.visible: hovered && ViewManager.quitTooltip !== ""
        ToolTip.delay: 1000
        ToolTip.text: ViewManager.quitTooltip
        onClicked: ViewManager.quit()
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: ViewManager.backAndNextVisible && !root.last
        Pill {
            text: ViewManager.backLabel
            enabled: ViewManager.backEnabled
            onClicked: ViewManager.back()
        }
        Pill {
            primary: true
            text: ViewManager.nextLabel
            enabled: ViewManager.nextEnabled
            onClicked: ViewManager.next()
        }
    }
}
