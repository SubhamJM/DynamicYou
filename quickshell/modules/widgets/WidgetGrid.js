.pragma library

Qt.include("WidgetCatalog.js");

var schemaVersion = 1;

function gridSnap(value, maximum, step) {
    var pitch = step || cardGridStep;
    var limit = Math.max(0, Math.floor(maximum / pitch) * pitch);
    return Math.max(0, Math.min(limit, Math.round((Number(value) || 0) / pitch) * pitch));
}

function gridOverlaps(first, second, gap) {
    return first.x < second.x + second.width + gap
        && first.x + first.width + gap > second.x
        && first.y < second.y + second.height + gap
        && first.y + first.height + gap > second.y;
}

function gridEdgeCandidates(card, occupied, width, height, gap, step) {
    var maxX = Math.max(0, width - card.width);
    var maxY = Math.max(0, height - card.height);
    var xs = [];
    var ys = [];
    function add(values, value, maximum) {
        var options = step > 0
            ? [Math.floor(value / step) * step, Math.ceil(value / step) * step]
            : [value];
        options.forEach(function(option) {
            var limit = step > 0 ? Math.floor(maximum / step) * step : maximum;
            var bounded = Math.max(0, Math.min(limit, option));
            if (values.indexOf(bounded) === -1)
                values.push(bounded);
        });
    }
    add(xs, Number(card.x) || 0, maxX);
    add(ys, Number(card.y) || 0, maxY);
    add(xs, 0, maxX);
    add(ys, 0, maxY);
    add(xs, maxX, maxX);
    add(ys, maxY, maxY);
    occupied.forEach(function(rect) {
        add(xs, rect.x - card.width - gap, maxX);
        add(xs, rect.x + rect.width + gap, maxX);
        add(ys, rect.y - card.height - gap, maxY);
        add(ys, rect.y + rect.height + gap, maxY);
    });
    var points = [];
    ys.forEach(function(y) {
        xs.forEach(function(x) { points.push({ x: x, y: y, rank: points.length }); });
    });
    return points;
}

function gridNearestFree(card, occupied, width, height, gap, step) {
    if (card.width > width || card.height > height)
        return null;
    var candidates = gridEdgeCandidates(card, occupied, width, height, gap, step);
    candidates.sort(function(a, b) {
        var delta = (a.x - card.x) * (a.x - card.x) + (a.y - card.y) * (a.y - card.y)
            - (b.x - card.x) * (b.x - card.x) - (b.y - card.y) * (b.y - card.y);
        if (delta !== 0)
            return delta;
        return a.y - b.y || a.x - b.x;
    });
    for (var i = 0; i < candidates.length; i += 1) {
        var rect = {
            id: card.id,
            x: candidates[i].x,
            y: candidates[i].y,
            width: card.width,
            height: card.height
        };
        if (!occupied.some(function(other) { return gridOverlaps(rect, other, gap); }))
            return rect;
    }
    return null;
}

function idsFor(activeIds) {
    var requested = Array.isArray(activeIds) ? activeIds : ids();
    return ids().filter(function(id) { return requested.indexOf(id) !== -1; });
}

function definitions(activeIds) { return sidebarDefinitions(idsFor(activeIds)); }
function tileDefinitionFor(id) { return definitionFor(String(id)); }
function placementFor(layout, id) {
    return (Array.isArray(layout) ? layout : []).find(function(tile) { return tile.id === id; }) || null;
}

function tileAt(id, point) {
    var size = sizeFor(id);
    return { id: id, x: point.x, y: point.y, width: size.width, height: size.height };
}

function clampAnchor(definition, x, y) {
    return {
        x: gridSnap(x, canvasWidth - widthFor(definition.id), cardGridStep),
        y: gridSnap(y, Number.MAX_SAFE_INTEGER, cardGridStep)
    };
}

function withinBounds(tile) {
    return Number.isFinite(tile.x) && Number.isFinite(tile.y)
        && tile.x >= 0 && tile.y >= 0
        && tile.x % cardGridStep === 0
        && tile.y % cardGridStep === 0
        && tile.x + tile.width <= canvasWidth;
}

function validateLayout(layout, activeIds) {
    var expected = idsFor(activeIds);
    if (!Array.isArray(layout) || layout.length !== expected.length)
        return false;
    var seen = {};
    for (var i = 0; i < layout.length; i += 1) {
        var tile = layout[i];
        if (!tile || expected.indexOf(tile.id) === -1 || seen[tile.id]
                || tile.width !== widthFor(tile.id) || tile.height !== heightFor(tile.id)
                || !withinBounds(tile))
            return false;
        for (var j = 0; j < i; j += 1) {
            if (gridOverlaps(tile, layout[j], cellGap))
                return false;
        }
        seen[tile.id] = true;
    }
    return true;
}

function contentHeight(layout, activeIds) {
    var allowed = idsFor(activeIds);
    return (Array.isArray(layout) ? layout : []).reduce(function(bottom, tile) {
        return allowed.indexOf(tile.id) === -1 ? bottom : Math.max(bottom, tile.y + tile.height);
    }, baseCellHeight);
}

