import QtQuick
import QtQuick.Controls.Basic as B
import QtQuick.Layouts

// The KrissOS Shell look (backend.theme, from theme/tokens.json, light or dark as the shell
// is): the pages in a side panel like the shell's, and the page under its title.
B.ApplicationWindow {
    id: root
    title: qsTr("Welcome to KrissOS")
    width: 1100
    height: 720
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    color: backend.theme.win
    font.family: backend.theme.sans
    Behavior on color { ColorAnimation { duration: 220 } }

    property int current: 0
    // The page on screen, for smoke_qml.py.
    readonly property Item currentItem: pageLoaders.itemAt(current) ? pageLoaders.itemAt(current).item : null

    readonly property var pages: [
        { title: qsTr("Welcome"), glyph: "home", page: "WelcomePage.qml" },
        { title: qsTr("Game checker"), glyph: "games", page: "GamesPage.qml" },
        { title: qsTr("Bring your apps"), glyph: "apps", page: "AppsPage.qml" },
        { title: qsTr("Copy from Windows"), glyph: "folder", page: "CopyPage.qml" },
        { title: qsTr("Drivers and extras"), glyph: "extras", page: "ExtrasPage.qml" }
    ]

    function showPage(i) { current = i }

    // The side panel: a raised card with the emblem and one row per page. The lit row slides
    // to the page you pick, as the shell's hover does.
    Rectangle {
        id: side
        x: 12; y: 12
        width: 248
        height: parent.height - 24
        radius: 22
        color: backend.theme.card
        border.width: 1
        border.color: backend.theme.line

        Row {
            id: brand
            x: 20; y: 22
            spacing: 12
            Image {
                source: logo
                width: 40; height: 40
                sourceSize.width: 80; sourceSize.height: 80
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "KrissOS"
                size: 18
                bold: true
            }
        }

        Item {
            id: nav
            anchors.top: brand.bottom
            anchors.topMargin: 24
            x: 10
            width: parent.width - 20
            height: root.pages.length * 44

            Rectangle {
                y: root.current * 44
                width: parent.width; height: 40
                radius: 10
                color: backend.theme.cardHover
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Rectangle {
                    x: 0; y: 10; width: 3; height: 20; radius: 1.5
                    color: backend.theme.accent
                }
            }

            Repeater {
                model: root.pages
                delegate: B.AbstractButton {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool now: root.current === index
                    y: index * 44
                    width: nav.width; height: 40
                    hoverEnabled: true
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.title
                    onClicked: root.showPage(index)
                    background: Rectangle {
                        radius: 10
                        color: row.hovered && !row.now ? Qt.alpha(backend.theme.fg, 0.05) : "transparent"
                        border.width: row.visualFocus ? 2 : 0
                        border.color: backend.theme.accentText
                    }
                    contentItem: Row {
                        leftPadding: 14
                        spacing: 12
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.glyph
                            color: row.now ? backend.theme.accentText : backend.theme.soft
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.title
                            color: row.now ? backend.theme.fg : backend.theme.soft
                            bold: row.now
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }

    Txt {
        id: heading
        x: side.width + 24 + 32
        y: 30
        width: parent.width - x - 32
        text: root.pages[root.current].title
        size: 28
        bold: true
    }

    // Each page is made the first time it is shown and then kept, so it keeps its state (an
    // install in progress, a copy) when you switch away. It comes in like the shell's panels:
    // up a little and in.
    Repeater {
        id: pageLoaders
        model: root.pages
        delegate: Loader {
            id: ld
            required property var modelData
            required property int index
            readonly property bool shown: root.current === index
            property bool visited: false
            property real shift: 0
            x: side.width + 24
            y: heading.y + heading.height + 16 + shift
            width: root.width - x
            height: root.height - heading.y - heading.height - 16
            active: shown || visited
            visible: shown
            source: modelData.page
            onShownChanged: if (shown) { visited = true; enter.restart() }
            Component.onCompleted: visited = shown
            ParallelAnimation {
                id: enter
                NumberAnimation { target: ld; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: ld; property: "shift"; from: 12; to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }
}
