import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../"
import "../"
import "WidgetCatalog.js" as Catalog

PanelWindow {
    id: root

    property var notchRoot: null
    readonly property bool requestedOpen: WidgetStore.sidebarOpen
    readonly property bool onLeft: WidgetStore.sidebarSide === "left"
    readonly property real edgeGap: WidgetStore.s(14)
    readonly property real topGap: WidgetStore.s(54)
    readonly property real bottomGap: WidgetStore.s(14)
    readonly property real px1: WidgetStore.uiScale
    readonly property real sidebarWidth: snapPx(Math.min(WidgetStore.s(548), Math.max(WidgetStore.s(420), width * 0.40)))

    function snapPx(v) {
        return Math.round(Number(v) * WidgetStore.qtScale) * WidgetStore.uiScale;
    }

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
        revealAnim.duration = Math.round((presentationOpen ? 290 : 220) * Math.abs(target - revealProgress));
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
        const leftEdge = sheetFrame.x + sheetTranslate.x;
        const topEdge = sheetFrame.y;
        return winX >= leftEdge
            && winX <= leftEdge + sheetFrame.width
            && winY >= topEdge
            && winY <= topEdge + sheetFrame.height;
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
            if (root.searchQuery !== "") {
                root.searchQuery = "";
                searchBox.text = "";
            } else if (WidgetDragSession.active) {
                WidgetDragSession.cancel();
            } else {
                WidgetStore.closeSidebar();
            }
        }
        Keys.onUpPressed: { if (drawerLoader.item) drawerLoader.item.scrollBy(-WidgetStore.s(180)); }
        Keys.onDownPressed: { if (drawerLoader.item) drawerLoader.item.scrollBy(WidgetStore.s(180)); }

        MouseArea {
            anchors.fill: parent
            enabled: root.requestedOpen && !WidgetDragSession.active
            onClicked: WidgetStore.closeSidebar()
        }

        // Crisp Material 3 Floating Widget Gallery Drawer
        Item {
            id: sheetFrame
            x: root.snapPx(root.onLeft ? root.edgeGap : Math.max(root.edgeGap, root.width - width - root.edgeGap))
            y: root.snapPx(root.topGap)
            width: root.sidebarWidth
            height: root.snapPx(Math.max(WidgetStore.s(360), root.height - root.topGap - root.bottomGap))
            opacity: Math.max(0, Math.min(1, root.revealProgress * 1.6))

            transform: Translate {
                id: sheetTranslate
                x: (root.sidebarWidth + root.edgeGap + WidgetStore.s(28)) * (root.onLeft ? -1 : 1) * (1.0 - root.revealProgress)
            }

            Rectangle {
                id: sheetSurface
                anchors.fill: parent
                radius: WidgetStore.s(24)
                color: Theme.m3.surface_container_low ?? Theme.colors.bg
                border.width: root.px1
                border.color: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.45)
                clip: true

                MouseArea {
                    anchors.fill: parent
                    z: 0
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        leftMargin: WidgetStore.s(16)
                        rightMargin: WidgetStore.s(16)
                        topMargin: WidgetStore.s(16)
                        bottomMargin: WidgetStore.s(14)
                    }
                    spacing: WidgetStore.s(12)
                    z: 2

                    // Top Header Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(10)

                        Rectangle {
                            Layout.preferredWidth: WidgetStore.s(36)
                            Layout.preferredHeight: WidgetStore.s(36)
                            radius: WidgetStore.s(11)
                            color: Theme.m3.primary_container ?? Theme.colors.card_bg
                            border.width: root.px1
                            border.color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.28)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "widgets"
                                iconSize: WidgetStore.si(18)
                                fill: 1
                                color: Theme.m3.on_primary_container ?? (Theme.m3.primary ?? Theme.accent)
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: WidgetStore.s(2)

                            Text {
                                width: parent.width
                                text: "Widget Gallery"
                                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(16)
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Row {
                                spacing: WidgetStore.s(6)

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: WidgetStore.s(6)
                                    height: WidgetStore.s(6)
                                    radius: width / 2
                                    color: WidgetStore.desktopCardIds.length > 0
                                        ? (Theme.m3.primary ?? Theme.accent)
                                        : Qt.alpha(Theme.m3.on_surface_variant ?? "#9999aa", 0.5)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: WidgetStore.desktopCardIds.length + " pinned · " + WidgetStore.cardIds.length + " widgets"
                                    color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(11)
                                    font.weight: Font.Medium
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        DeckHeaderButton {
                            icon: root.onLeft ? "dock_to_left" : "dock_to_right"
                            activeState: false
                            onTriggered: WidgetStore.toggleSidebarSide()
                        }

                        DeckHeaderButton {
                            icon: "grid_on"
                            activeState: WidgetStore.gridSnapEnabled
                            onTriggered: WidgetStore.toggleGridSnap()
                        }

                        DeckHeaderButton {
                            visible: WidgetStore.desktopCardIds.length > 0
                            icon: "layers_clear"
                            danger: true
                            onTriggered: WidgetStore.returnAllToSidebar()
                        }

                        DeckHeaderButton {
                            icon: "close"
                            onTriggered: WidgetStore.closeSidebar()
                        }
                    }

                    // Crisp Search Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(36)
                        radius: height / 2
                        color: Theme.m3.surface_container ?? Theme.colors.card_bg
                        border.width: root.px1
                        border.color: searchBox.activeFocus
                            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.72)
                            : Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.32)

                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: searchBox.forceActiveFocus()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: WidgetStore.s(12)
                                rightMargin: WidgetStore.s(10)
                            }
                            spacing: WidgetStore.s(8)

                            MaterialSymbol {
                                text: "search"
                                iconSize: WidgetStore.si(16)
                                color: searchBox.activeFocus
                                    ? (Theme.m3.primary ?? Theme.accent)
                                    : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
                            }

                            TextInput {
                                id: searchBox
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(12)
                                font.weight: Font.Medium
                                renderType: TextInput.NativeRendering
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: root.searchQuery = text.trim()

                                Text {
                                    visible: parent.text === ""
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search widgets…"
                                    color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                    opacity: 0.72
                                    font: parent.font
                                    renderType: Text.NativeRendering
                                }
                            }

                            Rectangle {
                                visible: searchBox.text !== ""
                                Layout.preferredWidth: WidgetStore.s(20)
                                Layout.preferredHeight: WidgetStore.s(20)
                                radius: width / 2
                                color: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: WidgetStore.si(12)
                                    color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchBox.text = "";
                                        root.searchQuery = "";
                                    }
                                }
                            }
                        }
                    }

                    // Category Filter Pills
                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(30)
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        contentWidth: filterRow.implicitWidth
                        contentHeight: height
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: filterRow
                            height: parent.height
                            spacing: WidgetStore.s(6)

                            Repeater {
                                model: Catalog.sources()

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: root.activeSource === modelData.id

                                    anchors.verticalCenter: parent.verticalCenter
                                    height: WidgetStore.s(28)
                                    width: root.snapPx(pillRow.implicitWidth + WidgetStore.s(18))
                                    radius: height / 2
                                    color: sel
                                        ? (Theme.m3.primary ?? Theme.accent)
                                        : (pillMouse.containsMouse
                                            ? (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)
                                            : (Theme.m3.surface_container ?? Theme.colors.card_bg))
                                    border.width: root.px1
                                    border.color: sel
                                        ? (Theme.m3.primary ?? Theme.accent)
                                        : Qt.alpha(Theme.m3.outline_variant ?? "#49454f", pillMouse.containsMouse ? 0.55 : 0.28)

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Row {
                                        id: pillRow
                                        anchors.centerIn: parent
                                        spacing: WidgetStore.s(5)

                                        MaterialSymbol {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.icon
                                            iconSize: WidgetStore.si(13)
                                            fill: sel ? 1 : 0
                                            color: sel
                                                ? (Theme.m3.on_primary ?? "#101014")
                                                : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            color: sel
                                                ? (Theme.m3.on_primary ?? "#101014")
                                                : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                                            font.family: "Google Sans Flex"
                                            font.pixelSize: WidgetStore.si(11)
                                            font.weight: sel ? Font.Bold : Font.Medium
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    MouseArea {
                                        id: pillMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeSource = modelData.id;
                                            if (drawerLoader.item) drawerLoader.item.scrollToFraction(0);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hairline divider separating chrome from gallery
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.px1
                        color: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.26)
                    }

                    // Lazy Categorized Vertical Widget Gallery (unmounted cleanly when drawer closes)
                    Loader {
                        id: drawerLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.panelPresented || WidgetDragSession.presentationActive
                        asynchronous: false
                        sourceComponent: WidgetDrawerView {
                            screenName: root.screen ? String(root.screen.name) : root.retainedScreenName
                            active: root.panelPresented
                            sourceFilter: root.activeSource
                            searchQuery: root.searchQuery
                            notchRoot: root.notchRoot
                            sidebarContainsFn: function(wx, wy) { return root.containsWindowPoint(wx, wy); }
                        }
                    }
                }
            }
        }
    }

    component DeckHeaderButton: Rectangle {
        property string icon: ""
        property bool activeState: false
        property bool danger: false
        signal triggered()

        Layout.preferredWidth: WidgetStore.s(32)
        Layout.preferredHeight: WidgetStore.s(32)
        radius: width / 2
        color: danger
            ? Qt.alpha(Theme.m3.error_container ?? "#7f1d1d", hbMouse.containsMouse ? 0.85 : 0.55)
            : (activeState
                ? (Theme.m3.primary_container ?? Theme.accent)
                : (hbMouse.containsMouse
                    ? (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)
                    : (Theme.m3.surface_container ?? Theme.colors.card_bg)))
        border.width: root.px1
        border.color: danger
            ? Qt.alpha(Theme.m3.error ?? "#ffb4ab", 0.35)
            : (activeState
                ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.45)
                : Qt.alpha(Theme.m3.outline_variant ?? "#49454f", hbMouse.containsMouse ? 0.50 : 0.28))

        Behavior on color { ColorAnimation { duration: 120 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: icon
            iconSize: WidgetStore.si(16)
            fill: activeState ? 1 : 0
            color: danger
                ? (Theme.m3.on_error_container ?? "#ffdada")
                : (activeState
                    ? (Theme.m3.on_primary_container ?? (Theme.m3.primary ?? Theme.accent))
                    : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary))
        }

        MouseArea {
            id: hbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: triggered()
        }
    }
}
