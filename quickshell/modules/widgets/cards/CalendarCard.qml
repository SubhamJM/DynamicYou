import QtQuick
import "../../../"

Rectangle {
    id: root

    property bool active: true
    property date currentDate: new Date()
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    radius: 24
    color: Theme.m3.surface_container_high ?? Theme.colors.hover_bg
    clip: true

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Rectangle {
        id: headingBand
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Math.max(42, root.height * 0.34)
        color: Theme.m3.secondary_container ?? Theme.colors.card_bg
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Text {
            anchors.centerIn: parent
            text: root.monthNames[root.currentDate.getMonth()] + "  " + root.weekdayNames[root.currentDate.getDay()]
            color: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
            font.family: "Google Sans Flex"
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 0.6
            font.hintingPreference: Font.PreferVerticalHinting
            renderType: Text.NativeRendering
        }
    }

    Text {
        anchors {
            top: headingBand.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        text: String(root.currentDate.getDate())
        color: Theme.m3.on_surface ?? Theme.colors.text_primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: "Google Sans Flex"
        font.pixelSize: Math.min(root.width * 0.50, root.height * 0.48)
        font.weight: Font.Medium
        font.variableAxes: ({ "ROND": 45, "wdth": 78 })
        font.hintingPreference: Font.PreferVerticalHinting
        renderType: Text.NativeRendering
    }
}
