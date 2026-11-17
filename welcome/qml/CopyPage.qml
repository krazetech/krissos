// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page
    property var partitions: backend.windowsPartitions()
    property string busy: ""        // device being opened
    property string root: ""        // where Windows is mounted
    property string error: ""
    property var users: []
    property string stage: "pick"   // pick, choose, copying, done
    property real done: 0
    property real total: 0
    property string file: ""
    property var result: null

    function sizeLabel(bytes) { return qsTr("%1 GB").arg((bytes / 1e9).toFixed(1)) }
    function folderLabel(f) {
        return { Desktop: qsTr("Desktop"), Documents: qsTr("Documents"), Pictures: qsTr("Pictures"),
                 Music: qsTr("Music"), Videos: qsTr("Videos") }[f]
    }

    Connections {
        target: backend
        function onWindowsMounted(where, err) {
            page.busy = ""
            page.error = err
            if (!where) return
            page.root = where
            page.users = backend.windowsUsers(where)
            page.stage = "choose"
        }
        function onCopyProgress(done, total, file) { page.done = done; page.total = total; page.file = file }
        function onCopyDone(copied, failed, bookmarks) {
            page.result = { copied: copied, failed: failed, bookmarks: bookmarks }
            page.stage = "done"
        }
    }

    header: Kirigami.InlineMessage {
        visible: true
        position: Kirigami.InlineMessage.Position.Header
        text: qsTr("KrissOS opens Windows read-only, so nothing on Windows changes. Files you already have here are kept, never replaced.")
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // 1. Pick the Windows partition
        Kirigami.PlaceholderMessage {
            visible: page.stage === "pick" && page.partitions.length === 0
            Layout.fillWidth: true
            icon.name: "drive-harddisk"
            text: qsTr("No Windows found on this PC")
            explanation: qsTr("Copy from Windows works when Windows is installed next to KrissOS. You can still copy files from a USB drive in the file manager.")
        }
        Repeater {
            model: page.stage === "pick" ? page.partitions : []
            delegate: Kirigami.AbstractCard {
                required property var modelData
                Layout.fillWidth: true
                contentItem: RowLayout {
                    Kirigami.Icon {
                        source: modelData.bitlocker ? "object-locked" : "drive-harddisk"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        QQC2.Label {
                            Layout.fillWidth: true
                            font.bold: true
                            text: (modelData.label || qsTr("Windows")) + " · " + page.sizeLabel(modelData.size)
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: modelData.bitlocker
                                ? qsTr("This drive is locked with BitLocker, so KrissOS cannot read it. To copy from it, start Windows and turn off BitLocker (Settings, Privacy and security, Device encryption), or copy your files to a USB drive from Windows.")
                                : modelData.path
                        }
                    }
                    QQC2.Button {
                        visible: !modelData.bitlocker
                        text: page.busy === modelData.path ? qsTr("Opening…") : qsTr("Open")
                        icon.name: "document-open-folder"
                        highlighted: true
                        enabled: page.busy === ""
                        onClicked: { page.busy = modelData.path; backend.mountWindows(modelData.path, modelData.mountpoint) }
                    }
                }
            }
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.error !== ""
            type: Kirigami.MessageType.Error
            text: qsTr("Windows could not be opened. If Windows uses Fast Startup, start Windows, hold Shift while you choose Shut down, then try again.") + "\n" + page.error
        }

        // 2. Choose what to copy
        Kirigami.FormLayout {
            visible: page.stage === "choose"
            Layout.fillWidth: true
            QQC2.ComboBox {
                id: user
                Kirigami.FormData.label: qsTr("Windows user:")
                model: page.users
            }
            ColumnLayout {
                Kirigami.FormData.label: qsTr("Copy:")
                Repeater {
                    id: folders
                    model: ["Desktop", "Documents", "Pictures", "Music", "Videos"]
                    delegate: QQC2.CheckBox {
                        required property string modelData
                        text: page.folderLabel(modelData)
                        checked: true
                    }
                }
            }
            QQC2.CheckBox {
                id: bookmarks
                text: qsTr("Edge and Chrome bookmarks")
                checked: true
            }
            QQC2.Button {
                text: qsTr("Copy to KrissOS")
                icon.name: "edit-copy"
                highlighted: true
                enabled: page.users.length > 0
                onClicked: {
                    const picked = []
                    for (let i = 0; i < folders.count; i++)
                        if (folders.itemAt(i).checked) picked.push(folders.itemAt(i).modelData)
                    page.stage = "copying"
                    // %1 is the browser name; the file goes in Documents.
                    backend.copyFromWindows(page.root, user.currentText, picked, bookmarks.checked, qsTr("%1 bookmarks.html"))
                }
            }
        }
        QQC2.Label {
            visible: page.stage === "choose" && page.users.length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("This drive has no Windows user folders.")
        }

        // 3. Progress
        ColumnLayout {
            visible: page.stage === "copying"
            Layout.fillWidth: true
            QQC2.Label {
                text: page.total > 0 ? qsTr("Copying… %1 of %2").arg(page.sizeLabel(page.done)).arg(page.sizeLabel(page.total))
                                     : qsTr("Finding your files…")
            }
            QQC2.ProgressBar {
                Layout.fillWidth: true
                indeterminate: page.total === 0
                value: page.total > 0 ? page.done / page.total : 0
            }
            QQC2.Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                opacity: 0.7
                text: page.file
            }
        }

        // 4. Done
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.stage === "done"
            type: !page.result || page.result.failed === 0 ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning
            text: !page.result ? ""
                : page.result.failed === -1 ? qsTr("There is not enough free space here to copy these folders. Free up space or choose fewer folders.")
                : page.result.failed < 0 ? qsTr("Copying stopped because of an error. Files copied so far are kept.")
                : qsTr("Copied %1 files.").arg(page.result.copied)
                  + (page.result.failed > 0 ? " " + qsTr("%1 files could not be read and were skipped (OneDrive files that are only online cannot be copied).").arg(page.result.failed) : "")
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: page.stage === "done" && page.result && page.result.bookmarks.length > 0
            text: !page.result ? "" : qsTr("Your bookmarks are saved in %1. To add them to Firefox, open Bookmarks, Manage bookmarks, Import and Backup, Import Bookmarks from HTML.")
                .arg(page.result.bookmarks.join(", "))
        }
    }
}
