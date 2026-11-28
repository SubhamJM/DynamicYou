import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../"
import "../"
import "WidgetCatalog.js" as Catalog

// Calm, architectural iNiR-inspired Floating Horizontal Bottom Widget Shelf
PanelWindow {
    id: root

    property var notchRoot: null
    readonly property bool requestedOpen: WidgetStore.sidebarOpen

    // iNiR architectural design tokens mapped directly from Theme.m3
    readonly property color colLayer1: Theme.m3.surface_container_low ?? "#15151a"
    readonly property color colLayer2: Theme.m3.surface_container ?? "#1c1c22"
    readonly property color colLayer3: Theme.m3.surface_container_high ?? "#26262e"
    readonly property color colLayerHover: Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.08)
    readonly property color colBorder: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.72)
    readonly property color colBorderSubtle: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.38)
    readonly property color colBorderFocus: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.75)
    readonly property color colSelection: Qt.alpha(Theme.m3.primary_container ?? Theme.primaryContainer, 0.48)
    readonly property color colText: Theme.m3.on_surface ?? Theme.text
    readonly property color colTextMuted: Qt.alpha(Theme.m3.on_surface_variant ?? Theme.subtext, 0.80)
    readonly property color colPrimary: Theme.m3.primary ?? Theme.accent
    readonly property color colDanger: Theme.m3.error ?? Theme.error
    readonly property color colDangerHover: Qt.alpha(Theme.m3.error_container ?? "#7f1d1d", 0.45)

    readonly property int radLarge: 12
    readonly property int radNormal: 8
    readonly property int radSmall: 6
    readonly property string uiFont: "Noto Sans"

    readonly property real edgeMargin: 16
    readonly property real shelfWidth: Math.round(Math.min(1260, Math.max(680, width - edgeMargin * 2)))
    readonly property real shelfHeight: 274

    property bool panelPresented: false
    property bool presentationOpen: false
    property real revealProgress: 0
    property string retainedScreenName: ""
    property string activeSource: "all"
    property string searchQuery: ""

    readonly property var targetScreen: {
        const focusedName = (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor)
            ? String(Hyprland.focusedMonitor.name || "")
            : "";
        const want = retainedScreenName || focusedName;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (String(Quickshell.screens[i].name) === want) return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function animateReveal() {
        revealAnim.stop();
        const target = presentationOpen ? 1 : 0;
        if (revealProgress === target) {
            if (!presentationOpen) finishClosing();
            return;
        }
        revealAnim.from = revealProgress;
        revealAnim.to = target;
        revealAnim.duration = Math.round((presentationOpen ? 260 : 190) * Math.abs(target - revealProgress));
        revealAnim.easing.bezierCurve = presentationOpen
            ? [0.16, 1.0, 0.3, 1.0, 1, 1]
            : [0.25, 0.85, 0.35, 1.0, 1, 1];
        revealAnim.start();
    }

    function openPresentation() {
        if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor) {
            retainedScreenName = String(Hyprland.focusedMonitor.name || "");
        } else if (Quickshell.screens.length > 0) {
            retainedScreenName = String(Quickshell.screens[0].name || "");
        }
        panelPresented = true;
        presentationOpen = true;
        animateReveal();
    }

    function beginClosing() {
        if (WidgetDragSession.active) WidgetDragSession.cancel();
        if (drawerLoader.item && typeof drawerLoader.item.closeContextMenu === "function") {
            drawerLoader.item.closeContextMenu();
        }
        presentationOpen = false;
        animateReveal();
    }

    function finishClosing() {
        if (requestedOpen) return;
        revealAnim.stop();
        revealProgress = 0;
        panelPresented = false;
    }

    function containsWindowPoint(winX, winY) {
        if (!panelPresented || revealProgress <= 0.02) return false;
        const topEdge = shelfFrame.y + shelfTranslate.y;
        return winX >= shelfFrame.x
            && winX <= shelfFrame.x + shelfFrame.width
            && winY >= topEdge
            && winY <= topEdge + shelfFrame.height;
    }

    function scrollDrawer(fraction) {
        if (drawerLoader.item) drawerLoader.item.scrollToFraction(fraction);
        return "OK";
    }

    onRequestedOpenChanged: {
        if (requestedOpen) openPresentation();
        else beginClosing();
    }

    Connections {
        target: WidgetDragSession
        function onPresentationActiveChanged() {
            if (WidgetDragSession.presentationActive && root.requestedOpen) {
                WidgetStore.closeSidebar();
            }
        }
    }

    Component.onCompleted: {
        if (requestedOpen) openPresentation();
    }

    visible: true
    screen: targetScreen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-widget-sidebar"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: requestedOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item { id: emptyMask; width: 0; height: 0 }

    mask: Region {
        item: root.panelPresented ? interactionItem : emptyMask
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "revealProgress"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (!root.presentationOpen) root.finishClosing();
        }
    }

    Item {
        id: interactionItem
        anchors.fill: parent
        visible: root.panelPresented
        focus: root.requestedOpen

        Keys.onEscapePressed: {
            if (drawerLoader.item && drawerLoader.item.menuTileId !== "") {
                drawerLoader.item.closeContextMenu();
            } else if (root.searchQuery !== "") {
                root.searchQuery = "";
                searchBox.text = "";
            } else if (WidgetDragSession.active) {
                WidgetDragSession.cancel();
            } else {
                WidgetStore.closeSidebar();
            }
        }
        Keys.onLeftPressed: { if (drawerLoader.item) drawerLoader.item.scrollBy(-240); }
        Keys.onRightPressed: { if (drawerLoader.item) drawerLoader.item.scrollBy(240); }

        // Click outside shelf dismisses it (or closes open tile menu first)
        MouseArea {
            anchors.fill: parent
            enabled: root.requestedOpen && !WidgetDragSession.active
            onClicked: {
                if (drawerLoader.item && drawerLoader.item.menuTileId !== "") {
                    drawerLoader.item.closeContextMenu();
                } else {
                    WidgetStore.closeSidebar();
                }
            }
        }

        // Bottom-Centered Floating iNiR Shelf Frame
        Item {
            id: shelfFrame
            x: Math.round((root.width - width) / 2)
            y: Math.round(root.height - height - 16)
            width: root.shelfWidth
            height: root.shelfHeight
            opacity: Math.max(0, Math.min(1, root.revealProgress * 1.6))

            transform: Translate {
                id: shelfTranslate
                y: Math.round((root.shelfHeight + 28) * (1.0 - root.revealProgress))
            }

            Rectangle {
                id: shelfSurface
                anchors.fill: parent
                radius: root.radLarge
                color: root.colLayer1
                border.width: 1
                border.color: root.colBorder

                // Prevent click-through to desktop backdrop
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // --- Top Head Bar: Category Tabs + Search Pill + Grid/Clear/Close ---
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        spacing: 8

                        // Category Filter Tabs
                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            contentWidth: tabsRow.implicitWidth
                            contentHeight: 34
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: tabsRow
                                height: 34
                                spacing: 4

                                Repeater {
                                    model: Catalog.sources()

                                    delegate: Rectangle {
                                        id: tabChip
                                        required property var modelData
                                        readonly property bool selected: root.activeSource === modelData.id

                                        height: 34
                                        width: tabInner.implicitWidth + 20
                                        radius: root.radSmall
                                        color: selected
                                            ? root.colSelection
                                            : (tabMa.containsMouse ? root.colLayerHover : "transparent")
                                        border.width: 1
                                        border.color: selected
                                            ? root.colBorderFocus
                                            : (tabMa.containsMouse ? root.colBorderSubtle : "transparent")

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            id: tabInner
                                            anchors.centerIn: parent
                                            spacing: 6

                                            MaterialSymbol {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: tabChip.modelData.icon
                                                iconSize: 16
                                                fill: tabChip.selected ? 1 : 0
                                                color: tabChip.selected ? root.colPrimary : root.colTextMuted
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: tabChip.modelData.label
                                                color: tabChip.selected ? root.colText : root.colTextMuted
                                                font.family: root.uiFont
                                                font.pixelSize: 13
                                                font.weight: tabChip.selected ? Font.DemiBold : Font.Medium
                                                renderType: Text.QtRendering
                                            }
                                        }

                                        MouseArea {
                                            id: tabMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeSource = tabChip.modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        // Search Pill
                        Rectangle {
                            Layout.preferredWidth: 215
                            Layout.preferredHeight: 34
                            radius: root.radSmall
                            color: root.colLayer2
                            border.width: 1
                            border.color: searchBox.activeFocus ? root.colBorderFocus : root.colBorderSubtle

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                                spacing: 7

                                MaterialSymbol {
                                    text: "search"
                                    iconSize: 16
                                    color: searchBox.activeFocus ? root.colPrimary : root.colTextMuted
                                }

                                TextInput {
                                    id: searchBox
                                    Layout.fillWidth: true
                                    color: root.colText
                                    selectionColor: root.colSelection
                                    font.family: root.uiFont
                                    font.pixelSize: 13
                                    font.weight: Font.Normal
                                    clip: true
                                    renderType: Text.QtRendering
                                    onTextChanged: root.searchQuery = text

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchBox.text === ""
                                        text: "Search widgets…"
                                        color: root.colTextMuted
                                        font.family: root.uiFont
                                        font.pixelSize: 13
                                        renderType: Text.QtRendering
                                    }
                                }

                                Rectangle {
                                    visible: searchBox.text !== ""
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 4
                                    color: clrMa.containsMouse ? root.colLayerHover : "transparent"

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: 14
                                        color: root.colTextMuted
                                    }

                                    MouseArea {
                                        id: clrMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchBox.text = "";
                                            searchBox.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }

                        // Pinned Counter Pill
                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: countTxt.implicitWidth + 18
                            radius: root.radSmall
                            color: root.colLayer2
                            border.width: 1
                            border.color: root.colBorderSubtle

                            Text {
                                id: countTxt
                                anchors.centerIn: parent
                                text: WidgetStore.desktopCardIds.length + " pinned"
                                color: WidgetStore.desktopCardIds.length > 0 ? root.colPrimary : root.colTextMuted
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                renderType: Text.QtRendering
                            }
                        }

                        // Grid Snap Toggle Button
                        InirIconButton {
                            icon: "grid_4x4"
                            active: WidgetStore.gridSnapEnabled
                            tooltipText: "Snap to grid"
                            onClicked: WidgetStore.toggleGridSnap()
                        }

                        // Return All Widgets Button
                        InirIconButton {
                            visible: WidgetStore.desktopCardIds.length > 0
                            icon: "layers_clear"
                            danger: true
                            tooltipText: "Return all"
                            onClicked: WidgetStore.returnAllToSidebar()
                        }

                        // Close Button
                        InirIconButton {
                            icon: "close"
                            tooltipText: "Close"
                            onClicked: WidgetStore.closeSidebar()
                        }
                    }

                    // Hairline Divider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.colBorderSubtle
                    }

                    // Horizontal Showcase Strip
                    Loader {
                        id: drawerLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.panelPresented
                        source: "WidgetDrawerView.qml"
                        onLoaded: {
                            item.screenName = Qt.binding(() => root.screen ? String(root.screen.name) : "");
                            item.active = Qt.binding(() => root.panelPresented);
                            item.sourceFilter = Qt.binding(() => root.activeSource);
                            item.searchQuery = Qt.binding(() => root.searchQuery);
                            item.notchRoot = Qt.binding(() => root.notchRoot);
                            item.sidebarContainsFn = (wx, wy) => root.containsWindowPoint(wx, wy);
                            item.overlayHost = interactionItem;
                        }
                    }
                }
            }
        }
    }

    component InirIconButton: Rectangle {
        id: btn
        property string icon: ""
        property string tooltipText: ""
        property bool active: false
        property bool danger: false
        signal clicked()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: root.radSmall
        color: {
            if (active) return root.colSelection;
            if (btnMa.containsMouse) return danger ? root.colDangerHover : root.colLayerHover;
            return root.colLayer2;
        }
        border.width: 1
        border.color: {
            if (active) return root.colBorderFocus;
            if (btnMa.containsMouse) return danger ? root.colDanger : root.colBorder;
            return root.colBorderSubtle;
        }

        Behavior on color { ColorAnimation { duration: 100 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: btn.icon
            iconSize: 18
            fill: btn.active ? 1 : 0
            color: {
                if (btn.active) return root.colPrimary;
                if (btn.danger && btnMa.containsMouse) return root.colDanger;
                return btnMa.containsMouse ? root.colText : root.colTextMuted;
            }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
