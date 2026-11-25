.pragma library

var GAP_MIN = 3.5;

function parseTime(m, s, f) {
    var t = Number(m) * 60 + Number(s);
    if (f !== undefined && f !== "")
        t += Number(f) / Math.pow(10, f.length);
    return t;
}

function squash(s) {
    return String(s).replace(/\s+/g, " ").trim();
}

var NOTICE_CJK = /\u7eaf\u97f3\u4e50|\u7d14\u97f3\u6a02|(\u6ca1|\u6c92)\u6709(\u586b\u8bcd|\u586b\u8a5e|\u6b4c\u8bcd|\u6b4c\u8a5e)|(\u6682|\u66ab)(\u65e0|\u7121)\u6b4c(\u8bcd|\u8a5e)|(\u65e0|\u7121)\u6b4c(\u8bcd|\u8a5e)|\u8bf7(\u60a8)?\u6b23\u8d4f|\u8acb(\u60a8)?\u6b23\u8cde/;
var NOTICE_EN = /\b(instrumental|pure music|no lyrics|without lyrics|no words|lyrics? (is |are )?(not|un)available)\b/i;

function isNoLyricsNotice(lines) {
    var n = 0;
    var total = 0;
    var joined = "";
    for (var i = 0; i < (lines ? lines.length : 0); i++) {
        var s = lines[i] && lines[i].text ? String(lines[i].text) : "";
        if (s === "") continue;
        n++;
        total += s.length;
        joined += s + " ";
    }
    if (n === 0 || n > 4 || total > 60) return false;
    return NOTICE_CJK.test(joined) || NOTICE_EN.test(joined);
}

function isAdlibLine(text) {
    var s = String(text);
    var rest = s.replace(/\([^)]*\)|\uff08[^\uff09]*\uff09/g, "");
    if (rest === s) return false;
    return rest.replace(/[\s\u3000.,!?~\-\u2013\u2014\u2026\u3001\u3002\uff01\uff1f\u266a\u266b]+/g, "") === "";
}

function isCjk(c) {
    return (c >= 0x3040 && c <= 0x30ff) || (c >= 0x3400 && c <= 0x4dbf) || (c >= 0x4e00 && c <= 0x9fff)
        || (c >= 0xf900 && c <= 0xfaff) || (c >= 0xff66 && c <= 0xff9f) || (c >= 0xac00 && c <= 0xd7af);
}

function isMark(c) {
    return (c >= 0x3000 && c <= 0x303f) || (c >= 0xff01 && c <= 0xff0f) || (c >= 0xff1a && c <= 0xff20)
        || c === 0x2026 || c === 0x2014 || c === 0x2019 || c === 0x2018;
}

function tokens(text) {
    var s = String(text === undefined || text === null ? "" : text);
    var out = [];
    var cur = "";
    var curCjk = false;
    var gap = false;
    var paren = false;
    function flush() {
        if (cur !== "") {
            var tok = { s: cur, gap: gap };
            if (paren) tok.adlib = true;
            out.push(tok);
            gap = false;
        }
        cur = "";
        curCjk = false;
    }
    for (var i = 0; i < s.length; i++) {
        var ch = s.charAt(i);
        var c = s.charCodeAt(i);
        if (ch === "(" || c === 0xff08) {
            flush();
            paren = true;
            continue;
        }
        if (ch === ")" || c === 0xff09) {
            flush();
            paren = false;
            continue;
        }
        if (/\s/.test(ch)) {
            flush();
            if (out.length > 0) gap = true;
            continue;
        }
        if (isMark(c) && cur !== "") {
            cur += ch;
            continue;
        }
        if (isCjk(c)) {
            if (cur !== "" && !curCjk) flush();
            cur += ch;
            curCjk = true;
            var left = 0;
            for (var j = i + 1; j < s.length && isCjk(s.charCodeAt(j)); j++) left++;
            if (cur.length >= 3 && left !== 1 && left !== 0) flush();
            continue;
        }
        if (curCjk) flush();
        cur += ch;
    }
    flush();
    return out;
}

function isKana(c) {
    return (c >= 0x3041 && c <= 0x30ff && c !== 0x30fb) || (c >= 0xff66 && c <= 0xff9f);
}

function isSmallKana(c) {
    return c === 0x3041 || c === 0x3043 || c === 0x3045 || c === 0x3047 || c === 0x3049
        || c === 0x3083 || c === 0x3085 || c === 0x3087 || c === 0x308e
        || c === 0x30a1 || c === 0x30a3 || c === 0x30a5 || c === 0x30a7 || c === 0x30a9
        || c === 0x30e3 || c === 0x30e5 || c === 0x30e7 || c === 0x30ee
        || c === 0x3095 || c === 0x3096 || c === 0x30f5 || c === 0x30f6;
}

