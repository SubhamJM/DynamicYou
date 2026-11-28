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
    readonly property real qtScale: {
        const raw = Number(Quickshell.env("QT_SCALE_FACTOR"));
        return (isFinite(raw) && raw > 0.1) ? raw : 1.0;
    }
    // Inverse Qt scale so desktop cards and Widget Deck stay 1.0x physically when shell runs at 1.2x.
    readonly property real uiScale: 1.0 / qtScale

    function s(v) {
        return Number(v) * uiScale;
    }

    function si(v) {
        return Math.max(1, Math.round(Number(v) * uiScale));
    }

    property bool sidebarOpen: false
    property bool desktopKeyboardFocus: false
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
    signal menuRequested(string cardId)
    signal desktopMenuRequested(real xPos, real yPos)
    signal desktopMenuCloseRequested()

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
        WidgetTelemetry.hold("desktop", false);
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

    function isPinned(cardId) {
        return root.desktopCardIds.indexOf(String(cardId)) !== -1;
    }

    function togglePin(cardId, screenName) {
        const id = String(cardId);
        if (isPinned(id)) {
            return root.setContainer(id, "sidebar");
        }
        return root.pinToDesktop(id, screenName);
    }

    function cardSize(cardId) {
        const id = String(cardId);
        const c = root.card(id);
        const base = Catalog.sizeFor(id, c ? c.options : null);
        return { width: base.width * uiScale, height: base.height * uiScale };
    }

    function cardOptions(cardId) {
        const c = root.card(String(cardId));
        return (c && c.options) ? c.options : ({});
    }

    function cardOption(cardId, key, fallback) {
        const opts = root.cardOptions(cardId);
        return (opts && opts[key] !== undefined) ? opts[key] : fallback;
    }

    function setCardOption(cardId, key, value) {
        const id = String(cardId);
        return root.persist(State.setCardOption(root.internalState, id, String(key), value), id);
    }

    function resetCardOptions(cardId) {
        const id = String(cardId);
        return root.persist(State.resetCardOptions(root.internalState, id), id);
    }

    function openMenu(cardId) {
        const id = String(cardId || "");
        root.menuRequested(id);
        return "OK";
    }

    function openDesktopMenu(xPos, yPos) {
        if (Number(xPos) <= -900) {
            root.desktopMenuCloseRequested();
            return "CLOSED";
        }
        root.desktopMenuRequested(Number(xPos) || 0, Number(yPos) || 0);
        return "OK";
    }

    function closeDesktopMenu() {
        root.desktopMenuCloseRequested();
        return "CLOSED";
    }

    Process {
        id: imagePickerProc
        property string targetCardId: ""
        property string targetKey: "customPath"
        stdout: StdioCollector {
            onStreamFinished: {
                const chosen = String(this.text || "").trim().split("\n")[0];
                if (chosen.indexOf("/") === 0 && imagePickerProc.targetCardId !== "") {
                    root.setCardOption(imagePickerProc.targetCardId, imagePickerProc.targetKey, chosen);
                }
                imagePickerProc.targetCardId = "";
            }
        }
    }

    function pickImageOption(cardId, optionKey) {
        if (imagePickerProc.running) return false;
        imagePickerProc.targetCardId = String(cardId || "");
        imagePickerProc.targetKey = String(optionKey || "customPath");
        const startDir = (Quickshell.env("HOME") || "") + "/Pictures";
        imagePickerProc.command = [
            "sh", "-c",
            "if command -v kdialog >/dev/null 2>&1; then " +
            "  kdialog --getopenfilename \"$1\" \"Images (*.png *.jpg *.jpeg *.webp *.gif *.avif *.bmp *.svg)\" 2>/dev/null || true; " +
            "elif command -v zenity >/dev/null 2>&1; then " +
            "  zenity --file-selection --filename=\"$1/\" --file-filter=\"Images | *.png *.jpg *.jpeg *.webp *.gif *.avif *.bmp *.svg\" 2>/dev/null || true; " +
            "fi",
            "sh", startDir
        ];
        imagePickerProc.running = true;
        return true;
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
        const hostW = host && host.width > 100 ? Number(host.width) : root.s(1920);
        const hostH = host && host.height > 100 ? Number(host.height) : root.s(1200);
        const topInset = 46;
        const sz = root.cardSize(id);
        const bottomReserve = root.sidebarOpen ? root.s(226) : root.s(24);
        const availH = Math.max(sz ? sz.height : 120, hostH - topInset - bottomReserve);

        const occupied = [];
        root.desktopCardIds.forEach(existingId => {
            if (existingId === id) return;
            const c = root.card(existingId);
            if (!c) return;
            if (targetScreen && c.screenName && c.screenName !== targetScreen) return;
            const esz = root.cardSize(existingId);
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

        const marginX = root.s(24);
        const marginY = root.s(16);
        const desired = {
            id: id,
            x: marginX,
            y: marginY,
            width: sz.width,
            height: sz.height
        };
        const found = DesktopLayout.gridNearestFree(
            desired, occupied, hostW, availH,
            Math.max(root.s(DesktopLayout.desktopCardGap), root.s(16)),
            root.s(Catalog.cardGridStep)
        );
        const placedX = found ? found.x : marginX;
        const placedY = topInset + (found ? found.y : marginY);
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
