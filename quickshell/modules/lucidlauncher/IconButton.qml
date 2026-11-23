import QtQuick
import "." as LauncherUi

// m3 expressive icon button. toggles fill their glyph and square off when on
Item {
    id: ib

    // "standard" | "filled" | "tonal" | "outlined"
    property string variant: "standard"
    // "xs" | "s" | "m"
    property string size: "s"
    // "narrow" | "default" | "wide"
    property string widthKind: "default"
    property string icon: ""
    property bool checkable: false
    property bool checked: false
    property bool disabled: false
    property real iconFill: -1
    property color tintOverride: "transparent"
    property color containerOverride: "transparent"
    property string tooltip: ""

    signal clicked()
    signal rightClicked()
    signal toggled(bool value)

    readonly property int btnH: ib.size === "xs" ? LauncherUi.Theme.dp(30) : (ib.size === "m" ? LauncherUi.Theme.dp(48) : LauncherUi.Theme.dp(36))
    readonly property int iconPx: ib.size === "xs" ? LauncherUi.Theme.dp(18) : (ib.size === "m" ? LauncherUi.Theme.dp(24) : LauncherUi.Theme.dp(20))
    readonly property int btnW: ib.widthKind === "narrow" ? Math.round(ib.btnH * 0.78) : (ib.widthKind === "wide" ? Math.round(ib.btnH * 1.3) : ib.btnH)
    readonly property bool on: ib.checkable && ib.checked

    readonly property color container: {
        if (ib.containerOverride.a > 0)
            return ib.containerOverride;

        if (ib.disabled)
            return ib.variant === "standard" || ib.variant === "outlined" ? "transparent" : LauncherUi.Theme.alpha(LauncherUi.Theme.text, LauncherUi.Theme.disabledContainer);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? LauncherUi.Theme.primary : LauncherUi.Theme.surfaceHighest) : LauncherUi.Theme.primary;
        case "tonal":
            return ib.checkable ? (ib.checked ? LauncherUi.Theme.secondary : LauncherUi.Theme.secondaryContainer) : LauncherUi.Theme.secondaryContainer;
        case "outlined":
            return ib.on ? LauncherUi.Theme.inverseSurface : "transparent";
        }
        return "transparent";
    }
    readonly property color content: {
        if (ib.tintOverride.a > 0)
            return ib.tintOverride;

        if (ib.disabled)
            return LauncherUi.Theme.alpha(LauncherUi.Theme.text, LauncherUi.Theme.disabledContent);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? LauncherUi.Theme.fgPrimary : LauncherUi.Theme.subtext) : LauncherUi.Theme.fgPrimary;
        case "tonal":
            return ib.checkable ? (ib.checked ? LauncherUi.Theme.fgSecondary : LauncherUi.Theme.fgSecondaryContainer) : LauncherUi.Theme.fgSecondaryContainer;
        case "outlined":
            return ib.on ? LauncherUi.Theme.fgInverseSurface : LauncherUi.Theme.subtext;
        }
        return ib.on ? LauncherUi.Theme.primary : LauncherUi.Theme.subtext;
    }

    implicitWidth: ib.btnW
    implicitHeight: ib.btnH
    readonly property bool jellyWobbling: squish.wobbling
    transform: Jelly {
        id: squish

        target: ib
        frequency: 6.5
    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed ? Math.min(LauncherUi.Theme.pill(ib.btnH), LauncherUi.Theme.rad(10)) : (ib.on && ib.variant !== "standard" ? Math.min(LauncherUi.Theme.pill(ib.btnH), LauncherUi.Theme.rad(12)) : LauncherUi.Theme.pill(ib.btnH))
        color: ib.container
        border.width: ib.variant === "outlined" && !ib.on ? 1 : 0
        border.color: LauncherUi.Theme.outline

        Behavior on radius {
            NumberAnimation {
                duration: LauncherUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: LauncherUi.Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: LauncherUi.Theme.durDefaultEffects
            }

        }

        StateLayer {
            id: area

            radius: box.radius
            tint: ib.content
            disabled: ib.disabled
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressedChanged: squish.kick(area.pressed ? -0.12 : 0.09)
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    ib.rightClicked();
                    return ;
                }
                if (ib.checkable)
                    ib.toggled(!ib.checked);

                ib.clicked();
            }
        }

    }

    Icon {
        anchors.centerIn: parent
        name: ib.icon
        size: ib.iconPx
        color: ib.content
        fill: ib.iconFill >= 0 ? ib.iconFill : (ib.on ? 1 : 0)
        scale: area.pressed ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: LauncherUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: LauncherUi.Theme.curveFastSpatial
            }

        }

    }

}
