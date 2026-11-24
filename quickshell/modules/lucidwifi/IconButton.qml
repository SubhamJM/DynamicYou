import QtQuick
import "." as WifiUi

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

    readonly property int btnH: ib.size === "xs" ? WifiUi.Theme.dp(30) : (ib.size === "m" ? WifiUi.Theme.dp(48) : WifiUi.Theme.dp(36))
    readonly property int iconPx: ib.size === "xs" ? WifiUi.Theme.dp(18) : (ib.size === "m" ? WifiUi.Theme.dp(24) : WifiUi.Theme.dp(20))
    readonly property int btnW: ib.widthKind === "narrow" ? Math.round(ib.btnH * 0.78) : (ib.widthKind === "wide" ? Math.round(ib.btnH * 1.3) : ib.btnH)
    readonly property bool on: ib.checkable && ib.checked

    readonly property color container: {
        if (ib.containerOverride.a > 0)
            return ib.containerOverride;

        if (ib.disabled)
            return ib.variant === "standard" || ib.variant === "outlined" ? "transparent" : WifiUi.Theme.alpha(WifiUi.Theme.text, WifiUi.Theme.disabledContainer);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? WifiUi.Theme.primary : WifiUi.Theme.surfaceHighest) : WifiUi.Theme.primary;
        case "tonal":
            return ib.checkable ? (ib.checked ? WifiUi.Theme.secondary : WifiUi.Theme.secondaryContainer) : WifiUi.Theme.secondaryContainer;
        case "outlined":
            return ib.on ? WifiUi.Theme.inverseSurface : "transparent";
        }
        return "transparent";
    }
    readonly property color content: {
        if (ib.tintOverride.a > 0)
            return ib.tintOverride;

        if (ib.disabled)
            return WifiUi.Theme.alpha(WifiUi.Theme.text, WifiUi.Theme.disabledContent);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? WifiUi.Theme.fgPrimary : WifiUi.Theme.subtext) : WifiUi.Theme.fgPrimary;
        case "tonal":
            return ib.checkable ? (ib.checked ? WifiUi.Theme.fgSecondary : WifiUi.Theme.fgSecondaryContainer) : WifiUi.Theme.fgSecondaryContainer;
        case "outlined":
            return ib.on ? WifiUi.Theme.fgInverseSurface : WifiUi.Theme.subtext;
        }
        return ib.on ? WifiUi.Theme.primary : WifiUi.Theme.subtext;
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
        radius: area.pressed ? Math.min(WifiUi.Theme.pill(ib.btnH), WifiUi.Theme.rad(10)) : (ib.on && ib.variant !== "standard" ? Math.min(WifiUi.Theme.pill(ib.btnH), WifiUi.Theme.rad(12)) : WifiUi.Theme.pill(ib.btnH))
        color: ib.container

        Behavior on radius {
            NumberAnimation {
                duration: WifiUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: WifiUi.Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: WifiUi.Theme.durDefaultEffects
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
                duration: WifiUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: WifiUi.Theme.curveFastSpatial
            }

        }

    }

}
