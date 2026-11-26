import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../../"
import "../../"
import "../"

// Matushell ResourcesWidget ported 1:1 to Dynamic You:
// GPU liquidband.frag.qsb animated wave + Submerged inverse-contrast text layer + Material Shape fill mode
// Styles: "material" | "glass" | "blur" (ditherglass.frag.qsb)
// Fill modes: "wave" | "linear" | "shape"
// Sizes: "1x3" (4 cards strip) | "3x1" (vertical column) | "2x2" / "2x3" (grid)
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "resources"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x3")
    readonly property string cardStyle: {
        const s = String(opts.styleMode || "material");
        return (s === "glass" || s === "blur") ? s : "material";
    }
    readonly property string fillMode: String(opts.fillMode || "wave")       // "wave" | "linear" | "shape"
    readonly property bool showBattery: opts.showBattery === true

    readonly property bool isWaveMode: fillMode === "wave"
    readonly property bool isShapeMode: fillMode === "shape"
    readonly property bool isGlass: cardStyle === "glass"
    readonly property bool isMaterial: cardStyle === "material"

    onActiveChanged: {
        if (typeof Sys !== "undefined") Sys.hold("resources", root.active, 1500);
        if (typeof WidgetTelemetry !== "undefined") WidgetTelemetry.hold("resources", root.active);
    }
    Component.onCompleted: {
        if (typeof Sys !== "undefined" && root.active) Sys.hold("resources", true, 1500);
        if (typeof WidgetTelemetry !== "undefined" && root.active) WidgetTelemetry.hold("resources", true);
    }
    Component.onDestruction: {
        if (typeof Sys !== "undefined") Sys.hold("resources", false, 1500);
        if (typeof WidgetTelemetry !== "undefined") WidgetTelemetry.hold("resources", false);
    }

    property real phase: 0
    FrameAnimation {
        running: root.active && root.isWaveMode
        onTriggered: root.phase += 0.04 * frameTime * 60
    }

    readonly property bool hasSys: typeof Sys !== "undefined"
    readonly property real cpuPct: hasSys ? Math.max(0, Math.min(100, (Sys.cpu || 0) * 100)) : 0
    readonly property real ramPct: hasSys ? Math.max(0, Math.min(100, (Sys.ram || 0) * 100)) : 0
    readonly property real diskPct: hasSys ? Math.max(0, Math.min(100, (Sys.disk || 0) * 100)) : 0

    readonly property bool hasGpu: (typeof WidgetTelemetry !== "undefined") && WidgetTelemetry.hasGpu
    readonly property real gpuPct: hasGpu && WidgetTelemetry.gpuPercent >= 0 ? Math.max(0, Math.min(100, WidgetTelemetry.gpuPercent)) : 0

    readonly property var batDev: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property real batPct: (batDev && batDev.ready) ? Math.max(0, Math.min(100, (batDev.percentage || 0) * 100)) : 100

    readonly property string cpuHeader: (hasSys && Sys.temp > 0) ? (Math.round(Sys.temp) + "°C") : "CPU"
    readonly property string cpuSub: {
        if (!hasSys) return "Processor";
        return Sys.cpuMhz > 0 ? ((Sys.cpuMhz / 1000).toFixed(1) + " GHz") : "Processor";
    }

    readonly property string ramHeader: hasSys && Sys.ramUsedGb > 0 ? (Sys.ramUsedGb.toFixed(1) + "G") : "MEM"
    readonly property string ramSub: hasSys && Sys.ramTotalGb > 0
        ? (Sys.ramUsedGb.toFixed(1) + " / " + Math.round(Sys.ramTotalGb) + " GB")
        : "Memory"

    readonly property string gpuHeader: (hasGpu && WidgetTelemetry.gpuTemp > 0) ? (Math.round(WidgetTelemetry.gpuTemp) + "°") : (hasGpu ? "GPU" : "N/A")
    readonly property string gpuSub: hasGpu
        ? String(WidgetTelemetry.gpuName || "Graphics").replace(/^(NVIDIA\s+GeForce|NVIDIA|AMD\s+Radeon|AMD|Intel(\(R\))?)\s+/i, "")
        : "Integrated"

    readonly property string diskHeader: hasSys && Sys.diskTotalGb > 0
        ? (Sys.diskTotalGb >= 900 ? (Sys.diskTotalGb / 1024).toFixed(1) + "T" : Math.round(Sys.diskTotalGb) + "G")
        : "DISK"
    readonly property string diskSub: hasSys && Sys.diskTotalGb > 0
        ? (Math.round(Sys.diskUsedGb) + " / " + Math.round(Sys.diskTotalGb) + " GB")
        : "Storage"

    readonly property var cardItems: {
        const list = [
            {
                title: "CPU", header: root.cpuHeader, sub: root.cpuSub, icon: "memory",
                shape: "gem", pct: root.cpuPct, warn: root.cpuPct >= 90 || (hasSys && Sys.temp >= 85),
                accent: Theme.m3.primary ?? Theme.accent,
                accentOn: Theme.m3.on_primary ?? "#101014",
                container: Theme.m3.primary_container ?? Theme.colors.card_bg,
                containerOn: Theme.m3.on_primary_container ?? Theme.colors.text_primary
            },
            {
                title: "RAM", header: root.ramHeader, sub: root.ramSub, icon: "memory_alt",
                shape: "cookie4", pct: root.ramPct, warn: root.ramPct >= 90,
                accent: Theme.m3.secondary ?? "#67e8f9",
                accentOn: Theme.m3.on_secondary ?? "#030a16",
                container: Theme.m3.secondary_container ?? Theme.colors.card_bg,
                containerOn: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
            },
            {
                title: "GPU", header: root.gpuHeader, sub: root.gpuSub, icon: "developer_board",
                shape: "pentagon", pct: root.gpuPct, warn: root.gpuPct >= 92,
                accent: Theme.m3.tertiary ?? "#f472b6",
                accentOn: Theme.m3.on_tertiary ?? "#101014",
                container: Theme.m3.tertiary_container ?? Theme.colors.card_bg,
                containerOn: Theme.m3.on_tertiary_container ?? Theme.colors.text_primary
            },
            {
                title: "Disk", header: root.diskHeader, sub: root.diskSub, icon: "storage",
                shape: "cookie6", pct: root.diskPct, warn: root.diskPct >= 92,
                accent: Theme.m3.tertiary ?? "#fbbf24",
                accentOn: Theme.m3.on_tertiary ?? "#101014",
                container: Theme.m3.surface_container_high ?? Theme.colors.card_bg,
                containerOn: Theme.m3.on_surface ?? Theme.colors.text_primary
            }
        ];
        if (root.showBattery) {
            list.push({
                title: "Battery", header: Math.round(root.batPct) + "%", sub: "Power", icon: "battery_full",
                shape: "pill", pct: root.batPct, warn: root.batPct <= 15,
                accent: Theme.m3.primary ?? Theme.accent,
                accentOn: Theme.m3.on_primary ?? "#101014",
                container: Theme.m3.primary_container ?? Theme.colors.card_bg,
                containerOn: Theme.m3.on_primary_container ?? Theme.colors.text_primary
            });
        }
        return list;
    }

    readonly property int gridCols: root.sizeMode === "3x1" ? 1 : ((root.sizeMode === "2x2" || root.sizeMode === "2x3") ? 2 : cardItems.length)
    readonly property int gridRows: Math.ceil(cardItems.length / Math.max(1, gridCols))

    GridLayout {
        anchors.fill: parent
        columns: root.gridCols
        rows: root.gridRows
        columnSpacing: WidgetStore.s(10)
        rowSpacing: WidgetStore.s(10)

        Repeater {
            model: root.cardItems

            delegate: Item {
                id: card
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real targetFill: Math.max(0.05, Math.min(0.98, Number(modelData.pct || 0) / 100.0))
                property real fillLevel: targetFill
                Behavior on fillLevel { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                readonly property real cornerRad: WidgetStore.s(24)
                readonly property color waveColor: modelData.warn ? (Theme.m3.error ?? "#ffb4ab") : modelData.accent
                readonly property color onWaveColor: modelData.warn ? (Theme.m3.on_error ?? "#101014") : modelData.accentOn
                readonly property color cardContainer: modelData.warn ? (Theme.m3.error_container ?? "#7f1d1d") : modelData.container
                readonly property color dryInk: root.isMaterial
                    ? (modelData.warn ? (Theme.m3.on_error_container ?? "#ffdada") : modelData.containerOn)
                    : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                readonly property color dryBadgeBg: root.isMaterial ? waveColor : Qt.alpha(waveColor, 0.22)
                readonly property color dryBadgeFg: root.isMaterial ? onWaveColor : waveColor

                // Backdrop: Material / Glass / Blur
                MatusBackdrop {
                    anchors.fill: parent
                    style: root.cardStyle
                    cornerRadius: card.cornerRad
                    materialColor: card.cardContainer
                }

                // Shape Fill Mode: Morphing bottom-left ExpressiveShape blob
                Item {
                    visible: root.isShapeMode
                    anchors.fill: parent
                    clip: true

                    ExpressiveShape {
                        width: Math.round(WidgetStore.s(64) + WidgetStore.s(84) * card.fillLevel)
                        height: width
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: -WidgetStore.s(18)
                        anchors.bottomMargin: -WidgetStore.s(18)
                        shape: card.modelData.shape
                        color: Qt.alpha(card.waveColor, 0.24 + 0.44 * card.fillLevel)
                    }
                }

                // Wave & Linear Fill Mode: Matushell liquidband.frag.qsb ShaderEffect
                ShaderEffect {
                    visible: !root.isShapeMode
                    anchors.fill: parent
                    blending: true

                    property real itemWidth: Math.max(1, width)
                    property real itemHeight: Math.max(1, height)
                    property real fill: card.fillLevel
                    property real phase: root.phase
                    property real amplitude: root.isWaveMode ? WidgetStore.s(3.8) : 0.0
                    property real cornerRadius: card.cornerRad
                    property color colorWave: card.waveColor

                    fragmentShader: Qt.resolvedUrl("shaders/liquidband.frag.qsb")
                }

                // Reusable inner typography tree (instantiated twice: dry top layer + submerged inverse clip layer)
                component CardInnerContent: Item {
                    property color textColor: card.dryInk
                    property color badgeBg: card.dryBadgeBg
                    property color badgeFg: card.dryBadgeFg
                    property real subOpacity: 0.72

                    anchors.fill: parent
                    anchors.margins: WidgetStore.s(12)

                    RowLayout {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: WidgetStore.s(5)

                        Item {
                            id: iconBadge
                            Layout.preferredWidth: WidgetStore.s(24)
                            Layout.preferredHeight: WidgetStore.s(24)

                            ExpressiveShape {
                                anchors.fill: parent
                                shape: card.modelData.shape
                                color: parent.parent.parent.badgeBg
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: card.modelData.icon
                                iconSize: WidgetStore.si(13)
                                fill: 1
                                color: parent.parent.parent.badgeFg
                            }
                        }

                        Text {
                            text: card.modelData.title
                            color: parent.parent.textColor
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(11)
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: card.modelData.header
                            color: parent.parent.textColor
                            opacity: 0.78
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(9.5)
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: subLine.top
                        anchors.bottomMargin: WidgetStore.s(1)
                        text: Math.round(card.modelData.pct) + "%"
                        color: parent.textColor
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(root.gridCols >= 4 ? 22 : 26)
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        id: subLine
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: card.modelData.sub
                        color: parent.textColor
                        opacity: parent.subOpacity
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(9.5)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                // Dry top layer
                CardInnerContent {
                    textColor: card.dryInk
                    badgeBg: card.dryBadgeBg
                    badgeFg: card.dryBadgeFg
                    subOpacity: 0.68
                }

                // Submerged inverse-contrast clip layer matched cleanly to Matushell
                Item {
                    id: liquidClip
                    visible: !root.isShapeMode
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    height: Math.round(card.height * card.fillLevel)

                    Item {
                        y: liquidClip.height - card.height
                        width: card.width
                        height: card.height

                        CardInnerContent {
                            textColor: card.onWaveColor
                            badgeBg: Qt.alpha(card.onWaveColor, 0.24)
                            badgeFg: card.onWaveColor
                            subOpacity: 0.85
                        }
                    }
                }
            }
        }
    }
}
