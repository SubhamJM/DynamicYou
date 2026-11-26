import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.lucidbar

Item {
    id: page

    property var host: null
    property date now: Loc.now()
    readonly property var wx: WeatherSource.report
    readonly property bool night: page.wx ? !page.wx.isDay : (page.now.getHours() < 6 || page.now.getHours() >= 20)
    readonly property var hours: {
        if (!page.wx || !page.wx.hours) return [];
        const out = [];
        for (let i = 0; i < page.wx.hours.length && out.length < 8; i += 3) out.push(page.wx.hours[i]);
        return out;
    }

    readonly property string userName: Quickshell.env("USER") || ""
    readonly property string greeting: {
        var h = page.now.getHours();
        if (h < 5) return I18n.tr("Still up?");
        if (h < 12) return I18n.tr("Good morning");
        if (h < 18) return I18n.tr("Good afternoon");
        if (h < 22) return I18n.tr("Good evening");
        return I18n.tr("Good night");
    }

    signal addRequested()

    Timer {
        interval: 1000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.now = Loc.now()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Left: Clean Matushell Clock Hero Card
            Rectangle {
                Layout.preferredWidth: 244
                Layout.fillHeight: true
                radius: 18
                color: Qt.alpha(Theme.accent, 0.09)
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.20)
                clip: true

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 2

                    CalText {
                        font.pixelSize: 16
                        weightAxis: 640
                        color: Theme.text
                        text: page.now.toLocaleDateString(I18n.locale, I18n.tr("dddd"))
                    }

                    CalText {
                        font.pixelSize: 12
                        weightAxis: 500
                        color: Theme.subtext
                        text: page.now.toLocaleDateString(I18n.locale, I18n.tr("d MMMM yyyy"))
                    }
                }

                // Giant stacked crisp clock
                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 4
                    spacing: -14

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 70
                        weightAxis: 700
                        tabular: true
                        color: Theme.text
                        text: {
                            const h = page.now.getHours();
                            return Prefs.clock24h ? String(h).padStart(2, "0") : String(h % 12 === 0 ? 12 : h % 12).padStart(2, "0");
                        }
                    }

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 70
                        weightAxis: 700
                        tabular: true
                        color: Theme.accent
                        text: String(page.now.getMinutes()).padStart(2, "0")

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: -4
                            width: secText.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: Qt.alpha(Theme.text, 0.08)

                            CalText {
                                id: secText
                                anchors.centerIn: parent
                                font.pixelSize: 12
                                weightAxis: 640
                                tabular: true
                                color: Theme.subtext
                                text: String(page.now.getSeconds()).padStart(2, "0") + "s"
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    spacing: 6

                    Rectangle {
                        visible: !Prefs.clock24h
                        anchors.verticalCenter: parent.verticalCenter
                        width: ampmText.implicitWidth + 14
                        height: 22
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.16)

                        CalText {
                            id: ampmText
                            anchors.centerIn: parent
                            font.pixelSize: 10
                            weightAxis: 660
                            color: Theme.accent
                            text: page.now.getHours() < 12 ? I18n.tr("AM") : I18n.tr("PM")
                        }
                    }

                    CalText {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        weightAxis: 520
                        color: Theme.subtext
                        text: page.greeting + (page.userName !== "" ? ", " + page.userName : "")
                    }
                }
            }

            // Right: Weather Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: Qt.alpha(Theme.text, 0.055)
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.07)

                Column {
                    visible: page.wx === null
                    anchors.centerIn: parent
                    spacing: 8

                    CalIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: WeatherSource.busy ? "sync" : "cloud_off"
                        font.pixelSize: 28
                        color: Theme.subtext
                    }

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 13
                        weightAxis: 500
                        color: Theme.subtext
                        text: WeatherSource.lastError !== ""
                            ? I18n.tr("Weather unavailable — %1", WeatherSource.lastError)
                            : I18n.tr("Fetching forecast…")
                    }
                }

                ColumnLayout {
                    visible: page.wx !== null
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // Current Condition Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            radius: 16
                            color: Qt.alpha(Theme.accent, 0.14)

                            WeatherIcon {
                                anchors.centerIn: parent
                                size: 38
                                kind: page.wx ? WeatherSource.kindFor(page.wx.code, page.night) : "clear"
                                tint: Theme.accent
                                cloudColor: Theme.text
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                CalText {
                                    font.pixelSize: 30
                                    weightAxis: 680
                                    tabular: true
                                    text: page.wx ? Units.deg(page.wx.tempC, page.wx.tempF) : ""
                                }

                                Item { Layout.fillWidth: true }

                                CalText {
                                    font.pixelSize: 11
                                    weightAxis: 560
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    text: WeatherSource.place
                                }
                            }

                            CalText {
                                font.pixelSize: 12
                                weightAxis: 500
                                color: Theme.subtext
                                tabular: true
                                text: page.wx
                                    ? WeatherSource.descFor(page.wx.code)
                                        + (page.wx.days && page.wx.days.length
                                            ? " · " + Units.deg(page.wx.days[0].maxC, page.wx.days[0].maxF) + " / " + Units.deg(page.wx.days[0].minC, page.wx.days[0].minF)
                                            : "")
                                    : ""
                            }
                        }
                    }

                    // Weather Metric Pills
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: page.wx ? [
                                ["thermostat", I18n.tr("Feels %1", Units.deg(page.wx.feelsC, page.wx.feelsF))],
                                ["water_drop", page.wx.humidity + "%"],
                                ["air", Units.wind(page.wx.windKmph, page.wx.windMph) + " " + (page.wx.windDir || "")],
                                ["umbrella", (page.wx.pop || 0) + "%"],
                                ["light_mode", "UV " + page.wx.uv]
                            ] : []

                            delegate: Rectangle {
                                required property var modelData
                                width: chipRow.implicitWidth + 18
                                height: 26
                                radius: 13
                                color: Qt.alpha(Theme.text, 0.06)

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    CalIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData[0]
                                        font.pixelSize: 14
                                        color: Theme.accent
                                    }

                                    CalText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: 11
                                        weightAxis: 560
                                        tabular: true
                                        text: modelData[1]
                                    }
                                }
                            }
                        }
                    }

                    // Hourly Strip
                    Row {
                        Layout.fillWidth: true

                        Repeater {
                            model: page.hours

                            delegate: Column {
                                required property var modelData
                                required property int index
                                width: parent.width / Math.max(1, page.hours.length)
                                spacing: 4

                                CalText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.pixelSize: 10
                                    weightAxis: index === 0 ? 640 : 500
                                    color: index === 0 ? Theme.accent : Theme.subtext
                                    tabular: true
                                    text: index === 0
                                        ? I18n.tr("Now")
                                        : new Date(modelData.time).toLocaleTimeString(I18n.locale, Prefs.clock24h ? I18n.tr("HH") : I18n.tr("h AP")).replace(":00", "")
                                }

                                WeatherIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    size: 24
                                    animate: false
                                    kind: WeatherSource.kindFor(modelData.code, !modelData.day)
                                    tint: Theme.accent
                                    cloudColor: Theme.subtext
                                }

                                CalText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.pixelSize: 12
                                    weightAxis: 600
                                    tabular: true
                                    text: Units.deg(modelData.tempC, modelData.tempF)
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(Theme.text, 0.08)
                    }

                    // 5-Day Outlook Strip
                    Row {
                        Layout.fillWidth: true

                        Repeater {
                            model: page.wx && page.wx.days ? page.wx.days.slice(1, 6) : []

                            delegate: Row {
                                required property var modelData
                                width: parent.width / 5
                                spacing: 4

                                Column {
                                    spacing: 1

                                    CalText {
                                        font.pixelSize: 11
                                        weightAxis: 580
                                        text: new Date(modelData.date + "T12:00").toLocaleDateString(I18n.locale, I18n.tr("ddd"))
                                    }

                                    CalText {
                                        font.pixelSize: 10
                                        weightAxis: 500
                                        tabular: true
                                        color: Theme.subtext
                                        text: Units.deg(modelData.maxC, modelData.maxF) + " / " + Units.deg(modelData.minC, modelData.minF)
                                    }
                                }

                                WeatherIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 22
                                    animate: false
                                    kind: WeatherSource.kindFor(modelData.code, false)
                                    tint: Theme.accent
                                    cloudColor: Theme.subtext
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom: Next Reminder Pill Card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            radius: 16
            color: Qt.alpha(Theme.text, 0.055)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.07)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Agenda.next ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.text, 0.07)

                    CalIcon {
                        anchors.centerIn: parent
                        text: Agenda.next ? "notifications_active" : "event_available"
                        font.pixelSize: 17
                        filled: true
                        color: Agenda.next ? Theme.accent : Theme.subtext
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    CalText {
                        width: parent.width
                        font.pixelSize: 13
                        weightAxis: 600
                        elide: Text.ElideRight
                        text: Agenda.next ? Agenda.next.item.name : I18n.tr("Nothing coming up")
                    }

                    CalText {
                        width: parent.width
                        font.pixelSize: 11
                        weightAxis: 480
                        color: Theme.subtext
                        elide: Text.ElideRight
                        tabular: true
                        text: Agenda.next
                            ? Agenda.next.at.toLocaleDateString(I18n.locale, I18n.tr("ddd d MMM"))
                                + " · " + Agenda.timeText(Agenda.next.item)
                                + " · " + Agenda.untilText(Agenda.next.at)
                            : I18n.tr("Reminders you add show up here")
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: remRow.implicitWidth + 22
                    radius: 16
                    color: remMouse.pressed ? Qt.alpha(Theme.accent, 0.24) : (remMouse.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.accent, 0.12))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: remRow
                        anchors.centerIn: parent
                        spacing: 5

                        CalIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "add"
                            font.pixelSize: 15
                            color: Theme.accent
                        }

                        CalText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 12
                            weightAxis: 620
                            color: Theme.text
                            text: I18n.tr("Reminder")
                        }
                    }

                    MouseArea {
                        id: remMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.addRequested()
                    }
                }
            }
        }
    }
}
