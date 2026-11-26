import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../"
import "../../"
import "../"

// Nothing OS Glyph CPU & RAM Dot-Ring + 34x8 Dot-Matrix Sparkline Bento Card
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "nothingResources"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x2")
    readonly property string singleMetric: String(opts.singleMetric || "cpu") // "cpu" | "ram"
    readonly property string accentMode: String(opts.accentMode || "glyph")
    readonly property bool showShadow: opts.showShadow !== false

    NothingGlyphTokens {
        id: tok
        accentMode: root.accentMode
    }

    onActiveChanged: {
        if (typeof Sys !== "undefined") Sys.hold("nothingResourcesCard", root.active, 1500);
    }
    Component.onCompleted: {
        if (typeof Sys !== "undefined") Sys.hold("nothingResourcesCard", root.active, 1500);
    }
    Component.onDestruction: {
        if (typeof Sys !== "undefined") Sys.hold("nothingResourcesCard", false);
    }

    readonly property real cpuFrac: (typeof Sys !== "undefined") ? Math.max(0, Math.min(1, Number(Sys.cpu) || 0)) : 0
    readonly property real ramFrac: (typeof Sys !== "undefined") ? Math.max(0, Math.min(1, Number(Sys.ram) || 0)) : 0
    readonly property int cpuPct: Math.round(cpuFrac * 100)
    readonly property int ramPct: Math.round(ramFrac * 100)
    readonly property int cpuTemp: (typeof Sys !== "undefined" && Sys.temp > 0) ? Math.round(Sys.temp) : -1
    readonly property string ramDetail: (typeof Sys !== "undefined" && Sys.ramTotalGb > 0)
        ? (Sys.ramUsedGb.toFixed(1) + "/" + Sys.ramTotalGb.toFixed(0) + "G")
        : "MEM"
    readonly property int gpuPct: (typeof WidgetTelemetry !== "undefined" && WidgetTelemetry.hasGpu && WidgetTelemetry.gpuPercent >= 0)
        ? Math.round(WidgetTelemetry.gpuPercent)
        : ((typeof Sys !== "undefined" && Sys.gpu >= 0) ? Math.round(Sys.gpu * 100) : -1)
    readonly property int diskPct: (typeof Sys !== "undefined") ? Math.round((Number(Sys.disk) || 0) * 100) : 0

    readonly property var cpuHistory: (typeof Sys !== "undefined" && Array.isArray(Sys.cpuHistory)) ? Sys.cpuHistory : []
    readonly property int sparkCols: isTall ? 28 : 22
    readonly property var sparkValues: {
        const h = cpuHistory;
        const n = sparkCols;
        const out = [];
        const pad = Math.max(0, n - h.length);
        for (let i = 0; i < pad; i++) out.push(0);
        for (let j = Math.max(0, h.length - n); j < h.length; j++) out.push(Math.max(0, Math.min(1, Number(h[j]) || 0)));
        return out;
    }

    readonly property bool isOne: sizeMode === "1x1"
    readonly property bool isDual: sizeMode === "1x2"
    readonly property bool isWide: sizeMode === "1x3"
    readonly property bool isTall: sizeMode === "2x2"

    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: tok.s1
        border.width: Math.max(1, WidgetStore.s(1))
        border.color: tok.border

        layer.enabled: root.onDesktop && root.showShadow && root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * WidgetStore.qtScale))
        )
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.7
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
    }

    // Reusable single ring tile
    component MetricDotRing: Item {
        property string label: "CPU"
        property string subLabel: ""
        property real frac: 0
        property int pct: 0
        property color ringColor: tok.fg
        property real ringSize: WidgetStore.s(110)

        Item {
            anchors.centerIn: parent
            width: ringSize
            height: ringSize

            NothingDotRing {
                anchors.fill: parent
                n: 30
                f: frac
                dot: WidgetStore.s(ringSize >= WidgetStore.s(100) ? 4.4 : 3.8)
                onColor: pct >= 85 ? tok.alertRed : ringColor
                offColor: tok.s3
            }

            Column {
                anchors.centerIn: parent
                spacing: WidgetStore.s(1)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pct + "%"
                    color: pct >= 85 ? tok.alertRed : tok.fg
                    font.family: tok.dotFont
                    font.pixelSize: WidgetStore.si(ringSize >= WidgetStore.s(100) ? 26 : 22)
                    font.weight: Font.Black
                    font.variableAxes: ({ "ROND": 100, "wght": 900 })
                    topPadding: -0.14 * font.pixelSize
                    bottomPadding: -0.14 * font.pixelSize
                    renderType: Text.QtRendering
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: label
                    color: tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(8.5)
                    font.letterSpacing: 1.0
                    renderType: Text.NativeRendering
                }

                Text {
                    visible: subLabel !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: subLabel
                    color: tok.mute
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(7.5)
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // 1x1 Single Ring Mode (click switches between CPU & RAM)
    Item {
        visible: root.isOne
        anchors.fill: parent

        readonly property bool showRam: root.singleMetric === "ram"

        MetricDotRing {
            anchors.centerIn: parent
            width: parent.width - WidgetStore.s(18)
            height: parent.height - WidgetStore.s(18)
            ringSize: WidgetStore.s(120)
            label: parent.showRam ? "RAM %" : "CPU %"
            subLabel: parent.showRam ? root.ramDetail : (root.cpuTemp > 0 ? (root.cpuTemp + "°C") : "")
            frac: parent.showRam ? root.ramFrac : root.cpuFrac
            pct: parent.showRam ? root.ramPct : root.cpuPct
            ringColor: parent.showRam ? tok.accent : tok.fg
        }

        MouseArea {
            enabled: root.interactive
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: WidgetStore.setCardOption(root.tileId, "singleMetric", root.singleMetric === "cpu" ? "ram" : "cpu")
        }
    }

    // 1x2 Dual Ring Mode: Side-by-side CPU & RAM rings
    RowLayout {
        visible: root.isDual
        anchors {
            fill: parent
            margins: WidgetStore.s(14)
        }
        spacing: WidgetStore.s(10)

        MetricDotRing {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ringSize: WidgetStore.s(118)
            label: "CPU"
            subLabel: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : ""
            frac: root.cpuFrac
            pct: root.cpuPct
            ringColor: tok.fg
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: WidgetStore.s(84)
            color: tok.s3
        }

        MetricDotRing {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ringSize: WidgetStore.s(118)
            label: "RAM"
            subLabel: root.ramDetail
            frac: root.ramFrac
            pct: root.ramPct
            ringColor: tok.accent
        }
    }

    // 1x3 Wide Bento: Twin rings left + 22x8 Dot-Matrix Sparkline & Stats right
    RowLayout {
        visible: root.isWide
        anchors {
            fill: parent
            margins: WidgetStore.s(14)
        }
        spacing: WidgetStore.s(14)

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: WidgetStore.s(10)

            MetricDotRing {
                width: WidgetStore.s(112)
                height: WidgetStore.s(112)
                ringSize: WidgetStore.s(108)
                label: "CPU"
                subLabel: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : ""
                frac: root.cpuFrac
                pct: root.cpuPct
                ringColor: tok.fg
            }

            MetricDotRing {
                width: WidgetStore.s(112)
                height: WidgetStore.s(112)
                ringSize: WidgetStore.s(108)
                label: "RAM"
                subLabel: root.ramDetail
                frac: root.ramFrac
                pct: root.ramPct
                ringColor: tok.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: WidgetStore.s(6)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "CPU · 60S"
                    color: tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(9)
                    font.letterSpacing: 1.0
                    renderType: Text.NativeRendering
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.gpuPct >= 0 ? ("GPU " + root.gpuPct + "%") : ("DISK " + root.diskPct + "%")
                    color: tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(9)
                    renderType: Text.NativeRendering
                }
            }

            // 22x8 Dot-Matrix Sparkline Grid
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Row {
                    anchors.centerIn: parent
                    spacing: WidgetStore.s(3.5)

                    Repeater {
                        model: root.sparkValues
                        Column {
                            required property real modelData
                            readonly property int litRows: Math.round(modelData * 7)
                            spacing: WidgetStore.s(3.5)

                            Repeater {
                                model: 7
                                Rectangle {
                                    required property int index
                                    readonly property int rowFromBottom: 6 - index
                                    readonly property bool isLit: rowFromBottom < litRows || (rowFromBottom === 0 && litRows === 0)
                                    width: WidgetStore.s(5.5)
                                    height: WidgetStore.s(5.5)
                                    radius: width / 2
                                    color: isLit
                                        ? (rowFromBottom >= 6 ? tok.accent : tok.fg)
                                        : tok.s3
                                }
                            }
                        }
                    }
                }
            }

            // Bottom GPU + Disk strip
            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(8)
                Text {
                    text: "MEM " + root.ramDetail
                    color: tok.mute
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(8.5)
                    renderType: Text.NativeRendering
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "DISK " + root.diskPct + "%"
                    color: tok.mute
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(8.5)
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // 2x2 Tall Full System Bento (matching Home.qml systemW + rings)
    ColumnLayout {
        visible: root.isTall
        anchors {
            fill: parent
            margins: WidgetStore.s(16)
        }
        spacing: WidgetStore.s(12)

        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(10)

            MetricDotRing {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(118)
                ringSize: WidgetStore.s(112)
                label: "CPU"
                subLabel: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : ""
                frac: root.cpuFrac
                pct: root.cpuPct
                ringColor: tok.fg
            }

            MetricDotRing {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(118)
                ringSize: WidgetStore.s(112)
                label: "RAM"
                subLabel: root.ramDetail
                frac: root.ramFrac
                pct: root.ramPct
                ringColor: tok.accent
            }
        }

        // Secondary 3-stat strip
        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(8)

            Repeater {
                model: [
                    { k: "GPU", v: root.gpuPct >= 0 ? (root.gpuPct + "%") : "IDLE" },
                    { k: "DISK", v: root.diskPct + "%" },
                    { k: "TEMP", v: root.cpuTemp > 0 ? (root.cpuTemp + "°") : "--" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: WidgetStore.s(42)
                    radius: WidgetStore.s(12)
                    color: tok.s2

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.v
                            color: tok.fg
                            font.family: tok.dotFont
                            font.pixelSize: WidgetStore.si(16)
                            font.weight: Font.Black
                            font.variableAxes: ({ "ROND": 100, "wght": 900 })
                            renderType: Text.QtRendering
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.k
                            color: tok.grey
                            font.family: tok.monoFont
                            font.pixelSize: WidgetStore.si(8)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        // Bottom 28x8 CPU Dot-Matrix Sparkline
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: WidgetStore.s(4)

            Text {
                text: "CPU HISTORY · LIVE"
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(8.5)
                font.letterSpacing: 1.0
                renderType: Text.NativeRendering
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Row {
                    anchors.centerIn: parent
                    spacing: WidgetStore.s(4)

                    Repeater {
                        model: root.sparkValues
                        Column {
                            required property real modelData
                            readonly property int litRows: Math.round(modelData * 8)
                            spacing: WidgetStore.s(3.5)

                            Repeater {
                                model: 8
                                Rectangle {
                                    required property int index
                                    readonly property int rowFromBottom: 7 - index
                                    readonly property bool isLit: rowFromBottom < litRows || (rowFromBottom === 0 && litRows === 0)
                                    width: WidgetStore.s(5.5)
                                    height: WidgetStore.s(5.5)
                                    radius: width / 2
                                    color: isLit
                                        ? (rowFromBottom >= 6 ? tok.accent : tok.fg)
                                        : tok.s3
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
