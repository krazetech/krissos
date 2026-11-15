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
