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
    readonly property real sidebarWidth: Math.min(WidgetStore.s(488), Math.max(WidgetStore.s(380), width * 0.36))

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
        revealAnim.duration = Math.round((presentationOpen ? 300 : 230) * Math.abs(target - revealProgress));
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

        // Borderless M3 / Matushell-style Floating Side Drawer
        Item {
            id: sheetFrame
            x: root.onLeft ? root.edgeGap : Math.max(root.edgeGap, root.width - width - root.edgeGap)
            y: root.topGap
            width: root.sidebarWidth
            height: Math.max(WidgetStore.s(360), root.height - root.topGap - root.bottomGap)
            opacity: Math.max(0, Math.min(1, root.revealProgress * 1.6))

            transform: Translate {
                id: sheetTranslate
                x: (root.sidebarWidth + root.edgeGap + WidgetStore.s(28)) * (root.onLeft ? -1 : 1) * (1.0 - root.revealProgress)
            }

            Rectangle {
                id: sheetSurface
                anchors.fill: parent
                radius: WidgetStore.s(26)
                color: Theme.m3.surface_container_low ?? Theme.colors.bg
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
                            radius: WidgetStore.s(12)
                            color: Theme.m3.primary_container ?? Theme.colors.card_bg

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "widgets"
                                iconSize: WidgetStore.si(18)
                                fill: 1
                                color: Theme.m3.primary ?? Theme.accent
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: WidgetStore.s(1)

                            Text {
                                width: parent.width
                                text: "Widgets"
                                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(16)
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                width: parent.width
                                text: WidgetStore.desktopCardIds.length + " on desktop · " + WidgetStore.cardIds.length + " available"
                                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(10.5)
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
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

                    // Search Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(36)
                        radius: height / 2
                        color: Theme.m3.surface_container ?? Theme.colors.card_bg

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
                            spacing: WidgetStore.s(5)

                            Repeater {
                                model: Catalog.sources()

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: root.activeSource === modelData.id

                                    height: WidgetStore.s(26)
                                    width: pillRow.implicitWidth + WidgetStore.s(14)
                                    radius: height / 2
                                    color: sel
                                        ? (Theme.m3.primary ?? Theme.accent)
                                        : (pillMouse.containsMouse
                                            ? (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)
                                            : (Theme.m3.surface_container ?? Theme.colors.card_bg))

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Row {
                                        id: pillRow
                                        anchors.centerIn: parent
                                        spacing: WidgetStore.s(4)

                                        MaterialSymbol {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.icon
                                            iconSize: WidgetStore.si(12)
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
                                            font.pixelSize: WidgetStore.si(10)
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

        MaterialSymbol {
            anchors.centerIn: parent
            text: icon
            iconSize: WidgetStore.si(16)
            fill: activeState ? 1 : 0
            color: danger
                ? (Theme.m3.on_error_container ?? "#ffdada")
                : (activeState
                    ? (Theme.m3.primary ?? Theme.accent)
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
