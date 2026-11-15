// One slide: English first, Bahasa Melayu under it. Rendered from theme/tokens.json.
// ponytail: both languages on every slide, because Calamares has no Malay UI
// translation to switch to; move to qsTr() and lang/*.qm once it does.
import QtQuick 2.15
import calamares.slideshow 1.0

Slide {
    property string heading
    property string body
    property string headingMs
    property string bodyMs

    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width * 0.1
        width: parent.width * 0.8
        spacing: 14

        Rectangle { width: 48; height: 4; radius: 2; color: "{{accent}}" }
        Text {
            text: heading; width: parent.width; wrapMode: Text.WordWrap
            color: "{{fg}}"; font.family: "{{font_sans}}"; font.pixelSize: 34; font.weight: Font.DemiBold
        }
        Text {
            text: body; width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.2
            color: "{{fg}}"; font.family: "{{font_sans}}"; font.pixelSize: 18
        }
        Item { width: 1; height: 18 }
        Text {
            text: headingMs; width: parent.width; wrapMode: Text.WordWrap
            color: "{{accent}}"; font.family: "{{font_sans}}"; font.pixelSize: 18; font.weight: Font.DemiBold
        }
        Text {
            text: bodyMs; width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.2
            color: "{{color7}}"; font.family: "{{font_sans}}"; font.pixelSize: 15
        }
    }
}
