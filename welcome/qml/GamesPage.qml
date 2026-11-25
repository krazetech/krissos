// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Layouts

Page {
    id: page
    property var results: []
    property string query: ""

    function statusColor(s) {
        if (s === "Supported" || s === "Running") return backend.theme.green
        if (s === "Planned") return backend.theme.amber
        return backend.theme.red
    }
    function statusLabel(s) {
        return { Supported: qsTr("Supported"), Running: qsTr("Runs"), Planned: qsTr("Planned"),
                 Broken: qsTr("Blocked"), Denied: qsTr("Denied") }[s] || s
    }
    function statusText(s) {
        return {
            Supported: qsTr("The anti-cheat is enabled for Linux. Online play should work."),
            Running: qsTr("Runs on Linux, but the developer does not officially support it."),
            Planned: qsTr("The developer has said Linux support is coming."),
            Broken: qsTr("The anti-cheat does not work on Linux, so online play is blocked."),
            Denied: qsTr("The developer blocks Linux on purpose. It will not run.")
        }[s] || ""
    }

    Field {
        id: search
        Layout.fillWidth: true
        glyph: "search"
        placeholderText: qsTr("Search a game, e.g. Valorant")
        onTextChanged: { page.query = text; page.results = backend.searchGames(text) }
    }

    Empty {
        visible: page.results.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 32
        Layout.leftMargin: 48
        Layout.rightMargin: 48
        glyph: "games"
        text: page.query ? qsTr("Not in the anti-cheat list") : qsTr("Will my games run?")
        explanation: qsTr("This list covers games with anti-cheat, the usual reason a game will not run on Linux. Most other games run through Steam's Proton; ProtonDB has player reports.")
        action: qsTr("Search ProtonDB")
        onTriggered: Qt.openUrlExternally("https://www.protondb.com/search?q=" + encodeURIComponent(page.query))
    }

    Repeater {
        model: page.results
        delegate: Card {
            required property var modelData
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                Txt {
                    text: modelData.name
                    Layout.fillWidth: true
                    size: 17
                    bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
                // The verdict, as a tinted chip.
                Rectangle {
                    radius: height / 2
                    color: Qt.alpha(page.statusColor(modelData.status), 0.18)
                    implicitWidth: badge.implicitWidth + 24
                    implicitHeight: badge.implicitHeight + 10
                    Txt {
                        id: badge
                        anchors.centerIn: parent
                        text: page.statusLabel(modelData.status)
                        color: page.statusColor(modelData.status)
                        bold: true
                        size: 13
                        wrapMode: Text.NoWrap
                    }
                }
            }
            Txt {
                Layout.fillWidth: true
                text: page.statusText(modelData.status)
            }
            Txt {
                Layout.fillWidth: true
                soft: true
                text: qsTr("Anti-cheat: %1").arg(modelData.anticheats.join(", ") || qsTr("none listed"))
                    + (modelData.note ? " · " + modelData.note : "")
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Pill {
                    flat: true
                    text: qsTr("Details")
                    glyph: "globe"
                    onClicked: Qt.openUrlExternally("https://areweanticheatyet.com/game/" + modelData.slug)
                }
                Pill {
                    flat: true
                    visible: !!modelData.steam
                    text: qsTr("ProtonDB reports")
                    glyph: "globe"
                    onClicked: Qt.openUrlExternally("https://www.protondb.com/app/" + modelData.steam)
                }
            }
        }
    }

    Txt {
        Layout.fillWidth: true
        soft: true
        size: 12
        text: qsTr("Anti-cheat data: AreWeAntiCheatYet (MIT). Game ratings: ProtonDB.")
    }
}
