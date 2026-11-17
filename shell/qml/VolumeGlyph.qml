// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import Quickshell.Services.Pipewire

// Scroll to change the volume; a click opens quick settings.
MouseArea {
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
    Glyph { name: vol.sink?.audio?.muted ? "mute" : "volume" }
}