function hasKana(s) {
    for (var i = 0; i < s.length; i++) {
        if (isKana(s.charCodeAt(i))) return true;
    }
    return false;
}

function latinSyllables(w) {
    var s = String(w).toLowerCase().replace(/[^a-z0-9\u00e0-\u00ff]/g, "");
    if (s === "") return 0;
    if (/^[0-9]+$/.test(s)) return s.length;
    var groups = s.match(/[aeiouy\u00e0-\u00e6\u00e8-\u00ef\u00f2-\u00f6\u00f9-\u00fc]+/g);
    var n = groups ? groups.length : 0;
    if (n > 1 && /[^aeiouy]e$/.test(s) && !/[^aeiouy]le$/.test(s)) n--;
    else if (n > 1 && /[^aeiouydt]ed$/.test(s)) n--;
    return Math.max(1, n);
}

function wordUnits(s, kanjiW) {
    var str = String(s);
    var total = 0;
    var run = "";
    for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i);
        var cjk = isCjk(c);
        if (!cjk) {
            if (!isMark(c)) run += str.charAt(i);
            continue;
        }
        if (run !== "") {
            total += latinSyllables(run);
            run = "";
        }
        if (isSmallKana(c)) continue;
        if (isKana(c) || (c >= 0xac00 && c <= 0xd7af)) total += 1;
        else total += kanjiW;
    }
    if (run !== "") total += latinSyllables(run);
    return total;
}

function kanjiWeight(toks) {
    var all = "";
    for (var i = 0; i < toks.length; i++) all += toks[i].s;
    return hasKana(all) ? 2 : 1;
}

var ADLIB_SHARE = 0.6;

function lineUnits(text) {
    var toks = tokens(text);
    var kw = kanjiWeight(toks);
    var total = 0;
    for (var i = 0; i < toks.length; i++)
        total += wordUnits(toks[i].s, kw) * (toks[i].adlib ? ADLIB_SHARE : 1);
    return total;
}

var DEFAULT_RATE = 4.2;

function songRate(lines) {
    var rates = [];
    for (var i = 0; i < (lines ? lines.length : 0); i++) {
        var l = lines[i];
        if (!l || l.text === "") continue;
        var u = lineUnits(l.text);
        if (u < 3) continue;
        var dur = -1;
        if (l.end !== undefined && l.end > l.t) {
            dur = l.end - l.t;
        } else {
            var nx = lines[i + 1];
            if (nx && nx.text !== "" && nx.t - l.t >= 0.8 && nx.t - l.t <= 6.5)
                dur = (nx.t - l.t) * 0.92;
        }
        if (dur > 0.5 && dur <= 12) rates.push(u / dur);
    }
    if (rates.length < 4) return DEFAULT_RATE;
    rates.sort(function(a, b) { return a - b; });
    return Math.max(2.0, Math.min(9.0, rates[rates.length >> 1]));
}

var OVERLAP_BELOW = 0.65;
var MAX_OVERLAP = 1.5;

function sungSpan(text, room, rate, known) {
    var roomOk = isFinite(room) && room > 0;
    if (known !== undefined && known > 0)
        return roomOk ? Math.min(known, room + 2) : known;
    var r = rate > 0 ? rate : DEFAULT_RATE;
    var raw = lineUnits(text) / r;
    var want = (raw + 0.25) * 1.2;
    if (!roomOk) return want;
    var span = Math.min(room * 0.92, want);
    if (room < raw * OVERLAP_BELOW)
        span = Math.max(span, Math.min(raw * 0.9, room + MAX_OVERLAP));
    return Math.max(span, Math.min(room, 0.4));
}

function foldEchoes(lines) {
    if (!lines || lines.length < 2) return lines || [];
    var rate = songRate(lines);
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        var p = out.length > 0 ? out[out.length - 1] : null;
        if (l.adlib && p && p.text !== "" && !p.adlib && l.t - p.t >= 0.15) {
            var overlaps = p.end !== undefined
                ? l.t < p.end - 0.3
                : l.t < p.t + 0.6 * lineUnits(p.text) / rate;
            if (overlaps) {
                var np = {};
                for (var key in p) np[key] = p[key];
                np.bg = p.bg ? { t: p.bg.t, text: p.bg.text + " " + l.text } : { t: l.t, text: l.text };
                out[out.length - 1] = np;
                continue;
            }
        }
        out.push(l);
    }
    return out;
}

