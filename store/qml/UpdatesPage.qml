// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Everything waiting, KrissOS and apps together, and one button that updates it all after a
// snapshot (kriss update), like Windows Update.
Kirigami.ScrollablePage {
    id: page
    title: qsTr("Updates")
    readonly property bool updating: backend.busy["*"] === "update"

    actions: [
        Kirigami.Action {
            text: qsTr("Check again")
            icon.name: "view-refresh"
            enabled: !backend.checking && !page.updating
            onTriggered: backend.refresh()
        },
        Kirigami.Action {
            text: page.updating ? qsTr("Updating…") : qsTr("Update all")
            icon.name: "system-software-update"
            enabled: backend.updates.length > 0 && Object.keys(backend.busy).length === 0
            onTriggered: backend.updateAll()
        }
    ]

    header: Kirigami.InlineMessage {
        position: Kirigami.InlineMessage.Position.Header
        visible: backend.updates.length > 0
        text: qsTr("A snapshot is taken before updating, so if something breaks you can start the PC as it was from the boot menu.")
    }

    ListView {
        id: list
        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: backend.checking ? "content-loading-symbolic" : "checkmark"
            text: backend.checking ? qsTr("Checking for updates…") : qsTr("Everything is up to date")
        }
        model: backend.updates
        delegate: QQC2.ItemDelegate {
            required property var modelData
            width: ListView.view.width
            text: modelData.name
            contentItem: RowLayout {
                QQC2.Label { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                QQC2.Label { text: modelData.version; opacity: 0.7 }
            }
        }
    }
}
