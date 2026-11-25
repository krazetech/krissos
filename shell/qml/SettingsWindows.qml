import QtQuick

// Settings > Personalise > Windows: how app windows look. Saved in shell.json (Desktop.qml);
// Theme.qml hands them to COSMIC and cosmic-comp-kriss (corners, the border, org.krissos.Look).
Column {
    spacing: Theme.s3

    SettingsUi.Card {
        SettingsUi.Choice {
            text: Tr.t("Corners")
            value: Desktop.windowCorners
            options: [["square", Tr.t("Square")], ["small", Tr.t("Slightly round")], ["round", Tr.t("Round")]]
            onPicked: v => Desktop.windowCorners = v
        }
        SettingsUi.Choice {
            text: Tr.t("Border around the window you are using")
            detail: Tr.t("In your accent colour.")
            value: Desktop.windowBorder
            options: [["off", Tr.t("None")], ["thin", Tr.t("Thin")], ["thick", Tr.t("Thick")]]
            onPicked: v => Desktop.windowBorder = v
        }
        SettingsUi.Choice {
            text: Tr.t("Shadows")
            value: Desktop.windowShadow
            options: [["off", Tr.t("None")], ["soft", Tr.t("Soft")], ["normal", Tr.t("Normal")], ["strong", Tr.t("Strong")]]
            onPicked: v => Desktop.windowShadow = v
        }
    }
    SettingsUi.Card {
        SettingsUi.Choice {
            text: Tr.t("Animation speed")
            detail: Theme.reduceMotion ? Tr.t("Animations are turned off for the whole desktop.") : Tr.t("Windows opening and closing, Start, menus and panels.")
            value: Desktop.animationSpeed
            options: [["slow", Tr.t("Relaxed")], ["normal", Tr.t("Normal")], ["fast", Tr.t("Quick")]]
            onPicked: v => Desktop.animationSpeed = v
        }
        SettingsUi.Toggle {
            text: Tr.t("Transparency effects")
            detail: Tr.t("The taskbar, Start, menus and notifications show a blur of what is behind them.")
            checked: Desktop.transparency
            onToggled: Desktop.transparency = !Desktop.transparency
        }
    }
}
