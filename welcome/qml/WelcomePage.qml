// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing * 2

        RowLayout {
            spacing: Kirigami.Units.largeSpacing * 2
            Image {
                source: logo
                sourceSize.width: Kirigami.Units.gridUnit * 4
                sourceSize.height: Kirigami.Units.gridUnit * 4
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                text: qsTr("Welcome to KrissOS")
                wrapMode: Text.WordWrap
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Coming from Windows? Start here. Check that your games run, then find a home for each of your apps.")
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button {
                text: qsTr("Check my games")
                icon.name: "input-gaming"
                highlighted: true
                onClicked: root.showPage(1)
            }
            QQC2.Button {
                text: qsTr("Bring my apps")
                icon.name: "system-software-install"
                onClicked: root.showPage(2)
            }
            QQC2.Button {
                text: qsTr("Copy my files")
                icon.name: "folder-download"
                onClicked: root.showPage(3)
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.ComboBox {
                Kirigami.FormData.label: qsTr("Language:")
                model: ["English", "Bahasa Melayu"]
                currentIndex: backend.language === "ms" ? 1 : 0
                onActivated: index => backend.setLanguage(index === 1 ? "ms" : "en")
            }
            QQC2.Label {
                Kirigami.FormData.label: qsTr("This PC:")
                text: qsTr("%1 GB RAM · %2 CPU threads · graphics: %3")
                    .arg(Math.round(backend.hw.ram_mb / 1024))
                    .arg(backend.hw.cores)
                    .arg(backend.hw.gpus.length ? backend.hw.gpus.join(", ") : qsTr("unknown"))
            }
            QQC2.Label {
                Kirigami.FormData.label: qsTr("Windows apps:")
                text: backend.hw.winboat_ok ? qsTr("This PC can run Windows apps in WinBoat")
                                            : qsTr("Linux apps and Wine (WinBoat needs a stronger PC)")
            }
        }
    }
}
