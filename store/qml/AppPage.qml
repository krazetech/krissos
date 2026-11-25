// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One app: what it is, a screenshot, Install or Open, and Uninstall.
Kirigami.ScrollablePage {
    id: page
    property var app: ({})
    title: app.name || ""
    readonly property bool installed: backend.installed.indexOf(app.id) >= 0

    Kirigami.PromptDialog {
        id: confirm
        title: qsTr("Uninstall %1?").arg(page.app.name || "")
        subtitle: qsTr("Its settings stay in your home folder. A snapshot is taken first, so you can undo this from the boot menu.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: backend.remove(page.app.id)
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            spacing: Kirigami.Units.gridUnit
            Kirigami.Icon {
                source: page.app.icon || "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.enormous
                Layout.preferredHeight: Kirigami.Units.iconSizes.enormous
            }
            ColumnLayout {
                Layout.fillWidth: true
                Kirigami.Heading {
                    Layout.fillWidth: true
                    text: page.app.name || ""
                    wrapMode: Text.WordWrap
                }
                QQC2.Label {
                    visible: !!page.app.dev
                    text: page.app.dev || ""
                    opacity: 0.7
                }
                QQC2.Label {
                    text: page.app.kind === "pacman" ? qsTr("From KrissOS")
                        : page.app.kind === "winapps" ? qsTr("Downloaded from Microsoft · runs in WinPodX")
                        : qsTr("From Flathub · runs in a sandbox")
                    opacity: 0.7
                }
                RowLayout {
                    AppButton { app: page.app }
                    QQC2.Button {
                        visible: page.installed && backend.canRemove(page.app.id)
                        text: qsTr("Uninstall")
                        icon.name: "edit-delete"
                        enabled: Object.keys(backend.busy).length === 0
                        onClicked: confirm.open()
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: page.app.summary || ""
            wrapMode: Text.WordWrap
            font.bold: true
        }

        Image {
            id: shot
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.preferredHeight: status === Image.Ready ? width * sourceSize.height / Math.max(1, sourceSize.width) : 0
            visible: status === Image.Ready
            source: page.app.shot || ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: page.app.desc || ""
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }
}
