import QtQuick
import QtQuick.Layouts
import Quickshell

// What to do before KrissOS can be installed, shown by kriss-install instead of the
// installer. KRISS_NOTICE picks the page: bitlocker or bios. Colours come from
// theme/tokens.json (rendered by kriss-installer's PKGBUILD).
ShellRoot {
    id: root

    readonly property string page: Quickshell.env("KRISS_NOTICE") ?? "bitlocker"
    readonly property bool ms: {
        for (const v of ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"]) {
            const s = (Quickshell.env(v) ?? "").split(":")[0];
            if (s) return s.startsWith("ms");
        }
        return false;
    }

    readonly property var pages: ({
        bitlocker: {
            en: {
                title: "Turn off BitLocker first",
                body: "Windows on this PC is encrypted with BitLocker, so KrissOS cannot safely make room next to it. Nothing has been changed.",
                steps: [
                    "Restart into Windows.",
                    "Open Settings > Privacy & security > Device encryption (or Control Panel > BitLocker Drive Encryption) and turn encryption off. Wait until it says decryption is finished; it can take an hour.",
                    "Keep your BitLocker recovery key somewhere safe anyway (aka.ms/myrecoverykey).",
                    "Turn off Fast Startup: Control Panel > Power Options > Choose what the power buttons do.",
                    "Shut Windows down, start from this USB again and choose Install KrissOS."
                ],
                footer: "To erase the whole disk instead, including Windows and all its files, run  kriss-install --ignore-bitlocker  in a terminal."
            },
            ms: {
                title: "Matikan BitLocker dahulu",
                body: "Windows pada PC ini disulitkan dengan BitLocker, jadi KrissOS tidak dapat membuat ruang di sebelahnya dengan selamat. Tiada apa-apa yang diubah.",
                steps: [
                    "Mulakan semula ke dalam Windows.",
                    "Buka Tetapan > Privasi & keselamatan > Penyulitan peranti (atau Panel Kawalan > Penyulitan Pemacu BitLocker) dan matikan penyulitan. Tunggu sehingga penyahsulitan selesai; ia boleh mengambil masa sejam.",
                    "Simpan juga kunci pemulihan BitLocker anda di tempat yang selamat (aka.ms/myrecoverykey).",
                    "Matikan Permulaan Pantas: Panel Kawalan > Pilihan Kuasa > Pilih fungsi butang kuasa.",
                    "Tutup Windows, mulakan semula dari USB ini dan pilih Pasang KrissOS."
                ],
                footer: "Untuk memadam seluruh cakera, termasuk Windows dan semua failnya, jalankan  kriss-install --ignore-bitlocker  dalam terminal."
            }
        },
        bios: {
            en: {
                title: "Start this USB in UEFI mode",
                body: "Windows on this PC starts in UEFI mode, but the PC started this USB in legacy BIOS mode. Start the USB in UEFI mode too, so KrissOS and Windows share one boot menu. Nothing has been changed.",
                steps: [
                    "Restart and open the boot menu (often F12, F11, F8 or Esc while the PC starts).",
                    "Pick the USB entry whose name starts with UEFI.",
                    "Choose Install KrissOS."
                ],
                footer: "To install in legacy BIOS mode anyway, run  kriss-install --legacy  in a terminal. Windows will then not be in the KrissOS boot menu."
            },
            ms: {
                title: "Mulakan USB ini dalam mod UEFI",
                body: "Windows pada PC ini bermula dalam mod UEFI, tetapi PC ini memulakan USB dalam mod BIOS lama. Mulakan USB dalam mod UEFI juga, supaya KrissOS dan Windows berkongsi satu menu but. Tiada apa-apa yang diubah.",
                steps: [
                    "Mulakan semula dan buka menu but (selalunya F12, F11, F8 atau Esc semasa PC dimulakan).",
                    "Pilih entri USB yang namanya bermula dengan UEFI.",
                    "Pilih Pasang KrissOS."
                ],
                footer: "Untuk memasang dalam mod BIOS lama juga, jalankan  kriss-install --legacy  dalam terminal. Windows tidak akan ada dalam menu but KrissOS."
            }
        }
    })
    readonly property var text: (pages[page] ?? pages.bitlocker)[ms ? "ms" : "en"]

    FloatingWindow {
        title: root.text.title
        onVisibleChanged: if (!visible) Qt.quit()
        implicitWidth: 640
        implicitHeight: column.implicitHeight + 64
        color: "{{bg}}"

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 32
            spacing: 16

            Text {
                text: root.text.title
                color: "{{fg}}"
                font.family: "{{font_sans}}"
                font.pixelSize: 26
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            Text {
                text: root.text.body
                color: "{{fg}}"
                font.family: "{{font_sans}}"
                font.pixelSize: 15
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            Repeater {
                model: root.text.steps
                RowLayout {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: "{{accent}}"
                        Layout.alignment: Qt.AlignTop
                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            color: "{{bg}}"
                            font.family: "{{font_sans}}"
                            font.weight: Font.Bold
                        }
                    }
                    Text {
                        text: modelData
                        color: "{{fg}}"
                        font.family: "{{font_sans}}"
                        font.pixelSize: 15
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                }
            }
            Text {
                visible: text !== ""
                text: root.text.footer
                color: "{{fg}}"
                opacity: 0.7
                font.family: "{{font_sans}}"
                font.pixelSize: 13
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            Rectangle {
                Layout.alignment: Qt.AlignRight
                implicitWidth: close.implicitWidth + 40
                implicitHeight: 40
                radius: 20
                color: mouse.containsMouse ? Qt.lighter("{{accent}}", 1.1) : "{{accent}}"
                Text {
                    id: close
                    anchors.centerIn: parent
                    text: root.ms ? "Tutup" : "Close"
                    color: "{{bg}}"
                    font.family: "{{font_sans}}"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Qt.quit()
                }
            }
        }
    }
}
