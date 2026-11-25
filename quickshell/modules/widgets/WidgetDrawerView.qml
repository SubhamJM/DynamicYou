import QtQuick
import QtQuick.Layouts
import "../../"
import "../"
import "WidgetCatalog.js" as Catalog
import "WidgetGrid.js" as Grid
import "WidgetState.js" as State
import "WidgetDesktopLayout.js" as DesktopLayout

Item {
    id: root

    property string screenName: ""
    property bool active: true
    property var notchRoot: null
    property var sidebarContainsFn: null

    readonly property var activeSidebarIds: {
        const ids = (WidgetStore.sidebarCardIds || []).slice();
        if (WidgetDragSession.active && WidgetDragSession.tileId !== ""
                && ids.indexOf(WidgetDragSession.tileId) === -1) {
            ids.push(WidgetDragSession.tileId);
        }
        return ids;
    }

    readonly property int gridContentWidth: Catalog.canvasWidth
    readonly property int gridContentHeight: {
        const base = Grid.contentHeight(committedLayout, activeSidebarIds);
        return (dragTargetValid && !desktopExtraction)
            ? Math.max(base, Grid.contentHeight(previewLayout, activeSidebarIds))
            : base;
    }

    readonly property var dropPlacement: dragTargetValid
        ? Grid.placementFor(previewLayout, draggingTileId)
        : null

    property var committedLayout: hydrateLayout()
    property var previewLayout: []
    property string draggingTileId: ""
    property Item dragSourceItem: null
    property real dragLiveX: 0
    property real dragLiveY: 0
    property real dragGrabOffsetX: 0
    property real dragGrabOffsetY: 0
    property int targetX: -1
    property int targetY: -1
    property bool dragTargetValid: false
    property bool desktopExtraction: false
    property bool motionEnabled: true

    // Inline right-click context menu state
    property string menuTileId: ""
    property real menuX: 0
    property real menuY: 0

    function hydrateLayout() {
        const activeIds = activeSidebarIds;
        const preferredAnchors = {};
        const saved = [];
        activeIds.forEach(id => {
            const a = WidgetStore.sidebarAnchor(id);
            if (a) {
                preferredAnchors[id] = a;
                saved.push({ id: id, x: a.x, y: a.y });
            }
        });
        return Grid.hydrateSaved({ version: 1, tiles: saved }, activeIds, preferredAnchors);
    }

    function syncLayoutFromStore() {
        if (draggingTileId !== "") return;
        motionEnabled = false;
        committedLayout = hydrateLayout();
        Qt.callLater(() => { motionEnabled = true; });
    }

    onActiveSidebarIdsChanged: syncLayoutFromStore()

    Connections {
        target: WidgetStore
        function onLayoutResetRequested() {
            root.motionEnabled = true;
            root.committedLayout = Grid.defaultLayout(root.activeSidebarIds, {});
        }
    }

    Connections {
        target: WidgetDragSession
        function onCanceled() {
            if (root.draggingTileId !== "") {
                root.resetDragState(true);
            }
        }
    }

    function sidebarContainsWindowPoint(winX, winY) {
        if (typeof root.sidebarContainsFn === "function") {
            return root.sidebarContainsFn(winX, winY);
        }
        return true;
    }

    function resetDragState(preserveMotion) {
        if (!preserveMotion) root.motionEnabled = false;
        root.draggingTileId = "";
        root.dragSourceItem = null;
        root.previewLayout = [];
        root.targetX = -1;
        root.targetY = -1;
        root.dragTargetValid = false;
        root.desktopExtraction = false;
        if (!preserveMotion) Qt.callLater(() => { root.motionEnabled = true; });
    }

    function displayPlacement(tileId) {
        if (draggingTileId.length > 0 && dragTargetValid && !desktopExtraction) {
            return Grid.placementFor(previewLayout, tileId) || Grid.placementFor(committedLayout, tileId);
        }
        return Grid.placementFor(committedLayout, tileId);
    }

    function startDrag(tileId, sourceItem, grabX, grabY, localX, localY) {
        menuTileId = "";
        if (WidgetDragSession.active) return;
        const pl = Grid.placementFor(committedLayout, tileId);
        if (!pl) return;
        if (!WidgetDragSession.begin(tileId, sourceItem, grabX, grabY)) return;

        draggingTileId = tileId;
        dragSourceItem = sourceItem;
        dragGrabOffsetX = grabX;
        dragGrabOffsetY = grabY;
        dragLiveX = pl.x;
        dragLiveY = pl.y;
        targetX = pl.x;
        targetY = pl.y;
        previewLayout = committedLayout.slice();
        dragTargetValid = true;
        desktopExtraction = false;
    }

    function updateDrag(tileId, pointerLocalX, pointerLocalY) {
        if (tileId !== draggingTileId || !dragSourceItem) return;

        const winPt = dragSourceItem.mapToItem(null, pointerLocalX, pointerLocalY);
        const insideSidebar = sidebarContainsWindowPoint(winPt.x, winPt.y);

        if (!insideSidebar) {
            const hostPt = WidgetDragSession.mapItemPoint(root.screenName, dragSourceItem, pointerLocalX, pointerLocalY);
            const host = WidgetDragSession.hostFor(root.screenName);
            if (hostPt && host) {
                if (!desktopExtraction) {
                    const srcRect = WidgetDragSession.mapItemRect(root.screenName, dragSourceItem);
                    const grabOffX = srcRect ? (hostPt.x - srcRect.x) : dragGrabOffsetX;
                    const grabOffY = srcRect ? (hostPt.y - srcRect.y) : dragGrabOffsetY;
                    if (WidgetDragSession.promoteToDesktop(
                            root.screenName, hostPt.x, hostPt.y,
                            grabOffX, grabOffY,
                            dragSourceItem.width, dragSourceItem.height,
                            host.width, host.height)) {
                        desktopExtraction = true;
                        previewLayout = [];
                        dragTargetValid = false;
                        targetX = -1;
                        targetY = -1;
                    }
                } else {
                    WidgetDragSession.update(hostPt.x, hostPt.y);
                }
            }
            return;
        }

        // Returned back inside the sidebar during an active extraction drag!
        if (desktopExtraction) {
            WidgetDragSession.clear();
            WidgetDragSession.begin(tileId, dragSourceItem, dragGrabOffsetX, dragGrabOffsetY);
            desktopExtraction = false;
            targetX = -1;
            targetY = -1;
        }

        const inGrid = gridCanvas.mapFromItem(dragSourceItem, pointerLocalX, pointerLocalY);
        dragLiveX = Math.max(-24, Math.min(gridContentWidth - dragSourceItem.width + 24, inGrid.x - dragGrabOffsetX));
        dragLiveY = Math.max(-16, inGrid.y - dragGrabOffsetY);

        const def = Grid.tileDefinitionFor(tileId);
        if (!def) return;
        const anchor = Grid.clampAnchor(def, inGrid.x - dragGrabOffsetX, inGrid.y - dragGrabOffsetY);
        if (anchor.x === targetX && anchor.y === targetY) return;
        targetX = anchor.x;
        targetY = anchor.y;
        const solved = Grid.moveLayout(committedLayout, tileId, anchor.x, anchor.y, activeSidebarIds);
        previewLayout = solved || [];
        dragTargetValid = solved !== null;
    }

    function finishDrag(tileId) {
        if (tileId !== draggingTileId) return;

        if (desktopExtraction) {
            const hostW = WidgetDragSession.hostWidth;
            const hostH = WidgetDragSession.hostHeight;
            const size = WidgetStore.cardSize(tileId);
            const topInset = 46;
            let gx = Math.max(0, Math.min(Math.max(0, hostW - size.width), WidgetDragSession.ghostX));
            let gy = Math.max(topInset, Math.min(Math.max(topInset, hostH - size.height), WidgetDragSession.ghostY));
            if (WidgetStore.gridSnapEnabled) {
                const sp = DesktopLayout.snapPoint(gx, gy, size.width, size.height, hostW, hostH, topInset);
                gx = sp.x;
                gy = sp.y;
            }
            const norm = State.normalizedPosition(gx, gy, hostW, hostH);
            const resolvedRects = WidgetDragSession.resolveDesktopDrop(root.screenName, tileId, gx, gy, size.width, size.height);
            const positions = [];
            if (Array.isArray(resolvedRects)) {
                resolvedRects.forEach(r => {
                    if (!r || !r.id) return;
                    const p = State.normalizedPosition(r.x, r.y, hostW, hostH);
                    positions.push({ id: String(r.id), xNorm: p.xNorm, yNorm: p.yNorm });
                });
            }
            WidgetDragSession.commitDrop(gx, gy);
            WidgetStore.setContainer(tileId, "desktop", root.screenName, norm.xNorm, norm.yNorm);
            if (positions.length > 0) {
                WidgetStore.setDesktopPositions(positions);
            }
            WidgetDragSession.requestHandoffCheck(tileId);
            resetDragState(false);
            return;
        }

        if (dragTargetValid && previewLayout.length > 0) {
            committedLayout = previewLayout.slice();
            WidgetStore.setSidebarLayout(committedLayout);
        }
        WidgetDragSession.clear();
        resetDragState(true);
    }

    function scrollBy(dy) {
        const maxY = Math.max(0, scrollView.contentHeight - scrollView.height);
        scrollView.contentY = Math.max(0, Math.min(maxY, scrollView.contentY + Number(dy || 0)));
    }

    function scrollToFraction(frac) {
        const maxY = Math.max(0, scrollView.contentHeight - scrollView.height);
        scrollView.contentY = Math.round(maxY * Math.max(0, Math.min(1, Number(frac || 0))));
    }

    function openContextMenu(tileId, winPtX, winPtY) {
        const localPt = root.mapFromItem(null, winPtX, winPtY);
        menuX = Math.max(8, Math.min(Math.max(8, root.width - 196), localPt.x));
        menuY = Math.max(8, Math.min(Math.max(8, root.height - 150), localPt.y));
        menuTileId = tileId;
    }

    Flickable {
        id: scrollView
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, gridContainer.height + (pinnedBar.visible ? pinnedBar.height + 20 : 12))
        interactive: root.draggingTileId === ""
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3000

        Item {
            id: gridContainer
            width: root.gridContentWidth
            height: root.gridContentHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                id: gridCanvas
                anchors.fill: parent

                // Subtle 24px alignment guide grid while reordering inside sidebar
                Canvas {
                    id: guideCanvas
                    anchors.fill: parent
                    visible: root.draggingTileId !== "" && !root.desktopExtraction
                    opacity: visible ? 1 : 0
                    z: 0

                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    onVisibleChanged: if (visible) requestPaint()
                    onHeightChanged: if (visible) requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const step = Catalog.cardGridGuideStep;
                        ctx.strokeStyle = Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.35);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        for (let x = step; x < width; x += step) {
                            ctx.moveTo(x + 0.5, 0);
                            ctx.lineTo(x + 0.5, height);
                        }
                        for (let y = step; y < height; y += step) {
                            ctx.moveTo(0, y + 0.5);
                            ctx.lineTo(width, y + 0.5);
                        }
                        ctx.stroke();
                    }
                }

                // Target slot preview indicator
                Rectangle {
                    id: slotIndicator
                    z: 1
                    visible: root.draggingTileId !== "" && !root.desktopExtraction && root.dropPlacement !== null
                    x: root.dropPlacement ? root.dropPlacement.x : 0
                    y: root.dropPlacement ? root.dropPlacement.y : 0
                    width: root.dropPlacement ? root.dropPlacement.width : 0
                    height: root.dropPlacement ? root.dropPlacement.height : 0
                    radius: 24
                    color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.14)
                    border.width: 2
                    border.color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.85)

                    Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                }

                // Draggable cards
                Repeater {
                    model: root.activeSidebarIds

                    delegate: Item {
                        id: tile

                        required property string modelData
                        readonly property string tileId: modelData
                        readonly property var placement: root.displayPlacement(tileId)
                        readonly property var cardDim: Catalog.sizeFor(tileId)
                        readonly property bool isDraggedHere: root.draggingTileId === tileId
                        readonly property bool hiddenByExtraction: root.desktopExtraction && isDraggedHere
                            || (WidgetDragSession.presentationActive && WidgetDragSession.tileId === tileId)

                        x: (isDraggedHere && !root.desktopExtraction)
                            ? root.dragLiveX
                            : (placement ? placement.x : 0)
                        y: (isDraggedHere && !root.desktopExtraction)
                            ? root.dragLiveY
                            : (placement ? placement.y : 0)
                        width: cardDim.width
                        height: cardDim.height
                        z: isDraggedHere ? 30 : 5
                        visible: !hiddenByExtraction && placement !== null
                        scale: (isDraggedHere && !root.desktopExtraction) ? 1.025 : 1.0

                        Behavior on x {
                            enabled: root.motionEnabled && !tile.isDraggedHere
                            NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.39, 1.29, 0.35, 0.98, 1, 1] }
                        }
                        Behavior on y {
                            enabled: root.motionEnabled && !tile.isDraggedHere
                            NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.39, 1.29, 0.35, 0.98, 1, 1] }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }

                        WidgetCardContent {
                            anchors.fill: parent
                            tileId: tile.tileId
                            active: root.active && !tile.hiddenByExtraction
                            interactive: !tile.isDraggedHere
                            notchRoot: root.notchRoot
                        }

                        HoverHandler {
                            cursorShape: tileDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }

                        DragHandler {
                            id: tileDrag
                            target: null
                            enabled: root.active
                            acceptedButtons: Qt.LeftButton
                            grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything

                            property bool started: false

                            onActiveChanged: {
                                if (active) {
                                    started = true;
                                    root.startDrag(
                                        tile.tileId, tile,
                                        centroid.pressPosition.x, centroid.pressPosition.y,
                                        centroid.position.x, centroid.position.y
                                    );
                                } else if (started) {
                                    started = false;
                                    root.finishDrag(tile.tileId);
                                }
                            }

                            onCentroidChanged: {
                                if (active && started) {
                                    root.updateDrag(tile.tileId, centroid.position.x, centroid.position.y);
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: (eventPoint) => {
                                const wp = tile.mapToItem(null, eventPoint.position.x, eventPoint.position.y);
                                root.openContextMenu(tile.tileId, wp.x, wp.y);
                            }
                        }
                    }
                }
            }
        }

        // Compact recall bar when widgets are pinned to the desktop
        Rectangle {
            id: pinnedBar
            visible: WidgetStore.desktopCardIds.length > 0
            width: root.gridContentWidth
            height: visible ? pinnedFlow.implicitHeight + 24 : 0
            x: (parent.width - width) / 2
            y: gridContainer.height + 12
            radius: 16
            color: Theme.m3.surface_container ?? Theme.colors.card_bg
            border.width: 1
            border.color: Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.5)

            ColumnLayout {
                id: pinnedFlow
                anchors { fill: parent; margins: 12 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "On desktop (" + WidgetStore.desktopCardIds.length + ") · Click to recall"
                        color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: WidgetStore.desktopCardIds
                        delegate: Rectangle {
                            required property string modelData
                            readonly property var def: Catalog.definitionFor(modelData)
                            height: 28
                            width: chipRow.implicitWidth + 16
                            radius: 9
                            color: chipMouse.containsMouse
                                ? (Theme.m3.primary_container ?? Theme.colors.hover_bg)
                                : (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: def ? def.icon : "widgets"
                                    iconSize: 14
                                    color: Theme.m3.primary ?? Theme.accent
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: def ? def.name : modelData
                                    color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WidgetStore.setContainer(modelData, "sidebar")
                            }
                        }
                    }
                }
            }
        }
    }

    // Slim scrollbar
    Rectangle {
        visible: scrollView.contentHeight > scrollView.height + 4
        anchors { right: parent.right; rightMargin: -11 }
        y: (scrollView.contentY / Math.max(1, scrollView.contentHeight)) * parent.height
        width: 3
        height: Math.max(32, (scrollView.height / Math.max(1, scrollView.contentHeight)) * parent.height)
        radius: 2
        color: Qt.alpha(Theme.m3.on_surface_variant ?? "#67e8f9", 0.35)
    }

    // Dismiss context menu when clicking anywhere outside it
    MouseArea {
        visible: root.menuTileId !== ""
        anchors.fill: parent
        z: 190
        onClicked: root.menuTileId = ""
    }

    // Inline themed right-click context menu
    Rectangle {
        id: contextMenu
        visible: root.menuTileId !== ""
        x: root.menuX
        y: root.menuY
        width: 192
        height: menuCol.implicitHeight + 12
        z: 200
        radius: 14
        color: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg
        border.width: 1
        border.color: Qt.alpha(Theme.m3.outline ?? "#163a70", 0.7)

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 2

            MenuRow {
                icon: "pin_drop"
                label: "Pin to desktop"
                onTriggered: {
                    const id = root.menuTileId;
                    root.menuTileId = "";
                    WidgetStore.pinToDesktop(id, root.screenName);
                }
            }

            MenuRow {
                visible: root.menuTileId === "time"
                icon: "schedule"
                label: WidgetStore.clockStyle === "cookie" ? "Use Digital Clock" : "Use Cookie Clock"
                onTriggered: {
                    root.menuTileId = "";
                    WidgetStore.toggleClockStyle();
                }
            }

            MenuRow {
                visible: root.menuTileId === "music"
                icon: "music_note"
                label: WidgetStore.musicStyle === "sticker" ? "Desktop: Use Card" : "Desktop: Use Sticker"
                onTriggered: {
                    root.menuTileId = "";
                    WidgetStore.toggleMusicStyle();
                }
            }

            MenuRow {
                visible: root.menuTileId === "network" && (WidgetTelemetry.netInterfaces || []).length > 0
                icon: "swap_horiz"
                label: "Cycle Interface"
                onTriggered: {
                    const list = (WidgetTelemetry.netInterfaces || []).map(i => i.name);
                    list.push("__all__");
                    const cur = WidgetStore.preferredNetInterface || WidgetTelemetry.defaultInterface || list[0];
                    const idx = list.indexOf(cur);
                    WidgetStore.setPreferredNetInterface(list[(idx + 1) % list.length]);
                    root.menuTileId = "";
                }
            }

            MenuRow {
                visible: root.menuTileId === "storage" && (WidgetTelemetry.disks || []).length > 1
                icon: "hard_drive"
                label: "Cycle Disk Device"
                onTriggered: {
                    const devs = (WidgetTelemetry.disks || []).map(d => d.device);
                    const cur = WidgetStore.preferredDiskDevice || devs[0];
                    const idx = devs.indexOf(cur);
                    WidgetStore.setPreferredDiskDevice(devs[(idx + 1) % devs.length]);
                    root.menuTileId = "";
                }
            }
        }
    }

    component MenuRow: Rectangle {
        property string icon: ""
        property string label: ""
        signal triggered()

        width: parent.width
        height: visible ? 34 : 0
        radius: 9
        color: rowMouse.containsMouse
            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.16)
            : "transparent"

        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
            spacing: 8
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: icon
                iconSize: 16
                color: rowMouse.containsMouse
                    ? (Theme.m3.primary ?? Theme.accent)
                    : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                font.family: "Noto Sans"
                font.pixelSize: 12
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: triggered()
        }
    }
}
