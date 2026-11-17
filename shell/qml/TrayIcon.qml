// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
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
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    scale: pressed ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate();
        else if (mouse.button === Qt.RightButton || modelData.onlyMenu) { if (modelData.hasMenu) trayMenu.open(); }
        else modelData.activate();
    }
    onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)
    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        radius: width / 2
        color: tray.containsMouse ? Theme.card : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
    }
    IconImage { anchors.fill: parent; source: tray.modelData.icon }
    QsMenuAnchor {
        id: trayMenu
        menu: tray.modelData.menu
        anchor.item: tray
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
    }
}
