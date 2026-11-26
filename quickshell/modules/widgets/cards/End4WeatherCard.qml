import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../"
import "../../"
import "../"

// Authentic end-4pc M3 Expressive Weather widget supporting 1x1, 1x2, 1x3, 2x2, 2x3 + unit override
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "end4Weather"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x3")
    readonly property string unitMode: String(opts.unitMode || "auto")
    readonly property bool showShadow: opts.showShadow !== false
    readonly property bool resizing: resizeHandle.resizing

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

    readonly property string weatherSymbol: {
        switch (root.kind) {
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

    readonly property string tempText: hasReport
        ? ((useCelsius ? report.tempC : report.tempF) + "°")
        : "--°"
    readonly property string feelsText: hasReport
        ? ("Feels like " + (useCelsius ? report.feelsC : report.feelsF) + "°")
        : "Feels like --°"
    readonly property string descText: hasReport ? WeatherSource.descFor(report.code) : "Weather"
    readonly property string placeText: (hasReport && WeatherSource.place) ? String(WeatherSource.place) : "Local"
    readonly property string humidityText: hasReport ? (report.humidity + "%") : "--%"
    readonly property string rainText: hasReport
        ? (report.pop !== undefined ? (report.pop + "%") : ((report.precip || 0) + "mm"))
        : "--%"
    readonly property string windText: hasReport
        ? (useCelsius ? (report.windKmph + " km/h") : (report.windMph + " mph"))
        : "--"
    readonly property string uvText: hasReport ? String(report.uv) : "--"
    readonly property string sunriseText: hasReport ? fmtClock(report.sunrise) : "--:--"
    readonly property string sunsetText: hasReport ? fmtClock(report.sunset) : "--:--"

    onActiveChanged: {
        if (active && typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }
    Component.onCompleted: {
        if (typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }

    readonly property color cardBg: Theme.m3.primary_container ?? Theme.colors.card_bg
    readonly property color cardFg: Theme.m3.on_primary_container ?? Theme.colors.text_primary
    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"
    readonly property color chipBg: Theme.m3.surface_variant ?? Qt.alpha(Theme.m3.on_primary_container ?? "#ffffff", 0.12)
    readonly property color chipFg: Theme.m3.on_surface_variant ?? cardFg

    HoverHandler { id: cardHover }

    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(28)
        color: root.cardBg

        layer.enabled: root.onDesktop && root.showShadow && root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * WidgetStore.qtScale))
        )
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.42)
            shadowBlur: 0.7
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.sizeMode === "1x1") return oneByOneComp;
            if (root.sizeMode === "1x2") return oneByTwoComp;
            if (root.sizeMode === "2x2") return twoByTwoComp;
            if (root.sizeMode === "2x3") return twoByThreeComp;
            return oneByThreeComp;
        }
    }

    // 1x1
    Component {
        id: oneByOneComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(14) }
            spacing: -WidgetStore.s(2)

            Item {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: WidgetStore.s(36)
                Layout.preferredHeight: WidgetStore.s(36)

                ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.weatherSymbol
                    iconSize: WidgetStore.si(18)
                    fill: 1
                    color: root.onAccent
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: root.tempText
                color: root.cardFg
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(30)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }
            Text {
                Layout.fillWidth: true
                text: root.placeText
                color: root.cardFg
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

    // 1x2
    Component {
        id: oneByTwoComp
        RowLayout {
            anchors.fill: parent
            anchors.margins: WidgetStore.s(10)
            spacing: WidgetStore.s(12)

            Rectangle {
                Layout.preferredWidth: WidgetStore.s(98)
                Layout.fillHeight: true
                radius: WidgetStore.s(22)
                color: Qt.alpha(Theme.m3.surface_container_lowest ?? "#0a0e18", 0.35)

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: WidgetStore.s(2)

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: WidgetStore.s(48)
                        Layout.preferredHeight: WidgetStore.s(48)
                        ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.weatherSymbol
                            iconSize: WidgetStore.si(24)
                            fill: 1
                            color: root.onAccent
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.tempText
                        color: root.cardFg
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(24)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.rightMargin: WidgetStore.s(4)
                Layout.topMargin: WidgetStore.s(4)
                Layout.bottomMargin: WidgetStore.s(2)
                spacing: WidgetStore.s(2)

                Text {
                    Layout.fillWidth: true
                    text: root.placeText
                    color: root.cardFg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(15)
                    font.weight: Font.Bold
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.descText
                    color: root.cardFg
                    opacity: 0.68
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(12)
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(6)

                    Repeater {
                        model: [
                            { icon: "humidity_mid", val: root.humidityText },
                            { icon: "rainy", val: root.rainText }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: WidgetStore.s(36)
                            radius: WidgetStore.s(13)
                            color: root.chipBg
                            Row {
                                anchors.centerIn: parent
                                spacing: WidgetStore.s(5)
                                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; iconSize: WidgetStore.si(14); text: modelData.icon; color: root.accent }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.val
                                    color: root.chipFg
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(11)
                                    font.weight: Font.Bold
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 1x3 (default)
    Component {
        id: oneByThreeComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(16) }
            spacing: WidgetStore.s(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(12)

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.tempText
                    color: root.accent
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(40)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    lineHeight: 0.92
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: WidgetStore.s(1)

                    Text {
                        Layout.fillWidth: true
                        text: root.descText
                        color: root.cardFg
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(15)
                        font.weight: Font.DemiBold
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.placeText
                        color: root.cardFg
                        opacity: 0.65
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(12)
                        font.weight: Font.Medium
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: WidgetStore.s(52)
                    Layout.preferredHeight: WidgetStore.s(52)
                    ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.weatherSymbol
                        iconSize: WidgetStore.si(24)
                        fill: 1
                        color: root.onAccent
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(38)
                spacing: WidgetStore.s(6)

                Repeater {
                    model: [
                        { icon: "humidity_mid", val: root.humidityText },
                        { icon: "rainy",        val: root.rainText },
                        { icon: "air",          val: root.windText },
                        { icon: "wb_sunny",     val: "UV " + root.uvText }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: WidgetStore.s(14)
                        color: root.chipBg

                        Row {
                            anchors.centerIn: parent
                            spacing: WidgetStore.s(5)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; iconSize: WidgetStore.si(15); color: root.accent }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.val
                                color: root.chipFg
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(11)
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                                font.hintingPreference: Font.PreferVerticalHinting
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }
    }

    // 2x2
    Component {
        id: twoByTwoComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(16) }
            spacing: WidgetStore.s(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(12)

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: WidgetStore.s(54)
                    Layout.preferredHeight: WidgetStore.s(54)
                    ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.weatherSymbol
                        iconSize: WidgetStore.si(26)
                        fill: 1
                        color: root.onAccent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: WidgetStore.s(0)

                    Text {
                        text: root.tempText
                        color: root.accent
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(34)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.descText
                        color: root.cardFg
                        opacity: 0.72
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(12)
                        font.weight: Font.Medium
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(5)
                MaterialSymbol { iconSize: WidgetStore.si(15); text: "location_on"; color: root.accent; opacity: 0.75 }
                Text {
                    Layout.fillWidth: true
                    text: root.placeText
                    color: root.cardFg
                    opacity: 0.75
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(13)
                    font.weight: Font.Medium
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: WidgetStore.s(8)
                columnSpacing: WidgetStore.s(8)

                Repeater {
                    model: [
                        { icon: "humidity_mid", label: "Humidity", val: root.humidityText },
                        { icon: "rainy",        label: "Rain",     val: root.rainText },
                        { icon: "air",          label: "Wind",     val: root.windText },
                        { icon: "wb_sunny",     label: "UV Index", val: root.uvText }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: WidgetStore.s(16)
                        color: root.chipBg

                        RowLayout {
                            anchors { fill: parent; margins: WidgetStore.s(10) }
                            spacing: WidgetStore.s(8)
                            MaterialSymbol { iconSize: WidgetStore.si(18); text: modelData.icon; color: root.accent }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: modelData.label
                                    color: root.chipFg
                                    opacity: 0.65
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(10)
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.val
                                    color: root.chipFg
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(13)
                                    font.weight: Font.Bold
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 2x3
    Component {
        id: twoByThreeComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(16) }
            spacing: WidgetStore.s(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(14)

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: WidgetStore.s(2)
                    Text {
                        text: root.tempText
                        color: root.accent
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(42)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                        lineHeight: 0.92
                    }
                    RowLayout {
                        spacing: WidgetStore.s(4)
                        MaterialSymbol { iconSize: WidgetStore.si(13); text: "location_on"; color: root.accent; opacity: 0.75 }
                        Text {
                            text: root.placeText
                            color: root.cardFg
                            opacity: 0.75
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(12)
                            font.weight: Font.Medium
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: WidgetStore.s(2)
                    Text {
                        Layout.fillWidth: true
                        text: root.descText
                        color: root.cardFg
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(16)
                        font.weight: Font.DemiBold
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.feelsText
                        color: root.cardFg
                        opacity: 0.62
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(12)
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: WidgetStore.s(56)
                    Layout.preferredHeight: WidgetStore.s(56)
                    ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.weatherSymbol
                        iconSize: WidgetStore.si(28)
                        fill: 1
                        color: root.onAccent
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: WidgetStore.s(8)
                columnSpacing: WidgetStore.s(8)

                Repeater {
                    model: [
                        { icon: "humidity_mid", label: "Humidity", val: root.humidityText },
                        { icon: "air",          label: "Wind",     val: root.windText },
                        { icon: "rainy",        label: "Rain",     val: root.rainText },
                        { icon: "wb_sunny",     label: "UV Index", val: root.uvText },
                        { icon: "wb_twilight",  label: "Sunrise",  val: root.sunriseText },
                        { icon: "nights_stay",  label: "Sunset",   val: root.sunsetText }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: WidgetStore.s(18)
                        color: root.chipBg

                        RowLayout {
                            anchors { fill: parent; margins: WidgetStore.s(10) }
                            spacing: WidgetStore.s(8)
                            MaterialSymbol { iconSize: WidgetStore.si(19); text: modelData.icon; color: root.accent }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: modelData.label
                                    color: root.chipFg
                                    opacity: 0.62
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(10)
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.val
                                    color: root.chipFg
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(13)
                                    font.weight: Font.Bold
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    End4ResizeHandle {
        id: resizeHandle
        tileId: root.tileId
        hoverActive: cardHover.hovered
        enabledHandle: root.onDesktop && root.interactive
        currentMode: root.sizeMode
        snapModes: ["1x1", "1x2", "1x3", "2x2", "2x3"]
        strokeColor: root.cardFg
    }
}
