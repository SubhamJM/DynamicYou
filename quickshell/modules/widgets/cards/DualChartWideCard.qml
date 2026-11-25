import QtQuick
import Qt5Compat.GraphicalEffects
import "../../../"
import "../../"
import "../"

Item {
    id: root

    property string title: "Network"
    property string selectorIcon: "lan"
    property string selectorLabel: "Default"
    property string metric1Icon: "download"
    property string metric1Value: "0 B/s"
    property string metric2Icon: "upload"
    property string metric2Value: "0 B/s"
    property var primaryValues: []
    property var secondaryValues: []
    property bool active: visible

    property color leftColor: Theme.m3.primary ?? Theme.accent
    property color leftForeground: Theme.m3.on_primary ?? "#101014"
    property color rightColor: Theme.m3.primary_container ?? Theme.colors.card_bg
    property color rightForeground: Theme.m3.on_primary_container ?? Theme.colors.text_primary
    property color metric1Color: Theme.m3.primary ?? Theme.accent
    property color metric2Color: Theme.m3.secondary ?? Theme.colors.text_secondary

    readonly property color chart1Color: Qt.lighter(metric1Color, 1.1)
    readonly property color chart2Color: Qt.lighter(metric2Color, 1.15)
    readonly property real rightPanelX: Math.round(width * 0.53)
    readonly property int historyLen: 18
    readonly property real chartMaximum: {
        let m = 0;
        [primaryValues || [], secondaryValues || []].forEach(arr => {
            const start = Math.max(0, arr.length - historyLen);
            for (let i = start; i < arr.length; i += 1) {
                if (typeof arr[i] === "number" && isFinite(arr[i])) m = Math.max(m, arr[i]);
            }
        });
        return Math.max(1024, m * 1.2);
    }

    signal selectorClicked()

    clip: true

    // Left colored chart panel
    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: root.leftColor
    }

    Text {
        text: root.title
        color: root.leftForeground
        font.family: "Google Sans Flex"
        font.pixelSize: WidgetStore.si(28)
        font.weight: Font.Black
        font.variableAxes: ({ "GRAD": 100, "ROND": 35, "wdth": 85 })
        font.hintingPreference: Font.PreferVerticalHinting
        renderType: Text.NativeRendering
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: WidgetStore.s(16)
            topMargin: WidgetStore.s(14)
        }
    }

    SparklineCanvas {
        values: root.primaryValues
        secondaryValues: root.secondaryValues
        maximum: root.chartMaximum
        historyLength: root.historyLen
        active: root.active
        fillArea: true
        fillOpacity: 0.22
        lineColor: root.leftForeground
        secondaryLineColor: Qt.alpha(root.leftForeground, 0.42)
        lineWidth: WidgetStore.s(2.2)
        anchors {
            left: parent.left
            right: rightPanel.left
            top: parent.top
            bottom: parent.bottom
            topMargin: WidgetStore.s(50)
            bottomMargin: WidgetStore.s(8)
            rightMargin: WidgetStore.s(2)
        }
    }

    // Right rounded data panel
    Rectangle {
        id: rightPanel
        x: root.rightPanelX
        y: 0
        width: root.width - x
        height: root.height
        radius: WidgetStore.s(24)
        color: root.rightColor
        clip: true
        z: 2

        Column {
            anchors {
                fill: parent
                leftMargin: WidgetStore.s(14)
                rightMargin: WidgetStore.s(14)
                topMargin: WidgetStore.s(10)
                bottomMargin: WidgetStore.s(10)
            }
            spacing: WidgetStore.s(2)

            // Interactive source selector pill button (cycles interface/disk cleanly)
            Rectangle {
                id: selectorBtn
                width: parent.width
                height: WidgetStore.s(34)
                radius: WidgetStore.s(10)
                color: selectorMouse.containsMouse ? Qt.lighter(root.leftColor, 1.12) : root.leftColor

                Row {
                    anchors.centerIn: parent
                    spacing: WidgetStore.s(6)
                    width: Math.min(implicitWidth, parent.width - WidgetStore.s(16))

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectorIcon
                        iconSize: WidgetStore.si(16)
                        color: root.leftForeground
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectorLabel
                        color: root.leftForeground
                        font.family: "Noto Sans"
                        font.pixelSize: WidgetStore.si(12)
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: selectorMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectorClicked()
                }
            }

            RateRow {
                width: parent.width
                height: (parent.height - WidgetStore.s(34) - parent.spacing * 2) / 2
                iconName: root.metric1Icon
                value: root.metric1Value
                accentColor: root.metric1Color
            }

            RateRow {
                width: parent.width
                height: (parent.height - WidgetStore.s(34) - parent.spacing * 2) / 2
                iconName: root.metric2Icon
                value: root.metric2Value
                accentColor: root.metric2Color
            }
        }
    }

    component RateRow: Item {
        id: rowItem
        required property string iconName
        required property string value
        required property color accentColor

        MaterialSymbol {
            id: rowIcon
            text: rowItem.iconName
            iconSize: WidgetStore.si(24)
            fill: 1
            color: rowItem.accentColor
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        }

        Text {
            text: rowItem.value
            color: root.rightForeground
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(22)
            font.weight: Font.Black
            font.variableAxes: ({ "GRAD": 100, "ROND": 35, "wdth": 85 })
            elide: Text.ElideRight
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
            anchors {
                left: rowIcon.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: WidgetStore.s(8)
            }
        }
    }
}
