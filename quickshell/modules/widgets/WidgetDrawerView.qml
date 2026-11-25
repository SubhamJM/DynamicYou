import QtQuick
import QtQuick.Layouts
import "../../"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog
import "WidgetDesktopLayout.js" as DesktopLayout
import "WidgetState.js" as State

Item {
    id: root

    property string screenName: ""
    property bool active: true
    property var notchRoot: null
    property var sidebarContainsFn: null

    readonly property var catalogDefs: Catalog.all()
    property string draggingTileId: ""
    property string menuTileId: ""
    property real menuX: 0
    property real menuY: 0

    Connections {
        target: WidgetDragSession
        function onCanceled() {
            if (root.draggingTileId !== "") {
                root.draggingTileId = "";
            }
        }
    }

    function sidebarContainsWindowPoint(winX, winY) {
        if (typeof root.sidebarContainsFn === "function") {
            return root.sidebarContainsFn(winX, winY);
        }
        return true;
    }

    function scrollBy(dx) {
        const maxX = Math.max(0, scrollView.contentWidth - scrollView.width);
        scrollView.contentX = Math.max(0, Math.min(maxX, scrollView.contentX + Number(dx || 0)));
    }

    function scrollToFraction(frac) {
        const maxX = Math.max(0, scrollView.contentWidth - scrollView.width);
        scrollView.contentX = Math.round(maxX * Math.max(0, Math.min(1, Number(frac || 0))));
    }

    function openContextMenu(tileId, winPtX, winPtY) {
        const localPt = root.mapFromItem(null, winPtX, winPtY);
        const pad = WidgetStore.s(8);
        const menuW = WidgetStore.s(198);
        const menuH = contextMenu.height > 0 ? contextMenu.height : WidgetStore.s(110);
        menuX = Math.max(pad, Math.min(Math.max(pad, root.width - menuW - pad), localPt.x - menuW / 2));
        menuY = Math.max(pad, Math.min(Math.max(pad, root.height - menuH - pad), localPt.y - menuH - WidgetStore.s(8)));
        menuTileId = tileId;
    }

    // Horizontal wheel-to-scroll over the shelf
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                ? event.angleDelta.x
                : event.angleDelta.y;
            if (delta !== 0) {
                root.scrollBy(-delta * 0.9);
                event.accepted = true;
            }
        }
    }

    Flickable {
        id: scrollView
        anchors.fill: parent
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        contentWidth: slotRow.implicitWidth + WidgetStore.s(28)
        contentHeight: height
        interactive: root.draggingTileId === ""
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3000

        Row {
            id: slotRow
            anchors.verticalCenter: parent.verticalCenter
            x: WidgetStore.s(12)
            spacing: WidgetStore.s(16)

            Repeater {
                model: root.catalogDefs

                delegate: Item {
                    id: slot

                    required property var modelData
                    required property int index

                    readonly property string tileId: modelData.id
                    readonly property string title: modelData.name
                    readonly property string icon: modelData.icon
                    readonly property var cardDim: WidgetStore.cardSize(tileId)
                    readonly property bool placed: WidgetStore.isPinned(tileId)
                    readonly property bool isDragged: root.draggingTileId === tileId

                    readonly property real boxW: WidgetStore.s(166)
                    readonly property real boxH: WidgetStore.s(96)
                    readonly property real fit: Math.min(boxW / Math.max(1, cardDim.width), boxH / Math.max(1, cardDim.height), 0.65)
                    readonly property real shownW: cardDim.width * fit
                    readonly property real shownH: cardDim.height * fit
                    readonly property real mountH: WidgetStore.s(132)

                    width: Math.max(WidgetStore.s(138), Math.round(shownW) + WidgetStore.s(28))
                    height: mountH + WidgetStore.s(22)
                    opacity: isDragged ? 0.35 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    property real lift: slotMouse.containsMouse ? 1 : 0
                    Behavior on lift {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    }

                    property real hop: 1
                    SequentialAnimation {
                        id: hopAnim
                        NumberAnimation { target: slot; property: "hop"; to: 0.90; duration: 75; easing.type: Easing.OutQuad }
                        NumberAnimation { target: slot; property: "hop"; to: 1.0; duration: 360; easing.type: Easing.OutBack; easing.overshoot: 2.8 }
                    }

                    Item {
                        id: holder
                        width: slot.width
                        height: slot.height
                        y: WidgetStore.s(6) - WidgetStore.s(6) * slot.lift
                        rotation: (slot.index % 2 === 0 ? -1.9 : 1.9) * (1.0 - Math.min(1.0, slot.lift))
                        scale: slot.hop * (slotMouse.pressed ? 0.97 : (1.0 + 0.03 * slot.lift))
                        transformOrigin: Item.Center

                        // Main framed miniature widget screen
                        SekaiPill {
                            id: mount
                            width: holder.width
                            height: slot.mountH
                            cornerRadius: WidgetStore.s(16)
                            borderWidth: WidgetStore.s(2.5)
                            ringWidth: WidgetStore.s(3.5)
                            shadowDy: WidgetStore.s(4)
                            pressed: slotMouse.pressed
                            fillColor: Theme.m3.surface_container_high ?? Theme.colors.card_bg
                            ringColor: slot.lift > 0.4
                                ? (Theme.m3.primary ?? Theme.accent)
                                : Qt.alpha(Theme.m3.on_surface ?? "#e0f8ff", 0.16)

                            // Recessed dark screen behind live widget thumbnail
                            Rectangle {
                                id: previewScreen
                                anchors {
                                    fill: parent
                                    margins: WidgetStore.s(4)
                                }
                                radius: WidgetStore.s(10)
                                color: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.15)
                                antialiasing: true
                                clip: true

                                Item {
                                    id: previewBox
                                    width: slot.shownW
                                    height: slot.shownH
                                    x: (previewScreen.width - width) / 2
                                    y: Math.max(WidgetStore.s(4), (previewScreen.height - WidgetStore.s(10) - height) / 2)
                                    opacity: slot.placed ? 0.46 : 1.0
                                    enabled: false

                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    WidgetCardContent {
                                        width: slot.cardDim.width
                                        height: slot.cardDim.height
                                        scale: slot.fit
                                        transformOrigin: Item.TopLeft
                                        tileId: slot.tileId
                                        active: root.active && !slot.isDragged
                                        interactive: false
                                        notchRoot: root.notchRoot
                                    }
                                }
                            }
                        }

                        // Tilted bottom name tag pill (flips to PIN / UNPIN on hover)
                        SekaiPill {
                            id: tagPill
                            readonly property string hoverLabel: slot.placed ? "UNPIN" : "PIN"

                            width: Math.min(holder.width + WidgetStore.s(10), tagTxt.implicitWidth + WidgetStore.s(22))
                            height: WidgetStore.s(25)
                            x: (holder.width - width) / 2
                            y: slot.mountH - WidgetStore.s(9)
                            cornerRadius: WidgetStore.s(9)
                            borderWidth: WidgetStore.s(2)
                            ringWidth: WidgetStore.s(2)
                            shadowDy: WidgetStore.s(2)
                            rotation: slot.index % 2 === 0 ? 1.8 : -1.8
                            fillColor: slot.lift > 0.5
                                ? (slot.placed ? (Theme.m3.secondary ?? Theme.accent) : (Theme.m3.primary ?? Theme.accent))
                                : (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)

                            Behavior on width {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                            }

                            Text {
                                id: tagTxt
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: slot.lift > 0.5 ? tagPill.hoverLabel : slot.title.toUpperCase()
                                color: slot.lift > 0.5
                                    ? (Theme.m3.on_primary ?? "#101014")
                                    : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(10)
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.5
                                font.hintingPreference: Font.PreferVerticalHinting
                                renderType: Text.NativeRendering
                            }
                        }

                        // Top-right corner status badge (check = pinned, + = ready)
                        SekaiPill {
                            id: badge
                            width: WidgetStore.s(27)
                            height: WidgetStore.s(29)
                            x: holder.width - WidgetStore.s(21)
                            y: -WidgetStore.s(6)
                            cornerRadius: WidgetStore.s(14)
                            borderWidth: WidgetStore.s(2)
                            ringWidth: WidgetStore.s(1.5)
                            shadowDx: WidgetStore.s(1.5)
                            shadowDy: WidgetStore.s(2.5)
                            fillColor: slot.placed
                                ? (Theme.m3.secondary ?? "#67e8f9")
                                : (Theme.m3.primary ?? Theme.accent)
                            scale: slot.placed ? 1.0 : (0.90 + 0.16 * Math.min(1.0, slot.lift))

                            Behavior on scale {
                                NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: slot.placed ? "check" : "add"
                                iconSize: WidgetStore.si(15)
                                fill: 1
                                color: Theme.m3.on_primary ?? "#101014"
                            }
                        }
                    }

                    SekaiBurst {
                        id: pinBurst
                        x: slot.width / 2
                        y: slot.mountH / 2
                        count: 8
                        radius: WidgetStore.s(54)
                        size: WidgetStore.s(9)
                        z: 30
                    }

                    MouseArea {
                        id: slotMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: slot.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                        property point pressAt: Qt.point(0, 0)
                        property string gesture: "" // "" | "pull" | "scroll"
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
                                if (Math.abs(dy) > WidgetStore.s(10) && Math.abs(dy) >= Math.abs(dx) * 0.9 && dy < 0) {
                                    if (!WidgetDragSession.active && WidgetDragSession.begin(slot.tileId, slot, slot.width / 2, slot.height / 2)) {
                                        gesture = "pull";
                                        root.draggingTileId = slot.tileId;
                                    } else {
                                        gesture = "scroll";
                                    }
                                } else if (Math.abs(dx) > WidgetStore.s(12)) {
                                    gesture = "scroll";
                                }
                            }

                            if (gesture === "pull" && slot.isDragged) {
                                const winPt = slot.mapToItem(null, mouse.x, mouse.y);
                                const insideTray = root.sidebarContainsWindowPoint(winPt.x, winPt.y);
                                const hostPt = WidgetDragSession.mapItemPoint(root.screenName, slot, mouse.x, mouse.y);
                                const host = WidgetDragSession.hostFor(root.screenName);
                                if (!insideTray && hostPt && host) {
                                    if (!WidgetDragSession.presentationActive) {
                                        const realSz = WidgetStore.cardSize(slot.tileId);
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
                            if (gesture === "pull" && slot.isDragged) {
                                const winPt = slot.mapToItem(null, mouse.x, mouse.y);
                                const insideTray = root.sidebarContainsWindowPoint(winPt.x, winPt.y);
                                if (!insideTray && WidgetDragSession.presentationActive) {
                                    const hostW = WidgetDragSession.hostWidth;
                                    const hostH = WidgetDragSession.hostHeight;
                                    const size = WidgetStore.cardSize(slot.tileId);
                                    const topInset = 46;
                                    let gx = Math.max(0, Math.min(Math.max(0, hostW - size.width), WidgetDragSession.ghostX));
                                    let gy = Math.max(topInset, Math.min(Math.max(topInset, hostH - size.height), WidgetDragSession.ghostY));
                                    if (WidgetStore.gridSnapEnabled) {
                                        const sp = DesktopLayout.snapPoint(gx, gy, size.width, size.height, hostW, hostH, topInset, WidgetStore.s(Catalog.cardGridStep));
                                        gx = sp.x;
                                        gy = sp.y;
                                    }
                                    const norm = State.normalizedPosition(gx, gy, hostW, hostH);
                                    const resolvedRects = WidgetDragSession.resolveDesktopDrop(root.screenName, slot.tileId, gx, gy, size.width, size.height);
                                    const positions = [];
                                    if (Array.isArray(resolvedRects)) {
                                        resolvedRects.forEach(r => {
                                            if (!r || !r.id) return;
                                            const p = State.normalizedPosition(r.x, r.y, hostW, hostH);
                                            positions.push({ id: String(r.id), xNorm: p.xNorm, yNorm: p.yNorm });
                                        });
                                    }
                                    WidgetDragSession.commitDrop(gx, gy);
                                    WidgetStore.setContainer(slot.tileId, "desktop", root.screenName, norm.xNorm, norm.yNorm);
                                    if (positions.length > 0) {
                                        WidgetStore.setDesktopPositions(positions);
                                    }
                                    WidgetDragSession.requestHandoffCheck(slot.tileId);
                                } else {
                                    WidgetDragSession.cancel();
                                }
                                root.draggingTileId = "";
                                hopAnim.restart();
                            }
                        }

                        onCanceled: {
                            if (slot.isDragged) {
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
                                const wp = slot.mapToItem(null, mouse.x, mouse.y);
                                root.openContextMenu(slot.tileId, wp.x, wp.y);
                                return;
                            }
                            const wasPinned = slot.placed;
                            hopAnim.restart();
                            if (!wasPinned) pinBurst.fire();
                            WidgetStore.togglePin(slot.tileId, root.screenName);
                        }
                    }
                }
            }
        }
    }

    // Horizontal slim scrollbar under shelf
    Rectangle {
        visible: scrollView.contentWidth > scrollView.width + 4
        anchors { bottom: parent.bottom; bottomMargin: WidgetStore.s(1) }
        x: (scrollView.contentX / Math.max(1, scrollView.contentWidth)) * parent.width
        width: Math.max(WidgetStore.s(36), (scrollView.width / Math.max(1, scrollView.contentWidth)) * parent.width)
        height: WidgetStore.s(3)
        radius: WidgetStore.s(2)
        color: Qt.alpha(Theme.m3.primary ?? "#67e8f9", 0.55)
    }

    // Dismiss context menu when clicking outside
    MouseArea {
        visible: root.menuTileId !== ""
        anchors.fill: parent
        z: 190
        onClicked: root.menuTileId = ""
    }

    // Sekai Pop inline right-click context menu
    SekaiPill {
        id: contextMenu
        visible: root.menuTileId !== ""
        x: root.menuX
        y: root.menuY
        width: WidgetStore.s(198)
        height: menuCol.implicitHeight + WidgetStore.s(18)
        z: 200
        cornerRadius: WidgetStore.s(14)
        borderWidth: WidgetStore.s(2)
        ringWidth: WidgetStore.s(2.5)
        shadowDx: WidgetStore.s(2)
        shadowDy: WidgetStore.s(3)
        fillColor: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: WidgetStore.s(6) }
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
        radius: WidgetStore.s(8)
        color: rowMouse.containsMouse
            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.18)
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
                font.family: "Noto Sans"
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
