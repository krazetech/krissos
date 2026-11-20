// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One app's main button: Install, a spinner while it changes, then Open.
RowLayout {
    id: btn
    required property var app
    readonly property string appId: app.id || ""
    readonly property string doing: backend.busy[appId] || ""
    readonly property bool installed: backend.installed.indexOf(appId) >= 0

    QQC2.BusyIndicator {
        visible: btn.doing !== ""
        running: visible
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: Layout.preferredHeight
    }
    QQC2.Button {
        text: btn.doing === "install" ? qsTr("Installing…")
            : btn.doing === "remove" ? qsTr("Removing…")
            : !btn.installed ? qsTr("Install")
            : backend.canOpen(btn.appId) ? qsTr("Open") : qsTr("Installed")
        icon.name: btn.installed ? "" : "download"
        highlighted: !btn.installed && btn.doing === ""
        // One change at a time, and nothing to open for a pack.
        enabled: btn.doing === "" && (btn.installed ? backend.canOpen(btn.appId) : Object.keys(backend.busy).length === 0)
        onClicked: btn.installed ? backend.open(btn.appId) : backend.install(btn.appId)
    }
}
