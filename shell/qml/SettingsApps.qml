import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Apps > Installed apps: every app in Start, a search, and Uninstall, through
// `pkexec kriss remove --yes` as the Store does (a snapshot first; polkit asks for the
// password once for a few minutes). The package is the Flatpak app, or the pacman package
// that owns the app's desktop file. KrissOS's own parts can't be removed from here.
Column {
    id: page
    spacing: Theme.s3

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var shown: apps.filter(e => !filter.text || e.name.toLowerCase().includes(filter.text.toLowerCase()))
    property string asking: ""      // the app whose Uninstall is waiting for a yes
    property string busy: ""
    property string message: ""
    // Desktop file id: "flatpak ID" or "pacman NAME", worked out when Uninstall is pressed.
    property var owner: ({})
    function protectedPkg(p) { return /^(kriss-|cosmic-|quickshell|linux|systemd|pacman|flatpak|xdg-|pipewire|wireplumber|networkmanager|bluez)/.test(p); }

    Process {
        id: whose
        property string app: ""
        command: ["sh", "-c", `
            IFS=:; for d in \${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                f=$d/applications/$1.desktop
                [ -f "$f" ] || continue
                case $f in */flatpak/exports/*) echo "flatpak $1"; exit ;; esac
                p=$(pacman -Qqo "$f" 2>/dev/null) && echo "pacman $p" && exit
                echo "none"; exit
            done; echo none`, "sh", app]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = Object.assign({}, page.owner);
                o[whose.app] = text.trim();
                page.owner = o;
            }
        }
    }
    Process {
        id: remover
        property string app: ""
        stdout: StdioCollector { id: removeOut }
        stderr: StdioCollector { id: removeErr }
        onExited: code => {
            page.message = code === 0 ? Tr.t("%1 was uninstalled.", remover.app)
                : Tr.t("%1 could not be uninstalled: %2", remover.app, (removeErr.text || removeOut.text).trim().split("\n").pop());
            page.busy = "";
        }
    }

    SettingsUi.Card {
        Rectangle {
            width: parent.width
            height: Math.max(40, Theme.sp(14) + 24)
            radius: height / 2
            color: Theme.win
            border.width: filter.activeFocus ? Theme.focusWidth : Theme.rimWidth
            border.color: filter.activeFocus ? Theme.accentText : Theme.line
            TextInput {
                id: filter
                anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s4 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(14) }
                activeFocusOnTab: true
                Accessible.role: Accessible.EditableText
                Accessible.name: Tr.t("Find an app")
                Text { visible: !parent.text; text: Tr.t("Find an app"); color: Theme.soft; font: parent.font }
            }
        }
        SettingsUi.Note { visible: page.message !== ""; text: page.message }
        SettingsUi.Note { text: Tr.t("%1 apps", page.shown.length) }
        SettingsUi.LinkRow {
            glyph: "apps"
            text: Tr.t("Get more apps from the Store")
            onPicked: Quickshell.execDetached(["kriss-store"])
        }
    }

    SettingsUi.Card {
        Repeater {
            model: page.shown
            Column {
                id: app
                required property var modelData
                width: parent.width
                spacing: Theme.s1
                readonly property string own: page.owner[modelData.id] ?? ""
                readonly property bool open: page.asking === modelData.id
                Row {
                    width: parent.width
                    spacing: Theme.s3
                    Image {
                        source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                        sourceSize: Qt.size(28, 28)
                        width: 28; height: 28
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        width: parent.width - 28 - uninstall.width - 2 * Theme.s3
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: app.modelData.name
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                    }
                    SettingsUi.Push {
                        id: uninstall
                        text: page.busy === app.modelData.name ? Tr.t("Uninstalling…") : Tr.t("Uninstall")
                        anchors.verticalCenter: parent.verticalCenter
                        onPicked: {
                            if (page.busy) return;
                            page.asking = app.open ? "" : app.modelData.id;
                            if (page.asking && !app.own) { whose.app = app.modelData.id; whose.running = true; }
                        }
                    }
                }
                Row {
                    visible: app.open
                    spacing: Theme.s2
                    leftPadding: 28 + Theme.s3
                    SettingsUi.Note {
                        width: implicitWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: !app.own ? Tr.t("Checking…")
                            : app.own === "none" ? Tr.t("This app didn't come from a package, so it can't be uninstalled here.")
                            : page.protectedPkg(app.own.split(" ")[1]) ? Tr.t("This is part of KrissOS and stays.")
                            : Tr.t("Uninstall %1? A snapshot is taken first.", app.modelData.name)
                    }
                    SettingsUi.Push {
                        visible: app.own !== "" && app.own !== "none" && !page.protectedPkg(app.own.split(" ")[1])
                        main: true
                        text: Tr.t("Uninstall")
                        onPicked: {
                            page.asking = "";
                            page.busy = remover.app = app.modelData.name;
                            remover.command = ["pkexec", "kriss", "remove", "--yes", app.own.split(" ")[1]];
                            remover.running = true;
                        }
                    }
                }
            }
        }
    }
}
