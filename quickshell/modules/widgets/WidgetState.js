.pragma library

Qt.include("WidgetCatalog.js");
Qt.include("WidgetGrid.js");

var schemaVersion = 1;

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function clamp01(value, fallback) {
    var n = Number(value);
    if (!isFinite(n)) n = fallback;
    return Math.max(0, Math.min(1, n));
}

function safeDimension(v) { return Math.max(1, Number(v) || 1); }

function normalizedPosition(x, y, width, height) {
    return {
        xNorm: clamp01(Number(x) / safeDimension(width), 0.5),
        yNorm: clamp01(Number(y) / safeDimension(height), 0.5)
    };
}

function screenPoint(xNorm, yNorm, width, height, cardWidth, cardHeight) {
    var w = safeDimension(width);
    var h = safeDimension(height);
    var cw = Math.max(0, Number(cardWidth) || 0);
    var ch = Math.max(0, Number(cardHeight) || 0);
    return {
        x: Math.max(0, Math.min(Math.max(0, w - cw), clamp01(xNorm, 0) * w)),
        y: Math.max(0, Math.min(Math.max(0, h - ch), clamp01(yNorm, 0) * h))
    };
}

function copy(v) { return JSON.parse(JSON.stringify(v)); }

function defaultCard(def) {
    var anchor = defaultAnchorFor(def.id);
    return {
        enabled: true,
        container: "sidebar",
        screenName: "",
        sidebar: {
            x: anchor.column * (baseCellWidth + cellGap),
            y: anchor.row * (baseCellHeight + cellGap)
        },
        desktop: {
            xNorm: 0.08,
            yNorm: 0.12
        }
    };
}

function defaultState() {
    var s = {
        version: schemaVersion,
        sidebarSide: "left",
        gridSnapEnabled: true,
        clockStyle: "cookie",
        musicStyle: "sticker",
        preferredNetInterface: "",
        preferredDiskDevice: "",
        cards: {}
    };
    all().forEach(function(def) { s.cards[def.id] = defaultCard(def); });
    return s;
}

function normalize(raw) {
    var src = isObject(raw) ? raw : {};
    var srcCards = isObject(src.cards) ? src.cards : {};
    var out = {
        version: schemaVersion,
        sidebarSide: src.sidebarSide === "right" ? "right" : "left",
        gridSnapEnabled: typeof src.gridSnapEnabled === "boolean" ? src.gridSnapEnabled : true,
        clockStyle: src.clockStyle === "digital" ? "digital" : "cookie",
        musicStyle: src.musicStyle === "card" ? "card" : "sticker",
        preferredNetInterface: typeof src.preferredNetInterface === "string" ? src.preferredNetInterface : "",
        preferredDiskDevice: typeof src.preferredDiskDevice === "string" ? src.preferredDiskDevice : "",
        cards: {}
    };
    all().forEach(function(def) {
        var fb = defaultCard(def);
        var c = isObject(srcCards[def.id]) ? srcCards[def.id] : {};
        var sb = isObject(c.sidebar) ? c.sidebar : fb.sidebar;
        var dt = isObject(c.desktop) ? c.desktop : fb.desktop;
        out.cards[def.id] = {
            enabled: typeof c.enabled === "boolean" ? c.enabled : true,
            container: c.container === "desktop" ? "desktop" : "sidebar",
            screenName: typeof c.screenName === "string" ? c.screenName : "",
            sidebar: {
                x: isFinite(Number(sb.x)) ? Number(sb.x) : fb.sidebar.x,
                y: isFinite(Number(sb.y)) ? Number(sb.y) : fb.sidebar.y
            },
            desktop: {
                xNorm: clamp01(dt.xNorm, fb.desktop.xNorm),
                yNorm: clamp01(dt.yNorm, fb.desktop.yNorm)
            }
        };
    });
    return out;
}

function activeSidebarIds(state) {
    var norm = normalize(state);
    return ids().filter(function(id) {
        return norm.cards[id].enabled && norm.cards[id].container !== "desktop";
    });
}

function activeDesktopIds(state) {
    var norm = normalize(state);
    return ids().filter(function(id) {
        return norm.cards[id].enabled && norm.cards[id].container === "desktop";
    });
}

function desktopIdsForScreen(state, screenName, screenNames) {
    var norm = normalize(state);
    var first = Array.isArray(screenNames) && screenNames.length > 0 ? screenNames[0] : "";
    return activeDesktopIds(norm).filter(function(id) {
        var target = norm.cards[id].screenName;
        var resolved = (target !== "" && (!Array.isArray(screenNames) || screenNames.indexOf(target) !== -1)) ? target : first;
        return resolved === screenName;
    });
}

function setSidebarLayout(state, layout) {
    var next = copy(normalize(state));
    (Array.isArray(layout) ? layout : []).forEach(function(tile) {
        if (tile && next.cards[tile.id]) {
            next.cards[tile.id].sidebar = { x: Number(tile.x) || 0, y: Number(tile.y) || 0 };
        }
    });
    return next;
}

function setContainer(state, id, container, screenName, xNorm, yNorm) {
    var next = copy(normalize(state));
    if (!next.cards[id]) return next;
    next.cards[id].container = container === "desktop" ? "desktop" : "sidebar";
    if (typeof screenName === "string")
        next.cards[id].screenName = screenName;
    if (next.cards[id].container === "desktop" && isFinite(Number(xNorm)) && isFinite(Number(yNorm))) {
        next.cards[id].desktop = {
            xNorm: clamp01(xNorm, next.cards[id].desktop.xNorm),
            yNorm: clamp01(yNorm, next.cards[id].desktop.yNorm)
        };
    }
    return next;
}

function setDesktopPositions(state, positions) {
    var next = copy(normalize(state));
    (Array.isArray(positions) ? positions : []).forEach(function(pos) {
        if (!pos || !next.cards[pos.id]) return;
        next.cards[pos.id].desktop = {
            xNorm: clamp01(pos.xNorm, next.cards[pos.id].desktop.xNorm),
            yNorm: clamp01(pos.yNorm, next.cards[pos.id].desktop.yNorm)
        };
    });
    return next;
}
