pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../"
import "."
import "./widgets"

// Matushell-style resting Dynamic Island glance row:
// [Date • Time] [Network] [Material Battery w/ embedded percentage] (+ active timer)
RowLayout {
    id: root

    property date clockDate: new Date()
    property bool isScreenRecording: false
    property int notificationCount: 0
    property bool dndEnabled: false
    property string activeNetType: "wifi"
    property string activeNetName: ""
    property int activeNetSignal: 0

    signal timerOpenRequested(string tab)

    spacing: 10
    implicitHeight: 28

    readonly property color fgPrimary: Theme.colors.text_primary ?? "#f5f5f7"
    readonly property color fgSecondary: Qt.alpha(fgPrimary, 0.72)
    readonly property color accentColor: Theme.accent

    // --- Network Data ---
    readonly property bool wifiConnected: (typeof WidgetTelemetry !== "undefined" && WidgetTelemetry.wifiConnected)
        || (root.activeNetType === "wifi" && root.activeNetName.length > 0)
    readonly property bool ethernetConnected: (typeof Net !== "undefined" && Net.wiredDevices && Net.wiredDevices.some(d => d && d.connected))
        || (root.activeNetType === "eth" && root.activeNetName.length > 0)
    readonly property bool isNetConnected: wifiConnected || ethernetConnected
    readonly property real wifiSignalPct: {
        if (typeof WidgetTelemetry !== "undefined" && WidgetTelemetry.wifiSignal >= 0) {
            return WidgetTelemetry.wifiSignal;
        }
        return root.activeNetSignal;
    }
    readonly property string networkGlyph: {
        if (!root.isNetConnected) return "android_cell_5_bar_off";
        if (root.ethernetConnected) return "lan";
        if (root.wifiSignalPct >= 0 && root.wifiSignalPct < 50) return "android_cell_4_bar";
        return "android_cell_5_bar";
    }

    // 1. Clock glance (Matushell textForm: ddd, MMM d • h:mm)
    Row {
        id: clockGlance
        Layout.alignment: Qt.AlignVCenter
        spacing: 5

        Text {
            id: dateLabel
            anchors.baseline: clockFigure.baseline
            text: Qt.formatDate(root.clockDate, "ddd, MMM d")
            color: root.fgPrimary
            font.family: "Google Sans Flex"
            font.pixelSize: 13
            font.weight: Font.Medium
            font.variableAxes: ({ "wght": 500, "wdth": 100 })
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true
        }

        Text {
            anchors.baseline: clockFigure.baseline
            text: "•"
            color: root.fgSecondary
            font.family: "Google Sans Flex"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.variableAxes: ({ "wght": 500, "wdth": 100 })
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true
        }

        IrisClock {
            id: clockFigure
            pixelSize: 13
            family: "Google Sans Flex"
            weight: Font.Medium
            axisWeight: 500
            renderType: Text.QtRendering
            text: {
                const h = root.clockDate.getHours() % 12 || 12;
                const m = root.clockDate.getMinutes();
                return String(h) + ":" + (m < 10 ? "0" : "") + m;
            }
            color: root.fgPrimary
            separatorColor: root.accentColor
            isScreenRecording: root.isScreenRecording
        }
    }

    // 2. Network glance (Matushell IslandNetwork: cell bars / lan)
    Text {
        id: networkIcon
        Layout.alignment: Qt.AlignVCenter
        text: root.networkGlyph
        color: root.isNetConnected ? root.accentColor : Qt.alpha(root.fgPrimary, 0.5)
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 16
        font.hintingPreference: Font.PreferNoHinting
        font.variableAxes: ({
            "FILL": 0,
            "GRAD": Theme.fontIconGrad,
            "opsz": 16,
            "wght": 500
        })
        renderType: Text.CurveRendering
        antialiasing: true
        smooth: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // 3. Material Battery glance (shared capsule + embedded dual-contrast percentage)
    MatusBatteryCapsule {
        Layout.alignment: Qt.AlignVCenter
    }

    // 4. Active Chrono readouts (only shown when a timer/stopwatch is running)
    BarTimeReadouts {
        Layout.alignment: Qt.AlignVCenter
        onOpenRequested: tab => root.timerOpenRequested(tab)
    }
}
