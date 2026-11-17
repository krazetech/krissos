import QtQuick
import Quickshell
import Quickshell.Io
import "fuzzy.js" as Fuzzy

// What Start searches besides apps and recent files: settings pages, every file under home,
// the calculator and whether the web is reachable. It works only while Start is open: the
// file index is refreshed when Start opens (at most once an hour, at the lowest priority),
// and lookups run 120 ms after the typing stops, never per key.
Scope {
    id: root

    property string query
    property bool active

    readonly property string home: Quickshell.env("HOME")
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/kriss"

    // The helpers that are installed, looked up the first time Start opens.
    property var has: ({})
    readonly property bool plocate: !!has.plocate && !!has.updatedb
    readonly property string index: cache + (plocate ? "/files.db" : "/files.txt")

    // Online when NetworkManager says the internet is reachable; checked each time Start opens.
    property bool online: false

    // The latest answers, each with the text it was for, so a slow one never shows for newer text.
    property var files: []
    property string filesFor
    property string calcResult
    property string calcFor

    onActiveChanged: {
        if (!active) {
            files = []; filesFor = ""; calcResult = ""; calcFor = "";
            return;
        }
        if (has.done) refresh();
        else probe.running = true;
    }
    onQueryChanged: if (active) debounce.restart()

    function refresh() {
        net.running = !!has.nmcli;
        indexer.running = true;
    }

    Process {
        id: probe
        command: ["sh", "-c", "for c in qalc plocate updatedb fd nmcli wl-copy xdg-terminal-exec cosmic-term konsole; do command -v $c >/dev/null && echo $c; done; echo done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {};
                for (const c of text.split("\n")) if (c) h[c] = true;
                root.has = h;
                pages.running = true;
                if (root.active) {
                    root.refresh();
                    root.lookup();
                }
            }
        }
    }

    Process {
        id: net
        command: ["nmcli", "-t", "networking", "connectivity"]
        stdout: StdioCollector { onStreamFinished: root.online = text.trim() === "full" }
    }

    // The file index: plocate's own database of home when plocate is installed (updatedb
    // runs fine without root when it writes its own file), else a plain list from fd or find.
    // Hidden folders are left out, as Windows search leaves out AppData.
    Process {
        id: indexer
        command: ["sh", "-c", `
            c=$1; out=$2; mkdir -p "$c" || exit
            [ -n "$(find "$out" -mmin -60 2>/dev/null)" ] && exit 0
            low="nice -n19 ionice -c3"
            case $3 in
            plocate)
                set --
                for d in "$HOME"/.[!.]*/; do [ -d "$d" ] && set -- "$@" "\${d%/}"; done
                $low updatedb -l 0 -U "$HOME" -o "$out.new" --add-prunepaths "$*" \\
                    --prunenames ".git .hg .svn .cache .venv venv node_modules __pycache__" ;;
            fd) $low fd . "$HOME" > "$out.new" ;;
            *) $low find "$HOME" -mindepth 1 \\( -name '.*' -o -name node_modules \\) -prune -o -print > "$out.new" ;;
            esac && mv -f "$out.new" "$out"`,
            "sh", root.cache, root.index, root.plocate ? "plocate" : root.has.fd ? "fd" : "find"]
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.lookup()
    }

    function lookup() {
        const q = query.trim();
        // Files: two letters at least, and not a command.
        if (q.length >= 2 && !q.startsWith(">") && has.done) {
            locate.running = false;
            const words = q.split(/\s+/);
            locate.command = plocate
                ? ["plocate", "-d", index, "-i", "-b", "-l", "300", "--", ...words]
                : ["grep", "-iF", "-m", "300", "--", words[0], index];
            locate.forQuery = q;
            locate.running = true;
        }
        // The calculator: qalc when installed, else the small one in fuzzy.js.
        const e = Fuzzy.calcExpr(q);
        if (!e) return;
        if (has.qalc) {
            calc.running = false;
            calc.command = ["sh", "-c", 'r=$(qalc -t -m 500 -s "upxrates 0" " $1" </dev/null) && printf %s "$r"', "sh", e];
            calc.forExpr = e;
            calc.running = true;
        } else {
            const v = Fuzzy.calc(e);
            calcResult = isNaN(v) ? "" : String(+v.toPrecision(12));
            calcFor = e;
        }
    }

    Process {
        id: locate
        property string forQuery
        stdout: StdioCollector {
            onStreamFinished: {
                // Leave out anything inside a hidden folder (fd and find already do).
                root.files = text.split("\n").filter(p => p && !p.slice(root.home.length).includes("/."));
                root.filesFor = locate.forQuery;
            }
        }
    }

    Process {
        id: calc
        property string forExpr
        stdout: StdioCollector {
            onStreamFinished: {
                const r = Fuzzy.calcAnswer(text);
                // An answer that only repeats the question is no answer.
                root.calcResult = r !== calc.forExpr.trim() ? r : "";
                root.calcFor = calc.forExpr;
            }
        }
    }

    // Settings: each page of COSMIC Settings, and each KDE System Settings module when KDE's
    // is installed, read once from their desktop files (they are hidden from the app list, so
    // DesktopEntries leaves them out). The COSMIC Panel and Dock pages are left out: the
    // KrissOS taskbar replaces both. Each is {id, name, nameMs, words, icon, exec}.
    property var settings: []
    Process {
        id: pages
        command: ["sh", "-c", `
            IFS=:; for d in \${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                for f in "$d"/applications/com.system76.CosmicSettings.*.desktop "$d"/applications/kcm_*.desktop; do
                    [ -f "$f" ] && awk -v id="$(basename "$f" .desktop)" -F= '
                        /^\\[/ { main = $0 == "[Desktop Entry]" } !main { next }
                        { k = $1; sub(/^[^=]*=/, "") }
                        k == "Name" { n = $0 } k == "Name[ms]" { nm = $0 } k == "Icon" { i = $0 } k == "Exec" { x = $0 }
                        k ~ /^(Keywords|GenericName|Comment)(\\[ms\\])?$/ { w = w ";" $0 }
                        END { printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n", id, n, nm, w, i, x }' "$f"
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                root.settings = text.split("\n").map(l => l.split("\t")).filter(f => {
                    if (f.length < 6 || !f[1] || !f[5] || seen[f[0]] || /\.(Panel|Dock)$/.test(f[0])) return false;
                    return seen[f[0]] = true;
                }).map(f => ({ id: f[0], name: f[1], nameMs: f[2], words: f[3].split(";").filter(w => w), icon: f[4],
                    exec: f[5].split(" ").filter(a => a && !a.startsWith("%")) }));
            }
        }
    }

    // Malay names and words, and the words Windows people search for, for the COSMIC pages,
    // which ship none of these. Keyed by the end of the desktop file id, in lower case.
    readonly property var pageWords: ({
        about: ["Perihal", "perihal;maklumat sistem;versi;nama peranti;about;system info;version;device name;pc name"],
        accessibility: ["Kebolehcapaian", "kebolehcapaian;pembesar;kontras tinggi;accessibility;ease of access;magnifier;high contrast;screen reader"],
        appearance: ["Penampilan", "penampilan;tema;mod gelap;warna;personalisasi;appearance;theme;dark mode;colours;colors;personalise;personalize"],
        applications: ["Aplikasi", "aplikasi;apps;applications;installed apps"],
        bluetooth: ["Bluetooth", "bluetooth;peranti;pasangkan;devices;pair"],
        datetime: ["Tarikh & masa", "tarikh;masa;jam;zon waktu;date;time;clock;time zone"],
        defaultapps: ["Aplikasi lalai", "aplikasi lalai;pelayar lalai;default apps;default browser;open with"],
        desktop: ["Desktop", "desktop;sudut panas;ruang kerja;hot corner"],
        displays: ["Paparan", "paparan;skrin;monitor;resolusi;skala;lampu malam;display;screen;resolution;scale;night light;refresh rate"],
        input: ["Peranti input", "input;peranti input;input devices"],
        keyboard: ["Papan kekunci", "papan kekunci;susun atur;pintasan;keyboard;layout;shortcuts;input method"],
        legacyapplications: ["Aplikasi lama", "aplikasi lama;x11;xwayland;legacy apps"],
        mouse: ["Tetikus", "tetikus;penuding;kursor;mouse;pointer;cursor;scroll"],
        network: ["Rangkaian", "rangkaian;internet;proksi;network;proxy;ethernet"],
        notifications: ["Pemberitahuan", "pemberitahuan;jangan ganggu;notifications;do not disturb;alerts"],
        power: ["Kuasa", "kuasa;bateri;tidur;penjimat kuasa;power;battery;sleep;power saver;power plan"],
        regionlanguage: ["Rantau & bahasa", "rantau;bahasa;format;region;language;formats"],
        sound: ["Bunyi", "bunyi;audio;kelantangan;pembesar suara;mikrofon;sound;volume;speakers;microphone;output"],
        startupapps: ["Aplikasi permulaan", "aplikasi permulaan;mula automatik;startup apps;autostart;run at login"],
        system: ["Sistem & akaun", "sistem;akaun;system;accounts"],
        time: ["Masa & bahasa", "masa;bahasa;time;language"],
        touchpad: ["Pad sentuh", "pad sentuh;gerak isyarat;touchpad;trackpad;gestures"],
        users: ["Pengguna", "pengguna;akaun;kata laluan;users;accounts;password;sign-in options"],
        vpn: ["VPN", "vpn;rangkaian peribadi maya;private network"],
        wallpaper: ["Kertas dinding", "kertas dinding;latar belakang;wallpaper;background;desktop background;personalise"],
        windowmanagement: ["Pengurusan tetingkap", "tetingkap;jubin;window management;windows;snap;tiling;focus"],
        wired: ["Berwayar", "berwayar;ethernet;kabel;wired;cable;lan"],
        wireless: ["Wi-Fi", "wifi;wi-fi;wayarles;tanpa wayar;internet;wireless"],
        workspaces: ["Ruang kerja", "ruang kerja;desktop maya;workspaces;virtual desktops;task view"]
    })

    function settingRows(q, malay) {
        return settings.map(e => {
            const w = pageWords[e.id.split(".").pop().toLowerCase()];
            return {
                kind: "setting", label: malay && (e.nameMs || w) ? e.nameMs || w[0] : e.name, icon: e.icon, exec: e.exec,
                detail: e.id.startsWith("kcm_") ? "KDE" : "",
                // The name may match loosely; the words and descriptions only as written (or
                // "matikan" would find Date & Time by its scattered letters), and below a name.
                score: Math.max(Fuzzy.best([e.name, e.nameMs], q),
                    ...[...e.words, ...(w ? w[1].split(";") : [])].map(x => Fuzzy.score(x, q) - 100).filter(x => x >= 500))
            };
        });
    }
}
