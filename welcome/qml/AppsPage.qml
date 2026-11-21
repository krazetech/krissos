import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    // flatpak id -> "installing" | "installed" | "failed"
    property var installs: ({})
    property var pending: null

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

    Kirigami.PromptDialog {
        id: officeConfirm
        title: qsTr("Install Microsoft Office?")
        subtitle: qsTr("Word, Excel and PowerPoint are downloaded from Microsoft (about 3 GB) and installed in WinBoat's Windows. It needs the internet, WinBoat set up first, and your own Microsoft 365 account or product key: sign in or enter the key when Word first opens. KrissOS includes no Office files.\n\nRuns: kriss winapps office")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: { page.setInstall("office", "installing"); backend.installExtra("office") }
    }
    Component.onCompleted: if (backend.extraInstalled("office")) setInstall("office", "installed")

    Kirigami.PromptDialog {
        id: confirm
        title: page.pending ? qsTr("Install %1?").arg(page.pending.name) : ""
        subtitle: page.pending ? qsTr("KrissOS will install it from Flathub. You may be asked for your password.\n\nRuns: flatpak install flathub %1").arg(page.pending.flatpak) : ""
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: { page.setInstall(page.pending.flatpak, "installing"); backend.install(page.pending.flatpak) }
    }

    header: Kirigami.InlineMessage {
        visible: true
        position: Kirigami.InlineMessage.Position.Header
        type: backend.hw.winboat_ok ? Kirigami.MessageType.Positive : Kirigami.MessageType.Information
        text: backend.hw.winboat_ok
            ? qsTr("Pick the Windows apps you use. This PC can also run the real Windows versions in WinBoat, a Windows virtual machine.")
            : qsTr("Pick the Windows apps you use. WinBoat (a Windows virtual machine) is not offered on this PC: %1.")
                .arg(backend.hw.reasons.map(page.reasonLabel).join("; "))
    }

    ListView {
        model: backend.apps
        delegate: ColumnLayout {
            id: row
            required property var modelData
            required property int index
            readonly property var ans: pick.checked ? backend.answer(modelData) : null
            width: ListView.view.width
            spacing: 0

            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: index === 0 || backend.apps[index - 1].category !== modelData.category
                text: page.categoryLabel(modelData.category)
            }
            QQC2.CheckDelegate {
                id: pick
                Layout.fillWidth: true
                text: modelData.name
            }
            Kirigami.AbstractCard {
                visible: pick.checked
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                contentItem: ColumnLayout {
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.bold: true
                        text: !row.ans ? "" : {
                            native: qsTr("%1 is available for KrissOS.").arg(row.modelData.name),
                            winboat: qsTr("Run the real Windows version in WinBoat."),
                            alternative: qsTr("Use a Linux app that does the same job:"),
                            wine: qsTr("Run the Windows version with Wine, through Bottles."),
                            web: qsTr("Use it in your web browser."),
                            none: qsTr("There is no good way to run this on Linux yet.")
                        }[row.ans.kind]
                    }
                    QQC2.Button {
                        visible: row.ans && row.ans.kind === "winboat"
                        text: qsTr("Get WinBoat")
                        icon.name: "computer"
                        highlighted: true
                        // ponytail: links out until WinBoat is packaged in [kriss]; then `kriss install winboat`.
                        onClicked: Qt.openUrlExternally("https://www.winboat.app")
                    }
                    QQC2.Button {
                        readonly property string officeState: page.installs.office || ""
                        visible: row.ans && row.ans.kind === "winboat" && row.modelData.id === "office"
                        text: officeState === "installing" ? qsTr("Installing Office…")
                            : officeState === "installed" ? qsTr("Office is installed")
                            : officeState === "failed" ? qsTr("Office did not install. Set up WinBoat first, then try again")
                            : qsTr("Install Microsoft Office")
                        icon.name: "download"
                        enabled: officeState !== "installing" && officeState !== "installed"
                        onClicked: officeConfirm.open()
                    }
                    QQC2.Label {
                        visible: row.ans && row.ans.kind === "winboat" && row.ans.alts.length > 0
                        text: qsTr("Or use a Linux app:")
                    }
                    Repeater {
                        model: row.ans && row.ans.kind !== "web" ? row.ans.alts : []
                        delegate: RowLayout {
                            required property var modelData
                            readonly property string installState: modelData.flatpak ? (page.installs[modelData.flatpak] || "") : ""
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData.name + (modelData.unofficial ? " " + qsTr("(unofficial)") : "")
                            }
                            QQC2.Button {
                                text: !modelData.flatpak ? qsTr("Website")
                                    : installState === "installing" ? qsTr("Installing…")
                                    : installState === "installed" ? qsTr("Installed")
                                    : installState === "failed" ? qsTr("Failed, try again") : qsTr("Install")
                                icon.name: modelData.flatpak ? "download" : "internet-services"
                                enabled: installState !== "installing" && installState !== "installed"
                                onClicked: {
                                    if (!modelData.flatpak) return Qt.openUrlExternally(modelData.url)
                                    page.pending = modelData
                                    confirm.open()
                                }
                            }
                        }
                    }
                    QQC2.Button {
                        visible: row.ans && row.ans.kind === "wine"
                        text: qsTr("Install Bottles")
                        icon.name: "download"
                        onClicked: { page.pending = { name: "Bottles", flatpak: "com.usebottles.bottles" }; confirm.open() }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        visible: row.ans && row.ans.kind !== "wine" && row.ans.wine !== "no"
                        text: row.ans && row.ans.wine === "yes"
                            ? qsTr("The Windows version also runs with Wine (through Bottles).")
                            : qsTr("The Windows version may run with Wine, with problems.")
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        visible: row.ans && row.ans.winboat_blocked
                        text: qsTr("The full Windows version needs WinBoat, which this PC cannot run well.")
                    }
                    QQC2.Button {
                        visible: row.ans && row.ans.web !== ""
                        flat: row.ans && row.ans.kind !== "web"
                        text: qsTr("Open the web version")
                        icon.name: "internet-services"
                        onClicked: Qt.openUrlExternally(row.ans.web)
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        visible: !!row.modelData.uncertain
                        color: Kirigami.Theme.neutralTextColor
                        text: qsTr("Not fully tested; results may vary.")
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        visible: !!row.modelData.note
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        text: row.modelData.note || ""
                    }
                }
            }
        }
    }
}
