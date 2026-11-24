pragma Singleton

import QtQuick
import Quickshell
import "fuzzy.js" as Fuzzy

// The Settings window's pages (Settings.qml draws them), what search finds in them, and which
// one is open. A page the shell has no page of its own for yet opens that page of COSMIC
// Settings (`cosmic`), which then runs in a window of its own.
Singleton {
    id: root

    // The sections in the list on the left, in order: [id, glyph, name].
    readonly property var groups: [
        ["system", "display", Tr.t("System")],
        ["devices", "keyboard", Tr.t("Bluetooth and devices")],
        ["network", "globe", Tr.t("Network and internet")],
        ["personalise", "image", Tr.t("Personalise")],
        ["apps", "apps", Tr.t("Apps")],
        ["accounts", "user", Tr.t("Accounts")],
        ["time", "clock", Tr.t("Time and language")],
        ["privacy", "shield", Tr.t("Privacy")],
        ["update", "update", Tr.t("Updates")]
    ]

    // Each page: id, its section, glyph, name, a line saying what is on it, the words people
    // look for it by (English and Malay, ";" between), and either `keys`, the names of the
    // settings on the page as it shows them (search finds each one), or `cosmic`, the COSMIC
    // Settings page it opens.
    readonly property var pages: [
        { id: "display", group: "system", glyph: "display", name: Tr.t("Display"), detail: Tr.t("Main display, scale, resolution, night light"),
          words: "display;screen;monitor;resolution;scale;refresh rate;hz;night light;primary;main display;arrange;paparan;skrin;resolusi;skala;lampu malam;paparan utama",
          keys: [Tr.t("Rearrange your displays"), Tr.t("Identify"), Tr.t("Make this my main display"), Tr.t("Scale"), Tr.t("Display resolution"),
                 Tr.t("Refresh rate"), Tr.t("Orientation"), Tr.t("Variable refresh rate"), Tr.t("Use this display"), Tr.t("Night light")] },
        { id: "sound", group: "system", glyph: "volume", name: Tr.t("Sound"), detail: Tr.t("Speakers, microphone, volume"),
          words: "sound;audio;volume;speakers;headphones;microphone;output;input;volume mixer;app volume;system sounds;sound theme;chime;bunyi;bunyi sistem;tema bunyi;kelantangan;pembesar suara;mikrofon;pengadun",
          keys: [Tr.t("Output"), Tr.t("Input"), Tr.t("Volume mixer"), Tr.t("Play system sounds"), Tr.t("Sound theme")] },
        { id: "notifications", group: "system", glyph: "bell", name: Tr.t("Notifications"), detail: Tr.t("Alerts from apps, do not disturb"),
          words: "notifications;do not disturb;alerts;toasts;pop-ups;banners;pemberitahuan;jangan ganggu",
          keys: [Tr.t("Do not disturb"), Tr.t("Pop-ups from apps")] },
        { id: "power", group: "system", glyph: "power", name: Tr.t("Power and battery"), detail: Tr.t("Screen off, sleep, power mode, battery"),
          words: "power;battery;sleep;screen off;power saver;power plan;power mode;performance;kuasa;bateri;tidur;penjimat kuasa;prestasi",
          keys: [Tr.t("Battery"), Tr.t("Turn off the screen after"), Tr.t("Sleep after"), Tr.t("Power mode"), Tr.t("More power options")] },
        { id: "recovery", group: "system", glyph: "restart", name: Tr.t("Recovery"), detail: Tr.t("Reset this PC"),
          words: "recovery;reset;reset this pc;reinstall;factory reset;fresh start;pemulihan;set semula;pasang semula",
          keys: [Tr.t("Reset this PC")] },
        { id: "report", group: "system", glyph: "send", name: Tr.t("Report a problem"), detail: Tr.t("Send the KrissOS team what went wrong"),
          words: "report a problem;bug;feedback;help;crash;logs;laporkan masalah;pepijat;maklum balas;bantuan" },
        { id: "about", group: "system", glyph: "info", name: Tr.t("About"), detail: Tr.t("This PC's name, its parts and the KrissOS version"),
          words: "about;system info;version;device name;pc name;rename;specs;processor;memory;ram;graphics;gpu;perihal;maklumat sistem;versi;nama peranti;namakan semula",
          keys: [Tr.t("PC name"), Tr.t("This PC")] },

        { id: "bluetooth", group: "devices", glyph: "bluetooth", name: Tr.t("Bluetooth"), detail: Tr.t("Pair headphones, mice and phones"),
          words: "bluetooth;pair;devices;headphones;peranti;pasangkan",
          keys: [Tr.t("Your devices"), Tr.t("Add a device")] },
        { id: "mouse", group: "devices", glyph: "mouse", name: Tr.t("Mouse"), detail: Tr.t("Pointer speed, scrolling, buttons"),
          words: "mouse;pointer;cursor;scroll;speed;acceleration;left-handed;tetikus;penuding;kursor",
          keys: [Tr.t("Mouse pointer speed"), Tr.t("Enhance pointer precision"), Tr.t("Swap the left and right buttons"), Tr.t("Natural scrolling"), Tr.t("Scrolling speed")] },
        { id: "touchpad", group: "devices", glyph: "mouse", name: Tr.t("Touchpad"), detail: Tr.t("Tapping, scrolling, gestures"),
          words: "touchpad;trackpad;gestures;tap to click;pad sentuh;gerak isyarat",
          keys: [Tr.t("Touchpad speed"), Tr.t("Tap to click"), Tr.t("Turn off while typing"), Tr.t("Gestures")] },
        { id: "keyboard", group: "devices", glyph: "keyboard", name: Tr.t("Keyboard"), detail: Tr.t("Languages, typing, shortcuts"),
          words: "keyboard;layout;language;shortcuts;input method;chinese;pinyin;tamil;jawi;repeat;papan kekunci;susun atur;pintasan;bahasa",
          keys: [Tr.t("Chinese (Pinyin)"), Tr.t("Tamil"), Tr.t("Jawi"), Tr.t("Repeat delay"), Tr.t("Repeat rate"), Tr.t("Keyboard shortcuts")] },

        { id: "wifi", group: "network", glyph: "wifi", name: Tr.t("Wi-Fi"), detail: Tr.t("Wireless networks"),
          words: "wifi;wi-fi;wireless;internet;hotspot;wayarles;tanpa wayar",
          keys: [Tr.t("Networks"), Tr.t("More Wi-Fi options")] },
        { id: "ethernet", group: "network", glyph: "wired", name: Tr.t("Ethernet"), detail: Tr.t("Cable connections"),
          words: "ethernet;wired;cable;lan;berwayar;kabel" },
        { id: "vpn", group: "network", glyph: "lock", name: Tr.t("VPN"), detail: Tr.t("Private networks"), cosmic: "vpn",
          words: "vpn;private network;wireguard;openvpn;rangkaian peribadi maya" },

        { id: "colours", group: "personalise", glyph: "sun", name: Tr.t("Colours"), detail: Tr.t("Dark or light, accent colour, transparency"),
          words: "personalise;personalize;peribadikan;colours;colors;accent;accent colour;dark mode;light mode;theme;transparency;warna;warna aksen;mod gelap;tema",
          keys: [Tr.t("Choose your mode"), Tr.t("Transparency effects"), Tr.t("Accent colour")] },
        { id: "background", group: "personalise", glyph: "image", name: Tr.t("Background"), detail: Tr.t("The picture behind your desktop"),
          words: "wallpaper;background;desktop background;picture;kertas dinding;latar belakang;gambar",
          keys: [Tr.t("Background")] },
        { id: "taskbar", group: "personalise", glyph: "taskbar", name: Tr.t("Taskbar"), detail: Tr.t("Layout, alignment, tray icons"),
          words: "taskbar;dock;top bar;taskbar alignment;auto-hide;tray;system tray;combine;labels;search box;widgets;transparency;layout;mac;bar tugas;dulang;label;kotak carian;ketelusan",
          keys: [Tr.t("Desktop layout"), Tr.t("Taskbar alignment"), Tr.t("Taskbar size"), Tr.t("Combine taskbar buttons and hide labels"), Tr.t("Taskbar transparency"),
                 Tr.t("Automatically hide the taskbar"), Tr.t("Taskbar items"), Tr.t("Task View button"), Tr.t("Widgets button"),
                 Tr.t("Show the taskbar on all screens"), Tr.t("Tray icons")] },
        { id: "pins", group: "personalise", glyph: "pin", name: Tr.t("Pinned apps"), detail: Tr.t("The apps on Start and the taskbar"),
          words: "pins;pinned;start;pin to taskbar;unpin;sematkan;disematkan" },
        { id: "lock", group: "personalise", glyph: "lock", name: Tr.t("Lock screen"), detail: Tr.t("Picture, clock style, depth effect"),
          words: "lock screen;clock;lock picture;depth effect;skrin kunci;jam",
          keys: [Tr.t("Picture"), Tr.t("Position"), Tr.t("Size"), Tr.t("Weight"), Tr.t("Font"), Tr.t("Style"), Tr.t("Date"), Tr.t("Depth effect")] },
        { id: "text", group: "personalise", glyph: "text", name: Tr.t("Text and contrast"), detail: Tr.t("Bigger text, high contrast"),
          words: "text size;font size;bigger text;high contrast;accessibility;saiz teks;teks besar;kontras tinggi;kebolehcapaian",
          keys: [Tr.t("Text size"), Tr.t("High contrast")] },

        { id: "installed", group: "apps", glyph: "apps", name: Tr.t("Installed apps"), detail: Tr.t("Apps on this PC"),
          words: "apps;installed apps;applications;uninstall;remove;programs and features;aplikasi;nyahpasang;buang",
          keys: [Tr.t("Find an app"), Tr.t("Get more apps from the Store")] },
        { id: "defaultapps", group: "apps", glyph: "apps", name: Tr.t("Default apps"), detail: Tr.t("Which app opens web pages, music, pictures"),
          words: "default apps;default browser;open with;email;pdf;aplikasi lalai;pelayar lalai",
          keys: [Tr.t("Web browser"), Tr.t("Email"), Tr.t("Music"), Tr.t("Video"), Tr.t("Pictures"), Tr.t("PDF files"), Tr.t("Text files")] },
        { id: "startup", group: "apps", glyph: "restart", name: Tr.t("Startup"), detail: Tr.t("Apps that start when you sign in"),
          words: "startup apps;autostart;run at login;aplikasi permulaan;mula automatik" },

        { id: "users", group: "accounts", glyph: "user", name: Tr.t("Your info and sign-in"), detail: Tr.t("Your name, picture and password; other people"),
          words: "account;users;password;sign-in options;picture;name;akaun;pengguna;kata laluan;gambar;nama",
          keys: [Tr.t("Your name"), Tr.t("Choose a picture"), Tr.t("Change your password"), Tr.t("Other people")] },

        { id: "datetime", group: "time", glyph: "clock", name: Tr.t("Date and time"), detail: Tr.t("Time zone, setting the time automatically"),
          words: "date;time;clock;time zone;ntp;tarikh;masa;jam;zon waktu",
          keys: [Tr.t("Set the time automatically"), Tr.t("Time zone")] },
        { id: "language", group: "time", glyph: "globe", name: Tr.t("Language and region"), detail: Tr.t("English or Bahasa Melayu, formats"),
          words: "language;region;formats;english;malay;bahasa melayu;bahasa;rantau",
          keys: [Tr.t("Language"), Tr.t("Regional format")] },

        { id: "privacy", group: "privacy", glyph: "shield", name: Tr.t("Privacy"), detail: Tr.t("What KrissOS keeps, the microphone, history"),
          words: "privacy;telemetry;tracking;microphone;recent files;clipboard history;history;privasi;mikrofon;sejarah",
          keys: [Tr.t("Microphone"), Tr.t("History"), Tr.t("Clear recent files"), Tr.t("Clear clipboard history")] },

        { id: "updates", group: "update", glyph: "update", name: Tr.t("Updates"), detail: Tr.t("Update now, update channel, going back"),
          words: "update;updates;upgrade;windows update;channel;testing;snapshot;rollback;kemas kini;naik taraf;saluran;petikan",
          keys: [Tr.t("Update now"), Tr.t("Update channel"), Tr.t("Go back to before an update")] }
    ]

    function find(id) { return pages.find(p => p.id === id) ?? null; }
    function group(id) { return groups.find(g => g[0] === id) ?? null; }
    function pagesIn(groupId) { return pages.filter(p => p.group === groupId); }

    // What is open: a page id, or a section's id for its list of pages; "" while the window is
    // closed. `key` is a setting to point out once the page is drawn (from search).
    property string page: ""
    property string key: ""
    // The page that was open last, for opening the window again where it was.
    property string last: "display"
    onPageChanged: if (page) { last = page; Desktop.opened(); }

    // Open a page, a section, or ("") where the window was last; a COSMIC page runs COSMIC Settings.
    function open(id, key) {
        const p = find(id);
        if (p?.cosmic) {
            Quickshell.execDetached(["cosmic-settings", p.cosmic]);
            return;
        }
        root.key = key ?? "";
        page = p || group(id) ? id : last;
    }
    function close() { page = ""; key = ""; }

    // Search: the pages by name and words, and each setting on the shell's own pages by name,
    // best first. Each result: {id, key, name, path}.
    function search(q) {
        q = q.trim();
        if (!q) return [];
        const out = [];
        for (const p of pages) {
            const where = group(p.group)[2];
            const s = Math.max(Fuzzy.score(p.name, q), ...p.words.split(";").map(w => Fuzzy.score(w, q) - 100).filter(x => x >= 500));
            if (s > 0) out.push({ id: p.id, key: "", name: p.name, path: where, score: s + 50, glyph: p.glyph });
            for (const k of p.keys ?? []) {
                const ks = Fuzzy.score(k, q);
                if (ks >= 500 && k !== p.name) out.push({ id: p.id, key: k, name: k, path: where + " › " + p.name, score: ks, glyph: p.glyph });
            }
        }
        return out.sort((a, b) => b.score - a.score).slice(0, 12);
    }
}
