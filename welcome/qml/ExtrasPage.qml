import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    // extra id -> "installing" | "installed" | "failed"
    property var installs: ({})
    property var pending: null

    readonly property var extras: [
        // Only for NVIDIA GPUs older than Turing, which the installer leaves on nouveau.
        { id: "nvidia-legacy", icon: "video-display", show: backend.hw.nvidia_legacy === true,
          name: qsTr("Install the NVIDIA 580 driver (needs internet)"),
          ask: qsTr("Install the NVIDIA 580 driver?"),
          text: qsTr("Your NVIDIA graphics card is older than the GeForce 16 series, so it uses the open nouveau driver. NVIDIA's own 580 driver is faster for games. NVIDIA keeps it in long-term maintenance: it gets fixes but no new features. If you skip this, nouveau stays and everything keeps working. On laptops, the screen stays on the built-in graphics; start an app with prime-run to use the NVIDIA card. The NVIDIA card may not switch fully off with this driver, so the battery can run down faster. Restart after it installs.") },
        { id: "codecs", icon: "applications-multimedia", name: qsTr("Video and music codecs"),
          text: qsTr("Play MP4, MKV, MP3, AAC and other common formats in every app.") },
        { id: "printers", icon: "printer", name: qsTr("Printers"),
          text: qsTr("Printing support, plus a tool to add your printer. Most printers from the last ten years work without a driver.") },
        { id: "gaming", icon: "input-gaming", name: qsTr("Gaming pack"),
          text: qsTr("Steam, GameMode, Gamescope, MangoHud and the latest graphics drivers.") },
        { id: "ollama", icon: "dialog-scripts", name: qsTr("Local AI (Ollama)"),
          text: qsTr("Run AI models on this PC, using your graphics card when it can. Nothing leaves your computer.") },
        { id: "ai-clis", icon: "utilities-terminal", name: qsTr("Codex CLI and Gemini CLI"),
          text: qsTr("AI coding assistants for the terminal, from OpenAI and Google.") },
        { id: "claude-code", icon: "utilities-terminal", name: qsTr("Claude Code"),
          text: qsTr("Anthropic's AI coding assistant for the terminal. Installs for your user only, so no password is needed.") },
        // ponytail: links out until Antigravity is packaged.
        { id: "antigravity", icon: "internet-services", name: qsTr("Antigravity"),
          text: qsTr("Google's AI code editor. Download it from its website."), url: "https://antigravity.google/download" }
    ]

    function setInstall(id, state) {
        const m = Object.assign({}, installs)
        m[id] = state
        installs = m
    }

    Component.onCompleted: {
        const m = {}
        for (const e of extras)
            if (!e.url && backend.extraInstalled(e.id)) m[e.id] = "installed"
        installs = m
    }

    Connections {
        target: backend
        function onInstallDone(id, ok) { page.setInstall(id, ok ? "installed" : "failed") }
    }

    Kirigami.PromptDialog {
        id: confirm
        title: page.pending ? page.pending.ask || qsTr("Install %1?").arg(page.pending.name) : ""
        subtitle: page.pending ? qsTr("You may be asked for your password.\n\nRuns: %1").arg(backend.extraCommand(page.pending.id)) : ""
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: { page.setInstall(page.pending.id, "installing"); backend.installExtra(page.pending.id) }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Repeater {
            model: page.extras.filter(e => e.show !== false)
            delegate: Kirigami.AbstractCard {
                required property var modelData
                readonly property string installState: page.installs[modelData.id] || ""
                Layout.fillWidth: true
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: modelData.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        QQC2.Label { Layout.fillWidth: true; font.bold: true; text: modelData.name }
                        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: modelData.text }
                    }
                    QQC2.Button {
                        text: modelData.url ? qsTr("Website")
                            : installState === "installing" ? qsTr("Installing…")
                            : installState === "installed" ? qsTr("Installed")
                            : !backend.online ? qsTr("Needs internet")
                            : installState === "failed" ? qsTr("Failed, try again") : qsTr("Install")
                        icon.name: modelData.url ? "internet-services"
                            : !backend.online && !installState ? "network-offline" : "download"
                        // Offline is not an error: every extra is optional, so it just waits.
                        enabled: installState !== "installing" && installState !== "installed"
                            && (backend.online || !!modelData.url)
                        onClicked: {
                            if (modelData.url) return Qt.openUrlExternally(modelData.url)
                            page.pending = modelData
                            confirm.open()
                        }
                    }
                }
            }
        }
    }
}
