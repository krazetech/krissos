import QtQuick
import QtQuick.Layouts

Page {
    // The greeting: a card with the emblem and the three first steps.
    Card {
        Layout.fillWidth: true
        padding: 24
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            Image {
                source: logo
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                sourceSize.width: 144
                sourceSize.height: 144
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Txt {
                    Layout.fillWidth: true
                    text: qsTr("Welcome to KrissOS")
                    size: 22
                    bold: true
                }
                Txt {
                    Layout.fillWidth: true
                    soft: true
                    text: qsTr("Coming from Windows? Start here. Check that your games run, then find a home for each of your apps.")
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Pill {
                text: qsTr("Check my games")
                glyph: "games"
                highlighted: true
                onClicked: root.showPage(1)
            }
            Pill {
                text: qsTr("Bring my apps")
                glyph: "apps"
                onClicked: root.showPage(2)
            }
            Pill {
                text: qsTr("Copy my files")
                glyph: "folder"
                onClicked: root.showPage(3)
            }
        }
    }

    LayoutPicker {
        Layout.fillWidth: true
    }

    // Language and what this PC is, as label and value rows on one card.
    Card {
        Layout.fillWidth: true
        spacing: 0
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 24
            rowSpacing: 14
            Txt { soft: true; text: qsTr("Language:") }
            Select {
                Layout.preferredWidth: 240
                model: ["English", "Bahasa Melayu"]
                currentIndex: backend.language === "ms" ? 1 : 0
                onActivated: index => backend.setLanguage(index === 1 ? "ms" : "en")
            }
            Txt { soft: true; text: qsTr("This PC:") }
            Txt {
                Layout.fillWidth: true
                text: qsTr("%1 GB RAM · %2 CPU threads · graphics: %3")
                    .arg(Math.round(backend.hw.ram_mb / 1024))
                    .arg(backend.hw.cores)
                    .arg(backend.hw.gpus.length ? backend.hw.gpus.join(", ") : qsTr("unknown"))
            }
            Txt { soft: true; text: qsTr("Windows apps:") }
            Txt {
                Layout.fillWidth: true
                text: backend.hw.winboat_ok ? qsTr("This PC can run Windows apps in WinBoat")
                                            : qsTr("Linux apps and Wine (WinBoat needs a stronger PC)")
            }
        }
    }
}
