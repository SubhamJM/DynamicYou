pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../" // Dynamic You Theme singleton

Item {
    id: root

    property string currentTheme: "dark"
    readonly property bool isDark: true
    readonly property string effectiveMode: "dark"

    // 1:1 Dynamic You Theme.m3 bindings -> Matushell Theming role names
    readonly property color primary: Theme.m3.primary ?? Theme.accent ?? "#c4b7ff"
    readonly property color primaryOn: Theme.m3.on_primary ?? Theme.onAccent ?? "#1e1b2e"
    readonly property color primaryContainer: Theme.m3.primary_container ?? Theme.primaryContainer ?? "#433a75"
    readonly property color primaryContainerOn: Theme.m3.on_primary_container ?? Theme.fgPrimaryContainer ?? "#e6deff"
    readonly property color primaryFixed: Theme.m3.primary_fixed ?? primaryContainer
    readonly property color primaryFixedDim: Theme.m3.primary_fixed_dim ?? primary
    readonly property color onPrimaryFixed: Theme.m3.on_primary_fixed ?? primaryOn
    readonly property color onPrimaryFixedVariant: Theme.m3.on_primary_fixed_variant ?? primaryContainerOn

    readonly property color secondary: Theme.m3.secondary ?? primary
    readonly property color secondaryOn: Theme.m3.on_secondary ?? primaryOn
    readonly property color secondaryContainer: Theme.m3.secondary_container ?? primaryContainer
    readonly property color secondaryContainerOn: Theme.m3.on_secondary_container ?? primaryContainerOn

    readonly property color tertiary: Theme.m3.tertiary ?? primary
    readonly property color tertiaryOn: Theme.m3.on_tertiary ?? primaryOn
    readonly property color tertiaryContainer: Theme.m3.tertiary_container ?? primaryContainer
    readonly property color tertiaryContainerOn: Theme.m3.on_tertiary_container ?? primaryContainerOn

    readonly property color surface: Theme.m3.surface ?? "#141318"
    readonly property color surfaceOn: Theme.m3.on_surface ?? Theme.text ?? "#e6e1e9"
    readonly property color surfaceVariant: Theme.m3.surface_variant ?? "#47464f"
    readonly property color surfaceVariantOn: Theme.m3.on_surface_variant ?? Theme.subtext ?? "#c8c5d0"

    readonly property color surfaceContainerLowest: Theme.m3.surface_container_lowest ?? "#0f0e13"
    readonly property color surfaceContainerLow: Theme.m3.surface_container_low ?? "#1c1b20"
    readonly property color surfaceContainer: Theme.m3.surface_container ?? "#201f25"
    readonly property color surfaceContainerHigh: Theme.m3.surface_container_high ?? "#2b292f"
    readonly property color surfaceContainerHighest: Theme.m3.surface_container_highest ?? "#35343a"

    readonly property color surfaceBright: Theme.m3.surface_bright ?? "#3a383e"
    readonly property color surfaceDim: Theme.m3.surface_dim ?? "#141318"
    readonly property color surfaceTint: Theme.m3.surface_tint ?? primary

    readonly property color inversePrimary: Theme.m3.inverse_primary ?? primary
    readonly property color inverseSurface: Theme.m3.inverse_surface ?? "#e6e1e9"
    readonly property color inverseOnSurface: Theme.m3.inverse_on_surface ?? "#313036"

    readonly property color outline: Theme.m3.outline ?? "#928f99"
    readonly property color outlineVariant: Theme.m3.outline_variant ?? "#47464f"

    readonly property color error: Theme.m3.error ?? Theme.error ?? "#ffb4ab"
    readonly property color errorOn: Theme.m3.on_error ?? "#690005"
    readonly property color errorContainer: Theme.m3.error_container ?? "#93000a"
    readonly property color errorContainerOn: Theme.m3.on_error_container ?? "#ffdad6"

    readonly property color scrim: Theme.m3.scrim ?? "#000000"
    readonly property color shadow: Theme.m3.shadow ?? "#000000"
    readonly property color background: Theme.m3.background ?? surface
    readonly property color backgroundOn: Theme.m3.on_background ?? surfaceOn

    readonly property bool bezelActive: false
    readonly property color connectedSurface: surface
    readonly property real connectedSurfaceOpacity: 1
    readonly property real floatSurfaceOpacity: 1

    // --- Typography ---
    readonly property string fontFamily: flexLoader.status === FontLoader.Ready ? flexLoader.name : "Google Sans Flex"
    readonly property string fontFamilyDisplay: fontFamily
    readonly property string fontFamilyMono: "JetBrainsMono Nerd Font"
    readonly property string fontFamilyNerd: "JetBrainsMono Nerd Font"
    readonly property string fontFamilyIcon: "Material Symbols Rounded"

    readonly property int fontWeightLight: Font.Light
    readonly property int fontWeightNormal: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightDemiBold: Font.DemiBold
    readonly property int fontWeightBold: Font.Bold

    readonly property var fontAxesLight: ({ "wght": 300, "wdth": 100 })
    readonly property var fontAxesRegular: ({ "wght": 400, "wdth": 100 })
    readonly property var fontAxesMedium: ({ "wght": 500, "wdth": 100 })
    readonly property var fontAxesDemiBold: ({ "wght": 550, "wdth": 100 })
    readonly property var fontAxesBold: ({ "wght": 600, "wdth": 100 })

    readonly property int fontIconGrad: -25

    // --- Scale Multipliers ---
    readonly property real fontMultiplier: 1.0
    readonly property real paddingMultiplier: 1.0
    readonly property real spacingMultiplier: 1.0
    readonly property real radiusMultiplier: 1.0

    // --- Font Size Tokens ---
    readonly property int fontSizeSmallest: 10
    readonly property int fontSizeSmaller: 12
    readonly property int fontSizeSmallie: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeSmall: 15
    readonly property int fontSizeNormal: 16
    readonly property int fontSizeLarge: 17
    readonly property int fontSizeLarger: 19
    readonly property int fontSizeHuge: 22
    readonly property int fontSizeHugeass: 23
    readonly property int fontSizeTitle: 26
    readonly property int fontSizeDisplay: 30

    // --- Icon Sizes ---
    readonly property int iconSizeSm: 16
    readonly property int iconSize: 18
    readonly property int iconSizeMd: 20
    readonly property int iconSizeLg: 22
    readonly property int iconSizeXl: 24
    readonly property int iconSizeXXl: 28

    // --- Spacing ---
    readonly property int spacingXs: 2
    readonly property int spacingSm: 4
    readonly property int spacing: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 20

    // --- Radii ---
    readonly property int radiusTrack: 4
    readonly property int radiusHandle: 5
    readonly property int radiusSm: 8
    readonly property int radius: 12
    readonly property int radiusMd: 16
    readonly property int radiusLg: 20
    readonly property int bulgeSize: 24
    readonly property int bulgeSizeSm: 22
    readonly property int radiusLockCard: 75
    readonly property int radiusPill: 999

    // --- Layout Tokens ---
    readonly property int rowHeight: 48
    readonly property int rowHeightSlim: 40
    readonly property int rowHeightTall: 56
    readonly property int iconCircleSize: 32
    readonly property int barHeight: 44
    readonly property int islandHeight: 34
    readonly property int barPadding: 8
    readonly property int panelPaddingSm: 10
    readonly property int panelPadding: 14
    readonly property int panelPaddingLg: 18

    // --- Opacity Tokens ---
    readonly property real opacityHover: 0.08
    readonly property real opacityPress: 0.12
    readonly property real opacityDisabled: 0.38
    readonly property real opacityHint: 0.6
    readonly property real opacitySecondary: 0.7
    readonly property real opacityNearFull: 0.9
    readonly property real opacityScrim: 0.4
    readonly property real opacityScrimHeavy: 0.5
    readonly property real opacityScrimModal: 0.45

    function withAlpha(baseColor, alpha) {
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, alpha)
    }

    function transparentize(c, percentage) {
        var col = Qt.color(c)
        return Qt.rgba(col.r, col.g, col.b, col.a * (1 - percentage))
    }

    function mix(c1, c2, ratio) {
        var a = Qt.color(c1)
        var b = Qt.color(c2)
        return Qt.rgba(ratio * a.r + (1 - ratio) * b.r, ratio * a.g + (1 - ratio) * b.g, ratio * a.b + (1 - ratio) * b.b, ratio * a.a + (1 - ratio) * b.a)
    }

    FontLoader {
        id: flexLoader
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/lucid/GoogleSansFlex.ttf"
    }
}
