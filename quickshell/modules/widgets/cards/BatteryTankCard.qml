import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import "../../../"
import "../../"
import "../"

Item {
    id: root

    readonly property var bat: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property bool present: !!(bat && bat.ready && bat.isPresent)
    readonly property real percentage: present ? bat.percentage : 0.82
    readonly property real chargePercent: Math.round(percentage * 100)
    readonly property real targetLevel: present ? Math.max(0, Math.min(1, percentage)) : 0
    property real animatedLevel: targetLevel
    readonly property bool charging: present && bat.state === UPowerDevice.Charging
    readonly property bool full: present && (bat.state === UPowerDevice.FullyCharged || (chargePercent >= 100 && !charging))
    readonly property bool powerConnected: present && (typeof UPower !== "undefined") && !UPower.onBattery
    readonly property bool lowBattery: present && chargePercent <= 15 && !powerConnected

    readonly property color containerColor: Theme.m3.secondary_container ?? Theme.colors.card_bg
    readonly property color levelColor: lowBattery
        ? (Theme.m3.error ?? "#ffb4ab")
        : (Theme.m3.secondary ?? Theme.accent)
    readonly property color fgContainer: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
    readonly property color fgLevel: Theme.m3.on_secondary ?? "#030a16"
    readonly property real bodyRadius: Math.min(WidgetStore.s(24), batteryBody.width * 0.16)
    readonly property real iconCenterY: WidgetStore.s(16 + 18)
    readonly property bool iconCovered: animatedLevel >= 1 - iconCenterY / Math.max(1, batteryBody.height)

    Behavior on animatedLevel {
        NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.39, 1.29, 0.35, 0.98, 1, 1] }
    }

    function fmtDuration(sec) {
        if (!sec || sec <= 0 || !isFinite(sec)) return "";
        const m = Math.round(sec / 60);
        const h = Math.floor(m / 60);
        const rm = m % 60;
        return h > 0 ? (h + "h " + rm + "m") : (rm + "m");
    }

    function timingText() {
        if (root.full) return "Fully charged";
        if (root.charging) {
            const t = root.bat ? fmtDuration(root.bat.timeToFull) : "";
            return t ? ("Full in " + t) : "Charging";
        }
        if (root.powerConnected) return "Plugged in";
        const rem = root.bat ? fmtDuration(root.bat.timeToEmpty) : "";
        return rem ? (rem + " left") : "On battery";
    }

    function statusText() {
        if (!root.present) return "Unavailable";
        if (root.full) return "Charged";
        if (root.charging) return "Charging";
        if (root.powerConnected) return "AC Power";
        return "Discharging";
    }

    function batteryIconName() {
        if (!root.present) return "battery_unknown";
        if (root.charging) {
            if (chargePercent <= 20) return "battery_charging_20";
            if (chargePercent <= 35) return "battery_charging_30";
            if (chargePercent <= 55) return "battery_charging_50";
            if (chargePercent <= 70) return "battery_charging_60";
            if (chargePercent <= 85) return "battery_charging_80";
            if (chargePercent <= 95) return "battery_charging_90";
            return "battery_charging_full";
        }
        if (chargePercent <= 10) return "battery_0_bar";
        if (chargePercent <= 25) return "battery_2_bar";
        if (chargePercent <= 45) return "battery_3_bar";
        if (chargePercent <= 65) return "battery_4_bar";
        if (chargePercent <= 80) return "battery_5_bar";
        if (chargePercent <= 94) return "battery_6_bar";
        return "battery_full";
    }

    // Shadow behind tank body (supersampled 2x so edges stay crisp at 1.2x UI scale)
    Rectangle {
        anchors.fill: batteryBody
        radius: root.bodyRadius
        color: root.containerColor
        layer.enabled: root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)), Math.max(1, Math.round(height * 2 * WidgetStore.qtScale)))
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.42)
            shadowBlur: 0.7
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
    }

    // Battery top terminal cap
    Rectangle {
        width: Math.max(WidgetStore.s(34), Math.min(WidgetStore.s(54), parent.width * 0.30))
        height: WidgetStore.s(12)
        radius: WidgetStore.s(6)
        color: root.animatedLevel >= 1 ? root.levelColor : root.containerColor
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
    }

    Rectangle {
        id: batteryBody
        radius: root.bodyRadius
        color: root.containerColor
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; bottom: parent.bottom
            leftMargin: WidgetStore.s(3); rightMargin: WidgetStore.s(3)
            topMargin: WidgetStore.s(8); bottomMargin: WidgetStore.s(2)
        }
    }

    // Rounded tank silhouette mask (used ONLY for the solid liquid background fill, never for text)
    Rectangle {
        id: roundedMask
        parent: batteryBody
        anchors.fill: parent
        radius: batteryBody.radius
        color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)), Math.max(1, Math.round(height * 2 * WidgetStore.qtScale)))
    }

    // Clipped liquid color background ONLY (text stays outside any offscreen FBO layer!)
    Item {
        parent: batteryBody
        z: 1
        anchors.fill: parent
        layer.enabled: root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)), Math.max(1, Math.round(height * 2 * WidgetStore.qtScale)))
        layer.effect: OpacityMask {
            maskSource: roundedMask
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * root.animatedLevel
            color: root.levelColor
        }
    }

    // Unfilled foreground content clipped natively with GPU scissor (zero offscreen FBO blur)
    Item {
        id: topClip
        parent: batteryBody
        z: 2
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height * (1 - root.animatedLevel)
        clip: true
        visible: height > 0.5

        BatteryContents {
            x: WidgetStore.s(14)
            y: WidgetStore.s(14)
            width: Math.max(1, batteryBody.width - WidgetStore.s(28))
            height: Math.max(1, batteryBody.height - WidgetStore.s(28))
            fgColor: root.fgContainer
        }
    }

    // Filled foreground content clipped natively with GPU scissor (zero offscreen FBO blur)
    Item {
        id: levelClip
        parent: batteryBody
        z: 3
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * root.animatedLevel
        clip: true
        visible: height > 0.5

        BatteryContents {
            x: WidgetStore.s(14)
            y: levelClip.height - batteryBody.height + WidgetStore.s(14)
            width: Math.max(1, batteryBody.width - WidgetStore.s(28))
            height: Math.max(1, batteryBody.height - WidgetStore.s(28))
            fgColor: root.fgLevel
        }
    }

    MaterialSymbol {
        parent: batteryBody
        z: 4
        text: root.batteryIconName()
        iconSize: WidgetStore.si(32)
        fill: 1
        color: root.iconCovered ? root.fgLevel : (root.lowBattery ? (Theme.m3.error ?? "#ffb4ab") : (root.powerConnected ? (Theme.m3.primary ?? Theme.accent) : root.levelColor))
        anchors {
            top: parent.top
            right: parent.right
            margins: WidgetStore.s(12)
        }
    }

    component BatteryContents: Item {
        id: contents
        required property color fgColor

        Text {
            text: "Battery"
            color: contents.fgColor
            font.family: "Noto Sans"
            font.pixelSize: WidgetStore.si(13)
            font.weight: Font.DemiBold
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
            anchors { left: parent.left; top: parent.top }
        }

        ColumnLayout {
            visible: root.present
            spacing: WidgetStore.s(4)
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(4)
                MaterialSymbol { text: "schedule"; iconSize: WidgetStore.si(14); color: contents.fgColor }
                Text {
                    Layout.fillWidth: true
                    text: root.timingText()
                    color: contents.fgColor
                    opacity: 0.85
                    font.family: "Noto Sans"
                    font.pixelSize: WidgetStore.si(11)
                    elide: Text.ElideRight
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(4)
                visible: !isNaN(WidgetTelemetry.batteryRateW) && WidgetTelemetry.batteryRateW > 0.1
                MaterialSymbol { text: "electric_bolt"; iconSize: WidgetStore.si(14); color: contents.fgColor }
                Text {
                    Layout.fillWidth: true
                    text: WidgetTelemetry.batteryRateW.toFixed(1) + " W"
                    color: contents.fgColor
                    opacity: 0.85
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: WidgetStore.si(11)
                    elide: Text.ElideRight
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: WidgetTelemetry.batteryHealth > 0
                spacing: WidgetStore.s(4)
                MaterialSymbol { text: "health_and_safety"; iconSize: WidgetStore.si(14); color: contents.fgColor }
                Text {
                    Layout.fillWidth: true
                    text: "Health " + WidgetTelemetry.batteryHealth + "%"
                    color: contents.fgColor
                    opacity: 0.85
                    font.family: "Noto Sans"
                    font.pixelSize: WidgetStore.si(11)
                    elide: Text.ElideRight
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }
        }

        ColumnLayout {
            spacing: 0
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.statusText()
                color: contents.fgColor
                opacity: 0.78
                font.family: "Noto Sans"
                font.pixelSize: WidgetStore.si(11)
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(3)
                Item { Layout.fillWidth: true }
                MaterialSymbol {
                    text: root.powerConnected ? "power" : "power_off"
                    iconSize: WidgetStore.si(20)
                    fill: 1
                    color: contents.fgColor
                }
                Text {
                    text: root.present ? (root.chargePercent + "%") : "—"
                    color: contents.fgColor
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(24)
                    font.weight: Font.Bold
                    font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
                }
            }
        }
    }
}
