pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "."

// High-performance unified area picker overlay (Caelestia-inspired).
// Automatically snaps to hovered Hyprland windows or switches to freeform drag-select on press.
// Supports Fullscreen mode (dimming removed) with animated M3 mode pill and FAB switcher.
PanelWindow {
    id: root

    // --- Public API ---
    property var host: null
    property bool freezeFrame: false
    property string windowNamespace: "matushell:snip"
    property int activeTool: root.freezeFrame ? 0 : 1
    property int pickerMode: 0 // 0 = Area (Auto Window/Region), 1 = Fullscreen

    // --- Local State ---
    readonly property var monitor: Hyprland.monitorFor(root.screen)
    readonly property string monitorName: root.monitor ? root.monitor.name : ""
    readonly property real monitorScale: root.monitor ? root.monitor.scale : 1

    // Hyprland IPC coordinates live in compositor logical space (ipcMonW x ipcMonH),
    // whereas QML item coordinates may differ when QT_SCALE_FACTOR != 1.0 (e.g. 1.2x).
    readonly property real ipcMonW: (root.monitor && root.monitor.lastIpcObject && root.monitor.lastIpcObject.width > 0)
        ? (root.monitor.lastIpcObject.width / (root.monitorScale || 1))
        : (root.width > 0 ? root.width : 1920)
    readonly property real ipcMonH: (root.monitor && root.monitor.lastIpcObject && root.monitor.lastIpcObject.height > 0)
        ? (root.monitor.lastIpcObject.height / (root.monitorScale || 1))
        : (root.height > 0 ? root.height : 1200)
    readonly property real uiToLogX: root.width > 0 ? (ipcMonW / root.width) : 1.0
    readonly property real uiToLogY: root.height > 0 ? (ipcMonH / root.height) : 1.0
    readonly property real logToUiX: 1.0 / uiToLogX
    readonly property real logToUiY: 1.0 / uiToLogY

    property var clients: []
    property bool onClient: false
    property var activeClient: null
    property real startX: 0
    property real startY: 0

    // Exact mathematical coordinates (consumed by confirm crop, never animated)
    property real targetX: 0
    property real targetY: 0
    property real targetW: 0
    property real targetH: 0

    // Visual animated coordinates (consumed by shader cutout and border)
    property real animX: root.targetX
    property real animY: root.targetY
    property real animW: root.targetW
    property real animH: root.targetH

    // --- Hover & Trailing State for Mode Pill ---
    property int hoveredIndex: -1
    readonly property real hoverTargetIndex: root.hoveredIndex >= 0 ? root.hoveredIndex : root.pickerMode

    property real activeLead: root.pickerMode
    property real activeFollow: root.pickerMode
    property real hoverLead: root.hoverTargetIndex
    property real hoverFollow: root.hoverTargetIndex

    // --- Layout & Geometry ---
    readonly property int tabWidth: Math.round(136 * Theming.paddingMultiplier)
    readonly property int tabHeight: Math.round(38 * Theming.paddingMultiplier)
    readonly property int tabSpacing: Math.round(6 * Theming.spacingMultiplier)
    readonly property int pillPadding: Math.round(5 * Theming.paddingMultiplier)

    // --- Signals ---
    signal confirmed(var screenItem, string monitorName, int cropX, int cropY, int cropWidth, int cropHeight, int globalX, int globalY, var win)
    signal cancelled

    // --- Functions ---
    function pillX(lead, follow) {
        return root.pillPadding + Math.min(lead, follow) * (root.tabWidth + root.tabSpacing)
    }

    function pillWidth(lead, follow) {
        return Math.abs(lead - follow) * (root.tabWidth + root.tabSpacing) + root.tabWidth
    }

    function refreshClients() {
        if (!root.monitor) {
            root.clients = []
            return
        }

        const mon = root.monitor
        const spWs = (mon.lastIpcObject && mon.lastIpcObject.specialWorkspace) ? mon.lastIpcObject.specialWorkspace : null
        const spWsName = (spWs && spWs.name) ? spWs.name : ""
        const activeWsId = (spWsName.length > 0 && spWs.id !== undefined)
            ? spWs.id
            : ((mon.activeWorkspace && mon.activeWorkspace.id !== undefined)
                ? mon.activeWorkspace.id
                : (mon.lastIpcObject && mon.lastIpcObject.activeWorkspace ? mon.lastIpcObject.activeWorkspace.id : -1))
        const activeWsName = spWsName.length > 0
            ? spWsName
            : ((mon.activeWorkspace && mon.activeWorkspace.name) ? mon.activeWorkspace.name : (mon.lastIpcObject && mon.lastIpcObject.activeWorkspace ? mon.lastIpcObject.activeWorkspace.name : ""))

        const mx0 = (mon.lastIpcObject && mon.lastIpcObject.x !== undefined) ? mon.lastIpcObject.x : root.screen.x
        const my0 = (mon.lastIpcObject && mon.lastIpcObject.y !== undefined) ? mon.lastIpcObject.y : root.screen.y

        const toplevels = Hyprland.toplevels
        if (!toplevels) {
            root.clients = []
            return
        }

        const all = (typeof toplevels.values === "function") ? Array.from(toplevels.values()) : (toplevels.values ? Array.from(toplevels.values) : [])
        const list = []
        for (let i = 0; i < all.length; i++) {
            const w = all[i]
            if (!w || !w.lastIpcObject)
                continue
            const ipc = w.lastIpcObject
            if (ipc.mapped === false || ipc.hidden === true)
                continue
            if (!ipc.at || !ipc.size)
                continue
            if (w.monitor && w.monitor.name && mon.name && w.monitor.name !== mon.name)
                continue
            const winWsId = (w.workspace && w.workspace.id !== undefined) ? w.workspace.id : (ipc.workspace && ipc.workspace.id !== undefined ? ipc.workspace.id : -1)
            const winWsName = (w.workspace && w.workspace.name) ? w.workspace.name : (ipc.workspace && ipc.workspace.name ? ipc.workspace.name : "")
            const matchesWs = spWsName.length > 0
                ? (winWsName === spWsName || (activeWsId !== -1 && winWsId === activeWsId))
                : (activeWsId === -1 || winWsId === activeWsId || (activeWsName.length > 0 && winWsName === activeWsName))
            if (!matchesWs && !ipc.pinned)
                continue
            list.push({
                x: (ipc.at[0] - mx0) * root.logToUiX,
                y: (ipc.at[1] - my0) * root.logToUiY,
                w: ipc.size[0] * root.logToUiX,
                h: ipc.size[1] * root.logToUiY,
                floating: ipc.floating ? 1 : 0,
                pinned: ipc.pinned ? 1 : 0,
                fullscreen: ipc.fullscreen || 0,
                focusId: ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 999,
                clientClass: ipc.class || "",
                title: ipc.title || w.title || "",
                at: ipc.at,
                size: ipc.size
            })
        }

        list.sort(function (a, b) {
            if (b.pinned !== a.pinned)
                return b.pinned - a.pinned
            if (b.fullscreen !== a.fullscreen)
                return b.fullscreen - a.fullscreen
            if (b.floating !== a.floating)
                return b.floating - a.floating
            return a.focusId - b.focusId
        })
        root.clients = list
    }

    function setMode(mode) {
        root.pickerMode = mode
        if (root.host) {
            if (mode === 1) {
                root.host.currentMode = 2
            } else if (root.host.currentMode === 2) {
                root.host.currentMode = 0
            }
        }
        if (mode === 1) {
            root.onClient = false
            root.activeClient = null
            root.targetX = 0
            root.targetY = 0
            root.targetW = root.width
            root.targetH = root.height
        } else {
            root.refreshClients()
            root.checkClientRects(inputArea.mouseX, inputArea.mouseY)
        }
    }

    function checkClientRects(x, y) {
        if (root.pickerMode === 1)
            return
        for (let i = 0; i < root.clients.length; i++) {
            const c = root.clients[i]
            if (x >= c.x && y >= c.y && x < c.x + c.w && y < c.y + c.h) {
                root.onClient = true
                root.activeClient = c
                root.targetX = c.x
                root.targetY = c.y
                root.targetW = c.w
                root.targetH = c.h
                return
            }
        }

        // Empty desktop: no window hovered
        root.onClient = false
        root.activeClient = null
        if (!inputArea.pressed) {
            root.targetX = x
            root.targetY = y
            root.targetW = 0
            root.targetH = 0
        }
    }

    // --- Window Settings ---
    visible: root.host !== null && root.host.isOpen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: root.windowNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible && !(root.host !== null && root.host.closing) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: root.host !== null && root.host.closing ? emptyRegion : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onPickerModeChanged: {
        activeLead = root.pickerMode
        activeFollow = root.pickerMode
    }

    onHoverTargetIndexChanged: {
        hoverLead = root.hoverTargetIndex
        hoverFollow = root.hoverTargetIndex
    }

    onWidthChanged: {
        if (root.visible && root.pickerMode === 0) {
            root.refreshClients()
            root.checkClientRects(inputArea.mouseX, inputArea.mouseY)
        }
    }

    onHeightChanged: {
        if (root.visible && root.pickerMode === 0) {
            root.refreshClients()
            root.checkClientRects(inputArea.mouseX, inputArea.mouseY)
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            fadeRoot.forceActiveFocus()
            Hyprland.refreshToplevels()
            const initMode = (root.host && (root.host.currentMode === 2 || root.host.currentMode === 3)) ? 1 : 0
            root.setMode(initMode)
        }
    }

    Connections {
        function onRawEvent(event) {
            if (!root.visible || root.pickerMode !== 0)
                return
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindowv2" || event.name === "fullscreen" || event.name === "activewindowv2" || event.name === "workspace" || event.name === "workspacev2" || event.name === "activespecial" || event.name === "activespecialv2") {
                Hyprland.refreshToplevels()
                root.refreshClients()
            }
        }

        target: Hyprland
    }

    Region {
        id: emptyRegion
    }

    // Dual-speed trailing glides
    Behavior on activeLead {
        NumberAnimation {
            duration: MatusMotion.durationShort2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MatusMotion.curveGlide
        }
    }

    Behavior on activeFollow {
        NumberAnimation {
            duration: MatusMotion.durationMedium2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MatusMotion.curveGlide
        }
    }

    Behavior on hoverLead {
        NumberAnimation {
            duration: MatusMotion.durationShort2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MatusMotion.curveGlide
        }
    }

    Behavior on hoverFollow {
        NumberAnimation {
            duration: MatusMotion.durationMedium2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MatusMotion.curveGlide
        }
    }

    // Visual window snap animation (only active when not dragging and in Area mode)
    Behavior on animX {
        enabled: !inputArea.pressed && root.pickerMode === 0

        MatusAnim {
            type: MatusAnim.FastEffects
        }
    }

    Behavior on animY {
        enabled: !inputArea.pressed && root.pickerMode === 0

        MatusAnim {
            type: MatusAnim.FastEffects
        }
    }

    Behavior on animW {
        enabled: !inputArea.pressed && root.pickerMode === 0

        MatusAnim {
            type: MatusAnim.FastEffects
        }
    }

    Behavior on animH {
        enabled: !inputArea.pressed && root.pickerMode === 0

        MatusAnim {
            type: MatusAnim.FastEffects
        }
    }

    // Fade wrapper
    Item {
        id: fadeRoot

        anchors.fill: parent
        focus: true
        opacity: (root.host !== null && root.host.isOpen && (!root.freezeFrame || freezeFrameItem.hasContent) && !root.host.closing) ? 1 : 0

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.cancelled()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_R || event.key === Qt.Key_A) {
                root.setMode(0)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_F) {
                root.setMode(1)
                event.accepted = true
                return
            }
        }

        Behavior on opacity {
            MatusAnim {
                type: MatusAnim.FastEffects
            }
        }

        // Freeze-frame background (only when freezeFrame is true)
        ScreencopyView {
            id: freezeFrameItem

            anchors.fill: parent
            captureSource: (root.freezeFrame && root.host !== null && root.host.isOpen) ? root.screen : null
            live: false
        }

        // Single-pass GPU Shader Dimming with Smooth Cutout (hidden in fullscreen mode)
        ShaderEffect {
            property real widthPx: root.width
            property real heightPx: root.height
            property real selX: root.animX
            property real selY: root.animY
            property real selW: root.animW
            property real selH: root.animH
            property real selRadius: Theming.radiusSm
            property vector4d dimCol: Qt.vector4d(Theming.scrim.r, Theming.scrim.g, Theming.scrim.b, Theming.opacityScrim)

            anchors.fill: parent
            blending: true
            fragmentShader: Qt.resolvedUrl("../../shaders/snipdim.frag.qsb")
            opacity: root.pickerMode === 0 ? 1 : 0

            Behavior on opacity {
                MatusAnim {
                    type: MatusAnim.FastEffects
                }
            }
        }

        // Vertical crosshair aim line (Area mode)
        Rectangle {
            z: 90
            visible: inputArea.containsMouse && root.pickerMode === 0 && (root.host === null || !root.host.closing)
            opacity: 0.25
            x: inputArea.mouseX
            y: 0
            width: 1
            height: root.height
            color: Theming.primary
        }

        // Horizontal crosshair aim line (Area mode)
        Rectangle {
            z: 90
            visible: inputArea.containsMouse && root.pickerMode === 0 && (root.host === null || !root.host.closing)
            opacity: 0.25
            x: 0
            y: inputArea.mouseY
            width: root.width
            height: 1
            color: Theming.primary
        }

        // Dashed Selection Border & Badges
        Shape {
            id: selectionBorder

            readonly property int borderWidth: 2

            x: root.animX - borderWidth
            y: root.animY - borderWidth
            width: root.animW + borderWidth * 2
            height: root.animH + borderWidth * 2
            visible: (root.pickerMode === 1) || (root.animW > 2 && root.animH > 2 && (root.onClient || inputArea.pressed))

            ShapePath {
                strokeWidth: selectionBorder.borderWidth
                strokeColor: Theming.primary
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]

                PathRectangle {
                    x: selectionBorder.borderWidth / 2
                    y: selectionBorder.borderWidth / 2
                    width: root.animW + selectionBorder.borderWidth
                    height: root.animH + selectionBorder.borderWidth
                    radius: root.pickerMode === 1 ? 0 : Theming.radiusSm
                }
            }

            // Window Class / Title Chip
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: selectionBorder.borderWidth
                anchors.bottom: parent.top
                anchors.bottomMargin: 6 * Theming.spacingMultiplier - selectionBorder.borderWidth
                implicitWidth: titleText.implicitWidth + 16 * Theming.paddingMultiplier
                implicitHeight: titleText.implicitHeight + 8 * Theming.paddingMultiplier
                radius: Theming.radiusSm
                color: Theming.primary
                visible: root.pickerMode === 0 && root.activeClient !== null && (root.activeClient.clientClass || root.activeClient.title) !== ""

                MatusText {
                    id: titleText

                    anchors.centerIn: parent
                    text: root.activeClient ? (root.activeClient.clientClass || root.activeClient.title) : ""
                    family: Theming.fontFamilyMono
                    size: Theming.fontSizeSmaller
                    weight: MatusText.Weight.DemiBold
                    color: Theming.primaryOn
                }
            }

            // Dimension Badge
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: selectionBorder.borderWidth
                anchors.bottom: parent.top
                anchors.bottomMargin: 6 * Theming.spacingMultiplier - selectionBorder.borderWidth
                implicitWidth: dimText.implicitWidth + 16 * Theming.paddingMultiplier
                implicitHeight: dimText.implicitHeight + 8 * Theming.paddingMultiplier
                radius: Theming.radiusSm
                color: Theming.primary
                visible: root.animW > 16 && root.animH > 16

                MatusText {
                    id: dimText

                    anchors.centerIn: parent
                    text: (root.pickerMode === 1 ? "Fullscreen " : "") + Math.round(root.targetW * root.uiToLogX * root.monitorScale) + " × " + Math.round(root.targetH * root.uiToLogY * root.monitorScale)
                    family: Theming.fontFamilyMono
                    size: Theming.fontSizeSmaller
                    weight: MatusText.Weight.DemiBold
                    color: Theming.primaryOn
                }
            }
        }

        // Fullscreen Mouse Input Area
        MouseArea {
            id: inputArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: root.host !== null && !root.host.closing && (!root.freezeFrame || freezeFrameItem.hasContent)
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: {
                if (root.pickerMode === 0 && !pressed) {
                    root.refreshClients()
                    root.checkClientRects(mouseX, mouseY)
                }
            }

            onPressed: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.cancelled()
                    return
                }
                if (root.pickerMode === 0) {
                    root.startX = mouse.x
                    root.startY = mouse.y
                    if (!root.onClient) {
                        root.targetX = mouse.x
                        root.targetY = mouse.y
                        root.targetW = 0
                        root.targetH = 0
                    }
                }
            }

            onPositionChanged: function (mouse) {
                if (root.pickerMode === 1)
                    return
                if (pressed) {
                    const dx = Math.abs(mouse.x - root.startX)
                    const dy = Math.abs(mouse.y - root.startY)
                    if (dx > 4 || dy > 4 || !root.onClient) {
                        root.onClient = false
                        root.activeClient = null
                        root.targetX = Math.min(root.startX, mouse.x)
                        root.targetY = Math.min(root.startY, mouse.y)
                        root.targetW = Math.abs(mouse.x - root.startX)
                        root.targetH = Math.abs(mouse.y - root.startY)
                    }
                } else {
                    if (root.clients.length === 0)
                        root.refreshClients()
                    root.checkClientRects(mouse.x, mouse.y)
                }
            }

            onReleased: function (mouse) {
                if (mouse.button === Qt.RightButton)
                    return
                if (root.pickerMode === 1) {
                    const fullW = Math.round(root.width * root.uiToLogX * root.monitorScale)
                    const fullH = Math.round(root.height * root.uiToLogY * root.monitorScale)
                    const mx0 = (root.monitor && root.monitor.lastIpcObject) ? root.monitor.lastIpcObject.x : 0
                    const my0 = (root.monitor && root.monitor.lastIpcObject) ? root.monitor.lastIpcObject.y : 0
                    root.confirmed(root.screen, root.monitorName, 0, 0, fullW, fullH, mx0, my0, null)
                    return
                }

                const scaleX = root.uiToLogX * root.monitorScale
                const scaleY = root.uiToLogY * root.monitorScale
                let cropX = Math.max(0, Math.round(root.targetX * scaleX))
                let cropY = Math.max(0, Math.round(root.targetY * scaleY))
                let cropWidth = Math.round(root.targetW * scaleX)
                let cropHeight = Math.round(root.targetH * scaleY)

                const maxW = Math.round(root.width * scaleX)
                const maxH = Math.round(root.height * scaleY)
                cropWidth = Math.min(cropWidth, maxW - cropX)
                cropHeight = Math.min(cropHeight, maxH - cropY)

                if (cropWidth < 8 || cropHeight < 8)
                    return
                const mx0 = (root.monitor && root.monitor.lastIpcObject) ? root.monitor.lastIpcObject.x : 0
                const my0 = (root.monitor && root.monitor.lastIpcObject) ? root.monitor.lastIpcObject.y : 0
                const globalX = Math.round(mx0 + root.targetX * root.uiToLogX)
                const globalY = Math.round(my0 + root.targetY * root.uiToLogY)

                root.confirmed(root.screen, root.monitorName, cropX, cropY, cropWidth, cropHeight, globalX, globalY, root.activeClient)
            }
        }

        // Bottom Mode Picker + FAB Switcher
        Item {
            id: bottomControls

            z: 100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24 * Theming.spacingMultiplier
            implicitWidth: pill.implicitWidth + Theming.spacingLg + fabMenu.implicitWidth
            implicitHeight: Math.max(pill.implicitHeight, fabMenu.implicitHeight)

            // Mode Pill
            Item {
                id: pill

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.pillPadding * 2 + root.tabWidth * 2 + root.tabSpacing
                implicitHeight: root.pillPadding * 2 + root.tabHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theming.radiusPill
                    color: Theming.surfaceContainer
                }

                Rectangle {
                    id: hoverPill

                    x: Math.round(root.pillX(root.hoverLead, root.hoverFollow))
                    y: root.pillPadding
                    width: Math.round(root.pillWidth(root.hoverLead, root.hoverFollow))
                    height: root.tabHeight
                    radius: height / 2
                    color: Theming.withAlpha(Theming.primary, 0.12)
                    opacity: root.hoveredIndex >= 0 ? 1 : 0

                    Behavior on opacity {
                        MatusAnim {
                            type: MatusAnim.FastEffects
                        }
                    }
                }

                Rectangle {
                    id: activePill

                    x: Math.round(root.pillX(root.activeLead, root.activeFollow))
                    y: root.pillPadding
                    width: Math.round(root.pillWidth(root.activeLead, root.activeFollow))
                    height: root.tabHeight
                    radius: height / 2
                    color: Theming.primaryContainer
                }

                Row {
                    id: tabRow

                    x: root.pillPadding
                    y: root.pillPadding
                    spacing: root.tabSpacing

                    ModeTab {
                        mode: 0
                        iconName: "crop"
                        label: "Area"
                        key: "R"
                        shape: MaterialShape.Shape.Cookie4Sided
                        activeTab: root.pickerMode === 0
                        onActivated: root.setMode(0)
                        onHoverChanged: function (isHov) {
                            root.hoveredIndex = isHov ? 0 : (root.hoveredIndex === 0 ? -1 : root.hoveredIndex)
                        }
                    }

                    ModeTab {
                        mode: 1
                        iconName: "fullscreen"
                        label: "Fullscreen"
                        key: "F"
                        shape: MaterialShape.Shape.VerySunny
                        activeTab: root.pickerMode === 1
                        onActivated: root.setMode(1)
                        onHoverChanged: function (isHov) {
                            root.hoveredIndex = isHov ? 1 : (root.hoveredIndex === 1 ? -1 : root.hoveredIndex)
                        }
                    }
                }
            }

            // Tool switcher FAB Menu
            MatusFabMenu {
                id: fabMenu

                anchors.left: pill.right
                anchors.leftMargin: Theming.spacingLg
                anchors.verticalCenter: parent.verticalCenter
                iconName: root.activeTool === 1 ? "videocam" : (root.activeTool === 2 ? "colorize" : "photo_camera")
                fabSize: Math.round(52 * Theming.paddingMultiplier)
                itemHeight: Math.round(44 * Theming.paddingMultiplier)
                buttonSize: MatusButton.Size.L
                restShape: MaterialShape.Shape.Circle
                morphShape: MaterialShape.Shape.Square

                model: [
                    {
                        icon: "photo_camera",
                        label: "Screenshot"
                    },
                    {
                        icon: "videocam",
                        label: "Screen Recording"
                    },
                    {
                        icon: "colorize",
                        label: "Color Picker"
                    }
                ]

                onSelected: function (index) {
                    if (index !== root.activeTool) {
                        root.host.closeInstant()
                        MatusOverlays.requestToolSwitch(index)
                    }
                }
            }
        }
    }

    // --- Sub-components ---
    component ModeTab: Item {
        id: tab

        property int mode: 0
        property string iconName: ""
        property string label: ""
        property string key: ""
        property int shape: MaterialShape.Shape.Circle
        property bool activeTab: false
        readonly property bool isHovered: tabMa.containsMouse

        signal activated
        signal hoverChanged(bool hovered)

        width: root.tabWidth
        height: root.tabHeight

        onIsHoveredChanged: tab.hoverChanged(tab.isHovered)

        RowLayout {
            anchors.centerIn: parent
            spacing: Theming.spacingSm

            Item {
                implicitWidth: Math.round(24 * Theming.paddingMultiplier)
                implicitHeight: Math.round(24 * Theming.paddingMultiplier)

                MaterialShape {
                    anchors.centerIn: parent
                    implicitSize: parent.width
                    shape: tab.shape
                    scale: tab.activeTab ? 1.0 : 0.0
                    color: Theming.primaryContainerOn
                    opacity: tab.activeTab ? 0.18 : 0.0

                    Behavior on scale {
                        MatusAnim {
                            type: MatusAnim.FastSpatial
                        }
                    }
                    Behavior on opacity {
                        MatusAnim {
                            type: MatusAnim.FastEffects
                        }
                    }
                }

                MatusIcon {
                    anchors.centerIn: parent
                    text: tab.iconName
                    color: tab.activeTab ? Theming.primaryContainerOn : (tab.isHovered ? Theming.surfaceOn : Theming.surfaceVariantOn)
                    font.pixelSize: Theming.iconSizeMd

                    Behavior on color {
                        MatusColorAnim {
                            type: MatusAnim.FastEffects
                        }
                    }
                }
            }

            MatusText {
                text: tab.label
                color: tab.activeTab ? Theming.primaryContainerOn : (tab.isHovered ? Theming.surfaceOn : Theming.surfaceVariantOn)
                size: Theming.fontSizeNormal
                weight: tab.activeTab ? MatusText.Weight.DemiBold : MatusText.Weight.Medium

                Behavior on color {
                    MatusColorAnim {
                        type: MatusAnim.FastEffects
                    }
                }
            }

            Rectangle {
                Layout.leftMargin: Math.round(2 * Theming.spacingMultiplier)
                implicitWidth: Math.round(20 * Theming.paddingMultiplier)
                implicitHeight: Math.round(20 * Theming.paddingMultiplier)
                radius: Theming.radiusSm
                color: tab.activeTab ? Theming.mix(Theming.primaryContainerOn, Theming.primaryContainer, 0.82) : Theming.surfaceContainerHighest

                Behavior on color {
                    MatusColorAnim {
                        type: MatusAnim.FastEffects
                    }
                }

                MatusText {
                    anchors.centerIn: parent
                    text: tab.key
                    color: tab.activeTab ? Theming.primaryContainer : Theming.surfaceVariantOn
                    family: Theming.fontFamilyMono
                    size: Theming.fontSizeSmaller
                    weight: MatusText.Weight.DemiBold
                }
            }
        }

        MouseArea {
            id: tabMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.activated()
        }
    }
}
