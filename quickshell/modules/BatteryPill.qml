import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../"

// ────────────────────────────────────────────────────────────
// Material 3 / Android Expressive Battery Icon (Caelestia / Android 16 Style)
// Clean symbolic battery glyph with dynamic charge tiers & percentage readout.
// ────────────────────────────────────────────────────────────
Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool isReady: battery != null && (battery.percentage !== undefined && battery.percentage > 0)
    readonly property real percentage: isReady ? battery.percentage : 1.0
    readonly property int batteryLevel: Math.round(percentage * 100)
    readonly property bool isCharging: battery && (battery.state === UPowerDevice.Charging || battery.state === UPowerDevice.PendingCharge)
    readonly property bool isFullyCharged: battery && battery.state === UPowerDevice.FullyCharged
    readonly property bool isLow: isReady && batteryLevel <= 20 && !isCharging

    readonly property color chargeColor: "#34d399"
    readonly property color lowColor: "#ff5449"
    readonly property color normalColor: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
    readonly property color fillColor: root.isCharging ? root.chargeColor : (root.isLow ? root.lowColor : (Theme.colors.text_primary ?? "#ffffff"))

    function resolveBatteryIcon(level, charging) {
        if (charging) {
            if (level >= 95) return "battery_charging_full";
            if (level >= 85) return "battery_charging_90";
            if (level >= 75) return "battery_charging_80";
            if (level >= 55) return "battery_charging_60";
            if (level >= 45) return "battery_charging_50";
            if (level >= 25) return "battery_charging_30";
            return "battery_charging_20";
        }
        if (level >= 93) return "battery_android_full";
        if (level >= 78) return "battery_android_6";
        if (level >= 64) return "battery_android_5";
        if (level >= 50) return "battery_android_4";
        if (level >= 35) return "battery_android_3";
        if (level >= 21) return "battery_android_2";
        if (level >= 7) return "battery_android_1";
        return "battery_android_alert";
    }

    readonly property string iconGlyph: root.isReady ? root.resolveBatteryIcon(root.batteryLevel, root.isCharging) : "battery_android_full"

    implicitWidth: mainRow.implicitWidth
    implicitHeight: 22

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 5

        // Dynamic Material 3 Battery Glyph Icon
        MaterialSymbol {
            id: batteryIcon
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconGlyph
            iconSize: 18
            fill: 1
            color: root.fillColor

            // Subtle breathing pulse animation while actively charging
            SequentialAnimation on opacity {
                running: root.isCharging && !root.isFullyCharged
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        // Tabular Percentage Text
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.isReady ? root.batteryLevel : "--") + "%"
            font.family: (typeof Theme !== "undefined" && Theme.fontFamily) ? Theme.fontFamily : "Noto Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            color: root.fillColor
            renderType: Text.NativeRendering
        }
    }
}
