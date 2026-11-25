import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../"
import "../"
import "./cards"

PanelWindow {
    id: root

    property var notchRoot: null
    readonly property bool requestedOpen: WidgetStore.sidebarOpen
    readonly property real edgeGap: WidgetStore.s(22)
    readonly property real bottomGap: WidgetStore.s(14)
    readonly property real trayHeight: WidgetStore.s(204)

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
        const leftEdge = sheetFrame.x;
        const topEdge = sheetFrame.y + sheetTranslate.y;
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

    // Mapped with empty input mask when closed so Hyprland layer animations never fight the QML slide motion.
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
        Keys.onLeftPressed: drawerView.scrollBy(-WidgetStore.s(180))
        Keys.onRightPressed: drawerView.scrollBy(WidgetStore.s(180))
        Keys.onUpPressed: drawerView.scrollBy(-WidgetStore.s(180))
        Keys.onDownPressed: drawerView.scrollBy(WidgetStore.s(180))
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_PageDown) {
                drawerView.scrollBy(drawerView.width * 0.65);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageUp) {
                drawerView.scrollBy(-drawerView.width * 0.65);
                event.accepted = true;
            }
        }

        // Transparent click-away region above/around the bottom shelf
        MouseArea {
            anchors.fill: parent
            enabled: root.requestedOpen && !WidgetDragSession.active
            onClicked: WidgetStore.closeSidebar()
        }

        // Bottom-docked Sekai Pop Widget Picker shelf
        Item {
            id: sheetFrame
            x: root.edgeGap
            y: root.height - root.bottomGap - height
            width: Math.max(WidgetStore.s(640), root.width - root.edgeGap * 2)
            height: root.trayHeight
            opacity: Math.max(0, Math.min(1, root.revealProgress * 1.6))

            transform: Translate {
                id: sheetTranslate
                y: (root.trayHeight + root.bottomGap + WidgetStore.s(36)) * (1.0 - root.revealProgress)
            }

            SekaiPill {
                id: sheetSurface
                anchors.fill: parent
                cornerRadius: WidgetStore.s(22)
                borderWidth: WidgetStore.s(2.5)
                ringWidth: WidgetStore.s(3.5)
                shadowDx: WidgetStore.s(3)
                shadowDy: WidgetStore.s(5)
                fillColor: Theme.m3.surface_container ?? Theme.colors.bg
                ringColor: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.24)
                outlineColor: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.35)
                shadowColor: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.65)

                // Consume clicks inside shelf body so backdrop doesn't close it
                MouseArea {
                    anchors.fill: parent
                    z: 0
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: WidgetStore.s(16)
                        rightMargin: WidgetStore.s(16)
                        topMargin: WidgetStore.s(12)
                        bottomMargin: WidgetStore.s(12)
                    }
                    spacing: WidgetStore.s(14)
                    z: 2

                    // LEFT: Sekai Pop title header + Keycap hints
                    Column {
                        Layout.preferredWidth: WidgetStore.s(202)
                        Layout.alignment: Qt.AlignVCenter
                        spacing: WidgetStore.s(6)

                        Item {
                            width: parent.width
                            height: WidgetStore.s(40)

                            SekaiDiamond {
                                id: headDiamond
                                x: WidgetStore.s(3)
                                y: WidgetStore.s(4)
                                size: WidgetStore.s(14)
                                lit: true
                                litColor: Theme.m3.primary ?? Theme.accent
                            }

                            Text {
                                anchors.left: headDiamond.right
                                anchors.leftMargin: WidgetStore.s(10)
                                anchors.verticalCenter: headDiamond.verticalCenter
                                text: "WIDGET PICKER"
                                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(15)
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.6
                                font.hintingPreference: Font.PreferVerticalHinting
                                renderType: Text.NativeRendering
                            }

                            Text {
                                x: 0
                                y: WidgetStore.s(24)
                                width: parent.width
                                elide: Text.ElideRight
                                text: WidgetStore.desktopCardIds.length > 0
                                    ? (WidgetStore.desktopCardIds.length + " pinned · " + WidgetStore.cardIds.length + " widgets")
                                    : (WidgetStore.cardIds.length + " ready · Pick & place")
                                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                font.family: "Noto Sans"
                                font.pixelSize: WidgetStore.si(11)
                                font.weight: Font.DemiBold
                                font.hintingPreference: Font.PreferVerticalHinting
                                renderType: Text.NativeRendering
                            }
                        }

                        HintRow { keyText: "L"; label: "Click: pin / unpin" }
                        HintRow { keyText: "R"; label: "Right click: options" }
                        HintRow { keyIcon: "open_with"; label: "Drag up: place on screen" }
                    }

                    // Left crisp divider
                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(2)
                        Layout.preferredHeight: WidgetStore.s(132)
                        Layout.alignment: Qt.AlignVCenter
                        radius: WidgetStore.s(1)
                        color: Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.55)
                    }

                    // CENTER: Horizontally scrollable Sekai Pop widget miniature shelf
                    WidgetDrawerView {
                        id: drawerView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        screenName: root.screen ? String(root.screen.name) : root.retainedScreenName
                        active: root.panelPresented
                        notchRoot: root.notchRoot
                        sidebarContainsFn: function(wx, wy) { return root.containsWindowPoint(wx, wy); }
                    }

                    // Right crisp divider
                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(2)
                        Layout.preferredHeight: WidgetStore.s(132)
                        Layout.alignment: Qt.AlignVCenter
                        radius: WidgetStore.s(1)
                        color: Qt.alpha(Theme.m3.outline_variant ?? "#163a70", 0.55)
                    }

                    // RIGHT: Sekai Pop action keys (Grid Snap + Clear + Done)
                    Column {
                        Layout.preferredWidth: WidgetStore.s(154)
                        Layout.alignment: Qt.AlignVCenter
                        spacing: WidgetStore.s(8)

                        RowLayout {
                            width: parent.width
                            height: WidgetStore.s(50)
                            spacing: WidgetStore.s(8)

                            // Grid Snap toggle key
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                SekaiPill {
                                    anchors.fill: parent
                                    cornerRadius: WidgetStore.s(13)
                                    borderWidth: WidgetStore.s(2)
                                    ringWidth: WidgetStore.s(2.5)
                                    shadowDy: WidgetStore.s(3)
                                    pressed: snapMouse.pressed
                                    fillColor: WidgetStore.gridSnapEnabled
                                        ? (Theme.m3.primary_container ?? Theme.colors.hover_bg)
                                        : (snapMouse.containsMouse
                                            ? (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)
                                            : (Theme.m3.surface_container_high ?? Theme.colors.card_bg))

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        MaterialSymbol {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "grid_on"
                                            iconSize: WidgetStore.si(17)
                                            fill: WidgetStore.gridSnapEnabled ? 1 : 0
                                            color: WidgetStore.gridSnapEnabled
                                                ? (Theme.m3.primary ?? Theme.accent)
                                                : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "SNAP"
                                            color: WidgetStore.gridSnapEnabled
                                                ? (Theme.m3.on_primary_container ?? Theme.colors.text_primary)
                                                : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                                            font.family: "Google Sans Flex"
                                            font.pixelSize: WidgetStore.si(10)
                                            font.weight: Font.ExtraBold
                                            font.letterSpacing: 0.6
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }

                                MouseArea {
                                    id: snapMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: WidgetStore.toggleGridSnap()
                                }
                            }

                            // Return All / Unpin All key
                            Item {
                                id: clearBtn
                                Layout.preferredWidth: WidgetStore.s(66)
                                Layout.fillHeight: true
                                readonly property bool hasPinned: WidgetStore.desktopCardIds.length > 0
                                opacity: hasPinned ? 1.0 : 0.45

                                SekaiPill {
                                    anchors.fill: parent
                                    cornerRadius: WidgetStore.s(13)
                                    borderWidth: WidgetStore.s(2)
                                    ringWidth: WidgetStore.s(2.5)
                                    shadowDy: WidgetStore.s(3)
                                    pressed: clearMouse.pressed && clearBtn.hasPinned
                                    fillColor: (clearMouse.containsMouse && clearBtn.hasPinned)
                                        ? Qt.alpha(Theme.m3.error ?? "#ffb4ab", 0.22)
                                        : (Theme.m3.surface_container_high ?? Theme.colors.card_bg)

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        MaterialSymbol {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "layers_clear"
                                            iconSize: WidgetStore.si(17)
                                            color: (clearMouse.containsMouse && clearBtn.hasPinned)
                                                ? (Theme.m3.error ?? "#ffb4ab")
                                                : (Theme.m3.on_surface_variant ?? Theme.colors.text_secondary)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "CLEAR"
                                            color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                            font.family: "Google Sans Flex"
                                            font.pixelSize: WidgetStore.si(10)
                                            font.weight: Font.ExtraBold
                                            font.letterSpacing: 0.6
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }

                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: clearBtn.hasPinned
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: WidgetStore.returnAllToSidebar()
                                }
                            }
                        }

                        // Primary DONE key
                        Item {
                            width: parent.width
                            height: WidgetStore.s(54)

                            Gradient {
                                id: doneGrad
                                GradientStop { position: 0.0; color: Theme.m3.primary ?? Theme.accent }
                                GradientStop { position: 1.0; color: Theme.m3.secondary ?? Theme.accent }
                            }

                            SekaiPill {
                                anchors.fill: parent
                                cornerRadius: WidgetStore.s(15)
                                borderWidth: WidgetStore.s(2.5)
                                ringWidth: WidgetStore.s(3)
                                shadowDy: WidgetStore.s(4)
                                pressed: doneMouse.pressed
                                fillGradient: doneGrad

                                Row {
                                    anchors.centerIn: parent
                                    spacing: WidgetStore.s(6)

                                    MaterialSymbol {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "check"
                                        iconSize: WidgetStore.si(20)
                                        fill: 1
                                        color: Theme.m3.on_primary ?? "#101014"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "DONE"
                                        color: Theme.m3.on_primary ?? "#101014"
                                        font.family: "Google Sans Flex"
                                        font.pixelSize: WidgetStore.si(16)
                                        font.weight: Font.ExtraBold
                                        font.letterSpacing: 0.9
                                        font.hintingPreference: Font.PreferVerticalHinting
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }

                            MouseArea {
                                id: doneMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WidgetStore.closeSidebar()
                            }
                        }
                    }
                }
            }
        }
    }

    component HintRow: Item {
        id: hr
        property string keyText: ""
        property string keyIcon: ""
        property string label: ""

        width: parent.width
        height: WidgetStore.s(24)

        SekaiPill {
            width: WidgetStore.s(30)
            height: WidgetStore.s(24)
            cornerRadius: WidgetStore.s(7)
            borderWidth: WidgetStore.s(1.5)
            ringWidth: WidgetStore.s(2)
            shadowDy: WidgetStore.s(2)
            fillColor: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg

            Text {
                anchors.centerIn: parent
                visible: hr.keyIcon === ""
                text: hr.keyText
                color: Theme.m3.primary ?? Theme.accent
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(10)
                font.weight: Font.ExtraBold
                renderType: Text.NativeRendering
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: hr.keyIcon !== ""
                text: hr.keyIcon
                iconSize: WidgetStore.si(12)
                color: Theme.m3.primary ?? Theme.accent
            }
        }

        Text {
            x: WidgetStore.s(38)
            width: parent.width - x
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: hr.label
            color: Theme.m3.on_surface ?? Theme.colors.text_primary
            font.family: "Noto Sans"
            font.pixelSize: WidgetStore.si(11)
            font.weight: Font.DemiBold
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }
    }
}
