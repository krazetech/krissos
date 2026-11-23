import QtQuick
import QtQuick.Shapes

// Line icons in the app's own colours, drawn as the shell draws them (shell/qml/Glyph.qml,
// same paths), so they tint cleanly in light and dark.
Item {
    id: root
    property string name
    property color color: backend.theme.fg
    property real size: 20
    property real stroke: 2
    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        home: "M3 11l9-7 9 7M5 9.5V20h5v-6h4v6h5V9.5",
        games: "M6 8h12a4 4 0 0 1 4 4v1a4 4 0 0 1-7 2.6l-.6-.6h-4.8l-.6.6A4 4 0 0 1 2 13v-1a4 4 0 0 1 4-4zM7 10.5v3M5.5 12h3M16 11h.01M18 13h.01",
        apps: "M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z",
        folder: "M3 6a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z",
        extras: "M4 7h10M18 7h2M4 17h2M10 17h10M14 5v4M6 15v4",
        check: "M5 12l5 5 9-10",
        search: "M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M20 20l-4-4",
        globe: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18",
        update: "M12 3v12M7 10l5 5 5-5M5 20h14",
        lock: "M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4",
        drive: "M3 13l3-8h12l3 8v6H3zM3 13h18M17 16h.01",
        terminal: "M3 5h18v14H3zM7 10l3 2-3 2M12 15h4",
        music: "M9 18V5l11-2v13M6 18a3 3 0 1 0 6 0a3 3 0 1 0-6 0M17 16a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
        printer: "M7 9V3h10v6M5 9h14a2 2 0 0 1 2 2v6h-4M7 17H3v-6a2 2 0 0 1 2-2M7 14h10v7H7z",
        display: "M3 4h18v12H3zM8 20h8M12 16v4",
        ai: "M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z",
        chevron: "M9 6l6 6-6 6",
        info: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 11v5M12 8h.01",
        warn: "M12 3l10 18H2zM12 10v4M12 17h.01"
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
