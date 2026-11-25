// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A grid of app cards: Home's picks, a category, search results or what is installed.
Kirigami.ScrollablePage {
    id: page
    property string section
    property string query

    function load() {
        return !backend.ready ? []
            : section === "home" ? backend.featured()
            : section === "search" ? backend.search(query)
            : section === "installed" ? backend.installedApps()
            : backend.category(section)
    }
    property var apps: []
    onSectionChanged: apps = load()
    onQueryChanged: apps = load()
    Connections {
        target: backend
        function onCatalogueChanged() { page.apps = page.load() }
        function onStateChanged() { if (page.section === "installed") page.apps = page.load() }
    }

    header: Kirigami.InlineMessage {
        position: Kirigami.InlineMessage.Position.Header
        visible: backend.ready && backend.flathubCount === 0
        type: Kirigami.MessageType.Information
        text: qsTr("Connect to the internet to see Flathub's apps. Only the KrissOS packs are shown until then.")
    }

    GridView {
        id: grid
        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: grid.count === 0
            icon.name: !backend.ready ? "content-loading-symbolic" : page.section === "search" ? "edit-find" : "view-list-details"
            text: !backend.ready ? qsTr("Loading apps…")
                : page.section === "search" ? qsTr("No apps match “%1”").arg(page.query)
                : page.section === "installed" ? qsTr("Apps you install from the Store show up here")
                : qsTr("Nothing here yet")
        }
        model: page.apps
        readonly property int columns: Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 18)))
        cellWidth: Math.floor(width / columns)
        cellHeight: Kirigami.Units.gridUnit * 6.5
        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            Kirigami.AbstractCard {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                showClickFeedback: true
                onClicked: applicationWindow().openApp(modelData.id)
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: modelData.icon || "application-x-executable"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: modelData.summary
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            opacity: 0.7
                        }
                        AppButton {
                            app: modelData
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }
        }
    }
}
