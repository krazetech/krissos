import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "reveal.js" as Reveal

// "Choose a picture" in the Settings page that asks, as Windows' picture picker: the pictures
// in a folder as thumbnails (starting in Pictures, newest first), its folders to go into, Up to
// go back, and a row of KrissOS pictures when `stock` has some. It opens in place, under the
// button, and scrolls into view. Enter or a click picks, Esc or Close shuts it. Settings >
// Accounts, Background and Lock screen use it.
// ponytail: in the page, not over the window: an item moved onto a Quickshell window's
// content item is not drawn.
Item {
    id: picker
    property string title: Tr.t("Choose a picture")
    property var stock: []  // [[path, name]]
    property var kinds: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.svg"]
    signal chosen(string path)

    // The control that opened it gets the keyboard back.
    property Item back: null
    function open() {
        back = Window.activeFocusItem;
        if (home) folder = home;
        visible = true;
        grid.currentIndex = 0;
        grid.forceActiveFocus();
        Reveal.show(picker);
    }
    function close() { visible = false; back?.forceActiveFocus(); }
    function pick(path) { close(); chosen(path); }

    // Pictures (xdg-user-dir: "Gambar" in Malay), else the home folder.
    property string home: ""
    property string folder: ""
    Process {
        running: true
        command: ["sh", "-c", 'p=$(xdg-user-dir PICTURES 2>/dev/null); [ -d "$p" ] && [ "$p" != "$HOME" ] || p=$HOME; echo "$p"']
        stdout: StdioCollector { onStreamFinished: picker.home = picker.folder = text.trim() }
    }
    FolderListModel {
        id: files
        folder: picker.folder ? "file://" + picker.folder : ""
        nameFilters: picker.kinds
        caseSensitive: false
        showDirsFirst: true
        sortField: FolderListModel.Time
    }

    visible: false
    width: parent?.width ?? 0
    height: Theme.dp(520)

    Rectangle {
        id: box
        anchors.fill: parent
        radius: Theme.rCard
        color: Theme.win
        border.width: Theme.rimWidth
        border.color: Theme.line
        Accessible.role: Accessible.Dialog
        Accessible.name: picker.title

        Column {
            id: head
            x: 20; y: 16
            width: parent.width - 40
            spacing: Theme.s3
            Item {
                width: parent.width
                height: Math.max(36, titleText.implicitHeight)
                Text {
                    id: titleText
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.title
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(20); weight: Font.DemiBold }
                }
                Tile {
                    anchors.right: parent.right
                    width: 36; height: 36
                    glyph: "close"
                    name: Tr.t("Close")
                    onPicked: picker.close()
                }
            }
            SettingsUi.Label { visible: picker.stock.length > 0; text: Tr.t("KrissOS pictures") }
            Flow {
                visible: picker.stock.length > 0
                width: parent.width
                spacing: Theme.s2
                Repeater {
                    model: picker.stock
                    Tile {
                        required property var modelData
                        width: Theme.dp(72); height: Theme.dp(72)
                        round: true
                        path: modelData[0]
                        name: modelData[1]
                        onPicked: picker.pick(modelData[0])
                    }
                }
            }
            // Where we are: Up, the folder's name, and back to Pictures.
            Row {
                spacing: Theme.s2
                Tile {
                    width: 36; height: 36
                    glyph: "up"
                    name: Tr.t("Up a folder")
                    enabled: picker.folder !== "/" && picker.folder !== ""
                    opacity: enabled ? 1 : 0.4
                    onPicked: grid.upFolder()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, head.width - 36 - homePush.width - Theme.s2 * 3)
                    elide: Text.ElideMiddle
                    text: picker.folder === picker.home ? Tr.t("Pictures") : picker.folder.slice(picker.folder.lastIndexOf("/") + 1) || "/"
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
                }
                SettingsUi.Push {
                    id: homePush
                    visible: picker.folder !== picker.home
                    text: Tr.t("Pictures")
                    onPicked: picker.folder = picker.home
                }
            }
        }

        GridView {
            id: grid
            x: 14
            anchors.top: head.bottom
            anchors.topMargin: Theme.s3
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: parent.width - 28
            clip: true
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / Theme.dp(150))))
            cellHeight: Theme.dp(96) + Theme.sp(12) + 18
            model: files
            keyNavigationWraps: false
            activeFocusOnTab: true
            boundsBehavior: Flickable.StopAtBounds
            Keys.onEscapePressed: picker.close()
            Keys.onReturnPressed: currentItem?.picked()
            Keys.onEnterPressed: currentItem?.picked()
            Keys.onSpacePressed: currentItem?.picked()
            Keys.onPressed: e => { if (e.key === Qt.Key_Backspace) { upFolder(); e.accepted = true; } }
            function upFolder() { if (picker.folder !== "/") picker.folder = picker.folder.replace(/\/[^/]*$/, "") || "/"; }
            onCurrentItemChanged: if (activeFocus && currentItem) Reveal.show(currentItem)
            delegate: Tile {
                required property string fileName
                required property string filePath
                required property bool fileIsDir
                required property int index
                width: grid.cellWidth - 8
                height: grid.cellHeight - 8
                path: fileIsDir ? "" : filePath
                glyph: fileIsDir ? "folder" : ""
                name: fileName
                caption: true
                current: grid.activeFocus && grid.currentIndex === index
                onPicked: fileIsDir ? picker.folder = filePath : picker.pick(filePath)
            }
            Text {
                anchors.centerIn: parent
                visible: files.status === FolderListModel.Ready && files.count === 0
                text: Tr.t("No pictures in this folder.")
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(14) }
            }
        }
    }
    Keys.onEscapePressed: close()

    // A picture or folder to pick: a thumbnail (or glyph), and its name under it with `caption`.
    component Tile: MouseArea {
        id: t
        property string path
        property string glyph
        property string name
        property bool round
        property bool caption
        property bool current
        signal picked()
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: !caption
        onClicked: picked()
        Keys.onSpacePressed: picked()
        Keys.onReturnPressed: picked()
        Keys.onEscapePressed: picker.close()
        Accessible.role: Accessible.Button
        Accessible.name: name
        Accessible.onPressAction: picked()
        FocusRim { visible: (t.activeFocus || t.current) && Desktop.keyNav; anchors.bottomMargin: t.caption ? Theme.sp(12) + 8 : 0; radius: frame.radius + 4 }
        Rectangle {
            id: frame
            width: parent.width
            height: t.caption ? parent.height - Theme.sp(12) - 8 : parent.height
            radius: t.round ? width / 2 : Theme.rControl
            color: t.containsMouse ? Theme.cardHover : t.caption ? Theme.card : "transparent"
            clip: true
            scale: t.pressed ? Theme.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            Image {
                anchors.fill: parent
                anchors.margins: t.caption ? 4 : 0
                visible: t.path !== ""
                source: t.path ? Desktop.fileUrl(t.path) : ""
                sourceSize: Qt.size(300, 200)
                fillMode: t.caption ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                asynchronous: true
            }
            Glyph { anchors.centerIn: parent; visible: t.glyph !== ""; name: t.glyph; size: t.caption ? 40 : 20 }
        }
        Text {
            visible: t.caption
            anchors.top: frame.bottom
            anchors.topMargin: 4
            width: parent.width
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
            text: t.name
            color: Theme.soft
            font { family: Theme.sans; pixelSize: Theme.sp(12) }
        }
    }
}
