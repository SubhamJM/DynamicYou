import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.UPower
import "../../../"
import "../../../services"
import "../../"
import "../"

// Authentic end-4pc M3 Expressive Resources widget (CPU Gem, RAM Cookie4, Battery/Disk Cookie12)
// Supports Horizontal (1x3) <-> Vertical (3x1) flip + 3rd metric mode (auto / battery / disk)
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "end4Resources"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x3")
    readonly property bool isVertical: sizeMode === "3x1"
    readonly property string thirdMetric: String(opts.thirdMetric || "auto")
    readonly property bool showShadow: opts.showShadow !== false
    readonly property bool resizing: flipMouse.containsMouse || flipMouse.pressed

    onActiveChanged: {
        if (typeof Sys !== "undefined") Sys.hold("end4resources", root.active, 1500);
        if (typeof WidgetTelemetry !== "undefined") WidgetTelemetry.hold("end4resources", root.active);
    }
    Component.onCompleted: {
        if (typeof Sys !== "undefined" && root.active) Sys.hold("end4resources", true, 1500);
        if (typeof WidgetTelemetry !== "undefined" && root.active) WidgetTelemetry.hold("end4resources", true);
    }
    Component.onDestruction: {
        if (typeof Sys !== "undefined") Sys.hold("end4resources", false, 1500);
        if (typeof WidgetTelemetry !== "undefined") WidgetTelemetry.hold("end4resources", false);
    }

    readonly property var bat: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property bool batPresent: !!(bat && bat.ready && bat.isPresent)
    readonly property bool showBattery: thirdMetric === "battery" ? batPresent : (thirdMetric === "disk" ? false : batPresent)

    readonly property string cpuVal: (typeof Sys !== "undefined") ? (Math.round(Sys.cpu * 100) + "%") : "--%"
    readonly property string ramVal: (typeof Sys !== "undefined") ? (Math.round(Sys.ram * 100) + "%") : "--%"
    readonly property string thirdVal: showBattery
        ? (Math.round((bat.percentage || 0) * 100) + "%")
        : ((typeof Sys !== "undefined") ? (Math.round(Sys.disk * 100) + "%") : "--%")

    HoverHandler { id: cardHover }

    component StatCard: Item {
        id: statCard
        property string icon: ""
        property string value: ""
        property string label: ""
        property string shapeName: "cookie12"
        property color bgColor: Theme.m3.primary_container ?? Theme.colors.card_bg
        property color fgColor: Theme.m3.on_primary_container ?? Theme.colors.text_primary
        property color shapeColor: Theme.m3.primary ?? Theme.accent
        property color iconColor: Theme.m3.on_primary ?? "#101014"

        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: WidgetStore.s(26)
            color: statCard.bgColor

            layer.enabled: root.showShadow && root.visible && width > 1 && height > 1
            layer.smooth: true
            layer.textureSize: Qt.size(
                Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)),
                Math.max(1, Math.round(height * 2 * WidgetStore.qtScale))
            )
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.40)
                shadowBlur: 0.65
                shadowVerticalOffset: WidgetStore.s(4)
                autoPaddingEnabled: true
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(14) }
            spacing: -WidgetStore.s(3)

            Item {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: WidgetStore.s(38)
                Layout.preferredHeight: WidgetStore.s(38)

                ExpressiveShape { anchors.fill: parent; shape: statCard.shapeName; color: statCard.shapeColor }
                MaterialSymbol { anchors.centerIn: parent; text: statCard.icon; iconSize: WidgetStore.si(18); fill: 1; color: statCard.iconColor }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: statCard.value
                color: statCard.fgColor
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(28)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: statCard.label
                color: statCard.fgColor
                opacity: 0.65
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(12)
                font.weight: Font.Medium
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
                elide: Text.ElideRight
            }
        }
    }

    GridLayout {
        anchors.fill: parent
        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        columnSpacing: WidgetStore.s(10)
        rowSpacing: WidgetStore.s(10)

        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "memory"
            value: root.cpuVal
            label: "CPU"
            shapeName: "gem"
            bgColor: Theme.m3.primary_container ?? Theme.colors.card_bg
            fgColor: Theme.m3.on_primary_container ?? Theme.colors.text_primary
            shapeColor: Theme.m3.primary ?? Theme.accent
            iconColor: Theme.m3.on_primary ?? "#101014"
        }

        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "memory_alt"
            value: root.ramVal
            label: "RAM"
            shapeName: "cookie4"
            bgColor: Theme.m3.secondary_container ?? Theme.colors.card_bg
            fgColor: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
            shapeColor: Theme.m3.secondary ?? Theme.colors.text_secondary
            iconColor: Theme.m3.on_secondary ?? "#030a16"
        }

        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: root.showBattery ? "battery_full" : "hard_drive"
            value: root.thirdVal
            label: root.showBattery ? "Battery" : "Disk"
            shapeName: "cookie12"
            bgColor: Theme.m3.tertiary_container ?? Theme.colors.card_bg
            fgColor: Theme.m3.on_tertiary_container ?? Theme.colors.text_primary
            shapeColor: Theme.m3.tertiary ?? Theme.accent
            iconColor: Theme.m3.on_tertiary ?? "#101014"
        }
    }

    // end-4pc style WidgetFlipHandle (switches Horizontal 1x3 <-> Vertical 3x1)
    Rectangle {
        visible: root.onDesktop && root.interactive
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: -WidgetStore.s(6)
            bottomMargin: -WidgetStore.s(6)
        }
        width: WidgetStore.s(28)
        height: WidgetStore.s(28)
        radius: width / 2
        color: Theme.m3.primary ?? Theme.accent
        opacity: (cardHover.hovered || flipMouse.containsMouse) ? 0.92 : 0
        z: 30
        Behavior on opacity { NumberAnimation { duration: 140 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.isVertical ? "view_column" : "view_agenda"
            iconSize: WidgetStore.si(15)
            color: Theme.m3.on_primary ?? "#101014"
        }

        MouseArea {
            id: flipMouse
            anchors.fill: parent
            enabled: root.onDesktop && root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: WidgetStore.setCardOption(root.tileId, "sizeMode", root.isVertical ? "1x3" : "3x1")
        }
    }
}
