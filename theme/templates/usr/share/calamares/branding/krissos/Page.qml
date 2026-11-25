// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
// One slide: English first, Bahasa Melayu under it. Rendered from theme/tokens.json.
// ponytail: both languages on every slide, because Calamares has no Malay UI
// translation to switch to; move to qsTr() and lang/*.qm once it does.
import QtQuick 2.15
import calamares.slideshow 1.0

Slide {
    id: slide
    property string heading
    property string body
    property string headingMs
    property string bodyMs

    // Arrives like a shell toast (Sonner): up a little and in, with a touch of settle.
    onVisibleChanged: if (visible) enter.restart()
    ParallelAnimation {
        id: enter
        NumberAnimation { target: text; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: text; property: "shift"; from: 16; to: 0; duration: 500
                          easing.type: Easing.BezierSpline; easing.bezierCurve: [0.21, 1.02, 0.73, 1, 1, 1] }
    }

    Column {
        id: text
        property real shift: 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: shift - 16
        x: 48
        width: Math.min(parent.width - 96, 620)
        spacing: 12

        Text {
            text: heading; width: parent.width; wrapMode: Text.WordWrap
            color: "{{fg}}"; font.family: "{{font_sans}}"; font.pixelSize: 32; font.weight: Font.DemiBold
        }
        Text {
            text: body; width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.25
            color: "{{fg}}"; opacity: 0.86; font.family: "{{font_sans}}"; font.pixelSize: 17
        }
        Item { width: 1; height: 10 }
        Rectangle { width: parent.width; height: 1; color: "{{ui_line}}" }
        Item { width: 1; height: 4 }
        Text {
            text: headingMs; width: parent.width; wrapMode: Text.WordWrap
            color: "{{ui_accent_text}}"; font.family: "{{font_sans}}"; font.pixelSize: 16; font.weight: Font.DemiBold
        }
        Text {
            text: bodyMs; width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.25
            color: "{{ui_soft}}"; font.family: "{{font_sans}}"; font.pixelSize: 14
        }
    }
}
