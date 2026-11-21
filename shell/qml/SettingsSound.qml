import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Settings > System > Sound: where sound goes and comes from, their levels, and each app's
// level (Windows' volume mixer), through PipeWire.
Column {
    id: page
    spacing: Theme.s3

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    // Apps playing sound now.
    readonly property var apps: Pipewire.nodes.values.filter(n => n.audio && n.isSink && n.isStream)
    PwObjectTracker { objects: [page.sink, page.source].concat(page.apps) }

    function label(n) { return n.properties?.["application.name"] || n.description || n.nickname || n.name; }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Output") }
        SettingsUi.Note { visible: page.outputs.length === 0; text: Tr.t("No speakers or headphones found.") }
        Repeater {
            model: page.outputs
            SettingsUi.Radio {
                required property var modelData
                glyph: "volume"
                text: page.label(modelData)
                group: Tr.t("Output")
                on: modelData === page.sink
                onPicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
        SettingsUi.Slider {
            visible: page.sink?.audio !== undefined
            text: Tr.t("Volume")
            glyph: page.sink?.audio?.muted ? "mute" : "volume"
            muted: page.sink?.audio?.muted ?? false
            value: page.sink?.audio?.volume ?? 0
            onMuteClicked: page.sink.audio.muted = !page.sink.audio.muted
            onMoved: v => { page.sink.audio.muted = false; page.sink.audio.volume = v; }
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Input") }
        SettingsUi.Note { visible: page.inputs.length === 0; text: Tr.t("No microphones found.") }
        Repeater {
            model: page.inputs
            SettingsUi.Radio {
                required property var modelData
                glyph: "mic"
                text: page.label(modelData)
                group: Tr.t("Input")
                on: modelData === page.source
                onPicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
        SettingsUi.Slider {
            visible: page.source?.audio !== undefined
            text: Tr.t("Microphone")
            glyph: page.source?.audio?.muted ? "micOff" : "mic"
            muted: page.source?.audio?.muted ?? false
            value: page.source?.audio?.volume ?? 0
            onMuteClicked: page.source.audio.muted = !page.source.audio.muted
            onMoved: v => { page.source.audio.muted = false; page.source.audio.volume = v; }
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Volume mixer") }
        SettingsUi.Note { text: page.apps.length ? Tr.t("Each app playing sound, on its own.") : Tr.t("No apps are playing sound right now.") }
        Repeater {
            model: page.apps
            Column {
                required property var modelData
                width: parent.width
                SettingsUi.Note { text: page.label(modelData) }
                SettingsUi.Slider {
                    text: page.label(modelData)
                    glyph: modelData.audio?.muted ? "mute" : "volume"
                    muted: modelData.audio?.muted ?? false
                    value: modelData.audio?.volume ?? 0
                    onMuteClicked: modelData.audio.muted = !modelData.audio.muted
                    onMoved: v => { modelData.audio.muted = false; modelData.audio.volume = v; }
                }
            }
        }
    }
}
