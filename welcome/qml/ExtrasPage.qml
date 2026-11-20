import QtQuick
import QtQuick.Layouts

Page {
    id: page
    // extra id -> "installing" | "installed" | "failed"
    property var installs: ({})
    property var pending: null
    readonly property alias dialog: confirm  // for smoke_qml.py and screenshots
    // Local AI model name -> "pulling" | "pulled" | "failed"
    property var pulls: ({})

    readonly property var extras: [
        // Only for NVIDIA GPUs older than Turing, which the installer leaves on nouveau.
        { id: "nvidia-legacy", icon: "display", show: backend.hw.nvidia_legacy === true,
          name: qsTr("Install the NVIDIA 580 driver (needs internet)"),
          ask: qsTr("Install the NVIDIA 580 driver?"),
          text: qsTr("Your NVIDIA graphics card is older than the GeForce 16 series, so it uses the open nouveau driver. NVIDIA's own 580 driver is faster for games. NVIDIA keeps it in long-term maintenance: it gets fixes but no new features. If you skip this, nouveau stays and everything keeps working. On laptops, the screen stays on the built-in graphics; start an app with prime-run to use the NVIDIA card. This driver cannot switch an older NVIDIA card off when it is idle, as nouveau does. On our test laptop, idle power went from about 4.7 W to 6.8 W, so the battery lasts about a third less when idle (about 1.5 hours less on that laptop). Removing the nvidia-580xx-dkms and nvidia-580xx-utils packages brings nouveau back. Restart after it installs.") },
        { id: "codecs", icon: "music", name: qsTr("Video and music codecs"),
          text: qsTr("Play MP4, MKV, MP3, AAC and other common formats in every app.") },
        { id: "printers", icon: "printer", name: qsTr("Printers"),
          text: qsTr("Printing support, plus a tool to add your printer. Most printers from the last ten years work without a driver.") },
        { id: "gaming", icon: "games", name: qsTr("Gaming pack"),
          text: qsTr("Steam, GameMode, Gamescope, MangoHud and the latest graphics drivers.") },
        { id: "ollama", icon: "ai", name: qsTr("Local AI (Ollama)"),
          text: qsTr("Run AI models on this PC, using your graphics card when it can. Nothing leaves your computer.") },
        { id: "ai-clis", icon: "terminal", name: qsTr("Codex CLI and Gemini CLI"),
          text: qsTr("AI coding assistants for the terminal, from OpenAI and Google.") },
        { id: "claude-code", icon: "terminal", name: qsTr("Claude Code"),
          text: qsTr("Anthropic's AI coding assistant for the terminal. Installs for your user only, so no password is needed.") },
        // ponytail: links out until Antigravity is packaged.
        { id: "antigravity", icon: "globe", name: qsTr("Antigravity"),
          text: qsTr("Google's AI code editor. Download it from its website."), url: "https://antigravity.google/download" }
    ]

    function setInstall(id, state) {
        const m = Object.assign({}, installs)
        m[id] = state
        installs = m
    }

    function setPull(name, state) {
        const m = Object.assign({}, pulls)
        m[name] = state
        pulls = m
    }

    function gb(mb) { return Math.round(mb / 1024) }

    Component.onCompleted: {
        const m = {}
        for (const e of extras)
            if (!e.url && backend.extraInstalled(e.id)) m[e.id] = "installed"
        installs = m
        if (m.ollama) {
            const p = {}
            for (const name of backend.pulledModels()) p[name] = "pulled"
            pulls = p
        }
    }

    Connections {
        target: backend
        function onInstallDone(id, ok) {
            if (id.startsWith("pull:")) page.setPull(id.slice(5), ok ? "pulled" : "failed")
            else page.setInstall(id, ok ? "installed" : "failed")
        }
    }

    Confirm {
        id: confirm
        title: page.pending ? page.pending.ask || qsTr("Install %1?").arg(page.pending.name) : ""
        subtitle: page.pending ? qsTr("You may be asked for your password.\n\nRuns: %1").arg(backend.extraCommand(page.pending.id)) : ""
        onAccepted: { page.setInstall(page.pending.id, "installing"); backend.installExtra(page.pending.id) }
    }

    Repeater {
        model: page.extras.filter(e => e.show !== false)
        delegate: Card {
            required property var modelData
            readonly property string installState: page.installs[modelData.id] || ""
            Layout.fillWidth: true
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    width: 40; height: 40; radius: 10
                    color: Qt.tint(backend.theme.card, Qt.alpha(backend.theme.accent, 0.14))
                    Glyph { anchors.centerIn: parent; name: modelData.icon; color: backend.theme.accentText }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Txt { Layout.fillWidth: true; bold: true; text: modelData.name }
                    Txt { Layout.fillWidth: true; soft: true; text: modelData.text }
                }
                Pill {
                    Layout.alignment: Qt.AlignTop
                    text: modelData.url ? qsTr("Website")
                        : installState === "installing" ? qsTr("Installing…")
                        : installState === "installed" ? qsTr("Installed")
                        : !backend.online ? qsTr("Needs internet")
                        : installState === "failed" ? qsTr("Failed, try again") : qsTr("Install")
                    glyph: modelData.url ? "globe" : installState === "installed" ? "check" : "update"
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

            // Which AI models fit this PC. Sized from the bundled list, so it works offline.
            ColumnLayout {
                id: ai
                readonly property var fit: modelData.id === "ollama" && installState === "installed"
                    ? backend.ollamaModels() : null
                visible: !!fit
                Layout.fillWidth: true
                Layout.leftMargin: 54
                spacing: 10
                Txt {
                    Layout.fillWidth: true
                    text: !ai.fit ? ""
                        : ai.fit.gpu ? qsTr("Your graphics card has %1 GB of memory. Models that fit in it run fast.").arg(page.gb(ai.fit.memory_mb))
                        : qsTr("No graphics card memory found, so models run on the processor and share your %1 GB of RAM. Answers come slower than on a graphics card.").arg(page.gb(ai.fit.memory_mb))
                }
                Repeater {
                    model: ai.fit ? ai.fit.models : []
                    delegate: RowLayout {
                        required property var modelData
                        readonly property string pull: page.pulls[modelData.name] || ""
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Txt { Layout.fillWidth: true; bold: true; font.family: backend.theme.mono; text: modelData.name }
                            Txt {
                                Layout.fillWidth: true
                                soft: true
                                text: (modelData.kind === "coding" ? qsTr("Coding") : qsTr("General chat"))
                                    + " · " + qsTr("%1 GB download").arg(modelData.size_gb) + " · "
                                    + (modelData.fit === "fits" ? qsTr("Fits")
                                        : modelData.fit === "too_big" ? qsTr("Too big for this PC")
                                        : ai.fit.gpu ? qsTr("Tight: part of it runs on the processor, so it is slower")
                                        : qsTr("Tight: close other apps while you use it"))
                            }
                        }
                        Pill {
                            visible: modelData.fit !== "too_big" || pull === "pulled"
                            text: pull === "pulling" ? qsTr("Downloading…")
                                : pull === "pulled" ? qsTr("Downloaded")
                                : !backend.online ? qsTr("Needs internet")
                                : pull === "failed" ? qsTr("Failed, try again") : qsTr("Download")
                            glyph: pull === "pulled" ? "check" : "update"
                            enabled: pull !== "pulling" && pull !== "pulled" && backend.online
                            onClicked: { page.setPull(modelData.name, "pulling"); backend.pullModel(modelData.name) }
                        }
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    soft: true
                    text: qsTr("Downloading a model is the only step that needs internet. Then chat with it in a terminal: ollama run followed by the model name.")
                }
            }
        }
    }
}
