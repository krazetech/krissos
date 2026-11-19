import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The desktop's icons, as on Windows: Trash, then what is in ~/Desktop, in columns from the
// top left. Click selects, Ctrl+click adds, a drag draws a selection box, double-click or Enter
// opens, Delete moves to the trash, Ctrl+A selects all, right-click an icon for its menu.
// ponytail: icons keep their grid order; dragging them to new places is not done yet.
Item {
    id: root

    // ponytail: ~/Desktop, not xdg-user-dir; a renamed Desktop folder shows no icons.
    property bool showIcons: true
    readonly property string dir: Quickshell.env("HOME") + "/Desktop"
    readonly property int cellW: 92
    readonly property int cellH: Math.max(100, 70 + Math.ceil(Theme.sp(12) * 2.6))
    readonly property int pad: 12
    readonly property int rows: Math.max(1, Math.floor((height - Desktop.topRoom - Desktop.bottomRoom - pad * 2) / cellH))

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        showDirsFirst: true
        showHidden: false
        sortCaseSensitive: false
    }

    // [{name, path, dir, trash}]: Trash first, as Windows puts the Recycle Bin.
    readonly property var items: {
        if (!showIcons) return [];
        const out = [{ name: Tr.t("Trash"), path: "trash:///", trash: true }];
        for (let i = 0; i < folder.count; i++)
            out.push({ name: folder.get(i, "fileName"), path: folder.get(i, "filePath"), dir: folder.get(i, "fileIsDir") });
        return out;
    }
    property var selected: []   // paths
    property int current: -1    // the icon the keyboard is on
    // The desktop keeps the keyboard itself, so a screen reader hears the icon it reaches.
    Accessible.role: Accessible.List
    Accessible.name: Tr.t("Desktop")
    onCurrentChanged: if (activeFocus && items[current]) Accessible.announce(items[current].name)

    function cellRect(i) {
        return Qt.rect(pad + Math.floor(i / rows) * cellW, Desktop.topRoom + pad + (i % rows) * cellH, cellW, cellH);
    }
    function isSelected(path) { return selected.indexOf(path) >= 0; }
    function selectOnly(i) { selected = i >= 0 ? [items[i].path] : []; current = i; }
    function toggle(i) {
        const p = items[i].path;
        selected = isSelected(p) ? selected.filter(s => s !== p) : selected.concat([p]);
        current = i;
    }

    function open(paths) {
        for (const p of paths) {
            if (p.endsWith(".desktop")) Quickshell.execDetached(["gio", "launch", p]);
            else Quickshell.execDetached(["xdg-open", p]);
        }
    }
    function trash(paths) {
        const files = paths.filter(p => p !== "trash:///");
        if (files.length) Quickshell.execDetached(["gio", "trash", "--"].concat(files));
        selected = [];
    }

    function iconMenu(i, item, byKeyboard) {
        if (!isSelected(items[i].path)) selectOnly(i);
        const paths = selected;
        const out = [{ text: Tr.t("Open"), run: () => root.open(paths) }];
        if (!items[i].trash)
            out.push({ sep: true }, { text: Tr.t("Move to trash"), glyph: "trash", run: () => root.trash(paths) });
        menu.show(item, out, !!byKeyboard);
    }

    Menu { id: menu }

    // Empty space: a click clears the selection, a drag selects what the box touches.
    MouseArea {
        id: box
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        Accessible.ignored: true  // the selection box is pointer only; the keys select too
        property point from
        property var base: []
        onPressed: mouse => {
            root.forceActiveFocus();
            from = Qt.point(mouse.x, mouse.y);
            base = mouse.modifiers & Qt.ControlModifier ? root.selected : [];
            root.selected = base;
            root.current = -1;
        }
        onPositionChanged: {
            const r = Qt.rect(band.x, band.y, band.width, band.height);
            const hit = root.items.filter((it, i) => {
                const c = root.cellRect(i);
                return c.x < r.x + r.width && r.x < c.x + c.width && c.y < r.y + r.height && r.y < c.y + c.height;
            }).map(it => it.path);
            root.selected = base.concat(hit.filter(p => base.indexOf(p) < 0));
        }
        Rectangle {
            id: band
            visible: box.pressed
            x: Math.min(box.from.x, box.mouseX)
            y: Math.min(box.from.y, box.mouseY)
            width: Math.abs(box.mouseX - box.from.x)
            height: Math.abs(box.mouseY - box.from.y)
            z: 1
            radius: Theme.rSmall
            color: Theme.alpha(Theme.accent, 0.15)
            border.width: 1
            border.color: Theme.alpha(Theme.accentText, 0.7)
        }
    }

    Repeater {
        id: repeater
        model: root.items
        delegate: MouseArea {
            id: icon
            required property var modelData
            required property int index
            readonly property bool sel: root.isSelected(modelData.path)
            readonly property bool launcher: modelData.path.endsWith(".desktop")
            readonly property var cell: root.cellRect(index)
            x: cell.x; y: cell.y; width: cell.width - 4; height: cell.height - 4
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            Accessible.role: Accessible.ListItem
            Accessible.name: info.Name ?? modelData.name
            Accessible.selected: sel
            Accessible.onPressAction: root.open([modelData.path])
            onPressed: mouse => {
                root.forceActiveFocus();
                if (mouse.button === Qt.RightButton) return;
                if (mouse.modifiers & Qt.ControlModifier) root.toggle(index);
                else if (!sel) root.selectOnly(index);
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) root.iconMenu(index, icon, false);
                else if (!(mouse.modifiers & Qt.ControlModifier)) root.selectOnly(index);
            }
            onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) root.open([modelData.path]); }

            // A launcher's own name and icon, read from its .desktop file.
            FileView { id: entry; path: icon.launcher ? icon.modelData.path : ""; printErrors: false }
            readonly property var info: {
                const out = {};
                if (!launcher) return out;
                for (const l of (entry.text() ?? "").split("\n")) {
                    const m = /^(Name|Icon)=(.*)$/.exec(l);
                    if (m && !(m[1] in out)) out[m[1]] = m[2];
                }
                return out;
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.rCard
                color: icon.sel ? Theme.alpha(Theme.accent, 0.22) : icon.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                // The keyboard's icon gets the focus rim; a selected one a fainter line.
                readonly property bool kb: root.current === icon.index && root.activeFocus
                border.width: kb ? Theme.focusWidth : icon.sel ? Theme.rimWidth : 0
                border.color: kb ? Theme.accentText : Theme.alpha(Theme.accentText, 0.7)
                Behavior on color { ColorAnimation { duration: Theme.ms(Theme.fast); easing.type: Theme.ease } }
            }
            IconImage {
                id: img
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                implicitSize: 48
                source: Quickshell.iconPath(icon.modelData.trash ? "user-trash"
                    : icon.modelData.dir ? "folder"
                    : icon.launcher ? (icon.info.Icon ?? "application-x-executable")
                    : "text-x-generic", "text-x-generic")
            }
            Text {
                anchors { top: img.bottom; topMargin: Theme.s1; left: parent.left; right: parent.right; leftMargin: Theme.s1; rightMargin: Theme.s1 }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: icon.sel ? 4 : 2
                elide: Text.ElideRight
                text: icon.info.Name ?? icon.modelData.name
                color: Theme.fg
                font { family: Theme.sans; pixelSize: Theme.sp(12); weight: Font.Medium }
            }
        }
    }

    // Keys while the desktop has the keyboard: arrows move, Enter opens, Delete trashes.
    focus: true
    Keys.onPressed: event => {
        const n = items.length, i = current;
        const go = j => { if (j >= 0 && j < n) { selectOnly(j); } };
        if (event.key === Qt.Key_A && event.modifiers & Qt.ControlModifier) selected = items.map(it => it.path);
        else switch (event.key) {
        case Qt.Key_Up: go(i < 0 ? 0 : i - 1); break;
        case Qt.Key_Down: go(i < 0 ? 0 : i + 1); break;
        case Qt.Key_Left: go(i < 0 ? 0 : i - rows); break;
        case Qt.Key_Right: go(i < 0 ? 0 : i + rows); break;
        case Qt.Key_Home: go(0); break;
        case Qt.Key_End: go(n - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: open(selected); break;
        case Qt.Key_Delete: trash(selected); break;
        case Qt.Key_Escape: selected = []; current = -1; break;
        case Qt.Key_Menu:
            if (i >= 0) iconMenu(i, repeater.itemAt(i), true);
            break;
        case Qt.Key_F10:
            if (!(event.modifiers & Qt.ShiftModifier)) return;
            if (i >= 0) iconMenu(i, repeater.itemAt(i), true);
            break;
        default: return;
        }
        event.accepted = true;
    }
}
