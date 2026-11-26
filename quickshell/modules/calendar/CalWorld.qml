import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs

Item {
    id: page

    property var host: null
    property date now: Loc.now()
    readonly property var results: Zones.search(addInput.text, 6)
    readonly property int wheelStep: 190

    function pick(city) {
        addInput.text = "";
        Zones.addCity(city);
    }

    onVisibleChanged: {
        if (page.visible) Zones.loadAll();
    }

    Timer {
        interval: 1000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.now = Loc.now()
    }

    Flickable {
        id: cards
        readonly property bool scrollable: cards.contentHeight > cards.height

        anchors.top: parent.top
        anchors.bottom: adder.top
        anchors.bottomMargin: 12
        width: parent.width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        maximumFlickVelocity: 9000

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                event.accepted = true;
                const maxY = Math.max(0, cards.contentHeight - cards.height);
                const base = cardScroll.running ? cardScroll.to : cards.contentY;
                const target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * page.wheelStep));
                if (target === base) return;
                cardScroll.stop();
                cardScroll.from = cards.contentY;
                cardScroll.to = target;
                cardScroll.start();
            }
        }

        NumberAnimation {
            id: cardScroll
            target: cards
            property: "contentY"
            duration: 170
            easing.type: Easing.OutCubic
        }

        ScrollBar.vertical: ScrollBar {
            policy: cards.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            contentItem: Rectangle {
                implicitWidth: 3
                radius: 2
                color: Theme.accent
                opacity: cards.scrollable ? 1 : 0
            }
            background: Item {}
        }

        Grid {
            id: grid
            width: cards.width - (cards.scrollable ? 10 : 0)
            columns: 3
            spacing: 12

            Repeater {
                model: Zones.cities

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property date there: {
                        page.now;
                        return Zones.timeIn(card.modelData);
                    }
                    readonly property bool night: card.there.getHours() < 6 || card.there.getHours() >= 20

                    width: (grid.width - grid.spacing * 2) / 3
                    height: 128
                    radius: 16
                    color: card.night ? Qt.alpha(Theme.text, 0.055) : Qt.alpha(Theme.accent, 0.11)
                    border.width: 1
                    border.color: card.night ? Qt.alpha(Theme.text, 0.07) : Qt.alpha(Theme.accent, 0.22)

                    // Minimal circular analog dial
                    Rectangle {
                        id: dialCircle
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        width: 42
                        height: 42
                        radius: 21
                        color: Qt.alpha(card.night ? Theme.text : Theme.accent, 0.10)
                        border.width: 1
                        border.color: Qt.alpha(card.night ? Theme.text : Theme.accent, 0.22)

                        Rectangle {
                            x: dialCircle.width / 2 - 1
                            y: dialCircle.height / 2 - 11
                            width: 2
                            height: 11
                            radius: 1
                            color: Theme.text
                            transformOrigin: Item.Bottom
                            rotation: (card.there.getHours() % 12 + card.there.getMinutes() / 60) * 30
                        }

                        Rectangle {
                            x: dialCircle.width / 2 - 1
                            y: dialCircle.height / 2 - 15
                            width: 2
                            height: 15
                            radius: 1
                            color: Theme.accent
                            transformOrigin: Item.Bottom
                            rotation: card.there.getMinutes() * 6
                        }
                    }

                    Column {
                        x: 16
                        y: 14
                        spacing: 1

                        CalText {
                            font.pixelSize: 14
                            weightAxis: 620
                            width: card.width - 76
                            elide: Text.ElideRight
                            text: Zones.cityOf(card.modelData)
                        }

                        CalText {
                            font.pixelSize: 11
                            weightAxis: 480
                            color: Theme.subtext
                            text: Zones.regionOf(card.modelData)
                        }
                    }

                    CalText {
                        x: 16
                        anchors.bottom: subLine.top
                        anchors.bottomMargin: 2
                        font.pixelSize: 24
                        weightAxis: 660
                        tabular: true
                        text: card.there.toLocaleTimeString(I18n.locale, Prefs.clock24h ? I18n.tr("HH:mm") : I18n.tr("h:mm AP"))
                    }

                    CalText {
                        id: subLine
                        x: 16
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        font.pixelSize: 11
                        weightAxis: 500
                        color: Theme.subtext
                        tabular: true
                        text: Zones.dayText(card.modelData) + " · " + Zones.offsetText(card.modelData)
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 24
                        height: 24
                        radius: 12
                        color: rmMouse.containsMouse ? Qt.alpha(Theme.colors.error || "#f38ba8", 0.18) : Qt.alpha(Theme.text, 0.08)
                        opacity: cardHover.hovered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        CalIcon {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 14
                            color: rmMouse.containsMouse ? (Theme.colors.error || "#f38ba8") : Theme.subtext
                        }

                        MouseArea {
                            id: rmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Zones.removeCity(card.modelData)
                        }
                    }

                    HoverHandler {
                        id: cardHover
                    }
                }
            }
        }
    }

    // Empty state
    Column {
        visible: Zones.cities.length === 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24
        width: parent.width - 80
        spacing: 8

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48
            height: 48
            radius: 16
            color: Qt.alpha(Theme.accent, 0.10)

            CalIcon {
                anchors.centerIn: parent
                text: "public"
                font.pixelSize: 24
                color: Theme.accent
            }
        }

        CalText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 15
            weightAxis: 620
            text: I18n.tr("No cities yet")
        }

        CalText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
            weightAxis: 480
            color: Theme.subtext
            wrapMode: Text.Wrap
            text: I18n.tr("Search below for a city to track its local time and offset.")
        }
    }

    // Bottom Matushell Search Pill
    Rectangle {
        id: adder
        anchors.bottom: parent.bottom
        width: parent.width
        height: 40
        radius: 20
        color: addInput.activeFocus ? Qt.alpha(Theme.text, 0.09) : Qt.alpha(Theme.text, 0.06)
        border.width: 1
        border.color: addInput.activeFocus ? Qt.alpha(Theme.accent, 0.45) : Qt.alpha(Theme.text, 0.07)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 10

            CalIcon {
                text: "travel_explore"
                font.pixelSize: 18
                color: addInput.activeFocus ? Theme.accent : Theme.subtext
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CalText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    visible: addInput.text === ""
                    font.pixelSize: 13
                    weightAxis: 480
                    color: Qt.alpha(Theme.text, 0.42)
                    text: I18n.tr("Add a city — Lisbon, Tokyo, São Paulo…")
                }

                TextInput {
                    id: addInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Google Sans Flex"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    renderType: Text.QtRendering
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    clip: true
                    onAccepted: {
                        if (page.results.length > 0) {
                            Zones.addCity(page.results[0]);
                            addInput.text = "";
                        }
                    }
                }
            }

            Rectangle {
                visible: addInput.text !== ""
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: clrCityM.containsMouse ? Qt.alpha(Theme.text, 0.12) : "transparent"

                CalIcon {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 15
                    color: Theme.subtext
                }
                MouseArea {
                    id: clrCityM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addInput.text = "";
                        addInput.forceActiveFocus();
                    }
                }
            }
        }
    }

    // Floating city suggestions card
    Rectangle {
        visible: page.results.length > 0
        anchors.bottom: adder.top
        anchors.bottomMargin: 8
        width: parent.width
        height: suggCol.implicitHeight + 12
        radius: 16
        color: Theme.colors.card_bg || "#181a20"
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.10)
        z: 10

        Column {
            id: suggCol
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 2

            Repeater {
                model: page.results

                delegate: Rectangle {
                    required property var modelData
                    width: suggCol.width
                    height: 36
                    radius: 10
                    color: sMouse.containsMouse ? Qt.alpha(Theme.accent, 0.14) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        CalIcon {
                            text: "location_on"
                            font.pixelSize: 16
                            filled: true
                            color: Theme.accent
                        }

                        CalText {
                            Layout.fillWidth: true
                            font.pixelSize: 13
                            weightAxis: 540
                            elide: Text.ElideRight
                            text: Zones.cityOf(modelData) + " · " + Zones.regionOf(modelData)
                        }
                    }

                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.pick(modelData)
                    }
                }
            }
        }
    }
}
