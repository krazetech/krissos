import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

MouseArea {
    id: tray
    required property SystemTrayItem modelData
    width: 24
    height: 24
    anchors.verticalCenter: parent.verticalCenter
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate();
        else if (mouse.button === Qt.RightButton || modelData.onlyMenu) { if (modelData.hasMenu) trayMenu.open(); }
        else modelData.activate();
    }
    onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)
    IconImage { anchors.fill: parent; source: tray.modelData.icon }
    QsMenuAnchor {
        id: trayMenu
        menu: tray.modelData.menu
        anchor.item: tray
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
    }
}
