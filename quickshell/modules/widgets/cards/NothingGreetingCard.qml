import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import "../../../"
import "../../../services"
import "../../"
import "../"

// Nothing OS Glyph Greeting & Dot-Matrix Clock Bento Card
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "nothingGreeting"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x2")
    readonly property bool use24h: opts.use24h !== false
    readonly property bool blinkColon: opts.blinkColon !== false
    readonly property bool showWeatherMeta: opts.showWeatherMeta !== false
    readonly property string customName: String(opts.customName || "").trim()
    readonly property string accentMode: String(opts.accentMode || "glyph")
    readonly property bool showShadow: opts.showShadow !== false

    NothingGlyphTokens {
        id: tok
        accentMode: root.accentMode
    }

    property date nowDate: new Date()
    property bool colonVisible: true

    Timer {
        interval: root.blinkColon ? 500 : 1000
        repeat: true
        running: root.active
        onTriggered: {
            root.nowDate = new Date();
            if (root.blinkColon) root.colonVisible = !root.colonVisible;
            else root.colonVisible = true;
        }
    }

    // ISO 8601 week number (matching Nothing OS Home.qml)
    function isoWeek(d) {
        const dt = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        dt.setUTCDate(dt.getUTCDate() + 4 - (dt.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(dt.getUTCFullYear(), 0, 1));
        return Math.ceil((((dt - yearStart) / 86400000) + 1) / 7);
    }

    readonly property string hourStr: {
        const h = nowDate.getHours();
        return root.use24h ? String(h).padStart(2, "0") : String(h % 12 || 12);
    }
    readonly property string minStr: String(nowDate.getMinutes()).padStart(2, "0")
    readonly property string amPmStr: root.use24h ? "" : (nowDate.getHours() >= 12 ? "PM" : "AM")

    readonly property string dateLine: {
        const day = Qt.formatDate(nowDate, "dddd");
        const dm = Qt.formatDate(nowDate, "d MMM");
        return (day + " · " + dm + " · W" + String(isoWeek(nowDate))).toUpperCase();
    }

    readonly property string userName: {
        const raw = root.customName !== "" ? root.customName : (Quickshell.env("USER") || "kuro");
        return raw ? (raw.charAt(0).toUpperCase() + raw.slice(1)) : "Kuro";
    }

    readonly property string greetingStr: {
        const h = nowDate.getHours();
        const sal = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening");
        return sal + ", " + root.userName + ".";
    }

    readonly property int notifCount: {
        if (typeof Notifications !== "undefined" && Notifications.list) {
            return Notifications.list.length;
        }
        return 0;
    }

    readonly property string weatherMeta: {
        if (!root.showWeatherMeta || typeof WeatherSource === "undefined" || !WeatherSource.report) return "";
        const r = WeatherSource.report;
        const c = (typeof Prefs === "undefined" || Prefs.units !== "imperial");
        const t = c ? r.tempC : r.tempF;
        return t + "° " + String(WeatherSource.descFor(r.code) || "").toUpperCase();
    }

    readonly property var btBuds: {
        if (typeof Bluetooth === "undefined" || !Bluetooth.devices) return null;
        for (const d of Bluetooth.devices.values) {
            if (d && d.connected && d.batteryAvailable) return d;
        }
        return null;
    }

    Component.onCompleted: {
        if (root.showWeatherMeta && typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }

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

    ColumnLayout {
        anchors {
            fill: parent
            margins: WidgetStore.s(root.isTall ? 18 : 14)
        }
        spacing: WidgetStore.s(root.isTall ? 10 : 4)

        // Top date + week label
        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(6)

            Rectangle {
                width: WidgetStore.s(6)
                height: WidgetStore.s(6)
                radius: width / 2
                color: tok.accent
            }

            Text {
                Layout.fillWidth: true
                text: root.dateLine
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(root.isWide || root.isTall ? 10 : 9)
                font.letterSpacing: 1.1
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                visible: root.amPmStr !== ""
                text: root.amPmStr
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9)
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }

        // Giant Doto Dot-Matrix Clock (HH:MM)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: WidgetStore.s(root.isTall ? 78 : (root.isWide ? 56 : 50))

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                readonly property int clockPx: WidgetStore.si(root.isTall ? 72 : (root.isWide ? 56 : 48))

                Text {
                    text: root.hourStr
                    color: tok.fg
                    font.family: tok.dotFont
                    font.pixelSize: parent.clockPx
                    font.weight: Font.Black
                    font.variableAxes: ({ "ROND": 100, "wght": 900 })
                    topPadding: -0.14 * font.pixelSize
                    bottomPadding: -0.14 * font.pixelSize
                    renderType: Text.QtRendering
                }

                Text {
                    text: ":"
                    color: root.colonVisible ? tok.accent : Qt.alpha(tok.grey, 0.25)
                    font.family: tok.dotFont
                    font.pixelSize: parent.clockPx
                    font.weight: Font.Black
                    font.variableAxes: ({ "ROND": 100, "wght": 900 })
                    topPadding: -0.14 * font.pixelSize
                    bottomPadding: -0.14 * font.pixelSize
                    renderType: Text.QtRendering
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                Text {
                    text: root.minStr
                    color: tok.fg
                    font.family: tok.dotFont
                    font.pixelSize: parent.clockPx
                    font.weight: Font.Black
                    font.variableAxes: ({ "ROND": 100, "wght": 900 })
                    topPadding: -0.14 * font.pixelSize
                    bottomPadding: -0.14 * font.pixelSize
                    renderType: Text.QtRendering
                }
            }
        }

        // Greeting headline
        Text {
            Layout.fillWidth: true
            text: root.greetingStr
            color: tok.fg
            font.family: tok.uiFont
            font.pixelSize: WidgetStore.si(root.isTall ? 20 : (root.isWide ? 16 : 13))
            font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        // Subtle dotted rule in tall/wide mode
        Row {
            visible: root.isTall
            Layout.fillWidth: true
            spacing: WidgetStore.s(6)
            topPadding: WidgetStore.s(4)
            bottomPadding: WidgetStore.s(4)
            Repeater {
                model: 24
                Rectangle {
                    width: WidgetStore.s(3)
                    height: WidgetStore.s(3)
                    radius: width / 2
                    color: tok.s3
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Meta Footer Row: notifications, weather, earbuds battery
        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(10)

            Text {
                text: root.notifCount > 0
                    ? (root.notifCount + " NOTIF" + (root.notifCount === 1 ? "" : "S"))
                    : "NO NOTIFS"
                color: root.notifCount > 0 ? tok.accent : tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9)
                font.letterSpacing: 0.9
                renderType: Text.NativeRendering
            }

            Text {
                visible: root.weatherMeta !== ""
                text: "·"
                color: tok.mute
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9)
                renderType: Text.NativeRendering
            }

            Text {
                visible: root.weatherMeta !== ""
                Layout.fillWidth: true
                text: root.weatherMeta
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9)
                font.letterSpacing: 0.9
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                visible: root.btBuds !== null
                text: "EAR " + Math.round((root.btBuds?.battery || 0) * 100) + "%"
                color: tok.fg
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9)
                font.letterSpacing: 0.9
                renderType: Text.NativeRendering
            }
        }
    }
}
