import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../"
import "../"
import "WidgetCatalog.js" as Catalog
import "WidgetState.js" as State
import "WidgetDesktopLayout.js" as DesktopLayout

Variants {
    id: hosts

    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
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

        readonly property bool ownsExternalGhost: WidgetDragSession.presentationActive
            && WidgetDragSession.screenName === win.screenKey
            && WidgetDragSession.presentationGhostRect.valid

        property string draggingTileId: ""
        property var dragPreviewPositions: ({})
        property var highlightRect: null

        property string menuTileId: ""
        property real menuX: 0
        property real menuY: 0

        function slotItemFor(index) {
            return slotRepeater.itemAt(index);
        }

        function currentCardRects() {
            const list = [];
            win.desktopIds.forEach(id => {
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

        visible: win.desktopIds.length > 0 || win.ownsExternalGhost
        screen: modelData
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-desktop-widgets"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Static per-catalog-index mask regions + context menu regions
        mask: Region {
            Region { item: win.desktopIds.length > 0 ? win.slotItemFor(0) : null }
            Region { item: win.desktopIds.length > 1 ? win.slotItemFor(1) : null }
            Region { item: win.desktopIds.length > 2 ? win.slotItemFor(2) : null }
            Region { item: win.desktopIds.length > 3 ? win.slotItemFor(3) : null }
            Region { item: win.desktopIds.length > 4 ? win.slotItemFor(4) : null }
            Region { item: win.desktopIds.length > 5 ? win.slotItemFor(5) : null }
            Region { item: win.desktopIds.length > 6 ? win.slotItemFor(6) : null }
            Region { item: win.desktopIds.length > 7 ? win.slotItemFor(7) : null }
            Region { item: win.desktopIds.length > 8 ? win.slotItemFor(8) : null }
            Region { item: win.desktopIds.length > 9 ? win.slotItemFor(9) : null }
            Region { item: win.desktopIds.length > 10 ? win.slotItemFor(10) : null }
            Region { item: win.desktopIds.length > 11 ? win.slotItemFor(11) : null }
            Region { item: win.menuTileId !== "" ? menuScrim : null }
            Region { item: win.menuTileId !== "" ? contextMenu : null }
        }

        Item {
            id: desktopCanvas
            anchors.fill: parent

            function resolveDesktopDrop(tileId, x, y, w, h) {
                const existing = win.currentCardRects();
                const resolved = DesktopLayout.resolveDraggedCollision(
                    existing, tileId,
                    { id: tileId, x: x, y: y, width: w, height: h },
                    desktopCanvas.width, desktopCanvas.height,
                    WidgetStore.gridSnapEnabled, win.topInset
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
                    const step = Catalog.cardGridGuideStep;
                    ctx.strokeStyle = Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.30);
                    ctx.lineWidth = 1;
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
                radius: 24
                z: 1
                color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.14)
                border.width: 2
                border.color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.85)
            }

            // Persistent desktop-pinned widget slots
            Repeater {
                id: slotRepeater
                model: win.desktopIds

                delegate: Item {
                    id: cardSlot

                    required property string modelData
                    readonly property string tileId: modelData
                    readonly property var cardState: WidgetStore.card(tileId)
                    readonly property var cardSize: Catalog.sizeFor(tileId)
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
                        anchors.fill: parent
                        tileId: cardSlot.tileId
                        active: win.visible && !cardSlot.waitingGhostHandoff
                        interactive: !cardSlot.isDragged
                        onDesktop: true
                    }

                    HoverHandler {
                        cursorShape: cardDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    }

                    DragHandler {
                        id: cardDrag
                        target: null
                        enabled: true
                        acceptedButtons: Qt.LeftButton
                        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything

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
                            win.menuX = Math.max(12, Math.min(Math.max(12, desktopCanvas.width - 204), pt.x));
                            win.menuY = Math.max(win.topInset + 8, Math.min(Math.max(win.topInset + 8, desktopCanvas.height - 150), pt.y));
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

            // Dismiss scrim for right-click menu on desktop cards
            MouseArea {
                id: menuScrim
                anchors.fill: parent
                visible: win.menuTileId !== ""
                z: 90
                onClicked: win.menuTileId = ""
            }

            // Inline desktop context menu
            Rectangle {
                id: contextMenu
                visible: win.menuTileId !== ""
                x: win.menuX
                y: win.menuY
                width: 196
                height: dMenuCol.implicitHeight + 12
                z: 100
                radius: 14
                color: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg
                border.width: 1
                border.color: Qt.alpha(Theme.m3.outline ?? "#163a70", 0.7)

                Column {
                    id: dMenuCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 2

                    DMenuRow {
                        icon: "dock_to_left"
                        label: "Return to sidebar"
                        onTriggered: {
                            const id = win.menuTileId;
                            win.menuTileId = "";
                            WidgetStore.setContainer(id, "sidebar");
                        }
                    }

                    DMenuRow {
                        visible: win.menuTileId === "time"
                        icon: "schedule"
                        label: WidgetStore.clockStyle === "cookie" ? "Use Digital Clock" : "Use Cookie Clock"
                        onTriggered: {
                            win.menuTileId = "";
                            WidgetStore.toggleClockStyle();
                        }
                    }

                    DMenuRow {
                        visible: win.menuTileId === "music"
                        icon: "music_note"
                        label: WidgetStore.musicStyle === "sticker" ? "Use Card Mode" : "Use Sticker Mode"
                        onTriggered: {
                            win.menuTileId = "";
                            WidgetStore.toggleMusicStyle();
                        }
                    }

                    DMenuRow {
                        visible: win.desktopIds.length > 1
                        icon: "move_down"
                        label: "Return all to sidebar"
                        onTriggered: {
                            win.menuTileId = "";
                            WidgetStore.returnAllToSidebar();
                        }
                    }
                }
            }
        }
    }

    component DMenuRow: Rectangle {
        property string icon: ""
        property string label: ""
        signal triggered()

        width: parent.width
        height: visible ? 34 : 0
        radius: 9
        color: dRowMouse.containsMouse
            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.16)
            : "transparent"

        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
            spacing: 8
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: icon
                iconSize: 16
                color: dRowMouse.containsMouse
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
            id: dRowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: triggered()
        }
    }
}
