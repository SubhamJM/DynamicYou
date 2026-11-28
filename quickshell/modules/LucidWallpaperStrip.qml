import QtQuick
import QtQuick.Window
import qs.luciddocks
import Quickshell.Widgets
import qs
import qs.lucidui

Item {
    id: strip

    property var model: null
    property int heroW: Theme.dp(340)
    property int heroH: Theme.dp(211)
    property int midW: Theme.dp(238)
    property int midH: Theme.dp(148)
    property int smallW: Theme.dp(150)
    property int smallH: Theme.dp(93)
    property int tinyW: Theme.dp(100)
    property int tinyH: Theme.dp(62)
    property int itemGap: Theme.dp(10)
    property int hoveredIndex: -1
    readonly property int hoverGrow: Theme.dp(6)
    property alias currentIndex: view.currentIndex
    // the wallpaper actually in use
    property string appliedPath: ""
    // the Live tab: the same picker over the videos
    property bool live: false
    property real stableHeight: height
    readonly property real rowHeight: strip.heroH + Theme.dp(62)
    // the hero card at the screen's own density: every tier is drawn from it
    readonly property size decodeSize: Qt.size(Math.ceil(strip.heroW * Math.max(1, Screen.devicePixelRatio)), Math.ceil(strip.heroH * Math.max(1, Screen.devicePixelRatio)))
    // Settings -> Theme -> Strip: neighbours shown on each side
    readonly property int sides: Prefs.wallpaperStripSides === 3 ? 3 : 2

    property int previewInterval: 300
    property string pendingPreviewPath: ""
    property bool syncing: false
    property int pendingCenterIndex: -1

    // where the card the user picked sits, as fractions of the window (-1 when
    // it is not known); the "from the chosen card" transition grows from there
    property real originX: -1
    property real originY: -1

    signal interacted()
    signal chosen(string path)
    signal previewed(string path)

    function noteOrigin(card) {
        if (!card || strip.Window.width <= 0 || strip.Window.height <= 0) {
            strip.originX = -1;
            strip.originY = -1;
            return;
        }
        var p = card.mapToItem(null, card.width / 2, card.height / 2);
        strip.originX = p.x / strip.Window.width;
        strip.originY = p.y / strip.Window.height;
    }

    // arrow keys: one card along, and (for the styles laid out in rows) one row over
    function step(d) {
        strip.interacted();
        if (strip.model)
            view.currentIndex = Math.max(0, Math.min(strip.model.count - 1, view.currentIndex + d));
    }

    function stepVertical(d) {
    }

    function activateCurrent() {
        if (view.currentIndex < 0 || !strip.model)
            return;

        var item = strip.model.get(view.currentIndex);
        if (item) {
            strip.noteOrigin(view.currentItem);
            strip.chosen(item.path);
        }
    }

    function setIndexImmediate(i) {
        strip.syncing = true;
        previewThrottle.stop();
        strip.pendingPreviewPath = "";
        view.highlightMoveDuration = 0;
        view.currentIndex = i;
        strip.pendingCenterIndex = i;
        view.forceLayout();
        strip.centerPending();
        restoreAnim.restart();
    }

    // deferred — straight from a delegate handler this crashes mid-incubation
    function relayout() {
        view.forceLayout();
        if (strip.syncing && view.currentIndex >= 0) {
            view.positionViewAtIndex(view.currentIndex, ListView.Center);
        }
    }

    function centerPending() {
        if (strip.pendingCenterIndex < 0)
            return;

        view.positionViewAtIndex(strip.pendingCenterIndex, ListView.Center);
        strip.pendingCenterIndex = -1;
    }

    function emitPreview() {
        if (strip.pendingPreviewPath === "")
            return;

        // the transition can grow from the card being previewed
        strip.noteOrigin(view.currentItem);
        strip.previewed(strip.pendingPreviewPath);
        strip.pendingPreviewPath = "";
    }

    Timer {
        id: restoreAnim

        interval: 180
        onTriggered: {
            view.forceLayout();
            if (view.currentIndex >= 0) {
                view.positionViewAtIndex(view.currentIndex, ListView.Center);
            }
            view.highlightMoveDuration = Theme.ms(260);
            strip.syncing = false;
        }
    }

    Timer {
        id: previewThrottle

        interval: strip.previewInterval
        onTriggered: strip.emitPreview()
    }

    ListView {
        id: view


        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - strip.rowHeight) / 2)
        height: strip.heroH + Theme.dp(24)
        orientation: ListView.Horizontal
        spacing: strip.itemGap
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        model: strip.model
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (view.width - strip.heroW) / 2
        preferredHighlightEnd: (view.width + strip.heroW) / 2
        highlightMoveDuration: strip.syncing ? 0 : Theme.ms(260)
        flickDeceleration: 3000
        visible: count > 0
        cacheBuffer: strip.heroW * 6

        onWidthChanged: {
            if (strip.syncing && view.currentIndex >= 0) {
                view.forceLayout();
                view.positionViewAtIndex(view.currentIndex, ListView.Center);
            }
        }

        onCurrentIndexChanged: {
            Qt.callLater(strip.relayout);
            if (strip.syncing || view.currentIndex < 0 || !strip.model)
                return;

            var item = strip.model.get(view.currentIndex);
            if (!item)
                return;

            strip.pendingPreviewPath = item.path;
            previewThrottle.restart();
        }

        delegate: Item {
            id: slot

            required property string path
            required property string name
            required property string thumb
            required property bool temp
            required property int index

            readonly property bool isCurrent: view.currentIndex === slot.index
            readonly property bool isApplied: strip.appliedPath !== "" && strip.appliedPath === slot.path
            readonly property bool hovered: cardHover.hovered && stripHover.hovered
            readonly property bool pressed: cardTap.pressed && slot.hovered

            onHoveredChanged: {
                if (slot.hovered)
                    strip.hoveredIndex = slot.index;
                else if (strip.hoveredIndex === slot.index)
                    strip.hoveredIndex = -1;

            }
            readonly property int tier: Math.min(strip.sides, Math.abs(slot.index - view.currentIndex))
            readonly property int targetW: slot.tier === 0 ? strip.heroW : (slot.tier === 1 ? strip.midW : (slot.tier === 2 ? strip.smallW : strip.tinyW))
            readonly property int targetH: slot.tier === 0 ? strip.heroH : (slot.tier === 1 ? strip.midH : (slot.tier === 2 ? strip.smallH : strip.tinyH))

            width: slot.targetW
            height: view.height

            onWidthChanged: Qt.callLater(strip.relayout)

            Behavior on width {
                enabled: !strip.syncing
                NumberAnimation {
                    duration: Theme.ms(260)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }
            }

            ClippingRectangle {
                id: card

                anchors.centerIn: parent
                anchors.verticalCenterOffset: slot.hovered ? -Theme.dp(4) : 0
                scale: slot.pressed ? 1 - 4 / card.width : (slot.hovered ? 1 + strip.hoverGrow / card.width : 1)
                width: parent.width
                height: slot.targetH

                Behavior on anchors.verticalCenterOffset {
                    enabled: !strip.syncing
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    enabled: !strip.syncing
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }
                }
                radius: slot.tier === 0 ? Theme.shapeXl : (slot.tier === 1 ? Theme.shapeLg : (slot.tier === 2 ? Theme.shapeMd : Theme.shapeSm))
                color: Theme.bgTile
                opacity: (slot.tier === 0 || slot.hovered) ? 1 : (slot.tier === 1 ? 0.64 : (slot.tier === 2 ? 0.36 : 0.22))

                Behavior on height {
                    enabled: !strip.syncing
                    NumberAnimation {
                        duration: Theme.ms(260)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }
                }

                Behavior on opacity {
                    enabled: !strip.syncing
                    NumberAnimation {
                        duration: Theme.ms(240)
                    }
                }


                // the small copy decodes in a millisecond, so it is read in step and
                // is up on the card's first frame; an original still waiting for
                // one stays off the gui thread
                Image {
                    anchors.fill: parent
                    // a video has no picture of its own until its thumbnail is cut; asked of
                    // the file, since the model can change tab a moment before strip.live does
                    source: slot.thumb !== "" ? "file://" + slot.thumb : /\.(mp4|webm|mkv|mov|m4v)$/i.test(slot.path) ? "" : "file://" + slot.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: slot.thumb === ""
                    cache: true
                    sourceSize: strip.decodeSize
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.dp(8)
                    width: Theme.dp(48)
                    height: Theme.dp(24)
                    radius: Theme.dp(6)
                    color: Theme.accent
                    visible: /\.(mp4|webm|mkv|mov|m4v)$/i.test(slot.path)

                    Text {
                        anchors.centerIn: parent
                        text: "▶  LIVE"
                        color: Theme.fgAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(9)
                        font.bold: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.text
                    opacity: slot.pressed ? Theme.statePressed : (slot.hovered ? Theme.stateHover : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

            // Subtle accent outline on the centered hero card for crisp M3 framing
            Rectangle {
                anchors.fill: card
                radius: card.radius
                color: "transparent"
                border.width: slot.tier === 0 ? 1.5 : 0
                border.color: slot.isApplied ? Theme.accent : Qt.alpha(Theme.text, 0.22)
                visible: slot.tier === 0
            }

            Rectangle {
                anchors.right: card.right
                anchors.top: card.top
                anchors.margins: Theme.dp(10)
                width: Theme.dp(26)
                height: Theme.dp(26)
                radius: width / 2
                color: Theme.accent
                scale: slot.isApplied ? 1 : 0.4

                Behavior on scale {
                    enabled: !strip.syncing
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }
                }
                opacity: slot.isApplied ? 1 : 0
                visible: opacity > 0.01

                Text {
                    anchors.centerIn: parent
                    text: "check"
                    color: Theme.fgAccent
                    font.family: Theme.fontFamilyIcon
                    font.pixelSize: 15
                    font.hintingPreference: Font.PreferNoHinting
                    font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 15, "wght": 600 })
                    renderType: Text.CurveRendering
                    antialiasing: true
                    smooth: true
                }

                Behavior on opacity {
                    enabled: !strip.syncing
                    NumberAnimation {
                        duration: Theme.durShort
                    }
                }
            }

            // set from outside the folder, from lumen say: in the strip only while
            // it is the wallpaper, and this says so
            Rectangle {
                anchors.left: card.left
                anchors.top: card.top
                anchors.margins: Theme.dp(10)
                width: Theme.dp(26)
                height: Theme.dp(26)
                radius: width / 2
                color: Theme.secondaryContainer
                visible: slot.temp

                Icon {
                    anchors.centerIn: parent
                    name: "hourglass_top"
                    size: Theme.dp(16)
                    fill: 1
                    color: Theme.fgSecondaryContainer
                }

            }

            HoverHandler {
                id: cardHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: cardTap

                onTapped: {
                    strip.interacted();
                    if (slot.isCurrent) {
                        strip.noteOrigin(slot);
                        strip.chosen(slot.path);
                    } else
                        view.currentIndex = slot.index;
                }
            }

        }

    }

    HoverHandler {
        id: stripHover
    }

    Item {
        id: caption

        anchors.top: view.bottom
        anchors.topMargin: Theme.dp(12)
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.dp(26)
        visible: view.visible

        Row {
            id: capRow

            readonly property int at: strip.hoveredIndex >= 0 ? strip.hoveredIndex : view.currentIndex
            readonly property var entry: strip.model && capRow.at >= 0 && capRow.at < strip.model.count ? strip.model.get(capRow.at) : null

            anchors.centerIn: parent
            spacing: Theme.dp(10)

            Text {
                id: capName

                anchors.verticalCenter: parent.verticalCenter
                text: capRow.entry ? capRow.entry.name : ""
                color: Theme.text
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.variableAxes: ({ "wght": 580, "wdth": 100 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
                elide: Text.ElideRight
                width: Math.min(capMetrics.width + Theme.dp(4), Math.max(0, strip.width - Theme.dp(220)))

                TextMetrics {
                    id: capMetrics

                    font: capName.font
                    text: capName.text
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: appliedLabel.implicitWidth + Theme.dp(16)
                height: Theme.dp(22)
                radius: Theme.shapeFull
                color: Theme.accent
                visible: capRow.entry !== null && strip.appliedPath !== "" && strip.appliedPath === capRow.entry.path

                Text {
                    id: appliedLabel

                    anchors.centerIn: parent
                    text: I18n.tr("On the desktop")
                    color: Theme.fgAccent
                    font.family: "Google Sans Flex"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.variableAxes: ({ "wght": 580, "wdth": 100 })
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: strip.model && strip.model.count > 0 ? (capRow.at + 1) + " / " + strip.model.count : ""
                color: Theme.subtextDim
                font.family: "Google Sans Flex"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.variableAxes: ({ "wght": 500, "wdth": 100 })
                font.features: ({ "tnum": 1 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
            }

        }

    }

    Column {
        id: emptyState

        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - emptyState.implicitHeight) / 2)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.dp(12)
        visible: !strip.model || strip.model.count === 0

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(58)
            height: Theme.dp(58)
            radius: Theme.shapeXl
            color: Theme.withBlur(Theme.surfaceHigh)

            Icon {
                anchors.centerIn: parent
                name: strip.live ? "movie" : "wallpaper"
                size: Theme.dp(28)
                color: Theme.primary
            }

        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "titleMedium"
            text: strip.live ? I18n.tr("No videos in this folder") : I18n.tr("No wallpapers in this folder")
            color: Theme.text
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "bodyMedium"
            text: strip.live ? I18n.tr("Drop mp4, webm or mkv files into the theme's wallpaper folder and they show up here.") : I18n.tr("Drop images into the theme's wallpaper folder and they show up here.")
            color: Theme.subtextDim
        }

    }

}
