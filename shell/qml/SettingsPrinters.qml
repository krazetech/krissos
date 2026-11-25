import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Bluetooth and devices > Printers: the printers CUPS knows, including the ones it
// finds on the network by itself (driverless IPP Everywhere / AirPrint, through Avahi), the
// default one (this user's, through lpoptions), a test page, removing one, and adding one by
// its network address.
Column {
    id: page
    spacing: Theme.s3

    // [{name, info, state, added}]; `added` is a queue set up in CUPS, the rest are ones
    // CUPS sees on the network and prints to as they are.
    property var printers: []
    property string fallback: ""   // the default printer
    property bool looking: true
    property string error: ""

    Process {
        id: lister
        running: true
        // lpstat -e waits a moment for printers on the network to answer.
        command: ["sh", "-c", `
            added=$(lpstat -p 2>/dev/null | awk '$1 == "printer" { print $2 }')
            echo "default=$(lpstat -d 2>/dev/null | sed -n 's/^.*: *//p')"
            for p in $(lpstat -e 2>/dev/null); do
                info=$(lpoptions -p "$p" 2>/dev/null | grep -o "printer-info='[^']*'\\|printer-info=[^ ]*" | head -1 | sed "s/^printer-info=//; s/'//g")
                state=$(lpstat -p "$p" 2>/dev/null | head -1 | grep -o 'is idle\\|now printing\\|disabled' | head -1)
                case " $(echo $added) " in *" $p "*) a=1 ;; *) a=0 ;; esac
                printf 'printer\\t%s\\t%s\\t%s\\t%s\\n' "$p" "$info" "$state" "$a"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const l of text.split("\n")) {
                    if (l.startsWith("default=")) page.fallback = l.slice(8).trim();
                    const f = l.split("\t");
                    if (f[0] === "printer" && f[1]) list.push({ name: f[1], info: f[2] || f[1].replace(/_/g, " "), state: f[3], added: f[4] === "1" });
                }
                page.printers = list;
                page.looking = false;
            }
        }
    }
    function refresh() { looking = true; lister.running = true; }

    // Runs a CUPS command; what it says on failure is shown on the page.
    function run(args) {
        error = "";
        const p = runner.createObject(page, { command: args });
        p.exited.connect(code => { if (code !== 0) page.error = p.said || Tr.t("That didn't work."); page.refresh(); p.destroy(); });
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: proc
            property string said
            stderr: StdioCollector { onStreamFinished: proc.said = text.trim() }
        }
    }

    function stateText(p) {
        if (p.state === "now printing") return Tr.t("Printing");
        if (p.state === "disabled") return Tr.t("Paused");
        return p.added ? Tr.t("Ready") : Tr.t("Ready, found on the network");
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Printers") }
        SettingsUi.Note {
            visible: page.looking || page.printers.length === 0
            text: page.looking ? Tr.t("Looking for printers…")
                : Tr.t("No printers found. Turn the printer on and connect it to the same Wi-Fi or network as this PC, or add it by its address below.")
        }
        Repeater {
            model: page.printers
            Column {
                required property var modelData
                width: parent.width
                SettingsUi.Radio {
                    glyph: "printer"
                    text: modelData.info
                    detail: page.stateText(modelData) + (modelData.name === page.fallback ? " · " + Tr.t("Default") : "")
                    group: Tr.t("Default printer")
                    on: modelData.name === page.fallback
                    onPicked: page.run(["lpoptions", "-d", modelData.name])
                }
                Row {
                    spacing: Theme.s2
                    leftPadding: Theme.s5
                    SettingsUi.Push {
                        text: Tr.t("Print a test page")
                        onPicked: page.run(["lp", "-d", modelData.name, "-t", Tr.t("KrissOS test page"), "/usr/share/cups/data/testprint"])
                    }
                    SettingsUi.Push {
                        visible: modelData.added
                        text: Tr.t("Remove")
                        onPicked: page.run(["lpadmin", "-x", modelData.name])
                    }
                }
            }
        }
        SettingsUi.Note { visible: page.error !== ""; text: page.error; color: Theme.red }
        SettingsUi.Push {
            text: Tr.t("Look again")
            enabled: !page.looking
            opacity: enabled ? 1 : 0.4
            onPicked: page.refresh()
        }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Add a printer by its address") }
        SettingsUi.Note { text: Tr.t("For a printer on another network. Most printers made since 2015 work with no driver. The address is on the printer's screen or its network page.") }
        Row {
            spacing: Theme.s2
            Rectangle {
                width: Theme.dp(260)
                height: Math.max(36, Theme.sp(14) + 20)
                radius: Theme.rControl
                color: Theme.win
                border.width: address.activeFocus ? Theme.focusWidth : Theme.rimWidth
                border.color: address.activeFocus ? Theme.accentText : Theme.line
                TextInput {
                    id: address
                    anchors.fill: parent
                    anchors.margins: Theme.s2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentInk
                    clip: true
                    font { family: Theme.sans; pixelSize: Theme.sp(14) }
                    activeFocusOnTab: true
                    maximumLength: 253
                    // A host name or IPv4 address, with an optional port.
                    validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:\d{1,5})?/ }
                    onAccepted: add.picked()
                    Accessible.role: Accessible.EditableText
                    Accessible.name: Tr.t("Printer address")
                    Text {
                        visible: !address.text && !address.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                        text: "192.168.1.20"
                        color: Theme.soft
                        font: address.font
                    }
                }
            }
            SettingsUi.Push {
                id: add
                text: Tr.t("Add")
                main: true
                enabled: address.acceptableInput
                opacity: enabled ? 1 : 0.4
                onPicked: {
                    if (!enabled) return;
                    const name = "Printer-" + address.text.replace(/[^A-Za-z0-9]+/g, "-");
                    page.run(["lpadmin", "-p", name, "-E", "-v", "ipp://" + address.text + "/ipp/print", "-m", "everywhere"]);
                    address.text = "";
                }
            }
        }
    }
}
