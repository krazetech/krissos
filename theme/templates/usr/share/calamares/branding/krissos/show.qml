// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
// KrissOS install slideshow (Calamares slideshowAPI 2). Rendered from theme/tokens.json.
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    // A raised card on the window, with a soft accent glow in its corner, like the shell's
    // panels over the wallpaper.
    Rectangle { anchors.fill: parent; color: "{{ui_win}}" }
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4
        radius: 22
        color: "{{ui_card}}"
        border.width: 1
        border.color: "{{ui_line}}"
        clip: true
        Repeater {
            model: 4
            Rectangle {
                width: 520 - index * 110; height: width; radius: width / 2
                x: card.width - width / 2 - 60; y: -width / 2 + 40
                color: "{{accent}}"; opacity: 0.05
            }
        }
        Text {
            x: 48; y: 32
            text: (presentation.currentSlide + 1 < 10 ? "0" : "") + (presentation.currentSlide + 1) + " / 0" + presentation.slides.length
            color: "{{ui_soft}}"; font.family: "{{font_mono}}"; font.pixelSize: 13
        }
    }

    Timer {
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Page {
        heading: "Welcome to KrissOS"
        body: "Sit back while KrissOS installs. It usually takes a few minutes, and you can keep using this live session meanwhile."
        headingMs: "Selamat datang ke KrissOS"
        bodyMs: "Berehat sementara KrissOS dipasang. Biasanya ia mengambil masa beberapa minit, dan anda boleh terus menggunakan sesi langsung ini."
    }
    Page {
        heading: "It will feel familiar"
        body: "The taskbar sits at the bottom, the Windows key opens the menu, and the close button is top right."
        headingMs: "Anda akan rasa biasa"
        bodyMs: "Bar tugas di bawah, kekunci Windows membuka menu, dan butang tutup di kanan atas."
    }
    Page {
        heading: "Bring your apps"
        body: "Discover is your app store. On first login, KrissOS Welcome shows what replaces each Windows app you use."
        headingMs: "Bawa aplikasi anda"
        bodyMs: "Discover ialah gedung aplikasi anda. Pada log masuk pertama, KrissOS Welcome menunjukkan pengganti bagi setiap aplikasi Windows yang anda guna."
    }
    Page {
        heading: "Ready for games"
        body: "Steam and Proton run most Windows games. Check yours, including anti-cheat, in KrissOS Welcome."
        headingMs: "Sedia untuk permainan"
        bodyMs: "Steam dan Proton boleh menjalankan kebanyakan permainan Windows. Semak permainan anda, termasuk anti-cheat, dalam KrissOS Welcome."
    }
    Page {
        heading: "Updates you can undo"
        body: "Every update takes a snapshot first. If something breaks, pick the snapshot from the boot menu."
        headingMs: "Kemas kini yang boleh diundur"
        bodyMs: "Setiap kemas kini mengambil snapshot dahulu. Jika ada masalah, pilih snapshot itu dari menu but."
    }

    Row {
        x: 52
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
        spacing: 8
        Repeater {
            model: presentation.slides.length
            Rectangle {
                width: index === presentation.currentSlide ? 24 : 8; height: 8; radius: 4
                color: index === presentation.currentSlide ? "{{accent}}" : "{{ui_line}}"
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 220 } }
            }
        }
    }

    function onActivate() { presentation.currentSlide = 0 }
    function onLeave() {}
}
