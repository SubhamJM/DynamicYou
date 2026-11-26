import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog
import "WidgetState.js" as State
import "WidgetDesktopLayout.js" as DesktopLayout

Variants {
    id: hosts

    property var notchRoot: null
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property var notchRoot: hosts.notchRoot
        readonly property string screenKey: String(modelData.name || "")
        readonly property real topInset: 46

        readonly property var screenNames: {
            const out = [];
            for (let i = 0; i < Quickshell.screens.length; i++) {
                out.push(String(Quickshell.screens[i].name || ""));
            }
            return out;
        }

        readonly property var desktopIds: {
            const _cards = WidgetStore.cards;
            return _cards ? WidgetStore.desktopIdsForScreen(win.screenKey, win.screenNames) : [];
        }
        readonly property bool visualiserPinned: win.desktopIds.indexOf("bgVisualiser") !== -1
        readonly property var cardDesktopIds: win.desktopIds.filter(id => id !== "bgVisualiser")

        readonly property bool ownsExternalGhost: WidgetDragSession.presentationActive
            && WidgetDragSession.screenName === win.screenKey
            && WidgetDragSession.presentationGhostRect.valid

        property string draggingTileId: ""
        property var dragPreviewPositions: ({})
        property var highlightRect: null

        property string menuTileId: ""
        property real menuX: 0
        property real menuY: 0
        property bool desktopMenuOpen: false
        property real desktopMenuX: 0
        property real desktopMenuY: 0

        function slotItemFor(index) {
            return slotRepeater.itemAt(index);
        }

        function currentCardRects() {
            const list = [];
            win.cardDesktopIds.forEach(id => {
                const c = WidgetStore.card(id);
                const sz = WidgetStore.cardSize(id);
                if (!c) return;
                const pt = State.screenPoint(c.desktop.xNorm, c.desktop.yNorm, win.width, win.height, sz.width, sz.height);
                list.push({
                    id: id,
                    x: pt.x,
                    y: Math.max(win.topInset, pt.y),
                    width: sz.width,
                    height: sz.height
                });
            });
            return list;
        }

        readonly property var externalRects: {
            if (!win.ownsExternalGhost || win.width <= 0 || win.height <= 0) return [];
            const g = WidgetDragSession.presentationGhostRect;
            return desktopCanvas.resolveDesktopDrop(WidgetDragSession.tileId, g.x, g.y, g.width, g.height);
        }

        readonly property bool desktopRightClickEnabled: (typeof Prefs === "undefined") || Prefs.desktopMenu !== false
        readonly property bool hostActive: !(win.notchRoot && win.notchRoot.isWindowFullscreen && !win.notchRoot.fullscreenHoverRevealed && !WidgetStore.sidebarOpen && win.menuTileId === "" && !win.desktopMenuOpen)
        visible: desktopRightClickEnabled || win.desktopIds.length > 0 || win.ownsExternalGhost || win.desktopMenuOpen || win.menuTileId !== ""
        screen: modelData
        WlrLayershell.layer: (win.menuTileId !== "" || WidgetStore.desktopKeyboardFocus) ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-desktop-widgets"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: (win.menuTileId !== "" || WidgetStore.desktopKeyboardFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Static per-catalog-index mask regions + desktop backdrop + context menu regions
        mask: Region {
            Region { item: win.desktopRightClickEnabled ? desktopBackdrop : null }
            Region { item: win.cardDesktopIds.length > 0 ? win.slotItemFor(0) : null }
            Region { item: win.cardDesktopIds.length > 1 ? win.slotItemFor(1) : null }
            Region { item: win.cardDesktopIds.length > 2 ? win.slotItemFor(2) : null }
            Region { item: win.cardDesktopIds.length > 3 ? win.slotItemFor(3) : null }
            Region { item: win.cardDesktopIds.length > 4 ? win.slotItemFor(4) : null }
            Region { item: win.cardDesktopIds.length > 5 ? win.slotItemFor(5) : null }
            Region { item: win.cardDesktopIds.length > 6 ? win.slotItemFor(6) : null }
            Region { item: win.cardDesktopIds.length > 7 ? win.slotItemFor(7) : null }
            Region { item: win.cardDesktopIds.length > 8 ? win.slotItemFor(8) : null }
            Region { item: win.cardDesktopIds.length > 9 ? win.slotItemFor(9) : null }
            Region { item: win.cardDesktopIds.length > 10 ? win.slotItemFor(10) : null }
            Region { item: win.cardDesktopIds.length > 11 ? win.slotItemFor(11) : null }
            Region { item: win.cardDesktopIds.length > 12 ? win.slotItemFor(12) : null }
            Region { item: win.cardDesktopIds.length > 13 ? win.slotItemFor(13) : null }
            Region { item: win.cardDesktopIds.length > 14 ? win.slotItemFor(14) : null }
            Region { item: win.cardDesktopIds.length > 15 ? win.slotItemFor(15) : null }
            Region { item: win.cardDesktopIds.length > 16 ? win.slotItemFor(16) : null }
            Region { item: win.cardDesktopIds.length > 17 ? win.slotItemFor(17) : null }
            Region { item: win.cardDesktopIds.length > 18 ? win.slotItemFor(18) : null }
            Region { item: win.cardDesktopIds.length > 19 ? win.slotItemFor(19) : null }
            Region { item: win.cardDesktopIds.length > 20 ? win.slotItemFor(20) : null }
            Region { item: win.cardDesktopIds.length > 21 ? win.slotItemFor(21) : null }
            Region { item: win.cardDesktopIds.length > 22 ? win.slotItemFor(22) : null }
            Region { item: win.cardDesktopIds.length > 23 ? win.slotItemFor(23) : null }
            Region { item: win.cardDesktopIds.length > 24 ? win.slotItemFor(24) : null }
            Region { item: win.cardDesktopIds.length > 25 ? win.slotItemFor(25) : null }
            Region { item: (win.menuTileId !== "" || win.desktopMenuOpen) ? menuScrim : null }
            Region { item: win.menuTileId !== "" ? contextMenu : null }
            Region { item: win.desktopMenuOpen ? desktopMenu : null }
        }

        Connections {
            target: WidgetStore
            function onMenuRequested(cid) {
                win.desktopMenuOpen = false;
                const idx = win.desktopIds.indexOf(cid);
                if (idx === -1) {
                    win.menuTileId = "";
                    return;
                }
                const s = win.slotItemFor(idx);
                if (s) {
                    win.menuX = s.x + s.width / 2;
                    win.menuY = s.y + s.height / 2;
                }
                win.menuTileId = cid;
            }
            function onDesktopMenuRequested(px, py) {
                win.menuTileId = "";
                win.desktopMenuX = px > 0 ? px : desktopCanvas.width * 0.5;
                win.desktopMenuY = py > 0 ? py : desktopCanvas.height * 0.45;
                win.desktopMenuOpen = true;
            }
        }

        Item {
            id: desktopCanvas
            anchors.fill: parent

            // Matushell Background Audio Visualiser pinned to full bottom wallpaper edge
            Loader {
                id: bgVisLoader
                anchors.fill: parent
                z: 0
                active: win.visible && win.visualiserPinned
                sourceComponent: Component {
                    MatusBackgroundVisualiser {
                        active: win.visible && win.visualiserPinned && win.hostActive
                        onDesktop: true
                    }
                }
            }

            // Empty-desktop click layer (sits on WlrLayer.Bottom below normal windows & pinned cards)
            MouseArea {
                id: desktopBackdrop
                anchors.fill: parent
                z: 0
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (!win.desktopRightClickEnabled) return;
                        win.menuTileId = "";
                        win.desktopMenuX = mouse.x;
                        win.desktopMenuY = mouse.y;
                        win.desktopMenuOpen = true;
                    } else {
                        win.menuTileId = "";
                        win.desktopMenuOpen = false;
                    }
                }
            }

            function resolveDesktopDrop(tileId, x, y, w, h) {
                const existing = win.currentCardRects();
                const resolved = DesktopLayout.resolveDraggedCollision(
                    existing, tileId,
                    { id: tileId, x: x, y: y, width: w, height: h },
                    desktopCanvas.width, desktopCanvas.height,
                    WidgetStore.gridSnapEnabled, win.topInset,
                    WidgetStore.s(Catalog.cellGap),
                    WidgetStore.s(Catalog.cardGridStep)
                );
                return resolved;
            }

            Component.onCompleted: WidgetDragSession.registerHost(win.screenKey, desktopCanvas)
            Component.onDestruction: WidgetDragSession.unregisterHost(win.screenKey, desktopCanvas)

            // 24px alignment grid guides shown when dragging on desktop or from sidebar
            Canvas {
                anchors.fill: parent
                visible: win.draggingTileId !== "" || win.ownsExternalGhost
                opacity: visible ? 1 : 0
                z: 0

                Behavior on opacity { NumberAnimation { duration: 120 } }
                onVisibleChanged: if (visible) requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const step = WidgetStore.s(Catalog.cardGridGuideStep);
                    ctx.strokeStyle = Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.30);
                    ctx.lineWidth = Math.max(0.75, WidgetStore.uiScale);
                    ctx.beginPath();
                    for (let x = step; x < width; x += step) {
                        ctx.moveTo(x + 0.5, win.topInset);
                        ctx.lineTo(x + 0.5, height);
                    }
                    for (let y = win.topInset; y < height; y += step) {
                        ctx.moveTo(0, y + 0.5);
                        ctx.lineTo(width, y + 0.5);
                    }
                    ctx.stroke();
                }
            }

            // Target drop snap rectangle preview
            Rectangle {
                id: desktopDropHighlight
                readonly property var targetRect: {
                    if (win.ownsExternalGhost && win.externalRects.length > 0) {
                        return win.externalRects[0];
                    }
                    return win.highlightRect;
                }
                visible: (win.draggingTileId !== "" || win.ownsExternalGhost) && targetRect !== null
                x: targetRect ? targetRect.x : 0
                y: targetRect ? targetRect.y : 0
                width: targetRect ? targetRect.width : 0
                height: targetRect ? targetRect.height : 0
                radius: WidgetStore.s(24)
                z: 1
                color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.14)
                border.width: Math.max(1, WidgetStore.s(2))
                border.color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.85)
            }

            // Persistent desktop-pinned widget slots
            Repeater {
                id: slotRepeater
                model: win.cardDesktopIds

                delegate: Item {
                    id: cardSlot

                    required property string modelData
                    readonly property string tileId: modelData
                    readonly property var cardState: WidgetStore.card(tileId)
                    readonly property var cardSize: WidgetStore.cardSize(tileId)
                    readonly property bool isDragged: win.draggingTileId === tileId
                    readonly property bool waitingGhostHandoff: WidgetDragSession.waitingHandoff
                        && WidgetDragSession.tileId === tileId

                    readonly property var resolvedPoint: {
                        if (win.ownsExternalGhost) {
                            for (let i = 0; i < win.externalRects.length; i++) {
                                if (win.externalRects[i].id === tileId) return win.externalRects[i];
                            }
                        }
                        if (win.draggingTileId !== "" && win.dragPreviewPositions[tileId]) {
                            return win.dragPreviewPositions[tileId];
                        }
                        if (!cardState) return { x: 40, y: win.topInset + 16 };
                        const pt = State.screenPoint(
                            cardState.desktop.xNorm, cardState.desktop.yNorm,
                            desktopCanvas.width, desktopCanvas.height,
                            cardSize.width, cardSize.height
                        );
                        return { x: pt.x, y: Math.max(win.topInset, pt.y) };
                    }

                    property real dragX: 0
                    property real dragY: 0

                    x: isDragged ? dragX : resolvedPoint.x
                    y: isDragged ? dragY : resolvedPoint.y
                    width: cardSize.width
                    height: cardSize.height
                    z: isDragged ? 20 : 5
                    scale: isDragged ? 1.025 : 1.0
                    visible: win.visible

                    Behavior on x {
                        enabled: !cardSlot.isDragged && !cardSlot.waitingGhostHandoff
                        NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.39, 1.29, 0.35, 0.98, 1, 1] }
                    }
                    Behavior on y {
                        enabled: !cardSlot.isDragged && !cardSlot.waitingGhostHandoff
                        NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.39, 1.29, 0.35, 0.98, 1, 1] }
                    }
                    Behavior on width {
                        enabled: !cardSlot.isDragged && !cardSlot.waitingGhostHandoff
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        enabled: !cardSlot.isDragged && !cardSlot.waitingGhostHandoff
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                    }

                    Connections {
                        target: WidgetDragSession
                        function onHandoffCheckRequested(cid) {
                            if (cid === cardSlot.tileId) {
                                Qt.callLater(() => WidgetDragSession.completeHandoff(cid));
                            }
                        }
                    }

                    WidgetCardContent {
                        id: cardContent
                        anchors.fill: parent
                        tileId: cardSlot.tileId
                        active: win.visible && win.hostActive && !cardSlot.waitingGhostHandoff
                        interactive: !cardSlot.isDragged
                        onDesktop: true
                        notchRoot: win.notchRoot
                    }

                    HoverHandler {
                        cursorShape: cardContent.draggingLocked ? Qt.ArrowCursor : (cardDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    }

                    DragHandler {
                        id: cardDrag
                        target: null
                        enabled: !cardContent.draggingLocked
                        acceptedButtons: Qt.LeftButton
                        grabPermissions: PointerHandler.TakeOverForbidden

                        property bool started: false
                        property real grabOffX: 0
                        property real grabOffY: 0

                        onActiveChanged: {
                            if (active) {
                                started = true;
                                win.menuTileId = "";
                                grabOffX = centroid.pressPosition.x;
                                grabOffY = centroid.pressPosition.y;
                                cardSlot.dragX = cardSlot.x;
                                cardSlot.dragY = cardSlot.y;
                                win.draggingTileId = cardSlot.tileId;
                            } else if (started) {
                                started = false;
                                const snapped = desktopCanvas.resolveDesktopDrop(
                                    cardSlot.tileId, cardSlot.dragX, cardSlot.dragY,
                                    cardSlot.width, cardSlot.height
                                );
                                const updates = [];
                                snapped.forEach(r => {
                                    const p = State.normalizedPosition(r.x, r.y, desktopCanvas.width, desktopCanvas.height);
                                    updates.push({ id: r.id, xNorm: p.xNorm, yNorm: p.yNorm });
                                });
                                win.draggingTileId = "";
                                win.dragPreviewPositions = ({});
                                win.highlightRect = null;
                                if (updates.length > 0) WidgetStore.setDesktopPositions(updates);
                            }
                        }

                        onCentroidChanged: {
                            if (!active || !started) return;
                            const inCanvas = cardSlot.mapToItem(desktopCanvas, centroid.position.x, centroid.position.y);
                            const nx = Math.max(0, Math.min(Math.max(0, desktopCanvas.width - cardSlot.width), inCanvas.x - grabOffX));
                            const ny = Math.max(win.topInset, Math.min(Math.max(win.topInset, desktopCanvas.height - cardSlot.height), inCanvas.y - grabOffY));
                            cardSlot.dragX = nx;
                            cardSlot.dragY = ny;
                            const snapped = desktopCanvas.resolveDesktopDrop(
                                cardSlot.tileId, nx, ny, cardSlot.width, cardSlot.height
                            );
                            const map = {};
                            snapped.forEach(r => { map[r.id] = r; });
                            win.dragPreviewPositions = map;
                            win.highlightRect = map[cardSlot.tileId] || null;
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: (eventPoint) => {
                            const pt = cardSlot.mapToItem(desktopCanvas, eventPoint.position.x, eventPoint.position.y);
                            win.desktopMenuOpen = false;
                            win.menuX = pt.x;
                            win.menuY = pt.y;
                            win.menuTileId = cardSlot.tileId;
                        }
                    }
                }
            }

            // Active drag ghost dragged out from sidebar onto desktop
            Item {
                id: externalGhost
                visible: win.ownsExternalGhost
                x: WidgetDragSession.ghostX
                y: WidgetDragSession.ghostY
                width: WidgetDragSession.ghostWidth
                height: WidgetDragSession.ghostHeight
                scale: 1.025
                z: 40

                WidgetCardContent {
                    anchors.fill: parent
                    tileId: WidgetDragSession.tileId
                    active: win.ownsExternalGhost
                    interactive: false
                    onDesktop: true
                }
            }

            // Dismiss scrim for right-click menus on desktop
            MouseArea {
                id: menuScrim
                anchors.fill: parent
                visible: win.menuTileId !== "" || win.desktopMenuOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 90
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && win.desktopRightClickEnabled) {
                        win.menuTileId = "";
                        win.desktopMenuX = mouse.x;
                        win.desktopMenuY = mouse.y;
                        win.desktopMenuOpen = true;
                    } else {
                        win.menuTileId = "";
                        win.desktopMenuOpen = false;
                    }
                }
            }

            // Screen right-click desktop menu in clean end-4pc Material 3 grouped card style
            Item {
                id: desktopMenu
                visible: win.desktopMenuOpen
                width: WidgetStore.s(288)
                height: dmCol.implicitHeight + WidgetStore.s(16)
                x: Math.max(WidgetStore.s(12), Math.min(Math.max(WidgetStore.s(12), desktopCanvas.width - width - WidgetStore.s(12)), win.desktopMenuX))
                y: Math.max(win.topInset + WidgetStore.s(8), Math.min(Math.max(win.topInset + WidgetStore.s(8), desktopCanvas.height - height - WidgetStore.s(12)), win.desktopMenuY))
                z: 100

                Rectangle {
                    anchors.fill: parent
                    radius: WidgetStore.s(24)
                    color: Theme.m3.surface_container_highest ?? Theme.colors.card_bg
                    opacity: 0.94

                    layer.enabled: desktopMenu.visible && width > 1 && height > 1
                    layer.smooth: true
                    layer.textureSize: Qt.size(
                        Math.max(1, Math.round(width * WidgetStore.qtScale)),
                        Math.max(1, Math.round(height * WidgetStore.qtScale))
                    )
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.50)
                        shadowBlur: 0.78
                        shadowVerticalOffset: WidgetStore.s(6)
                        autoPaddingEnabled: true
                    }
                }

                ColumnLayout {
                    id: dmCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: WidgetStore.s(8)
                    }
                    spacing: WidgetStore.s(3)

                    // Row 1: Edit Widgets (opens Widget Picker shelf)
                    M3DesktopMenuRow {
                        isFirst: true
                        isLast: false
                        icon: "dashboard_customize"
                        label: WidgetStore.sidebarOpen ? "Close Widget Picker" : "Edit Widgets"
                        badgeText: win.desktopIds.length > 0 ? (win.desktopIds.length + " pinned") : ""
                        showChevron: true
                        onTriggered: {
                            win.desktopMenuOpen = false;
                            WidgetStore.toggleSidebar();
                        }
                    }

                    // Row 2: Snap to Grid toggle
                    M3DesktopMenuRow {
                        isFirst: false
                        isLast: false
                        icon: "grid_4x4"
                        label: "Snap to Grid"
                        showSwitch: true
                        switchChecked: WidgetStore.gridSnapEnabled
                        onTriggered: WidgetStore.toggleGridSnap()
                    }

                    // Pinned Widget Options quick chips (when pinned cards exist)
                    Rectangle {
                        visible: win.desktopIds.length > 0
                        Layout.fillWidth: true
                        implicitHeight: pinnedOptsCol.implicitHeight + WidgetStore.s(16)
                        topLeftRadius: WidgetStore.s(6)
                        topRightRadius: WidgetStore.s(6)
                        bottomLeftRadius: WidgetStore.s(6)
                        bottomRightRadius: WidgetStore.s(6)
                        color: Theme.m3.surface_container_high ?? Theme.colors.hover_bg

                        ColumnLayout {
                            id: pinnedOptsCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: WidgetStore.s(12)
                                rightMargin: WidgetStore.s(12)
                                topMargin: WidgetStore.s(8)
                            }
                            spacing: WidgetStore.s(6)

                            Text {
                                text: "Widget options"
                                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(10.5)
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: WidgetStore.s(5)

                                Repeater {
                                    model: win.desktopIds

                                    Rectangle {
                                        required property string modelData
                                        readonly property var wDef: Catalog.definitionFor(modelData)
                                        width: wChipInner.implicitWidth + WidgetStore.s(14)
                                        height: WidgetStore.s(26)
                                        radius: height / 2
                                        color: chipMouse.containsMouse
                                            ? (Theme.m3.primary ?? Theme.accent)
                                            : (Theme.m3.secondary_container ?? Theme.colors.hover_bg)

                                        Row {
                                            id: wChipInner
                                            anchors.centerIn: parent
                                            spacing: WidgetStore.s(4)
                                            MaterialSymbol {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: wDef ? wDef.icon : "tune"
                                                iconSize: WidgetStore.si(13)
                                                fill: 1
                                                color: chipMouse.containsMouse
                                                    ? (Theme.m3.on_primary ?? "#101014")
                                                    : (Theme.m3.on_secondary_container ?? Theme.colors.text_primary)
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: wDef ? wDef.name : modelData
                                                color: chipMouse.containsMouse
                                                    ? (Theme.m3.on_primary ?? "#101014")
                                                    : (Theme.m3.on_secondary_container ?? Theme.colors.text_primary)
                                                font.family: "Google Sans Flex"
                                                font.pixelSize: WidgetStore.si(10.5)
                                                font.weight: Font.DemiBold
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        MouseArea {
                                            id: chipMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.desktopMenuOpen = false;
                                                win.menuX = win.desktopMenuX;
                                                win.menuY = win.desktopMenuY;
                                                win.menuTileId = modelData;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Row 3: Wallpaper & Style
                    M3DesktopMenuRow {
                        isFirst: false
                        isLast: false
                        icon: "wallpaper"
                        label: "Wallpaper & style"
                        showChevron: true
                        onTriggered: {
                            win.desktopMenuOpen = false;
                            if (win.notchRoot && typeof win.notchRoot.switchMode === "function")
                                win.notchRoot.switchMode("wallpaper", false);
                        }
                    }

                    // Row 4: Settings
                    M3DesktopMenuRow {
                        isFirst: false
                        isLast: win.desktopIds.length === 0
                        icon: "settings"
                        label: "Settings"
                        showChevron: true
                        onTriggered: {
                            win.desktopMenuOpen = false;
                            if (win.notchRoot && typeof win.notchRoot.openSettings === "function")
                                win.notchRoot.openSettings("");
                        }
                    }

                    // Row 5: Return all widgets (when widgets are pinned)
                    M3DesktopMenuRow {
                        visible: win.desktopIds.length > 0
                        isFirst: false
                        isLast: true
                        icon: "move_down"
                        label: "Return all widgets"
                        danger: true
                        onTriggered: {
                            win.desktopMenuOpen = false;
                            WidgetStore.returnAllToSidebar();
                        }
                    }
                }
            }

            // Inline style-matched desktop options panel (M3 Expressive or Sekai Pop)
            WidgetOptionsPanel {
                id: contextMenu
                visible: win.menuTileId !== ""
                tileId: win.menuTileId
                onDesktop: true
                screenName: win.screenKey
                notchRoot: win.notchRoot
                x: Math.max(WidgetStore.s(12), Math.min(Math.max(WidgetStore.s(12), desktopCanvas.width - width - WidgetStore.s(12)), win.menuX))
                y: Math.max(win.topInset + WidgetStore.s(8), Math.min(Math.max(win.topInset + WidgetStore.s(8), desktopCanvas.height - height - WidgetStore.s(12)), win.menuY))
                z: 100
                onClosed: win.menuTileId = ""
            }
        }
    }

    component M3DesktopMenuRow: Rectangle {
        property bool isFirst: false
        property bool isLast: false
        property string icon: ""
        property string label: ""
        property string badgeText: ""
        property bool showChevron: false
        property bool showSwitch: false
        property bool switchChecked: false
        property bool danger: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: visible ? WidgetStore.s(44) : 0
        topLeftRadius: isFirst ? WidgetStore.s(18) : WidgetStore.s(6)
        topRightRadius: isFirst ? WidgetStore.s(18) : WidgetStore.s(6)
        bottomLeftRadius: isLast ? WidgetStore.s(18) : WidgetStore.s(6)
        bottomRightRadius: isLast ? WidgetStore.s(18) : WidgetStore.s(6)
        color: dmRowMouse.containsMouse
            ? (danger
                ? Qt.alpha(Theme.m3.error_container ?? "#7f1d1d", 0.72)
                : Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.16))
            : (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)

        RowLayout {
            anchors {
                fill: parent
                leftMargin: WidgetStore.s(14)
                rightMargin: WidgetStore.s(12)
            }
            spacing: WidgetStore.s(10)

            MaterialSymbol {
                text: icon
                iconSize: WidgetStore.si(18)
                color: danger
                    ? (Theme.m3.error ?? "#ffb4ab")
                    : (dmRowMouse.containsMouse ? (Theme.m3.primary ?? Theme.accent) : (Theme.m3.on_surface ?? Theme.colors.text_primary))
            }

            Text {
                Layout.fillWidth: true
                text: label
                color: danger
                    ? (Theme.m3.error ?? "#ffb4ab")
                    : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(12.5)
                font.weight: Font.Medium
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
                elide: Text.ElideRight
            }

            Text {
                visible: badgeText !== ""
                text: badgeText
                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                opacity: 0.75
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(10.5)
                renderType: Text.NativeRendering
            }

            Rectangle {
                visible: showSwitch
                Layout.preferredWidth: WidgetStore.s(30)
                Layout.preferredHeight: WidgetStore.s(17)
                radius: height / 2
                color: switchChecked ? (Theme.m3.primary ?? Theme.accent) : Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.25)
                Rectangle {
                    width: WidgetStore.s(11); height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: switchChecked ? (parent.width - width - WidgetStore.s(3)) : WidgetStore.s(3)
                    color: switchChecked ? (Theme.m3.on_primary ?? "#101014") : "#ffffff"
                }
            }

            MaterialSymbol {
                visible: showChevron
                text: "chevron_right"
                iconSize: WidgetStore.si(16)
                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                opacity: 0.55
            }
        }

        MouseArea {
            id: dmRowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: triggered()
        }
    }
}
