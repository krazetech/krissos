import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Apps > Default apps: which app opens web links, email, music, video, pictures,
// PDFs and text, as Windows lists them. Read and set with `gio mime` (glib2), which every
// app's "Open with" follows; picking one sets it for all of that kind's file types.
Column {
    id: page
    spacing: Theme.s3

    readonly property var kinds: [
        ["web", "globe", Tr.t("Web browser"), ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"]],
        ["email", "send", Tr.t("Email"), ["x-scheme-handler/mailto"]],
        ["music", "music", Tr.t("Music"), ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"]],
        ["video", "play", Tr.t("Video"), ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime"]],
        ["photos", "image", Tr.t("Pictures"), ["image/jpeg", "image/png", "image/gif", "image/webp"]],
        ["pdf", "file", Tr.t("PDF files"), ["application/pdf"]],
        ["text", "text", Tr.t("Text files"), ["text/plain"]]
    ]
    // kind: {now: desktop id, apps: [desktop ids]}, from `gio mime` on each kind's first type.
    property var found: ({})
    property string open: ""
    Process {
        id: reader
        running: true
        command: ["sh", "-c", 'for t; do echo "@$t"; LC_ALL=C gio mime "$t" 2>/dev/null; done', "sh"].concat(page.kinds.map(k => k[3][0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                let cur = null;
                for (const line of text.split("\n")) {
                    if (line.startsWith("@")) {
                        const k = page.kinds.find(k => k[3][0] === line.slice(1));
                        cur = out[k[0]] = { now: "", apps: [] };
                    } else if (cur && /^Default application/.test(line)) {
                        cur.now = line.split(": ").pop().trim().replace(/\.desktop$/, "");
                    } else if (cur && /^\s+\S+\.desktop$/.test(line)) {
                        const id = line.trim().replace(/\.desktop$/, "");
                        if (cur.apps.indexOf(id) < 0) cur.apps.push(id);
                    }
                }
                page.found = out;
            }
        }
    }
    function set(kind, id) {
        Quickshell.execDetached(["sh", "-c", 'app=$1; shift; for t; do gio mime "$t" "$app"; done; true', "sh", id + ".desktop"].concat(kind[3]));
        const o = Object.assign({}, found);
        o[kind[0]] = Object.assign({}, o[kind[0]], { now: id });
        found = o;
        open = "";
    }
    function name(id) { DesktopEntries.applications.values; return DesktopEntries.byId(id)?.name ?? id; }

    SettingsUi.Card {
        Repeater {
            model: page.kinds
            Column {
                id: kind
                required property var modelData
                width: parent.width
                readonly property var info: page.found[modelData[0]] ?? { now: "", apps: [] }
                SettingsUi.LinkRow {
                    glyph: kind.modelData[1]
                    text: kind.modelData[2]
                    detail: kind.info.now ? page.name(kind.info.now) : Tr.t("Not set")
                    onPicked: page.open = page.open === kind.modelData[0] ? "" : kind.modelData[0]
                }
                Column {
                    visible: page.open === kind.modelData[0]
                    width: parent.width
                    leftPadding: 20 + Theme.s3
                    SettingsUi.Note { visible: kind.info.apps.length === 0; text: Tr.t("No app here can open these. Get one from the Store.") }
                    Repeater {
                        model: kind.info.apps.filter(id => { DesktopEntries.applications.values; return DesktopEntries.byId(id) !== null; })
                        SettingsUi.Radio {
                            required property string modelData
                            width: parent.width - 20 - Theme.s3
                            text: page.name(modelData)
                            group: kind.modelData[2]
                            on: modelData === kind.info.now
                            onPicked: page.set(kind.modelData, modelData)
                        }
                    }
                }
            }
        }
    }
}
