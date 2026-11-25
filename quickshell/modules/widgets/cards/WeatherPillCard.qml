import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../lucidbar"
import "../../"
import "../"

Item {
    id: root

    property bool active: true
    readonly property var opts: WidgetStore.cardOptions("weather")
    readonly property string unitMode: String(opts.unitMode || "auto")
    readonly property string styleMode: String(opts.styleMode || "classic")
    readonly property bool isMinimal: styleMode === "minimal"
    readonly property bool showHourly: opts.showHourly !== false
    readonly property bool showRange: opts.showRange !== false
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

    readonly property string tempText: hasReport
        ? ((useCelsius ? report.tempC : report.tempF) + "°")
        : "--°"
    readonly property string descText: hasReport ? WeatherSource.descFor(report.code) : "Syncing..."
    readonly property var today: (hasReport && report.days && report.days.length > 0) ? report.days[0] : null
    readonly property string highLowText: {
        if (!today) return "H --°  L --°";
        return "H " + (useCelsius ? today.maxC : today.maxF) + "°  L " + (useCelsius ? today.minC : today.minF) + "°";
    }
    readonly property string placeText: (hasReport && WeatherSource.place) ? String(WeatherSource.place).toUpperCase() : "LOCAL"
    readonly property string humidityText: hasReport ? (report.humidity + "%") : "--%"
    readonly property string windText: hasReport
        ? (useCelsius ? (report.windKmph + " km/h") : (report.windMph + " mph"))
        : "--"
    readonly property string uvText: hasReport ? String(report.uv) : "--"

    readonly property var hourSlots: {
        const hrs = (hasReport && report.hours) ? report.hours : [];
        const indices = [0, 3, 6, 9];
        const out = [];
        for (let i = 0; i < indices.length; i++) {
            const h = hrs[indices[i]];
            if (h) {
                const m = String(h.time || "").match(/T?(\d{2}):/);
                const hh = m ? m[1] : "";
                out.push({
                    timeLabel: hh ? (hh + ":00") : "--",
                    kind: WeatherSource.kindFor(h.code, !h.day),
                    tempLabel: (useCelsius ? h.tempC : h.tempF) + "°"
                });
            } else {
                out.push({
                    timeLabel: "--",
                    kind: "clear",
                    tempLabel: "--°"
                });
            }
        }
        return out;
    }

    onActiveChanged: {
        if (active && typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }
    Component.onCompleted: {
        if (typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }

    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"
    readonly property color secondary: Theme.m3.secondary ?? "#67e8f9"
    readonly property color tertiary: Theme.m3.tertiary ?? "#ffb4ab"
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

        // Subtle atmospheric corner circle
        Rectangle {
            width: WidgetStore.s(150)
            height: width
            radius: width / 2
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -WidgetStore.s(42)
            anchors.rightMargin: -WidgetStore.s(36)
            color: Qt.alpha(root.accent, 0.14)
        }

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: WidgetStore.s(11)
                rightMargin: WidgetStore.s(11)
                topMargin: WidgetStore.s(10)
                bottomMargin: WidgetStore.s(11)
            }
            spacing: WidgetStore.s(8)

            // Header row: WEATHER tag + Location tag
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: WidgetStore.s(24)
                Layout.maximumHeight: WidgetStore.s(24)
                spacing: WidgetStore.s(6)

                SekaiPill {
                    Layout.preferredWidth: badgeRow.implicitWidth + WidgetStore.s(16)
                    Layout.preferredHeight: WidgetStore.s(22)
                    cornerRadius: WidgetStore.s(8)
                    borderWidth: WidgetStore.s(2)
                    ringWidth: WidgetStore.s(1.5)
                    shadowDy: WidgetStore.s(2)
                    rotation: -1.8
                    fillColor: root.accent

                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(4)
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "partly_cloudy_day"
                            iconSize: WidgetStore.si(12)
                            fill: 1
                            color: root.onAccent
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "WEATHER"
                            color: root.onAccent
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(9)
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 0.8
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                SekaiPill {
                    Layout.maximumWidth: WidgetStore.s(132)
                    Layout.preferredWidth: Math.min(WidgetStore.s(132), locRow.implicitWidth + WidgetStore.s(16))
                    Layout.preferredHeight: WidgetStore.s(22)
                    cornerRadius: WidgetStore.s(8)
                    borderWidth: WidgetStore.s(1.8)
                    ringWidth: WidgetStore.s(1.5)
                    shadowDy: WidgetStore.s(2)
                    rotation: 1.4
                    fillColor: Theme.m3.surface_container_highest ?? Theme.colors.card_bg
                    ringColor: Qt.alpha(root.secondary, 0.25)

                    RowLayout {
                        id: locRow
                        anchors {
                            fill: parent
                            leftMargin: WidgetStore.s(6)
                            rightMargin: WidgetStore.s(6)
                        }
                        spacing: WidgetStore.s(3)

                        MaterialSymbol {
                            text: "location_on"
                            iconSize: WidgetStore.si(11)
                            fill: 1
                            color: root.secondary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.placeText
                            color: root.fg
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(9)
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 0.6
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Hero plate: big temperature + condition + framed WeatherIcon medallion
            SekaiPill {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: WidgetStore.s(110)
                cornerRadius: WidgetStore.s(16)
                borderWidth: WidgetStore.s(2)
                ringWidth: WidgetStore.s(2)
                shadowDx: WidgetStore.s(2)
                shadowDy: WidgetStore.s(3)
                fillColor: Theme.m3.surface_container_high ?? Theme.colors.card_bg
                ringColor: Qt.alpha(root.accent, 0.25)

                // Soft accent glow inside hero plate
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(root.accent, 0.16) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: WidgetStore.s(12)
                        rightMargin: WidgetStore.s(12)
                        topMargin: WidgetStore.s(8)
                        bottomMargin: WidgetStore.s(8)
                    }
                    spacing: WidgetStore.s(10)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: root.tempText
                            color: root.fg
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(38)
                            font.weight: Font.Black
                            font.features: { "tnum": 1 }
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                            lineHeight: 0.92
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.descText
                            color: root.accent
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(12)
                            font.weight: Font.Bold
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: root.showRange
                            Layout.fillWidth: true
                            text: root.highLowText
                            color: root.muted
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(10)
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                        }
                    }

                    SekaiPill {
                        Layout.preferredWidth: WidgetStore.s(64)
                        Layout.preferredHeight: WidgetStore.s(64)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: WidgetStore.s(32)
                        borderWidth: WidgetStore.s(2)
                        ringWidth: WidgetStore.s(2)
                        shadowDy: WidgetStore.s(2)
                        fillColor: Theme.m3.surface_container_lowest ?? "#0a0e18"
                        ringColor: Qt.alpha(root.accent, 0.30)

                        WeatherIcon {
                            anchors.centerIn: parent
                            size: WidgetStore.s(40)
                            kind: root.kind
                            tint: root.accent
                            cloudColor: root.fg
                            animate: root.active
                        }
                    }
                }
            }

            // Stat keycaps row: HUMIDITY / WIND / UV (hidden in Minimal mode matching sekai-pop)
            RowLayout {
                visible: !root.isMinimal
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: WidgetStore.s(48)
                Layout.minimumHeight: WidgetStore.s(46)
                Layout.maximumHeight: WidgetStore.s(50)
                spacing: WidgetStore.s(6)

                Repeater {
                    model: [
                        { label: "HUMIDITY", val: root.humidityText, icon: "water_drop", col: root.secondary },
                        { label: "WIND",     val: root.windText,     icon: "air",        col: root.accent },
                        { label: "UV",       val: root.uvText,       icon: "wb_sunny",   col: root.tertiary }
                    ]

                    SekaiPill {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cornerRadius: WidgetStore.s(11)
                        borderWidth: WidgetStore.s(1.8)
                        ringWidth: WidgetStore.s(1.5)
                        shadowDy: WidgetStore.s(2)
                        fillColor: Theme.m3.surface_container_high ?? Theme.colors.card_bg
                        ringColor: Qt.alpha(modelData.col, 0.20)

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - WidgetStore.s(8)
                            spacing: WidgetStore.s(1)

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: WidgetStore.s(3)

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    iconSize: WidgetStore.si(10)
                                    fill: 1
                                    color: modelData.col
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: root.muted
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(7.5)
                                    font.weight: Font.ExtraBold
                                    font.letterSpacing: 0.6
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.val
                                color: root.fg
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(11)
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                                font.hintingPreference: Font.PreferVerticalHinting
                                renderType: Text.NativeRendering
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Hourly forecast strip
            SekaiPill {
                visible: root.showHourly
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: WidgetStore.s(64)
                Layout.minimumHeight: WidgetStore.s(62)
                Layout.maximumHeight: WidgetStore.s(66)
                cornerRadius: WidgetStore.s(13)
                borderWidth: WidgetStore.s(1.8)
                ringWidth: WidgetStore.s(1.5)
                shadowDy: WidgetStore.s(2)
                fillColor: Theme.m3.surface_container_high ?? Theme.colors.card_bg
                ringColor: Qt.alpha(root.fg, 0.12)

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: WidgetStore.s(8)
                        rightMargin: WidgetStore.s(8)
                        topMargin: WidgetStore.s(5)
                        bottomMargin: WidgetStore.s(5)
                    }
                    spacing: WidgetStore.s(4)

                    Repeater {
                        model: root.hourSlots

                        Item {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                anchors.centerIn: parent
                                spacing: WidgetStore.s(2)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.timeLabel
                                    color: root.muted
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(8.5)
                                    font.weight: Font.ExtraBold
                                    font.features: { "tnum": 1 }
                                    font.hintingPreference: Font.PreferVerticalHinting
                                    renderType: Text.NativeRendering
                                }

                                WeatherIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    size: WidgetStore.s(20)
                                    kind: modelData.kind
                                    tint: root.accent
                                    cloudColor: root.fg
                                    animate: false
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.tempLabel
                                    color: root.fg
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
    }
}
