import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Personalise: the shell's own small settings window, like Windows' Personalisation page.
// Colours, background, taskbar, pins, and text size and contrast, a page each. Every change
// applies at once and is saved to shell.json (Desktop.qml); nothing needs a restart.
// Opened from Start search, the desktop's right-click menu and `kriss-shell personalise PAGE`.
FloatingWindow {
    id: win

    visible: Desktop.personalisePage !== ""
    title: Tr.t("Personalise")
    color: Theme.win
    implicitWidth: 820
    implicitHeight: 640
    minimumSize: Qt.size(600, 440)
    // The window's close button.
    onVisibleChanged: {
        if (!visible) Desktop.personalisePage = "";
        else focusNav.restart();
    }

    readonly property string page: Desktop.personalisePage
    readonly property var pages: [
        ["colours", "sun", Tr.t("Colours")],
        ["background", "image", Tr.t("Background")],
        ["taskbar", "taskbar", Tr.t("Taskbar")],
        ["pins", "pin", Tr.t("Pinned apps")],
        ["text", "text", Tr.t("Text and contrast")]
    ]
    readonly property int pageIndex: Math.max(0, pages.findIndex(p => p[0] === page))
    onPageChanged: if (page) {
        scroller.contentY = 0;
        focusNav.restart();
    }

    // The keyboard starts on the open page's entry in the list on the left.
    Timer {
        id: focusNav
        interval: 0
        onTriggered: nav.itemAt(win.pageIndex)?.forceActiveFocus()
    }

    // A control that the keyboard reaches scrolls into view.
    function reveal(item) {
        const y = item.mapToItem(scroller.contentItem, 0, 0).y;
        if (y < scroller.contentY) scroller.contentY = Math.max(0, y - 12);
        else if (y + item.height > scroller.contentY + scroller.height) scroller.contentY = y + item.height - scroller.height + 12;
    }

    // Rebuilt lists (pins) lose the focus; the row whose key is here takes it back.
    property string again: ""

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Desktop.personalisePage = ""

        // The pages.
        Rectangle {
            id: side
            width: 230
            height: parent.height
            color: Theme.card
            Accessible.role: Accessible.PageTabList
            Accessible.name: Tr.t("Personalise")

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                Text {
                    text: Tr.t("Personalise")
                    color: Theme.fg
                    leftPadding: 8
                    bottomPadding: 12
                    topPadding: 4
                    font { family: Theme.sans; pixelSize: Theme.sp(20); weight: Font.DemiBold }
                    Accessible.ignored: true
                }
                Repeater {
                    id: nav
                    model: win.pages
                    MouseArea {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool on: win.pageIndex === index
                        width: parent.width
                        height: Math.max(40, Theme.sp(14) + 24)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: on
                        onClicked: Desktop.personalisePage = modelData[0]
                        function go(d) {
                            const i = (win.pageIndex + d + win.pages.length) % win.pages.length;
                            Desktop.personalisePage = win.pages[i][0];
                            nav.itemAt(i).forceActiveFocus();
                        }
                        Keys.onUpPressed: go(-1)
                        Keys.onDownPressed: go(1)
                        Keys.onReturnPressed: scroller.nextItemInFocusChain(true)?.forceActiveFocus()
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData[2]
                        Accessible.selectable: true
                        Accessible.selected: on
                        Accessible.onPressAction: clicked(null)
                        FocusRim { anchors.margins: 0; radius: 10 }
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: tab.on ? Theme.cardHover : tab.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        }
                        // The open page's mark, as Windows' settings lists have.
                        Rectangle {
                            visible: tab.on
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 16
                            radius: 2
                            color: Theme.accent
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14
                            spacing: 12
                            Glyph { name: tab.modelData[1]; size: 18; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: tab.modelData[2]
                                color: Theme.fg
                                anchors.verticalCenter: parent.verticalCenter
                                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: tab.on ? Font.DemiBold : Font.Medium }
                            }
                        }
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

            Column {
                id: body
                x: 32
                y: 24
                width: scroller.width - 64
                spacing: 14
                Text {
                    text: win.pages[win.pageIndex][2]
                    color: Theme.fg
                    font { family: Theme.sans; pixelSize: Theme.sp(24); weight: Font.DemiBold }
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Loader {
                    width: parent.width
                    active: win.visible
                    sourceComponent: ({ colours: colours, background: background, taskbar: taskbar, pins: pins, text: textPage })[win.pages[win.pageIndex][0]]
                }
            }
        }
    }

    // Colours: the accent and light or dark.
    Component {
        id: colours
        Column {
            spacing: 14
            Card {
                Choice {
                    text: Tr.t("Choose your mode")
                    detail: Tr.t("Apps that follow the system switch with the shell.")
                    value: Theme.mode
                    options: [["dark", Tr.t("Dark")], ["light", Tr.t("Light")], ["system", Tr.t("Follow apps setting")], ["auto", Tr.t("By time of day")]]
                    onPicked: v => Theme.set("mode", v)
                }
                Row {
                    visible: Theme.mode === "auto"
                    spacing: 16
                    TimeField { text: Tr.t("Light from"); value: Desktop.themeLight; onEdited: v => Desktop.themeLight = v }
                    TimeField { text: Tr.t("Dark from"); value: Desktop.themeDark; onEdited: v => Desktop.themeDark = v }
                }
            }
            Card {
                Label { text: Tr.t("Accent colour") }
                Note { text: Theme.high ? Tr.t("High contrast uses its own colours. Your choice comes back when you turn it off.") : Tr.t("Buttons, switches and highlights use it.") }
                Flow {
                    width: parent.width
                    spacing: 10
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
                            onActiveFocusChanged: if (activeFocus) win.reveal(sw)
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.name
                            Accessible.description: Tr.t("Accent colour")
                            Accessible.checkable: true
                            Accessible.checked: on
                            Accessible.onPressAction: clicked(null)
                            FocusRim { anchors.margins: -3; radius: 25 }
                            Rectangle {
                                anchors.fill: parent
                                radius: 22
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
                Note { text: Theme.accents.find(a => a.color.toLowerCase() === Theme.chosenAccent.toLowerCase())?.name ?? "" }
            }
        }
    }

    // Background: the time-of-day picture, KrissOS's own, or any picture.
    Component {
        id: background
        Column {
            id: bgPage
            spacing: 14
            readonly property string wall: Desktop.wallpaper
            // Pictures in the shared backgrounds and in Pictures, newest first.
            property var found: []
            Process {
                running: true
                command: ["sh", "-c", `
                    p=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
                    find /usr/share/backgrounds "$p" -maxdepth 3 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' \\
                        -o -iname '*.png' -o -iname '*.webp' -o -iname '*.svg' \\) -printf '%T@ %p\\n' 2>/dev/null |
                        sort -rn | cut -d' ' -f2- | head -40`]
                stdout: StdioCollector {
                    onStreamFinished: bgPage.found = text.split("\n").filter(p => p && !p.startsWith(Theme.wallpapers + "/kriss-"))
                }
            }
            Card {
                Label { text: Tr.t("Background") }
                Note { text: Tr.t("Dynamic moves from dawn to night with the clock. KrissOS follows light and dark.") }
                Flow {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [["dynamic", Tr.t("Dynamic"), Theme.wallpapers + "/kriss-day.svg"],
                                ["static", Tr.t("KrissOS"), Theme.wallpapers + "/kriss-" + (Theme.dark ? "dark" : "light") + ".svg"]]
                            .concat((bgPage.wall.startsWith("/") && bgPage.found.indexOf(bgPage.wall) < 0 ? [bgPage.wall] : []).concat(bgPage.found)
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
            spacing: 14
            Card {
                Choice {
                    text: Tr.t("Taskbar alignment")
                    value: Desktop.taskbarAlignment
                    options: [["left", Tr.t("Left")], ["centre", Tr.t("Centre")]]
                    onPicked: v => Desktop.taskbarAlignment = v
                }
                Choice {
                    text: Tr.t("Taskbar size")
                    value: Desktop.taskbarSize
                    options: [["small", Tr.t("Small")], ["medium", Tr.t("Medium")], ["large", Tr.t("Large")]]
                    onPicked: v => Desktop.taskbarSize = v
                }
                Choice {
                    text: Tr.t("Combine taskbar buttons")
                    value: Desktop.taskbarCombine
                    options: [["always", Tr.t("Always")], ["full", Tr.t("When the taskbar is full")], ["never", Tr.t("Never")]]
                    onPicked: v => Desktop.taskbarCombine = v
                }
            }
            Card {
                Toggle {
                    text: Tr.t("Automatically hide the taskbar")
                    detail: Tr.t("It comes back when the pointer reaches the bottom edge.")
                    checked: Desktop.taskbarAutoHide
                    onToggled: Desktop.taskbarAutoHide = !Desktop.taskbarAutoHide
                }
                Toggle {
                    text: Tr.t("Task View button")
                    checked: Desktop.taskbarTaskView
                    onToggled: Desktop.taskbarTaskView = !Desktop.taskbarTaskView
                }
                Toggle {
                    text: Tr.t("Show the taskbar on all screens")
                    checked: Desktop.taskbarAllScreens
                    onToggled: Desktop.taskbarAllScreens = !Desktop.taskbarAllScreens
                }
            }
            Card {
                Label { text: Tr.t("Tray icons") }
                Note { text: SystemTray.items.values.length ? Tr.t("Icons that are off wait behind the arrow next to the clock.") : Tr.t("No apps have a tray icon right now.") }
                Repeater {
                    model: SystemTray.items
                    Toggle {
                        required property var modelData
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
            spacing: 14
            Card {
                Note { text: Tr.t("These apps are pinned to Start and the taskbar, in this order. Pin more from Start: right-click an app.") }
                Note { visible: Desktop.pinned.length === 0; text: Tr.t("Nothing is pinned.") }
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
                            spacing: 10
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

    // Text size and contrast.
    Component {
        id: textPage
        Column {
            spacing: 14
            Card {
                Choice {
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
            Card {
                Toggle {
                    text: Tr.t("High contrast")
                    detail: Tr.t("Black and white, with stronger outlines, for low vision.")
                    checked: Theme.high
                    onToggled: Desktop.contrast = Theme.high ? "normal" : "high"
                }
            }
        }
    }

    // A group of settings on a raised card.
    component Card: Rectangle {
        default property alias content: inner.data
        width: parent?.width ?? 0
        implicitHeight: inner.implicitHeight + 32
        radius: Theme.radiusSmall
        color: Theme.card
        border.width: Theme.high ? Theme.rimWidth : 0
        border.color: Theme.line
        Column {
            id: inner
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12
        }
    }

    component Label: Text {
        width: parent?.width ?? 0
        wrapMode: Text.WordWrap
        color: Theme.fg
        font { family: Theme.sans; pixelSize: Theme.sp(15); weight: Font.DemiBold }
    }

    component Note: Text {
        width: parent?.width ?? 0
        wrapMode: Text.WordWrap
        color: Theme.soft
        font { family: Theme.sans; pixelSize: Theme.sp(13) }
    }

    // One of a few choices, as a row of buttons; a screen reader hears radio buttons.
    component Choice: Column {
        id: choice
        property string text
        property string detail
        property var options    // [[value, label]]
        property string value
        signal picked(string v)
        width: parent?.width ?? 0
        spacing: 8
        Label { text: choice.text }
        Note { visible: text !== ""; text: choice.detail }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: choice.options
                MouseArea {
                    id: opt
                    required property var modelData
                    readonly property bool on: choice.value === modelData[0]
                    width: optText.implicitWidth + 32
                    height: Math.max(36, Theme.sp(13) + 20)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    onClicked: choice.picked(modelData[0])
                    Keys.onSpacePressed: clicked(null)
                    Keys.onReturnPressed: clicked(null)
                    Keys.onEnterPressed: clicked(null)
                    onActiveFocusChanged: if (activeFocus) win.reveal(opt)
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData[1]
                    Accessible.description: choice.text
                    Accessible.checkable: true
                    Accessible.checked: on
                    Accessible.onPressAction: clicked(null)
                    FocusRim { radius: height / 2 + 4 }
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: opt.on ? (opt.containsMouse ? Theme.accentHover : Theme.accent) : opt.containsMouse ? Theme.cardHover : Theme.win
                        border.width: opt.on ? 0 : Theme.rimWidth
                        border.color: Theme.line
                        scale: opt.pressed ? Theme.pressScale : 1
                        Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                        Behavior on scale { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
                    }
                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: opt.modelData[1]
                        color: opt.on ? Theme.accentInk : Theme.fg
                        font { family: Theme.sans; pixelSize: Theme.sp(13); weight: opt.on ? Font.DemiBold : Font.Medium }
                    }
                }
            }
        }
    }

    // A setting that is on or off: the whole row is the switch.
    component Toggle: MouseArea {
        id: tg
        property string text
        property string detail
        property bool checked
        signal toggled()
        width: parent?.width ?? 0
        height: Math.max(48, words.implicitHeight + 16)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: toggled()
        Keys.onSpacePressed: toggled()
        Keys.onReturnPressed: toggled()
        Keys.onEnterPressed: toggled()
        onActiveFocusChanged: if (activeFocus) win.reveal(tg)
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        Accessible.description: detail
        Accessible.checkable: true
        Accessible.checked: checked
        Accessible.onPressAction: toggled()
        Accessible.onToggleAction: toggled()
        FocusRim { anchors.margins: -4; radius: 12 }
        Column {
            id: words
            anchors.left: parent.left
            anchors.right: track.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: tg.text
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(14); weight: Font.Medium }
            }
            Text {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: tg.detail
                color: Theme.soft
                font { family: Theme.sans; pixelSize: Theme.sp(12) }
            }
        }
        Rectangle {
            id: track
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: 12
            color: tg.checked ? (tg.containsMouse ? Theme.accentHover : Theme.accent) : Theme.win
            border.width: tg.checked ? 0 : Theme.rimWidth + 1
            border.color: Theme.soft
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: tg.checked ? parent.width - width - 4 : 4
                color: tg.checked ? Theme.accentInk : Theme.soft
                Behavior on x { NumberAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
        }
    }

    // HH:MM, for when light and dark start.
    component TimeField: Column {
        id: tf
        property string text
        property string value
        signal edited(string v)
        spacing: 6
        Note { width: implicitWidth; text: tf.text }
        Rectangle {
            width: 96
            height: Math.max(36, Theme.sp(14) + 20)
            radius: 10
            color: Theme.win
            border.width: input.activeFocus ? Theme.focusWidth : Theme.rimWidth
            border.color: input.activeFocus ? Theme.accent : Theme.line
            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 8
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
                onActiveFocusChanged: if (activeFocus) { selectAll(); win.reveal(tf); }
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
        signal picked()
        width: 150
        height: 84 + Theme.sp(12) + 10
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: picked()
        Keys.onSpacePressed: picked()
        Keys.onReturnPressed: picked()
        Keys.onEnterPressed: picked()
        onActiveFocusChanged: if (activeFocus) win.reveal(th)
        Accessible.role: glyph ? Accessible.Button : Accessible.RadioButton
        Accessible.name: text
        Accessible.description: glyph ? "" : Tr.t("Background")
        Accessible.checkable: !glyph
        Accessible.checked: on
        Accessible.onPressAction: picked()
        FocusRim { anchors.bottomMargin: Theme.sp(12) + 6; radius: 14 }
        Rectangle {
            id: frame
            width: parent.width
            height: 84
            radius: 10
            color: th.containsMouse ? Theme.cardHover : Theme.win
            border.width: th.on ? 3 : Theme.rimWidth
            border.color: th.on ? Theme.accent : Theme.line
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
                // Before kriss-theme ships the day light, Dynamic shows the dark one (as DynamicWallpaper does).
                onStatusChanged: if (status === Image.Error && th.value === "dynamic") source = Desktop.fileUrl(Theme.wallpapers + "/kriss-dark.svg")
            }
            Glyph { anchors.centerIn: parent; visible: th.glyph !== ""; name: th.glyph; size: 24 }
        }
        Text {
            anchors.top: frame.bottom
            anchors.topMargin: 6
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
        onActiveFocusChanged: if (activeFocus) win.reveal(ib)
        Component.onCompleted: if (key && key === win.again && enabled) forceActiveFocus()
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: if (enabled) picked()
        FocusRim { radius: 22 }
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: ib.containsMouse ? Theme.cardHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
        }
        Glyph { anchors.centerIn: parent; name: ib.glyph; size: 18 }
    }
}
