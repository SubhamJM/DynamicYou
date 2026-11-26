import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../services"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog

// Unified borderless Material 3 options panel for all widget sources
Item {
    id: root

    property string tileId: ""
    property bool onDesktop: true
    property string screenName: ""
    property var notchRoot: null
    signal closed()

    readonly property var def: root.tileId !== "" ? Catalog.definitionFor(root.tileId) : null
    readonly property string sourceTitle: def && def.source ? Catalog.sourceLabel(def.source) : "Widget"
    readonly property var opts: root.tileId !== "" ? WidgetStore.cardOptions(root.tileId) : ({})
    readonly property var sizeModes: (def && Array.isArray(def.sizeModes)) ? def.sizeModes : []
    readonly property string currentSize: String(opts.sizeMode || (sizeModes.length > 0 ? sizeModes[0] : ""))
    readonly property bool pinned: root.tileId !== "" && WidgetStore.isPinned(root.tileId)

    implicitWidth: WidgetStore.s(296)
    implicitHeight: Math.min(WidgetStore.s(700), m3Col.implicitHeight + WidgetStore.s(26))
    width: implicitWidth
    height: implicitHeight

    function sizeLabel(mode) {
        if (root.tileId === "end4Resources") {
            return mode === "3x1" ? "Vertical" : "Horizontal";
        }
        return mode.replace("x", "×");
    }

    Item {
        id: m3Card
        visible: root.tileId !== ""
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: WidgetStore.s(24)
            color: Theme.m3.surface_container_highest ?? Theme.colors.card_bg

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

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(10)

                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(32)
                        Layout.preferredHeight: WidgetStore.s(32)
                        radius: WidgetStore.s(10)
                        color: Theme.m3.primary ?? Theme.accent

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
                            text: root.sourceTitle + " · Options"
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

                // Size Mode selector
                M3ChipGroup {
                    visible: root.sizeModes.length > 0
                    title: root.tileId === "end4Resources" ? "Layout" : "Widget size"
                    currentValue: root.currentSize
                    options: root.sizeModes.map(m => ({ id: m, label: root.sizeLabel(m) }))
                    onPicked: (val) => WidgetStore.setCardOption(root.tileId, "sizeMode", val)
                }

                // Weather & end4Weather options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "weather" || root.tileId === "end4Weather"
                    spacing: WidgetStore.s(6)

                    M3ChipGroup {
                        visible: root.tileId === "weather"
                        title: "Backdrop"
                        currentValue: String(root.opts.styleMode || "material")
                        options: [
                            { id: "material", label: "Material" },
                            { id: "glass", label: "Glass" },
                            { id: "blur", label: "Blur" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("weather", "styleMode", val)
                    }
                    M3ChipGroup {
                        title: "Units"
                        currentValue: String(root.opts.unitMode || "auto")
                        options: [
                            { id: "auto", label: "Auto" },
                            { id: "c", label: "°C" },
                            { id: "f", label: "°F" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption(root.tileId, "unitMode", val)
                    }
                }

                // Matushell Media options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "media"
                    spacing: WidgetStore.s(6)

                    M3ToggleRow {
                        icon: "album"
                        label: "Album Cover"
                        checked: root.opts.showArt !== false
                        onToggled: WidgetStore.setCardOption("media", "showArt", !(root.opts.showArt !== false))
                    }
                    M3ToggleRow {
                        icon: "radio_button_checked"
                        label: "On Air Sticker"
                        checked: root.opts.showBadge !== false
                        onToggled: WidgetStore.setCardOption("media", "showBadge", !(root.opts.showBadge !== false))
                    }
                    M3ToggleRow {
                        icon: "timer"
                        label: "Timestamps"
                        checked: root.opts.showDuration !== false
                        onToggled: WidgetStore.setCardOption("media", "showDuration", !(root.opts.showDuration !== false))
                    }
                }

                // Matushell Background Visualiser options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "bgVisualiser"
                    spacing: WidgetStore.s(6)

                    M3ChipGroup {
                        title: "Visualiser Style"
                        currentValue: String(root.opts.visStyle || "wave_outlined")
                        options: [
                            { id: "wave_outlined", label: "Outlined" },
                            { id: "wave", label: "Wave" },
                            { id: "bars", label: "Bars" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "visStyle", val)
                    }

                    M3ChipGroup {
                        title: "Palette"
                        currentValue: String(root.opts.colorMode || "inverse")
                        options: [
                            { id: "inverse", label: "Inverse" },
                            { id: "primary", label: "Primary" },
                            { id: "secondary", label: "Secondary" },
                            { id: "tertiary", label: "Tertiary" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "colorMode", val)
                    }

                    M3ChipGroup {
                        title: "Wave Height"
                        currentValue: String(Number(root.opts.heightScale !== undefined ? root.opts.heightScale : 0.42))
                        options: [
                            { id: "0.28", label: "Low" },
                            { id: "0.42", label: "Default" },
                            { id: "0.58", label: "Tall" },
                            { id: "0.74", label: "Hero" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "heightScale", Number(val))
                    }

                    M3ChipGroup {
                        title: "Bars"
                        currentValue: String(Number(root.opts.barCount || 60))
                        options: [
                            { id: "32", label: "32" },
                            { id: "48", label: "48" },
                            { id: "60", label: "60" },
                            { id: "80", label: "80" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "barCount", Number(val))
                    }

                    M3ChipGroup {
                        visible: String(root.opts.visStyle || "wave_outlined") === "bars"
                        title: "Bar Rounding"
                        currentValue: String(Number(root.opts.rounding !== undefined ? root.opts.rounding : 6))
                        options: [
                            { id: "0", label: "Flat" },
                            { id: "4", label: "4px" },
                            { id: "8", label: "8px" },
                            { id: "14", label: "Pill" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "rounding", Number(val))
                    }

                    M3ChipGroup {
                        visible: String(root.opts.visStyle || "wave_outlined") === "bars"
                        title: "Bar Spacing"
                        currentValue: String(Number(root.opts.spacing !== undefined ? root.opts.spacing : 4))
                        options: [
                            { id: "0", label: "0px" },
                            { id: "2", label: "2px" },
                            { id: "4", label: "4px" },
                            { id: "8", label: "8px" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "spacing", Number(val))
                    }

                    M3ChipGroup {
                        title: "Gain"
                        currentValue: String(Number(root.opts.gain || 0.55))
                        options: [
                            { id: "0.35", label: "Low" },
                            { id: "0.55", label: "Mid" },
                            { id: "0.85", label: "High" },
                            { id: "1.1", label: "Max" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "gain", Number(val))
                    }

                    M3ChipGroup {
                        title: "Edge Margin"
                        currentValue: String(Number(root.opts.edgeInset !== undefined ? root.opts.edgeInset : 0))
                        options: [
                            { id: "0", label: "Full Edge" },
                            { id: "24", label: "24px" },
                            { id: "64", label: "64px" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "edgeInset", Number(val))
                    }

                    M3ChipGroup {
                        title: "Opacity"
                        currentValue: String(Number(root.opts.visOpacity !== undefined ? root.opts.visOpacity : 0.70))
                        options: [
                            { id: "0.45", label: "45%" },
                            { id: "0.7", label: "70%" },
                            { id: "0.92", label: "92%" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "visOpacity", Number(val))
                    }

                    M3ChipGroup {
                        title: "Refresh Rate"
                        currentValue: String(Number(root.opts.fps || 45))
                        options: [
                            { id: "30", label: "30 fps" },
                            { id: "45", label: "45 fps" },
                            { id: "60", label: "60 fps" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("bgVisualiser", "fps", Number(val))
                    }

                    M3ToggleRow {
                        icon: "graphic_eq"
                        label: "Always Visible (Demo Wave)"
                        checked: root.opts.alwaysVisible === true
                        onToggled: WidgetStore.setCardOption("bgVisualiser", "alwaysVisible", !(root.opts.alwaysVisible === true))
                    }
                }

                // Matushell Resources options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "resources"
                    spacing: WidgetStore.s(8)

                    M3ChipGroup {
                        title: "Backdrop"
                        currentValue: String(root.opts.styleMode || "material")
                        options: [
                            { id: "material", label: "Material" },
                            { id: "glass", label: "Glass" },
                            { id: "blur", label: "Blur" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("resources", "styleMode", val)
                    }

                    M3ChipGroup {
                        title: "Fill Style"
                        currentValue: String(root.opts.fillMode || "wave")
                        options: [
                            { id: "wave", label: "Wave" },
                            { id: "linear", label: "Linear" },
                            { id: "shape", label: "Shape" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("resources", "fillMode", val)
                    }

                    M3ToggleRow {
                        icon: "battery_full"
                        label: "Include Battery Card"
                        checked: root.opts.showBattery === true
                        onToggled: WidgetStore.setCardOption("resources", "showBattery", !(root.opts.showBattery === true))
                    }
                }

                // Matushell Usercard options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "usercard"
                    spacing: WidgetStore.s(8)

                    M3ChipGroup {
                        title: "Backdrop"
                        currentValue: String(root.opts.styleMode || "material")
                        options: [
                            { id: "material", label: "Material" },
                            { id: "glass", label: "Glass" },
                            { id: "blur", label: "Blur" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("usercard", "styleMode", val)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)
                        M3ActionPill {
                            Layout.fillWidth: true
                            icon: "face"
                            label: "Choose Avatar…"
                            tonal: true
                            onTriggered: WidgetStore.pickImageOption("usercard", "customAvatar")
                        }
                        M3ActionPill {
                            visible: String(root.opts.customAvatar || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(64)
                            icon: "close"
                            label: "Clear"
                            onTriggered: WidgetStore.setCardOption("usercard", "customAvatar", "")
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
                            onTriggered: WidgetStore.pickImageOption("usercard", "customBanner")
                        }
                        M3ActionPill {
                            visible: String(root.opts.customBanner || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(64)
                            icon: "close"
                            label: "Clear"
                            onTriggered: WidgetStore.setCardOption("usercard", "customBanner", "")
                        }
                    }
                }

                // Matushell Image options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "image"
                    spacing: WidgetStore.s(8)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)
                        M3ActionPill {
                            Layout.fillWidth: true
                            icon: "add_photo_alternate"
                            label: "Choose Image / GIF…"
                            tonal: true
                            onTriggered: WidgetStore.pickImageOption("image", "customPath")
                        }
                        M3ActionPill {
                            visible: String(root.opts.customPath || "") !== ""
                            Layout.preferredWidth: WidgetStore.s(64)
                            icon: "close"
                            label: "Reset"
                            onTriggered: WidgetStore.setCardOption("image", "customPath", "")
                        }
                    }

                    M3ChipGroup {
                        title: "Frame"
                        currentValue: String(root.opts.frameStyle || "polaroid")
                        options: [
                            { id: "polaroid", label: "Polaroid" },
                            { id: "card", label: "Card" },
                            { id: "clean", label: "Clean" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "frameStyle", val)
                    }

                    M3ChipGroup {
                        title: "Fit"
                        currentValue: String(root.opts.fitMode || "fill")
                        options: [
                            { id: "fill", label: "Fill" },
                            { id: "fit", label: "Fit" },
                            { id: "crop", label: "Zoom" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "fitMode", val)
                    }

                    M3ChipGroup {
                        visible: String(root.opts.fitMode || "fill") === "crop"
                        title: "Zoom"
                        currentValue: String(Number(root.opts.zoom !== undefined ? root.opts.zoom : 1.0))
                        options: [
                            { id: "1", label: "1.0×" },
                            { id: "1.3", label: "1.3×" },
                            { id: "1.7", label: "1.7×" },
                            { id: "2.2", label: "2.2×" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "zoom", Number(val))
                    }

                    M3ChipGroup {
                        title: "Corners"
                        currentValue: String(Number(root.opts.roundness !== undefined ? root.opts.roundness : 12))
                        options: [
                            { id: "0", label: "0px" },
                            { id: "8", label: "8px" },
                            { id: "18", label: "18px" },
                            { id: "28", label: "28px" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "roundness", Number(val))
                    }

                    M3ChipGroup {
                        title: "Opacity"
                        currentValue: String(Number(root.opts.opacityLevel !== undefined ? root.opts.opacityLevel : 1.0))
                        options: [
                            { id: "1", label: "100%" },
                            { id: "0.85", label: "85%" },
                            { id: "0.65", label: "65%" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("image", "opacityLevel", Number(val))
                    }

                    M3ToggleRow {
                        icon: "border_outer"
                        label: "Frame Outline"
                        checked: root.opts.showBorder !== false
                        onToggled: WidgetStore.setCardOption("image", "showBorder", !(root.opts.showBorder !== false))
                    }
                    M3ToggleRow {
                        visible: String(root.opts.frameStyle || "polaroid") === "polaroid"
                        icon: "subtitles"
                        label: "Filename Caption"
                        checked: root.opts.showCaption !== false
                        onToggled: WidgetStore.setCardOption("image", "showCaption", !(root.opts.showCaption !== false))
                    }
                    M3ToggleRow {
                        visible: String(root.opts.frameStyle || "polaroid") !== "card"
                        icon: "rotate_right"
                        label: "Polaroid Tilt"
                        checked: root.opts.tilted !== false
                        onToggled: WidgetStore.setCardOption("image", "tilted", !(root.opts.tilted !== false))
                    }
                }

                // end4Media options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "end4Media" && root.currentSize === "1x3"
                    spacing: WidgetStore.s(6)
                    M3ToggleRow {
                        icon: "lyrics"
                        label: "Lyrics Drawer"
                        checked: root.opts.showLyrics === true
                        onToggled: WidgetStore.setCardOption("end4Media", "showLyrics", !(root.opts.showLyrics === true))
                    }
                    M3ToggleRow {
                        icon: "title"
                        label: "Show Titles"
                        checked: root.opts.showTitles !== false
                        onToggled: WidgetStore.setCardOption("end4Media", "showTitles", !(root.opts.showTitles !== false))
                    }
                    M3ToggleRow {
                        icon: "tune"
                        label: "Show Controls"
                        checked: root.opts.showControls !== false
                        onToggled: WidgetStore.setCardOption("end4Media", "showControls", !(root.opts.showControls !== false))
                    }
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

                // end4Image options
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
                            Layout.preferredWidth: WidgetStore.s(64)
                            icon: "close"
                            label: "Reset"
                            onTriggered: WidgetStore.setCardOption("end4Image", "customPath", "")
                        }
                    }

                    M3ChipGroup {
                        title: "Shape"
                        currentValue: String(root.opts.shapeMode || "rounded")
                        options: [
                            { id: "rounded", label: "Rounded" },
                            { id: "circle", label: "Circle" },
                            { id: "cookie", label: "Cookie" },
                            { id: "gem", label: "Gem" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("end4Image", "shapeMode", val)
                    }

                    M3ChipGroup {
                        title: "Fit"
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

                // GitHub contribution options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "github"
                    spacing: WidgetStore.s(8)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(36)
                        radius: WidgetStore.s(14)
                        color: Theme.m3.surface_container_high ?? Theme.colors.hover_bg
                        border.width: ghUserInput.activeFocus ? Math.max(1, WidgetStore.s(1.4)) : 0
                        border.color: Theme.m3.primary ?? Theme.accent

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: ghUserInput.forceActiveFocus()
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: WidgetStore.s(10); rightMargin: WidgetStore.s(6) }
                            spacing: WidgetStore.s(6)

                            MaterialSymbol { text: "alternate_email"; iconSize: WidgetStore.si(14); color: Theme.m3.primary ?? Theme.accent }
                            TextInput {
                                id: ghUserInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                selectByMouse: true
                                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(11)
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                Binding {
                                    when: !ghUserInput.activeFocus
                                    target: ghUserInput
                                    property: "text"
                                    value: String(root.opts.user || "")
                                }
                                onAccepted: WidgetStore.setCardOption("github", "user", text.trim().replace(/^@/, ""))
                                Text {
                                    visible: parent.text === ""
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "GitHub username"
                                    color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                    font: parent.font
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: WidgetStore.s(42)
                                Layout.preferredHeight: WidgetStore.s(22)
                                radius: WidgetStore.s(11)
                                color: Theme.m3.primary ?? Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: "Set"
                                    color: Theme.m3.on_primary ?? "#101014"
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(9.5)
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ghUserInput.accepted()
                                }
                            }
                        }
                    }

                    M3ChipGroup {
                        title: "Heatmap Palette"
                        currentValue: String(root.opts.colorMode || "accent")
                        options: [
                            { id: "accent", label: "Shell Accent" },
                            { id: "github", label: "GitHub Green" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("github", "colorMode", val)
                    }
                }

                // Nothing Greeting options
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "nothingGreeting"
                    spacing: WidgetStore.s(6)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: WidgetStore.s(36)
                        radius: WidgetStore.s(14)
                        color: Theme.m3.surface_container_high ?? Theme.colors.hover_bg
                        border.width: greetNameInput.activeFocus ? Math.max(1, WidgetStore.s(1.4)) : 0
                        border.color: Theme.m3.primary ?? Theme.accent

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: greetNameInput.forceActiveFocus()
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: WidgetStore.s(10); rightMargin: WidgetStore.s(6) }
                            spacing: WidgetStore.s(6)

                            MaterialSymbol { text: "badge"; iconSize: WidgetStore.si(14); color: Theme.m3.primary ?? Theme.accent }
                            TextInput {
                                id: greetNameInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                selectByMouse: true
                                color: Theme.m3.on_surface ?? Theme.colors.text_primary
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(11)
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                Binding {
                                    when: !greetNameInput.activeFocus
                                    target: greetNameInput
                                    property: "text"
                                    value: String(root.opts.customName || "")
                                }
                                onAccepted: WidgetStore.setCardOption("nothingGreeting", "customName", text.trim())
                                Text {
                                    visible: parent.text === ""
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Display name (default user)"
                                    color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                                    font: parent.font
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: WidgetStore.s(42)
                                Layout.preferredHeight: WidgetStore.s(22)
                                radius: WidgetStore.s(11)
                                color: Theme.m3.primary ?? Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: "Set"
                                    color: Theme.m3.on_primary ?? "#101014"
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: WidgetStore.si(9.5)
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: greetNameInput.accepted()
                                }
                            }
                        }
                    }

                    M3ToggleRow {
                        icon: "schedule"
                        label: "24-Hour Clock"
                        checked: root.opts.use24h !== false
                        onToggled: WidgetStore.setCardOption("nothingGreeting", "use24h", !(root.opts.use24h !== false))
                    }
                    M3ToggleRow {
                        icon: "blur_on"
                        label: "Blinking Colon"
                        checked: root.opts.blinkColon !== false
                        onToggled: WidgetStore.setCardOption("nothingGreeting", "blinkColon", !(root.opts.blinkColon !== false))
                    }
                    M3ToggleRow {
                        icon: "partly_cloudy_day"
                        label: "Weather Meta"
                        checked: root.opts.showWeatherMeta !== false
                        onToggled: WidgetStore.setCardOption("nothingGreeting", "showWeatherMeta", !(root.opts.showWeatherMeta !== false))
                    }
                }

                // Nothing Resources 1x1 metric switch
                M3ChipGroup {
                    visible: root.tileId === "nothingResources" && root.currentSize === "1x1"
                    title: "Single Ring Metric"
                    currentValue: String(root.opts.singleMetric || "cpu")
                    options: [
                        { id: "cpu", label: "CPU %" },
                        { id: "ram", label: "RAM %" }
                    ]
                    onPicked: (val) => WidgetStore.setCardOption("nothingResources", "singleMetric", val)
                }

                // Nothing Player toggles
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "nothingPlayer"
                    spacing: WidgetStore.s(6)

                    M3ToggleRow {
                        icon: "album"
                        label: "Spin Vinyl Art"
                        checked: root.opts.spinArt !== false
                        onToggled: WidgetStore.setCardOption("nothingPlayer", "spinArt", !(root.opts.spinArt !== false))
                    }
                    M3ToggleRow {
                        icon: "grain"
                        label: "Dot-Matrix Cover"
                        checked: root.opts.dotMatrixArt !== false
                        onToggled: WidgetStore.setCardOption("nothingPlayer", "dotMatrixArt", !(root.opts.dotMatrixArt !== false))
                    }
                }

                // Nothing Glyph shared accent style
                M3ChipGroup {
                    visible: root.tileId.indexOf("nothing") === 0
                    title: "Nothing Accent"
                    currentValue: String(root.opts.accentMode || "glyph")
                    options: [
                        { id: "glyph", label: "Nothing Red" },
                        { id: "shell", label: "Shell Accent" }
                    ]
                    onPicked: (val) => WidgetStore.setCardOption(root.tileId, "accentMode", val)
                }

                // Dynamic You Clock / Music / Network / Storage options
                M3ChipGroup {
                    visible: root.tileId === "time"
                    title: "Clock Face"
                    currentValue: WidgetStore.clockStyle
                    options: [
                        { id: "cookie", label: "Cookie" },
                        { id: "digital", label: "Digital" }
                    ]
                    onPicked: (val) => {
                        if (WidgetStore.clockStyle !== val) WidgetStore.toggleClockStyle();
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.tileId === "music"
                    spacing: WidgetStore.s(8)

                    M3ChipGroup {
                        title: "Display Style"
                        currentValue: WidgetStore.musicStyle
                        options: [
                            { id: "sticker", label: "Sticker (OG)" },
                            { id: "card", label: "Card" }
                        ]
                        onPicked: (val) => {
                            if (WidgetStore.musicStyle !== val) WidgetStore.toggleMusicStyle();
                        }
                    }

                    M3ChipGroup {
                        visible: WidgetStore.musicStyle === "sticker"
                        title: "Song Name Tag"
                        currentValue: String(root.opts.tagMode || "always")
                        options: [
                            { id: "always", label: "Always" },
                            { id: "hover", label: "On Hover" },
                            { id: "off", label: "Hidden" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("music", "tagMode", val)
                    }

                    M3ChipGroup {
                        title: "Lyrics Size"
                        currentValue: String(root.opts.textScale || "md")
                        options: [
                            { id: "sm", label: "Compact" },
                            { id: "md", label: "Default" },
                            { id: "lg", label: "Large" }
                        ]
                        onPicked: (val) => WidgetStore.setCardOption("music", "textScale", val)
                    }

                    M3ToggleRow {
                        icon: "animation"
                        label: "Word-by-Word Bounce"
                        checked: root.opts.wordByWord !== false
                        onToggled: WidgetStore.setCardOption("music", "wordByWord", !(root.opts.wordByWord !== false))
                    }

                    M3ToggleRow {
                        icon: "pause_circle"
                        label: "Dim When Paused"
                        checked: root.opts.dimPaused !== false
                        onToggled: WidgetStore.setCardOption("music", "dimPaused", !(root.opts.dimPaused !== false))
                    }

                    M3ActionPill {
                        Layout.fillWidth: true
                        icon: "refresh"
                        label: "Refresh Lyrics"
                        tonal: true
                        onTriggered: LyricsService.retrySearch()
                    }
                }

                M3ActionPill {
                    visible: root.tileId === "network" && (WidgetTelemetry.netInterfaces || []).length > 0
                    Layout.fillWidth: true
                    icon: "swap_horiz"
                    label: "Cycle Network Interface"
                    tonal: true
                    onTriggered: {
                        const list = (WidgetTelemetry.netInterfaces || []).map(i => i.name);
                        list.push("__all__");
                        const cur = WidgetStore.preferredNetInterface || WidgetTelemetry.defaultInterface || list[0];
                        const idx = list.indexOf(cur);
                        WidgetStore.setPreferredNetInterface(list[(idx + 1) % list.length]);
                    }
                }

                M3ActionPill {
                    visible: root.tileId === "storage" && (WidgetTelemetry.disks || []).length > 1
                    Layout.fillWidth: true
                    icon: "hard_drive"
                    label: "Cycle Disk Device"
                    tonal: true
                    onTriggered: {
                        const devs = (WidgetTelemetry.disks || []).map(d => d.device);
                        const cur = WidgetStore.preferredDiskDevice || devs[0];
                        const idx = devs.indexOf(cur);
                        WidgetStore.setPreferredDiskDevice(devs[(idx + 1) % devs.length]);
                    }
                }

                // Drop Shadow option (resizable expressive & dot-matrix cards)
                M3ToggleRow {
                    visible: root.tileId.indexOf("end4") === 0 || root.tileId.indexOf("nothing") === 0 || root.tileId === "github"
                    icon: "shadow"
                    label: "Drop Shadow"
                    checked: root.opts.showShadow !== false
                    onToggled: WidgetStore.setCardOption(root.tileId, "showShadow", !(root.opts.showShadow !== false))
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.alpha(Theme.m3.outline_variant ?? "#4a5c72", 0.32)
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

    component M3ChipGroup: ColumnLayout {
        property string title: ""
        property string currentValue: ""
        property var options: []
        signal picked(string val)

        Layout.fillWidth: true
        spacing: WidgetStore.s(3)

        Text {
            visible: title !== ""
            text: title
            color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(10)
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
                    Layout.preferredHeight: WidgetStore.s(25)
                    radius: WidgetStore.s(12.5)
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
}
