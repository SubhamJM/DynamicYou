import QtQuick
import qs

// Material 3 / Android Expressive Battery Icon (Caelestia / Android 16 Style)
Item {
    id: bp

    property int percent: 0
    property bool charging: false
    property bool low: bp.percent <= 20 && !bp.charging
    property bool showText: true

    readonly property color chargeColor: "#34d399"
    readonly property color fillColor: bp.charging ? bp.chargeColor : (bp.low ? Theme.error : Theme.text)

    function resolveBatteryIcon(level, isCharging) {
        if (isCharging) {
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

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.dp(22)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.dp(5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bp.resolveBatteryIcon(bp.percent, bp.charging)
            font.family: Theme.fontFamilyIcon
            font.pixelSize: Theme.dp(18)
            font.variableAxes: ({ "FILL": 1 })
            color: bp.fillColor

            SequentialAnimation on opacity {
                running: bp.charging
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        Text {
            visible: bp.showText
            anchors.verticalCenter: parent.verticalCenter
            text: bp.percent + "%"
            color: bp.fillColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }
}
