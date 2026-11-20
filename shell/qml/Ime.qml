pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// The input method (fcitx5) the taskbar shows, and Windows+Space (`kriss-shell input next`).
// Click or Windows+Space steps through the fcitx5 profile. fcitx5's own tray icon is hidden
// in the Bar; it is still the signal that the input method changed, so nothing polls.
Singleton {
    id: ip

    readonly property var sni: SystemTray.items.values.find(i => i.id === "Fcitx") ?? null
    readonly property bool shown: sni !== null && list.length > 1
    // fcitx5 redraws its icon and tooltip on every switch, including Ctrl+Space in an app.
    readonly property string sniState: sni ? [sni.icon, sni.tooltipTitle, sni.title].join("|") : ""
    // Only while fcitx5 is up: fcitx5-remote talks D-Bus, which would start a fcitx5 the user quit.
    onSniStateChanged: if (sni) current.running = true

    property string im: ""
    property var list: []

    readonly property var look: {
        if (im === "keyboard-us") return ["EN", Tr.t("English")];
        if (im === "pinyin") return ["拼", Tr.t("Chinese (Pinyin)")];
        if (im.startsWith("m17n_ta")) return ["த", Tr.t("Tamil")];
        if (im.startsWith("keyboard-my")) return ["ج", Tr.t("Jawi")];
        // Anything else the user added: the layout code, e.g. keyboard-de -> DE.
        const code = im.replace(/^keyboard-/, "").replace(/^m17n_/, "").split(/[-_]/)[0];
        return [code.slice(0, 2).toUpperCase(), im];
    }

    function next(step) {
        if (!sni || !list.length) return;
        const i = list.indexOf(im);
        const to = list[((i < 0 ? 0 : i) + step + list.length) % list.length];
        im = to;  // shown at once; fcitx5's icon change confirms it
        set.command = ["fcitx5-remote", "-s", to];
        set.running = true;
    }

    // The order Windows+Space steps through: the user's profile, else the KrissOS one.
    Process {
        id: profile
        running: ip.sni !== null
        command: ["sh", "-c", "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile\" 2>/dev/null || cat /etc/xdg/fcitx5/profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                let inItem = false;
                for (const l of text.split("\n")) {
                    if (l.startsWith("[")) inItem = /^\[Groups\/0\/Items\/\d+\]$/.test(l.trim());
                    else if (inItem && l.startsWith("Name=")) names.push(l.slice(5).trim());
                }
                ip.list = names;
            }
        }
    }
    Process {
        id: current
        command: ["fcitx5-remote", "-n"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) ip.im = text.trim() }
    }
    Process { id: set }
    // A changed profile (fcitx5's settings, or the KrissOS Settings app) is read again.
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/fcitx5/profile"
        watchChanges: true
        printErrors: false
        onFileChanged: profile.running = true
    }

    IpcHandler {
        target: "input"
        function next(): void { ip.next(1); }
        function previous(): void { ip.next(-1); }
    }

}
