import QtQuick
import "." as BtUi

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

    readonly property int btnH: ib.size === "xs" ? BtUi.Theme.dp(30) : (ib.size === "m" ? BtUi.Theme.dp(48) : BtUi.Theme.dp(36))
    readonly property int iconPx: ib.size === "xs" ? BtUi.Theme.dp(18) : (ib.size === "m" ? BtUi.Theme.dp(24) : BtUi.Theme.dp(20))
    readonly property int btnW: ib.widthKind === "narrow" ? Math.round(ib.btnH * 0.78) : (ib.widthKind === "wide" ? Math.round(ib.btnH * 1.3) : ib.btnH)
    readonly property bool on: ib.checkable && ib.checked

    readonly property color container: {
        if (ib.containerOverride.a > 0)
            return ib.containerOverride;

        if (ib.disabled)
            return ib.variant === "standard" || ib.variant === "outlined" ? "transparent" : BtUi.Theme.alpha(BtUi.Theme.text, BtUi.Theme.disabledContainer);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? BtUi.Theme.primary : BtUi.Theme.surfaceHighest) : BtUi.Theme.primary;
        case "tonal":
            return ib.checkable ? (ib.checked ? BtUi.Theme.secondary : BtUi.Theme.secondaryContainer) : BtUi.Theme.secondaryContainer;
        case "outlined":
            return ib.on ? BtUi.Theme.inverseSurface : "transparent";
        }
        return "transparent";
    }
    readonly property color content: {
        if (ib.tintOverride.a > 0)
            return ib.tintOverride;

        if (ib.disabled)
            return BtUi.Theme.alpha(BtUi.Theme.text, BtUi.Theme.disabledContent);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? BtUi.Theme.fgPrimary : BtUi.Theme.subtext) : BtUi.Theme.fgPrimary;
        case "tonal":
            return ib.checkable ? (ib.checked ? BtUi.Theme.fgSecondary : BtUi.Theme.fgSecondaryContainer) : BtUi.Theme.fgSecondaryContainer;
        case "outlined":
            return ib.on ? BtUi.Theme.fgInverseSurface : BtUi.Theme.subtext;
        }
        return ib.on ? BtUi.Theme.primary : BtUi.Theme.subtext;
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
        radius: area.pressed ? Math.min(BtUi.Theme.pill(ib.btnH), BtUi.Theme.rad(10)) : (ib.on && ib.variant !== "standard" ? Math.min(BtUi.Theme.pill(ib.btnH), BtUi.Theme.rad(12)) : BtUi.Theme.pill(ib.btnH))
        color: ib.container
        border.width: ib.variant === "outlined" && !ib.on ? 1 : 0
        border.color: BtUi.Theme.outline

        Behavior on radius {
            NumberAnimation {
                duration: BtUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: BtUi.Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: BtUi.Theme.durDefaultEffects
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
                duration: BtUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: BtUi.Theme.curveFastSpatial
            }

        }

    }

}
