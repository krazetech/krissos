import QtQuick
import Quickshell
import Quickshell.Io
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

    // Sound themes installed (/usr/share/sounds/NAME/index.theme), as [name, shown name].
    property var themes: []
    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/sounds/*/index.theme; do d=${f%/index.theme}; printf '%s\\t%s\\n' \"${d##*/}\" \"$(sed -n 's/^Name=//p' \"$f\" | head -1)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: page.themes = text.trim().split("\n").filter(l => l).map(l => l.split("\t")).map(t => [t[0], t[1] || t[0]])
        }
    }

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

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("System sounds") }
        SettingsUi.Toggle {
            text: Tr.t("Play system sounds")
            detail: Tr.t("A chime with notifications, a tick when the volume changes, and a sound when you plug something in")
            checked: Desktop.sounds
            onToggled: Desktop.sounds = !checked
        }
        SettingsUi.Choice {
            visible: Desktop.sounds && page.themes.length > 1
            text: Tr.t("Sound theme")
            value: Desktop.soundTheme || "ocean"
            options: page.themes
            onPicked: v => Desktop.soundTheme = v
        }
    }
}
