import QtQuick
import Quickshell

// The lock screen's clock: big and bold, hours over minutes by default, in liquid glass over
// the wallpaper (shaders/glass.frag), with the date above it. Its look comes from `opts`
// (shell.json's lockClock, set in Personalise > Lock screen): stack, size, weight, font,
// style and date; LockFace places it. With reduced transparency or high contrast it is solid
// (outlined in high contrast); with reduced motion nothing moves.
Item {
    id: clock

    property var opts: Desktop.lockClock
    property Item backdrop        // the blurred wallpaper the glass shows, bent
    property real screenHeight: 1080
    property real screenWidth: 1920
    property date now: new Date()

    // The size, as a share of the screen's height: the whole clock for one line, about the
    // same block for two. Bigger with the text size, never wider or taller than fits.
    readonly property real share: ({ s: 0.18, m: 0.22, l: 0.26, xl: 0.32 })[opts.size] ?? 0.26
    readonly property bool stacked: opts.stack !== "line"
    readonly property int px: {
        const want = Math.min(share * screenHeight, 360 * screenHeight / 1440) * Math.max(1, Theme.textScale);
        const fit = Math.min(screenHeight * 0.42, screenWidth * (stacked ? 0.5 : 0.24));
        return Math.round(Math.min(stacked ? want * 0.62 : want, fit));
    }
    readonly property string family: ({ rounded: "Nunito", condensed: "IBM Plex Sans Condensed", serif: "Noto Serif Display" })[opts.font] ?? "Inter Display"
    readonly property int weight: ({ regular: Font.Normal, semibold: Font.DemiBold, heavy: Font.Black })[opts.weight] ?? Font.Bold
    // Glass unless asked otherwise, or when see-through surfaces are off (Theme.solid covers
    // high contrast too).
    readonly property string style: Theme.solid ? "solid" : opts.style === "solid" || opts.style === "outline" ? opts.style : "glass"
    readonly property bool glass: style === "glass"

    implicitWidth: Math.max(date.visible ? date.implicitWidth : 0, digits.width)
    implicitHeight: (date.visible ? date.implicitHeight + Theme.s1 : 0) + digits.height

    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatDateTime(now, "HH:mm") + (date.visible ? ", " + date.text : "")

    Text {
        id: date
        visible: clock.opts.date !== false
        anchors.horizontalCenter: parent.horizontalCenter
        text: clock.now.toLocaleString(Qt.locale(), "dddd, d MMMM")
        color: Theme.alpha(Theme.nightFg, 0.9)
        font { family: Theme.sans; pixelSize: Math.max(Theme.sp(16), Math.round(clock.px * (clock.stacked ? 0.13 : 0.1))); weight: Font.DemiBold }
        style: Theme.high ? Text.Outline : Text.Normal
        styleColor: "#000000"
        Accessible.ignored: true
    }

    // The digits: drawn once, as the glass's shape, or shown as they are when solid.
    Column {
        id: digits
        anchors.horizontalCenter: parent.horizontalCenter
        y: date.visible ? date.implicitHeight + Theme.s1 : 0
        spacing: -Math.round(clock.px * 0.2)  // stacked lines sit close, as on a phone
        visible: !clock.glass
        Repeater {
            model: clock.stacked ? [Qt.formatDateTime(clock.now, "HH"), Qt.formatDateTime(clock.now, "mm")]
                                 : [Qt.formatDateTime(clock.now, "HH:mm")]
            RollingText {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                rolls: !clock.glass
                // Outline: hollow digits; high contrast: solid ones with a dark edge.
                color: clock.glass ? "#ffffff" : clock.style === "outline" && !Theme.high ? "transparent" : Theme.nightFg
                style: clock.style === "outline" || Theme.high ? Text.Outline : Text.Normal
                styleColor: Theme.high ? "#000000" : Theme.nightFg
                font { family: clock.family; pixelSize: clock.px; weight: clock.weight }
                Accessible.ignored: true
            }
        }
    }
    // The glass: the digits' shape over the wallpaper behind them. A change inside the hidden
    // digits alone doesn't make the screen draw a frame, so a screen nobody touched kept the
    // old shape ("00 00" after sleep) until the pointer moved over it. Ask for the frame.
    onNowChanged: if (glass) { shapeSource.scheduleUpdate(); behindSource.scheduleUpdate(); Window.window?.update(); }
    ShaderEffectSource {
        id: shapeSource
        sourceItem: clock.glass ? digits : null
        hideSource: true
        mipmap: true
        visible: false
    }
    ShaderEffectSource {
        id: behindSource
        sourceItem: clock.glass ? clock.backdrop : null
        // Only what is behind the digits; it redraws only when the wallpaper does.
        sourceRect: {
            if (!clock.backdrop) return Qt.rect(0, 0, 0, 0);
            const p = digits.mapToItem(clock.backdrop, 0, 0);
            return Qt.rect(p.x, p.y, digits.width, digits.height);
        }
        mipmap: true
        visible: false
    }
    ShaderEffect {
        visible: clock.glass && clock.backdrop !== null
        x: digits.x
        y: digits.y
        width: digits.width
        height: digits.height
        property var shape: shapeSource
        property var backdrop: behindSource
        property size pixel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
        property real bend: Math.round(clock.px * 0.05)
        property real halo: 1  // the shader keeps it for light wallpapers
        fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
    }
}
