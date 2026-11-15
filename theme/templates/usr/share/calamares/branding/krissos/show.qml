// KrissOS install slideshow (Calamares slideshowAPI 2). Rendered from theme/tokens.json.
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Rectangle { anchors.fill: parent; color: "{{surface}}" }

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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 8
        Repeater {
            model: presentation.slides.length
            Rectangle {
                width: index === presentation.currentSlide ? 20 : 8; height: 8; radius: 4
                color: index === presentation.currentSlide ? "{{accent}}" : "{{muted}}"
            }
        }
    }

    function onActivate() { presentation.currentSlide = 0 }
    function onLeave() {}
}
