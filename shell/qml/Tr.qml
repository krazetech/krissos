pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Translations. Quickshell installs no QTranslator, so qsTr() would always return
// English; every shell string goes through Tr.t() instead. The catalogue for the
// user's language is i18n/<lang>.json next to shell.qml: {"English text": "translation"}.
// Missing entries fall back to English. `make-i18n` checks every Tr.t() string has one.
Singleton {
    id: root

    // LANGUAGE (a colon list), then LC_ALL, LC_MESSAGES and LANG, as gettext reads them.
    readonly property string lang: {
        for (const v of ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"]) {
            const s = (Quickshell.env(v) ?? "").split(":")[0];
            if (s) return s.split(/[_.@]/)[0];
        }
        return "en";
    }

    property var strings: ({})

    // `%1`, `%2`... in the text are replaced by the extra arguments, like qsTr().arg().
    function t(text, ...args) {
        let s = strings[text] ?? text;
        args.forEach((a, i) => s = s.replace("%" + (i + 1), a));
        return s;
    }

    FileView {
        path: root.lang === "en" ? "" : Quickshell.shellPath("i18n/" + root.lang + ".json")
        printErrors: false
        onLoaded: {
            try {
                root.strings = JSON.parse(text());
            } catch (e) {
                console.warn("Tr:", path, e);
            }
        }
    }
}
