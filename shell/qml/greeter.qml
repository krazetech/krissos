//@ pragma IconTheme {{icon_theme}}
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// The login screen: the lock screen's face, with the users (pictures and names) at the
// bottom left, as on Windows, and the desktop to start at the bottom right. greetd runs it
// on cosmic-comp through `kriss-shell greeter`. It opens on the boot splash's keris, which
// opens out into the login screen (below).
ShellRoot {
    id: root

    property string password: ""
    property string message: ""
    property bool checking: false
    readonly property string hint: Tr.t("Press any key to sign in")
    readonly property string verb: Tr.t("Sign in")

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
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kriss-greeter"
            // The first screen takes the keyboard; the others show the same field.
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.night

            // The boot splash (kriss-theme's Plymouth theme) ends on black. The keris comes
            // back here at the same place and size, then opens out over the whole screen and
            // the login screen shows through it. kriss.script sizes the logo the same way.
            readonly property real logo: Math.floor(Math.min(win.width, win.height) * 0.09) * 2
            readonly property real far: Math.hypot(win.width, win.height) / 2 + 2
            property real intro: 0  // the keris and its glow coming back, 0 to 1
            property real open: 0   // the opening, 0 to 1 at a steady pace; ease() shapes each part
            function ease(t) {
                t = Math.max(0, Math.min(1, t));
                return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
            }
            SequentialAnimation {
                running: true
                NumberAnimation { target: win; property: "intro"; to: 1; duration: Theme.ms(250); easing.type: Theme.ease }
                PauseAnimation { duration: Theme.ms(100) }
                NumberAnimation { target: win; property: "open"; to: 1; duration: Theme.ms(1100) }
            }

            // The circle the login screen shows through, a step behind the disc's edge.
            Item {
                id: hole
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    readonly property real r: win.logo * 0.3 + (win.far - win.logo * 0.3) * win.ease((win.open - 0.12) / 0.88)
                    anchors.centerIn: parent
                    width: 2 * r
                    height: width
                    radius: r
                }
            }

            Item {
                anchors.fill: parent
                opacity: Math.max(0, (win.open - 0.45) / 0.55)
                scale: 0.96 + 0.04 * opacity
                layer.enabled: win.open < 1
                layer.effect: MultiEffect { maskEnabled: true; maskSource: hole }

                LockFace { id: face; host: root }

                // The users, as on Windows: picture and name; the one signing in is lit.
                Column {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
                    spacing: Theme.s1
                    visible: root.users.length > 1
                    Repeater {
                        model: root.users
                        delegate: LockButton {
                            id: userChip
                            required property var modelData
                            required property int index
                            implicitWidth: userRow.implicitWidth + 20
                            implicitHeight: 44
                            accessibleName: modelData[1]
                            color: Theme.alpha(Theme.nightFg, index === root.user ? 0.16 : activeFocus ? 0.12 : 0)
                            onClicked: { root.user = index; root.message = ""; face.ask(""); }
                            Row {
                                id: userRow
                                anchors { left: parent.left; leftMargin: Theme.s1; verticalCenter: parent.verticalCenter }
                                spacing: Theme.s2
                                Avatar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 32
                                    name: userChip.modelData[1]
                                    faces: ["/var/lib/AccountsService/icons/" + userChip.modelData[0]]
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: userChip.modelData[1]
                                    color: Theme.alpha(Theme.nightFg, userChip.index === root.user ? 1 : 0.75)
                                    font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.DemiBold }
                                }
                            }
                        }
                    }
                }

                // The desktop to start: a pill that opens the list above it.
                LockButton {
                    id: sessionPill
                    property bool open: false
                    anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
                    visible: root.sessions.length > 1
                    glyph: open ? "down" : "up"
                    label: root.sessions.length ? root.sessions[root.session][0] : ""
                    accessibleName: Tr.t("Desktop: %1", label)
                    onClicked: open = !open
                    Keys.onEscapePressed: open = false
                }
                Rectangle {
                    anchors { right: sessionPill.right; bottom: sessionPill.top; bottomMargin: Theme.s2 }
                    visible: sessionPill.open && sessionPill.visible
                    width: sessionList.implicitWidth + 12
                    height: sessionList.implicitHeight + 12
                    radius: Theme.rCard
                    color: Theme.alpha(Theme.night, 0.72)
                    border.width: 1
                    border.color: Theme.alpha(Theme.nightFg, 0.12)
                    Column {
                        id: sessionList
                        anchors.centerIn: parent
                        spacing: Theme.s0
                        Repeater {
                            model: root.sessions
                            delegate: LockButton {
                                required property var modelData
                                required property int index
                                width: Math.max(implicitWidth, sessionList.width)
                                glyph: index === root.session ? "check" : ""
                                label: modelData[0]
                                onClicked: { root.session = index; sessionPill.open = false; sessionPill.forceActiveFocus(); }
                                Keys.onEscapePressed: { sessionPill.open = false; sessionPill.forceActiveFocus(); }
                            }
                        }
                    }
                }
            }

            // The keris, over the login screen until it has opened. The glow and logo are
            // the splash's own images, so the hand-off matches it pixel for pixel.
            Image {
                anchors.centerIn: parent
                width: Math.floor(win.logo * 2.6 / 2) * 2
                height: width
                source: "file:///usr/share/plymouth/themes/kriss/glow-512.png"
                opacity: 0.35 * win.intro * Math.max(0, 1 - win.open * 2)
                visible: opacity > 0
            }
            Rectangle {
                id: disc
                readonly property real r: win.logo / 2 + (win.far - win.logo / 2) * win.ease(win.open)
                anchors.centerIn: parent
                width: 2 * r
                height: width
                radius: r
                color: Theme.accent
                opacity: win.intro * (1 - Math.max(0, (win.open - 0.55) / 0.45))
                visible: opacity > 0
            }
            Image {
                anchors.centerIn: parent
                width: disc.width
                height: width
                source: "file:///usr/share/plymouth/themes/kriss/logo-512.png"
                opacity: win.intro * Math.max(0, 1 - win.open * 3)
                visible: opacity > 0
            }
        }
    }
}
