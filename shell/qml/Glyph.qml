import QtQuick
import QtQuick.Shapes

// Line icons drawn in the shell's own colours, so they tint cleanly in both themes
// (symbolic icons from the icon theme are fixed to one colour).
Item {
    id: root

    property string name
    property color color: Theme.fg
    property real size: 20
    property real stroke: 2

    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        wifi: "M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19h.01",
        wifiOff: "M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19h.01M3 3l18 18",
        wired: "M4 5h16v9H4zM8 14v3h8v-3M12 17v3",
        volume: "M4 9h4l5-4v14l-5-4H4zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12",
        mute: "M4 9h4l5-4v14l-5-4H4zM17 9l5 6M22 9l-5 6",
        bell: "M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 20a2 2 0 0 0 4 0",
        bellOff: "M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 20a2 2 0 0 0 4 0M3 3l18 18",
        bluetooth: "M7 7l10 10-5 5V2l5 5L7 17",
        mic: "M9 5a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0zM5 11a7 7 0 0 0 14 0M12 18v3",
        micOff: "M9 5a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0zM5 11a7 7 0 0 0 14 0M12 18v3M3 3l18 18",
        sun: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0-8 0M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
        check: "M5 12l5 5 9-10",
        power: "M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0",
        search: "M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M20 20l-4-4",
        balanced: "M4 16a8 8 0 1 1 16 0M12 16l4-5",
        performance: "M13 2L4 14h7l-1 8 9-12h-7z",
        saver: "M5 19c0-8 5-14 15-14 0 10-6 15-14 15M5 19l7-7",
        close: "M6 6l12 12M18 6L6 18",
        lock: "M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4",
        sleep: "M20 14a8 8 0 1 1-10-10 6 6 0 0 0 10 10z",
        restart: "M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5",
        signout: "M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10",
        file: "M6 3h8l4 4v14H6zM14 3v4h4",
        chevron: "M9 6l6 6-6 6",
        down: "M7 10l5 5 5-5",
        up: "M7 14l5-5 5 5",
        back: "M15 6l-6 6 6 6",
        play: "M7 4.5v15l12-7.5z",
        pause: "M8 5v14M16 5v14",
        next: "M5 5l10 7-10 7zM19 5v14",
        prev: "M19 5L9 12l10 7zM5 5v14",
        music: "M9 18V5l11-2v13M6 18a3 3 0 1 0 6 0a3 3 0 1 0-6 0M17 16a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
        charging: "M13 2L4 14h7l-1 8 9-12h-7z"
    })

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke * 24 / root.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.paths[root.name] ?? "" }
        }
    }
}
