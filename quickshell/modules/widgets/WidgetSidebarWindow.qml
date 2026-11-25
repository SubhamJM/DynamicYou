import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../"
import "../"

PanelWindow {
    id: root

    property var notchRoot: null
    readonly property bool requestedOpen: WidgetStore.sidebarOpen
    readonly property bool onLeft: WidgetStore.sidebarSide === "left"
    readonly property real edgeGap: 14
    readonly property real topGap: 14
    readonly property real bottomGap: 14
    readonly property real sidebarWidth: Math.min(508, Math.max(360, width * 0.44))

    property bool panelPresented: false
    property bool presentationOpen: false
    property real revealProgress: 0
    property string retainedScreenName: ""

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
        revealAnim.duration = Math.round((presentationOpen ? 300 : 250) * Math.abs(target - revealProgress));
        // Smooth deceleration in both directions so close glides calmly instead of snapping abruptly
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
        drawerView.scrollToFraction(fraction);
        return "OK";
    }

    onRequestedOpenChanged: {
        if (requestedOpen) openPresentation();
        else beginClosing();
    }

    Component.onCompleted: {
        if (requestedOpen) openPresentation();
    }

    // Keep the LayerShell surface mapped with an empty input mask when closed so Hyprland's
    // layersIn/layersOut popin compositor animation never fights the QML slide motion.
    visible: true
    screen: targetScreen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-widget-sidebar"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: requestedOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        id: emptyMask
        width: 0
        height: 0
    }

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
            if (WidgetDragSession.active) WidgetDragSession.cancel();
            else WidgetStore.closeSidebar();
        }
        Keys.onUpPressed: drawerView.scrollBy(-84)
        Keys.onDownPressed: drawerView.scrollBy(84)
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_PageDown) {
                drawerView.scrollBy(drawerView.height * 0.75);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageUp) {
                drawerView.scrollBy(-drawerView.height * 0.75);
                event.accepted = true;
            }
        }

        // Transparent click-away region (zero darkening/shadow over the rest of the desktop)
        MouseArea {
            anchors.fill: parent
            enabled: root.requestedOpen && !WidgetDragSession.active
            onClicked: WidgetStore.closeSidebar()
        }

        // Pure horizontal GPU Translate + smooth opacity fade (zero scale wobble, 144Hz steady)
        Item {
            id: sheetFrame
            x: root.onLeft ? root.edgeGap : Math.max(root.edgeGap, root.width - width - root.edgeGap)
            y: root.topGap
            width: root.sidebarWidth
            height: Math.max(300, root.height - root.topGap - root.bottomGap)
            opacity: Math.max(0, Math.min(1, root.revealProgress * 1.6))

            transform: Translate {
                id: sheetTranslate
                x: (root.sidebarWidth + root.edgeGap + 24) * (root.onLeft ? -1 : 1) * (1.0 - root.revealProgress)
            }

            // Main clean borderless rounded floating container
            Rectangle {
                id: sheetSurface
                anchors.fill: parent
                radius: 24
                color: Theme.m3.surface_container_low ?? Theme.colors.bg
                clip: true

                // Subtle top accent tint matching exact rounded corners (never bleeds square bounding edges)
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 140
                    topLeftRadius: 24
                    topRightRadius: 24
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.10) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Consume background clicks inside sheet so they don't dismiss
                MouseArea {
                    anchors.fill: parent
                    z: 0
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        leftMargin: 18
                        rightMargin: 18
                        topMargin: 16
                        bottomMargin: 16
                    }
                    spacing: 14
                    z: 2

                    // Distinct Dynamic You Widget Deck Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        spacing: 8

                        // Expressive title badge + live status line (never overlaps right controls)
                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            clip: true

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 11
                                color: Theme.m3.primary_container ?? Theme.colors.card_bg

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "widgets"
                                    iconSize: 18
                                    fill: 1
                                    color: Theme.m3.primary ?? Theme.accent
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 0
                                Text {
                                    width: parent.width
                                    text: "Widget Deck"
                                    color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    width: parent.width
                                    text: WidgetStore.desktopCardIds.length > 0
                                        ? (WidgetStore.sidebarCardIds.length + " in deck · " + WidgetStore.desktopCardIds.length + " pinned")
                                        : (WidgetStore.sidebarCardIds.length + " widgets ready · Drag to pin")
                                    color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                    opacity: 0.78
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // Segmented control capsule (explicit Layout sizing so icons never overflow capsule)
                        Rectangle {
                            Layout.preferredWidth: pillControls.implicitWidth + 10
                            Layout.minimumWidth: pillControls.implicitWidth + 10
                            Layout.preferredHeight: 34
                            radius: 11
                            color: Theme.m3.surface_container ?? Theme.colors.card_bg

                            Row {
                                id: pillControls
                                anchors.centerIn: parent
                                spacing: 3

                                HeaderIconButton {
                                    iconName: "swap_horiz"
                                    active: !root.onLeft
                                    onClicked: WidgetStore.toggleSidebarSide()
                                }

                                HeaderIconButton {
                                    iconName: "grid_on"
                                    active: WidgetStore.gridSnapEnabled
                                    onClicked: WidgetStore.toggleGridSnap()
                                }

                                HeaderIconButton {
                                    visible: WidgetStore.desktopCardIds.length > 0
                                    iconName: "dock_to_left"
                                    onClicked: WidgetStore.returnAllToSidebar()
                                }

                                HeaderIconButton {
                                    iconName: "restart_alt"
                                    onClicked: WidgetStore.resetSidebarLayout()
                                }
                            }
                        }

                        // Separate close button
                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 11
                            color: closeMouse.pressed
                                ? (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)
                                : (closeMouse.containsMouse
                                    ? Qt.alpha(Theme.m3.error ?? "#ffb4ab", 0.16)
                                    : (Theme.m3.surface_container ?? Theme.colors.card_bg))

                            Behavior on color { ColorAnimation { duration: 120 } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 17
                                color: closeMouse.containsMouse
                                    ? (Theme.m3.error ?? "#ffb4ab")
                                    : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WidgetStore.closeSidebar()
                            }
                        }
                    }

                    // Hairline divider separating deck controls from scrollable grid
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.45)
                    }

                    // Scrollable draggable widget drawer
                    WidgetDrawerView {
                        id: drawerView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        screenName: root.screen ? String(root.screen.name) : root.retainedScreenName
                        active: root.panelPresented
                        notchRoot: root.notchRoot
                        sidebarContainsFn: function(wx, wy) { return root.containsWindowPoint(wx, wy); }
                    }
                }

                // Tactile accent edge grip bar
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.onLeft ? (parent.width - width - 4) : 4
                    width: 3
                    height: 44
                    radius: 2
                    color: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.36)
                }
            }
        }
    }

    component HeaderIconButton: Rectangle {
        property string iconName: ""
        property bool active: false
        signal clicked()

        width: 28
        height: 28
        radius: 8
        color: active
            ? (Theme.m3.primary_container ?? Theme.colors.hover_bg)
            : (btnMouse.pressed
                ? (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)
                : (btnMouse.containsMouse
                    ? Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.08)
                    : "transparent"))

        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: parent.iconName
            iconSize: 16
            fill: parent.active ? 1 : 0
            color: parent.active || btnMouse.containsMouse
                ? (Theme.m3.primary ?? Theme.accent)
                : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
