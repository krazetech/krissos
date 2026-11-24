import QtQuick
import Quickshell
import Quickshell.Io

// Settings > System > Storage: how full each drive is (df), what in your home folder takes
// the space (du on the XDG folders, apps, temporary files and the bin), and emptying the bin.
Column {
    id: page
    spacing: Theme.s3

    function size(bytes) {
        const gb = bytes / 1e9;
        return gb >= 10 ? Tr.t("%1 GB", Math.round(gb)) : gb >= 1 ? Tr.t("%1 GB", gb.toFixed(1)) : Tr.t("%1 MB", Math.round(bytes / 1e6));
    }

    // [{source, target, size, used, free}], one per drive (btrfs mounts its subvolumes many times).
    property var drives: []
    Process {
        id: df
        running: true
        command: ["df", "-B1", "--output=source,target,size,used,avail", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = [];
                for (const l of text.trim().split("\n").slice(1)) {
                    const f = l.trim().split(/\s+/);
                    const src = f[0].replace(/\[.*\]$/, "");
                    // The small boot partitions are not for files.
                    if (f.length < 5 || !src.startsWith("/dev/") || seen[src] || /^\/(boot|efi)(\/|$)/.test(f[1])) continue;
                    seen[src] = true;
                    out.push({ source: src, target: f[1], size: +f[2], used: +f[3], free: +f[4] });
                }
                // The system drive first.
                page.drives = out.sort((a, b) => (b.target === "/") - (a.target === "/"));
            }
        }
    }

    // [{id, path, bytes}] for the home folder's parts, largest first.
    property var parts: []
    property bool counting: true
    Process {
        id: du
        running: true
        command: ["sh", "-c", `
            h=$HOME d=\${XDG_DATA_HOME:-$HOME/.local/share} c=\${XDG_CACHE_HOME:-$HOME/.cache}
            for k in DOCUMENTS DOWNLOAD PICTURES MUSIC VIDEOS DESKTOP; do
                p=$(xdg-user-dir $k 2>/dev/null); [ -n "$p" ] && [ "$p" != "$h" ] && [ -d "$p" ] && printf '%s\\t%s\\t%s\\n' $k "$p" "$(du -sb "$p" 2>/dev/null | cut -f1)"
            done
            printf 'APPS\\t%s\\t%s\\n' "$h/.var/app" "$(du -scb "$h/.var/app" /var/lib/flatpak "$d/flatpak" 2>/dev/null | tail -1 | cut -f1)"
            printf 'GAMES\\t%s\\t%s\\n' "$d/Steam/steamapps/common" "$(du -sb "$d/Steam/steamapps/common" 2>/dev/null | cut -f1)"
            printf 'CACHE\\t%s\\t%s\\n' "$c" "$(du -sb "$c" 2>/dev/null | cut -f1)"
            printf 'TRASH\\t%s\\t%s\\n' "$d/Trash" "$(du -sb "$d/Trash/files" 2>/dev/null | cut -f1)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                page.parts = text.trim().split("\n").map(l => l.split("\t"))
                    .filter(f => f.length === 3).map(f => ({ id: f[0], path: f[1], bytes: +f[2] || 0 }))
                    .sort((a, b) => b.bytes - a.bytes);
                page.counting = false;
            }
        }
    }
    function recount() { counting = true; df.running = true; du.running = true; }

    readonly property var names: ({
        DOCUMENTS: [Tr.t("Documents"), "info"], DOWNLOAD: [Tr.t("Downloads"), "external"], PICTURES: [Tr.t("Pictures"), "display"],
        MUSIC: [Tr.t("Music"), "volume"], VIDEOS: [Tr.t("Videos"), "display"], DESKTOP: [Tr.t("Desktop"), "display"],
        APPS: [Tr.t("Apps from the Store"), "settings"], GAMES: [Tr.t("Steam games"), "display"], CACHE: [Tr.t("Temporary files"), "clock"], TRASH: [Tr.t("Bin"), "restart"]
    })
    readonly property real biggest: parts.length ? Math.max(1, parts[0].bytes) : 1
    readonly property real trash: parts.find(p => p.id === "TRASH")?.bytes ?? 0

    component Bar: Rectangle {
        property real part
        width: parent.width
        height: 8
        radius: height / 2
        color: Theme.track
        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, parent.part))
            height: parent.height
            radius: parent.radius
            color: parent.part > 0.9 ? Theme.red : Theme.accent
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Drives") }
        Repeater {
            model: page.drives
            Column {
                required property var modelData
                width: parent.width
                spacing: Theme.s1
                Accessible.role: Accessible.StaticText
                Accessible.name: name.text + ", " + free.text
                Text {
                    id: name
                    text: modelData.target === "/" ? Tr.t("This PC") : modelData.target.split("/").pop() || modelData.target
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(14) }
                }
                Bar { part: modelData.used / modelData.size }
                Text {
                    id: free
                    text: Tr.t("%1 free of %2", page.size(modelData.free), page.size(modelData.size))
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(13) }
                }
            }
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("What's using space") }
        SettingsUi.Note { visible: page.counting; text: Tr.t("Counting…") }
        Repeater {
            model: page.counting ? [] : page.parts.filter(p => p.bytes > 0)
            Column {
                required property var modelData
                width: parent.width
                SettingsUi.LinkRow {
                    glyph: page.names[modelData.id]?.[1] ?? "info"
                    text: page.names[modelData.id]?.[0] ?? modelData.id
                    detail: page.size(modelData.bytes)
                    onPicked: Quickshell.execDetached(["xdg-open", modelData.id === "TRASH" ? "trash:///" : modelData.path])
                }
                Bar { part: modelData.bytes / page.biggest }
            }
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Free up space") }
        SettingsUi.Note {
            text: page.trash > 0 ? Tr.t("The bin holds %1. Emptying it deletes those files for good.", page.size(page.trash))
                                 : Tr.t("The bin is empty.")
        }
        Row {
            spacing: Theme.s2
            visible: page.trash > 0
            SettingsUi.Push {
                property bool sure: false
                text: sure ? Tr.t("Yes, delete them for good") : Tr.t("Empty the bin")
                main: sure
                onPicked: {
                    if (!sure) { sure = true; return; }
                    sure = false;
                    emptier.running = true;
                }
            }
        }
        Process { id: emptier; command: ["gio", "trash", "--empty"]; onExited: page.recount() }
    }
}
