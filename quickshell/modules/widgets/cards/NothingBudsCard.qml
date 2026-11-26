import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import "../../../"
import "../../../services"
import "../../"
import "../"

// Nothing OS Glyph Earbuds Battery Ring (with Split L/R/Case + Audio Volume Ring fallback)
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "nothingBuds"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x1")
    readonly property string accentMode: String(opts.accentMode || "glyph")
    readonly property bool showShadow: opts.showShadow !== false

    NothingGlyphTokens {
        id: tok
        accentMode: root.accentMode
    }

    // Connected audio earbuds / headset detection
    readonly property var btDevice: {
        if (typeof EarbudsControlService !== "undefined" && EarbudsControlService.glanceDevice) {
            return EarbudsControlService.glanceDevice;
        }
        if (typeof Bluetooth !== "undefined" && Bluetooth.devices) {
            for (const d of Bluetooth.devices.values) {
                if (d && d.connected && d.batteryAvailable) return d;
            }
        }
        return null;
    }

    readonly property var batBreakdown: {
        if (!btDevice || typeof EarbudsControlService === "undefined") return null;
        return EarbudsControlService.batteryInfo(btDevice);
    }

    readonly property var noiseInfo: {
        if (!btDevice || typeof EarbudsControlService === "undefined") return null;
        const nc = EarbudsControlService.noiseControl(btDevice);
        return (nc && nc.available) ? nc : null;
    }

    function extractLevel(entry) {
        if (entry === null || entry === undefined) return -1;
        if (typeof entry === "number") return Math.max(0, Math.min(100, Math.round(entry)));
        if (typeof entry === "object" && entry.level !== undefined && entry.level !== null) {
            return Math.max(0, Math.min(100, Math.round(Number(entry.level))));
        }
        return -1;
    }

    readonly property int leftBat: extractLevel(batBreakdown?.left)
    readonly property int rightBat: extractLevel(batBreakdown?.right)
    readonly property int caseBat: extractLevel(batBreakdown?.case)
    readonly property bool hasSplitBat: leftBat >= 0 || rightBat >= 0 || caseBat >= 0

    readonly property bool hasBuds: btDevice !== null && (budsPercent >= 0)
    readonly property int budsPercent: {
        if (!btDevice) return -1;
        if (batBreakdown && batBreakdown.available && batBreakdown.aggregate !== null) {
            return Math.max(0, Math.min(100, Math.round(Number(batBreakdown.aggregate))));
        }
        if (btDevice.batteryAvailable && (btDevice.battery ?? -1) >= 0) {
            return Math.max(0, Math.min(100, Math.round(btDevice.battery * 100)));
        }
        return -1;
    }

    readonly property string budsName: {
        if (!btDevice) return "NO BUDS";
        return String(btDevice.deviceName || btDevice.name || "EARBUDS").toUpperCase();
    }

    // System Audio fallback (just like Nothing OS Home.qml budsW)
    readonly property var sink: (typeof Audio !== "undefined") ? Audio.sink : null
    readonly property bool audioMuted: Boolean(sink && sink.audio ? sink.audio.muted : (typeof Audio !== "undefined" ? Audio.muted : false))
    readonly property real volumeFrac: {
        if (sink && sink.audio && isFinite(sink.audio.volume)) {
            return Math.max(0, Math.min(1, Number(sink.audio.volume)));
        }
        if (typeof Audio !== "undefined" && isFinite(Audio.value)) {
            return Math.max(0, Math.min(1, Number(Audio.value)));
        }
        return 0;
    }
    readonly property int volumePct: Math.round(volumeFrac * 100)

    readonly property int displayPercent: hasBuds ? budsPercent : volumePct
    readonly property real displayFrac: hasBuds ? (budsPercent / 100.0) : (audioMuted ? 0.0 : volumeFrac)
    readonly property bool isAlertLow: hasBuds ? (budsPercent <= 20) : audioMuted

    readonly property bool isWide: sizeMode === "1x2"

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

    // 1x1 Circular Dot Ring (Buds Battery or Volume Fallback)
    Item {
        visible: !root.isWide
        anchors.fill: parent

        NothingDotRing {
            anchors.centerIn: parent
            width: WidgetStore.s(124)
            height: WidgetStore.s(124)
            n: 32
            f: root.displayFrac
            dot: WidgetStore.s(4.6)
            onColor: root.isAlertLow ? tok.alertRed : (root.hasBuds ? tok.fg : tok.accent)
            offColor: tok.s3
        }

        Column {
            anchors.centerIn: parent
            width: WidgetStore.s(92)
            spacing: WidgetStore.s(2)

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hasBuds ? "earbuds" : (root.audioMuted ? "volume_off" : "volume_up")
                iconSize: WidgetStore.si(14)
                fill: 1
                color: root.isAlertLow ? tok.alertRed : (root.hasBuds ? tok.fg : tok.grey)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (!root.hasBuds && root.audioMuted) ? "MUTE" : (root.displayPercent + "%")
                color: root.isAlertLow ? tok.alertRed : tok.fg
                font.family: tok.dotFont
                font.pixelSize: WidgetStore.si((!root.hasBuds && root.audioMuted) ? 20 : 26)
                font.weight: Font.Black
                font.variableAxes: ({ "ROND": 100, "wght": 900 })
                topPadding: -0.14 * font.pixelSize
                bottomPadding: -0.14 * font.pixelSize
                renderType: Text.QtRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (!root.hasBuds) return "VOLUME";
                    const mode = String(root.noiseInfo ? (root.noiseInfo.currentModeLabel || "") : "").toUpperCase();
                    if (mode && mode !== "OFF" && mode !== "NORMAL") return mode;
                    return root.budsName;
                }
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(8)
                font.letterSpacing: 0.7
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }

    // 1x2 Wide Buds Glyph Card (Dot ring + device badge & L/R/Case bars or Volume mixer)
    RowLayout {
        visible: root.isWide
        anchors {
            fill: parent
            margins: WidgetStore.s(14)
        }
        spacing: WidgetStore.s(14)

        // Left dot-matrix ring
        Item {
            Layout.preferredWidth: WidgetStore.s(118)
            Layout.preferredHeight: WidgetStore.s(118)
            Layout.alignment: Qt.AlignVCenter

            NothingDotRing {
                anchors.fill: parent
                n: 30
                f: root.displayFrac
                dot: WidgetStore.s(4.2)
                onColor: root.isAlertLow ? tok.alertRed : (root.hasBuds ? tok.fg : tok.accent)
                offColor: tok.s3
            }

            Column {
                anchors.centerIn: parent
                spacing: WidgetStore.s(1)

                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hasBuds ? "earbuds" : (root.audioMuted ? "volume_off" : "volume_up")
                    iconSize: WidgetStore.si(14)
                    fill: 1
                    color: root.isAlertLow ? tok.alertRed : tok.grey
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (!root.hasBuds && root.audioMuted) ? "MUTE" : (root.displayPercent + "%")
                    color: root.isAlertLow ? tok.alertRed : tok.fg
                    font.family: tok.dotFont
                    font.pixelSize: WidgetStore.si((!root.hasBuds && root.audioMuted) ? 18 : 24)
                    font.weight: Font.Black
                    font.variableAxes: ({ "ROND": 100, "wght": 900 })
                    topPadding: -0.14 * font.pixelSize
                    bottomPadding: -0.14 * font.pixelSize
                    renderType: Text.QtRendering
                }
            }
        }

        // Right device telemetry column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: WidgetStore.s(6)

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(6)
                Rectangle {
                    width: WidgetStore.s(6)
                    height: width
                    radius: width / 2
                    color: root.hasBuds ? tok.fg : (root.audioMuted ? tok.alertRed : tok.accent)
                }
                Text {
                    Layout.fillWidth: true
                    text: root.hasBuds ? root.budsName : "AUDIO OUTPUT"
                    color: tok.fg
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(9.5)
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.hasBuds
                    ? (root.noiseInfo ? ("MODE · " + String(root.noiseInfo.currentModeLabel || "NORMAL").toUpperCase()) : "BLUETOOTH AUDIO")
                    : (root.sink ? String(root.sink.description || root.sink.name || "DEFAULT SINK").toUpperCase() : "SPEAKERS")
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(8.5)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Item { Layout.fillHeight: true }

            // Split L/R/Case bars when BudsLink exposes them, else Volume/Battery seg bar
            ColumnLayout {
                visible: root.hasBuds && root.hasSplitBat
                Layout.fillWidth: true
                spacing: WidgetStore.s(5)

                Repeater {
                    model: [
                        { k: "L", v: root.leftBat },
                        { k: "R", v: root.rightBat },
                        { k: "C", v: root.caseBat }
                    ].filter(x => x.v >= 0)

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)

                        Text {
                            Layout.preferredWidth: WidgetStore.s(12)
                            text: modelData.k
                            color: tok.grey
                            font.family: tok.monoFont
                            font.pixelSize: WidgetStore.si(8.5)
                            renderType: Text.NativeRendering
                        }

                        NothingSegBar {
                            Layout.fillWidth: true
                            height: WidgetStore.s(5)
                            n: 10
                            f: modelData.v / 100.0
                            onColor: modelData.v <= 20 ? tok.alertRed : tok.fg
                            offColor: tok.s3
                        }

                        Text {
                            Layout.preferredWidth: WidgetStore.s(26)
                            horizontalAlignment: Text.AlignRight
                            text: modelData.v + "%"
                            color: modelData.v <= 20 ? tok.alertRed : tok.fg
                            font.family: tok.monoFont
                            font.pixelSize: WidgetStore.si(8.5)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            ColumnLayout {
                visible: !(root.hasBuds && root.hasSplitBat)
                Layout.fillWidth: true
                spacing: WidgetStore.s(4)

                Text {
                    text: root.hasBuds ? "BATTERY LEVEL" : "SCROLL TO ADJUST"
                    color: tok.mute
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(8)
                    renderType: Text.NativeRendering
                }

                NothingSegBar {
                    Layout.fillWidth: true
                    height: WidgetStore.s(7)
                    n: 14
                    f: root.displayFrac
                    onColor: root.isAlertLow ? tok.alertRed : tok.fg
                    offColor: tok.s3
                    accentHeadColor: tok.accent
                }
            }
        }
    }

    // Wheel-to-adjust volume + Click to mute/unmute
    MouseArea {
        enabled: root.interactive
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        scrollGestureEnabled: false
        onClicked: {
            if (root.sink && root.sink.audio) {
                root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
        onWheel: (e) => {
            if (!root.sink || !root.sink.audio) return;
            const dy = (e.angleDelta.y || e.angleDelta.x);
            if (dy === 0) return;
            root.sink.audio.muted = false;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.volumeFrac + (dy > 0 ? 0.04 : -0.04)));
            e.accepted = true;
        }
    }
}
