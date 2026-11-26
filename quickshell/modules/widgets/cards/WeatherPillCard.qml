import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../"
import "../"

// Matushell WeatherCard ported 1:1 to Dynamic You:
// Styles: "material" | "glass" | "blur" (ditherglass.frag.qsb)
// Sizes: "1x1" | "1x2" | "1x3" | "2x3"
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property var notchRoot: null
    property string tileId: "weather"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x3")
    readonly property string cardStyle: {
        const s = String(opts.styleMode || "material");
        return (s === "glass" || s === "blur") ? s : "material";
    }
    readonly property string unitMode: String(opts.unitMode || "auto")

    readonly property bool isMaterial: cardStyle === "material"
    readonly property bool isBlur: cardStyle === "blur"
    readonly property bool isGlass: cardStyle === "glass"

    readonly property var report: (typeof WeatherSource !== "undefined") ? WeatherSource.report : null
    readonly property bool hasReport: report !== null
    readonly property bool useCelsius: {
        if (unitMode === "c") return true;
        if (unitMode === "f") return false;
        return (typeof Prefs === "undefined" || Prefs.units !== "imperial");
    }
    readonly property int hourNow: new Date().getHours()
    readonly property bool night: report ? !report.isDay : (hourNow < 6 || hourNow >= 20)
    readonly property string kind: hasReport ? WeatherSource.kindFor(report.code, night) : "clear"

    readonly property string wxIcon: {
        switch (kind) {
            case "clear": return "clear_day";
            case "clear-night": return "clear_night";
            case "partly": return "partly_cloudy_day";
            case "partly-night": return "partly_cloudy_night";
            case "cloud": return "cloud";
            case "rain": return "rainy";
            case "snow": return "ac_unit";
            case "storm": return "thunderstorm";
            case "fog": return "foggy";
            default: return "cloud";
        }
    }

    function fmtClock(iso) {
        const m = String(iso || "").match(/T?(\d{2}:\d{2})/);
        return m ? m[1] : "--:--";
    }

    readonly property string tempText: hasReport ? ((useCelsius ? report.tempC : report.tempF) + "°") : "--°"
    readonly property string feelsText: hasReport ? ("Feels " + (useCelsius ? report.feelsC : report.feelsF) + "°") : "Feels --°"
    readonly property string feelsVal: hasReport ? ((useCelsius ? report.feelsC : report.feelsF) + "°") : "--°"
    readonly property string descText: hasReport ? WeatherSource.descFor(report.code) : "Weather"
    readonly property string placeText: (hasReport && WeatherSource.place) ? String(WeatherSource.place) : "Local"
    readonly property string humidityText: hasReport ? (report.humidity + "%") : "--%"
    readonly property string cloudText: hasReport && report.cloud !== undefined ? (report.cloud + "%") : (hasReport ? ("UV " + report.uv) : "--")
    readonly property string windText: hasReport ? (useCelsius ? (report.windKmph + " km/h") : (report.windMph + " mph")) : "--"
    readonly property string precipText: hasReport ? (report.pop !== undefined ? (report.pop + "%") : ((report.precip || 0) + "mm")) : "--%"
    readonly property string pressureText: hasReport && report.pressure ? (report.pressure + " hPa") : (hasReport ? ("UV " + report.uv) : "--")
    readonly property string sunriseText: hasReport ? fmtClock(report.sunrise) : "--:--"
    readonly property string sunsetText: hasReport ? fmtClock(report.sunset) : "--:--"

    onActiveChanged: { if (active && typeof WeatherSource !== "undefined") WeatherSource.ensure(); }
    Component.onCompleted: { if (typeof WeatherSource !== "undefined") WeatherSource.ensure(); }

    // Matushell style tokens
    readonly property color bgColor: Theme.m3.surface_container ?? Theme.colors.card_bg
    readonly property color onSurface: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property real dimOpacity: 0.68
    readonly property color accentColor: Theme.m3.primary ?? Theme.accent
    readonly property color accentColorOn: Theme.m3.on_primary ?? "#101014"

    readonly property color heroPanelFill: isMaterial
        ? accentColor
        : (isBlur ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.30))
    readonly property color heroPanelOn: isMaterial ? accentColorOn : accentColor

    readonly property color badgeFill: isMaterial
        ? Qt.alpha(onSurface, 0.10)
        : (isBlur ? Qt.rgba(1, 1, 1, 0.18) : Qt.alpha(Theme.m3.surface_container_high ?? "#2b2930", 0.75))
    readonly property color dividerColor: Qt.alpha(onSurface, 0.15)
    readonly property color tileNormalFill: isMaterial
        ? Qt.alpha(onSurface, 0.08)
        : (isBlur ? Qt.rgba(1, 1, 1, 0.18) : Qt.alpha(Theme.m3.surface_container_high ?? "#2b2930", 0.70))
    readonly property color tileHighlightFill: isMaterial
        ? Qt.alpha(accentColor, 0.24)
        : Qt.alpha(accentColor, 0.15)

    MatusBackdrop {
        anchors.fill: parent
        style: root.cardStyle
        cornerRadius: WidgetStore.s(26)
        materialColor: root.bgColor
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.sizeMode === "1x1") return oneByOneComp;
            if (root.sizeMode === "1x2") return oneByTwoComp;
            if (root.sizeMode === "2x3") return twoByThreeComp;
            return oneByThreeComp;
        }
    }

    component WeatherCookieIcon: Item {
        property real glyphSize: 22
        implicitWidth: WidgetStore.s(46)
        implicitHeight: WidgetStore.s(46)

        ExpressiveShape {
            anchors.fill: parent
            shape: "cookie12"
            color: root.accentColor
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.wxIcon
            fill: 1
            color: root.accentColorOn
            iconSize: WidgetStore.si(glyphSize)
        }
    }

    component WeatherMetricChip: Row {
        property string icon: ""
        property string value: ""
        spacing: WidgetStore.s(4)

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icon
            iconSize: WidgetStore.si(14)
            color: root.onSurface
            opacity: root.dimOpacity
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value || "--"
            color: root.onSurface
            opacity: root.dimOpacity
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(11)
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
    }

    component WeatherWideHeader: RowLayout {
        Layout.fillWidth: true
        spacing: WidgetStore.s(12)

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.tempText
            color: root.accentColor
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(36)
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.descText
                elide: Text.ElideRight
                color: root.onSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(13)
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            Text {
                Layout.fillWidth: true
                text: root.placeText
                opacity: root.dimOpacity
                elide: Text.ElideRight
                color: root.onSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(11)
                renderType: Text.NativeRendering
            }
        }

        WeatherCookieIcon {
            Layout.preferredWidth: WidgetStore.s(46)
            Layout.preferredHeight: WidgetStore.s(46)
            glyphSize: 22
        }
    }

    component WeatherMetricTile: Rectangle {
        property string icon: ""
        property string value: ""
        property string label: ""
        property bool highlighted: false

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: WidgetStore.s(18)
        color: highlighted ? root.tileHighlightFill : root.tileNormalFill
        border.width: (root.isGlass && highlighted) ? Math.max(1, WidgetStore.s(1)) : 0
        border.color: Qt.alpha(root.accentColor, 0.35)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: WidgetStore.s(3)

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                iconSize: WidgetStore.si(19)
                color: parent.parent.highlighted ? root.accentColor : root.onSurface
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value || "--"
                color: root.onSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(12)
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                opacity: root.dimOpacity
                color: root.onSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(9.5)
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }
        }
    }

    // 1x1 Compact Tile
    Component {
        id: oneByOneComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(14) }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                WeatherCookieIcon {
                    Layout.preferredWidth: WidgetStore.s(34)
                    Layout.preferredHeight: WidgetStore.s(34)
                    glyphSize: 18
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: root.hasReport
                    Layout.preferredHeight: WidgetStore.s(22)
                    Layout.preferredWidth: feels1Txt.implicitWidth + WidgetStore.s(10)
                    radius: height / 2
                    color: root.badgeFill
                    Text {
                        id: feels1Txt
                        anchors.centerIn: parent
                        text: root.feelsVal
                        color: root.onSurface
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(10)
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: root.tempText
                color: root.onSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(32)
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                text: root.descText
                opacity: root.dimOpacity
                elide: Text.ElideRight
                color: root.onSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(10.5)
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }
        }
    }

    // 1x2 Horizontal Glance
    Component {
        id: oneByTwoComp
        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: WidgetStore.s(110)
                clip: true

                Rectangle {
                    x: 0; y: 0
                    width: parent.width + WidgetStore.s(52)
                    height: parent.height
                    radius: WidgetStore.s(26)
                    color: root.heroPanelFill
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: WidgetStore.s(2)
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.wxIcon
                        fill: 1
                        color: root.heroPanelOn
                        iconSize: WidgetStore.si(36)
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.tempText
                        opacity: 0.88
                        color: root.heroPanelOn
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(16)
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: WidgetStore.s(14)
                Layout.leftMargin: WidgetStore.s(12)
                spacing: WidgetStore.s(3)

                Text {
                    Layout.fillWidth: true
                    text: root.placeText
                    elide: Text.ElideRight
                    color: root.onSurface
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(14)
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
                Text {
                    Layout.fillWidth: true
                    text: root.descText
                    opacity: root.dimOpacity
                    elide: Text.ElideRight
                    color: root.onSurface
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(11.5)
                    renderType: Text.NativeRendering
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(4)
                    WeatherMetricChip { icon: "humidity_mid"; value: root.humidityText }
                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: WidgetStore.s(10); Layout.leftMargin: WidgetStore.s(4); Layout.rightMargin: WidgetStore.s(4); color: root.dividerColor }
                    WeatherMetricChip { icon: "air"; value: root.windText }
                }
            }
        }
    }

    // 1x3 Wide Panoramic Glance
    Component {
        id: oneByThreeComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(14) }
            spacing: WidgetStore.s(8)

            WeatherWideHeader {}

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: WidgetStore.s(4)
                spacing: WidgetStore.s(14)

                WeatherMetricChip { icon: "humidity_mid"; value: root.humidityText }
                WeatherMetricChip { icon: "rainy"; value: root.precipText }
                WeatherMetricChip { icon: "air"; value: root.windText }
                WeatherMetricChip { icon: "thermostat"; value: root.feelsVal }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    visible: root.sunriseText !== "--:--"
                    spacing: WidgetStore.s(2)
                    WeatherMetricChip { icon: "wb_twilight"; value: root.sunriseText }
                    WeatherMetricChip { icon: "nights_stay"; value: root.sunsetText }
                }
            }
        }
    }

    // 2x3 Expanded Metric Grid
    Component {
        id: twoByThreeComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(14) }
            spacing: WidgetStore.s(10)

            WeatherWideHeader {}

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(20, parent.width - WidgetStore.s(40))
                    height: 1
                    opacity: 0.16
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.2; color: root.onSurface }
                        GradientStop { position: 0.8; color: root.onSurface }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: WidgetStore.s(8)
                columnSpacing: WidgetStore.s(8)

                WeatherMetricTile { icon: "humidity_mid"; value: root.humidityText; label: "Humidity"; highlighted: true }
                WeatherMetricTile { icon: "air"; value: root.windText; label: "Wind" }
                WeatherMetricTile { icon: "rainy"; value: root.precipText; label: "Precipitation"; highlighted: true }
                WeatherMetricTile { icon: "thermostat"; value: root.feelsVal; label: "Feels like" }
                WeatherMetricTile { icon: "wb_twilight"; value: root.sunriseText; label: "Sunrise"; highlighted: true }
                WeatherMetricTile { icon: "nights_stay"; value: root.sunsetText; label: "Sunset" }
            }
        }
    }
}
