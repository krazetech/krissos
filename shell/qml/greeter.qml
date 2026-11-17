//@ pragma IconTheme {{icon_theme}}
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// The login screen: the lock screen's face, with other users at the bottom left (as on
// Windows) and the desktop to start at the bottom right. greetd runs it on cosmic-comp
// through `kriss-shell greeter`.
ShellRoot {
    id: root

    property string password: ""
    property string message: ""
    property bool checking: false
    readonly property string hint: Tr.t("Press Enter to sign in")

    property var users: []      // [[login, name to show]]
    property int user: 0
    readonly property string userName: users.length ? users[user][1] : ""
    // ponytail: only AccountsService's copy; the greeter user cannot read ~/.face in a private home.
    readonly property var faces: users.length ? ["/var/lib/AccountsService/icons/" + users[user][0]] : []
    property var sessions: []   // [[name, command, desktop names]], the KrissOS Shell first
    property int session: 0

    // ponytail: the last user and desktop are not remembered; the greeter user has no
    // writable home. Add a state file under /var/lib if people use several.
    function submit() {
        if (checking || !users.length || !sessions.length) return;
        checking = true;
        message = "";
        Greetd.createSession(users[user][0]);
    }

    function fail(text) {
        checking = false;
        password = "";
        message = text;
    }

    Connections {
        target: Greetd
        // ponytail: only the password prompt is answered; other PAM messages (a
        // fingerprint reader, say) are not shown.
        function onAuthMessage(text, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password);
        }
        function onAuthFailure(text) { root.fail(Tr.t("That password didn't work. Try again.")); }
        // Quickshell cancels a failed attempt itself, and greetd answers that with an
        // error; only errors during an attempt mean something.
        function onError(text) { if (root.checking) root.fail(text); }
        function onReadyToLaunch() {
            const s = root.sessions[root.session];
            // ponytail: Exec split on spaces; no session file here quotes its arguments.
            Greetd.launch(s[1].split(" ").filter(a => a), ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=" + s[2]]);
        }
    }

    // People who can log in: uid 1000 and up with a real shell.
    Process {
        command: ["getent", "passwd"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.users = text.split("\n").map(l => l.split(":"))
                .filter(f => f.length > 6 && +f[2] >= 1000 && +f[2] < 60000 && !/(nologin|false)$/.test(f[6]))
                .map(f => [f[0], f[4].split(",")[0] || f[0]])
        }
    }

    // Desktops to start, from the Wayland session files.
    Process {
        command: ["sh", "-c", "grep -H -E '^(Name|Exec|DesktopNames)=' /usr/share/wayland-sessions/*.desktop"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const byFile = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(.*?):(Name|Exec|DesktopNames)=(.*)$/);
                    if (!m) continue;
                    if (!byFile[m[1]]) byFile[m[1]] = { file: m[1], Name: "", Exec: "", DesktopNames: "" };
                    const s = byFile[m[1]];
                    if (!s[m[2]]) s[m[2]] = m[3];
                }
                root.sessions = Object.values(byFile).filter(s => s.Exec)
                    .sort((a, b) => b.file.endsWith("/kriss-shell.desktop") - a.file.endsWith("/kriss-shell.desktop"))
                    .map(s => [s.Name, s.Exec, s.DesktopNames.replace(/;$/, "").replace(/;/g, ":")]);
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-greeter"
            // The first screen takes the keyboard; the others show the same field.
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.night

            LockFace { host: root }

            // Other users, as on Windows.
            Column {
                anchors { left: parent.left; bottom: parent.bottom; margins: 36 }
                spacing: 6
                visible: root.users.length > 1
                Repeater {
                    model: root.users
                    delegate: Choice {
                        required property var modelData
                        required property int index
                        label: modelData[1]
                        current: index === root.user
                        onClicked: { root.user = index; root.message = ""; }
                    }
                }
            }

            // The desktop to start; a click picks the next one.
            Choice {
                anchors { right: parent.right; bottom: parent.bottom; margins: 36 }
                visible: root.sessions.length > 1
                label: root.sessions.length ? root.sessions[root.session][0] : ""
                current: true
                onClicked: root.session = (root.session + 1) % root.sessions.length
            }
        }
    }

    component Choice: MouseArea {
        property string label
        property bool current
        width: text.implicitWidth + 28
        height: 36
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(Theme.nightFg, parent.current ? 0.14 : 0.0)
        }
        Text {
            id: text
            anchors.centerIn: parent
            text: parent.label
            color: Theme.alpha(Theme.nightFg, parent.current ? 1 : 0.7)
            font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
        }
    }
}
