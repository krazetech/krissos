// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// The Store: a search field and the sections on the left, apps on the right, the way the
// Windows Store lays them out.
Kirigami.ApplicationWindow {
    id: root
    title: qsTr("Store")
    width: 1150
    height: 760
    minimumWidth: Kirigami.Units.gridUnit * 24

    property string current: "home"

    readonly property var sections: [
        { key: "home", title: qsTr("Home"), icon: "go-home" },
        { key: "productivity", title: qsTr("Productivity"), icon: "applications-office" },
        { key: "creativity", title: qsTr("Photo and design"), icon: "applications-graphics" },
        { key: "games", title: qsTr("Games"), icon: "applications-games" },
        { key: "media", title: qsTr("Music and video"), icon: "applications-multimedia" },
        { key: "internet", title: qsTr("Internet and chat"), icon: "applications-internet" },
        { key: "development", title: qsTr("Programming"), icon: "applications-development" },
        { key: "education", title: qsTr("Education"), icon: "applications-education" },
        { key: "utilities", title: qsTr("Utilities"), icon: "applications-utilities" },
        { key: "installed", title: qsTr("Installed"), icon: "view-list-details" },
        { key: "updates", title: qsTr("Updates"), icon: "system-software-update" }
    ]

    // The pool makes each page once and keeps it (as in kriss-welcome); pushing URLs made
    // Kirigami create pages outside the scene. One grid page serves every section.
    Kirigami.PagePool { id: pool }
    function page(file, props) {
        const p = pool.loadPage(Qt.resolvedUrl(file))
        Object.assign(p, props)
        return p
    }

    function show(key) {
        current = key
        search.text = ""
        pageStack.clear()
        if (key === "updates")
            return pageStack.push(page("UpdatesPage.qml", {}))
        const s = sections.find(s => s.key === key)
        pageStack.push(page("GridPage.qml", { title: s.title, section: key, query: "" }))
    }
    function showSearch(q) {
        if (!q.trim()) return show(current === "search" ? "home" : current)
        current = "search"
        pageStack.clear()
        pageStack.push(page("GridPage.qml", { title: qsTr("Results for “%1”").arg(q.trim()), section: "search", query: q }))
    }
    function openApp(id) {
        const a = backend.app(id)
        if (!a.id) return
        while (pageStack.depth > 1) pageStack.pop()
        pageStack.push(page("AppPage.qml", { app: a }))
    }

    Component.onCompleted: show("home")

    // Opened from Start for one app: show it once the catalogue is in.
    Connections {
        target: backend
        enabled: startApp !== ""
        function onCatalogueChanged() { root.openApp(startApp); enabled = false }
    }

    // What happened to the last change, below the page, like a Windows toast.
    Connections {
        target: backend
        function onDone(id, action, ok) {
            const name = id ? (backend.app(id).name || id) : ""
            root.showPassiveNotification(!ok
                ? { install: qsTr("%1 was not installed. Check your internet, then try again.").arg(name),
                    remove: qsTr("%1 was not removed.").arg(name),
                    update: qsTr("The updates did not finish. Try again later.") }[action]
                : { install: qsTr("%1 is installed. Find it in Start.").arg(name),
                    remove: qsTr("%1 is removed.").arg(name),
                    update: qsTr("Everything is up to date.") }[action], "long")
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        modal: !root.wideScreen
        width: Kirigami.Units.gridUnit * 14
        header: Kirigami.SearchField {
            id: search
            placeholderText: qsTr("Search apps and games")
            // Searches as you type, after a short pause (the field's own delay).
            autoAccept: true
            onAccepted: root.showSearch(text)
            Component.onCompleted: forceActiveFocus()
        }
        actions: root.sections.map(s => nav.createObject(root, {
            key: s.key, "icon.name": s.icon,
            text: Qt.binding(() => s.key === "updates" && backend.updates.length
                ? qsTr("Updates (%1)").arg(backend.updates.length) : s.title)
        }))
    }

    Component {
        id: nav
        Kirigami.Action {
            property string key
            checkable: true
            checked: root.current === key
            onTriggered: root.show(key)
        }
    }
}
