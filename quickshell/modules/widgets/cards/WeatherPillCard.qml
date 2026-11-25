import QtQuick
import QtQuick.Effects
import "../../../"
import "../../../lucidbar"
import "../../"

Item {
    id: root

    property bool active: true
    readonly property var report: (typeof WeatherSource !== "undefined") ? WeatherSource.report : null
    readonly property bool hasReport: report !== null
    readonly property int hourNow: new Date().getHours()
    readonly property bool night: report ? !report.isDay : (hourNow < 6 || hourNow >= 20)
    readonly property string kind: hasReport ? WeatherSource.kindFor(report.code, night) : "clear"
    readonly property string tempText: hasReport
        ? (((typeof Prefs !== "undefined" && !Prefs.tempCelsius) ? report.tempF : report.tempC) + "°")
        : "--°"
    readonly property string descText: hasReport ? WeatherSource.descFor(report.code) : "Weather"

    onActiveChanged: {
        if (active && typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }
    Component.onCompleted: {
        if (typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }

    readonly property color pillBg: Theme.m3.primary_container ?? Theme.colors.card_bg
    readonly property color pillAccent: Theme.m3.primary ?? Theme.accent
    readonly property color pillFg: Theme.m3.on_primary_container ?? Theme.colors.text_primary

    ExpressiveShape {
        id: backgroundShape
        anchors.centerIn: parent
        width: Math.min(root.width - 28, root.height - 28, 224)
        height: width
        shape: "pill"
        color: root.pillBg

        layer.enabled: root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.75
            shadowVerticalOffset: 5
            autoPaddingEnabled: true
        }
    }

    // Crisp unlayered foreground glyphs above the shadowed shape
    Item {
        anchors.centerIn: parent
        width: backgroundShape.width
        height: backgroundShape.height
        z: 2

        Text {
            text: root.tempText
            color: root.pillAccent
            font.family: "Google Sans Flex"
            font.pixelSize: 74
            font.weight: Font.Medium
            font.variableAxes: ({ "ROND": 35, "wdth": 75 })
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 16
                rightMargin: 14
            }
        }

        WeatherIcon {
            size: 76
            kind: root.kind
            tint: root.pillFg
            cloudColor: root.pillFg
            animate: root.active
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: 16
                bottomMargin: 18
            }
        }
    }
}
