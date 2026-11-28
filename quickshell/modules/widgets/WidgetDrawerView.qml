import QtQuick
import QtQuick.Layouts
import "../../"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog
import "WidgetDesktopLayout.js" as DesktopLayout
import "WidgetState.js" as State

// Sharp Material 3 Widget Gallery with mipmapped 1:1 widget stages and clean metadata footers
Item {
    id: root

    property string screenName: ""
    property bool active: true
    property string sourceFilter: "all"
    property string searchQuery: ""
    property var notchRoot: null
    property var sidebarContainsFn: null

    readonly property real px1: WidgetStore.uiScale

    function snapPx(v) {
        return Math.round(Number(v) * WidgetStore.qtScale) * WidgetStore.uiScale;
    }

    function floorPx(v) {
        return Math.floor(Number(v) * WidgetStore.qtScale) * WidgetStore.uiScale;
    }

    readonly property var categorySections: {
        const order = ["resources", "time", "media", "system", "personal"];
        const q = String(root.searchQuery || "").trim().toLowerCase();
        const allDefs = Catalog.all();
        const want = (root.sourceFilter === "all") ? order : [root.sourceFilter];
        const groups = [];
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
            // Place compact (<=2 col) items before full-width (>=3 col) cards so pairs never orphan
            items.sort((a, b) => {
                const aw = WidgetStore.cardSize(a.id).width >= WidgetStore.s(380) ? 1 : 0;
                const bw = WidgetStore.cardSize(b.id).width >= WidgetStore.s(380) ? 1 : 0;
                return aw - bw;
            });
            groups.push({
                id: cid,
                label: Catalog.sourceLabel(cid),
                icon: sourceIcon(cid),
                items: items
            });
        }
        return groups;
    }

    function sourceIcon(cid) {
        const srcs = Catalog.sources();
        for (let i = 0; i < srcs.length; i++) {
            if (srcs[i].id === cid) return srcs[i].icon;
        }
        return "widgets";
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
        const pad = WidgetStore.s(8);
        const menuW = WidgetStore.s(210);
        const menuH = contextMenu.height > 0 ? contextMenu.height : WidgetStore.s(130);
        menuX = root.snapPx(Math.max(pad, Math.min(Math.max(pad, root.width - menuW - pad), localPt.x - menuW / 2)));
        menuY = root.snapPx(Math.max(pad, Math.min(Math.max(pad, root.height - menuH - pad), localPt.y + WidgetStore.s(4))));
        menuTileId = tileId;
    }

    // Empty search state
    Column {
        visible: root.categorySections.length === 0
        anchors.centerIn: parent
        spacing: WidgetStore.s(8)

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "search_off"
            iconSize: WidgetStore.si(28)
            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
            opacity: 0.65
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No matching widgets"
            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(12)
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
    }

    Flickable {
        id: scrollView
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: sectionsCol.implicitHeight + WidgetStore.s(12)
        interactive: root.draggingTileId === ""
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3000

        Column {
            id: sectionsCol
            width: root.floorPx(scrollView.width - WidgetStore.s(12))
            spacing: WidgetStore.s(20)

            Repeater {
                model: root.categorySections

                delegate: Column {
                    id: sectionCol
                    required property var modelData
                    width: sectionsCol.width
                    spacing: WidgetStore.s(10)

                    // Refined Category Section Header
                    RowLayout {
                        width: parent.width
                        spacing: WidgetStore.s(8)

                        MaterialSymbol {
                            text: sectionCol.modelData.icon || "widgets"
                            iconSize: WidgetStore.si(14)
                            color: Theme.m3.primary ?? Theme.accent
                        }

                        Text {
                            text: sectionCol.modelData.label
                            color: Theme.m3.on_surface ?? Theme.colors.text_primary
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(12)
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.px1
                            color: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.25)
                        }

                        Rectangle {
                            Layout.preferredWidth: root.snapPx(cntTxt.implicitWidth + WidgetStore.s(12))
                            Layout.preferredHeight: WidgetStore.s(18)
                            radius: height / 2
                            color: Theme.m3.surface_container ?? Theme.colors.card_bg
                            border.width: root.px1
                            border.color: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.30)

                            Text {
                                id: cntTxt
                                anchors.centerIn: parent
                                text: String(sectionCol.modelData.items.length)
                                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(10)
                                font.weight: Font.Bold
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    // Responsive Flow Grid (wide 3-col cards span full width; compact cards pack 2-up on aligned integer pixels)
                    Flow {
                        id: cardsFlow
                        width: parent.width
                        readonly property real gridGap: root.snapPx(WidgetStore.s(10))
                        spacing: gridGap

                        Repeater {
                            model: sectionCol.modelData.items

                            delegate: Rectangle {
                                id: cardSlot

                                required property var modelData
                                readonly property string tileId: modelData.id
                                readonly property string title: modelData.name
                                readonly property string icon: modelData.icon
                                readonly property var cardDim: WidgetStore.cardSize(tileId)
                                readonly property bool placed: WidgetStore.isPinned(tileId)
                                readonly property bool isDragged: root.draggingTileId === tileId

                                readonly property bool wideSpan: cardDim.width >= WidgetStore.s(380)
                                readonly property real slotW: wideSpan
                                    ? sectionCol.width
                                    : root.floorPx((sectionCol.width - cardsFlow.gridGap - root.px1) / 2)
                                readonly property real stagePadX: WidgetStore.s(12)
                                readonly property real stagePadY: WidgetStore.s(12)
                                readonly property real footerH: WidgetStore.s(34)

                                readonly property real stageW: slotW - stagePadX * 2
                                readonly property real stageMaxH: wideSpan
                                    ? (cardDim.height > cardDim.width * 0.55 ? WidgetStore.s(206) : WidgetStore.s(144))
                                    : WidgetStore.s(134)

                                readonly property real fit: Math.min(
                                    stageW / Math.max(1, cardDim.width),
                                    stageMaxH / Math.max(1, cardDim.height),
                                    wideSpan ? 0.98 : 0.86
                                )
                                readonly property real shownW: root.snapPx(cardDim.width * fit)
                                readonly property real shownH: root.snapPx(cardDim.height * fit)
                                readonly property real stageWellH: wideSpan
                                    ? root.snapPx(Math.max(WidgetStore.s(76), shownH + stagePadY * 2))
                                    : WidgetStore.s(154)

                                width: slotW
                                height: stageWellH + footerH
                                radius: WidgetStore.s(18)
                                clip: true
                                opacity: isDragged ? 0.35 : 1.0
                                color: placed
                                    ? Qt.alpha(Theme.m3.primary_container ?? Theme.colors.card_bg, slotMouse.containsMouse ? 0.28 : 0.18)
                                    : (slotMouse.containsMouse
                                        ? (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)
                                        : (Theme.m3.surface_container ?? Theme.colors.card_bg))
                                border.width: root.px1
                                border.color: placed
                                    ? Qt.alpha(Theme.m3.primary ?? Theme.accent, slotMouse.containsMouse ? 0.78 : 0.55)
                                    : Qt.alpha(Theme.m3.outline_variant ?? "#49454f", slotMouse.containsMouse ? 0.52 : 0.26)

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on border.color { ColorAnimation { duration: 140 } }

                                // Clean Showcase Stage (no inner dark box bezel; crisp mipmapped 1:1 widget texture)
                                Item {
                                    id: previewWell
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                    }
                                    height: cardSlot.stageWellH

                                    Item {
                                        width: cardSlot.shownW
                                        height: cardSlot.shownH
                                        x: root.snapPx((previewWell.width - width) / 2)
                                        y: root.snapPx((previewWell.height - height) / 2)
                                        enabled: false

                                        WidgetCardContent {
                                            width: cardSlot.cardDim.width
                                            height: cardSlot.cardDim.height
                                            scale: cardSlot.fit
                                            transformOrigin: Item.TopLeft
                                            // Render live widget into a native 1:1 mipmapped FBO texture so NativeRendering glyphs & hairlines downsample crisply without jagged blur
                                            layer.enabled: root.active && !cardSlot.isDragged && cardSlot.fit < 0.99
                                            layer.smooth: true
                                            layer.mipmap: true
                                            layer.textureSize: Qt.size(
                                                Math.max(1, Math.round(cardSlot.cardDim.width * WidgetStore.qtScale)),
                                                Math.max(1, Math.round(cardSlot.cardDim.height * WidgetStore.qtScale))
                                            )
                                            tileId: cardSlot.tileId
                                            active: root.active && !cardSlot.isDragged
                                            interactive: false
                                            notchRoot: root.notchRoot
                                        }
                                    }
                                }

                                // Tonal Footer Strip separated by 1px hairline
                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: root.px1
                                        rightMargin: root.px1
                                        bottomMargin: root.px1
                                    }
                                    height: cardSlot.footerH - root.px1
                                    bottomLeftRadius: Math.max(0, cardSlot.radius - root.px1)
                                    bottomRightRadius: Math.max(0, cardSlot.radius - root.px1)
                                    color: Qt.alpha(Theme.m3.surface_container_highest ?? "#262630", cardSlot.placed ? 0.36 : 0.28)

                                    Rectangle {
                                        anchors { top: parent.top; left: parent.left; right: parent.right }
                                        height: root.px1
                                        color: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.22)
                                    }
                                }

                                // Clean Bottom Metadata & Action Bar (never overlaps widget preview!)
                                RowLayout {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: WidgetStore.s(12)
                                        rightMargin: WidgetStore.s(10)
                                    }
                                    height: cardSlot.footerH
                                    spacing: WidgetStore.s(6)

                                    MaterialSymbol {
                                        text: cardSlot.icon
                                        iconSize: WidgetStore.si(14)
                                        color: cardSlot.placed
                                            ? (Theme.m3.primary ?? Theme.accent)
                                            : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: cardSlot.title
                                        color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                        font.family: "Google Sans Flex"
                                        font.pixelSize: WidgetStore.si(11.5)
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }

                                    // Grid Size Pill
                                    Rectangle {
                                        visible: cardSlot.wideSpan || (!cardSlot.placed && !slotMouse.containsMouse)
                                        Layout.preferredWidth: root.snapPx(dimTxt.implicitWidth + WidgetStore.s(10))
                                        Layout.preferredHeight: WidgetStore.s(18)
                                        radius: height / 2
                                        color: Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.07)

                                        Text {
                                            id: dimTxt
                                            anchors.centerIn: parent
                                            readonly property var opts: WidgetStore.cardOptions(cardSlot.tileId)
                                            text: opts && opts.sizeMode
                                                ? String(opts.sizeMode).replace("x", "×")
                                                : (cardSlot.modelData.rowSpan + "×" + cardSlot.modelData.columnSpan)
                                            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                            font.family: "Google Sans Flex"
                                            font.pixelSize: WidgetStore.si(9.5)
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    // Crisp Pinned / Pin Status Chip cleanly in the footer
                                    Rectangle {
                                        visible: cardSlot.placed || slotMouse.containsMouse
                                        Layout.preferredWidth: root.snapPx(badgeRow.implicitWidth + WidgetStore.s(12))
                                        Layout.preferredHeight: WidgetStore.s(20)
                                        radius: height / 2
                                        color: cardSlot.placed
                                            ? (Theme.m3.primary ?? Theme.accent)
                                            : (Theme.m3.primary_container ?? (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg))

                                        Row {
                                            id: badgeRow
                                            anchors.centerIn: parent
                                            spacing: WidgetStore.s(3)

                                            MaterialSymbol {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: cardSlot.placed ? "check" : "add"
                                                iconSize: WidgetStore.si(12)
                                                fill: 1
                                                color: cardSlot.placed
                                                    ? (Theme.m3.on_primary ?? "#101014")
                                                    : (Theme.m3.on_primary_container ?? (Theme.m3.on_surface ?? "#ffffff"))
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: cardSlot.placed ? (cardSlot.wideSpan ? "Pinned" : "On") : "Add"
                                                color: cardSlot.placed
                                                    ? (Theme.m3.on_primary ?? "#101014")
                                                    : (Theme.m3.on_primary_container ?? (Theme.m3.on_surface ?? "#ffffff"))
                                                font.family: "Google Sans Flex"
                                                font.pixelSize: WidgetStore.si(9.5)
                                                font.weight: Font.Bold
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: slotMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: cardSlot.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                    property point pressAt: Qt.point(0, 0)
                                    property string gesture: ""
                                    preventStealing: gesture === "pull"

                                    onPressed: (mouse) => {
                                        root.menuTileId = "";
                                        pressAt = Qt.point(mouse.x, mouse.y);
                                        gesture = "";
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!pressed || !(pressedButtons & Qt.LeftButton)) return;
                                        const dx = mouse.x - pressAt.x;
                                        const dy = mouse.y - pressAt.y;

                                        if (gesture === "") {
                                            if (Math.abs(dx) > WidgetStore.s(12) && Math.abs(dx) >= Math.abs(dy) * 0.9) {
                                                if (!WidgetDragSession.active && WidgetDragSession.begin(cardSlot.tileId, cardSlot, cardSlot.width / 2, cardSlot.height / 2)) {
                                                    gesture = "pull";
                                                    root.draggingTileId = cardSlot.tileId;
                                                } else {
                                                    gesture = "scroll";
                                                }
                                            } else if (Math.abs(dy) > WidgetStore.s(12)) {
                                                gesture = "scroll";
                                            }
                                        }

                                        if (gesture === "pull" && cardSlot.isDragged) {
                                            const winPt = cardSlot.mapToItem(null, mouse.x, mouse.y);
                                            const insideTray = root.sidebarContainsWindowPoint(winPt.x, winPt.y);
                                            const hostPt = WidgetDragSession.mapItemPoint(root.screenName, cardSlot, mouse.x, mouse.y);
                                            const host = WidgetDragSession.hostFor(root.screenName);
                                            if (!insideTray && hostPt && host) {
                                                if (!WidgetDragSession.presentationActive) {
                                                    const realSz = WidgetStore.cardSize(cardSlot.tileId);
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
                                        if (gesture === "pull" && cardSlot.isDragged) {
                                            const winPt = cardSlot.mapToItem(null, mouse.x, mouse.y);
                                            const insideTray = root.sidebarContainsWindowPoint(winPt.x, winPt.y);
                                            if (!insideTray && WidgetDragSession.presentationActive) {
                                                const hostW = WidgetDragSession.hostWidth;
                                                const hostH = WidgetDragSession.hostHeight;
                                                const size = WidgetStore.cardSize(cardSlot.tileId);
                                                const topInset = 46;
                                                let gx = Math.max(0, Math.min(Math.max(0, hostW - size.width), WidgetDragSession.ghostX));
                                                let gy = Math.max(topInset, Math.min(Math.max(topInset, hostH - size.height), WidgetDragSession.ghostY));
                                                if (WidgetStore.gridSnapEnabled) {
                                                    const sp = DesktopLayout.snapPoint(gx, gy, size.width, size.height, hostW, hostH, topInset, WidgetStore.s(Catalog.cardGridStep));
                                                    gx = sp.x;
                                                    gy = sp.y;
                                                }
                                                const norm = State.normalizedPosition(gx, gy, hostW, hostH);
                                                const resolvedRects = WidgetDragSession.resolveDesktopDrop(root.screenName, cardSlot.tileId, gx, gy, size.width, size.height);
                                                const positions = [];
                                                if (Array.isArray(resolvedRects)) {
                                                    resolvedRects.forEach(r => {
                                                        if (!r || !r.id) return;
                                                        const p = State.normalizedPosition(r.x, r.y, hostW, hostH);
                                                        positions.push({ id: String(r.id), xNorm: p.xNorm, yNorm: p.yNorm });
                                                    });
                                                }
                                                WidgetDragSession.commitDrop(gx, gy);
                                                WidgetStore.setContainer(cardSlot.tileId, "desktop", root.screenName, norm.xNorm, norm.yNorm);
                                                if (positions.length > 0) WidgetStore.setDesktopPositions(positions);
                                                WidgetDragSession.requestHandoffCheck(cardSlot.tileId);
                                            } else {
                                                WidgetDragSession.cancel();
                                            }
                                            root.draggingTileId = "";
                                        }
                                    }

                                    onCanceled: {
                                        if (cardSlot.isDragged) {
                                            WidgetDragSession.cancel();
                                            root.draggingTileId = "";
                                        }
                                        gesture = "";
                                    }

                                    onClicked: (mouse) => {
                                        if (gesture !== "") {
                                            gesture = "";
                                            return;
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            const wp = cardSlot.mapToItem(null, mouse.x, mouse.y);
                                            root.openContextMenu(cardSlot.tileId, wp.x, wp.y);
                                            return;
                                        }
                                        WidgetStore.togglePin(cardSlot.tileId, root.screenName);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Vertical slim scrollbar
    Rectangle {
        visible: scrollView.contentHeight > scrollView.height + 4
        anchors { right: parent.right; rightMargin: WidgetStore.s(1) }
        y: (scrollView.contentY / Math.max(1, scrollView.contentHeight)) * parent.height
        width: WidgetStore.s(3)
        height: Math.max(WidgetStore.s(36), (scrollView.height / Math.max(1, scrollView.contentHeight)) * parent.height)
        radius: WidgetStore.s(2)
        color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.55)
    }

    MouseArea {
        visible: root.menuTileId !== ""
        anchors.fill: parent
        z: 190
        onClicked: root.menuTileId = ""
    }

    // Crisp M3 Inline Context Menu
    Rectangle {
        id: contextMenu
        visible: root.menuTileId !== ""
        x: root.menuX
        y: root.menuY
        width: WidgetStore.s(210)
        height: menuCol.implicitHeight + WidgetStore.s(14)
        z: 200
        radius: WidgetStore.s(16)
        color: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg
        border.width: root.px1
        border.color: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.45)

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: WidgetStore.s(7) }
            spacing: WidgetStore.s(2)

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
        height: visible ? WidgetStore.s(32) : 0
        radius: WidgetStore.s(10)
        color: rowMouse.containsMouse
            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.16)
            : "transparent"

        Row {
            anchors {
                left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                leftMargin: WidgetStore.s(8); rightMargin: WidgetStore.s(8)
            }
            spacing: WidgetStore.s(8)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: icon
                iconSize: WidgetStore.si(15)
                color: rowMouse.containsMouse
                    ? (Theme.m3.primary ?? Theme.accent)
                    : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(11)
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
