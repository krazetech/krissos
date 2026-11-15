import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// The launcher, laid out like the Windows Start menu so people coming from Windows
// find their way: search on top, Pinned (or All apps), Recommended files, then the
// account and power at the bottom. Typing searches straight away.
PanelWindow {
    id: win

    visible: Desktop.launcherOpen
    screen: Desktop.screen

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "kriss-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Cover the screen above the bar, so a click anywhere else closes the menu.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: panel; radius: panel.radius }

    property string query: ""
    property bool allApps: false
    property bool powerMenu: false
    property int current: 0

    readonly property var everything: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (!q) return allApps ? everything : Desktop.pinnedEntries();
        const hit = e => [e.name, e.genericName, ...e.keywords].some(s => s && s.toLowerCase().includes(q));
        const starts = e => e.name.toLowerCase().startsWith(q);
        return everything.filter(hit).sort((a, b) => starts(b) - starts(a)).slice(0, 18);
    }

    function close() { Desktop.launcherOpen = false; }
    function launch(entry) { entry.execute(); close(); }

    onVisibleChanged: {
        if (!visible) return;
        query = ""; allApps = false; powerMenu = false; current = 0;
        search.text = "";
        search.forceActiveFocus();
        recentFile.reload();
    }
    onShownChanged: current = 0

    // Recently used files, from the list GTK and most other apps keep.
    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        printErrors: false
    }

    readonly property var recent: {
        const text = recentFile.text() ?? "";
        const out = [];
        const re = /<bookmark\s[^>]*href="([^"]+)"[^>]*modified="([^"]+)"/g;
        let m;
        while ((m = re.exec(text)) !== null) out.push({ href: m[1], when: new Date(m[2]) });
        // ponytail: regex over the XBEL file; fine for the few hundred entries it holds.
        return out.sort((a, b) => b.when - a.when).slice(0, 4);
    }

    function ago(d) {
        const min = Math.round((Date.now() - d) / 60000);
        if (min < 1) return Tr.t("Just now");
        if (min < 60) return Tr.t("%1 min ago", min);
        const today = new Date(); today.setHours(0, 0, 0, 0);
        if (d >= today) return Tr.t("Today at %1", Qt.formatTime(d, "HH:mm"));
        if (d >= today - 86400000) return Tr.t("Yesterday at %1", Qt.formatTime(d, "HH:mm"));
        return d.toLocaleString(Qt.locale(), "d MMM");
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.gap * 1.5
        anchors.bottomMargin: Theme.gap
        width: 600
        height: body.implicitHeight + body.anchors.topMargin + body.anchors.bottomMargin + foot.height
        radius: Theme.radius + 4
        color: Theme.bar
        border.width: 1
        border.color: Theme.rim
        clip: true

        opacity: win.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        MouseArea { anchors.fill: parent; onClicked: win.powerMenu = false }

        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 22
            anchors.topMargin: 22
            anchors.bottomMargin: 14
            spacing: 14

            // Search.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 0
                implicitHeight: 46
                radius: height / 2
                color: Theme.card
                border.width: 2
                border.color: Theme.accent
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10
                    Glyph { name: "search"; size: 18; color: Theme.soft }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font { family: Theme.sans; pixelSize: 15; weight: Font.Medium }
                        onTextChanged: win.query = text
                        Text {
                            visible: !search.text
                            text: Tr.t("Search for apps, settings and files")
                            color: Theme.soft
                            font: search.font
                        }
                        Keys.onEscapePressed: win.close()
                        Keys.onReturnPressed: if (win.shown[win.current]) win.launch(win.shown[win.current])
                        Keys.onLeftPressed: win.current = Math.max(0, win.current - 1)
                        Keys.onRightPressed: win.current = Math.min(win.shown.length - 1, win.current + 1)
                        Keys.onUpPressed: win.current = Math.max(0, win.current - grid.columns)
                        Keys.onDownPressed: win.current = Math.min(win.shown.length - 1, win.current + grid.columns)
                    }
                }
            }

            // Pinned / All apps / Best match header.
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: win.query ? Tr.t("Best match") : win.allApps ? Tr.t("All apps") : Tr.t("Pinned")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold }
                }
                Chip {
                    visible: !win.query
                    label: win.allApps ? Tr.t("Back") : Tr.t("All apps")
                    glyph: win.allApps ? "back" : "chevron"
                    onClicked: win.allApps = !win.allApps
                }
            }

            GridView {
                id: grid
                readonly property int columns: 6
                Layout.fillWidth: true
                visible: win.shown.length > 0
                Layout.preferredHeight: Math.min(win.allApps ? 4 : 3, Math.ceil(win.shown.length / columns)) * cellHeight
                cellWidth: width / columns
                cellHeight: 92
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.shown
                currentIndex: win.current

                delegate: MouseArea {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) return win.launch(modelData);
                        const id = modelData.id;
                        appMenu.show(cell, [
                            [Tr.t("Open"), () => win.launch(modelData)],
                            [Desktop.isPinned(id) ? Tr.t("Unpin from taskbar") : Tr.t("Pin to taskbar"), () => Desktop.togglePin(id)]
                        ]);
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSmall
                        color: cell.containsMouse || cell.index === win.current && win.query ? Theme.card : "transparent"
                        border.width: cell.index === win.current && win.query ? 2 : 0
                        border.color: Theme.accent
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 50; height: 50; radius: 14
                            color: cell.containsMouse ? Theme.win : Theme.card
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 32
                                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: grid.cellWidth - 8
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: cell.modelData.name
                            color: Theme.fg
                            font { family: Theme.sans; pixelSize: 12; weight: Font.Medium }
                        }
                    }
                }
            }

            Text {
                visible: win.shown.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: win.query ? Tr.t("No apps match that search.") : Tr.t("Right-click an app to pin it.")
                color: Theme.soft
                font { family: Theme.sans; pixelSize: 14 }
            }

            // Recommended files.
            RowLayout {
                visible: !win.query && !win.allApps
                Layout.fillWidth: true
                Layout.topMargin: 4
                Text {
                    Layout.fillWidth: true
                    text: Tr.t("Recommended")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 15; weight: Font.DemiBold }
                }
            }

            GridLayout {
                visible: !win.query && !win.allApps
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 2

                Repeater {
                    model: win.recent
                    delegate: MouseArea {
                        id: rec
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 52
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Qt.openUrlExternally(modelData.href); win.close(); }

                        Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: rec.containsMouse ? Theme.card : "transparent" }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12
                            Rectangle {
                                implicitWidth: 36; implicitHeight: 36; radius: 10
                                color: Theme.card
                                Glyph { anchors.centerIn: parent; name: "file"; size: 18; color: Theme.accent }
                            }
                            Column {
                                Layout.fillWidth: true
                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: decodeURIComponent(rec.modelData.href.split("/").pop())
                                    color: Theme.fg
                                    font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
                                }
                                Text {
                                    text: win.ago(rec.modelData.when)
                                    color: Theme.soft
                                    font { family: Theme.sans; pixelSize: 11 }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: win.recent.length === 0
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    verticalAlignment: Text.AlignVCenter
                    text: Tr.t("Files you open will show up here.")
                    color: Theme.soft
                    font { family: Theme.sans; pixelSize: 13 }
                }
            }
        }

        // Account and power.
        Rectangle {
            id: foot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 64
            color: "transparent"
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.line }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase()
                        color: Theme.accentInk
                        font { family: Theme.sans; pixelSize: 15; weight: Font.Bold }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Quickshell.env("USER") ?? ""
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
                }
            }

            MouseArea {
                id: powerBtn
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.powerMenu = !win.powerMenu
                Rectangle { anchors.fill: parent; radius: 19; color: powerBtn.containsMouse || win.powerMenu ? Theme.card : "transparent" }
                Glyph { anchors.centerIn: parent; name: "power"; size: 19 }
            }
        }

        // Power menu, above the power button.
        Rectangle {
            visible: win.powerMenu
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: foot.top
            anchors.bottomMargin: -4
            width: 190
            height: menu.implicitHeight + 12
            radius: Theme.radiusSmall + 2
            color: Theme.card
            border.width: 1
            border.color: Theme.line

            Column {
                id: menu
                anchors.centerIn: parent
                width: parent.width - 12
                Repeater {
                    model: [
                        ["lock", Tr.t("Lock"), () => { win.close(); Desktop.locked = true; }],
                        ["sleep", Tr.t("Sleep"), () => { win.close(); Quickshell.execDetached(["systemctl", "suspend"]); }],
                        ["restart", Tr.t("Restart"), () => Quickshell.execDetached(["systemctl", "reboot"])],
                        ["power", Tr.t("Shut down"), () => Quickshell.execDetached(["systemctl", "poweroff"])],
                        // Quitting the shell cleanly ends the session (see kriss-shell).
                        ["signout", Tr.t("Sign out"), () => Qt.quit()]
                    ]
                    delegate: MouseArea {
                        id: item
                        required property var modelData
                        width: menu.width
                        height: 38
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData[2]()
                        Rectangle { anchors.fill: parent; radius: 10; color: item.containsMouse ? Theme.win : "transparent" }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Glyph { name: item.modelData[0]; size: 17 }
                            Text {
                                text: item.modelData[1]
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: 14; weight: Font.Medium }
                            }
                        }
                    }
                }
            }
        }
    }

    Menu { id: appMenu }

    component Chip: MouseArea {
        id: chip
        property string label
        property string glyph
        implicitWidth: chipRow.implicitWidth + 22
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle { anchors.fill: parent; radius: 15; color: chip.containsMouse ? Theme.win : Theme.card }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            Text {
                text: chip.label
                color: Theme.fg
                font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
            }
            Glyph { anchors.verticalCenter: parent.verticalCenter; name: chip.glyph; size: 14 }
        }
    }
}
