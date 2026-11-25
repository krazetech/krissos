// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
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
        display: "M3 4h18v12H3zM8 20h8M12 16v4",
        keyboard: "M2 6h20v12H2zM6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10",
        mouse: "M7 9a5 5 0 0 1 10 0v6a5 5 0 0 1-10 0zM12 4v5",
        user: "M8 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0M4 21a8 8 0 0 1 16 0",
        users: "M6 8a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0M2 20a7.5 7.5 0 0 1 15 0M15 4.6a3.5 3.5 0 0 1 0 6.8M18.5 13.5a7.5 7.5 0 0 1 3.5 6.5",
        clock: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 7v5l3 2",
        drive: "M3 13h18v6H3zM5 13l3-8h8l3 8M7 16h.01",
        printer: "M6 9V3h12v6M6 18H4v-7h16v7h-2M6 14h12v7H6z",
        info: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 11v5M12 8h.01",
        settings: "M4 6h10M18 6h2M14 4v4M4 12h4M12 12h8M8 10v4M4 18h12M16 16v4",
        external: "M14 4h6v6M20 4l-9 9M18 14v6H4V6h6",
        shield: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z",
        power: "M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0",
        search: "M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M20 20l-4-4",
        balanced: "M4 16a8 8 0 1 1 16 0M12 16l4-5",
        performance: "M13 2L4 14h7l-1 8 9-12h-7z",
        saver: "M5 19c0-8 5-14 15-14 0 10-6 15-14 15M5 19l7-7",
        pin: "M12 17v5M9 4h6l-1 6 3 3v2H7v-2l3-3z",
        keyboard: "M3 6h18v12H3zM7 10h.01M11 10h.01M15 10h.01M17 10h.01M7 14h10",
        unpin: "M12 17v5M9 4h6l-1 6 3 3v2H7v-2l3-3zM3 3l18 18",
        close: "M6 6l12 12M18 6L6 18",
        plus: "M12 5v14M5 12h14",
        edit: "M4 20h4L19 9l-4-4L4 16zM14 6l4 4",
        taskView: "M3 9h12v11H3zM8 9V4h13v11h-6",
        taskbar: "M3 5h18v14H3zM3 15h18M7 17h.01M10 17h.01",
        window: "M3 5h18v14H3zM3 9h18M6 7h.01M9 7h.01",
        image: "M3 5h18v14H3zM3 16l5-5 5 5 3-3 5 5M15 9h.01",
        text: "M5 7V5h14v2M12 5v14M9 19h6",
        apps: "M4 4h4v4H4zM10 4h4v4h-4zM16 4h4v4h-4zM4 10h4v4H4zM10 10h4v4h-4zM16 10h4v4h-4zM4 16h4v4H4zM10 16h4v4h-4zM16 16h4v4h-4z",
        trash: "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
        lock: "M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4",
        sleep: "M20 14a8 8 0 1 1-10-10 6 6 0 0 0 10 10z",
        nightLight: "M3 18h18M7 18a5 5 0 0 1 10 0M12 7v3M5.6 11.6l1.4 1.4M18.4 11.6l-1.4 1.4M8 21h8",
        access: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 7.5h.01M7.5 10l4.5 1 4.5-1M12 11v3l-2.5 3.5M12 14l2.5 3.5",
        restart: "M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5",
        signout: "M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10",
        file: "M6 3h8l4 4v14H6zM14 3v4h4",
        folder: "M3 6a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z",
        calc: "M6 3h12v18H6zM9 7h6M9 12h.01M12 12h.01M15 12h.01M9 16h.01M12 16h.01M15 16h.01",
        terminal: "M3 5h18v14H3zM7 10l3 2-3 2M12 15h4",
        globe: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18",
        camera: "M3 8h4l2-3h6l2 3h4v11H3zM9 13a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
        update: "M12 3v12M7 10l5 5 5-5M5 20h14",
        chevron: "M9 6l6 6-6 6",
        down: "M7 10l5 5 5-5",
        up: "M7 14l5-5 5 5",
        back: "M15 6l-6 6 6 6",
        play: "M7 4.5v15l12-7.5z",
        pause: "M8 5v14M16 5v14",
        next: "M5 5l10 7-10 7zM19 5v14",
        prev: "M19 5L9 12l10 7zM5 5v14",
        music: "M9 18V5l11-2v13M6 18a3 3 0 1 0 6 0a3 3 0 1 0-6 0M17 16a3 3 0 1 0 6 0a3 3 0 1 0-6 0",
        charging: "M13 2L4 14h7l-1 8 9-12h-7z",
        clipboard: "M9 3h6v4H9zM9 5H6v16h12V5h-3",
        smile: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M8.5 14.5a4.5 4.5 0 0 0 7 0M9 9.5h.01M15 9.5h.01",
        omega: "M4 20h5v-2.5a7 7 0 1 1 6 0V20h5",
        trash: "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3",
        widgets: "M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z",
        more: "M5 12h.01M12 12h.01M19 12h.01",
        send: "M5 12h14M13 6l6 6-6 6",
        stop: "M7 7h10v10H7z",
        region: "M4 8V4h4M16 4h4v4M20 16v4h-4M8 20H4v-4",
        record: "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M8 12a4 4 0 1 0 8 0a4 4 0 1 0-8 0",
        ai: "M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z",
        cloud: "M7 18a4 4 0 0 1-.5-8 6 6 0 0 1 11.5 1.5A3.5 3.5 0 0 1 17.5 18z",
        rain: "M7 14a4 4 0 0 1-.5-8 6 6 0 0 1 11.5 1.5A3.5 3.5 0 0 1 17.5 14zM8 17l-1 3M12 17l-1 3M16 17l-1 3",
        snow: "M7 14a4 4 0 0 1-.5-8 6 6 0 0 1 11.5 1.5A3.5 3.5 0 0 1 17.5 14zM8 18h.01M12 20h.01M16 18h.01",
        storm: "M7 14a4 4 0 0 1-.5-8 6 6 0 0 1 11.5 1.5A3.5 3.5 0 0 1 17.5 14zM13 14l-3 4h4l-3 4",
        fog: "M4 9h16M4 13h16M6 17h12"
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
