.pragma library

Qt.include("WidgetCatalog.js");
Qt.include("WidgetGrid.js");

var desktopCardGap = cellGap;
var desktopCardEdgeInset = 24;

function clamp(v, mn, mx) { return Math.max(mn, Math.min(mx, v)); }

function snapPoint(x, y, cardW, cardH, canvasW, canvasH, topInset) {
    var minY = topInset || 0;
    var snappedX = gridSnap(x, Math.max(0, canvasW - cardW), cardGridStep);
    var snappedY = Math.max(minY, gridSnap(y, Math.max(minY, canvasH - cardH), cardGridStep));
    return { x: snappedX, y: snappedY };
}

function clampRect(id, x, y, w, h, canvasW, canvasH, topInset) {
    var minY = topInset || 0;
    return {
        id: String(id),
        x: clamp(Number(x) || 0, 0, Math.max(0, canvasW - w)),
        y: clamp(Number(y) || 0, minY, Math.max(minY, canvasH - h)),
        width: w,
        height: h
    };
}

function overlapsAny(rect, occupied, gap) {
    for (var i = 0; i < occupied.length; i += 1) {
        if (gridOverlaps(rect, occupied[i], gap)) return true;
    }
    return false;
}

function resolveDraggedCollision(cards, draggedId, draggedRect, canvasW, canvasH, snapEnabled, topInset) {
    var minY = topInset || 0;
    var availH = Math.max(1, canvasH - minY);
    var placedDragged = snapEnabled
        ? (function() {
            var sp = snapPoint(draggedRect.x, draggedRect.y, draggedRect.width, draggedRect.height, canvasW, canvasH, minY);
            return { id: String(draggedId), x: sp.x, y: sp.y, width: draggedRect.width, height: draggedRect.height };
        })()
        : clampRect(draggedId, draggedRect.x, draggedRect.y, draggedRect.width, draggedRect.height, canvasW, canvasH, minY);

    var occupied = [placedDragged];
    var others = (Array.isArray(cards) ? cards : []).filter(function(c) { return c.id !== String(draggedId); });
    var displaced = [];
    others.forEach(function(c) {
        var r = clampRect(c.id, c.x, c.y, c.width, c.height, canvasW, canvasH, minY);
        if (gridOverlaps(r, placedDragged, desktopCardGap)) {
            displaced.push(r);
        } else {
            occupied.push(r);
        }
    });
    displaced.forEach(function(c) {
        var shifted = { id: c.id, x: c.x, y: c.y - minY, width: c.width, height: c.height };
        var occRelative = occupied.map(function(o) {
            return { id: o.id, x: o.x, y: o.y - minY, width: o.width, height: o.height };
        });
        var found = gridNearestFree(shifted, occRelative, canvasW, availH, desktopCardGap, cardGridStep);
        if (found) {
            found.y += minY;
            occupied.push(found);
        } else {
            occupied.push(c);
        }
    });
    return occupied;
}
