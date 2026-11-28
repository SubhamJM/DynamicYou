import QtQuick
import QtQuick.Layouts
import "../../"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog
import "WidgetDesktopLayout.js" as DesktopLayout
import "WidgetState.js" as State

// Horizontal iNiR Showcase Shelf with true aspect-ratio plates, crisp mipmapped previews,
// smooth wheel/chevron paging, drag-up-to-desktop placement, and legible QtRendering typography.
Item {
    id: root

    property string screenName: ""
    property bool active: true
    property string sourceFilter: "all"
    property string searchQuery: ""
    property var notchRoot: null
    property var sidebarContainsFn: null
    property Item overlayHost: null

    // iNiR tokens aligned with WidgetSidebarWindow
    readonly property color colLayer1: Theme.m3.surface_container_low ?? "#15151a"
    readonly property color colLayer2: Theme.m3.surface_container ?? "#1c1c22"
    readonly property color colLayer3: Theme.m3.surface_container_high ?? "#26262e"
    readonly property color colLayerHover: Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.08)
    readonly property color colBorder: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.72)
    readonly property color colBorderSubtle: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.38)
    readonly property color colBorderFocus: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.78)
    readonly property color colSelection: Qt.alpha(Theme.m3.primary_container ?? Theme.primaryContainer, 0.45)
    readonly property color colText: Theme.m3.on_surface ?? Theme.text
    readonly property color colTextMuted: Qt.alpha(Theme.m3.on_surface_variant ?? Theme.subtext, 0.80)
    readonly property color colPrimary: Theme.m3.primary ?? Theme.accent
    readonly property color colOnPrimary: Theme.m3.on_primary ?? Theme.onAccent
    readonly property string uiFont: "Noto Sans"

    readonly property real plateHeight: 136
    readonly property real labelGap: 8
    readonly property real labelHeight: 24
    readonly property real tileGap: 14

    function sourceIcon(cid) {
        const srcs = Catalog.sources();
        for (let i = 0; i < srcs.length; i++) {
            if (srcs[i].id === cid) return srcs[i].icon;
        }
        return "widgets";
    }

    // Flat ordered list of shelf entries (optional category markers when viewing "All")
    readonly property var shelfEntries: {
        const order = ["resources", "time", "media", "system", "personal"];
        const q = String(root.searchQuery || "").trim().toLowerCase();
        const allDefs = Catalog.all();
        const want = (root.sourceFilter === "all") ? order : [root.sourceFilter];
        const showHeaders = (root.sourceFilter === "all" && q === "");
        const entries = [];

        for (let i = 0; i < want.length; i++) {
            const cid = want[i];
            const items = allDefs.filter(d => {
                if (d.source !== cid) return false;
                if (q !== "") {
                    const hay = (String(d.name || "") + " " + String(d.id || "") + " " + Catalog.sourceLabel(cid)).toLowerCase();
                    if (hay.indexOf(q) === -1) return false;
                }
                return true;
            });
            if (items.length === 0) continue;

            if (showHeaders) {
                entries.push({
                    kind: "divider",
                    cid: cid,
                    label: Catalog.sourceLabel(cid),
                    icon: sourceIcon(cid),
                    count: items.length
                });
            }
            for (let k = 0; k < items.length; k++) {
                entries.push({
                    kind: "tile",
                    def: items[k]
                });
            }
        }
        return entries;
    }

    property string draggingTileId: ""
    property string menuTileId: ""
    property real menuX: 0
    property real menuY: 0

    Connections {
        target: WidgetDragSession
        function onCanceled() {
            if (root.draggingTileId !== "") root.draggingTileId = "";
        }
    }

    function sidebarContainsWindowPoint(winX, winY) {
        if (typeof root.sidebarContainsFn === "function") return root.sidebarContainsFn(winX, winY);
        return true;
    }

    function scrollBy(dx) {
        const maxX = Math.max(0, shelfFlick.contentWidth - shelfFlick.width);
        shelfFlick.contentX = Math.max(0, Math.min(maxX, shelfFlick.contentX + Number(dx || 0)));
    }

    function scrollToFraction(frac) {
        const maxX = Math.max(0, shelfFlick.contentWidth - shelfFlick.width);
        shelfFlick.contentX = Math.round(maxX * Math.max(0, Math.min(1, Number(frac || 0))));
    }

    function closeContextMenu() {
        root.menuTileId = "";
    }

    function openContextMenu(tileId, winPtX, winPtY) {
        const targetParent = root.overlayHost || root;
        const pt = targetParent.mapFromItem(null, winPtX, winPtY);
        const menuW = 244;
        const menuH = Math.max(120, contextMenu.height);
        root.menuTileId = tileId;
        root.menuX = Math.round(Math.max(10, Math.min(targetParent.width - menuW - 10, pt.x - menuW / 2)));
        root.menuY = Math.round(Math.max(54, pt.y - menuH - 12));
    }

    onSourceFilterChanged: {
        shelfFlick.contentX = 0;
        root.menuTileId = "";
    }
    onSearchQueryChanged: shelfFlick.contentX = 0

    // Empty Search State
    Column {
        visible: root.shelfEntries.length === 0
        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "search_off"
            iconSize: 30
            color: root.colTextMuted
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No matching widgets"
            color: root.colText
            font.family: root.uiFont
            font.pixelSize: 14
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
        }
    }

    // Horizontal Paged Showcase Track
    Flickable {
        id: shelfFlick
        anchors {
            fill: parent
            topMargin: 6
            bottomMargin: 2
        }
        clip: true
        contentWidth: Math.max(width, shelfRow.implicitWidth)
        contentHeight: height
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickableDirection: Flickable.HorizontalFlick

        Behavior on contentX {
            NumberAnimation {
                duration: 210
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                    ? -event.angleDelta.x
                    : -event.angleDelta.y;
                root.scrollBy(delta * 1.45);
                event.accepted = true;
            }
        }

        Row {
            id: shelfRow
            height: shelfFlick.height
            spacing: root.tileGap

            Repeater {
                model: root.shelfEntries

                delegate: Item {
                    id: slotRoot
                    required property var modelData
                    readonly property bool isDivider: modelData.kind === "divider"

                    width: isDivider ? dividerCard.width : tileLoader.width
                    height: shelfRow.height

                    // Sleek iNiR Category Anchor Pillar (only in "All" unfiltered view)
                    Rectangle {
                        id: dividerCard
                        visible: slotRoot.isDivider
                        width: slotRoot.isDivider ? 88 : 0
                        height: root.plateHeight
                        y: 0
                        radius: 8
                        color: Qt.alpha(root.colLayer2, 0.65)
                        border.width: 1
                        border.color: root.colBorderSubtle

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 10 }
                            width: 2
                            radius: 1
                            color: Qt.alpha(root.colPrimary, 0.65)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            width: parent.width - 20

                            MaterialSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: slotRoot.isDivider ? slotRoot.modelData.icon : ""
                                iconSize: 22
                                fill: 1
                                color: root.colPrimary
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: slotRoot.isDivider ? slotRoot.modelData.label : ""
                                color: root.colText
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                                renderType: Text.QtRendering
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: slotRoot.isDivider ? (slotRoot.modelData.count + " items") : ""
                                color: root.colTextMuted
                                font.family: root.uiFont
                                font.pixelSize: 11
                                renderType: Text.QtRendering
                            }
                        }
                    }

                    // True-Aspect Showcase Plate + Readable Footer Title
                    Item {
                        id: tileLoader
                        visible: !slotRoot.isDivider
                        width: visible ? Math.max(plate.width, titleRow.implicitWidth + 6) : 0
                        height: visible ? shelfRow.height : 0

                        readonly property var def: !slotRoot.isDivider ? slotRoot.modelData.def : null
                        readonly property string tileId: def ? def.id : ""
                        readonly property string title: def ? def.name : ""
                        readonly property string icon: def ? def.icon : "widgets"
                        readonly property var cardDim: def ? WidgetStore.cardSize(tileId) : ({ width: 172, height: 172 })
                        readonly property var cardSpan: def
                            ? Catalog.spanForSizeMode(WidgetStore.cardOption(tileId, "sizeMode", ""), def.columnSpan, def.rowSpan)
                            : ({ columnSpan: 1, rowSpan: 1 })
                        readonly property real aspect: cardDim.width / Math.max(1, cardDim.height)
                        readonly property real plateW: Math.round(Math.max(122, Math.min(340, root.plateHeight * aspect)))
                        readonly property bool placed: def ? WidgetStore.isPinned(tileId) : false
                        readonly property bool isDragged: def ? (root.draggingTileId === tileId) : false

                        readonly property real fit: Math.min(
                            (plateW - 14) / Math.max(1, cardDim.width),
                            (root.plateHeight - 14) / Math.max(1, cardDim.height),
                            0.94
                        )
                        readonly property real shownW: Math.round(cardDim.width * fit)
                        readonly property real shownH: Math.round(cardDim.height * fit)

                        opacity: isDragged ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        // Plate Surface
                        Rectangle {
                            id: plate
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            width: tileLoader.plateW
                            height: root.plateHeight
                            radius: 8
                            color: tileLoader.placed
                                ? root.colSelection
                                : (tileMouse.containsMouse ? root.colLayer3 : root.colLayer2)
                            border.width: 1
                            border.color: tileLoader.placed
                                ? root.colBorderFocus
                                : (tileMouse.containsMouse ? root.colBorder : root.colBorderSubtle)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            // Hard clip guard inside plate ensures wide/complex cards (e.g. Disk I/O) never spill
                            Item {
                                id: previewClip
                                anchors.centerIn: parent
                                width: tileLoader.shownW
                                height: tileLoader.shownH
                                clip: true
                                enabled: false

                                WidgetCardContent {
                                    width: tileLoader.cardDim.width
                                    height: tileLoader.cardDim.height
                                    scale: tileLoader.fit
                                    transformOrigin: Item.TopLeft
                                    layer.enabled: root.active && !tileLoader.isDragged && width > 1 && height > 1
                                    layer.smooth: true
                                    layer.mipmap: true
                                    layer.textureSize: Qt.size(
                                        Math.max(1, Math.round(width * WidgetStore.qtScale)),
                                        Math.max(1, Math.round(height * WidgetStore.qtScale))
                                    )
                                    tileId: tileLoader.tileId
                                    active: root.active && !tileLoader.isDragged
                                    interactive: false
                                    notchRoot: root.notchRoot
                                }
                            }

                            // Subtle Top-Right Status Badge (+ on hover / check when pinned)
                            Rectangle {
                                anchors { top: parent.top; right: parent.right; margins: 7 }
                                width: 24
                                height: 24
                                radius: 12
                                visible: tileLoader.placed || tileMouse.containsMouse
                                color: tileLoader.placed ? root.colPrimary : root.colLayer1
                                border.width: 1
                                border.color: tileLoader.placed ? root.colPrimary : root.colBorder

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: tileLoader.placed ? "check" : "add"
                                    iconSize: 15
                                    fill: 1
                                    color: tileLoader.placed ? root.colOnPrimary : root.colText
                                }
                            }

                            // Pointer & Drag-Up-to-Desktop Interaction
                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                cursorShape: tileLoader.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                property point pressAt: Qt.point(0, 0)
                                property string gesture: ""
                                preventStealing: gesture === "pull"

                                onPressed: (mouse) => {
                                    root.menuTileId = "";
                                    pressAt = Qt.point(mouse.x, mouse.y);
                                    gesture = "";
                                }

                                onPositionChanged: (mouse) => {
                                    if (!pressed || !(pressedButtons & Qt.LeftButton) || slotRoot.isDivider) return;
                                    const dx = mouse.x - pressAt.x;
                                    const dy = mouse.y - pressAt.y;

                                    if (gesture === "") {
                                        // Pulling upward (out of bottom shelf) starts live desktop drag placement
                                        if (dy < -10 && Math.abs(dy) >= Math.abs(dx) * 0.65) {
                                            if (!WidgetDragSession.active && WidgetDragSession.begin(tileLoader.tileId, plate, plate.width / 2, plate.height / 2)) {
                                                gesture = "pull";
                                                root.draggingTileId = tileLoader.tileId;
                                            } else {
                                                gesture = "scroll";
                                            }
                                        } else if (Math.abs(dx) > 12) {
                                            gesture = "scroll";
                                        }
                                    }

                                    if (gesture === "pull" && tileLoader.isDragged) {
                                        const winPt = plate.mapToItem(null, mouse.x, mouse.y);
                                        const insideTray = root.sidebarContainsWindowPoint(winPt.x, winPt.y);
                                        const hostPt = WidgetDragSession.mapItemPoint(root.screenName, plate, mouse.x, mouse.y);
                                        const host = WidgetDragSession.hostFor(root.screenName);
                                        if (!insideTray && hostPt && host) {
                                            if (!WidgetDragSession.presentationActive) {
                                                const realSz = WidgetStore.cardSize(tileLoader.tileId);
                                                WidgetDragSession.promoteToDesktop(
                                                    root.screenName, hostPt.x, hostPt.y,
                                                    realSz.width / 2, realSz.height / 2,
                                                    realSz.width, realSz.height,
                                                    host.width, host.height
                                                );
                                            } else {
                                                WidgetDragSession.update(hostPt.x, hostPt.y);
                                            }
                                        }
                                    }
                                }

                                onReleased: (mouse) => {
                                    if (gesture === "pull" && tileLoader.isDragged) {
                                        const winPt = plate.mapToItem(null, mouse.x, mouse.y);
                                        const insideTray = root.sidebarContainsWindowPoint(winPt.x, winPt.y);
                                        if (!insideTray && WidgetDragSession.presentationActive) {
                                            const hostW = WidgetDragSession.hostWidth;
                                            const hostH = WidgetDragSession.hostHeight;
                                            const size = WidgetStore.cardSize(tileLoader.tileId);
                                            const topInset = 46;
                                            let gx = Math.max(0, Math.min(Math.max(0, hostW - size.width), WidgetDragSession.ghostX));
                                            let gy = Math.max(topInset, Math.min(Math.max(topInset, hostH - size.height), WidgetDragSession.ghostY));
                                            if (WidgetStore.gridSnapEnabled) {
                                                const sp = DesktopLayout.snapPoint(gx, gy, size.width, size.height, hostW, hostH, topInset, WidgetStore.s(Catalog.cardGridStep));
                                                gx = sp.x;
                                                gy = sp.y;
                                            }
                                            const norm = State.normalizedPosition(gx, gy, hostW, hostH);
                                            const resolvedRects = WidgetDragSession.resolveDesktopDrop(root.screenName, tileLoader.tileId, gx, gy, size.width, size.height);
                                            const positions = [];
                                            if (Array.isArray(resolvedRects)) {
                                                resolvedRects.forEach(r => {
                                                    if (!r || !r.id) return;
                                                    const p = State.normalizedPosition(r.x, r.y, hostW, hostH);
                                                    positions.push({ id: String(r.id), xNorm: p.xNorm, yNorm: p.yNorm });
                                                });
                                            }
                                            WidgetDragSession.commitDrop(gx, gy);
                                            WidgetStore.setContainer(tileLoader.tileId, "desktop", root.screenName, norm.xNorm, norm.yNorm);
                                            if (positions.length > 0) WidgetStore.setDesktopPositions(positions);
                                            WidgetDragSession.requestHandoffCheck(tileLoader.tileId);
                                        } else {
                                            WidgetDragSession.cancel();
                                        }
                                        root.draggingTileId = "";
                                    }
                                }

                                onCanceled: {
                                    if (tileLoader.isDragged) {
                                        WidgetDragSession.cancel();
                                        root.draggingTileId = "";
                                    }
                                    gesture = "";
                                }

                                onClicked: (mouse) => {
                                    if (slotRoot.isDivider || gesture !== "") return;
                                    if (mouse.button === Qt.RightButton) {
                                        const winPt = plate.mapToItem(null, mouse.x, mouse.y);
                                        root.openContextMenu(tileLoader.tileId, winPt.x, winPt.y);
                                        return;
                                    }
                                    if (mouse.button === Qt.LeftButton) {
                                        WidgetStore.togglePin(tileLoader.tileId, root.screenName);
                                    }
                                }
                            }
                        }

                        // Clean Legible Label + Span Tag Underneath Plate
                        Row {
                            id: titleRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.plateHeight + root.labelGap
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tileLoader.title
                                color: tileLoader.placed ? root.colPrimary : root.colText
                                font.family: root.uiFont
                                font.pixelSize: 13
                                font.weight: tileLoader.placed ? Font.Bold : Font.DemiBold
                                renderType: Text.QtRendering
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: spanLbl.implicitWidth + 10
                                height: 18
                                radius: 4
                                color: root.colLayer2
                                border.width: 1
                                border.color: root.colBorderSubtle

                                Text {
                                    id: spanLbl
                                    anchors.centerIn: parent
                                    text: tileLoader.cardSpan.rowSpan + "×" + tileLoader.cardSpan.columnSpan
                                    color: root.colTextMuted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    renderType: Text.QtRendering
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Left / Right Shelf Scroll Buttons
    Repeater {
        model: [
            { dir: -1, icon: "chevron_left", can: shelfFlick.contentX > 4 },
            { dir: 1, icon: "chevron_right", can: shelfFlick.contentX < Math.max(0, shelfFlick.contentWidth - shelfFlick.width - 4) }
        ]

        delegate: Rectangle {
            required property var modelData
            visible: shelfFlick.contentWidth > shelfFlick.width + 8 && modelData.can
            x: modelData.dir < 0 ? 4 : root.width - width - 4
            y: Math.round(6 + (root.plateHeight - height) / 2)
            width: 32
            height: 32
            radius: 16
            color: navMa.containsMouse ? root.colLayer3 : Qt.alpha(root.colLayer1, 0.92)
            border.width: 1
            border.color: navMa.containsMouse ? root.colBorderFocus : root.colBorder
            z: 20

            MaterialSymbol {
                anchors.centerIn: parent
                text: modelData.icon
                iconSize: 20
                color: navMa.containsMouse ? root.colPrimary : root.colText
            }

            MouseArea {
                id: navMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.scrollBy(modelData.dir * Math.round(shelfFlick.width * 0.65))
            }
        }
    }

    // Floating iNiR Options Menu (hosted in overlayHost so it opens cleanly above the shelf without clipping)
    Rectangle {
        id: contextMenu
        parent: root.overlayHost || root
        visible: root.menuTileId !== ""
        x: root.menuX
        y: root.menuY
        width: 244
        height: menuCol.implicitHeight + 16
        z: 400
        radius: 12
        color: root.colLayer1
        border.width: 1
        border.color: root.colBorder

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 2

            MenuRow {
                icon: WidgetStore.isPinned(root.menuTileId) ? "dock_to_left" : "pin_drop"
                label: WidgetStore.isPinned(root.menuTileId) ? "Unpin from desktop" : "Pin to desktop"
                onTriggered: {
                    const id = root.menuTileId;
                    root.menuTileId = "";
                    WidgetStore.togglePin(id, root.screenName);
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
                readonly property var def: root.menuTileId !== "" ? Catalog.definitionFor(root.menuTileId) : null
                readonly property var modes: (def && Array.isArray(def.sizeModes)) ? def.sizeModes : []
                visible: modes.length > 0
                icon: "aspect_ratio"
                label: {
                    if (modes.length === 0) return "";
                    const cur = String(WidgetStore.cardOption(root.menuTileId, "sizeMode", modes[0]));
                    return root.menuTileId === "end4Resources"
                        ? ("Layout: " + (cur === "3x1" ? "Vertical" : "Horizontal"))
                        : ("Cycle Size (" + cur.replace("x", "×") + ")");
                }
                onTriggered: {
                    const idx = modes.indexOf(String(WidgetStore.cardOption(root.menuTileId, "sizeMode", modes[0])));
                    const next = modes[(idx + 1) % modes.length];
                    WidgetStore.setCardOption(root.menuTileId, "sizeMode", next);
                }
            }

            MenuRow {
                visible: root.menuTileId === "weather" || root.menuTileId === "end4Weather"
                icon: "thermostat"
                label: {
                    const u = String(WidgetStore.cardOption(root.menuTileId, "unitMode", "auto"));
                    return "Units: " + (u === "c" ? "°C" : (u === "f" ? "°F" : "Auto"));
                }
                onTriggered: {
                    const order = ["auto", "c", "f"];
                    const cur = String(WidgetStore.cardOption(root.menuTileId, "unitMode", "auto"));
                    WidgetStore.setCardOption(root.menuTileId, "unitMode", order[(order.indexOf(cur) + 1) % order.length]);
                }
            }

            MenuRow {
                visible: root.menuTileId === "bgVisualiser"
                icon: "graphic_eq"
                label: {
                    const s = String(WidgetStore.cardOption("bgVisualiser", "visStyle", "wave_outlined"));
                    return "Style: " + (s === "wave_outlined" ? "Outlined Wave" : (s === "wave" ? "Pure Wave" : "Bars"));
                }
                onTriggered: {
                    const order = ["wave_outlined", "wave", "bars"];
                    const cur = String(WidgetStore.cardOption("bgVisualiser", "visStyle", "wave_outlined"));
                    WidgetStore.setCardOption("bgVisualiser", "visStyle", order[(order.indexOf(cur) + 1) % order.length]);
                }
            }

            MenuRow {
                visible: root.menuTileId === "bgVisualiser"
                icon: "visibility"
                label: WidgetStore.cardOption("bgVisualiser", "alwaysVisible", false) ? "Demo Wave: On" : "Auto-Hide on Silence"
                onTriggered: WidgetStore.setCardOption("bgVisualiser", "alwaysVisible", !WidgetStore.cardOption("bgVisualiser", "alwaysVisible", false))
            }

            MenuRow {
                visible: root.menuTileId === "resources"
                icon: "waves"
                label: {
                    const f = String(WidgetStore.cardOption("resources", "fillMode", "wave"));
                    return "Fill: " + (f === "wave" ? "Wave" : (f === "linear" ? "Linear" : "Shape"));
                }
                onTriggered: {
                    const order = ["wave", "linear", "shape"];
                    const cur = String(WidgetStore.cardOption("resources", "fillMode", "wave"));
                    WidgetStore.setCardOption("resources", "fillMode", order[(order.indexOf(cur) + 1) % order.length]);
                }
            }

            MenuRow {
                visible: root.menuTileId === "github"
                icon: "palette"
                label: String(WidgetStore.cardOption("github", "colorMode", "accent")) === "github"
                    ? "Palette: GitHub Green"
                    : "Palette: Shell Accent"
                onTriggered: {
                    const cur = String(WidgetStore.cardOption("github", "colorMode", "accent"));
                    WidgetStore.setCardOption("github", "colorMode", cur === "github" ? "accent" : "github");
                }
            }

            MenuRow {
                visible: root.menuTileId === "end4Media"
                icon: "lyrics"
                label: WidgetStore.cardOption("end4Media", "showLyrics", false) ? "Lyrics Drawer: On" : "Lyrics Drawer: Off"
                onTriggered: WidgetStore.setCardOption("end4Media", "showLyrics", !WidgetStore.cardOption("end4Media", "showLyrics", false))
            }

            MenuRow {
                visible: root.menuTileId === "image"
                icon: "subtitles"
                label: WidgetStore.cardOption("image", "showCaption", true) ? "Caption: Shown" : "Caption: Hidden"
                onTriggered: WidgetStore.setCardOption("image", "showCaption", !WidgetStore.cardOption("image", "showCaption", true))
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
        height: visible ? 36 : 0
        radius: 6
        color: rowMouse.containsMouse ? root.colLayerHover : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 9

            MaterialSymbol {
                text: icon
                iconSize: 17
                color: rowMouse.containsMouse ? root.colPrimary : root.colTextMuted
            }
            Text {
                Layout.fillWidth: true
                text: label
                color: root.colText
                font.family: root.uiFont
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                renderType: Text.QtRendering
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
