import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland // Required for ToplevelManager and ScreencopyView
import "../"

ColumnLayout {
    id: winSwitcher
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    focus: true
    Component.onCompleted: refreshClients()

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
            winSwitcher.activateSelected();
            event.accepted = true;
        }
    }

    property alias windowGrid: windowCarousel
    property bool pendingActivation: false
    ListModel { id: clientsModel }

    readonly property int calculatedCount: clientsModel.count

    function refreshClients() {
        // Clear the model instantly to prevent flashing stale data from previous Alt+Tabs
        clientsModel.clear(); 
        pendingActivation = false;
        
        if (clientScanner.running) clientScanner.running = false;
        clientScanner.running = true;
    }

    function cycleNext() {
        if (clientsModel.count > 0) windowCarousel.incrementCurrentIndex();
    }

    function cyclePrev() {
        if (clientsModel.count > 0) windowCarousel.decrementCurrentIndex();
    }

    property bool pendingQuickSwitch: false

    function quickSwitchToLast() {
        if (clientScanner.running) {
            pendingQuickSwitch = true;
            return;
        }

        if (clientsModel.count > 1) {
            var item = clientsModel.get(1);
            var rawAddr = item.address.trim();
            var formattedAddr = rawAddr.startsWith("0x") ? rawAddr : ("0x" + rawAddr);

            var cmd = `focuswindow address:${formattedAddr}`;
            if (typeof Hyprland !== "undefined") {
                Hyprland.dispatch(cmd);
            }
            Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
        }
    }

    // Delay buffer to allow Wayland layer surface grab release prior to dispatch
    Timer {
        id: focusDelayTimer
        interval: 40
        repeat: false
        property string targetAddress: ""
        onTriggered: {
            var cmd = `focuswindow address:${targetAddress}`;
            if (typeof Hyprland !== "undefined") {
                Hyprland.dispatch(cmd);
            }
            Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
        }
    }

    function activateSelected() {
        if (root.activeMode !== "switcher") return;

        // If the user Alt+Tabs super fast before the scanner finishes, queue the activation
        if (clientScanner.running) {
            pendingActivation = true;
            return;
        }

        if (clientsModel.count > 0 && windowCarousel.currentIndex >= 0 && windowCarousel.currentIndex < clientsModel.count) {
            var item = clientsModel.get(windowCarousel.currentIndex);
            var rawAddr = item.address.trim();
            var formattedAddr = rawAddr.startsWith("0x") ? rawAddr : ("0x" + rawAddr);

            root.collapseToIdle();

            var cmd = `focuswindow address:${formattedAddr}`;
            if (typeof Hyprland !== "undefined") {
                Hyprland.dispatch(cmd);
            }
            Quickshell.execDetached(["hyprctl", "dispatch", cmd]);

            focusDelayTimer.targetAddress = formattedAddr;
            focusDelayTimer.restart();
        } else {
            root.collapseToIdle();
        }
    }

    Process {
        id: clientScanner
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                var rawClients = [];
                try {
                    rawClients = JSON.parse(this.text);
                } catch(e) {
                    return;
                }

                var valid = [];
                for (var k = 0; k < rawClients.length; k++) {
                    var c = rawClients[k];
                    var wsId = (c.workspace && typeof c.workspace.id === "number") ? c.workspace.id : -1;
                    if (wsId > 0 && !c.hidden) {
                        valid.push(c);
                    }
                }

                valid.sort((a, b) => {
                    var idA = typeof a.focusHistoryID === "number" ? a.focusHistoryID : 999;
                    var idB = typeof b.focusHistoryID === "number" ? b.focusHistoryID : 999;
                    return idA - idB;
                });

                var newItems = [];
                for (var i = 0; i < valid.length; i++) {
                    var v = valid[i];
                    var cClass = (v.class || "application-x-executable").trim();
                    var initClass = (v.initialClass || cClass).toLowerCase().trim();
                    var winW = (v.size && v.size.length >= 2) ? v.size[0] : 1920;
                    var winH = (v.size && v.size.length >= 2) ? v.size[1] : 1080;

                    newItems.push({
                        "address": v.address ? v.address.trim() : "",
                        "title": v.title ? v.title.trim() : "Unknown",
                        "className": cClass,
                        "workspace": String(v.workspace ? v.workspace.id : 1),
                        "iconName": initClass,
                        "winWidth": winW,
                        "winHeight": winH
                    });
                }

                // Prevent Carousel snap animations during the population phase
                windowCarousel.highlightMoveDuration = 0;

                // Batch append to avoid rendering intermediate states
                for (var j = 0; j < newItems.length; j++) {
                    clientsModel.append(newItems[j]);
                }

                // Preselect previous window (index 1) immediately
                if (clientsModel.count > 0) {
                    windowCarousel.currentIndex = clientsModel.count > 1 ? 1 : 0;
                    windowCarousel.positionViewAtIndex(windowCarousel.currentIndex, PathView.Center);
                }

                restoreAnimTimer.restart();

                // If a quick-tap Alt-Tab was released while scanning, trigger quick switch directly
                if (pendingQuickSwitch) {
                    pendingQuickSwitch = false;
                    quickSwitchToLast();
                    return;
                }

                // If a super-fast Alt+Tab release was queued while we were scanning, trigger it now!
                if (pendingActivation) {
                    pendingActivation = false;
                    activateSelected();
                }
            }
        }
    }

    Timer {
        id: restoreAnimTimer
        interval: 60
        repeat: false
        onTriggered: windowCarousel.highlightMoveDuration = 180
    }

    // 34px Minimal Luxury Header
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 8
        Layout.leftMargin: 4
        Layout.rightMargin: 4

        Text {
            text: "ACTIVE WINDOWS"
            font.family: "Noto Sans"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: Qt.rgba(255, 255, 255, 0.60)
            renderType: Text.NativeRendering
        }

        Rectangle {
            visible: clientsModel.count > 0
            implicitHeight: 20
            implicitWidth: countText.implicitWidth + 12
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.08)

            Text {
                id: countText
                anchors.centerIn: parent
                text: (windowCarousel.currentIndex + 1) + " / " + clientsModel.count
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Qt.rgba(255, 255, 255, 0.75)
                renderType: Text.NativeRendering
            }
        }

        Item { Layout.fillWidth: true }
        
        Text {
            text: "Alt + Tab to cycle • Release to focus"
            font.family: "Noto Sans"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Qt.rgba(255, 255, 255, 0.40)
            renderType: Text.NativeRendering
        }
    }

    // 3D Carousel View
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            // Only show 'No open windows' if we are actually done scanning
            visible: clientsModel.count === 0 && !clientScanner.running 
            text: "No open windows"
            color: Theme.colors.text_secondary ?? "#565f89"
            font.pixelSize: 13
        }

        RowLayout {
            anchors.fill: parent
            visible: clientsModel.count > 0
            spacing: 8

            Rectangle {
                id: leftArrow
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: leftArrowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                border.width: 0
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                    color: leftArrowMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.65)
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: leftArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: windowCarousel.decrementCurrentIndex()
                }
            }

            PathView {
                id: windowCarousel
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                model: clientsModel

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 0

                readonly property real itemWidth: Math.min(320, Math.max(180, width * 0.46))
                readonly property real itemHeight: height * 0.88

                Keys.onLeftPressed: decrementCurrentIndex()
                Keys.onRightPressed: incrementCurrentIndex()
                Keys.onReturnPressed: winSwitcher.activateSelected()
                Keys.onEnterPressed: winSwitcher.activateSelected()
                Keys.onEscapePressed: root.collapseToIdle()
                Keys.onReleased: (event) => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                        winSwitcher.activateSelected();
                        event.accepted = true;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0) windowCarousel.incrementCurrentIndex();
                        else if (wheel.angleDelta.y > 0) windowCarousel.decrementCurrentIndex();
                    }
                }

                path: Path {
                    startX: -windowCarousel.itemWidth * 0.35
                    startY: windowCarousel.height / 2
                    PathAttribute { name: "itemScale"; value: 0.55 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: -42.0 }

                    PathLine { x: windowCarousel.width * 0.22; y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.80 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: -28.0 }

                    PathLine { x: windowCarousel.width * 0.50; y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 1.0 }
                    PathAttribute { name: "itemOpacity"; value: 1.0 }
                    PathAttribute { name: "itemZ"; value: 30 }
                    PathAttribute { name: "itemRotationY"; value: 0.0 }

                    PathLine { x: windowCarousel.width * 0.78; y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.80 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: 28.0 }

                    PathLine { x: windowCarousel.width + (windowCarousel.itemWidth * 0.35); y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.55 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: 42.0 }
                }

                delegate: Item {
                    id: delegateRoot
                    width: windowCarousel.itemWidth
                    height: windowCarousel.itemHeight

                    scale: PathView.itemScale ?? 0.8
                    opacity: PathView.itemOpacity ?? 0.0
                    z: PathView.itemZ ?? 1
                    visible: opacity > 0.01

                    transform: Rotation {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: PathView.itemRotationY ?? 0
                    }
                    
                    // Match Hyprland IPC address to Wayland Toplevel buffer
                    property var toplevel: {
                        var rawAddr = address.trim();
                        var searchAddr = rawAddr.startsWith("0x") ? rawAddr.substring(2) : rawAddr;
                        var allToplevels = typeof ToplevelManager !== "undefined" ? ToplevelManager.toplevels.values : [];
                        for (var i = 0; i < allToplevels.length; i++) {
                            if (allToplevels[i].HyprlandToplevel && allToplevels[i].HyprlandToplevel.address === searchAddr) {
                                return allToplevels[i];
                            }
                        }
                        return null;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: PathView.isCurrentItem ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
                        border.width: 0
                        clip: true

                        // Live Native Wayland Buffer Preview
                        Rectangle {
                            anchors.fill: parent
                            color: "#141416"
                            
                            ScreencopyView {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height * (winWidth / Math.max(1, winHeight)))
                                height: Math.min(parent.height, parent.width / (winWidth / Math.max(1, winHeight)))
                                
                                captureSource: delegateRoot.toplevel
                                live: true

                                layer.enabled: true
                                layer.mipmap: true
                                layer.smooth: true
                                
                                // Fallback icon for windows that reject the screencopy protocol
                                IrisIcon {
                                    anchors.centerIn: parent
                                    visible: !parent.captureSource
                                    icon: iconName
                                    iconSize: 64
                                    fallbackSymbol: IconResolver.resolve(iconName, className).fallbackSymbol || "window"
                                    color: Theme.accent
                                }
                            }
                        }

                        // Gradient Info Overlay
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 64
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(14, 14, 16, 0.92) }
                            }
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                anchors.bottomMargin: 10
                                spacing: 2
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        color: Qt.rgba(255, 255, 255, 0.10)
                                        Text {
                                            anchors.centerIn: parent
                                            text: workspace
                                            font.family: "Noto Sans"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: Qt.rgba(255, 255, 255, 0.85)
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    // App Icon Badge
                                    IrisIcon {
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        icon: iconName
                                        iconSize: 16
                                        fallbackSymbol: IconResolver.resolve(iconName, className).fallbackSymbol || "window"
                                        color: Theme.accent
                                    }

                                    Text {
                                        text: className
                                        color: "#ffffff"
                                        font.family: "Noto Sans"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Text {
                                    text: title
                                    color: Qt.rgba(255, 255, 255, 0.65)
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (PathView.isCurrentItem) {
                                winSwitcher.activateSelected();
                            } else {
                                windowCarousel.currentIndex = index;
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightArrow
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: rightArrowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                border.width: 0
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                    color: rightArrowMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.65)
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: rightArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: windowCarousel.incrementCurrentIndex()
                }
            }

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: rightArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: rightArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: windowCarousel.incrementCurrentIndex()
                }
            }
        }
    }
}
