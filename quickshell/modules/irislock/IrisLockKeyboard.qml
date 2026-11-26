import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: kbd

    signal keyClicked(string key)
    signal backspaceClicked()
    signal enterClicked()
    signal closeRequested()

    property bool showSymbols: false
    property bool shifted: false

    height: 236
    radius: 20
    color: Qt.rgba(0.08, 0.08, 0.12, 0.84)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)

    readonly property var row1: showSymbols
        ? ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        : ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    readonly property var row2: showSymbols
        ? ["@", "#", "$", "%", "&", "-", "+", "(", ")"]
        : ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    readonly property var row3: showSymbols
        ? ["*", "\"", "'", ":", ";", "!", "?"]
        : ["z", "x", "c", "v", "b", "n", "m"]

    component KeyCap: Rectangle {
        property string label: ""
        property string iconGlyph: ""
        property bool accent: false
        property bool activeToggle: false
        signal triggered()

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 10
        color: accent
            ? Theme.accent
            : (activeToggle ? Qt.rgba(1, 1, 1, 0.28) : (km.pressed ? Qt.rgba(1, 1, 1, 0.26) : (km.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10))))
        scale: km.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }
        Behavior on color { ColorAnimation { duration: 90 } }

        Text {
            visible: iconGlyph === ""
            anchors.centerIn: parent
            text: label
            font.family: "Google Sans Flex"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
            font.hintingPreference: Font.PreferNoHinting
            color: accent ? Theme.onAccent : "#ffffff"
        }

        Text {
            visible: iconGlyph !== ""
            anchors.centerIn: parent
            text: iconGlyph
            font.family: Theme.fontFamilyIcon
            font.pixelSize: 18
            font.variableAxes: ({ "FILL": 1, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
            renderType: Text.CurveRendering
            font.hintingPreference: Font.PreferNoHinting
            color: accent ? Theme.onAccent : "#ffffff"
        }

        MouseArea {
            id: km
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: triggered()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Row 1
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5
            Repeater {
                model: kbd.row1
                delegate: KeyCap {
                    required property string modelData
                    label: (!kbd.showSymbols && kbd.shifted) ? modelData.toUpperCase() : modelData
                    onTriggered: {
                        kbd.keyClicked(label);
                        if (!kbd.showSymbols && kbd.shifted) kbd.shifted = false;
                    }
                }
            }
        }

        // Row 2
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 5
            Repeater {
                model: kbd.row2
                delegate: KeyCap {
                    required property string modelData
                    label: (!kbd.showSymbols && kbd.shifted) ? modelData.toUpperCase() : modelData
                    onTriggered: {
                        kbd.keyClicked(label);
                        if (!kbd.showSymbols && kbd.shifted) kbd.shifted = false;
                    }
                }
            }
        }

        // Row 3 (Shift + Letters + Backspace)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            KeyCap {
                Layout.fillWidth: false
                Layout.preferredWidth: 54
                iconGlyph: kbd.showSymbols ? "" : "arrow_upward"
                label: kbd.showSymbols ? "ABC" : ""
                activeToggle: kbd.shifted && !kbd.showSymbols
                onTriggered: {
                    if (kbd.showSymbols) kbd.showSymbols = false;
                    else kbd.shifted = !kbd.shifted;
                }
            }

            Repeater {
                model: kbd.row3
                delegate: KeyCap {
                    required property string modelData
                    label: (!kbd.showSymbols && kbd.shifted) ? modelData.toUpperCase() : modelData
                    onTriggered: {
                        kbd.keyClicked(label);
                        if (!kbd.showSymbols && kbd.shifted) kbd.shifted = false;
                    }
                }
            }

            KeyCap {
                Layout.fillWidth: false
                Layout.preferredWidth: 54
                iconGlyph: "backspace"
                onTriggered: kbd.backspaceClicked()
            }
        }

        // Row 4 (?123 + Space + Unlock + Close)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            KeyCap {
                Layout.fillWidth: false
                Layout.preferredWidth: 64
                label: kbd.showSymbols ? "ABC" : "?123"
                onTriggered: kbd.showSymbols = !kbd.showSymbols
            }

            KeyCap {
                Layout.fillWidth: true
                label: "Space"
                onTriggered: kbd.keyClicked(" ")
            }

            KeyCap {
                Layout.fillWidth: false
                Layout.preferredWidth: 72
                accent: true
                iconGlyph: "arrow_forward"
                onTriggered: kbd.enterClicked()
            }

            KeyCap {
                Layout.fillWidth: false
                Layout.preferredWidth: 44
                iconGlyph: "keyboard_hide"
                onTriggered: kbd.closeRequested()
            }
        }
    }
}
