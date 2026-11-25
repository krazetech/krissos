// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
.pragma library
// Fuzzy matching for the launcher, scored the way cmdk ranks: an exact name, then a
// prefix, then a word start, then anywhere, then the letters in order. 0 = no match.

const boundary = /[\s\-_.\/]/;

function score(text, query) {
    if (!text) return 0;
    const t = text.toLowerCase(), q = query.toLowerCase().trim();
    if (!q) return 1;
    if (t === q) return 1000;
    if (t.startsWith(q)) return 900 - t.length;
    const i = t.indexOf(q);
    if (i > 0) return (boundary.test(t[i - 1]) ? 800 : 600) - i;
    // Letters in order: a bonus for runs and for word starts, a cost for gaps.
    let s = 0, pos = 0, run = 0;
    for (const c of q) {
        if (c === " ") continue;
        const j = t.indexOf(c, pos);
        if (j < 0) return 0;
        run = j === pos ? run + 1 : 0;
        s += 10 + run * 5 + (j === 0 || boundary.test(t[j - 1]) ? 15 : 0) - Math.min(j - pos, 10);
        pos = j + 1;
    }
    return Math.max(1, Math.min(s, 500));
}

// The best score over several fields (name, generic name, keywords...).
function best(fields, query) {
    return Math.max(0, ...fields.map(f => score(f, query)));
}

// Type-ahead in a menu, as in Radix: the next label after `from` that starts with what was
// typed, wrapping round. Typing one letter again and again cycles through its labels.
// -1 when nothing matches.
function typeahead(labels, typed, from) {
    const t = typed.toLowerCase();
    const same = t.length > 1 && [...t].every(c => c === t[0]);
    const prefix = same ? t[0] : t;
    // A longer prefix may still match the current label; a new or repeated letter moves on.
    const start = same || t.length === 1 ? from + 1 : from;
    for (let k = 0; k < labels.length; k++) {
        const i = (Math.max(start, 0) + k) % labels.length;
        if (labels[i].toLowerCase().startsWith(prefix)) return i;
    }
    return -1;
}

// Start's result groups in order: the calculator first when it has an answer, then the
// group with the best match (ties keep the order given: apps, settings, commands, files),
// and the web last. Each group is {key, items}, its items already best first.
function order(groups) {
    const top = g => g.items.length ? g.items[0].score : 0;
    const pinned = { calc: -1, web: 1 };
    return groups.filter(g => g.items.length)
        .map((g, i) => ({ g, i }))
        .sort((a, b) => (pinned[a.g.key] ?? 0) - (pinned[b.g.key] ?? 0) || top(b.g) - top(a.g) || a.i - b.i)
        .map(x => x.g);
}

// What the calculator should work out, in the words qalc understands, or "" when the text is
// not a sum or a conversion: "15% of 80" → "15% * 80", "5 km in miles" → "5 km to -miles"
// (the minus asks for one unit, not "3 mi + 188 yd"), "30 c in f" → "30 °C to -°F".
function calcExpr(text) {
    let s = text.trim().replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
    // A number first (or a bracket, or a function such as sqrt(2)), and a digit somewhere.
    if (!/^([-+(.]*\d|[a-z]+\s*\()/i.test(s) || !/\d/.test(s)) return "";
    // A plain number is not a sum.
    if (/^[-+]?[\d.,\s]+$/.test(s)) return "";
    s = s.replace(/(\d)\s*%\s*of\b/gi, "$1% *");
    const conv0 = /\s(?:in|to|as|=)\s+[^\d\s][^\s]*$/i.test(s);
    // Outside a conversion, words are only functions, "pi" and "e": "2048 game" is a title.
    if (!conv0 && /[a-z]/i.test(s.replace(/[a-z]+\s*\(|\b(pi|e)\b/gi, ""))) return "";
    const temp = u => ({ c: "°C", f: "°F", k: "K" })[u.toLowerCase()] ?? u;
    const conv = s.match(/^(.*\d.*?)\s+(?:in|to|as|=)\s+([^\d\s][^\s]*)$/i);
    if (conv) {
        const from = conv[1].replace(/(\d)\s*([cfk])$/i, (_, d, u) => d + " " + temp(u));
        s = from + " to -" + temp(conv[2]);
    }
    return s;
}

// qalc's answer when it is one: a number, maybe with one unit or a currency ("120 min",
// "MYR 4.083"); qalc turns unknown words into products of units, which aren't answers.
function calcAnswer(text) {
    const r = text.trim().replace(/−/g, "-");
    return /^(?:[A-Z]{3} )?[-+]?\d[\d.,]*(?:E[-+]?\d+)?(?: ?[^\s\d()×·+][^\s()×·]*)?$/.test(r) ? r : "";
}

// A small calculator for when qalc is missing: + - * / ^ %, brackets and decimals. It reads
// the text itself (never eval). NaN when it can't.
function calc(text) {
    const toks = text.replace(/\s+/g, "").match(/\d*\.?\d+(?:e[-+]?\d+)?|[-+*/^%()]/gi);
    if (!toks || toks.join("") !== text.replace(/\s+/g, "")) return NaN;
    let i = 0;
    const peek = () => toks[i], next = () => toks[i++];
    function atom() {
        const t = next();
        if (t === "(") { const v = sum(); if (next() !== ")") throw 0; return v; }
        if (t === "-") return -atom();
        if (t === "+") return atom();
        if (t === undefined || isNaN(t)) throw 0;
        let v = parseFloat(t);
        if (peek() === "%") { next(); v /= 100; }
        return v;
    }
    function power() { const b = atom(); if (peek() === "^") { next(); return Math.pow(b, power()); } return b; }
    function product() {
        let v = power();
        while (peek() === "*" || peek() === "/") v = next() === "*" ? v * power() : v / power();
        return v;
    }
    function sum() {
        let v = product();
        while (peek() === "+" || peek() === "-") v = next() === "+" ? v + product() : v - product();
        return v;
    }
    try {
        const v = sum();
        return i === toks.length && isFinite(v) ? v : NaN;
    } catch (e) {
        return NaN;
    }
}
