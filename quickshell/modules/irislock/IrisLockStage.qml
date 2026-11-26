pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services

Item {
    id: root

    required property var context
    property Item frost: null
    property bool editing: false
    readonly property string selected: LockConfig.selection
    property Item input: null
    property bool oskVisible: false
    property bool dragging: false
    property bool peeking: false
    property rect selectedRect: Qt.rect(0, 0, 0, 0)
    readonly property bool arranging: root.editing && !root.peeking
    property bool onCentreX: false
    property bool onCentreY: false
    property date now: new Date()
    property string kbdLayout: ""
    property bool recordingActive: false

    readonly property real typeScale: LockConfig.typeScale
    function lockType(size: int): int { return Math.max(8, Math.round(size * root.typeScale)) }
    function renderFor(block: string): int {
        return Math.abs(LockConfig.scaleOf(block) - 1) < 0.001 ? Text.QtRendering : Text.CurveRendering;
    }

    readonly property int margin: 56
    readonly property date lockedAt: new Date()

    signal submitted()
    signal relayout()
    onWidthChanged: root.relayout()
    onHeightChanged: root.relayout()

    Timer {
        interval: 500
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Process {
        id: kbdProc
        running: root.visible
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); kb=[k for k in d.get('keyboards',[]) if k.get('main')]; kb=kb or d.get('keyboards',[]); print(kb[0].get('active_keymap','') if kb else '')\""]
        stdout: StdioCollector {
            onStreamFinished: root.kbdLayout = text.trim()
        }
    }

    // Shared helper components for crisp Matushell + iRiS typography & icons
    component StageText: Text {
        property bool tabular: false
        property int weightAxis: 540
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: weightAxis >= 700 ? Font.Black : (weightAxis >= 620 ? Font.Bold : (weightAxis >= 560 ? Font.DemiBold : (weightAxis >= 450 ? Font.Medium : Font.Light)))
        font.variableAxes: ({ "wght": weightAxis })
        font.features: tabular ? ({ "tnum": 1 }) : ({})
        renderType: Text.QtRendering
        font.hintingPreference: Font.PreferNoHinting
        color: "#ffffff"
    }

    component StageIcon: Text {
        property bool filled: false
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 18
        font.variableAxes: ({ "FILL": filled ? 1 : 0, "GRAD": Theme.fontIconGrad, "opsz": 24, "wght": 500 })
        renderType: Text.CurveRendering
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: "#ffffff"
    }

    // Frosted cutout Glass plate (cuts directly from single blurred texture for sharp 60fps refraction)
    component Glass: Item {
        id: glass
        property real radius: 20
        property bool outline: false
        property point at: Qt.point(0, 0)
        property real zoom: 1
        readonly property string material: LockConfig.material

        function sync(): void {
            const origin = glass.mapToItem(root, 0, 0);
            const unit = glass.mapToItem(root, 1, 0);
            glass.zoom = Math.max(0.01, unit.x - origin.x);
            glass.at = origin;
        }

        Timer { id: glassSync; interval: 0; onTriggered: glass.sync() }
        Component.onCompleted: glassSync.restart()
        onWidthChanged: glassSync.restart()
        onHeightChanged: glassSync.restart()
        Connections {
            target: root
            function onRelayout(): void { glassSync.restart(); }
        }

        ClippingRectangle {
            anchors.fill: parent
            visible: glass.material === "glass" && root.frost !== null
            radius: glass.radius
            color: "transparent"

            ShaderEffectSource {
                sourceItem: root.frost
                x: -glass.at.x / glass.zoom
                y: -glass.at.y / glass.zoom
                width: root.width / glass.zoom
                height: root.height / glass.zoom
                live: true
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: glass.material !== "none" || glass.outline
            radius: glass.radius
            color: glass.material === "glass"
                ? Qt.rgba(0, 0, 0, 0.22)
                : (glass.material === "tint" ? Qt.rgba(0, 0, 0, 0.42) : "transparent")
            border.width: glass.material === "tint" ? 0 : (glass.material === "none" ? 1 : 0)
            border.color: Qt.rgba(1, 1, 1, 0.20)
        }

        IrisGlassEdge {
            anchors.fill: parent
            visible: glass.material === "glass"
            radius: glass.radius
        }
    }

    function clockText(totalSec: real): string {
        const s = Math.max(0, Math.floor(totalSec));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec;
    }

    function nearestZone(x: real, y: real): string {
        let best = "";
        let distance = Number.POSITIVE_INFINITY;
        for (const zone of LockConfig.zones) {
            const a = LockConfig.zoneAnchor(zone, root.width, root.height, root.margin);
            const away = Math.hypot(x - a.x, y - a.y);
            if (away < distance) {
                distance = away;
                best = zone;
            }
        }
        return distance < 140 ? best : "";
    }

    function weatherGlyph(code, night) {
        const c = parseInt(code);
        if (isNaN(c)) return "cloud";
        if (c === 0) return night ? "clear_night" : "sunny";
        if (c <= 3) return night ? "partly_cloudy_night" : "partly_cloudy_day";
        if (c <= 48) return "foggy";
        if (c <= 82) return "rainy";
        if (c <= 86) return "weather_snowy";
        return "thunderstorm";
    }

    // Status reading item
    component Reading: Item {
        id: reading
        property string glyph: ""
        property string label: ""
        property real battery: -1

        implicitWidth: readingRow.implicitWidth
        implicitHeight: readingRow.implicitHeight

        Row {
            id: readingRow
            spacing: 5

            StageIcon {
                visible: reading.battery < 0 || reading.glyph === "bolt"
                anchors.verticalCenter: parent.verticalCenter
                text: reading.glyph
                font.pixelSize: 16
                color: Qt.rgba(1, 1, 1, 0.78)
            }

            IrisBatteryMark {
                visible: reading.battery >= 0
                anchors.verticalCenter: parent.verticalCenter
                markHeight: 10
                level: reading.battery
                tint: Qt.rgba(1, 1, 1, 0.85)
                frame: Qt.rgba(1, 1, 1, 0.50)
            }

            StageText {
                anchors.verticalCenter: parent.verticalCenter
                text: reading.label
                color: Qt.rgba(1, 1, 1, 0.82)
                font.pixelSize: root.lockType(12)
                weightAxis: 540
                tabular: true
            }
        }
    }

    // Frosted Activity Plate (Recording / Timer / Pomodoro / Stopwatch)
    component ActivityPlate: Item {
        id: plate
        property bool shown: false
        property string glyph: ""
        property color tint: "#ffffff"
        property string label: ""
        property string figure: ""
        property real progress: -1

        visible: plate.shown
        implicitWidth: 380
        implicitHeight: plate.shown ? 62 : 0

        Glass {
            anchors.fill: parent
            radius: 18
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 18
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.alpha(plate.tint, 0.22)

                StageIcon {
                    anchors.centerIn: parent
                    text: plate.glyph
                    filled: true
                    font.pixelSize: 19
                    color: plate.tint
                }
            }

            StageText {
                Layout.fillWidth: true
                text: plate.label
                color: plate.figure.length > 0 ? Qt.rgba(1, 1, 1, 0.78) : "#ffffff"
                font.pixelSize: root.lockType(14)
                weightAxis: plate.figure.length > 0 ? 540 : 620
                elide: Text.ElideRight
            }

            StageText {
                text: plate.figure
                color: plate.tint
                font.pixelSize: root.lockType(20)
                weightAxis: 680
                tabular: true
            }
        }

        Rectangle {
            visible: plate.progress >= 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 20
            anchors.bottomMargin: 6
            width: Math.max(0, (parent.width - 40) * Math.max(0, Math.min(1, plate.progress)))
            height: 2
            radius: 1
            color: plate.tint
        }
    }

    // Draggable / Selectable Block Wrapper
    component BlockBody: Item {
        id: body
        property string blockId: ""
        readonly property var entry: {
            LockConfig.revision;
            return LockConfig.entry(body.blockId);
        }
        readonly property real blockScale: LockConfig.scaleOf(body.blockId)
        readonly property real plateRadius: body.blockId === "media" && String(body.entry?.style ?? "card") !== "bare" ? 22
            : body.blockId === "activity" ? 18 : 18
        readonly property bool on: Boolean(body.entry?.enable ?? false)
        readonly property bool picked: root.editing && root.selected === body.blockId

        implicitWidth: Math.max(slot.implicitWidth * body.blockScale, root.arranging ? 120 : 0)
        implicitHeight: Math.max(slot.implicitHeight * body.blockScale, root.arranging ? 36 : 0)
        visible: body.on || root.arranging
        opacity: body.on || !root.arranging ? 1 : 0.34
        Behavior on opacity { NumberAnimation { duration: 140 } }

        onPickedChanged: if (body.picked) root.selectedRect = Qt.rect(body.x, body.y, body.width, body.height)
        onXChanged: {
            root.relayout();
            if (body.picked) root.selectedRect = Qt.rect(body.x, body.y, body.width, body.height);
        }
        onYChanged: {
            root.relayout();
            if (body.picked) root.selectedRect = Qt.rect(body.x, body.y, body.width, body.height);
        }
        onBlockScaleChanged: root.relayout()

        Loader {
            id: slot
            anchors.centerIn: parent
            scale: body.blockScale
            sourceComponent: body.blockId === "clock" ? clockBlock
                : body.blockId === "glance" ? glanceBlock
                : body.blockId === "media" ? mediaBlock
                : body.blockId === "activity" ? activityBlock
                : body.blockId === "session" ? sessionBlock
                : statusBlock
        }

        // Arranging selection ring
        Rectangle {
            visible: root.arranging
            anchors.fill: parent
            anchors.margins: -8
            radius: Math.round(body.plateRadius * body.blockScale) + 8
            color: body.picked ? Qt.alpha(Theme.accent, 0.16)
                : (grip.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
            border.width: body.picked || grip.containsMouse ? 2 : 0
            border.color: body.picked ? Theme.accent : Qt.rgba(1, 1, 1, 0.35)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Floating Block Label + Visibility Pill above hovered/selected block in edit mode
        Row {
            visible: root.arranging && (body.picked || grip.containsMouse)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 12
            spacing: 5
            z: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: chromeLabel.implicitWidth + 16
                height: 24
                radius: 12
                color: body.picked ? Theme.accent : Qt.rgba(0, 0, 0, 0.72)

                StageText {
                    id: chromeLabel
                    anchors.centerIn: parent
                    text: LockConfig.labelOf(body.blockId)
                    color: body.picked ? Theme.onAccent : "#ffffff"
                    font.pixelSize: 11
                    weightAxis: 640
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: powerArea.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0, 0, 0, 0.72)

                StageIcon {
                    anchors.centerIn: parent
                    text: body.on ? "visibility" : "visibility_off"
                    font.pixelSize: 14
                    color: body.on ? "#ffffff" : Qt.rgba(1, 1, 1, 0.55)
                }

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LockConfig.toggle(body.blockId)
                }
            }
        }

        MouseArea {
            id: grip
            anchors.fill: parent
            anchors.margins: -8
            enabled: root.arranging
            visible: root.arranging
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            property point origin: Qt.point(0, 0)
            property bool moved: false

            onPressed: mouse => {
                LockConfig.selection = body.blockId;
                LockConfig.activeGroup = LockConfig.groupOf(body.blockId);
                grip.origin = Qt.point(mouse.x, mouse.y);
                grip.moved = false;
            }
            onPositionChanged: mouse => {
                if (!grip.pressed) return;
                if (!grip.moved && Math.hypot(mouse.x - grip.origin.x, mouse.y - grip.origin.y) < 6) return;
                if (!grip.moved) root.dragging = true;
                grip.moved = true;
                const scene = grip.mapToItem(root, mouse.x, mouse.y);
                const halfW = body.width / 2;
                const halfH = body.height / 2;
                let cx = Math.max(halfW, Math.min(root.width - halfW, scene.x - grip.origin.x + grip.width / 2));
                let cy = Math.max(halfH, Math.min(root.height - halfH, scene.y - grip.origin.y + grip.height / 2));
                const pull = (mouse.modifiers & Qt.ShiftModifier) ? 0 : 12;
                root.onCentreX = Math.abs(cx - root.width / 2) < pull;
                root.onCentreY = Math.abs(cy - root.height / 2) < pull;
                if (root.onCentreX) cx = root.width / 2;
                if (root.onCentreY) cy = root.height / 2;
                LockConfig.place(body.blockId, "free", cx / Math.max(1, root.width), cy / Math.max(1, root.height));
            }
            onReleased: mouse => {
                root.dragging = false;
                root.onCentreX = false;
                root.onCentreY = false;
                if (!grip.moved) return;
                if (mouse.modifiers & Qt.ShiftModifier) return;
                const centre = body.mapToItem(root, body.width / 2, body.height / 2);
                const zone = root.nearestZone(centre.x, centre.y);
                if (zone.length > 0) LockConfig.writeBlock(body.blockId, { zone: zone });
            }
            onCanceled: {
                root.dragging = false;
                root.onCentreX = false;
                root.onCentreY = false;
            }
        }
    }

    // Zone Anchoring & Collision Avoidance
    property var zoneExtents: ({})
    function noteZone(zone: string, top: real, bottom: real): void {
        const cur = root.zoneExtents[zone];
        if (cur && cur.top === top && cur.bottom === bottom) return;
        const next = Object.assign({}, root.zoneExtents);
        next[zone] = { top: top, bottom: bottom };
        root.zoneExtents = next;
    }

    function middleY(zone: string, height: real): real {
        const above = zone === "left" ? "topLeft" : zone === "right" ? "topRight" : "top";
        const below = zone === "left" ? "bottomLeft" : zone === "right" ? "bottomRight" : "bottom";
        const gap = 24;
        const ceiling = (root.zoneExtents[above]?.bottom ?? 0) + gap;
        const floor = (root.zoneExtents[below]?.top ?? root.height) - gap;
        let y = root.height / 2 - height / 2;
        if (y + height > floor) y = floor - height;
        if (y < ceiling) y = ceiling;
        return y;
    }

    // 9 Structured Zone Columns
    Repeater {
        model: LockConfig.zones

        delegate: Column {
            id: zoneColumn
            required property string modelData
            readonly property bool middle: ["center", "left", "right"].includes(zoneColumn.modelData)
            readonly property var seat: LockConfig.zoneAnchor(zoneColumn.modelData, root.width, root.height, root.margin)
            readonly property var members: {
                LockConfig.revision;
                return LockConfig.shown(zoneColumn.modelData, root.arranging);
            }

            spacing: 18
            onXChanged: root.relayout()
            onYChanged: root.relayout()

            x: Math.round(zoneColumn.seat.align === Qt.AlignLeft ? zoneColumn.seat.x
                : zoneColumn.seat.align === Qt.AlignRight ? zoneColumn.seat.x - width
                : zoneColumn.seat.x - width / 2)
            y: Math.round(zoneColumn.middle ? root.middleY(zoneColumn.modelData, height)
                : zoneColumn.seat.up ? zoneColumn.seat.y - height : zoneColumn.seat.y)

            function note(): void {
                if (zoneColumn.middle) return;
                root.noteZone(zoneColumn.modelData,
                    zoneColumn.members.length > 0 ? zoneColumn.y : root.height,
                    zoneColumn.members.length > 0 ? zoneColumn.y + zoneColumn.height : 0);
            }

            Timer { id: noteLater; interval: 0; onTriggered: zoneColumn.note() }
            onHeightChanged: noteLater.restart()
            onMembersChanged: noteLater.restart()
            Component.onCompleted: noteLater.restart()

            Repeater {
                model: ScriptModel { values: zoneColumn.members }
                delegate: BlockBody {
                    required property string modelData
                    blockId: modelData
                    x: Math.round(zoneColumn.seat.align === Qt.AlignLeft ? 0
                        : zoneColumn.seat.align === Qt.AlignRight ? zoneColumn.width - width
                        : (zoneColumn.width - width) / 2)
                }
            }
        }
    }

    // Free-positioned Blocks
    Repeater {
        model: ScriptModel {
            values: {
                LockConfig.revision;
                return LockConfig.loose(root.arranging);
            }
        }
        delegate: BlockBody {
            id: loose
            required property string modelData
            blockId: modelData
            x: Math.round(Number(loose.entry?.fx ?? 0.5) * root.width - width / 2)
            y: Math.round(Number(loose.entry?.fy ?? 0.5) * root.height - height / 2)
        }
    }

    // Magnetic Center Crosshairs while dragging
    Rectangle {
        visible: root.dragging && root.onCentreX
        width: 1
        height: root.height
        x: Math.round(root.width / 2)
        color: Theme.accent
        opacity: 0.75
    }
    Rectangle {
        visible: root.dragging && root.onCentreY
        height: 1
        width: root.width
        y: Math.round(root.height / 2)
        color: Theme.accent
        opacity: 0.75
    }

    // Zone Snap Rings while dragging
    Repeater {
        model: root.dragging && root.arranging ? LockConfig.zones : []
        delegate: Rectangle {
            id: seatRing
            required property string modelData
            readonly property var seat: LockConfig.zoneAnchor(seatRing.modelData, root.width, root.height, root.margin)
            readonly property bool hot: root.nearestZone(root.selectedRect.x + root.selectedRect.width / 2,
                root.selectedRect.y + root.selectedRect.height / 2) === seatRing.modelData

            width: seatRing.hot ? 34 : 18
            height: width
            radius: width / 2
            x: Math.round(seatRing.seat.x - width / 2)
            y: Math.round(seatRing.seat.y - height / 2)
            color: seatRing.hot ? Qt.alpha(Theme.accent, 0.25) : "transparent"
            border.width: 2
            border.color: seatRing.hot ? Theme.accent : Qt.rgba(1, 1, 1, 0.35)
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }

    // =========================================================================
    // 1. CLOCK BLOCK
    // =========================================================================
    Component {
        id: clockBlock
        Item {
            id: clock
            readonly property var entry: {
                LockConfig.revision;
                return LockConfig.entry("clock");
            }
            readonly property string style: String(clock.entry?.style ?? "stack")
            readonly property bool showDate: Boolean(clock.entry?.date ?? true) && clock.style !== "minimal"
            readonly property int timeSize: Math.max(24, Math.round(
                Number(LockConfig.typeOptions?.clockSize ?? 112) * root.typeScale * (clock.style === "minimal" ? 0.45 : 1)))
            readonly property int timeWeight: Math.max(100, Math.min(900, Number(LockConfig.typeOptions?.clockWeight ?? 700)))
            readonly property real tracking: Number(LockConfig.typeOptions?.clockTracking ?? -2)
            readonly property color inkColor: String(LockConfig.typeOptions?.accent ?? "plain") === "accent" ? Theme.accent : "#ffffff"

            readonly property string dateText: {
                const df = String(LockConfig.typeOptions?.dateFormat ?? "long");
                if (df === "weekday") return root.now.toLocaleDateString(I18n.locale, "dddd");
                if (df === "short") return root.now.toLocaleDateString(I18n.locale, "ddd d MMM");
                if (df === "numeric") return root.now.toLocaleDateString(I18n.locale, Locale.ShortFormat);
                return root.now.toLocaleDateString(I18n.locale, "dddd, d MMMM");
            }
            readonly property string timeText: {
                const wanted = String(LockConfig.typeOptions?.clockFormat ?? "auto");
                const seconds = Boolean(LockConfig.typeOptions?.seconds ?? false);
                const use24 = wanted === "24h" ? true : (wanted === "12h" ? false : Prefs.clock24h);
                const pat = (use24 ? "HH:mm" : "h:mm") + (seconds ? ":ss" : "") + (!use24 && wanted === "12h" ? " AP" : "");
                return Qt.formatDateTime(root.now, pat);
            }

            implicitWidth: clockCol.implicitWidth
            implicitHeight: clockCol.implicitHeight

            Column {
                id: clockCol
                spacing: clock.style === "inline" ? 0 : -4

                StageText {
                    anchors.horizontalCenter: clockCol.horizontalCenter
                    visible: clock.showDate
                    text: clock.dateText
                    color: Qt.rgba(1, 1, 1, 0.78)
                    font.pixelSize: root.lockType(20)
                    weightAxis: 540
                    renderType: root.renderFor("clock")
                }

                StageText {
                    anchors.horizontalCenter: clockCol.horizontalCenter
                    text: clock.timeText
                    color: clock.inkColor
                    font.family: LockConfig.clockFamily
                    font.pixelSize: clock.timeSize
                    weightAxis: clock.timeWeight
                    tabular: true
                    font.letterSpacing: clock.tracking
                    renderType: root.renderFor("clock")
                }
            }
        }
    }

    // =========================================================================
    // 2. AT-A-GLANCE CHIPS (Weather, Events, Battery)
    // =========================================================================
    component Chip: Item {
        id: chip
        property string glyph: ""
        property string label: ""
        property string figure: ""
        property color tint: "#ffffff"
        property real battery: -1

        implicitWidth: chipRow.implicitWidth + 30
        implicitHeight: 38

        Glass {
            anchors.fill: parent
            radius: 19
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7

            StageIcon {
                visible: chip.battery < 0 || chip.glyph === "bolt"
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                filled: true
                font.pixelSize: 17
                color: chip.tint
            }

            IrisBatteryMark {
                visible: chip.battery >= 0
                anchors.verticalCenter: parent.verticalCenter
                markHeight: 11
                level: chip.battery
                tint: chip.tint
                frame: Qt.rgba(1, 1, 1, 0.56)
            }

            StageText {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.figure.length > 0
                text: chip.figure
                color: "#ffffff"
                tabular: true
                weightAxis: 640
                font.pixelSize: root.lockType(14)
            }

            StageText {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.label.length > 0
                width: Math.min(implicitWidth, 220)
                text: chip.label
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.78)
                weightAxis: 520
                font.pixelSize: root.lockType(13)
            }
        }
    }

    Component {
        id: glanceBlock
        Row {
            id: glance
            readonly property var entry: {
                LockConfig.revision;
                return LockConfig.entry("glance");
            }
            readonly property var wx: WeatherSource.report
            readonly property bool night: glance.wx ? !glance.wx.isDay : (root.now.getHours() < 6 || root.now.getHours() >= 20)
            readonly property string tempStr: glance.wx ? Units.deg(glance.wx.tempC, glance.wx.tempF) : ""
            readonly property var nextEv: {
                Agenda.checkedDay;
                root.now;
                return Agenda.next;
            }
            readonly property bool battAvail: typeof Battery !== "undefined" && Battery.available

            spacing: 8

            Chip {
                visible: Boolean(glance.entry?.weather ?? true) && glance.tempStr.length > 0
                glyph: glance.wx ? root.weatherGlyph(glance.wx.code, glance.night) : "cloud"
                figure: glance.tempStr
                label: WeatherSource.place || ""
            }

            Chip {
                visible: Boolean(glance.entry?.events ?? true) && glance.nextEv !== null
                glyph: "event"
                tint: Theme.accent
                label: glance.nextEv
                    ? (glance.nextEv.item.name + " · " + Agenda.untilText(glance.nextEv.at))
                    : ""
            }

            Chip {
                visible: Boolean(glance.entry?.battery ?? true) && glance.battAvail
                glyph: (typeof Battery !== "undefined" && Battery.isCharging) ? "bolt" : ""
                battery: typeof Battery !== "undefined" ? Battery.percentage : 0
                tint: (typeof Battery !== "undefined" && Battery.percentage < 0.2 && !Battery.isCharging) ? "#f38ba8" : "#ffffff"
                figure: (typeof Battery !== "undefined" ? Battery.percent : 0) + "%"
            }
        }
    }

    // =========================================================================
    // 3. NOW PLAYING MEDIA CARD
    // =========================================================================
    Component {
        id: mediaBlock
        Item {
            id: media
            readonly property bool playing: MprisController.activePlayer !== null
                && String(MprisController.activePlayer.trackTitle || MprisController.activePlayer.identity || "").length > 0
            readonly property bool bare: {
                LockConfig.revision;
                return String(LockConfig.entry("media")?.style ?? "card") === "bare";
            }

            implicitWidth: 380
            implicitHeight: (media.playing || root.editing) ? mediaCard.implicitHeight : 0
            visible: media.playing || root.editing

            Glass {
                anchors.fill: parent
                visible: !media.bare
                radius: 22
            }

            IrisLockMediaCard {
                id: mediaCard
                anchors.fill: parent
                active: media.playing
                styleMode: media.bare ? "bare" : "card"
            }
        }
    }

    // =========================================================================
    // 4. ACTIVITY PLATES (Screen Recording / Timer / Pomodoro / Stopwatch)
    // =========================================================================
    Component {
        id: activityBlock
        Column {
            spacing: 10

            readonly property var activeTimer: {
                Chrono.now;
                const running = Chrono.timers.find(t => t.running);
                return running || (Chrono.timers.length > 0 ? Chrono.timers[0] : null);
            }
            readonly property bool timerShown: Chrono.pomoActive || activeTimer !== null || Chrono.swRunning

            ActivityPlate {
                shown: root.recordingActive
                glyph: "radio_button_checked"
                tint: "#f38ba8"
                label: I18n.tr("Recording")
                figure: ""
            }

            ActivityPlate {
                readonly property string kind: Chrono.pomoActive ? "pomodoro"
                    : (activeTimer !== null ? "countdown" : (Chrono.swRunning ? "stopwatch" : ""))
                readonly property bool paused: kind === "pomodoro" ? !Chrono.pomoRunning
                    : (kind === "countdown" && activeTimer ? !activeTimer.running : false)
                readonly property real remMs: kind === "pomodoro" ? Chrono.pomoRemaining
                    : (kind === "countdown" && activeTimer ? Chrono.remaining(activeTimer) : 0)
                readonly property real totMs: kind === "pomodoro" ? Math.max(1, Prefs.pomodoroFocus * 60000)
                    : (kind === "countdown" && activeTimer ? Math.max(1, activeTimer.total) : 1)

                shown: timerShown
                glyph: paused ? "pause" : (kind === "stopwatch" ? "timer" : (kind === "pomodoro" && Chrono.pomoPhase !== "focus" ? "coffee" : "hourglass_top"))
                tint: paused ? Qt.rgba(1, 1, 1, 0.70) : Theme.accent
                label: kind === "pomodoro" ? Chrono.phaseLabel(Chrono.pomoPhase)
                    : (kind === "countdown" ? ((activeTimer && activeTimer.label) || I18n.tr("Timer")) : I18n.tr("Stopwatch"))
                figure: kind === "stopwatch"
                    ? Chrono.clock(Chrono.swRunning ? Chrono.swBank + (Date.now() - Chrono.swStart) : Chrono.swBank, false)
                    : Chrono.countdown(remMs)
                progress: (kind === "pomodoro" || kind === "countdown") ? Math.max(0, Math.min(1, 1 - remMs / totMs)) : -1
            }
        }
    }

    // =========================================================================
    // 5. STATUS BAR (Keyboard Layout, Network, Battery)
    // =========================================================================
    Component {
        id: statusBlock
        Row {
            id: status
            readonly property var entry: {
                LockConfig.revision;
                return LockConfig.entry("status");
            }
            readonly property bool hasWifi: Net.wifiDevice !== null
            readonly property string netGlyph: (Net.wiredDevices && Net.wiredDevices.length > 0 && Net.wiredDevices.some(d => d.connected))
                ? "lan"
                : (Net.wifiDevice && Net.wifiDevice.connected ? "wifi" : "wifi_off")
            readonly property string netLabel: (Net.wiredDevices && Net.wiredDevices.length > 0 && Net.wiredDevices.some(d => d.connected))
                ? "Ethernet"
                : (Net.wifiDevice && Net.wifiDevice.connected ? "Connected" : "Offline")

            spacing: 14

            Reading {
                visible: Boolean(status.entry?.keyboard ?? true) && root.kbdLayout.length > 0
                glyph: "keyboard"
                label: root.kbdLayout
            }

            Reading {
                visible: Boolean(status.entry?.network ?? true)
                glyph: status.netGlyph
                label: status.netLabel
            }

            Reading {
                visible: Boolean(status.entry?.battery ?? true) && typeof Battery !== "undefined" && Battery.available
                glyph: (typeof Battery !== "undefined" && Battery.isCharging) ? "bolt" : ""
                battery: typeof Battery !== "undefined" ? Battery.percentage : 0
                label: (typeof Battery !== "undefined" ? Battery.percent : 0) + "%"
            }
        }
    }

    // =========================================================================
    // 6. SESSION / SIGN-IN BLOCK (Avatar Ring, Name, Password Capsule, Hint)
    // =========================================================================
    Component {
        id: sessionBlock
        Item {
            id: session
            readonly property var entry: {
                LockConfig.revision;
                return LockConfig.entry("session");
            }
            readonly property string userName: Quickshell.env("USER") || "kuro"
            readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)
            readonly property string hintText: root.context.unlockInProgress ? I18n.tr("Unlocking…")
                : root.context.showFailure ? I18n.tr("Incorrect password")
                : root.context.fingerprintsConfigured ? I18n.tr("Touch fingerprint reader or enter password")
                : ""

            implicitWidth: sessionCol.implicitWidth
            implicitHeight: sessionCol.implicitHeight

            Column {
                id: sessionCol
                spacing: 0

                // Avatar inside frosted halo ring
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Boolean(session.entry?.avatar ?? true)
                    width: visible ? 92 : 0
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.20)
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.24)

                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: 84
                        height: 84
                        radius: 42
                        color: Qt.rgba(1, 1, 1, 0.14)

                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: LockConfig.avatarPath !== "" ? "file://" + LockConfig.avatarPath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        StageText {
                            anchors.centerIn: parent
                            visible: avatarImg.status !== Image.Ready
                            text: session.displayName.charAt(0).toUpperCase()
                            font.pixelSize: 34
                            weightAxis: 680
                            color: "#ffffff"
                        }
                    }
                }

                Item { width: 1; height: (Boolean(session.entry?.avatar ?? true)) ? 12 : 0 }

                StageText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Boolean(session.entry?.name ?? true)
                    height: visible ? implicitHeight : 0
                    text: session.displayName
                    font.pixelSize: root.lockType(18)
                    weightAxis: 640
                    color: "#ffffff"
                }

                Item { width: 1; height: 14 }

                // Frosted Password Capsule
                Item {
                    id: capsule
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(180, Math.min(420, Number(session.entry?.width ?? 260)))
                    height: 44

                    Glass {
                        anchors.fill: parent
                        radius: 22
                        outline: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: passwordInput.activeFocus ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        border.width: root.context.showFailure ? 2 : 0
                        border.color: "#f38ba8"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    transform: Translate { id: shakeOffset }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: shakeOffset; property: "x"; to: -12; duration: 45; easing.type: Easing.OutQuad }
                        NumberAnimation { target: shakeOffset; property: "x"; to: 10; duration: 70; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 60; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 55; easing.type: Easing.OutQuad }
                    }

                    Connections {
                        target: root.context
                        function onFailed(): void { shake.restart(); }
                    }

                    // Virtual Keyboard button
                    Rectangle {
                        id: keyboardBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        radius: 16
                        color: root.oskVisible || kbdM.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        StageIcon {
                            anchors.centerIn: parent
                            text: "keyboard"
                            font.pixelSize: 17
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: kbdM
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.editing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.oskVisible = !root.oskVisible
                        }
                    }

                    // Unlock / Submit Arrow Button
                    Rectangle {
                        id: submitBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        radius: 16
                        color: subM.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
                        opacity: (root.context.currentText.length > 0 || root.context.unlockInProgress) ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        StageIcon {
                            anchors.centerIn: parent
                            text: root.context.unlockInProgress ? "more_horiz" : "arrow_forward"
                            font.pixelSize: 17
                            color: subM.containsMouse ? Theme.onAccent : "#ffffff"
                        }

                        MouseArea {
                            id: subM
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.editing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitted()
                        }
                    }

                    // Password TextInput
                    TextInput {
                        id: passwordInput
                        anchors.left: keyboardBtn.right
                        anchors.leftMargin: 6
                        anchors.right: submitBtn.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: "#ffffff"
                        selectionColor: Qt.rgba(1, 1, 1, 0.28)
                        selectedTextColor: "#ffffff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 14
                        font.letterSpacing: 2
                        clip: true
                        enabled: !root.context.unlockInProgress && !root.editing
                        text: root.context.currentText
                        onTextChanged: if (root.context.currentText !== text) root.context.currentText = text
                        onAccepted: root.submitted()
                        Component.onCompleted: root.input = passwordInput
                        Component.onDestruction: if (root.input === passwordInput) root.input = null

                        StageText {
                            anchors.centerIn: parent
                            visible: passwordInput.text.length === 0
                            text: root.context.fingerprintsConfigured ? I18n.tr("Password or fingerprint") : I18n.tr("Enter Password")
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.pixelSize: root.lockType(13)
                            weightAxis: 520
                        }
                    }
                }

                Item { width: 1; height: 10 }

                StageText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Boolean(session.entry?.hint ?? true)
                    height: visible ? implicitHeight : 0
                    text: session.hintText || " "
                    color: root.context.showFailure ? "#f38ba8" : Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: root.lockType(12)
                    weightAxis: 520
                }
            }
        }
    }

    // On-screen Lock Keyboard
    IrisLockKeyboard {
        id: lockKeyboard
        z: 30
        visible: root.oskVisible && !root.editing
        x: Math.round((root.width - width) / 2)
        width: Math.min(root.width * 0.62, 620)

        function place(): void {
            const gap = 14;
            const edge = 48;
            if (!root.input) {
                lockKeyboard.y = Math.round(root.height - lockKeyboard.height - edge);
                return;
            }
            const at = root.input.mapToItem(root, 0, 0);
            const mid = at.y + root.input.height / 2;
            const capsuleBottom = mid + 24 + 28;
            const capsuleTop = mid - 24;
            lockKeyboard.y = Math.round(root.height - capsuleBottom - gap - edge >= lockKeyboard.height
                ? capsuleBottom + gap
                : Math.max(edge, capsuleTop - gap - lockKeyboard.height));
        }

        onVisibleChanged: if (visible) lockKeyboard.place()
        onHeightChanged: lockKeyboard.place()
        Connections {
            target: root
            function onRelayout(): void { lockKeyboard.place(); }
        }

        onKeyClicked: key => {
            if (!root.input) return;
            root.input.text += key;
            root.input.forceActiveFocus();
        }
        onBackspaceClicked: {
            if (!root.input) return;
            if (root.input.text.length > 0) root.input.text = root.input.text.slice(0, -1);
            root.input.forceActiveFocus();
        }
        onEnterClicked: if (root.context.currentText.length > 0) root.submitted()
        onCloseRequested: root.oskVisible = false
    }
}
