import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../"
import "../"

SekaiPill {
    id: root

    property string label: ""
    property string detail: ""
    property string valueText: ""
    property real level: 0
    property string iconName: "memory"
    property color accentColor: Theme.m3.primary ?? Theme.accent
    property color textColor: Theme.m3.on_surface ?? Theme.colors.text_primary
    property color mutedColor: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary

    readonly property color pillFill: Theme.m3.surface_container_high ?? Theme.colors.card_bg
    readonly property real clampedLevel: Math.max(0, Math.min(1, Number(level) || 0))

    implicitHeight: WidgetStore.s(104)
    cornerRadius: WidgetStore.s(15)
    borderWidth: WidgetStore.s(2)
    ringWidth: WidgetStore.s(2)
    shadowDx: WidgetStore.s(2)
    shadowDy: WidgetStore.s(3)
    fillColor: root.pillFill
    ringColor: Qt.alpha(root.accentColor, 0.20)

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: WidgetStore.s(11)
            rightMargin: WidgetStore.s(11)
            topMargin: WidgetStore.s(10)
            bottomMargin: WidgetStore.s(10)
        }
        spacing: WidgetStore.s(6)

        // Top row: icon keycap + label
        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(8)

            SekaiPill {
                Layout.preferredWidth: WidgetStore.s(30)
                Layout.preferredHeight: WidgetStore.s(30)
                cornerRadius: WidgetStore.s(9)
                borderWidth: WidgetStore.s(1.8)
                ringWidth: WidgetStore.s(1.5)
                shadowDy: WidgetStore.s(2)
                fillColor: Qt.alpha(root.accentColor, 0.20)
                ringColor: Qt.alpha(root.accentColor, 0.25)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: WidgetStore.si(16)
                    fill: 1
                    color: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(1)

                Text {
                    Layout.fillWidth: true
                    text: root.label
                    color: root.mutedColor
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(10)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.9
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.detail
                    color: root.textColor
                    opacity: 0.88
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(10)
                    font.weight: Font.DemiBold
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Middle metric readout row + Sekai Pop framed meter bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(5)

            Text {
                Layout.fillWidth: true
                text: root.valueText
                color: root.textColor
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(24)
                font.weight: Font.Black
                font.features: { "tnum": 1 }
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
                lineHeight: 0.92
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(11)
                radius: WidgetStore.s(5.5)
                color: Theme.m3.surface_container_lowest ?? "#070b14"
                border.width: WidgetStore.s(1.6)
                border.color: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.3)
                clip: true

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: WidgetStore.s(2)
                    }
                    width: Math.max(
                        root.clampedLevel > 0.01 ? WidgetStore.s(6) : 0,
                        (parent.width - WidgetStore.s(4)) * root.clampedLevel
                    )
                    radius: WidgetStore.s(3.5)
                    color: root.accentColor

                    Behavior on width {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