function compactLayout(layout, activeIds) {
    var expected = idsFor(activeIds || (layout || []).map(function(tile) { return tile.id; }));
    if (!validateLayout(layout, expected))
        return null;
    var ordered = layout.slice().sort(function(a, b) {
        return a.y - b.y || a.x - b.x || expected.indexOf(a.id) - expected.indexOf(b.id);
    });
    var placed = [];
    ordered.forEach(function(tile) {
        var y = 0;
        placed.forEach(function(above) {
            if (tile.x < above.x + above.width + cellGap
                    && tile.x + tile.width + cellGap > above.x)
                y = Math.max(y, above.y + above.height + cellGap);
        });
        placed.push(tileAt(tile.id, { x: tile.x, y: y }));
    });
    return expected.map(function(id) { return placementFor(placed, id); });
}

function place(id, anchor, occupied) {
    var fallback = defaultAnchorFor(id);
    var point = clampAnchor(
        tileDefinitionFor(id),
        anchor ? anchor.x : fallback.column * (baseCellWidth + cellGap),
        anchor ? anchor.y : fallback.row * (baseCellHeight + cellGap)
    );
    var card = tileAt(id, point);
    var bottom = occupied.reduce(function(value, tile) { return Math.max(value, tile.y + tile.height); }, point.y);
    return gridNearestFree(card, occupied, canvasWidth, bottom + cellGap + card.height, cellGap, cardGridStep);
}

function buildLayout(activeIds, savedAnchors, preferredAnchors) {
    var expected = idsFor(activeIds);
    var occupied = [];
    expected.forEach(function(id) {
        if (savedAnchors[id])
            occupied.push(tileAt(id, savedAnchors[id]));
    });
    expected.filter(function(id) { return !savedAnchors[id]; }).sort(function(a, b) {
        return Number(!!(preferredAnchors && preferredAnchors[b]))
            - Number(!!(preferredAnchors && preferredAnchors[a])) || expected.indexOf(a) - expected.indexOf(b);
    }).forEach(function(id) {
        occupied.push(place(id, preferredAnchors && preferredAnchors[id], occupied));
    });
    return compactLayout(expected.map(function(id) { return placementFor(occupied, id); }), expected);
}

function defaultLayout(activeIds, preferredAnchors) {
    return buildLayout(activeIds, {}, preferredAnchors);
}

function hydrateSaved(savedLayout, activeIds, preferredAnchors) {
    var expected = idsFor(activeIds);
    if (!savedLayout || !Array.isArray(savedLayout.tiles))
        return defaultLayout(expected, preferredAnchors);
    var anchors = {};
    var seen = {};
    var occupied = [];
    for (var i = 0; i < savedLayout.tiles.length; i += 1) {
        var saved = savedLayout.tiles[i];
        if (!saved || !tileDefinitionFor(saved.id) || seen[saved.id])
            return defaultLayout(expected, preferredAnchors);
        seen[saved.id] = true;
        var point = { x: Number(saved.x) || 0, y: Number(saved.y) || 0 };
        var tile = tileAt(saved.id, point);
        if (!withinBounds(tile))
            return defaultLayout(expected, preferredAnchors);
        if (expected.indexOf(saved.id) === -1)
            continue;
        if (occupied.some(function(other) { return gridOverlaps(tile, other, cellGap); }))
            return defaultLayout(expected, preferredAnchors);
        occupied.push(tile);
        anchors[saved.id] = point;
    }
    return buildLayout(expected, anchors, preferredAnchors);
}

function serializeLayout(layout, activeIds) {
    var expected = idsFor(activeIds);
    var source = validateLayout(layout, expected) ? compactLayout(layout, expected) : defaultLayout(expected);
    return {
        version: schemaVersion,
        tiles: expected.map(function(id) {
            var tile = placementFor(source, id);
            return { id: id, x: tile.x, y: tile.y };
        })
    };
}

function moveLayout(layout, tileId, targetX, targetY, activeIds) {
    var expected = idsFor(activeIds || (layout || []).map(function(tile) { return tile.id; }));
    if (!validateLayout(layout, expected) || expected.indexOf(tileId) === -1)
        return null;
    var moving = tileAt(tileId, clampAnchor(tileDefinitionFor(tileId), targetX, targetY));
    var occupied = [moving];
    var remaining = layout.filter(function(tile) { return tile.id !== tileId; });
    var displaced = [];
    remaining.forEach(function(tile) {
        if (gridOverlaps(tile, moving, cellGap))
            displaced.push(tile);
        else
            occupied.push(tileAt(tile.id, tile));
    });
    displaced.sort(function(a, b) {
        return b.width * b.height - a.width * a.height || expected.indexOf(a.id) - expected.indexOf(b.id);
    });
    displaced.forEach(function(tile) { occupied.push(place(tile.id, tile, occupied)); });
    return compactLayout(expected.map(function(id) { return placementFor(occupied, id); }), expected);
}
