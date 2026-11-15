import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: qsTr("Welcome to KrissOS")
    width: 1100
    height: 720
    minimumWidth: Kirigami.Units.gridUnit * 22

    property int current: 0

    readonly property var pages: [
        { title: qsTr("Welcome"), icon: "go-home", page: welcomePage },
        { title: qsTr("Game checker"), icon: "input-gaming", page: gamesPage },
        { title: qsTr("Bring your apps"), icon: "system-software-install", page: appsPage },
        { title: qsTr("Copy from Windows"), icon: "folder-download", page: soonPage },
        { title: qsTr("Drivers and extras"), icon: "preferences-system", page: soonPage }
    ]

    function showPage(i) {
        current = i
        pageStack.clear()
        pageStack.push(pages[i].page, { title: pages[i].title })
    }

    Component.onCompleted: showPage(0)

    globalDrawer: Kirigami.GlobalDrawer {
        modal: !root.wideScreen
        width: Kirigami.Units.gridUnit * 13
        actions: root.pages.map((p, i) => drawerAction.createObject(root, { text: p.title, "icon.name": p.icon, index: i }))
    }

    Component {
        id: drawerAction
        Kirigami.Action {
            property int index
            checkable: true
            checked: root.current === index
            onTriggered: root.showPage(index)
        }
    }

    Component { id: welcomePage; WelcomePage {} }
    Component { id: gamesPage; GamesPage {} }
    Component { id: appsPage; AppsPage {} }
    Component {
        id: soonPage
        Kirigami.Page {
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                icon.name: "clock"
                text: qsTr("Coming soon")
                explanation: qsTr("This part of KrissOS Welcome arrives in a later update.")
            }
        }
    }
}
