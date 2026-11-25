import QtQuick
import QtQuick.Effects
import "../../../"
import "../"

Item {
    id: root

    property bool active: true
    property date currentTime: new Date()
    readonly property int hour24: currentTime.getHours()
    readonly property int hour12: ((hour24 + 11) % 12) + 1
    readonly property int minute: currentTime.getMinutes()
    readonly property int second: currentTime.getSeconds()
    readonly property bool is12h: (typeof Prefs !== "undefined") ? !Prefs.clock24h : true
    readonly property bool digitalMode: WidgetStore.clockStyle === "digital"

    readonly property color colPrimary: Theme.m3.primary ?? Theme.accent
    readonly property color colPrimaryContainer: Theme.m3.primary_container ?? Theme.colors.card_bg
    readonly property color colSecondary: Theme.m3.secondary ?? Theme.colors.text_secondary
    readonly property color colSecondaryContainer: Theme.m3.secondary_container ?? Theme.colors.hover_bg
    readonly property color colOnSecondaryContainer: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
    readonly property color colTertiary: Theme.m3.tertiary ?? Theme.accent
    readonly property color colOnSurface: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color dialColor: Qt.lighter(colPrimaryContainer, 1.45)
    readonly property color infoColor: Qt.lighter(colPrimary, 1.2)

    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property string dateText: dayNames[currentTime.getDay()] + " · "
        + String(currentTime.getDate()).padStart(2, "0") + " " + monthNames[currentTime.getMonth()]

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    // ---------------------------------------------------------
    // 1. COOKIE CLOCK STYLE (like_what_I_want SidebarCookieClock)
    // ---------------------------------------------------------
    Item {
        id: cookieClock
        visible: !root.digitalMode
        anchors.fill: parent

        readonly property real dialSize: Math.max(100, Math.min(width, height) * 0.90)
        readonly property real k: dialSize / 230.0

        Item {
            width: cookieClock.dialSize
            height: cookieClock.dialSize
            anchors.centerIn: parent

            ExpressiveShape {
                id: cookieFace
                anchors.fill: parent
                shape: "cookie"
                cookieSides: 14
                color: root.colPrimaryContainer

                RotationAnimation on rotation {
                    running: root.active && !root.digitalMode
                    from: 360
                    to: 0
                    duration: 60000
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                }

                layer.enabled: cookieClock.visible && width > 1 && height > 1
                layer.smooth: true
                layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)), Math.max(1, Math.round(height * 2 * WidgetStore.qtScale)))
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.7
                    shadowVerticalOffset: WidgetStore.s(4)
                    autoPaddingEnabled: true
                }
            }

            // 12 Subtle Dial Dots
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(10 * cookieClock.k)
                z: 1
                Repeater {
                    model: 12
                    Item {
                        required property int index
                        anchors.fill: parent
                        rotation: 30 * index
                        Rectangle {
                            width: Math.round(10 * cookieClock.k)
                            height: width
                            radius: width / 2
                            color: Qt.alpha(root.dialColor, 0.55)
                            anchors {
                                left: parent.left
                                leftMargin: Math.round(12 * cookieClock.k)
                                verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // Minute Hand (behind numerals so stacked digits are always readable)
            Item {
                anchors.fill: parent
                z: 2
                rotation: -90 + 6 * root.minute
                Behavior on rotation {
                    RotationAnimation { direction: RotationAnimation.Clockwise; duration: 350; easing.type: Easing.OutCubic }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width / 2 - Math.round(4 * cookieClock.k)
                    width: Math.round(88 * cookieClock.k)
                    height: Math.round(8 * cookieClock.k)
                    radius: height / 2
                    color: Qt.alpha(root.colTertiary, 0.45)
                    border.width: Math.max(1, WidgetStore.s(2))
                    border.color: Qt.alpha(root.colTertiary, 0.85)
                }
            }

            // Hour Hand (behind numerals, distinct hollow/tinted pill)
            Item {
                anchors.fill: parent
                z: 3
                rotation: -90 + 30 * ((root.hour12 % 12) + root.minute / 60)
                Behavior on rotation {
                    RotationAnimation { direction: RotationAnimation.Clockwise; duration: 350; easing.type: Easing.OutCubic }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width / 2 - Math.round(8 * cookieClock.k)
                    width: Math.round(64 * cookieClock.k)
                    height: Math.round(16 * cookieClock.k)
                    radius: height / 2
                    color: Qt.alpha(root.colPrimary, 0.38)
                    border.width: Math.max(1, WidgetStore.s(2.5))
                    border.color: Qt.alpha(root.colPrimary, 0.92)
                }
            }

            // Center Stacked Digits rendered natively at scale 1.0 (zero blur)
            Column {
                anchors.centerIn: parent
                spacing: Math.round(-16 * cookieClock.k)
                z: 5
                Repeater {
                    model: root.is12h
                        ? [String(root.hour12).padStart(2, "0"), String(root.minute).padStart(2, "0"), (root.hour24 >= 12 ? "PM" : "AM")]
                        : [String(root.hour24).padStart(2, "0"), String(root.minute).padStart(2, "0")]
                    delegate: Text {
                        required property int index
                        required property var modelData
                        readonly property bool isPeriod: index >= 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        color: Theme.m3.on_primary_container ?? "#e0f8ff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: Math.round((isPeriod ? 22 : 66) * cookieClock.k)
                        font.weight: Font.Bold
                        font.variableAxes: ({ "ROND": 25, "wdth": 40 })
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Second Dot Hand
            Item {
                anchors.fill: parent
                z: 4
                rotation: 90 + 6 * root.second
                Rectangle {
                    width: Math.round(14 * cookieClock.k)
                    height: width
                    radius: width / 2
                    color: root.colSecondary
                    anchors {
                        left: parent.left
                        leftMargin: Math.round(24 * cookieClock.k)
                        verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Center Pin
            Rectangle {
                anchors.centerIn: parent
                width: WidgetStore.s(6)
                height: WidgetStore.s(6)
                radius: WidgetStore.s(3)
                color: root.colTertiary
                z: 4
            }
        }

        // Expressive corner BubbleDate badges (Day top-left Pentagon, Month bottom-right Pill)
        Item {
            width: WidgetStore.s(58)
            height: WidgetStore.s(58)
            anchors {
                top: parent.top
                left: parent.left
                topMargin: WidgetStore.s(8)
                leftMargin: WidgetStore.s(8)
            }
            z: 7

            ExpressiveShape {
                anchors.fill: parent
                shape: "pentagon"
                color: Theme.m3.tertiary_container ?? root.colSecondaryContainer
            }

            Text {
                anchors.centerIn: parent
                text: String(root.currentTime.getDate()).padStart(2, "0")
                color: Theme.m3.on_tertiary_container ?? root.colOnSecondaryContainer
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(24)
                font.weight: Font.Black
                font.variableAxes: ({ "ROND": 30, "wdth": 75 })
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }
        }

        Item {
            width: WidgetStore.s(58)
            height: WidgetStore.s(58)
            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: WidgetStore.s(8)
                rightMargin: WidgetStore.s(8)
            }
            z: 7

            ExpressiveShape {
                anchors.fill: parent
                shape: "pill"
                color: root.colSecondaryContainer
            }

            Text {
                anchors.centerIn: parent
                text: String(root.currentTime.getMonth() + 1).padStart(2, "0")
                color: root.colOnSecondaryContainer
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(24)
                font.weight: Font.Black
                font.variableAxes: ({ "ROND": 30, "wdth": 75 })
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }
        }
    }

    // ---------------------------------------------------------
    // 2. DIGITAL CLOCK STYLE (SystemClockCard digital face)
    // ---------------------------------------------------------
    Rectangle {
        id: digitalClock
        visible: root.digitalMode
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: root.colPrimaryContainer

        Column {
            anchors.centerIn: parent
            spacing: WidgetStore.s(4)

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: WidgetStore.s(8)

                Text {
                    text: String(root.is12h ? root.hour12 : root.hour24).padStart(2, "0")
                    color: root.colPrimary
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(104)
                    font.weight: Font.Medium
                    font.variableAxes: ({ "ROND": 25, "wdth": 32 })
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: WidgetStore.s(4)
                    Text {
                        text: String(root.minute).padStart(2, "0")
                        color: root.colSecondary
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(64)
                        font.weight: Font.Medium
                        font.variableAxes: ({ "ROND": 25, "wdth": 32 })
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                    Rectangle {
                        visible: root.is12h
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: periodLbl.implicitWidth + WidgetStore.s(14)
                        height: WidgetStore.s(22)
                        radius: WidgetStore.s(8)
                        color: root.colSecondaryContainer
                        Text {
                            id: periodLbl
                            anchors.centerIn: parent
                            text: root.hour24 >= 12 ? "PM" : "AM"
                            color: root.colOnSecondaryContainer
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(12)
                            font.weight: Font.Bold
                            font.hintingPreference: Font.PreferVerticalHinting
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateText
                color: root.colOnSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(15)
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }
        }
    }
}
