import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import "../../../"
import "../../"
import "../"

Item {
    id: root

    required property string iconName
    required property string valueText
    required property string supportingText
    required property real level
    property bool valueAvailable: true
    property bool active: true
    property color shapeColor: Theme.m3.primary_container ?? Theme.colors.card_bg
    property color liquidColor: Qt.rgba(0, 0.89, 1.0, 0.52)
    property color contentColor: Theme.m3.on_primary_container ?? Theme.colors.text_primary

    readonly property real targetLevel: root.valueAvailable ? Math.max(0, Math.min(1, root.level)) : 0
    property real animatedLevel: targetLevel
    readonly property real waveAmplitude: Math.min(WidgetStore.s(9), height * 0.06)
        * Math.max(0, Math.min(1, animatedLevel / 0.08, (1 - animatedLevel) / 0.08))

    Behavior on animatedLevel {
        NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.39, 1.29, 0.35, 0.98, 1, 1] }
    }

    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: root.shapeColor
    }

    Rectangle {
        id: vesselMask
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)), Math.max(1, Math.round(height * 2 * WidgetStore.qtScale)))
    }

    Item {
        anchors.fill: parent
        layer.enabled: root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)), Math.max(1, Math.round(height * 2 * WidgetStore.qtScale)))
        layer.effect: OpacityMask { maskSource: vesselMask }

        OceanWave {
            y: root.height * (1 - root.animatedLevel) - amplitude
            wavelength: Math.max(1, root.width * 1.65)
            amplitude: root.waveAmplitude
            fillDepth: root.height + amplitude * 2
            waveColor: root.liquidColor
            opacity: 0.45
            phaseOffset: 0.35
            cycleDuration: 9500
            reverse: true
            flowing: root.active && root.visible && root.valueAvailable
            visible: root.animatedLevel > 0
        }

        OceanWave {
            y: root.height * (1 - root.animatedLevel) - amplitude
            wavelength: Math.max(1, root.width * 1.35)
            amplitude: root.waveAmplitude * 0.72
            fillDepth: root.height + amplitude * 2
            waveColor: root.liquidColor
            cycleDuration: 5800
            flowing: root.active && root.visible && root.valueAvailable
            visible: root.animatedLevel > 0
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: WidgetStore.s(10) }
        spacing: -WidgetStore.s(2)

        Item { Layout.fillHeight: true }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: root.iconName
            color: root.contentColor
            iconSize: WidgetStore.si(28)
            fill: 1
        }

        Text {
            Layout.fillWidth: true
            text: root.valueText
            color: root.contentColor
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(28)
            font.weight: Font.DemiBold
            font.variableAxes: ({ "ROND": 25, "wdth": 65 })
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }

        Text {
            Layout.fillWidth: true
            text: root.supportingText
            color: root.contentColor
            opacity: 0.86
            font.family: "Noto Sans"
            font.pixelSize: WidgetStore.si(11)
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }

        Item { Layout.fillHeight: true }
    }

    component OceanWave: Shape {
        id: wave
        required property real wavelength
        required property real amplitude
        required property real fillDepth
        required property color waveColor
        required property int cycleDuration
        property bool flowing: true
        property bool reverse: false
        property real phaseOffset: 0
        property real phase: 0

        x: -(phase + phaseOffset) * wavelength
        width: wavelength * 3
        height: fillDepth
        preferredRendererType: Shape.CurveRenderer

        NumberAnimation on phase {
            from: wave.reverse ? 1 : 0
            to: wave.reverse ? 0 : 1
            duration: wave.cycleDuration
            loops: Animation.Infinite
            running: wave.flowing && wave.visible && wave.amplitude > 0
            easing.type: Easing.Linear
        }

        ShapePath {
            strokeWidth: 0
            fillColor: wave.waveColor
            PathSvg {
                path: {
                    const L = wave.wavelength;
                    const A = wave.amplitude;
                    let d = "M 0," + A + " ";
                    for (let i = 0; i < 3; i += 1) {
                        const x = i * L;
                        d += "Q " + (x + L * 0.25) + "," + (-A) + " " + (x + L * 0.5) + "," + A + " ";
                        d += "Q " + (x + L * 0.75) + "," + (A * 3) + " " + (x + L) + "," + A + " ";
                    }
                    return d + "L " + wave.width + "," + wave.fillDepth + " L 0," + wave.fillDepth + " Z";
                }
            }
        }
    }
}
