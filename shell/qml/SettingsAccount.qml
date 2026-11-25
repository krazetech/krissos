import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Accounts > Your info and sign-in: your name and picture (AccountsService, which
// lets you change your own without the password; Start, the lock screen and the login screen
// show them), changing your password (passwd, in a terminal), and COSMIC's page for other people.
Column {
    id: page
    spacing: Theme.s3

    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string objectPath: "/org/freedesktop/Accounts/User" + uid
    property string uid: ""
    property string saved: ""
    Process {
        running: true
        command: ["id", "-u"]
        stdout: StdioCollector { onStreamFinished: page.uid = text.trim() }
    }
    function account(method, arg) {
        Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.Accounts", objectPath,
            "org.freedesktop.Accounts.User", method, "s", arg]);
    }

    SettingsUi.Card {
        Row {
            spacing: Theme.s4
            Avatar {
                size: Theme.dp(72)
                name: Desktop.personName
                faces: Desktop.faces
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s1
                Text {
                    text: Desktop.personName
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(20); weight: Font.DemiBold }
                }
                Text {
                    text: Tr.t("Signed in as %1 on this PC", page.user)
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: Theme.sp(13) }
                }
            }
        }
        SettingsUi.Push { text: Tr.t("Choose a picture"); onPicked: picker.open() }
        PicturePicker {
            id: picker
            stock: [["jerai", Tr.t("Gunung Jerai")], ["bunga-raya", Tr.t("Hibiscus")], ["wau", Tr.t("Moon kite")],
                    ["kucing", Tr.t("Cat")], ["penyu", Tr.t("Sea turtle")], ["permainan", Tr.t("Game controller")]]
                .map(p => [decodeURIComponent(String(Qt.resolvedUrl("pictures/" + p[0] + ".svg")).replace(/^file:\/\//, "")), p[1]])
            // ~/.face for the shell (a PNG: the login screen's copy has no name to tell an SVG
            // by), then AccountsService's copy of it for the login screen.
            onChosen: path => Quickshell.execDetached(["sh", "-c", `
                case "$1" in *.svg|*.SVG) rsvg-convert -w 256 -h 256 -o "$HOME/.face" "$1" ;; *) cp -f "$1" "$HOME/.face" ;; esac &&
                busctl --system call org.freedesktop.Accounts "$2" org.freedesktop.Accounts.User SetIconFile s "$HOME/.face"`,
                "sh", path, page.objectPath])
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Your name") }
        SettingsUi.Note { text: Tr.t("As Start, the lock screen and the login screen show it.") }
        Row {
            spacing: Theme.s2
            Rectangle {
                width: Theme.dp(260)
                height: Math.max(36, Theme.sp(14) + 20)
                radius: Theme.rControl
                color: Theme.win
                border.width: nameField.activeFocus ? Theme.focusWidth : Theme.rimWidth
                border.color: nameField.activeFocus ? Theme.accentText : Theme.line
                TextInput {
                    id: nameField
                    anchors.fill: parent
                    anchors.margins: Theme.s2
                    verticalAlignment: TextInput.AlignVCenter
                    text: Desktop.fullName
                    color: Theme.fg
                    clip: true
                    maximumLength: 64
                    font { family: Theme.sans; pixelSize: Theme.sp(14) }
                    activeFocusOnTab: true
                    onAccepted: rename.picked()
                    Accessible.role: Accessible.EditableText
                    Accessible.name: Tr.t("Your name")
                }
            }
            SettingsUi.Push {
                id: rename
                text: Tr.t("Save")
                onPicked: {
                    // No commas or colons: they would split the account's GECOS field.
                    const n = nameField.text.replace(/[,:]/g, " ").trim();
                    if (!n) return;
                    page.account("SetRealName", n);
                    Desktop.fullName = n;
                    page.saved = Tr.t("Saved.");
                }
            }
        }
        SettingsUi.Note { visible: page.saved !== ""; text: page.saved }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "lock"
            text: Tr.t("Change your password")
            detail: Tr.t("Opens a window that asks for the old one, then the new one twice")
            onPicked: Quickshell.execDetached(["sh", "-c", 'command -v cosmic-term >/dev/null && exec cosmic-term -- passwd || exec xdg-terminal-exec passwd'])
        }
        SettingsUi.LinkRow {
            glyph: "user"
            text: Tr.t("Other people")
            detail: Tr.t("Add someone, or make an account an administrator")
            external: true
            onPicked: Quickshell.execDetached(["cosmic-settings", "users"])
        }
    }
}
