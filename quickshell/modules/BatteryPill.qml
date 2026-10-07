import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Services.UPower
import "../"

// Material You (Material 3) animated battery pill with dynamic charging state
Item {
    id: root

    implicitWidth: batteryContainer.width
    implicitHeight: 24

    readonly property var battery: UPower.displayDevice
    
    // Readiness check to prevent initial zero-state / null-device visual glitches
    readonly property bool isReady: battery != null && (battery.percentage !== undefined && battery.percentage > 0)
    readonly property real percentage: isReady ? battery.percentage : 1.0
    readonly property int batteryLevel: Math.round(percentage * 100)
    readonly property bool isCharging: battery && battery.state === UPowerDevice.Charging
    readonly property bool isFullyCharged: battery && battery.state === UPowerDevice.FullyCharged
    readonly property bool isPluggedIn: isCharging || isFullyCharged
    readonly property bool isWarning: isReady && batteryLevel <= 25 && batteryLevel > 15
    readonly property bool isLow: isReady && batteryLevel <= 15
    readonly property bool isCritical: isLow && !isPluggedIn

    // Material 3 emphasized decelerate motion curve
    readonly property var motionCurve: (typeof NotchConfig !== "undefined" && NotchConfig.motionCurve) ? NotchConfig.motionCurve : [0.05, 0.7, 0.1, 1, 1, 1]

    // Track state changes for animations
    property bool wasPluggedIn: false
    property bool showExpandedMode: false
    property bool justPluggedIn: false

    // Detect plug-in event
    onIsPluggedInChanged: {
        if (isPluggedIn && !wasPluggedIn) {
            justPluggedIn = true
            showExpandedMode = true
            liquidFillAnim.restart()
            expandTimer.restart()
        }
        wasPluggedIn = isPluggedIn
    }

    // Timer to collapse back after showing liquid fill
    Timer {
        id: expandTimer
        interval: 4000
        onTriggered: {
            showExpandedMode = false
            justPluggedIn = false
        }
    }

    // Material 3 Dynamic Tonal Colors
    readonly property color normalColor: {
        if (!isReady) return Theme.colors.text_primary ?? "#f8fafc"
        if (isLow) return Theme.colors.error ?? "#f87171"
        if (isWarning) return Theme.colors.warning ?? "#fbbf24"
        return Theme.accent ?? "#7aa2f7"
    }

    readonly property color chargingColor: "#8FDEB4"
    readonly property color compactBatteryColor: {
        if (showExpandedMode || justPluggedIn) return chargingColor
        if (isPluggedIn && (isLow || isWarning)) return normalColor
        if (isPluggedIn) return chargingColor
        return normalColor
    }

    // Main container
    Item {
        id: batteryContainer
        anchors.centerIn: parent
        width: showExpandedMode ? expandedPill.width : Math.max(normalBattery.implicitWidth, 54)
        height: 20

        Behavior on width {
            NumberAnimation {
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.motionCurve
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // STATE 1 & 3: Normal / Charging compact view — Material You Capsule
        // ═══════════════════════════════════════════════════════════════
        Row {
            id: normalBattery
            anchors.centerIn: parent
            spacing: 6
            visible: !showExpandedMode
            opacity: (!showExpandedMode && root.isReady) ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.motionCurve }
            }

            // Percentage text
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.isReady ? batteryLevel : "--") + "%"
                font.family: "Noto Sans"
                font.pixelSize: 12
                font.weight: (isWarning || isLow) ? Font.Bold : Font.DemiBold
                color: compactBatteryColor
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation { duration: 280 }
                }

                // Critical pulse
                SequentialAnimation on opacity {
                    running: isCritical
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: 500 }
                    NumberAnimation { to: 0.3; duration: 500 }
                }
            }

            // Material You Battery Stadium Capsule
            Item {
                width: 24
                height: 12
                anchors.verticalCenter: parent.verticalCenter

                // Stadium Capsule Body
                Rectangle {
                    id: batteryBody
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.width: 1.2
                    border.color: compactBatteryColor

                    Behavior on border.color {
                        ColorAnimation { duration: 280 }
                    }

                    // Fluid inner fill
                    Rectangle {
                        id: fillRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 1.5
                        width: Math.max(0, (parent.width - 3) * (root.isReady ? root.percentage : 0))
                        radius: 4.5
                        color: compactBatteryColor

                        Behavior on width {
                            NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: root.motionCurve }
                        }

                        // Charging shimmer
                        Rectangle {
                            id: chargeShimmer
                            visible: isCharging && !isFullyCharged && !showExpandedMode
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.16)
                            opacity: 0

                            property real shimmerPos: 0
                            x: (parent.width + width) * shimmerPos - width

                            SequentialAnimation on shimmerPos {
                                running: isCharging && !isFullyCharged && !showExpandedMode
                                loops: Animation.Infinite
                                NumberAnimation { from: -0.3; to: 1.3; duration: 1200; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 400 }
                            }

                            SequentialAnimation on opacity {
                                running: isCharging && !isFullyCharged && !showExpandedMode
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.04; to: 0.18; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.18; to: 0.04; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    // Charging bolt icon
                    MaterialSymbol {
                        visible: isPluggedIn && !showExpandedMode
                        anchors.centerIn: parent
                        text: "bolt"
                        fill: 1
                        iconSize: 11
                        color: Theme.colors.bg ?? "#000000"

                        SequentialAnimation on scale {
                            running: isCharging && !isFullyCharged && !showExpandedMode
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.25; duration: 400; easing.type: Easing.OutCubic }
                            NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InCubic }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // STATE 2: Just plugged in — Material You Expressive Pill
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            id: expandedPill
            anchors.centerIn: parent
            width: pillRow.implicitWidth + 24
            height: 22
            radius: 11
            visible: showExpandedMode
            opacity: showExpandedMode ? 1 : 0
            color: Qt.rgba(0.06, 0.08, 0.12, 0.94)
            border.width: 1
            border.color: Qt.rgba(chargingColor.r, chargingColor.g, chargingColor.b, 0.50)

            Behavior on opacity {
                NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.motionCurve }
            }

            // Soft breathing glow ring
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: chargingColor
                opacity: 0

                SequentialAnimation on opacity {
                    running: showExpandedMode
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.0; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: "bolt"
                    fill: 1
                    iconSize: 13
                    color: chargingColor
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on scale {
                        running: showExpandedMode
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.15; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: (root.isReady ? batteryLevel : "--") + "%"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.colors.text_primary ?? "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }

            // Progress underline
            Rectangle {
                id: underlineTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                height: 2
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    id: liquidFillBg
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 0
                    radius: parent.radius
                    color: chargingColor

                    SequentialAnimation {
                        id: liquidFillAnim

                        NumberAnimation {
                            target: liquidFillBg
                            property: "width"
                            from: 0
                            to: underlineTrack.width * (root.isReady ? root.percentage : 0)
                            duration: 900
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.motionCurve
                        }
                    }
                }
            }
        }
    }
}
