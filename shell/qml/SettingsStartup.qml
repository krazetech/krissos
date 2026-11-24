import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Apps > Startup: the apps that start when you sign in (XDG autostart: your own in
// ~/.config/autostart, the system's in /etc/xdg/autostart), each with a switch. Off writes
// Hidden=true into your own copy, which systemd's autostart generator honours; on takes it out.
Column {
    id: page
    spacing: Theme.s3

    readonly property string mine: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/autostart"
    property var items: []   // [{file, name, icon, on}]
    Component.onCompleted: lister.running = true
    Process {
        id: lister
        command: ["sh", "-c", `
            mine=$1
            for f in /etc/xdg/autostart/*.desktop "$mine"/*.desktop; do
                [ -f "$f" ] || continue
                b=\${f##*/}
                [ -f "$mine/$b" ] && [ "$f" != "$mine/$b" ] && continue
                awk -v b="$b" -F= '/^\\[/ { main = $0 == "[Desktop Entry]" } !main { next }
                    $1 == "Name" { n = $2 } $1 == "Icon" { i = $2 } $1 == "NoDisplay" && $2 == "true" { nd = 1 }
                    $1 == "Hidden" && $2 == "true" { h = 1 } $1 == "X-GNOME-Autostart-enabled" && $2 == "false" { h = 1 }
                    $1 == "OnlyShowIn" && $2 !~ /KrissOS|COSMIC/ { nd = 1 }
                    $1 == "NotShowIn" && $2 ~ /KrissOS|COSMIC/ { nd = 1 }
                    END { if (n != "" && !nd) printf "%s\\t%s\\t%s\\t%s\\n", b, n, i, h ? "off" : "on" }' "$f"
            done | sort -t "$(printf '\\t')" -k2`, "sh", page.mine]
        stdout: StdioCollector {
            onStreamFinished: page.items = text.split("\n").filter(l => l).map(l => l.split("\t"))
                .map(f => ({ file: f[0], name: f[1], icon: f[2], on: f[3] === "on" }))
        }
    }
    function set(item, on) {
        Quickshell.execDetached(["sh", "-c", `
            mine=$1 b=$2 on=$3
            mkdir -p "$mine"
            [ -f "$mine/$b" ] || cp "/etc/xdg/autostart/$b" "$mine/$b"
            sed -i '/^Hidden=/d; /^X-GNOME-Autostart-enabled=/d' "$mine/$b"
            [ "$on" = on ] || sed -i '/^\\[Desktop Entry\\]/a Hidden=true' "$mine/$b"
            # Back on, and the same as the system's: drop the copy.
            [ "$on" = on ] && [ -f "/etc/xdg/autostart/$b" ] && cmp -s "$mine/$b" "/etc/xdg/autostart/$b" && rm -f "$mine/$b"
            true`, "sh", mine, item.file, on ? "on" : "off"]);
        items = items.map(i => i.file === item.file ? Object.assign({}, i, { on: on }) : i);
    }

    SettingsUi.Card {
        SettingsUi.Note { text: items.length ? Tr.t("These start on their own when you sign in. Fewer makes signing in faster.") : Tr.t("Nothing starts on its own when you sign in.") }
        Repeater {
            model: page.items
            SettingsUi.Toggle {
                required property var modelData
                text: modelData.name
                checked: modelData.on
                onToggled: page.set(modelData, !checked)
            }
        }
    }
}
