import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Settings > System > Power and battery: the power mode (power-profiles-daemon), the battery
// on a laptop (UPower), and COSMIC's power page for the rest.
// ponytail: no screen-off or sleep timers yet; KrissOS runs no idle daemon. Add them here
// once one is chosen (cosmic-idle reads com.system76.CosmicIdle).
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
            detail: Tr.t("When the screen turns off, sleep, the power button")
            external: true
            onPicked: Quickshell.execDetached(["cosmic-settings", "power"])
        }
    }
}
