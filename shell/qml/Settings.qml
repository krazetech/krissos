import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "reveal.js" as Reveal

// KrissOS Settings: the shell's own settings window, a mix of Windows 11's (sections on the
// left, cards, a breadcrumb at the top) and macOS's (grouped lists, a search that finds each
// setting, not just pages). SettingsPages.qml lists the pages; a page the shell has no page
// of its own for yet opens COSMIC Settings at it. Every change applies at once.
// Opened from Start (the gear and search), the right-click menus, `kriss-shell settings PAGE`.
FloatingWindow {
    id: win

    visible: SettingsPages.page !== ""
    title: Tr.t("Settings")
    color: Theme.win
    // Grows with the text size, like the panels.
    implicitWidth: Theme.dp(1000)
    implicitHeight: Theme.dp(700)
    minimumSize: Qt.size(Theme.dp(640), Theme.dp(460))
    // The window's close button.
    onVisibleChanged: {
        if (!visible) SettingsPages.close();
        else focusNav.restart();
    }

    // The open page (null on a section's list of pages) and its section.
    readonly property var current: SettingsPages.find(SettingsPages.page)
    readonly property string section: current ? current.group : SettingsPages.page
    readonly property int sectionIndex: Math.max(0, SettingsPages.groups.findIndex(g => g[0] === section))
    readonly property string query: searchInput.text.trim()
    readonly property var results: SettingsPages.search(query)
    onCurrentChanged: scroller.contentY = 0
    onSectionChanged: scroller.contentY = 0

    // The keyboard starts on the open section in the list on the left.
    Timer {
        id: focusNav
        interval: 0
        onTriggered: nav.itemAt(win.sectionIndex)?.forceActiveFocus()
    }

    // Kept for the controls below that call it by the window's id.
    function reveal(item) { Reveal.show(item); }

    // A setting found by search: once its page is drawn, scroll to it and light it up.
    function pointOut() {
        const key = SettingsPages.key;
        if (!key || !pageLoader.item) return;
        const hit = findText(pageLoader.item, key);
        SettingsPages.key = "";
        if (!hit) return;
        Reveal.show(hit, 48);
        const p = hit.mapToItem(scroller.contentItem, 0, 0);
        flash.x = p.x - 8; flash.y = p.y - 6; flash.width = hit.width + 16; flash.height = hit.height + 12;
        flashAnim.restart();
    }
    function findText(item, text) {
        if (!item.visible) return null;
        if (item.text === text) return item;
        for (const c of item.children) {
            const f = findText(c, text);
            if (f) return f;
        }
        return null;
    }
    Timer { id: pointLater; interval: 60; onTriggered: win.pointOut() }
    Connections {
        target: SettingsPages
        function onKeyChanged() { if (SettingsPages.key) pointLater.restart(); }
    }

    // Rebuilt lists (pins) lose the focus; the row whose key is here takes it back.
    property string again: ""

    // Pictures in the shared backgrounds and in Pictures (not screenshots), newest first, for Background and
    // Lock screen; looked for again each time either page opens.
    property var pictures: []
    function findPictures() { finder.running = true; }
    Process {
        id: finder
        command: ["sh", "-c", `
            p=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
            find /usr/share/backgrounds "$p" -maxdepth 3 -type f -not -path '*/Screenshots/*' \\( -iname '*.jpg' -o -iname '*.jpeg' \\
                -o -iname '*.png' -o -iname '*.webp' -o -iname '*.svg' \\) -printf '%T@ %p\\n' 2>/dev/null |
                sort -rn | cut -d' ' -f2- | head -40`]
        stdout: StdioCollector {
            onStreamFinished: win.pictures = text.split("\n").filter(p => p && !p.startsWith(Theme.wallpapers + "/kriss-") && !p.endsWith(".mask.png"))
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (searchInput.text) searchInput.text = "";
            else SettingsPages.close();
        }
        // Ctrl+F or typing anywhere outside a field: search, as in macOS's System Settings.
        Keys.onPressed: e => {
            if ((e.key === Qt.Key_F && e.modifiers & Qt.ControlModifier) || (e.text.length === 1 && e.text > " " && !(e.modifiers & Qt.ControlModifier))) {
                if (!(e.key === Qt.Key_F)) searchInput.text += e.text;
                searchInput.forceActiveFocus();
                e.accepted = true;
            }
        }

        // The search field and the sections.
        Rectangle {
            id: side
            width: Theme.dp(260)
            height: parent.height
            color: Theme.card
            Column {
                anchors.fill: parent
                anchors.margins: Theme.s3
                spacing: Theme.s1
                Rectangle {
                    width: parent.width
                    height: Math.max(40, Theme.sp(14) + 24)
                    radius: height / 2
                    color: Theme.win
                    border.width: searchInput.activeFocus ? Theme.focusWidth : Theme.rimWidth
                    border.color: searchInput.activeFocus ? Theme.accentText : Theme.line
                    Glyph { id: lens; name: "search"; size: 16; x: 14; anchors.verticalCenter: parent.verticalCenter; color: Theme.soft }
                    TextInput {
                        id: searchInput
                        anchors { left: lens.right; leftMargin: Theme.s2; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentInk
                        clip: true
                        font { family: Theme.sans; pixelSize: Theme.sp(14) }
                        activeFocusOnTab: true
                        Keys.onDownPressed: resultList.itemAt(0)?.forceActiveFocus()
                        Keys.onReturnPressed: if (win.results.length) SettingsPages.open(win.results[0].id, win.results[0].key), text = ""
                        Accessible.role: Accessible.EditableText
                        Accessible.name: Tr.t("Find a setting")
                        Text {
                            visible: !parent.text
                            text: Tr.t("Find a setting")
                            color: Theme.soft
                            font: parent.font
                        }
                    }
                }
                Item { width: 1; height: Theme.s2 }
                Repeater {
                    id: nav
                    model: SettingsPages.groups
                    NavRow {
                        required property var modelData
                        required property int index
                        on: !win.query && win.section === modelData[0]
                        glyph: modelData[1]
                        text: modelData[2]
                        activeFocusOnTab: on || (win.query !== "" && index === 0)
                        onPicked: { searchInput.text = ""; SettingsPages.open(modelData[0]); }
                        function go(d) {
                            const i = (win.sectionIndex + d + SettingsPages.groups.length) % SettingsPages.groups.length;
                            SettingsPages.open(SettingsPages.groups[i][0]);
                            nav.itemAt(i).forceActiveFocus();
                        }
                        Keys.onUpPressed: go(-1)
                        Keys.onDownPressed: go(1)
                    }
                }
            }
        }

        Flickable {
            id: scroller
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }
            contentHeight: body.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Where a setting found by search is.
            Rectangle {
                id: flash
                z: 2
                radius: Theme.rControl
                color: "transparent"
                border.width: 2
                border.color: Theme.accentText
                opacity: 0
                SequentialAnimation {
                    id: flashAnim
                    NumberAnimation { target: flash; property: "opacity"; to: 1; duration: Theme.ms(Theme.fast) }
                    PauseAnimation { duration: Theme.ms(1200) }
                    NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.ms(400) }
                }
            }

            Column {
                id: body
                x: 32
                y: 24
                width: Math.min(scroller.width - 64, Theme.dp(900))
                spacing: Theme.s3

                // The breadcrumb: Section › Page, the section a link back to its list.
                Row {
                    spacing: Theme.s2
                    visible: !win.query
                    MouseArea {
                        id: crumb
                        visible: win.current !== null
                        width: crumbText.implicitWidth
                        height: crumbText.implicitHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: visible
                        onClicked: SettingsPages.open(win.section)
                        Keys.onReturnPressed: clicked(null)
                        Keys.onSpacePressed: clicked(null)
                        Accessible.role: Accessible.Link
                        Accessible.name: crumbText.text
                        Accessible.onPressAction: clicked(null)
                        FocusRim { radius: Theme.rControl }
                        Text {
                            id: crumbText
                            text: SettingsPages.group(win.section)?.[2] ?? ""
                            color: crumb.containsMouse ? Theme.fg : Theme.soft
                            font { family: Theme.sans; pixelSize: Theme.sp(26); weight: Font.DemiBold }
                        }
                    }
                    Text {
                        visible: win.current !== null
                        text: "›"
                        color: Theme.soft
                        font { family: Theme.sans; pixelSize: Theme.sp(26); weight: Font.DemiBold }
                    }
                    Text {
                        text: win.current?.name ?? SettingsPages.group(win.section)?.[2] ?? ""
                        color: Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(26); weight: Font.DemiBold }
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                }

                // Search results: the pages, then the settings, each with where it is.
                Text {
                    visible: win.query !== ""
                    text: win.results.length ? Tr.t("Results for “%1”", win.query) : Tr.t("Nothing matches “%1”", win.query)
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(22); weight: Font.DemiBold }
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                SettingsUi.Card {
                    visible: win.query !== "" && win.results.length > 0
                    Repeater {
                        id: resultList
                        model: win.query ? win.results : []
                        SettingsUi.LinkRow {
                            required property var modelData
                            required property int index
                            glyph: modelData.glyph
                            text: modelData.name
                            detail: modelData.path
                            external: !!SettingsPages.find(modelData.id)?.cosmic
                            onPicked: { searchInput.text = ""; SettingsPages.open(modelData.id, modelData.key); }
                            Keys.onUpPressed: index ? resultList.itemAt(index - 1).forceActiveFocus() : searchInput.forceActiveFocus()
                            Keys.onDownPressed: resultList.itemAt(index + 1)?.forceActiveFocus()
                        }
                    }
                }

                Loader {
                    id: pageLoader
                    width: parent.width
                    visible: !win.query
                    active: win.visible
                    sourceComponent: !win.current ? sectionPage
                        : ({ users: accountPage, datetime: timePage, language: languagePage, privacy: privacyPage, updates: updatesPage, installed: installedPage, defaultapps: defaultAppsPage, startup: startupPage, wifi: wifiPage, ethernet: ethernetPage, bluetooth: bluetoothPage, mouse: mousePage, keyboard: keyboardPage, touchpad: touchpadPage, display: displayPage, sound: soundPage, notifications: notificationsPage, power: powerPage, about: aboutPage, storage: storagePage, printers: printersPage, recovery: recoveryPage, report: reportPage, colours: colours, background: background, taskbar: taskbar, pins: pins, lock: lockPage, text: textPage })[win.current.id] ?? null
                    onLoaded: if (SettingsPages.key) pointLater.restart()
                }
            }
        }
    }

    // A section: its pages, as Windows 11 lists them, each with what is on it.
    Component {
        id: sectionPage
        Column {
            spacing: Theme.s3
            SettingsUi.Card {
                Repeater {
                    model: SettingsPages.pagesIn(win.section)
                    SettingsUi.LinkRow {
                        required property var modelData
                        glyph: modelData.glyph
                        text: modelData.name
                        detail: modelData.detail
                        external: !!modelData.cosmic
                        onPicked: SettingsPages.open(modelData.id)
                    }
                }
            }
        }
    }

    Component { id: displayPage; SettingsDisplay {} }
    Component { id: accountPage; SettingsAccount {} }
    Component { id: timePage; SettingsTime {} }
    Component { id: languagePage; SettingsLanguage {} }
    Component { id: privacyPage; SettingsPrivacy {} }
    Component { id: updatesPage; SettingsUpdates {} }
    Component { id: installedPage; SettingsApps {} }
    Component { id: defaultAppsPage; SettingsDefaultApps {} }
    Component { id: startupPage; SettingsStartup {} }
    Component { id: wifiPage; SettingsWifi {} }
    Component { id: ethernetPage; SettingsEthernet {} }
    Component { id: bluetoothPage; SettingsBluetooth {} }
    Component { id: mousePage; SettingsPointer {} }
    Component { id: storagePage; SettingsStorage {} }
    Component { id: printersPage; SettingsPrinters {} }
    Component { id: keyboardPage; SettingsKeyboard {} }
    Component { id: touchpadPage; SettingsPointer { touchpad: true } }
    Component { id: soundPage; SettingsSound {} }
    Component { id: notificationsPage; SettingsNotifications {} }
    Component { id: powerPage; SettingsPower {} }
    Component { id: aboutPage; SettingsAbout {} }

    Component { id: recoveryPage; SettingsRecovery {} }
    Component { id: reportPage; SettingsReport {} }

    // Colours: the accent and light or dark.
    Component {
        id: colours
        Column {
            spacing: Theme.s3
            SettingsUi.Card {
                SettingsUi.Choice {
                    text: Tr.t("Choose your mode")
                    detail: Tr.t("Apps that follow the system switch with the shell.")
                    value: Theme.mode
                    options: [["dark", Tr.t("Dark")], ["light", Tr.t("Light")], ["system", Tr.t("Follow apps setting")], ["auto", Tr.t("By time of day")]]
                    onPicked: v => Theme.set("mode", v)
                }
                Row {
                    visible: Theme.mode === "auto"
                    spacing: Theme.s4
                    TimeField { text: Tr.t("Light from"); value: Desktop.themeLight; onEdited: v => Desktop.themeLight = v }
                    TimeField { text: Tr.t("Dark from"); value: Desktop.themeDark; onEdited: v => Desktop.themeDark = v }
                }
            }
            SettingsUi.Card {
                SettingsUi.Toggle {
                    text: Tr.t("Transparency effects")
                    detail: Tr.t("The taskbar, Start, menus and notifications show a blur of what is behind them.")
                    checked: Desktop.transparency
                    onToggled: Desktop.transparency = !Desktop.transparency
                }
            }
            SettingsUi.Card {
                SettingsUi.Label { text: Tr.t("Accent colour") }
                SettingsUi.Note { text: Theme.high ? Tr.t("High contrast uses its own colours. Your choice comes back when you turn it off.") : Tr.t("Buttons, switches and highlights use it.") }
                Flow {
                    width: parent.width
                    spacing: Theme.s2
                    Repeater {
                        model: Theme.accents
                        MouseArea {
                            id: sw
                            required property var modelData
                            readonly property bool on: Theme.chosenAccent.toLowerCase() === modelData.color.toLowerCase()
                            width: 44
                            height: 44
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            onClicked: Theme.set("accent", modelData.color)
                            Keys.onSpacePressed: clicked(null)
                            Keys.onReturnPressed: clicked(null)
                            Keys.onEnterPressed: clicked(null)
                            onActiveFocusChanged: if (activeFocus) Reveal.show(sw)
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.name
                            Accessible.description: Tr.t("Accent colour")
                            Accessible.checkable: true
                            Accessible.checked: on
                            Accessible.onPressAction: clicked(null)
                            FocusRim { anchors.margins: -3; radius: Theme.rPanel + 3 }
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.rPanel
                                color: sw.modelData.color
                                border.width: sw.on ? 3 : 0
                                border.color: Theme.fg
                                scale: sw.pressed ? Theme.pressScale : 1
                                Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                                Glyph { anchors.centerIn: parent; visible: sw.on; name: "check"; size: 18; color: Theme.night }
                            }
                        }
                    }
                }
                SettingsUi.Note { text: Theme.accents.find(a => a.color.toLowerCase() === Theme.chosenAccent.toLowerCase())?.name ?? "" }
            }
        }
    }

    // Background: the time-of-day picture, KrissOS's own, or any picture.
    Component {
        id: background
        Column {
            id: bgPage
            spacing: Theme.s3
            readonly property string wall: Desktop.wallpaper
            Component.onCompleted: win.findPictures()
            SettingsUi.Card {
                SettingsUi.Label { text: Tr.t("Background") }
                SettingsUi.Note { text: Tr.t("Sungai Petani turns from day to night with the clock. KrissOS follows light and dark.") }
                Flow {
                    width: parent.width
                    spacing: Theme.s2
                    Repeater {
                        model: [["dynamic", "Sungai Petani", Theme.wallpapers + "/sungai-petani-day.jpg"],
                                ["static", Tr.t("KrissOS"), Theme.wallpapers + "/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"]]
                            .concat((bgPage.wall.startsWith("/") && win.pictures.indexOf(bgPage.wall) < 0 ? [bgPage.wall] : []).concat(win.pictures)
                                .map(p => [p, p.slice(p.lastIndexOf("/") + 1), p]))
                        Thumb {
                            required property var modelData
                            value: modelData[0]
                            text: modelData[1]
                            path: modelData[2]
                            on: bgPage.wall === value || value === "static" && bgPage.wall !== "dynamic" && !bgPage.wall.startsWith("/")
                            onPicked: Desktop.wallpaper = value
                        }
                    }
                    Thumb {
                        text: Tr.t("Browse")
                        glyph: "folder"
                        onPicked: picker.open()
                    }
                }
            }
            FileDialog {
                id: picker
                title: Tr.t("Choose a picture")
                nameFilters: [Tr.t("Pictures") + " (*.jpg *.jpeg *.png *.webp *.svg)"]
                onAccepted: Desktop.wallpaper = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
            }
        }
    }

    // Taskbar: where it sits, how it groups, and the tray.
    Component {
        id: taskbar
        Column {
            spacing: Theme.s3
            SettingsUi.Card {
                // The two layouts, switched live (Desktop.setLayout, as kriss-welcome does).
                SettingsUi.Choice {
                    text: Tr.t("Desktop layout")
                    detail: Tr.t("The top bar and dock also put window buttons on the left, in apps that allow it.")
                    value: Desktop.layout
                    options: [["windows", Tr.t("Taskbar")], ["mac", Tr.t("Top bar and dock")]]
                    onPicked: v => Desktop.setLayout(v)
                }
            }
            SettingsUi.Card {
                SettingsUi.Choice {
                    // The dock is always centred.
                    visible: !Desktop.mac
                    text: Tr.t("Taskbar alignment")
                    value: Desktop.taskbarAlignment
                    options: [["left", Tr.t("Left")], ["centre", Tr.t("Centre")]]
                    onPicked: v => Desktop.taskbarAlignment = v
                }
                SettingsUi.Choice {
                    text: Desktop.mac ? Tr.t("Dock size") : Tr.t("Taskbar size")
                    value: Desktop.taskbarSize
                    options: [["small", Tr.t("Small")], ["medium", Tr.t("Medium")], ["large", Tr.t("Large")]]
                    onPicked: v => Desktop.taskbarSize = v
                }
                SettingsUi.Choice {
                    // The dock always combines.
                    visible: !Desktop.mac
                    text: Tr.t("Combine taskbar buttons and hide labels")
                    value: Desktop.taskbarCombine
                    options: [["always", Tr.t("Always")], ["full", Tr.t("When the taskbar is full")], ["never", Tr.t("Never")]]
                    onPicked: v => Desktop.taskbarCombine = v
                }
                SettingsUi.Choice {
                    visible: !Theme.solid
                    text: Desktop.mac ? Tr.t("Top bar transparency") : Tr.t("Taskbar transparency")
                    value: Desktop.taskbarTransparency
                    options: [["none", Tr.t("None")], ["normal", Tr.t("A little")], ["more", Tr.t("More")]]
                    onPicked: v => Desktop.taskbarTransparency = v
                }
            }
            SettingsUi.Card {
                visible: !Desktop.mac
                SettingsUi.Label { text: Tr.t("Taskbar items") }
                SettingsUi.Choice {
                    text: Tr.t("Search")
                    value: Desktop.taskbarSearch
                    options: [["hidden", Tr.t("Hide")], ["icon", Tr.t("Search icon only")], ["box", Tr.t("Search box")]]
                    onPicked: v => Desktop.taskbarSearch = v
                }
                SettingsUi.Toggle {
                    text: Tr.t("Task View button")
                    checked: Desktop.taskbarTaskView
                    onToggled: Desktop.taskbarTaskView = !Desktop.taskbarTaskView
                }
                SettingsUi.Toggle {
                    text: Tr.t("Widgets button")
                    checked: Desktop.taskbarWidgets
                    onToggled: Desktop.taskbarWidgets = !Desktop.taskbarWidgets
                }
            }
            SettingsUi.Card {
                SettingsUi.Toggle {
                    text: Tr.t("Automatically hide the taskbar")
                    detail: Tr.t("It comes back when the pointer reaches the bottom edge.")
                    checked: Desktop.taskbarAutoHide
                    onToggled: Desktop.taskbarAutoHide = !Desktop.taskbarAutoHide
                }
                SettingsUi.Toggle {
                    text: Tr.t("Show the taskbar on all screens")
                    detail: Tr.t("Off: only on the main display.")
                    checked: Desktop.taskbarAllScreens
                    onToggled: Desktop.taskbarAllScreens = !Desktop.taskbarAllScreens
                }
            }
            SettingsUi.Card {
                SettingsUi.Label { text: Tr.t("Tray icons") }
                SettingsUi.Note { text: SystemTray.items.values.length ? Tr.t("Icons that are off wait behind the arrow next to the clock.") : Tr.t("No apps have a tray icon right now.") }
                Repeater {
                    model: SystemTray.items
                    SettingsUi.Toggle {
                        required property var modelData
                        visible: modelData.id !== "Fcitx"  // shown as the input method instead
                        text: modelData.tooltipTitle || modelData.title || modelData.id
                        checked: !Desktop.isTrayHidden(modelData.id)
                        onToggled: Desktop.setTrayHidden(modelData.id, checked)
                    }
                }
            }
        }
    }

    // Pins: Start and the taskbar share one list.
    Component {
        id: pins
        Column {
            spacing: Theme.s3
            SettingsUi.Card {
                SettingsUi.Note { text: Tr.t("These apps are pinned to Start and the taskbar, in this order. Pin more from Start: right-click an app.") }
                SettingsUi.Note { visible: Desktop.pinned.length === 0; text: Tr.t("Nothing is pinned.") }
                Repeater {
                    model: Desktop.pinned
                    Item {
                        id: pin
                        required property string modelData
                        required property int index
                        readonly property var entry: { DesktopEntries.applications.values; return DesktopEntries.byId(modelData); }
                        readonly property string name: entry?.name ?? modelData
                        width: parent.width
                        height: Math.max(48, Theme.sp(14) + 28)
                        Accessible.role: Accessible.ListItem
                        Accessible.name: name
                        function move(d) {
                            const list = Desktop.pinned.slice();
                            list.splice(index, 1);
                            list.splice(index + d, 0, modelData);
                            win.again = modelData + (d < 0 ? "up" : "down");
                            Desktop.pinned = list;
                        }
                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.s2
                            Image {
                                source: Quickshell.iconPath(pin.entry?.icon ?? "", "application-x-executable")
                                sourceSize: Qt.size(28, 28)
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                            }
                            Text {
                                Layout.fillWidth: true
                                text: pin.name
                                elide: Text.ElideRight
                                color: Theme.fg
                                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
                            }
                            IconButton {
                                key: pin.modelData + "up"
                                glyph: "up"
                                text: Tr.t("Move %1 up", pin.name)
                                enabled: pin.index > 0
                                onPicked: pin.move(-1)
                            }
                            IconButton {
                                key: pin.modelData + "down"
                                glyph: "down"
                                text: Tr.t("Move %1 down", pin.name)
                                enabled: pin.index < Desktop.pinned.length - 1
                                onPicked: pin.move(1)
                            }
                            IconButton {
                                glyph: "unpin"
                                text: Tr.t("Unpin %1", pin.name)
                                onPicked: {
                                    win.again = "";
                                    Desktop.togglePin(pin.modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The lock screen's clock, with a live preview: the lock screen itself, small.
    QtObject {
        id: previewHost
        property string password: ""
        property string message: ""
        property bool checking: false
        readonly property string hint: Tr.t("Press any key to unlock")
        readonly property string verb: Tr.t("Unlock")
        readonly property string userName: Desktop.personName
        readonly property var faces: Desktop.faces
        function submit() {}
    }
    Component {
        id: lockPage
        Column {
            spacing: Theme.s3
            SettingsUi.Card {
                Item {
                    id: preview
                    width: parent.width
                    height: Math.round(width * face.height / face.width)
                    Accessible.role: Accessible.Graphic
                    Accessible.name: Tr.t("Preview of the lock screen")
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rControl
                        color: Theme.night
                        clip: true
                        Item {
                            width: Desktop.screen?.width ?? 1920
                            height: Desktop.screen?.height ?? 1080
                            scale: preview.width / width
                            transformOrigin: Item.TopLeft
                            enabled: false  // a picture: no keys, no clicks
                            LockFace { id: face; host: previewHost }
                        }
                    }
                }
                SettingsUi.Note { visible: text !== ""; text: face.depthNote }
            }
            SettingsUi.Card {
                id: lockPics
                readonly property string wall: Desktop.lockClock.wallpaper || "desktop"
                Component.onCompleted: win.findPictures()
                SettingsUi.Label { text: Tr.t("Picture") }
                Flow {
                    width: parent.width
                    spacing: Theme.s2
                    Repeater {
                        model: [["desktop", Tr.t("Same as background"), Desktop.wallpaper.startsWith("/") ? Desktop.wallpaper
                                    : Desktop.wallpaper === "dynamic" ? Theme.wallpapers + "/sungai-petani-day.jpg"
                                    : Theme.wallpapers + "/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"],
                                ["dynamic", "Sungai Petani", Theme.wallpapers + "/sungai-petani-day.jpg"],
                                ["static", Tr.t("KrissOS"), Theme.wallpapers + "/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"]]
                            .concat((lockPics.wall.startsWith("/") && win.pictures.indexOf(lockPics.wall) < 0 ? [lockPics.wall] : []).concat(win.pictures)
                                .map(p => [p, p.slice(p.lastIndexOf("/") + 1), p]))
                        Thumb {
                            required property var modelData
                            value: modelData[0]
                            text: modelData[1]
                            path: modelData[2]
                            group: Tr.t("Lock screen picture")
                            on: lockPics.wall === value
                            onPicked: Desktop.setLockClock("wallpaper", value)
                        }
                    }
                    Thumb {
                        text: Tr.t("Browse")
                        glyph: "folder"
                        onPicked: lockPicker.open()
                    }
                }
                FileDialog {
                    id: lockPicker
                    title: Tr.t("Choose a picture")
                    nameFilters: [Tr.t("Pictures") + " (*.jpg *.jpeg *.png *.webp *.svg)"]
                    onAccepted: Desktop.setLockClock("wallpaper", decodeURIComponent(String(selectedFile).replace(/^file:\/\//, "")))
                }
            }
            SettingsUi.Card {
                SettingsUi.Choice {
                    text: Tr.t("Position")
                    value: Desktop.lockClock.position
                    options: [["top", Tr.t("Top")], ["centre", Tr.t("Centre")], ["left", Tr.t("Left")], ["bottom", Tr.t("Bottom")]]
                    onPicked: v => Desktop.setLockClock("position", v)
                }
                SettingsUi.Choice {
                    text: Tr.t("Layout")
                    value: Desktop.lockClock.stack
                    options: [["stacked", Tr.t("Hours over minutes")], ["line", Tr.t("One line")]]
                    onPicked: v => Desktop.setLockClock("stack", v)
                }
                SettingsUi.Choice {
                    text: Tr.t("Size")
                    value: Desktop.lockClock.size
                    options: [["s", Tr.t("Small")], ["m", Tr.t("Medium")], ["l", Tr.t("Large")], ["xl", Tr.t("Extra large")]]
                    onPicked: v => Desktop.setLockClock("size", v)
                }
                SettingsUi.Choice {
                    text: Tr.t("Weight")
                    value: Desktop.lockClock.weight
                    options: [["regular", Tr.t("Regular")], ["semibold", Tr.t("Semibold")], ["bold", Tr.t("Bold")], ["heavy", Tr.t("Heavy")]]
                    onPicked: v => Desktop.setLockClock("weight", v)
                }
                SettingsUi.Choice {
                    text: Tr.t("Font")
                    value: Desktop.lockClock.font
                    options: [["inter-display", "Inter Display"], ["rounded", Tr.t("Rounded")], ["condensed", Tr.t("Condensed")], ["serif", Tr.t("Serif")]]
                    onPicked: v => Desktop.setLockClock("font", v)
                }
                SettingsUi.Choice {
                    text: Tr.t("Style")
                    detail: Theme.solid ? Tr.t("Glass needs transparency effects and normal contrast, so the clock is solid now.") : ""
                    value: Desktop.lockClock.style
                    options: [["glass", Tr.t("Glass")], ["solid", Tr.t("Solid")], ["outline", Tr.t("Outline")]]
                    onPicked: v => Desktop.setLockClock("style", v)
                }
            }
            SettingsUi.Card {
                SettingsUi.Toggle {
                    text: Tr.t("Date")
                    checked: Desktop.lockClock.date
                    onToggled: Desktop.setLockClock("date", !checked)
                }
                SettingsUi.Toggle {
                    text: Tr.t("Media, battery and network")
                    checked: Desktop.lockClock.widgets
                    onToggled: Desktop.setLockClock("widgets", !checked)
                }
                SettingsUi.Toggle {
                    text: Tr.t("Depth effect")
                    detail: Tr.t("The picture's subject stands in front of the time. Worked out on this PC; nothing is sent anywhere.")
                    checked: Desktop.lockClock.depth
                    onToggled: Desktop.setLockClock("depth", !checked)
                }
            }
        }
    }

    // Text size and contrast.
    Component {
        id: textPage
        Column {
            spacing: Theme.s3
            SettingsUi.Card {
                SettingsUi.Choice {
                    text: Tr.t("Text size")
                    detail: Tr.t("For the shell and the apps that follow the system text size.")
                    value: String(Math.round(Theme.textScale * 100))
                    options: [["100", "100%"], ["125", "125%"], ["150", "150%"], ["175", "175%"], ["200", "200%"]]
                    onPicked: v => {
                        Theme.textScale = v / 100;
                        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", String(v / 100)]);
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Tr.t("The quick brown fox jumps over the lazy dog.")
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(14) }
                    Accessible.ignored: true
                }
            }
            SettingsUi.Card {
                SettingsUi.Toggle {
                    text: Tr.t("High contrast")
                    detail: Tr.t("Black and white, with stronger outlines, for low vision.")
                    checked: Theme.high
                    onToggled: Desktop.contrast = Theme.high ? "normal" : "high"
                }
            }
        }
    }

    // HH:MM, for when light and dark start.
    component TimeField: Column {
        id: tf
        property string text
        property string value
        signal edited(string v)
        spacing: Theme.s1
        SettingsUi.Note { width: implicitWidth; text: tf.text }
        Rectangle {
            width: 96
            height: Math.max(36, Theme.sp(14) + 20)
            radius: Theme.rControl
            color: Theme.win
            border.width: input.activeFocus ? Theme.focusWidth : Theme.rimWidth
            border.color: input.activeFocus ? Theme.accentText : Theme.line
            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: Theme.s2
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                text: tf.value
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentInk
                font { family: Theme.mono; pixelSize: Theme.sp(14) }
                activeFocusOnTab: true
                validator: RegularExpressionValidator { regularExpression: /([01]\d|2[0-3]):[0-5]\d/ }
                onEditingFinished: if (acceptableInput) tf.edited(text)
                onActiveFocusChanged: if (activeFocus) { selectAll(); Reveal.show(tf); }
                Accessible.role: Accessible.EditableText
                Accessible.name: tf.text
                Accessible.description: Tr.t("Hours and minutes, like 07:00")
            }
        }
    }

    // A wallpaper to pick, or Browse.
    component Thumb: MouseArea {
        id: th
        property string value
        property string text
        property string path
        property string glyph
        property bool on
        property string group: Tr.t("Background")  // what the choice is for, for screen readers
        signal picked()
        width: Theme.dp(150)
        height: Theme.dp(84) + Theme.sp(12) + 10
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: picked()
        Keys.onSpacePressed: picked()
        Keys.onReturnPressed: picked()
        Keys.onEnterPressed: picked()
        onActiveFocusChanged: if (activeFocus) Reveal.show(th)
        Accessible.role: glyph ? Accessible.Button : Accessible.RadioButton
        Accessible.name: text
        Accessible.description: glyph ? "" : group
        Accessible.checkable: !glyph
        Accessible.checked: on
        Accessible.onPressAction: picked()
        FocusRim { anchors.bottomMargin: Theme.sp(12) + 6; radius: Theme.rControl + 4 }
        Rectangle {
            id: frame
            width: parent.width
            height: 84
            radius: Theme.rControl
            color: th.containsMouse ? Theme.cardHover : Theme.win
            border.width: th.on ? 3 : Theme.rimWidth
            border.color: th.on ? Theme.accentText : Theme.line
            clip: true
            scale: th.pressed ? Theme.pressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            Image {
                anchors.fill: parent
                anchors.margins: frame.border.width
                visible: th.path !== ""
                source: th.path ? Desktop.fileUrl(th.path) : ""
                sourceSize: Qt.size(300, 168)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Before kriss-theme ships the photos, Dynamic shows the dark one (as DynamicWallpaper does).
                onStatusChanged: if (status === Image.Error && th.value === "dynamic") source = Desktop.fileUrl(Theme.wallpapers + "/kriss-dark.svg")
            }
            Glyph { anchors.centerIn: parent; visible: th.glyph !== ""; name: th.glyph; size: 24 }
        }
        Text {
            anchors.top: frame.bottom
            anchors.topMargin: Theme.s1
            width: parent.width
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
            text: th.text
            color: th.on ? Theme.fg : Theme.soft
            font { family: Theme.sans; pixelSize: Theme.sp(12); weight: th.on ? Font.DemiBold : Font.Normal }
        }
    }

    // A small round button with a glyph.
    component IconButton: MouseArea {
        id: ib
        property string glyph
        property string text
        property string key
        signal picked()
        implicitWidth: 36
        implicitHeight: 36
        opacity: enabled ? 1 : 0.35
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: enabled
        onClicked: picked()
        Keys.onSpacePressed: picked()
        Keys.onReturnPressed: picked()
        Keys.onEnterPressed: picked()
        onActiveFocusChanged: if (activeFocus) Reveal.show(ib)
        Component.onCompleted: if (key && key === win.again && enabled) forceActiveFocus()
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: if (enabled) picked()
        FocusRim { radius: Theme.rCard + 4 }
        Rectangle {
            anchors.fill: parent
            radius: Theme.rCard
            color: ib.containsMouse ? Theme.cardHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        Glyph { anchors.centerIn: parent; name: ib.glyph; size: 18 }
    }

    // A section in the list on the left.
    component NavRow: MouseArea {
        id: tab
        property bool on
        property string glyph
        property string text
        signal picked()
        width: parent?.width ?? 0
        height: Math.max(40, Theme.sp(14) + 24)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: picked()
        Keys.onReturnPressed: picked()
        Keys.onSpacePressed: picked()
        Accessible.role: Accessible.PageTab
        Accessible.name: text
        Accessible.selectable: true
        Accessible.selected: on
        Accessible.onPressAction: picked()
        FocusRim { anchors.margins: 0; radius: Theme.rControl }
        Rectangle {
            anchors.fill: parent
            radius: Theme.rControl
            color: tab.on ? Theme.cardHover : tab.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        // The open section's mark, as Windows' settings lists have.
        Rectangle {
            visible: tab.on
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 16
            radius: width / 2
            color: Theme.accentText
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            spacing: Theme.s3
            Glyph { name: tab.glyph; size: 18; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: tab.text
                width: Math.min(implicitWidth, tab.width - 14 - 18 - Theme.s3 - Theme.s2)
                elide: Text.ElideRight
                color: Theme.fg
                anchors.verticalCenter: parent.verticalCenter
                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: tab.on ? Font.DemiBold : Font.Medium }
            }
        }
    }

}
