import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"
import "../../"
import "../"

Item {
    id: root

    property bool active: true
    readonly property var opts: WidgetStore.cardOptions("resources")
    readonly property bool showLoadBadge: opts.showLoadBadge !== false
    readonly property bool showDetail: opts.showDetail !== false
    readonly property bool compactDetail: opts.compactDetail === true

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

    readonly property bool hasCpu: typeof Sys !== "undefined"
    readonly property bool hasTelemetry: typeof WidgetTelemetry !== "undefined"

    readonly property real cpuLevel: hasCpu ? Math.max(0, Math.min(1, Sys.cpu)) : 0
    readonly property string cpuPctText: hasCpu ? Math.round(cpuLevel * 100) + "%" : "—"
    readonly property string cpuDetail: {
        if (!hasCpu) return "Unavailable";
        const ghz = Sys.cpuMhz > 0 ? (Sys.cpuMhz / 1000).toFixed(1) + " GHz" : "Active";
        if (Sys.temp > 0) return Math.round(Sys.temp) + "°C · " + ghz;
        return ghz;
    }

    readonly property bool hasGpu: hasTelemetry && WidgetTelemetry.hasGpu
    readonly property real gpuPct: hasGpu && WidgetTelemetry.gpuPercent >= 0 ? WidgetTelemetry.gpuPercent : -1
    readonly property string gpuPctText: gpuPct >= 0 ? Math.round(gpuPct) + "%" : "—"
    readonly property string gpuDetail: {
        if (!hasGpu) return "No discrete GPU";
        if (WidgetTelemetry.gpuVramTotalMb > 0 && WidgetTelemetry.gpuVramUsedMb >= 0) {
            const usedGb = (WidgetTelemetry.gpuVramUsedMb / 1024).toFixed(1);
            const totalGb = Math.round(WidgetTelemetry.gpuVramTotalMb / 1024);
            const tempStr = WidgetTelemetry.gpuTemp > 0 ? (Math.round(WidgetTelemetry.gpuTemp) + "°C · ") : "";
            return tempStr + usedGb + "/" + totalGb + "G";
        }
        return String(WidgetTelemetry.gpuName || "GPU").replace(/^(NVIDIA|AMD|Intel)\s+/i, "");
    }

    readonly property real ramLevel: hasCpu ? Math.max(0, Math.min(1, Sys.ram)) : 0
    readonly property string ramPctText: hasCpu ? Math.round(ramLevel * 100) + "%" : "—"
    readonly property string ramDetail: hasCpu && Sys.ramTotalGb > 0
        ? Sys.ramUsedGb.toFixed(1) + " / " + Sys.ramTotalGb.toFixed(0) + " GB"
        : "—"

    readonly property real diskLevel: hasCpu ? Math.max(0, Math.min(1, Sys.disk)) : 0
    readonly property string diskPctText: hasCpu ? Math.round(diskLevel * 100) + "%" : "—"
    readonly property string diskDetail: hasCpu && Sys.diskTotalGb > 0
        ? Math.round(Sys.diskUsedGb) + " / " + Math.round(Sys.diskTotalGb) + " GB"
        : "—"

    readonly property string loadText: hasCpu && Sys.load1 >= 0
        ? "LOAD " + Number(Sys.load1).toFixed(2)
        : "LIVE"

    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"
    readonly property color fg: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color muted: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary

    SekaiPill {
        anchors.fill: parent
        cornerRadius: WidgetStore.s(22)
        borderWidth: WidgetStore.s(2.5)
        ringWidth: WidgetStore.s(3)
        shadowDx: WidgetStore.s(3)
        shadowDy: WidgetStore.s(4)
        fillColor: Theme.m3.surface_container ?? Theme.colors.card_bg
        ringColor: Qt.alpha(root.accent, 0.24)

        // Subtle Sekai backdrop circle
        Rectangle {
            width: WidgetStore.s(220)
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -WidgetStore.s(50)
            anchors.bottomMargin: -WidgetStore.s(50)
            color: Qt.alpha(root.accent, 0.08)
        }

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: WidgetStore.s(12)
                rightMargin: WidgetStore.s(12)
                topMargin: WidgetStore.s(11)
                bottomMargin: WidgetStore.s(12)
            }
            spacing: WidgetStore.s(9)

            // Top bar: tilted RESOURCES badge + LOAD pill
            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(8)

                SekaiPill {
                    Layout.preferredWidth: resBadgeRow.implicitWidth + WidgetStore.s(18)
                    Layout.preferredHeight: WidgetStore.s(24)
                    cornerRadius: WidgetStore.s(8)
                    borderWidth: WidgetStore.s(2)
                    ringWidth: WidgetStore.s(1.5)
                    shadowDy: WidgetStore.s(2)
                    rotation: -1.5
                    fillColor: root.accent

                    Row {
                        id: resBadgeRow
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(5)

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "monitoring"
                            iconSize: WidgetStore.si(13)
                            fill: 1
                            color: root.onAccent
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "RESOURCES"
                            color: root.onAccent
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(10)
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 0.8
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                SekaiPill {
                    visible: root.showLoadBadge
                    Layout.preferredWidth: loadRow.implicitWidth + WidgetStore.s(16)
                    Layout.preferredHeight: WidgetStore.s(22)
                    cornerRadius: WidgetStore.s(8)
                    borderWidth: WidgetStore.s(1.8)
                    ringWidth: WidgetStore.s(1.5)
                    shadowDy: WidgetStore.s(2)
                    fillColor: Theme.m3.surface_container_highest ?? Theme.colors.card_bg
                    ringColor: Qt.alpha(root.accent, 0.22)

                    Row {
                        id: loadRow
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(5)

                        Rectangle {
                            width: WidgetStore.s(6)
                            height: width
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.m3.secondary ?? "#4ade80"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.loadText
                            color: root.fg
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(9)
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 0.7
                            font.features: { "tnum": 1 }
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // 2x2 Grid of Sekai ResourceMeters
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rows: 2
                columnSpacing: WidgetStore.s(9)
                rowSpacing: WidgetStore.s(9)

                ResourceMeter {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "CPU"
                    detail: root.showDetail ? root.cpuDetail : ""
                    valueText: root.cpuPctText
                    level: root.cpuLevel
                    iconName: "memory"
                    accentColor: Theme.m3.primary ?? Theme.accent
                    textColor: root.fg
                    mutedColor: root.muted
                }

                ResourceMeter {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "GPU"
                    detail: root.showDetail ? (root.compactDetail ? String(WidgetTelemetry.gpuName || "GPU").replace(/^(NVIDIA|AMD|Intel)\s+/i, "") : root.gpuDetail) : ""
                    valueText: root.gpuPctText
                    level: root.gpuPct >= 0 ? root.gpuPct / 100.0 : 0
                    iconName: "developer_board"
                    accentColor: Theme.m3.tertiary ?? "#ff9e7d"
                    textColor: root.fg
                    mutedColor: root.muted
                }

                ResourceMeter {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "RAM"
                    detail: root.showDetail ? root.ramDetail : ""
                    valueText: root.ramPctText
                    level: root.ramLevel
                    iconName: "memory_alt"
                    accentColor: Theme.m3.secondary ?? "#67e8f9"
                    textColor: root.fg
                    mutedColor: root.muted
                }

                ResourceMeter {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "DISK"
                    detail: root.showDetail ? root.diskDetail : ""
                    valueText: root.diskPctText
                    level: root.diskLevel
                    iconName: "hard_drive"
                    accentColor: Theme.m3.primary_fixed_dim ?? "#84b9ff"
                    textColor: root.fg
                    mutedColor: root.muted
                }
            }
        }
    }
}