function tokenWeights(toks) {
    var kw = kanjiWeight(toks);
    var w = [];
    var lastMain = -1;
    for (var i = 0; i < toks.length; i++) {
        w.push((wordUnits(toks[i].s, kw) + 0.35) * (toks[i].adlib ? ADLIB_SHARE : 1));
        if (!toks[i].adlib) lastMain = i;
    }
    if (lastMain > 0) w[lastMain] *= 1.3;
    return w;
}

function spans(toks, t0, dur) {
    var w = tokenWeights(toks);
    var total = 0;
    for (var i = 0; i < w.length; i++) total += w[i];
    if (total <= 0) return [];
    var out = [];
    var acc = 0;
    for (var k = 0; k < toks.length; k++) {
        out.push({ from: t0 + dur * acc / total, to: t0 + dur * (acc + w[k]) / total });
        acc += w[k];
    }
    return out;
}

function spansFor(toks, t0, dur, marks) {
    if (!marks || marks.length === 0 || toks.length === 0)
        return spans(toks, t0, dur);
    var t1 = t0 + dur;
    var starts = [];
    var off = 0;
    for (var i = 0; i < toks.length; i++) {
        starts.push(off);
        off += toks[i].s.length;
    }
    var total = off;
    function timeAt(cs) {
        var j = -1;
        for (var m = 0; m < marks.length; m++) {
            if (marks[m].cs <= cs) j = m;
            else break;
        }
        if (j < 0) {
            var f = marks[0];
            return f.cs > 0 ? t0 + (f.t - t0) * cs / f.cs : t0;
        }
        var a = marks[j];
        var nxt = marks[j + 1];
        var bT = Math.max(a.t, nxt ? nxt.t : t1);
        var bC = nxt ? nxt.cs : total;
        if (bC <= a.cs) return a.t;
        return a.t + (bT - a.t) * (cs - a.cs) / (bC - a.cs);
    }
    var out = [];
    var prev = t0;
    for (var k = 0; k < toks.length; k++) {
        var from = Math.max(prev, timeAt(starts[k]));
        var to = Math.max(from, k + 1 < toks.length ? timeAt(starts[k + 1]) : t1);
        out.push({ from: from, to: to });
        prev = from;
    }
    return out;
}

