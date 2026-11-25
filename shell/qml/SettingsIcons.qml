import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Personalise > Icons: the icon pack, for apps and the shell. COSMIC's own
// setting (com.system76.CosmicTk icon_theme) is the one place it is kept; the session starts
// the shell with it (QS_ICON_THEME), and GTK, Qt and KDE apps get it here. Quickshell reads
// its icon theme only when it starts, so picking one restarts the shell (the session brings
// it straight back; open apps stay).
Column {
    id: page
    spacing: Theme.s3

    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cosmic/com.system76.CosmicTk/v1/icon_theme"
    readonly property string current: (iconFile.text() ?? "").trim().replace(/"/g, "") || "{{icon_theme}}"
    FileView { id: iconFile; path: page.config; printErrors: false }

    // The icon themes installed: [[folder name, name]]. A folder with only cursors has no
    // Directories line; hicolor and default are fallbacks, not packs.
    property var packs: []
    Process {
        running: true
        command: ["sh", "-c", `for d in /usr/share/icons/* "$HOME/.local/share/icons"/* "$HOME/.icons"/*; do
            f="$d/index.theme"; b=\${d##*/}
            [ -f "$f" ] && grep -q '^Directories=' "$f" || continue
            case "$b" in hicolor|default|locolor) continue;; esac
            printf '%s\\t%s\\n' "$b" "$(sed -n 's/^Name=//p' "$f" | head -1)"
        done | sort -u -t "$(printf '\\t')" -k1,1`]
        stdout: StdioCollector {
            onStreamFinished: page.packs = text.trim().split("\n").filter(l => l).map(l => {
                const [id, name] = l.split("\t");
                return [id, name || id];
            })
        }
    }

    function pick(id) {
        Quickshell.execDetached(["sh", "-c", `
            c=\${XDG_CONFIG_HOME:-$HOME/.config}
            d="$c/cosmic/com.system76.CosmicTk/v1"
            mkdir -p "$d" && printf '"%s"' "$1" > "$d/.icon_theme.new" && mv -f "$d/.icon_theme.new" "$d/icon_theme"
            gsettings set org.gnome.desktop.interface icon-theme "$1"
            for f in "$c/gtk-3.0/settings.ini" "$c/gtk-4.0/settings.ini"; do
                [ -f "$f" ] && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$1/" "$f"
            done
            [ -f "$c/qt6ct/qt6ct.conf" ] && sed -i "s/^icon_theme=.*/icon_theme=$1/" "$c/qt6ct/qt6ct.conf"
            command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kdeglobals --group Icons --key Theme "$1"
            # Back to this page once the shell is up again.
            ( sleep 2; for i in 1 2 3 4 5 6 7 8 9 10; do kriss-shell settings icons 2>/dev/null && break; sleep 1; done ) &`, "sh", id]);
        // A failing exit, so the session starts the shell again (a clean one signs out).
        restart.start();
    }
    Timer { id: restart; interval: 400; onTriggered: Qt.exit(3) }

    SettingsUi.Card {
        SettingsUi.Choice {
            text: Tr.t("Icon pack")
            detail: Tr.t("The taskbar restarts for a moment to pick up the new icons. Some apps show them after you open them again.")
            value: page.current
            options: page.packs
            onPicked: v => { if (v !== page.current) page.pick(v); }
        }
    }
}
