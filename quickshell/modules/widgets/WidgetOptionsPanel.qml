import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../services"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog

// Unified per-widget settings panel rendered in the widget's native shell style:
// - end4* widgets use M3 Expressive rounded surfaces, pills, and switches (end-4pc style)
// - Sekai Pop widgets use SekaiPill outlined raised chips & tilted badges
Item {
    id: root

    property string tileId: ""
    property bool onDesktop: true
    property string screenName: ""
    property var notchRoot: null
    signal closed()

    readonly property var def: root.tileId !== "" ? Catalog.definitionFor(root.tileId) : null
    readonly property bool isM3: !!(def && def.isM3 === true)
    readonly property var opts: root.tileId !== "" ? WidgetStore.cardOptions(root.tileId) : ({})
    readonly property var sizeModes: (def && Array.isArray(def.sizeModes)) ? def.sizeModes : []
    readonly property string currentSize: String(opts.sizeMode || (sizeModes.length > 0 ? sizeModes[0] : ""))
    readonly property bool pinned: root.tileId !== "" && WidgetStore.isPinned(root.tileId)

    implicitWidth: WidgetStore.s(284)
    implicitHeight: isM3
        ? Math.min(WidgetStore.s(540), m3Col.implicitHeight + WidgetStore.s(28))
        : Math.min(WidgetStore.s(540), sekaiCol.implicitHeight + WidgetStore.s(32))
    width: implicitWidth
    height: implicitHeight

    function sizeLabel(mode) {
        if (root.tileId === "end4Resources") {
            return mode === "3x1" ? "Vertical" : "Horizontal";
        }
        return mode.replace("x", "×");
    }

    // ---------------------------------------------------------
    // 1. M3 EXPRESSIVE OPTIONS PANEL (end-4pc style)
    // ---------------------------------------------------------
    Item {
        id: m3Card
        visible: root.isM3 && root.tileId !== ""
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: WidgetStore.s(24)
            color: Theme.m3.surface_container_highest ?? Theme.colors.card_bg
            border.width: Math.max(1, WidgetStore.s(1))
            border.color: Qt.alpha(Theme.m3.outline_variant ?? "#4a5c72", 0.55)

            layer.enabled: m3Card.visible && width > 1 && height > 1
            layer.smooth: true
            layer.textureSize: Qt.size(
                Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)),
                Math.max(1, Math.round(height * 2 * WidgetStore.qtScale))
            )
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.50)
                shadowBlur: 0.78
                shadowVerticalOffset: WidgetStore.s(6)
                autoPaddingEnabled: true
            }
        }

        Flickable {
            id: m3Flick
            anchors {
                fill: parent
                margins: WidgetStore.s(14)
            }
            clip: true
            contentWidth: width
            contentHeight: m3Col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: m3Col
                width: m3Flick.width
                spacing: WidgetStore.s(10)

                // M3 Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(10)

                    Item {
                        Layout.preferredWidth: WidgetStore.s(32)
                        Layout.preferredHeight: WidgetStore.s(32)
                        ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: Theme.m3.primary ?? Theme.accent }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.def ? root.def.icon : "tune"
                            iconSize: WidgetStore.si(16)
                            fill: 1
                            color: Theme.m3.on_primary ?? "#101014"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: root.def ? root.def.name : "Widget"
                            color: Theme.m3.on_surface ?? Theme.colors.text_primary
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(14)
                            font.weight: Font.Bold
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Material 3 options"
                            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(10)
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(28)
                        Layout.preferredHeight: WidgetStore.s(28)
                        radius: width / 2
                        color: m3ResetMouse.containsMouse
                            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.16)
                            : Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.08)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "restart_alt"
                            iconSize: WidgetStore.si(16)
                            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                        }
                        MouseArea {
                            id: m3ResetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WidgetStore.resetCardOptions(root.tileId)
                        }
                    }
                }

                // Size Mode selector (1x1, 1x2, 1x3, 2x2, 2x3 or Horizontal / Vertical)
                M3ChipGroup {
                    visible: root.sizeModes.length > 0
                    title: root.tileId === "end4Resources" ? "Layout" : "Widget size"
                    currentValue: root.currentSize
                    options: root.sizeModes.map(m => ({ id: m, label: root.sizeLabel(m) }))
                    onPicked: (val) => WidgetStore.setCardOption(root.tileId, "sizeMode", val)
                }

                // end4Weather options
                M3ChipGroup {
                    visible: root.tileId === "end4Weather"
                    title: "Units"
                    currentValue: String(root.opts.unitMode || "auto")
                    options: [
                        { id: "auto", label: "Auto" },
                        { id: "c", label: "°C / km/h" },
                        { id: "f", label: "°F / mph" }
                    ]
                    onPicked: (val) => WidgetStore.setCardOption("end4Weather", "unitMode", val)
                }

                // end4Media options
                M3ToggleRow {
                    visible: root.tileId === "end4Media" && root.currentSize === "1x3"
                    icon: "lyrics"
                    label: "Lyrics Drawer"
                    checked: root.opts.showLyrics === true
                    onToggled: WidgetStore.setCardOption("end4Media", "showLyrics", !(root.opts.showLyrics === true))
                }
                M3ToggleRow {
                    visible: root.tileId === "end4Media" && root.currentSize === "1x3"
                    icon: "title"
                    label: "Show Titles"
                    checked: root.opts.showTitles !== false
                    onToggled: WidgetStore.setCardOption("end4Media", "showTitles", !(root.opts.showTitles !== false))
                }
                M3ToggleRow {
                    visible: root.tileId === "end4Media" && root.currentSize === "1x3"
                    icon: "tune"
                    label: "Show Controls"
                    checked: root.opts.showControls !== false
                    onToggled: WidgetStore.setCardOption("end4Media", "showControls", !(root.opts.showControls !== false))
                }

                // end4Resources options
                M3ChipGroup {
                    visible: root.tileId === "end4Resources"
                    title: "Third Stat Card"
                    currentValue: String(root.opts.thirdMetric || "auto")
                    options: [
                        { id: "auto", label: "Auto" },
                        { id: "battery", label: "Battery" },
                        { id: "disk", label: "Disk" }
                    ]
                    onPicked: (val) => WidgetStore.setCardOption("end4Resources", "thirdMetric", val)
                }

                // end4User options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "end4User"
                    spacing: WidgetStore.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)

                        M3ActionPill {
                            Layout.fillWidth: true
                            icon: "face"
                            label: "Choose Avatar…"
                            tonal: true
                            onTriggered: WidgetStore.pickImageOption("end4User", "customAvatar")
                        }
                        M3ActionPill {
                            visible: String(root.opts.customAvatar || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(64)
                            icon: "close"
                            label: "Clear"
                            onTriggered: WidgetStore.setCardOption("end4User", "customAvatar", "")
                        }
                    }

                    RowLayout {
                        visible: root.currentSize === "2x2" || root.currentSize === "2x3"
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)

                        M3ActionPill {
                            Layout.fillWidth: true
                            icon: "panorama"
                            label: "Choose Banner…"
                            tonal: true
                            onTriggered: WidgetStore.pickImageOption("end4User", "customBanner")
                        }
                        M3ActionPill {
                            visible: String(root.opts.customBanner || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(64)
                            icon: "close"
                            label: "Clear"
                            onTriggered: WidgetStore.setCardOption("end4User", "customBanner", "")
                        }
                    }

                    M3ToggleRow {
                        visible: root.currentSize === "2x2"
                        icon: "auto_awesome"
                        label: "Weather Quip"
                        checked: root.opts.showQuip !== false
                        onToggled: WidgetStore.setCardOption("end4User", "showQuip", !(root.opts.showQuip !== false))
                    }
                    M3ToggleRow {
                        visible: root.currentSize !== "1x1"
                        icon: "schedule"
                        label: "System Uptime"
                        checked: root.opts.showUptime !== false
                        onToggled: WidgetStore.setCardOption("end4User", "showUptime", !(root.opts.showUptime !== false))
                    }
                    M3ToggleRow {
                        visible: root.currentSize === "2x2"
                        icon: "lock"
                        label: "Quick Actions"
                        checked: root.opts.showActions !== false
                        onToggled: WidgetStore.setCardOption("end4User", "showActions", !(root.opts.showActions !== false))
                    }
                }

                // end4Image options (any custom image + M3 Cookie/Gem shapes + fit + opacity)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "end4Image"
                    spacing: WidgetStore.s(8)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)

                        M3ActionPill {
                            Layout.fillWidth: true
                            icon: "add_photo_alternate"
                            label: "Choose Image / GIF…"
                            tonal: true
                            onTriggered: WidgetStore.pickImageOption("end4Image", "customPath")
                        }
                        M3ActionPill {
                            visible: String(root.opts.customPath || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(74)
                            icon: "wallpaper"
                            label: "Wall"
                            onTriggered: WidgetStore.setCardOption("end4Image", "customPath", "")
                        }
                    }

                    M3ChipGroup {
                        title: "Shape mask"
                        currentValue: String(root.opts.shapeMode || "rounded")
                        options: [
                            { id: "rounded", label: "Rect" },
                            { id: "cookie4", label: "Cookie4" },
                            { id: "cookie12", label: "Cookie12" },
                            { id: "gem", label: "Gem" },
                            { id: "circle", label: "Circle" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("end4Image", "shapeMode", val)
                    }

                    M3ChipGroup {
                        title: "Fit & Opacity"
                        currentValue: String(root.opts.fitMode || "fill")
                        options: [
                            { id: "fill", label: "Fill Crop" },
                            { id: "fit", label: "Fit Whole" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("end4Image", "fitMode", val)
                    }

                    M3ChipGroup {
                        title: "Opacity"
                        currentValue: String(Number(root.opts.opacityLevel !== undefined ? root.opts.opacityLevel : 1.0))
                        options: [
                            { id: "1", label: "100%" },
                            { id: "0.85", label: "85%" },
                            { id: "0.65", label: "65%" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("end4Image", "opacityLevel", Number(val))
                    }
                }

                // Shared M3 appearance option: Drop Shadow
                M3ToggleRow {
                    icon: "shadow"
                    label: "Drop Shadow"
                    checked: root.opts.showShadow !== false
                    onToggled: WidgetStore.setCardOption(root.tileId, "showShadow", !(root.opts.showShadow !== false))
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.alpha(Theme.m3.outline_variant ?? "#4a5c72", 0.38)
                }

                // Footer actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(6)

                    M3ActionPill {
                        Layout.fillWidth: true
                        icon: root.pinned ? "dock_to_left" : "pin_drop"
                        label: root.pinned ? "Unpin" : "Pin"
                        onTriggered: {
                            const id = root.tileId;
                            root.closed();
                            WidgetStore.togglePin(id, root.screenName);
                        }
                    }

                    M3ActionPill {
                        visible: WidgetStore.desktopCardIds.length > 1
                        Layout.fillWidth: true
                        icon: "move_down"
                        label: "Return all"
                        danger: true
                        onTriggered: {
                            root.closed();
                            WidgetStore.returnAllToSidebar();
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // 2. SEKAI POP OPTIONS PANEL (SekaiPill raised badges)
    // ---------------------------------------------------------
    SekaiPill {
        id: sekaiCard
        visible: !root.isM3 && root.tileId !== ""
        anchors.fill: parent
        cornerRadius: WidgetStore.s(18)
        borderWidth: WidgetStore.s(2.5)
        ringWidth: WidgetStore.s(2.5)
        shadowDx: WidgetStore.s(3)
        shadowDy: WidgetStore.s(4)
        fillColor: Theme.m3.surface_container ?? Theme.colors.card_bg
        ringColor: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.25)

        Flickable {
            id: sekaiFlick
            anchors {
                fill: parent
                margins: WidgetStore.s(12)
            }
            clip: true
            contentWidth: width
            contentHeight: sekaiCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: sekaiCol
                width: sekaiFlick.width
                spacing: WidgetStore.s(8)

                // Sekai Pop tilted header badge + Reset button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(6)

                    SekaiPill {
                        Layout.preferredWidth: sekaiBadgeRow.implicitWidth + WidgetStore.s(18)
                        Layout.preferredHeight: WidgetStore.s(24)
                        cornerRadius: WidgetStore.s(8)
                        borderWidth: WidgetStore.s(2)
                        ringWidth: WidgetStore.s(1.5)
                        shadowDy: WidgetStore.s(2)
                        rotation: -1.6
                        fillColor: Theme.m3.primary ?? Theme.accent

                        Row {
                            id: sekaiBadgeRow
                            anchors.centerIn: parent
                            spacing: WidgetStore.s(5)
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.def ? root.def.icon : "tune"
                                iconSize: WidgetStore.si(13)
                                fill: 1
                                color: Theme.m3.on_primary ?? "#101014"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.def ? root.def.name : "WIDGET").toUpperCase()
                                color: Theme.m3.on_primary ?? "#101014"
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(9.5)
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.7
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    SekaiPill {
                        Layout.preferredWidth: WidgetStore.s(26)
                        Layout.preferredHeight: WidgetStore.s(26)
                        cornerRadius: WidgetStore.s(9)
                        borderWidth: WidgetStore.s(1.8)
                        ringWidth: WidgetStore.s(1.5)
                        shadowDy: WidgetStore.s(2)
                        pressed: sekaiResetMouse.pressed
                        fillColor: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "restart_alt"
                            iconSize: WidgetStore.si(14)
                            color: Theme.m3.on_surface ?? Theme.colors.text_primary
                        }
                        MouseArea {
                            id: sekaiResetMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WidgetStore.resetCardOptions(root.tileId)
                        }
                    }
                }

                // Sekai Weather options (style classic/minimal + units + toggles)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "weather"
                    spacing: WidgetStore.s(6)

                    SekaiChipGroup {
                        currentValue: String(root.opts.styleMode || "classic")
                        options: [
                            { id: "classic", label: "CLASSIC" },
                            { id: "minimal", label: "MINIMAL" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("weather", "styleMode", val)
                    }

                    SekaiChipGroup {
                        currentValue: String(root.opts.unitMode || "auto")
                        options: [
                            { id: "auto", label: "AUTO" },
                            { id: "c", label: "°C" },
                            { id: "f", label: "°F" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("weather", "unitMode", val)
                    }

                    SekaiOptionRow {
                        icon: "schedule"
                        label: "HOURLY STRIP"
                        stateLabel: (root.opts.showHourly !== false) ? "ON" : "OFF"
                        activeState: root.opts.showHourly !== false
                        onTriggered: WidgetStore.setCardOption("weather", "showHourly", !(root.opts.showHourly !== false))
                    }
                    SekaiOptionRow {
                        icon: "thermostat"
                        label: "HIGH / LOW RANGE"
                        stateLabel: (root.opts.showRange !== false) ? "ON" : "OFF"
                        activeState: root.opts.showRange !== false
                        onTriggered: WidgetStore.setCardOption("weather", "showRange", !(root.opts.showRange !== false))
                    }
                }

                // Sekai Media options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "media"
                    spacing: WidgetStore.s(6)

                    SekaiOptionRow {
                        icon: "album"
                        label: "ALBUM COVER"
                        stateLabel: (root.opts.showArt !== false) ? "ON" : "OFF"
                        activeState: root.opts.showArt !== false
                        onTriggered: WidgetStore.setCardOption("media", "showArt", !(root.opts.showArt !== false))
                    }
                    SekaiOptionRow {
                        icon: "radio_button_checked"
                        label: "ON AIR STICKER"
                        stateLabel: (root.opts.showBadge !== false) ? "ON" : "OFF"
                        activeState: root.opts.showBadge !== false
                        onTriggered: WidgetStore.setCardOption("media", "showBadge", !(root.opts.showBadge !== false))
                    }
                    SekaiOptionRow {
                        icon: "timer"
                        label: "TIMESTAMPS"
                        stateLabel: (root.opts.showDuration !== false) ? "ON" : "OFF"
                        activeState: root.opts.showDuration !== false
                        onTriggered: WidgetStore.setCardOption("media", "showDuration", !(root.opts.showDuration !== false))
                    }
                }

                // Sekai Resources options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "resources"
                    spacing: WidgetStore.s(6)

                    SekaiOptionRow {
                        icon: "speed"
                        label: "SYSTEM LOAD CHIP"
                        stateLabel: (root.opts.showLoadBadge !== false) ? "ON" : "OFF"
                        activeState: root.opts.showLoadBadge !== false
                        onTriggered: WidgetStore.setCardOption("resources", "showLoadBadge", !(root.opts.showLoadBadge !== false))
                    }
                    SekaiOptionRow {
                        icon: "info"
                        label: "DETAIL SUBTITLES"
                        stateLabel: (root.opts.showDetail !== false) ? "ON" : "OFF"
                        activeState: root.opts.showDetail !== false
                        onTriggered: WidgetStore.setCardOption("resources", "showDetail", !(root.opts.showDetail !== false))
                    }
                    SekaiOptionRow {
                        icon: "developer_board"
                        label: "COMPACT GPU NAME"
                        stateLabel: (root.opts.compactDetail === true) ? "ON" : "OFF"
                        activeState: root.opts.compactDetail === true
                        onTriggered: WidgetStore.setCardOption("resources", "compactDetail", !(root.opts.compactDetail === true))
                    }
                }

                // Sekai User options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "usercard"
                    spacing: WidgetStore.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(5)

                        SekaiOptionRow {
                            Layout.fillWidth: true
                            icon: "face"
                            label: "AVATAR…"
                            stateLabel: String(root.opts.customAvatar || "") !== "" ? "CUSTOM" : "PICK"
                            activeState: String(root.opts.customAvatar || "") !== ""
                            onTriggered: WidgetStore.pickImageOption("usercard", "customAvatar")
                        }
                        SekaiOptionRow {
                            visible: String(root.opts.customAvatar || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(62)
                            icon: "close"
                            label: "RST"
                            stateLabel: ""
                            activeState: false
                            onTriggered: WidgetStore.setCardOption("usercard", "customAvatar", "")
                        }
                    }
                    SekaiOptionRow {
                        icon: "badge"
                        label: "USER HEADER CHIP"
                        stateLabel: (root.opts.showBanner !== false) ? "ON" : "OFF"
                        activeState: root.opts.showBanner !== false
                        onTriggered: WidgetStore.setCardOption("usercard", "showBanner", !(root.opts.showBanner !== false))
                    }
                    SekaiOptionRow {
                        icon: "alternate_email"
                        label: "@HOSTNAME LINE"
                        stateLabel: (root.opts.showHost !== false) ? "ON" : "OFF"
                        activeState: root.opts.showHost !== false
                        onTriggered: WidgetStore.setCardOption("usercard", "showHost", !(root.opts.showHost !== false))
                    }
                    SekaiOptionRow {
                        icon: "tag"
                        label: "STAT KEYCAPS"
                        stateLabel: (root.opts.showBadges !== false) ? "ON" : "OFF"
                        activeState: root.opts.showBadges !== false
                        onTriggered: WidgetStore.setCardOption("usercard", "showBadges", !(root.opts.showBadges !== false))
                    }
                }

                // Sekai Image options (full sekai-pop ImageInspector toolset!)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "image"
                    spacing: WidgetStore.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(5)
                        SekaiOptionRow {
                            Layout.fillWidth: true
                            icon: "add_photo_alternate"
                            label: "CHOOSE IMAGE / GIF"
                            stateLabel: "BROWSE"
                            activeState: true
                            onTriggered: WidgetStore.pickImageOption("image", "customPath")
                        }
                        SekaiOptionRow {
                            visible: String(root.opts.customPath || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(58)
                            icon: "wallpaper"
                            label: "WALL"
                            stateLabel: ""
                            activeState: false
                            onTriggered: WidgetStore.setCardOption("image", "customPath", "")
                        }
                    }

                    SekaiChipGroup {
                        currentValue: String(root.opts.frameStyle || "polaroid")
                        options: [
                            { id: "polaroid", label: "POLAROID" },
                            { id: "card", label: "CARD" },
                            { id: "clean", label: "CLEAN" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "frameStyle", val)
                    }

                    SekaiChipGroup {
                        currentValue: String(root.opts.fitMode || "fill")
                        options: [
                            { id: "fill", label: "FILL" },
                            { id: "fit", label: "FIT" },
                            { id: "crop", label: "ZOOM" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "fitMode", val)
                    }

                    SekaiChipGroup {
                        visible: String(root.opts.fitMode || "fill") === "crop"
                        currentValue: String(Number(root.opts.zoom !== undefined ? root.opts.zoom : 1.0))
                        options: [
                            { id: "1", label: "1.0×" },
                            { id: "1.3", label: "1.3×" },
                            { id: "1.7", label: "1.7×" },
                            { id: "2.2", label: "2.2×" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "zoom", Number(val))
                    }

                    SekaiChipGroup {
                        currentValue: String(Number(root.opts.roundness !== undefined ? root.opts.roundness : 12))
                        options: [
                            { id: "0", label: "0PX" },
                            { id: "8", label: "8PX" },
                            { id: "18", label: "18PX" },
                            { id: "28", label: "28PX" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "roundness", Number(val))
                    }

                    SekaiChipGroup {
                        currentValue: String(Number(root.opts.opacityLevel !== undefined ? root.opts.opacityLevel : 1.0))
                        options: [
                            { id: "1", label: "100%" },
                            { id: "0.85", label: "85%" },
                            { id: "0.65", label: "65%" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "opacityLevel", Number(val))
                    }

                    SekaiOptionRow {
                        icon: "border_outer"
                        label: "FRAME OUTLINE"
                        stateLabel: (root.opts.showBorder !== false) ? "ON" : "OFF"
                        activeState: root.opts.showBorder !== false
                        onTriggered: WidgetStore.setCardOption("image", "showBorder", !(root.opts.showBorder !== false))
                    }
                    SekaiOptionRow {
                        visible: String(root.opts.frameStyle || "polaroid") === "polaroid"
                        icon: "subtitles"
                        label: "FILENAME CAPTION"
                        stateLabel: (root.opts.showCaption !== false) ? "ON" : "OFF"
                        activeState: root.opts.showCaption !== false
                        onTriggered: WidgetStore.setCardOption("image", "showCaption", !(root.opts.showCaption !== false))
                    }
                    SekaiOptionRow {
                        visible: String(root.opts.frameStyle || "polaroid") !== "card"
                        icon: "rotate_right"
                        label: "POLAROID TILT"
                        stateLabel: (root.opts.tilted !== false) ? "ON" : "OFF"
                        activeState: root.opts.tilted !== false
                        onTriggered: WidgetStore.setCardOption("image", "tilted", !(root.opts.tilted !== false))
                    }
                }

                // Clock & Music styles
                SekaiOptionRow {
                    visible: root.tileId === "time"
                    icon: "schedule"
                    label: WidgetStore.clockStyle === "cookie" ? "USE DIGITAL CLOCK" : "USE COOKIE CLOCK"
                    stateLabel: WidgetStore.clockStyle === "cookie" ? "COOKIE" : "DIGITAL"
                    activeState: true
                    onTriggered: WidgetStore.toggleClockStyle()
                }
                SekaiOptionRow {
                    visible: root.tileId === "music"
                    icon: "music_note"
                    label: WidgetStore.musicStyle === "sticker" ? "USE CARD MODE" : "USE STICKER MODE"
                    stateLabel: WidgetStore.musicStyle === "sticker" ? "STICKER" : "CARD"
                    activeState: true
                    onTriggered: WidgetStore.toggleMusicStyle()
                }

                // Network / Storage cycle
                SekaiOptionRow {
                    visible: root.tileId === "network" && (WidgetTelemetry.netInterfaces || []).length > 0
                    icon: "swap_horiz"
                    label: "CYCLE INTERFACE"
                    stateLabel: "NEXT"
                    activeState: false
                    onTriggered: {
                        const list = (WidgetTelemetry.netInterfaces || []).map(i => i.name);
                        list.push("__all__");
                        const cur = WidgetStore.preferredNetInterface || WidgetTelemetry.defaultInterface || list[0];
                        const idx = list.indexOf(cur);
                        WidgetStore.setPreferredNetInterface(list[(idx + 1) % list.length]);
                    }
                }
                SekaiOptionRow {
                    visible: root.tileId === "storage" && (WidgetTelemetry.disks || []).length > 1
                    icon: "hard_drive"
                    label: "CYCLE DISK DEVICE"
                    stateLabel: "NEXT"
                    activeState: false
                    onTriggered: {
                        const devs = (WidgetTelemetry.disks || []).map(d => d.device);
                        const cur = WidgetStore.preferredDiskDevice || devs[0];
                        const idx = devs.indexOf(cur);
                        WidgetStore.setPreferredDiskDevice(devs[(idx + 1) % devs.length]);
                    }
                }

                // Footer keys
                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(6)

                    SekaiPill {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(30)
                        cornerRadius: WidgetStore.s(10)
                        borderWidth: WidgetStore.s(2)
                        ringWidth: WidgetStore.s(1.5)
                        shadowDy: WidgetStore.s(2)
                        pressed: unpinMouse.pressed
                        fillColor: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg

                        Row {
                            anchors.centerIn: parent; spacing: WidgetStore.s(4)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: root.pinned ? "dock_to_left" : "pin_drop"; iconSize: WidgetStore.si(13); color: Theme.m3.on_surface ?? Theme.colors.text_primary }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.pinned ? "UNPIN" : "PIN"; color: Theme.m3.on_surface ?? Theme.colors.text_primary; font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(9.5); font.weight: Font.ExtraBold; renderType: Text.NativeRendering }
                        }
                        MouseArea {
                            id: unpinMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const id = root.tileId;
                                root.closed();
                                WidgetStore.togglePin(id, root.screenName);
                            }
                        }
                    }

                    SekaiPill {
                        visible: WidgetStore.desktopCardIds.length > 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(30)
                        cornerRadius: WidgetStore.s(10)
                        borderWidth: WidgetStore.s(2)
                        ringWidth: WidgetStore.s(1.5)
                        shadowDy: WidgetStore.s(2)
                        pressed: retMouse.pressed
                        fillColor: Theme.m3.error_container ?? "#5f1a25"

                        Row {
                            anchors.centerIn: parent; spacing: WidgetStore.s(4)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "move_down"; iconSize: WidgetStore.si(13); color: Theme.m3.on_error_container ?? "#ffdada" }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "CLEAR"; color: Theme.m3.on_error_container ?? "#ffdada"; font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(9.5); font.weight: Font.ExtraBold; renderType: Text.NativeRendering }
                        }
                        MouseArea {
                            id: retMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closed();
                                WidgetStore.returnAllToSidebar();
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== Shared small subcomponents =====
    component M3ChipGroup: ColumnLayout {
        property string title: ""
        property string currentValue: ""
        property var options: []
        signal picked(string val)

        Layout.fillWidth: true
        spacing: WidgetStore.s(4)

        Text {
            visible: title !== ""
            text: title
            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(10.5)
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(4)

            Repeater {
                model: options
                Rectangle {
                    required property var modelData
                    readonly property bool act: currentValue === String(modelData.id)
                    Layout.fillWidth: true
                    Layout.preferredHeight: WidgetStore.s(28)
                    radius: WidgetStore.s(14)
                    color: act
                        ? (Theme.m3.primary ?? Theme.accent)
                        : (cgMouse.containsMouse
                            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.14)
                            : (Theme.m3.surface_container_high ?? Theme.colors.hover_bg))

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: act ? (Theme.m3.on_primary ?? "#101014") : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(9.5)
                        font.weight: act ? Font.Bold : Font.Medium
                        renderType: Text.NativeRendering
                    }
                    MouseArea {
                        id: cgMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picked(String(modelData.id))
                    }
                }
            }
        }
    }

    component M3ActionPill: Rectangle {
        property string icon: ""
        property string label: ""
        property bool tonal: false
        property bool danger: false
        signal triggered()

        Layout.preferredHeight: WidgetStore.s(31)
        radius: WidgetStore.s(15.5)
        color: danger
            ? Qt.alpha(Theme.m3.error_container ?? "#7f1d1d", actMouse.containsMouse ? 0.85 : 0.65)
            : (tonal
                ? (Theme.m3.secondary_container ?? Theme.colors.hover_bg)
                : (actMouse.containsMouse ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.16) : (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)))

        Row {
            anchors.centerIn: parent
            spacing: WidgetStore.s(5)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: icon
                iconSize: WidgetStore.si(14)
                color: danger
                    ? (Theme.m3.on_error_container ?? "#ffdada")
                    : (tonal ? (Theme.m3.on_secondary_container ?? Theme.colors.text_primary) : (Theme.m3.on_surface ?? Theme.colors.text_primary))
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: danger
                    ? (Theme.m3.on_error_container ?? "#ffdada")
                    : (tonal ? (Theme.m3.on_secondary_container ?? Theme.colors.text_primary) : (Theme.m3.on_surface ?? Theme.colors.text_primary))
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(10.5)
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }
        MouseArea { id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: triggered() }
    }

    component M3ToggleRow: Rectangle {
        property string icon: ""
        property string label: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: visible ? WidgetStore.s(32) : 0
        radius: WidgetStore.s(14)
        color: rowClick.containsMouse
            ? Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.14)
            : (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)

        RowLayout {
            anchors { fill: parent; leftMargin: WidgetStore.s(10); rightMargin: WidgetStore.s(10) }
            spacing: WidgetStore.s(8)
            MaterialSymbol { text: icon; iconSize: WidgetStore.si(15); color: Theme.m3.primary ?? Theme.accent }
            Text {
                Layout.fillWidth: true; text: label
                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(11); font.weight: Font.Medium
                renderType: Text.NativeRendering; elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredWidth: WidgetStore.s(30)
                Layout.preferredHeight: WidgetStore.s(17)
                radius: height / 2
                color: checked ? (Theme.m3.primary ?? Theme.accent) : Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.25)
                Rectangle {
                    width: WidgetStore.s(11); height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: checked ? (parent.width - width - WidgetStore.s(3)) : WidgetStore.s(3)
                    color: checked ? (Theme.m3.on_primary ?? "#101014") : "#ffffff"
                    Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                }
            }
        }
        MouseArea { id: rowClick; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggled() }
    }

    component SekaiChipGroup: RowLayout {
        property string currentValue: ""
        property var options: []
        signal picked(string val)

        Layout.fillWidth: true
        spacing: WidgetStore.s(4)

        Repeater {
            model: options
            SekaiPill {
                required property var modelData
                readonly property bool act: currentValue === String(modelData.id)
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(26)
                cornerRadius: WidgetStore.s(8)
                borderWidth: WidgetStore.s(1.6)
                ringWidth: WidgetStore.s(1.2)
                shadowDy: WidgetStore.s(1.5)
                pressed: scMouse.pressed
                fillColor: act ? (Theme.m3.primary ?? Theme.accent) : (Theme.m3.surface_container_high ?? Theme.colors.hover_bg)
                Text {
                    anchors.centerIn: parent; text: modelData.label
                    color: act ? (Theme.m3.on_primary ?? "#101014") : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(8.8); font.weight: Font.ExtraBold
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: scMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: picked(String(modelData.id))
                }
            }
        }
    }

    component SekaiOptionRow: SekaiPill {
        property string icon: ""
        property string label: ""
        property string stateLabel: ""
        property bool activeState: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: visible ? WidgetStore.s(30) : 0
        cornerRadius: WidgetStore.s(10)
        borderWidth: WidgetStore.s(1.8)
        ringWidth: WidgetStore.s(1.5)
        shadowDy: WidgetStore.s(2)
        pressed: sRowMouse.pressed
        fillColor: Theme.m3.surface_container_high ?? Theme.colors.hover_bg

        RowLayout {
            anchors { fill: parent; leftMargin: WidgetStore.s(9); rightMargin: WidgetStore.s(8) }
            spacing: WidgetStore.s(6)
            MaterialSymbol { text: icon; iconSize: WidgetStore.si(14); color: Theme.m3.primary ?? Theme.accent }
            Text {
                Layout.fillWidth: true; text: label
                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(9); font.weight: Font.ExtraBold
                font.letterSpacing: 0.4; renderType: Text.NativeRendering; elide: Text.ElideRight
            }
            Rectangle {
                visible: stateLabel !== ""
                Layout.preferredWidth: stTxt.implicitWidth + WidgetStore.s(10)
                Layout.preferredHeight: WidgetStore.s(17)
                radius: WidgetStore.s(5)
                color: activeState ? (Theme.m3.primary ?? Theme.accent) : Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.14)
                Text {
                    id: stTxt; anchors.centerIn: parent; text: stateLabel
                    color: activeState ? (Theme.m3.on_primary ?? "#101014") : (Theme.m3.on_surface ?? Theme.colors.text_primary)
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(8); font.weight: Font.ExtraBold
                    renderType: Text.NativeRendering
                }
            }
        }
        MouseArea { id: sRowMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: triggered() }
    }
}
