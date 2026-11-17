.pragma library
// The runtime half of the theme: checks the user's choices from shell.json, works out the
// accent's shades and when "auto" turns light or dark. Plain JS so shell/theme-check can
// test it under node.

const modes = ["dark", "light", "system", "auto"];

// "#RRGGBB" in lower case, or null. "#RGB" is widened.
function parseColor(s) {
    if (typeof s !== "string") return null;
    let m = /^#([0-9a-f]{6})$/i.exec(s.trim());
    if (m) return "#" + m[1].toLowerCase();
    m = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/i.exec(s.trim());
    return m ? ("#" + m[1] + m[1] + m[2] + m[2] + m[3] + m[3]).toLowerCase() : null;
}

function isMode(s) {
    return modes.indexOf(s) >= 0;
}

// "HH:MM" as minutes after midnight, or null.
function minutes(s) {
    const m = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(String(s ?? "").trim());
    return m ? +m[1] * 60 + +m[2] : null;
}

// Whether "auto" is light at `now` (minutes after midnight): from `light` until `dark`,
// across midnight when dark comes first. Bad or equal times fall back to 07:00 / 19:00.
function lightAt(now, light, dark) {
    let l = minutes(light), d = minutes(dark);
    if (l === null || d === null || l === d) { l = 7 * 60; d = 19 * 60; }
    return l < d ? now >= l && now < d : now >= l || now < d;
}

function rgb(hex) {
    const n = parseInt(hex.slice(1), 16);
    return [n >> 16 & 255, n >> 8 & 255, n & 255];
}

function hex(c) {
    return "#" + c.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("");
}

// a moved t of the way to b, both "#RRGGBB".
function mix(a, b, t) {
    const x = rgb(a), y = rgb(b);
    return hex(x.map((v, i) => v + (y[i] - v) * t));
}

function luminance(c) {
    const l = rgb(c).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2];
}

// WCAG contrast ratio, 1 to 21.
function contrast(a, b) {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// The accent darkened or lightened (towards `ink`) in small steps until it stands
// out from `bg` by `ratio`: a fill or ring on a light window needs a deeper colour.
function ensureContrast(c, bg, ratio, ink) {
    for (let t = 0; t <= 1; t += 0.02) {
        const out = mix(c, ink, t);
        if (contrast(out, bg) >= ratio) return out;
    }
    return ink;
}

// What every surface needs from the accent: the colour itself for this mode (lightened on
// dark windows, deepened on light ones, only as far as 3:1 needs), the text
// on it (black or white, whichever reads better), and hover and pressed shades. Hover
// moves away from the text colour so it never reads worse; pressed goes the other way,
// only a little.
function shades(accent, dark, darkBg, lightBg) {
    const base = dark ? ensureContrast(accent, darkBg, 3, "#ffffff") : ensureContrast(accent, lightBg, 3, "#000000");
    const ink = contrast(base, "#000000") >= contrast(base, "#ffffff") ? "#000000" : "#ffffff";
    const away = ink === "#000000" ? "#ffffff" : "#000000";
    return { accent: base, ink: ink, hover: mix(base, away, 0.12), pressed: mix(base, ink, 0.1) };
}
