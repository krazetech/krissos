import QtQuick
import Quickshell

// The time-of-day wallpaper: one scene in four lights (kriss-dawn, -day, -dusk and -night,
// from theme/generate.py), blended between neighbours by the clock like macOS's Dynamic
// Desktop. The blend moves once a minute, about 1 % a step, so it never visibly jumps, and
// nothing redraws in between or while the light holds (all day, all night).
Item {
    id: root

    // The time shown; tests set it.
    property date at: clock.date
    // Minutes after midnight and the light reached then; between two, the light blends.
    // ponytail: fixed hours, no sunrise tables (no location offline); move these if it
    // looks wrong far from the equator.
    readonly property var keys: [[270, "night"], [360, "dawn"], [480, "day"], [990, "day"], [1110, "dusk"], [1230, "night"]]
    // Loaded and drawn, so a cover over it can fade.
    readonly property bool ready: (flip ? b : a).status === Image.Ready

    // Before kriss-theme ships the four lights, fall back to the plain dark wallpaper.
    property bool missing: false
    function url(name) { return "file://" + Theme.wallpapers + "/kriss-" + (missing ? "dark" : name) + ".svg"; }

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
}
