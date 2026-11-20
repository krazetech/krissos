import QtQuick
import QtQuick.Effects
import Quickshell

// The time-of-day wallpaper: the Sungai Petani clock tower by day and by night (the photo
// pair kriss-theme ships), blended by the clock like macOS's Dynamic Desktop. The blend
// moves once a minute, about 1 % a step, so it never visibly jumps, and nothing redraws in
// between or while the light holds (all day, all night).
Item {
    id: root

    // The time shown; tests set it.
    property date at: clock.date
    // Minutes after midnight and the light reached then; between two, the light blends.
    // ponytail: fixed hours, no sunrise tables (no location offline); move these if it
    // looks wrong far from the equator.
    readonly property var keys: [[360, "night"], [450, "day"], [1050, "day"], [1170, "night"]]
    // Loaded and drawn, so a cover over it can fade.
    readonly property bool ready: (flip ? b : a).status === Image.Ready

    // Before kriss-theme ships the photos, fall back to the plain dark wallpaper.
    property bool missing: false
    function url(name) {
        return "file://" + Theme.wallpapers + (missing ? "/kriss-dark.svg" : "/sungai-petani-" + name + ".jpg");
    }

    // [from, to, how far] at minute m.
    function blend(m) {
        const k = keys, n = k.length;
        let i = n - 1;
        while (i > 0 && m < k[i][0]) i--;
        if (m < k[0][0]) i = n - 1;
        const from = k[i], to = k[(i + 1) % n];
        const span = (to[0] - from[0] + 1440) % 1440;
        const t = ((m - from[0] + 1440) % 1440) / span;
        return [from[1], to[1], t * t * (3 - 2 * t)];  // smoothstep: slow at both ends
    }

    // Two pictures: the lower one fully shown, the upper one fading in over it. When the
    // upper one is fully in, the two swap roles, so neither ever shows half loaded.
    property bool flip: false
    property real fraction: 0
    function place() {
        const now = blend(at.getHours() * 60 + at.getMinutes());
        const low = flip ? b : a, high = flip ? a : b;
        const from = url(now[0]);
        const to = now[1] !== now[0] && now[2] > 0 ? url(now[1]) : "";
        if (String(high.source) === from && String(low.source) !== from) {
            flip = !flip;
            return place();
        }
        low.source = from;
        high.source = to;
        fraction = to ? now[2] : 0;
    }
    onAtChanged: place()
    onMissingChanged: place()
    Component.onCompleted: place()

    SystemClock { id: clock; precision: SystemClock.Minutes }

    component Light: Image {
        anchors.fill: parent
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: opacity > 0 && source != ""
        onStatusChanged: if (status === Image.Error) root.missing = true
    }
    Light { id: a; z: root.flip ? 1 : 0; opacity: root.flip ? root.fraction : 1 }
    Light { id: b; z: root.flip ? 0 : 1; opacity: root.flip ? 1 : root.fraction }

    // The tower's two clocks tell the time shown. The photos have their own hands painted
    // out (theme/photos/erase-hands.py); these are drawn back in the photo's own style:
    // thick tapered hands on a big hub, in the dial ring's ink, softened by the photo's blur.
    // [hub x, hub y, disc rx, disc ry] in the 3840x2160 photo. The left face is seen at an
    // angle, so its circle squashes to an ellipse; ponytail: no skew, it reads fine at this size.
    readonly property var dials: [[1049, 1456, 23, 49], [1427, 1436, 41, 48]]
    // Where PreserveAspectCrop puts the photo: scale and offset.
    readonly property real scale_: Math.max(width / 3840, height / 2160)
    // Only the patch around both dials is drawn and blurred: photo x 1000..1500, y 1380..1530.
    Canvas {
        id: hands
        z: 2
        visible: !root.missing
        x: (root.width - 3840 * root.scale_) / 2 + 1000 * root.scale_
        y: (root.height - 2160 * root.scale_) / 2 + 1380 * root.scale_
        width: 500 * root.scale_
        height: 150 * root.scale_
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: Math.max(3, Math.round(6 * root.scale_))  // the photo's softness
        }
        onPaint: {
            const ctx = getContext("2d"), s = root.scale_;
            ctx.resetTransform();
            ctx.clearRect(0, 0, width, height);
            const h = root.at.getHours() % 12 + root.at.getMinutes() / 60, m = root.at.getMinutes();
            ctx.fillStyle = "#0b1520";
            for (const [cx, cy, rx, ry] of root.dials) {
                // Unit circle = the dial's centre disc.
                ctx.setTransform(rx * s, 0, 0, ry * s, (cx - 1000) * s, (cy - 1380) * s);
                // [turn, length, width at the hub, width at the tip]
                for (const [turn, len, w0, w1] of [[h / 12, 0.55, 0.34, 0.2], [m / 60, 0.8, 0.26, 0.12]]) {
                    const t = turn * 2 * Math.PI, ux = Math.sin(t), uy = -Math.cos(t), px = -uy, py = ux;
                    ctx.beginPath();
                    ctx.moveTo(px * w0 / 2, py * w0 / 2);
                    ctx.lineTo(ux * len + px * w1 / 2, uy * len + py * w1 / 2);
                    ctx.lineTo(ux * len - px * w1 / 2, uy * len - py * w1 / 2);
                    ctx.lineTo(-px * w0 / 2, -py * w0 / 2);
                    ctx.closePath();
                    ctx.fill();
                }
                ctx.beginPath();
                ctx.ellipse(-0.21, -0.21, 0.42, 0.42);
                ctx.fill();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: root; function onAtChanged() { hands.requestPaint(); } }
    }
}
