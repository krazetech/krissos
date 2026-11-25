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

    // Sound themes installed (sounds/NAME/index.theme in $XDG_DATA_HOME, then
    // $XDG_DATA_DIRS: the first of a name wins), as [name, shown name, from the store],
    // KrissOS first.
    property var themes: []
    Process {
        id: themeScan
        running: true
        command: ["sh", "-c", `
            dirs="\${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            IFS=:; for d in $dirs; do
                for f in "$d"/sounds/*/index.theme; do
                    [ -f "$f" ] || continue; t=\${f%/index.theme}
                    printf '%s\\t%s\\t%s\\n' "\${t##*/}" "$(sed -n 's/^Name=//p' "$f" | head -1)" "$([ -e "$t/.kriss-store" ] && echo 1)"
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                page.themes = text.trim().split("\n").map(l => l.split("\t"))
                    .filter(t => t[0] && !seen[t[0]] && (seen[t[0]] = true))
                    .map(t => [t[0], t[1] || t[0], t[2] === "1"])
                    .sort((x, y) => (y[0] === "kriss") - (x[0] === "kriss") || x[1].localeCompare(y[1]));
            }
        }
    }

    // More sound themes (Settings > Sound > Get more sound themes): the list in the repo,
    // store/sound-themes.json, read from main each time. Install downloads one, checks its
    // sha256, and unpacks the theme folder into ~/.local/share/sounds/ID with a .kriss-store
    // mark; Remove deletes only marked ones.
    readonly property string storeUrl: "https://raw.githubusercontent.com/krazetech/krissos/main/store/sound-themes.json"
    property var store: []
    property string storeState: ""      // "", "loading", "failed" or "open"
    property string storeBusy: ""       // the theme being installed or removed
    property string storeFailed: ""     // the theme that failed to install
    function installed(id) { return themes.some(t => t[0] === id && t[2]); }
    Process {
        id: storeFetch
        command: ["curl", "-sfL", "--max-time", "20", page.storeUrl]
        stdout: StdioCollector { id: storeText }
        onExited: code => {
            try { page.store = JSON.parse(storeText.text); page.storeState = "open"; }
            catch (e) { page.storeState = "failed"; }
        }
    }
    Process {
        id: storeJob
        property var theme
        property bool remove
        command: ["sh", "-c", `
            case $1 in ""|*[!A-Za-z0-9_.+-]*) exit 2 ;; esac
            case $4 in ""|/*|*..*) exit 2 ;; esac
            dest="\${XDG_DATA_HOME:-$HOME/.local/share}/sounds/$1"
            if [ "$5" = remove ]; then [ -e "$dest/.kriss-store" ] && rm -rf "$dest"; exit; fi
            set -e
            tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
            curl -sfL --max-time 300 -o "$tmp/a" "$2"
            echo "$3  $tmp/a" | sha256sum -c --status
            mkdir "$tmp/x"; tar -xf "$tmp/a" -C "$tmp/x" --no-same-owner "$4"
            [ -f "$tmp/x/$4/index.theme" ]
            rm -rf "$dest"; mkdir -p "\${dest%/*}"; cp -r "$tmp/x/$4" "$dest"; : > "$dest/.kriss-store"`,
            "sh", theme?.id ?? "", theme?.url ?? "", theme?.sha256 ?? "", theme?.path ?? "", remove ? "remove" : "install"]
        onExited: code => {
            const id = storeJob.theme.id, removed = storeJob.remove;
            page.storeBusy = "";
            if (code !== 0 && !removed) page.storeFailed = id;
            else if (!removed) { Desktop.sounds = true; Desktop.soundTheme = id; Desktop.play(id, "desktop-login", "message-new-instant"); }
            else if (Desktop.soundTheme === id) Desktop.soundTheme = "kriss";
            themeScan.running = true;
        }
    }
    function storeRun(theme, remove) {
        if (storeBusy) return;
        storeBusy = theme.id; storeFailed = "";
        storeJob.theme = theme; storeJob.remove = remove; storeJob.running = true;
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
        // "No sounds" is sounds off (Desktop.sounds), so the theme picked stays for later.
        SettingsUi.Choice {
            text: Tr.t("Sound theme")
            detail: Tr.t("A chime with notifications, a tick when the volume changes, and sounds when you sign in, plug something in or the battery runs low")
            value: Desktop.sounds ? Desktop.soundTheme || "kriss" : ""
            options: [["", Tr.t("No sounds")]].concat(page.themes)
            onPicked: v => {
                Desktop.sounds = v !== "";
                if (v === "") return;
                Desktop.soundTheme = v;
                Desktop.play(v, "desktop-login", "message-new-instant");
            }
        }
        SettingsUi.Push {
            visible: page.storeState === "" || page.storeState === "failed"
            text: Tr.t("Get more sound themes")
            onPicked: { page.storeState = "loading"; storeFetch.running = true; }
        }
        SettingsUi.Note {
            visible: page.storeState === "loading" || page.storeState === "failed"
            text: page.storeState === "loading" ? Tr.t("Checking…") : Tr.t("Couldn't load the list. Check your internet connection.")
        }
        Repeater {
            model: page.storeState === "open" ? page.store : []
            Row {
                id: entry
                required property var modelData
                readonly property bool have: page.installed(modelData.id)
                width: parent.width
                spacing: Theme.s3
                Column {
                    width: parent.width - action.width - Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: entry.modelData.name
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                    }
                    SettingsUi.Note {
                        width: parent.width
                        text: page.storeFailed === entry.modelData.id
                            ? Tr.t("Couldn't install %1. Check your internet connection.", entry.modelData.name)
                            : [entry.modelData.by, entry.modelData.size, entry.modelData.licence].join(" · ")
                    }
                }
                SettingsUi.Push {
                    id: action
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.storeBusy === entry.modelData.id ? (entry.have ? Tr.t("Removing…") : Tr.t("Installing…"))
                        : entry.have ? Tr.t("Remove") : Tr.t("Install")
                    onPicked: page.storeRun(entry.modelData, entry.have)
                }
            }
        }
    }
}
