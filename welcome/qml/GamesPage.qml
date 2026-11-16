import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    property var results: []
    property string query: ""

    function statusColor(s) {
        if (s === "Supported" || s === "Running") return Kirigami.Theme.positiveTextColor
        if (s === "Planned") return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.negativeTextColor
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

    header: QQC2.ToolBar {
        Kirigami.SearchField {
            id: search
            anchors.fill: parent
            placeholderText: qsTr("Search a game, e.g. Valorant")
            onTextChanged: { page.query = text; page.results = backend.searchGames(text) }
        }
    }

    ListView {
        id: list
        model: page.results
        spacing: Kirigami.Units.smallSpacing

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: "input-gaming"
            text: page.query ? qsTr("Not in the anti-cheat list") : qsTr("Will my games run?")
            explanation: qsTr("This list covers games with anti-cheat, the usual reason a game will not run on Linux. Most other games run through Steam's Proton; ProtonDB has player reports.")
            helpfulAction: Kirigami.Action {
                text: qsTr("Search ProtonDB")
                icon.name: "internet-services"
                onTriggered: Qt.openUrlExternally("https://www.protondb.com/search?q=" + encodeURIComponent(page.query))
            }
        }

        delegate: Kirigami.AbstractCard {
            required property var modelData
            width: ListView.view.width
            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    Kirigami.Heading {
                        level: 3
                        text: modelData.name
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        radius: height / 2
                        color: Qt.alpha(page.statusColor(modelData.status), 0.18)
                        implicitWidth: badge.implicitWidth + Kirigami.Units.largeSpacing * 2
                        implicitHeight: badge.implicitHeight + Kirigami.Units.smallSpacing * 2
                        QQC2.Label {
                            id: badge
                            anchors.centerIn: parent
                            text: page.statusLabel(modelData.status)
                            color: page.statusColor(modelData.status)
                            font.bold: true
                        }
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: page.statusText(modelData.status)
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    text: qsTr("Anti-cheat: %1").arg(modelData.anticheats.join(", ") || qsTr("none listed"))
                        + (modelData.note ? " · " + modelData.note : "")
                }
                RowLayout {
                    QQC2.Button {
                        flat: true
                        text: qsTr("Details")
                        icon.name: "internet-services"
                        onClicked: Qt.openUrlExternally("https://areweanticheatyet.com/game/" + modelData.slug)
                    }
                    QQC2.Button {
                        flat: true
                        visible: !!modelData.steam
                        text: qsTr("ProtonDB reports")
                        icon.name: "internet-services"
                        onClicked: Qt.openUrlExternally("https://www.protondb.com/app/" + modelData.steam)
                    }
                }
            }
        }
    }

    footer: QQC2.Label {
        padding: Kirigami.Units.smallSpacing
        opacity: 0.6
        font: Kirigami.Theme.smallFont
        text: qsTr("Anti-cheat data: AreWeAntiCheatYet (MIT). Game ratings: ProtonDB.")
    }
}
