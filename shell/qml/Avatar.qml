import QtQuick
import QtQuick.Effects
import Quickshell.Io

// A user's picture in a circle, or their initial on an accent disc, as in the launcher.
Rectangle {
    id: avatar
    property string name
    property var faces: []  // picture paths to try, first found wins
    property int size: 96
    width: size; height: size; radius: size / 2
    color: Theme.accent
    border.width: Math.max(2, Math.round(size / 24))
    border.color: Theme.alpha(Theme.nightFg, 0.15)

    // The first of faces that exists, found up front so a missing ~/.face is not logged
    // (and a failed load does not feed back into the path).
    property string path: ""
    Process {
        id: finder
        command: ["sh", "-c", 'for f; do [ -r "$f" ] && { echo "$f"; exit; }; done', "sh"].concat(avatar.faces)
        stdout: StdioCollector { onStreamFinished: avatar.path = text.trim() }
    }
    onFacesChanged: { path = ""; finder.running = true; }
    Component.onCompleted: finder.running = true

    Text {
        anchors.centerIn: parent
        visible: pic.status !== Image.Ready
        text: avatar.name.charAt(0).toUpperCase()
        color: Theme.accentInk
        font { family: Theme.sans; pixelSize: avatar.size * 0.42; weight: Font.Bold }
    }
    Image {
        id: pic
        anchors.fill: parent
        anchors.margins: avatar.border.width
        source: avatar.path ? "file://" + avatar.path : ""
        sourceSize: Qt.size(avatar.size * 2, avatar.size * 2)
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    Rectangle { id: round; anchors.fill: pic; radius: width / 2; visible: false; layer.enabled: true }
    MultiEffect {
        anchors.fill: pic
        visible: pic.status === Image.Ready
        source: pic
        maskEnabled: true
        maskSource: round
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