function lineIndexAt(lines, t) {
    var lo = 0;
    var hi = lines.length - 1;
    var ans = -1;
    while (lo <= hi) {
        var mid = (lo + hi) >> 1;
        if (lines[mid].t <= t) {
            ans = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return ans;
}

function smooth(u) {
    u = Math.max(0, Math.min(1, u));
    return u * u * (3 - 2 * u);
}

var RUSH_LEAD = 0.3;

function cursor(lines, t, lead, rush) {
    var i = lineIndexAt(lines, t);
    if (i + 1 < lines.length) {
        var nextT = lines[i + 1].t;
        var room = i >= 0 ? nextT - lines[i].t : Infinity;
        var ahead = rush > 0 ? lead * (1 + RUSH_LEAD * Math.min(1, rush)) : lead;
        var ld = Math.min(ahead, Math.max(0.05, room * 0.4));
        if (t > nextT - ld)
            return i + smooth((t - (nextT - ld)) / ld);
    }
    return i;
}

var POSES = [
    { d: -2, y: -118, s: 0.42, o: 0,    r: 4.8 },
    { d: -1, y: -62,  s: 0.58, o: 0.34, r: 2.4 },
    { d: 0,  y: 0,    s: 1,    o: 1,    r: 0 },
    { d: 1,  y: 68,   s: 0.66, o: 0.60, r: -2.4 },
    { d: 2,  y: 122,  s: 0.46, o: 0,    r: -4.8 }
];

function blend(table, d) {
    if (d <= table[0].d)
        return { y: table[0].y, scale: table[0].s, opacity: table[0].o, rot: table[0].r };
    var last = table[table.length - 1];
    if (d >= last.d)
        return { y: last.y, scale: last.s, opacity: last.o, rot: last.r };
    for (var i = 0; i < table.length - 1; i++) {
        var a = table[i];
        var b = table[i + 1];
        if (d >= a.d && d <= b.d) {
            var u = smooth((d - a.d) / (b.d - a.d));
            return {
                y: a.y + (b.y - a.y) * u,
                scale: a.s + (b.s - a.s) * u,
                opacity: a.o + (b.o - a.o) * u,
                rot: a.r + (b.r - a.r) * u
            };
        }
    }
    return { y: 0, scale: 1, opacity: 1, rot: 0 };
}

function pose(d) {
    return blend(POSES, d);
}

function leaveAt(startT, nextT, lead) {
    var room = nextT - startT;
    return nextT - Math.min(lead, Math.max(0.05, room * 0.4));
}

function overrun(end, from) {
    if (!isFinite(end) || !isFinite(from)) return 0;
    return Math.max(0, end - from);
}

var RUSH_FROM = 0.04;
var RUSH_FULL = 0.3;

function rushOf(over) {
    return smooth((over - RUSH_FROM) / (RUSH_FULL - RUSH_FROM));
}

var HOLD_TAIL = 0.12;
var RELEASE = 0.6;

function hold(t, end, rush) {
    if (!(rush > 0)) return 0;
    return Math.min(1, rush) * (1 - smooth((t - end - HOLD_TAIL) / RELEASE));
}

var HELD_POSES = [
    { d: -2, y: -118, s: 0.42, o: 0,    r: 4.8 },
    { d: -1, y: -76,  s: 0.64, o: 0.80, r: 2.4 },
    { d: 0,  y: 0,    s: 1,    o: 1,    r: 0 },
    { d: 1,  y: 68,   s: 0.66, o: 0.60, r: -2.4 },
    { d: 2,  y: 122,  s: 0.46, o: 0,    r: -4.8 }
];

function takeover(d, h) {
    var a = pose(d);
    if (!(h > 0)) return a;
    var b = blend(HELD_POSES, d);
    var k = Math.min(1, h);
    return {
        y: a.y + (b.y - a.y) * k,
        scale: a.scale + (b.scale - a.scale) * k,
        opacity: a.opacity + (b.opacity - a.opacity) * k,
        rot: a.rot + (b.rot - a.rot) * k
    };
}

var LANDING = 0.38;

function landing(tau, rush) {
    if (!(rush > 0) || !(tau > 0) || tau >= LANDING) return 0;
    var s = Math.sin(Math.PI * tau / LANDING);
    return Math.min(1, rush) * s * s;
}

function fit(naturalW, maxW) {
    if (naturalW <= 0 || naturalW <= maxW) return 1;
    return Math.max(0.55, maxW / naturalW);
}

function wordAt(sp, t) {
    var ans = -1;
    for (var i = 0; i < sp.length; i++) {
        if (sp[i] === undefined) break;
        if (sp[i].from <= t) ans = i;
        else break;
    }
    return ans;
}

function hop(sp, k, t) {
    if (k < 0 || k >= sp.length - 1 || sp[k] === undefined || sp[k + 1] === undefined) return 0;
    var a = sp[k].from;
    var b = sp[k + 1].from;
    if (b <= a) return 0;
    return Math.max(0, Math.min(1, (t - a) / (b - a)));
}

function arch(p) {
    return 4 * p * (1 - p);
}

function hit(sp, k, t) {
    if (k < 0 || k >= sp.length || sp[k] === undefined || t < sp[k].from) return 0;
    return Math.max(0, 1 - (t - sp[k].from) / 0.22);
}

function sung(span, t) {
    if (span.to <= span.from) return t >= span.to ? 1 : 0;
    return Math.max(0, Math.min(1, (t - span.from) / (span.to - span.from)));
}

function mainIndexes(toks) {
    var out = [];
    var i;
    for (i = 0; i < toks.length; i++) {
        if (!toks[i].adlib) out.push(i);
    }
    if (out.length === 0) {
        for (i = 0; i < toks.length; i++) out.push(i);
    }
    return out;
}

var CLOCK_WINDOW = 10;

function clockReset(pos, nowMs) {
    return { pos: pos, at: nowMs, hist: [], cand: null };
}

function estimate(state, nowMs, playing) {
    if (!playing) return state.pos;
    return state.pos + (nowMs - state.at) / 1000;
}

function observe(state, polled, nowMs, playing) {
    if (!playing) return { pos: polled, at: nowMs, hist: [], cand: null };
    var o = polled - nowMs / 1000;
    var hist = state.hist || [];
    if (hist.length === 0) return { pos: polled, at: nowMs, hist: [o], cand: null };
    var d = o - (state.pos - state.at / 1000);
    if (Math.abs(d) >= 1.5) return { pos: polled, at: nowMs, hist: [o], cand: null };
    if (d < -0.35) {
        var c = state.cand;
        var n = (c && Math.abs(o - c.o) < 0.12) ? c.n + 1 : 1;
        if (n >= (d > -0.8 ? 8 : 3)) return { pos: polled, at: nowMs, hist: [o], cand: null };
        return { pos: state.pos, at: state.at, hist: hist, cand: { o: o, n: n } };
    }
    var next = hist.concat([o]);
    if (next.length > CLOCK_WINDOW) next = next.slice(next.length - CLOCK_WINDOW);
    var best = next[0];
    for (var i = 1; i < next.length; i++) {
        if (next[i] > best) best = next[i];
    }
    return { pos: best + nowMs / 1000, at: nowMs, hist: next, cand: null };
}

function pollTrust(prev, polled, stale, playing) {
    if (!playing) return { use: true, stale: 0 };
    if (Math.abs(polled - prev) < 0.001) {
        stale = stale + 1;
        return { use: stale < 3, stale: stale };
    }
    return { use: true, stale: 0 };
}

// Adapts Dynamic You LyricsService.syncedLines [{ time, text, endTime?, words? }]
// into Sekai Pop's line model [{ t, text, end?, marks?, bg?, adlib? }].
function adaptServiceLines(rawLines) {
    if (!Array.isArray(rawLines) || rawLines.length === 0) return [];
    var out = [];
    for (var i = 0; i < rawLines.length; i++) {
        var r = rawLines[i];
        if (!r) continue;
        var t = Number(r.time !== undefined ? r.time : r.t);
        if (!isFinite(t)) continue;
        var txt = squash(r.text || "");
        var entry = { t: Math.max(0, t), text: txt };
        var rEnd = Number(r.endTime !== undefined ? r.endTime : r.end);
        if (isFinite(rEnd) && rEnd > entry.t) entry.end = rEnd;
        if (txt !== "" && isAdlibLine(txt)) entry.adlib = true;

        if (Array.isArray(r.words) && r.words.length > 0) {
            var marks = [];
            var built = "";
            var lastWordEnd = -1;
            for (var w = 0; w < r.words.length; w++) {
                var wk = r.words[w];
                if (!wk || !wk.text) continue;
                var wt = Number(wk.begin !== undefined ? wk.begin : (wk.startTime !== undefined ? wk.startTime : entry.t));
                var cs = built.replace(/[\s()\uff08\uff09]/g, "").length;
                if (isFinite(wt)) marks.push({ cs: cs, t: Math.max(0, wt) });
                built += String(wk.text);
                if (w + 1 < r.words.length) {
                    built += (wk.trailingSpace !== undefined ? wk.trailingSpace : " ");
                }
                var wEnd = Number(wk.end !== undefined ? wk.end : wk.endTime);
                if (isFinite(wEnd) && wEnd > lastWordEnd) lastWordEnd = wEnd;
            }
            if (marks.length > 0) {
                entry.marks = marks;
                if (txt === "") entry.text = squash(built);
            }
            if (lastWordEnd > entry.t && entry.end === undefined) entry.end = lastWordEnd;
        }
        out.push(entry);
    }

    if (out.length === 0 || isNoLyricsNotice(out)) return [];
    out.sort(function(a, b) { return a.t - b.t; });

    // Merge simultaneous timestamps into backing vocal (bg) and fold echoes
    var merged = [];
    for (var k = 0; k < out.length; k++) {
        var cur = out[k];
        var p = merged.length > 0 ? merged[merged.length - 1] : null;
        if (p && p.text !== "" && cur.text !== "" && Math.abs(cur.t - p.t) <= 0.15) {
            var main = (p.adlib && !cur.adlib) ? cur : p;
            var side = main === p ? cur : p;
            main.bg = {
                t: Math.max(main.t, side.t),
                text: (main.bg ? main.bg.text + " " : "") + side.text
            };
            merged[merged.length - 1] = main;
            continue;
        }
        if (cur.text !== "" || (p && p.text !== "")) {
            merged.push(cur);
        }
    }

    // Insert gap indicator for long instrumental breaks (>= GAP_MIN) or intro (> 3s)
    var withGaps = [];
    for (var g = 0; g < merged.length; g++) {
        var line = merged[g];
        if (line.text === "") {
            var nextNonEmpty = Infinity;
            for (var z = g + 1; z < merged.length; z++) {
                if (merged[z].text !== "") {
                    nextNonEmpty = merged[z].t;
                    break;
                }
            }
            if (nextNonEmpty - line.t >= GAP_MIN) withGaps.push(line);
            continue;
        }
        withGaps.push(line);
        if (g + 1 < merged.length) {
            var nx = merged[g + 1];
            var lineDone = line.end !== undefined ? line.end : (line.t + 2.2);
            if (nx.text !== "" && nx.t - lineDone >= GAP_MIN + 1.5) {
                withGaps.push({ t: lineDone + 0.6, text: "" });
            }
        }
    }

    withGaps = foldEchoes(withGaps);
    if (withGaps.length > 0 && withGaps[0].text !== "" && withGaps[0].t > 3) {
        withGaps.unshift({ t: 0, text: "" });
    }
    return withGaps;
}
