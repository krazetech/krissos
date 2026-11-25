// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import Quickshell.Services.Pipewire

// Scroll to change the volume; a click opens quick settings.
MouseArea {
    Accessible.ignored: true  // pointer only; the keyboard has its own way
    id: vol
    readonly property var sink: Pipewire.defaultAudioSink
    width: 20
    height: 20
    anchors.verticalCenter: parent.verticalCenter
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property string label: !sink?.audio ? "" : sink.audio.muted ? Tr.t("Sound muted")
        : Tr.t("Volume %1%", Math.round(sink.audio.volume * 100))
    Glyph { name: vol.sink?.audio?.muted ? "mute" : "volume" }
}
