import QtQuick
import QtQuick.Controls.Basic as B
import QtQuick.Layouts

// Asks before an install, as a sheet that rises from the bottom of the window with Vaul's
// long soft ease (the shell's quick settings sheet), over a dimmed page.
B.Popup {
    id: d
    property string title
    property string subtitle
    signal accepted()
    readonly property var t: backend.theme
    parent: B.Overlay.overlay
    modal: true
    width: Math.min(560, parent.width - 48)
    x: (parent.width - width) / 2
    y: parent.height - height - 24
    padding: 24
    enter: Transition {
        NumberAnimation { property: "y"; from: d.parent.height; to: d.parent.height - d.height - 24; duration: 500
                          easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
    }
    exit: Transition {
        NumberAnimation { property: "y"; to: d.parent.height; duration: 180; easing.type: Easing.InCubic }
        NumberAnimation { property: "opacity"; to: 0; duration: 180 }
    }
    B.Overlay.modal: Rectangle { color: Qt.alpha("#000000", 0.4) }
    background: Rectangle {
        radius: 22
        color: d.t.card
        border.width: 1
        border.color: d.t.line
    }
    contentItem: ColumnLayout {
        spacing: 12
        Txt { Layout.fillWidth: true; text: d.title; size: 20; bold: true }
        Txt { Layout.fillWidth: true; text: d.subtitle; soft: true }
        RowLayout {
            Layout.topMargin: 8
            Layout.alignment: Qt.AlignRight
            spacing: 10
            Pill { text: qsTr("Cancel"); onClicked: d.close() }
            Pill { text: qsTr("Continue"); highlighted: true; onClicked: { d.close(); d.accepted() } }
        }
    }
}
