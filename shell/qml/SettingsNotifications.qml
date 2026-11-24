import QtQuick

// Settings > System > Notifications: do not disturb, and which apps may pop up. An app that
// may not still puts its notifications in the notification center, as on Windows' "Show
// notification banners" switch. The apps are those that have sent one.
Column {
    id: page
    spacing: Theme.s3

    readonly property var apps: {
        const names = Notifs.all.map(n => n.appName).concat(Desktop.quietApps).filter(a => a);
        return names.filter((a, i) => names.indexOf(a) === i).sort((a, b) => a.localeCompare(b));
    }

    SettingsUi.Card {
        SettingsUi.Toggle {
            text: Tr.t("Do not disturb")
            detail: Tr.t("No pop-ups; notifications wait in the notification center. Urgent ones, like a low battery, still show.")
            checked: Desktop.dnd
            onToggled: Desktop.dnd = !Desktop.dnd
        }
        SettingsUi.Note { text: Tr.t("Pop-ups also wait while a game or video is fullscreen.") }
    }

    SettingsUi.Card {
        SettingsUi.Label { text: Tr.t("Pop-ups from apps") }
        SettingsUi.Note { text: page.apps.length ? Tr.t("Off: the app's notifications go to the notification center without popping up.") : Tr.t("Apps show up here once they send a notification.") }
        Repeater {
            model: page.apps
            SettingsUi.Toggle {
                required property string modelData
                text: modelData
                checked: Desktop.quietApps.indexOf(modelData) < 0
                onToggled: Desktop.quietApps = checked ? Desktop.quietApps.concat([modelData]) : Desktop.quietApps.filter(a => a !== modelData)
            }
        }
    }
}
