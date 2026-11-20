import QtQuick
import Quickshell
import Quickshell.Io

// Settings > System > About: this PC's name (renamed through hostnamectl, which asks for the
// password), its parts, and the KrissOS version, with a button that copies it all for a
// forum post or a bug report.
Column {
    id: page
    spacing: Theme.s3

    property var info: ({})
    Process {
        id: gather
        running: true
        command: ["sh", "-c", `
            . /etc/os-release
            echo "os=\${PRETTY_NAME:-KrissOS} \${VERSION_CODENAME:-}"
            echo "shell=$(pacman -Q kriss-shell 2>/dev/null | cut -d' ' -f2)"
            echo "kernel=$(uname -r)"
            echo "host=$(hostnamectl hostname 2>/dev/null || cat /etc/hostname)"
            echo "model=$(cat /sys/devices/virtual/dmi/id/sys_vendor /sys/devices/virtual/dmi/id/product_name 2>/dev/null | grep -vi 'to be filled' | paste -sd ' ')"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
            echo "mem=$(awk '/MemTotal/ { printf "%.0f", $2 / 1048576 }' /proc/meminfo)"
            echo "gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller|display' | cut -d: -f3- | sed 's/^ *//; s/ (rev .*//' | paste -sd ';')"
            echo "disk=$(df -h --output=size / | tail -1 | tr -d ' ')"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) o[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                page.info = o;
                if (!name.activeFocus) name.text = o.host ?? "";
            }
        }
    }

    readonly property var rows: [
        [Tr.t("Version"), (info.os ?? "") + (info.shell ? " · " + Tr.t("Shell %1", info.shell) : "")],
        [Tr.t("Device"), info.model ?? ""],
        [Tr.t("Processor"), info.cpu ?? ""],
        [Tr.t("Memory"), info.mem ? Tr.t("%1 GB", info.mem) : ""],
        [Tr.t("Graphics"), (info.gpu ?? "").split(";").join("\n")],
        [Tr.t("System drive"), info.disk ?? ""],
        [Tr.t("Linux kernel"), info.kernel ?? ""]
    ].filter(r => r[1])

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("PC name") }
        SettingsUi.Note { text: Tr.t("What other devices see on your network and over Bluetooth. Letters, digits and dashes.") }
        Row {
            spacing: Theme.s2
            Rectangle {
                width: Theme.dp(260)
                height: Math.max(36, Theme.sp(14) + 20)
                radius: Theme.rControl
                color: Theme.win
                border.width: name.activeFocus ? Theme.focusWidth : Theme.rimWidth
                border.color: name.activeFocus ? Theme.accentText : Theme.line
                TextInput {
                    id: name
                    anchors.fill: parent
                    anchors.margins: Theme.s2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentInk
                    clip: true
                    font { family: Theme.sans; pixelSize: Theme.sp(14) }
                    activeFocusOnTab: true
                    maximumLength: 63
                    validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?/ }
                    onAccepted: rename.picked()
                    Accessible.role: Accessible.EditableText
                    Accessible.name: Tr.t("PC name")
                }
            }
            SettingsUi.Push {
                id: rename
                text: Tr.t("Rename")
                enabled: name.acceptableInput && name.text !== (page.info.host ?? "")
                opacity: enabled ? 1 : 0.4
                onPicked: if (enabled) renamer.running = true
            }
        }
    }
    Process {
        id: renamer
        command: ["hostnamectl", "set-hostname", name.text]
        onExited: gather.running = true
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("This PC") }
        Repeater {
            model: page.rows
            Row {
                required property var modelData
                width: parent.width
                spacing: Theme.s3
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData[0] + ": " + modelData[1]
                Text {
                    width: Math.min(Theme.dp(160), parent.width / 3)
                    text: parent.modelData[0]
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(13) }
                }
                Text {
                    width: parent.width - Math.min(Theme.dp(160), parent.width / 3) - Theme.s3
                    wrapMode: Text.WordWrap
                    text: parent.modelData[1]
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(13); weight: Font.Medium }
                }
            }
        }
        SettingsUi.Push {
            text: copied.running ? Tr.t("Copied") : Tr.t("Copy")
            onPicked: {
                Quickshell.execDetached(["wl-copy", page.rows.map(r => r[0] + ": " + r[1].replace(/\n/g, ", ")).join("\n")]);
                copied.restart();
            }
            Timer { id: copied; interval: 2000 }
        }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "send"
            text: Tr.t("Report a problem")
            detail: Tr.t("Send the KrissOS team what went wrong")
            onPicked: SettingsPages.open("report")
        }
    }
}
