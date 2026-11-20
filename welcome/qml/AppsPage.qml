import QtQuick
import QtQuick.Layouts

Page {
    id: page
    // flatpak id -> "installing" | "installed" | "failed"
    property var installs: ({})
    property var pending: null
    readonly property alias dialog: confirm  // for smoke_qml.py and screenshots

    function setInstall(id, state) {
        const m = Object.assign({}, installs)
        m[id] = state
        installs = m
    }
    function categoryLabel(c) {
        return { office: qsTr("Office and study"), creative: qsTr("Creative"), chat: qsTr("Chat and calls"),
                 media: qsTr("Music and video"), browser: qsTr("Web browsers"), games: qsTr("Game launchers"),
                 dev: qsTr("Programming"), utilities: qsTr("Utilities"), cloud: qsTr("Cloud storage") }[c] || c
    }
    function reasonLabel(r) {
        return { ram: qsTr("needs about 16 GB of RAM"),
                 virt: qsTr("CPU virtualisation is off (turn on VT-x or AMD-V in the BIOS)"),
                 kvm: qsTr("KVM is not available"), cores: qsTr("needs at least 4 CPU threads"),
                 unknown: qsTr("the hardware check did not run") }[r] || r
    }

    Connections {
        target: backend
        function onInstallDone(id, ok) { page.setInstall(id, ok ? "installed" : "failed") }
    }

    Confirm {
        id: confirm
        title: page.pending ? qsTr("Install %1?").arg(page.pending.name) : ""
        subtitle: page.pending ? qsTr("KrissOS will install it from Flathub. You may be asked for your password.\n\nRuns: flatpak install flathub %1").arg(page.pending.flatpak) : ""
        onAccepted: { page.setInstall(page.pending.flatpak, "installing"); backend.install(page.pending.flatpak) }
    }

    Note {
        Layout.fillWidth: true
        kind: backend.hw.winboat_ok ? "good" : "info"
        text: backend.hw.winboat_ok
            ? qsTr("Pick the Windows apps you use. This PC can also run the real Windows versions in WinBoat, a Windows virtual machine.")
            : qsTr("Pick the Windows apps you use. WinBoat (a Windows virtual machine) is not offered on this PC: %1.")
                .arg(backend.hw.reasons.map(page.reasonLabel).join("; "))
    }

    Repeater {
        model: backend.apps
        delegate: ColumnLayout {
            id: row
            required property var modelData
            required property int index
            readonly property var ans: pick.checked ? backend.answer(modelData) : null
            Layout.fillWidth: true
            spacing: 6

            Txt {
                Layout.fillWidth: true
                Layout.topMargin: index === 0 ? 0 : 10
                visible: index === 0 || backend.apps[index - 1].category !== modelData.category
                text: page.categoryLabel(modelData.category)
                soft: true
                bold: true
                size: 13
            }
            Card {
                Layout.fillWidth: true
                padding: 12
                spacing: 10
                color: pick.hovered && !pick.checked ? backend.theme.cardHover : backend.theme.card
                Check {
                    id: pick
                    Layout.fillWidth: true
                    text: modelData.name
                    font.weight: Font.Medium
                }
                ColumnLayout {
                    visible: pick.checked
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    spacing: 8
                    Txt {
                        Layout.fillWidth: true
                        bold: true
                        text: !row.ans ? "" : {
                            native: qsTr("%1 is available for KrissOS.").arg(row.modelData.name),
                            winboat: qsTr("Run the real Windows version in WinBoat."),
                            alternative: qsTr("Use a Linux app that does the same job:"),
                            wine: qsTr("Run the Windows version with Wine, through Bottles."),
                            web: qsTr("Use it in your web browser."),
                            none: qsTr("There is no good way to run this on Linux yet.")
                        }[row.ans.kind]
                    }
                    Pill {
                        visible: row.ans && row.ans.kind === "winboat"
                        text: qsTr("Get WinBoat")
                        glyph: "display"
                        highlighted: true
                        // ponytail: links out until WinBoat is packaged in [kriss]; then `kriss install winboat`.
                        onClicked: Qt.openUrlExternally("https://www.winboat.app")
                    }
                    Txt {
                        visible: row.ans && row.ans.kind === "winboat" && row.ans.alts.length > 0
                        text: qsTr("Or use a Linux app:")
                    }
                    Repeater {
                        model: row.ans && row.ans.kind !== "web" ? row.ans.alts : []
                        delegate: RowLayout {
                            required property var modelData
                            readonly property string installState: modelData.flatpak ? (page.installs[modelData.flatpak] || "") : ""
                            Layout.fillWidth: true
                            Txt {
                                Layout.fillWidth: true
                                text: modelData.name + (modelData.unofficial ? " " + qsTr("(unofficial)") : "")
                            }
                            Pill {
                                text: !modelData.flatpak ? qsTr("Website")
                                    : installState === "installing" ? qsTr("Installing…")
                                    : installState === "installed" ? qsTr("Installed")
                                    : installState === "failed" ? qsTr("Failed, try again") : qsTr("Install")
                                glyph: !modelData.flatpak ? "globe" : installState === "installed" ? "check" : "update"
                                enabled: installState !== "installing" && installState !== "installed"
                                onClicked: {
                                    if (!modelData.flatpak) return Qt.openUrlExternally(modelData.url)
                                    page.pending = modelData
                                    confirm.open()
                                }
                            }
                        }
                    }
                    Pill {
                        visible: row.ans && row.ans.kind === "wine"
                        text: qsTr("Install Bottles")
                        glyph: "update"
                        onClicked: { page.pending = { name: "Bottles", flatpak: "com.usebottles.bottles" }; confirm.open() }
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: row.ans && row.ans.kind !== "wine" && row.ans.wine !== "no"
                        soft: true
                        text: row.ans && row.ans.wine === "yes"
                            ? qsTr("The Windows version also runs with Wine (through Bottles).")
                            : qsTr("The Windows version may run with Wine, with problems.")
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: row.ans && row.ans.winboat_blocked
                        soft: true
                        text: qsTr("The full Windows version needs WinBoat, which this PC cannot run well.")
                    }
                    Pill {
                        visible: row.ans && row.ans.web !== ""
                        flat: row.ans && row.ans.kind !== "web"
                        text: qsTr("Open the web version")
                        glyph: "globe"
                        onClicked: Qt.openUrlExternally(row.ans.web)
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: !!row.modelData.uncertain
                        color: backend.theme.amber
                        text: qsTr("Not fully tested; results may vary.")
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: !!row.modelData.note
                        soft: true
                        size: 12
                        text: row.modelData.note || ""
                    }
                }
            }
        }
    }
}
