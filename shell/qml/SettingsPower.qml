import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Settings > System > Power and battery: when the screen turns off and the PC sleeps
// (cosmic-idle, which the session starts, reads them from com.system76.CosmicIdle and
// follows a change at once), the power mode (power-profiles-daemon) and the battery on a
// laptop (UPower).
Column {
    id: page
    spacing: Theme.s3

    readonly property var dev: UPower.displayDevice
    readonly property bool laptop: dev?.isLaptopBattery ?? false
    FileView {
        id: ppd
        path: "/usr/share/dbus-1/system-services/net.hadess.PowerProfiles.service"
        printErrors: false
    }

    SettingsUi.Card {
        visible: page.laptop
        SettingsUi.Label { text: Tr.t("Battery") }
        Text {
            text: Math.round(page.dev.percentage * 100) + "%"
            color: Theme.fg
            font { family: Theme.sans; pixelSize: Theme.sp(32); weight: Font.DemiBold }
            Accessible.role: Accessible.StaticText
            Accessible.name: Tr.t("Battery %1%", Math.round(page.dev.percentage * 100))
        }
        SettingsUi.Note {
            // UPower's estimates are in seconds; 0 while it is still working them out.
            readonly property int secs: UPower.onBattery ? page.dev.timeToEmpty : page.dev.timeToFull
            text: (UPower.onBattery ? Tr.t("On battery.") : Tr.t("Plugged in.")) + (secs > 0
                ? " " + (UPower.onBattery ? Tr.t("About %1 left.", page.span(secs)) : Tr.t("Full in about %1.", page.span(secs))) : "")
        }
    }
    function span(s) {
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h ? Tr.t("%1 h %2 min", h, m) : Tr.t("%1 min", m);
    }

    // cosmic-idle's settings, one RON value per file in milliseconds: Some(900000) or None.
    // Missing files are cosmic-idle's defaults.
    readonly property string idleDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cosmic/com.system76.CosmicIdle/v1"
    function minutes(file, fallback) {
        const m = /Some\((\d+)\)/.exec(file.text() ?? "");
        return file.loaded ? (m ? String(Math.round(m[1] / 60000)) : "0") : fallback;
    }
    function setIdle(name, mins) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf %s "$3" > "$1/.$2" && mv -f "$1/.$2" "$1/$2"',
            "sh", idleDir, name, +mins ? "Some(" + mins * 60000 + ")" : "None"]);
    }
    FileView { id: screenOff; path: page.idleDir + "/screen_off_time"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    FileView { id: sleepAc; path: page.idleDir + "/suspend_on_ac_time"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    FileView { id: sleepBattery; path: page.idleDir + "/suspend_on_battery_time"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    function times(list, now) {
        const out = list.indexOf(+now) < 0 && +now ? list.concat([+now]).sort((a, b) => a - b) : list;
        return out.map(m => [String(m), m >= 60 ? Tr.t("%1 h", m / 60) : Tr.t("%1 min", m)]).concat([["0", Tr.t("Never")]]);
    }

    SettingsUi.Card {
        SettingsUi.Choice {
            text: Tr.t("Turn off the screen after")
            detail: Tr.t("The PC locks as the screen goes off. Videos and games keep it on.")
            value: page.minutes(screenOff, "15")
            options: page.times([1, 2, 5, 10, 15, 30, 60], value)
            onPicked: v => page.setIdle("screen_off_time", v)
        }
        SettingsUi.Choice {
            text: page.laptop ? Tr.t("Sleep after, when plugged in") : Tr.t("Sleep after")
            value: page.minutes(sleepAc, "30")
            options: page.times([5, 10, 15, 30, 60, 120], value)
            onPicked: v => page.setIdle("suspend_on_ac_time", v)
        }
        SettingsUi.Choice {
            visible: page.laptop
            text: Tr.t("Sleep after, on battery")
            value: page.minutes(sleepBattery, "15")
            options: page.times([5, 10, 15, 30, 60], value)
            onPicked: v => page.setIdle("suspend_on_battery_time", v)
        }
    }

    SettingsUi.Card {
        visible: ppd.loaded
        SettingsUi.Choice {
            text: Tr.t("Power mode")
            detail: Tr.t("Power saver makes the battery last longer; Performance is for games and heavy work.")
            value: String(PowerProfiles.profile)
            options: [[String(PowerProfile.PowerSaver), Tr.t("Power saver")], [String(PowerProfile.Balanced), Tr.t("Balanced")]]
                .concat(PowerProfiles.hasPerformanceProfile ? [[String(PowerProfile.Performance), Tr.t("Performance")]] : [])
            onPicked: v => PowerProfiles.profile = +v
        }
    }

    SettingsUi.Card {
        SettingsUi.LinkRow {
            glyph: "power"
            text: Tr.t("More power options")
            detail: Tr.t("The power button and closing the lid")
            external: true
            onPicked: Quickshell.execDetached(["cosmic-settings", "power"])
        }
    }
}
