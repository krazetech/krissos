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
        { title: qsTr("Welcome"), icon: "go-home", page: "WelcomePage.qml" },
        { title: qsTr("Game checker"), icon: "input-gaming", page: "GamesPage.qml" },
        { title: qsTr("Bring your apps"), icon: "system-software-install", page: "AppsPage.qml" },
        { title: qsTr("Copy from Windows"), icon: "folder-download", page: "CopyPage.qml" },
        { title: qsTr("Drivers and extras"), icon: "preferences-system", page: "ExtrasPage.qml" }
    ]

    // The pool makes each page once and keeps it, so a page keeps its state (an install
    // in progress, a copy) when you switch away. Pushing Components instead made Kirigami
    // create every page outside the scene and destroy it on the next switch.
    Kirigami.PagePool { id: pool }

    function showPage(i) {
        current = i
        pageStack.clear()
        pageStack.push(pool.loadPage(Qt.resolvedUrl(pages[i].page)), { title: pages[i].title })
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
}
