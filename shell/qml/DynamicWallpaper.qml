import QtQuick
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
    // out (theme/photos/erase-hands.py); these are drawn over them, once a minute.
    // [hub x, hub y, disc rx, disc ry] in the 3840x2160 photo. The left face is seen at an
    // angle, so its circle squashes to an ellipse; ponytail: no skew, it reads fine at this size.
    readonly property var dials: [[1049, 1456, 23, 49], [1427, 1436, 41, 48]]
    Canvas {
        id: hands
        anchors.fill: parent
        z: 2
        visible: !root.missing
        onPaint: {
            const ctx = getContext("2d");
            ctx.resetTransform();
            ctx.clearRect(0, 0, width, height);
            // Where PreserveAspectCrop puts the photo.
            const s = Math.max(width / 3840, height / 2160), ox = (width - 3840 * s) / 2, oy = (height - 2160 * s) / 2;
            const h = root.at.getHours() % 12 + root.at.getMinutes() / 60, m = root.at.getMinutes();
            ctx.fillStyle = ctx.strokeStyle = "#101a24";
            ctx.lineCap = "round";
            for (const [cx, cy, rx, ry] of root.dials) {
                // Unit circle = the dial's centre disc.
                ctx.setTransform(rx * s, 0, 0, ry * s, ox + cx * s, oy + cy * s);
                for (const [turn, length, width] of [[h / 12, 0.55, 0.14], [m / 60, 0.88, 0.09]]) {
                    const t = turn * 2 * Math.PI;
                    ctx.lineWidth = width;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(Math.sin(t) * length, -Math.cos(t) * length);
                    ctx.stroke();
                }
                ctx.beginPath();
                ctx.ellipse(-0.12, -0.12, 0.24, 0.24);
                ctx.fill();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: root; function onAtChanged() { hands.requestPaint(); } }
    }
}
