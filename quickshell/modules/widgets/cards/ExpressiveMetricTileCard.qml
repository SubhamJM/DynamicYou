import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../../"
import "../../"

Rectangle {
    id: root

    property string label: ""
    property string iconName: "monitoring"
    property string valueText: "—"
    property string supportingText: ""
    property string detailText: ""
    property string temperatureText: ""
    property real usage: -1
    property string shapeOverride: ""
    property var trendValues: []
    property bool chartActive: visible
    property int updateInterval: 1500
    property real decorationSize: 56
    property color containerColor: Theme.m3.primary_container ?? Theme.colors.card_bg
    property color foregroundColor: Theme.m3.on_primary_container ?? Theme.colors.text_primary
    property color accentColor: Theme.m3.primary ?? Theme.accent
    property color accentForegroundColor: Theme.m3.on_primary ?? "#101014"

    readonly property real normUsage: Math.max(0, Math.min(1, root.usage))
    readonly property string resolvedShape: {
        if (root.shapeOverride !== "") return root.shapeOverride;
        if (root.normUsage >= 0.80) return "softBurst";
        if (root.normUsage >= 0.45) return "sunny";
        return "cookie4";
    }

    radius: 24
    color: root.containerColor

    Behavior on color { ColorAnimation { duration: 180 } }

    // Clipped background layer ONLY for the peeking bottom-right shape (keeps text/icons native sharp)
    Item {
        id: shapeMaskSource
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "white"
        }
    }

    Item {
        anchors.fill: parent
        z: 1
        layer.enabled: root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
        layer.effect: OpacityMask { maskSource: shapeMaskSource }

        ExpressiveShape {
            id: metricShape
            width: Math.min(root.width * 0.36, root.height * 0.44, root.decorationSize * (1.0 + root.normUsage * 0.14))
            height: width
            shape: root.resolvedShape
            color: root.accentColor
            rotation: 18
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: -width * 0.16
                bottomMargin: -height * 0.18
            }

            Behavior on width {
                NumberAnimation { duration: 400; easing.type: Easing.OutBack }
            }
        }
    }

    MaterialSymbol {
        z: 4
        anchors.centerIn: badgeAnchor
        rotation: 0
        text: root.iconName
        color: root.accentForegroundColor
        iconSize: 22
        fill: 1
    }

    Item {
        id: badgeAnchor
        readonly property real sz: Math.min(root.width * 0.36, root.height * 0.44, root.decorationSize * (1.0 + root.normUsage * 0.14))
        width: sz
        height: sz
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: -sz * 0.16
            bottomMargin: -sz * 0.18
        }
    }

    // Top-right thermostat pill
    Row {
        id: tempBadge
        visible: root.temperatureText.length > 0
        spacing: 2
        z: 5
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 12
            rightMargin: 14
        }

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: "thermostat"
            color: root.foregroundColor
            iconSize: 15
            fill: 1
            opacity: 0.80
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temperatureText
            color: root.foregroundColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            opacity: 0.88
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 14
            topMargin: 12
            bottomMargin: 12
        }
        spacing: 2

        Text {
            Layout.maximumWidth: Math.max(48, root.width - tempBadge.width - 36)
            text: root.label
            color: root.foregroundColor
            font.family: "Google Sans Flex"
            font.pixelSize: 19
            font.weight: Font.Bold
            elide: Text.ElideRight
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }

        Text {
            Layout.maximumWidth: Math.max(48, root.width - root.decorationSize - 24)
            visible: text.length > 0
            text: root.detailText
            color: root.foregroundColor
            opacity: 0.72
            font.family: "Noto Sans"
            font.pixelSize: 11
            elide: Text.ElideRight
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }

        SparklineCanvas {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: visible ? 38 : 0
            visible: root.trendValues.length > 1
            values: root.trendValues
            historyLength: 60
            updateInterval: root.updateInterval
            maximum: 1.0
            active: root.chartActive
            lineColor: root.accentColor
            baselineColor: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.18)
            lineWidth: 2.2
            fillOpacity: 0.15
        }

        Item {
            Layout.fillHeight: true
            visible: root.trendValues.length <= 1
        }

        Text {
            Layout.fillWidth: true
            Layout.rightMargin: root.decorationSize * 0.45
            text: root.valueText
            color: root.foregroundColor
            font.family: "Google Sans Flex"
            font.pixelSize: 28
            font.weight: Font.Bold
            elide: Text.ElideRight
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }

        Text {
            Layout.fillWidth: true
            Layout.rightMargin: root.decorationSize * 0.55
            visible: text.length > 0
            text: root.supportingText
            color: root.foregroundColor
            opacity: 0.74
            font.family: "Noto Sans"
            font.pixelSize: 11
            elide: Text.ElideRight
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }
    }
}
