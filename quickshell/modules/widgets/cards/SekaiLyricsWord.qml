import QtQuick
import "../../../"
import "../"

Item {
    id: root

    property string text: ""
    property int pixelSize: WidgetStore.si(28)
    property color fillColor: "#FFFFFF"
    property color litColor: Theme.m3.primary ?? Theme.accent
    property color outlineColor: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.35)
    property real sung: 0
    property bool withFill: false

    readonly property real outline: Math.max(WidgetStore.s(2.0), root.pixelSize * 0.085)
    readonly property real shadowDx: Math.max(WidgetStore.s(1.5), root.pixelSize * 0.06)
    readonly property real shadowDy: Math.max(WidgetStore.s(2.0), root.pixelSize * 0.085)
    readonly property real edge: Math.ceil(root.outline) + 1

    implicitWidth: Math.ceil(ink.implicitWidth + 2 * root.edge + root.shadowDx)
    implicitHeight: Math.ceil(ink.implicitHeight + 2 * root.edge + root.shadowDy)

    component Glyphs: Text {
        text: root.text
        font.family: "Google Sans Flex"
        font.pixelSize: root.pixelSize
        font.weight: Font.ExtraBold
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.QtRendering
    }

    Item {
        id: box
        x: root.edge
        y: root.edge
        width: ink.implicitWidth
        height: ink.implicitHeight

        // Hard drop shadow
        Repeater {
            model: 4
            Glyphs {
                required property int index
                x: root.shadowDx + (index % 2 === 0 ? -1 : 1) * root.outline * 0.7
                y: root.shadowDy + (index < 2 ? -1 : 1) * root.outline * 0.7
                color: root.outlineColor
            }
        }

        // Crisp 8-point sticker outline
        Repeater {
            model: 8
            Glyphs {
                required property int index
                x: Math.cos(index * Math.PI / 4) * root.outline
                y: Math.sin(index * Math.PI / 4) * root.outline
                color: root.outlineColor
            }
        }

        // Base white ink
        Glyphs {
            id: ink
            color: root.fillColor
        }

        // Sung accent sweep left -> right
        Item {
            visible: root.withFill && root.sung > 0.001
            width: Math.round(box.width * Math.max(0, Math.min(1, root.sung)))
            height: box.height
            clip: true

            Glyphs {
                color: root.litColor
            }
        }
    }
}
