pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "WidgetCatalog.js" as Catalog
import "WidgetGrid.js" as Grid
import "WidgetState.js" as State
import "WidgetDesktopLayout.js" as DesktopLayout

Singleton {
    id: root

    readonly property string statePath: (Quickshell.env("HOME") || "") + "/.config/quickshell/lucidprefs/widgets.json"

    property bool sidebarOpen: false
    property bool loaded: false
    property var internalState: State.defaultState()

    readonly property var state: State.normalize(internalState)
    readonly property var cards: state.cards
    readonly property string sidebarSide: state.sidebarSide
    readonly property bool gridSnapEnabled: state.gridSnapEnabled
    readonly property string clockStyle: state.clockStyle
    readonly property string musicStyle: state.musicStyle
    readonly property string preferredNetInterface: state.preferredNetInterface
    readonly property string preferredDiskDevice: state.preferredDiskDevice
    readonly property var cardIds: Catalog.ids()
    readonly property var sidebarCardIds: State.activeSidebarIds(state)
    readonly property var desktopCardIds: State.activeDesktopIds(state)

    signal cardStateChanged(string cardId)
    signal layoutResetRequested()

    FileView {
        id: storeFile
        path: root.statePath
        blockLoading: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const raw = text().trim();
                if (raw !== "") {
                    root.internalState = State.normalize(JSON.parse(raw));
                }
            } catch (e) {
                console.warn("[WidgetStore] Failed to parse state:", e);
            }
            root.loaded = true;
            root.syncTelemetryHold();
        }
        onLoadFailed: {
            root.loaded = true;
            root.syncTelemetryHold();
        }
    }

    Timer {
        id: saveDebounce
        interval: 150
        repeat: false
        onTriggered: {
            if (!root.loaded) return;
            storeFile.setText(JSON.stringify(root.state, null, 2) + "\n");
        }
    }

    function persist(nextState, changedId) {
        const normalized = State.normalize(nextState);
        root.internalState = normalized;
        if (changedId) root.cardStateChanged(String(changedId));
        root.syncTelemetryHold();
        saveDebounce.restart();
        return true;
    }

    function syncTelemetryHold() {
        WidgetTelemetry.hold("sidebar", root.sidebarOpen);
        WidgetTelemetry.hold("desktop", root.desktopCardIds.length > 0);
    }

    Component.onCompleted: {
        // Trigger initial FileView read; if file does not exist yet mark loaded cleanly
        Qt.callLater(() => {
            if (!root.loaded) {
                root.loaded = true;
                root.syncTelemetryHold();
            }
        });
    }

    function toggleSidebar() {
        sidebarOpen = !sidebarOpen;
        syncTelemetryHold();
        return sidebarOpen ? "OPEN" : "CLOSED";
    }

    function openSidebar() {
        sidebarOpen = true;
        syncTelemetryHold();
        return "OPEN";
    }

    function closeSidebar() {
        sidebarOpen = false;
        syncTelemetryHold();
        return "CLOSED";
    }

    function card(cardId) {
        return root.cards[String(cardId)] || null;
    }

    function cardSize(cardId) {
        return Catalog.sizeFor(String(cardId));
    }

    function sidebarAnchor(cardId) {
        const c = root.card(cardId);
        return c ? c.sidebar : null;
    }

    function desktopIdsForScreen(screenName, screenNames) {
        return State.desktopIdsForScreen(root.state, String(screenName || ""), screenNames || []);
    }

    function setSidebarLayout(layout) {
        const active = root.sidebarCardIds;
        if (!Grid.validateLayout(layout, active)) return false;
        return root.persist(State.setSidebarLayout(root.internalState, layout), "");
    }

    function setContainer(cardId, container, screenName, xNorm, yNorm) {
        const id = String(cardId);
        return root.persist(State.setContainer(root.internalState, id, container, screenName, xNorm, yNorm), id);
    }

    function setDesktopPositions(positions) {
        return root.persist(State.setDesktopPositions(root.internalState, positions), "");
    }

    function pinToDesktop(cardId, screenName) {
        const id = String(cardId);
        const targetScreen = String(screenName || "");
        const host = WidgetDragSession.hostFor(targetScreen);
        const hostW = host && host.width > 100 ? Number(host.width) : 1600;
        const hostH = host && host.height > 100 ? Number(host.height) : 1000;
        const topInset = 46;
        const availH = Math.max(1, hostH - topInset);
        const sz = Catalog.sizeFor(id);

        const occupied = [];
        root.desktopCardIds.forEach(existingId => {
            if (existingId === id) return;
            const c = root.card(existingId);
            if (!c) return;
            if (targetScreen && c.screenName && c.screenName !== targetScreen) return;
            const esz = Catalog.sizeFor(existingId);
            const pt = State.screenPoint(c.desktop.xNorm, c.desktop.yNorm, hostW, hostH, esz.width, esz.height);
            const yRel = Math.max(0, pt.y - topInset);
            occupied.push({
                id: existingId,
                x: pt.x,
                y: yRel,
                width: esz.width,
                height: esz.height
            });
        });

        const desired = {
            id: id,
            x: 24,
            y: 16,
            width: sz.width,
            height: sz.height
        };
        const found = DesktopLayout.gridNearestFree(
            desired, occupied, hostW, availH,
            Math.max(DesktopLayout.desktopCardGap, 16), Catalog.cardGridStep
        );
        const placedX = found ? found.x : 24;
        const placedY = topInset + (found ? found.y : 16);
        const norm = State.normalizedPosition(placedX, placedY, hostW, hostH);
        return root.setContainer(id, "desktop", targetScreen, norm.xNorm, norm.yNorm);
    }

    function returnAllToSidebar() {
        const next = State.copy(root.state);
        Object.keys(next.cards).forEach(id => {
            next.cards[id].container = "sidebar";
        });
        const active = State.activeSidebarIds(next);
        const hydrated = Grid.defaultLayout(active, {});
        const committed = State.setSidebarLayout(next, hydrated);
        root.persist(committed, "");
        root.layoutResetRequested();
    }

    function resetSidebarLayout() {
        const next = State.copy(root.state);
        const active = State.activeSidebarIds(next);
        const hydrated = Grid.defaultLayout(active, {});
        const committed = State.setSidebarLayout(next, hydrated);
        root.persist(committed, "");
        root.layoutResetRequested();
    }

    function toggleGridSnap() {
        const next = State.copy(root.state);
        next.gridSnapEnabled = !next.gridSnapEnabled;
        root.persist(next, "");
    }

    function toggleSidebarSide() {
        const next = State.copy(root.state);
        next.sidebarSide = next.sidebarSide === "left" ? "right" : "left";
        root.persist(next, "");
    }

    function toggleClockStyle() {
        const next = State.copy(root.state);
        next.clockStyle = next.clockStyle === "cookie" ? "digital" : "cookie";
        root.persist(next, "time");
    }

    function toggleMusicStyle() {
        const next = State.copy(root.state);
        next.musicStyle = next.musicStyle === "sticker" ? "card" : "sticker";
        root.persist(next, "music");
    }

    function setPreferredNetInterface(iface) {
        const next = State.copy(root.state);
        next.preferredNetInterface = String(iface || "");
        root.persist(next, "network");
    }

    function setPreferredDiskDevice(dev) {
        const next = State.copy(root.state);
        next.preferredDiskDevice = String(dev || "");
        root.persist(next, "storage");
    }
}
