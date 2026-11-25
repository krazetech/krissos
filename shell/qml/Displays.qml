pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The screens as cosmic-comp sees them (`cosmic-randr list --kdl`), and changing them.
//
// The main display: Wayland has no "primary" screen, so KrissOS uses cosmic-comp's own
// xwayland_primary flag for one. cosmic-comp saves it with the rest of the screen setup (per
// set of screens, so it survives a reboot and comes back when the same screens are plugged in),
// gives X11 games it as their primary screen, and with 0008-new-windows-on-primary.patch opens
// new windows there. The shell puts the full taskbar, Start, notifications and the sign-in
// screen on it (Desktop.primary).
Singleton {
    id: root

    // [{name, enabled, make, model, x, y, scale, transform, vrr, vrrSupport, primary, mirroring,
    //   modes: [{w, h, r (mHz), current, preferred}], w, h, r}], from the last listing.
    property var outputs: []
    readonly property var enabledOutputs: outputs.filter(o => o.enabled)
    readonly property string primary: outputs.find(o => o.primary)?.name ?? ""

    // A display's name as people know it: its maker and model, else the connector.
    function label(o) {
        const m = (o.model || "").trim();
        return m && m !== "0x0000" ? m : o.name;
    }
    // Its maker and model, e.g. "Samsung Odyssey G50SF" (the maker's first word only:
    // EDIDs say "Samsung Electric Company").
    function fullName(o) {
        const make = (o.make || "").trim().split(/\s+/)[0], name = label(o);
        return make && name !== o.name && !name.toLowerCase().includes(make.toLowerCase()) ? make + " " + name : name;
    }
    // Where a display sits next to the others that are on: "left", "right", "above", "below",
    // "middle" (others on both sides), or "" for a single display.
    function side(o) {
        const others = enabledOutputs.filter(x => x.name !== o.name && !x.mirroring);
        if (!others.length) return "";
        const c = x => { const l = logical(x); return { x: x.x + l.w / 2, y: x.y + l.h / 2 }; };
        const me = c(o), cs = others.map(c);
        const dx = cs.map(p => me.x - p.x), dy = cs.map(p => me.y - p.y);
        if (dx.some(d => d > 0) && dx.some(d => d < 0)) return "middle";
        const sx = dx.reduce((a, b) => a + b, 0), sy = dy.reduce((a, b) => a + b, 0);
        if (Math.abs(sx) >= Math.abs(sy)) return sx > 0 ? "right" : "left";
        return sy > 0 ? "below" : "above";
    }

    // Its size on the desktop, in logical pixels (scale and turning applied).
    function logical(o) {
        const turned = /90|270/.test(o.transform);
        const w = (turned ? o.h : o.w) / (o.scale || 1), h = (turned ? o.w : o.h) / (o.scale || 1);
        return { w: Math.round(w), h: Math.round(h) };
    }

    function refresh() { lister.running = true; }
    Component.onCompleted: refresh()
    Connections {
        target: Quickshell
        function onScreensChanged() { root.refresh(); }
    }

    Process {
        id: lister
        command: ["cosmic-randr", "list", "--kdl"]
        stdout: StdioCollector { onStreamFinished: { root.kdl = text; root.outputs = root.parse(text); } }
    }
    property string kdl: ""  // that listing as it came, for setPositions

    // ponytail: a line parser for the KDL cosmic-randr prints, not a KDL parser; it knows the
    // nodes that listing has.
    function parse(text) {
        const out = [];
        let o = null;
        const flag = v => v === "#true" ? true : v === "#false" ? false : v.replace(/"/g, "");
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            let m;
            if ((m = /^output "([^"]+)"(?: enabled=(#\w+))?/.exec(line))) {
                o = { name: m[1], enabled: m[2] !== "#false", make: "", model: "", x: 0, y: 0, scale: 1, transform: "normal",
                      vrr: false, vrrSupport: false, primary: false, mirroring: "", modes: [], w: 0, h: 0, r: 0 };
                out.push(o);
            } else if (!o) {
                continue;
            } else if ((m = /^description(?: make="([^"]*)")?(?: model="([^"]*)")?/.exec(line))) {
                o.make = m[1] ?? ""; o.model = m[2] ?? "";
            } else if ((m = /^position (-?\d+) (-?\d+)/.exec(line))) {
                o.x = +m[1]; o.y = +m[2];
            } else if ((m = /^scale ([\d.]+)/.exec(line))) {
                o.scale = +m[1];
            } else if ((m = /^transform "(\w+)"/.exec(line))) {
                o.transform = m[1];
            } else if ((m = /^adaptive_sync_support (\S+)/.exec(line))) {
                o.vrrSupport = flag(m[1]) !== false;
            } else if ((m = /^adaptive_sync (\S+)/.exec(line))) {
                o.vrr = flag(m[1]) !== false;
            } else if ((m = /^xwayland_primary (\S+)/.exec(line))) {
                o.primary = flag(m[1]) === true;
            } else if ((m = /^mirroring "([^"]+)"/.exec(line))) {
                o.mirroring = m[1];
            } else if ((m = /^mode (\d+) (\d+) (\d+)(.*)/.exec(line))) {
                const mode = { w: +m[1], h: +m[2], r: +m[3], current: /current=#true/.test(m[4]), preferred: /preferred=#true/.test(m[4]) };
                o.modes.push(mode);
                if (mode.current) { o.w = mode.w; o.h = mode.h; o.r = mode.r; }
            }
        }
        return out;
    }

    // Run a cosmic-randr change (or `command`), then list again. `done(ok)` is called after.
    function run(args, done, command) {
        const p = changer.createObject(root, { command: command ?? ["cosmic-randr"].concat(args) });
        p.exited.connect(code => {
            refresh();
            if (done) done(code === 0);
            p.destroy();
        });
        p.running = true;
    }
    Component {
        id: changer
        Process {
            stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("cosmic-randr:", text.trim()) }
        }
    }

    // Windows+P and Settings: "pc" (the main display only), "duplicate" (the others show the
    // main one), "extend" (every display on, side by side) or "second" (the first other one
    // only, which becomes the main display). Steps run one after another, screens being
    // turned on before others go off, so one is always lit.
    readonly property string projection: {
        const on = outputs.filter(o => o.enabled);
        if (outputs.length < 2) return "pc";
        if (on.some(o => o.mirroring)) return "duplicate";
        if (on.length > 1) return "extend";
        return on[0]?.name === (first || primary) ? "pc" : "second";
    }
    // Windows+P's "PC screen": the main display, kept while "Second screen only" makes another
    // one the main display for a while.
    // ponytail: not saved; after a restart in "Second screen only" the lit one counts as the PC's.
    property string first: ""
    onPrimaryChanged: if (primary && (!first || outputs.find(o => o.name === first)?.enabled)) first = primary
    function project(how) {
        const main = first || primary || outputs[0]?.name, others = outputs.map(o => o.name).filter(n => n !== main);
        if (!main || !others.length) return;
        const steps = [];
        if (how === "pc") {
            steps.push(["enable", main], ["xwayland", "--primary", main]);
            for (const n of others) steps.push(["disable", n]);
        } else if (how === "duplicate") {
            steps.push(["enable", main], ["xwayland", "--primary", main]);
            for (const n of others) steps.push(["mirror", n, main]);
        } else if (how === "extend") {
            for (const n of [main].concat(others)) steps.push(["enable", n]);
            steps.push(["xwayland", "--primary", main]);
        } else if (how === "second") {
            steps.push(["enable", others[0]], ["xwayland", "--primary", others[0]], ["disable", main]);
            for (const n of others.slice(1)) steps.push(["disable", n]);
        }
        const next = () => { if (steps.length) run(steps.shift(), next); };
        next();
    }

    function setPrimary(name, done) { run(["xwayland", "--primary", name], done); }
    // Places displays ([{name, x, y}]) all at once: the last listing with their positions
    // changed, applied whole with `cosmic-randr kdl`. One `position` at a time would let two
    // screens overlap on the way, and cosmic-comp then stacks them itself. It takes no negative
    // positions, so the caller moves the layout to start at 0,0.
    function setPositions(list, done) {
        let name = "";
        const text = kdl.split("\n").map(line => {
            name = line.match(/^output "([^"]+)"/)?.[1] ?? name;
            const p = list.find(x => x.name === name);
            return p && /^\s*position /.test(line) ? "  position " + Math.round(p.x) + " " + Math.round(p.y) : line;
        }).join("\n");
        run(["kdl"], done, ["sh", "-c", 'printf "%s\n" "$1" | cosmic-randr kdl', "sh", text]);
    }
    function setEnabled(name, on, done) { run([on ? "enable" : "disable", name], done); }
    // mode: {w, h, r}; any of scale, transform and vrr ("automatic" or "false") may be left out.
    function setMode(name, mode, extra, done) {
        const args = ["mode", name, String(mode.w), String(mode.h), "--refresh", (mode.r / 1000).toFixed(3)];
        if (extra?.scale) args.push("--scale", String(extra.scale));
        if (extra?.transform) args.push("--transform", extra.transform);
        if (extra?.vrr) args.push("--adaptive-sync", extra.vrr);
        run(args, done);
    }
}
