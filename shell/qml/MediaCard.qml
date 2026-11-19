import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// What's playing, with the controls the media keys also reach: in quick settings and
// the widgets panel. Hide it when no player has a track.
ClippingRectangle {
    id: media
    readonly property var p: Desktop.player
    implicitHeight: 72
    radius: Theme.radiusSmall
    color: Theme.card
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        ClippingRectangle {
            implicitWidth: 52
            implicitHeight: 52
            radius: 10
            color: Theme.win
            Glyph { anchors.centerIn: parent; name: "music"; color: Theme.soft; visible: art.status !== Image.Ready }
            Image {
                id: art
                anchors.fill: parent
                source: media.p?.trackArtUrl ?? ""
                sourceSize: Qt.size(104, 104)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            Layout.fillWidth: true
            spacing: 3
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: media.p?.trackTitle ?? ""
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: media.p?.trackArtist || media.p?.identity || ""
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
        Repeater {
            model: ["prev", "play", "next"]
            delegate: MouseArea {
                id: mb
                required property string modelData
                readonly property bool primary: modelData === "play"
                implicitWidth: 36
                implicitHeight: 36
                hoverEnabled: true
                function press() { modelData === "prev" ? media.p.previous() : modelData === "next" ? media.p.next() : media.p.togglePlaying(); }
                activeFocusOnTab: true
                Keys.onReturnPressed: press()
                Keys.onEnterPressed: press()
                Keys.onSpacePressed: press()
                Accessible.role: Accessible.Button
                Accessible.name: modelData === "prev" ? Tr.t("Previous") : modelData === "next" ? Tr.t("Next")
                    : media.p?.isPlaying ? Tr.t("Pause") : Tr.t("Play")
                Accessible.onPressAction: press()
                FocusRim { radius: width / 2 + 2 }
                enabled: modelData === "prev" ? media.p?.canGoPrevious ?? false
                    : modelData === "next" ? media.p?.canGoNext ?? false : media.p?.canTogglePlaying ?? false
                cursorShape: Qt.PointingHandCursor
                opacity: enabled ? 1 : 0.35
                onClicked: press()
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: mb.primary ? Theme.accent : mb.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                    scale: mb.pressed ? Theme.pressScale : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                }
                Glyph {
                    anchors.centerIn: parent
                    name: mb.primary && media.p?.isPlaying ? "pause" : mb.modelData
                    size: 16
                    color: mb.primary ? Theme.accentInk : Theme.fg
                }
            }
        }
    }
}
