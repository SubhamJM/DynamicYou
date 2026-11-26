import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: page

    property var host: null
    property var selected: {
        const n = Loc.now();
        return { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
    }
    readonly property date selectedDate: new Date(page.selected.year, page.selected.month, page.selected.day)
    readonly property var dayItems: {
        Agenda.checkedDay;
        return Agenda.forDay(page.selected.year, page.selected.month, page.selected.day);
    }

    property int newHour: 9
    property int newMinute: 0
    property bool hourGuessed: false
    property bool halfPicked: false
    property string newRepeat: ""
    readonly property bool pm: page.newHour >= 12
    readonly property int shownHour: Prefs.clock24h ? page.newHour : (page.newHour % 12 === 0 ? 12 : page.newHour % 12)
    readonly property bool past: {
        Agenda.minuteKey;
        return page.newRepeat === "" && page.gone(page.newHour, page.newMinute);
    }
    readonly property bool shown: page.visible && (!page.host || page.host.expanded)

    onShownChanged: if (page.shown) page.freshTime()

    function selectToday() {
        const n = Loc.now();
        page.selected = { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
        month.goToday();
        page.freshTime();
    }

    function gone(hour, minute) {
        const n = Loc.now();
        return new Date(page.selected.year, page.selected.month, page.selected.day, hour, minute)
            < new Date(n.getFullYear(), n.getMonth(), n.getDate(), n.getHours(), n.getMinutes());
    }

    function isToday() {
        return page.gone(0, 0) && !page.gone(23, 59);
    }

    function startVisit() {
        if (nameInput.text !== "") return;
        const n = Loc.now();
        page.selected = { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
        if (!month.isCurrent) month.goToday();
        page.freshTime();
    }

    function freshTime() {
        if (nameInput.text !== "") return;
        page.newHour = 9;
        page.newMinute = 0;
        page.hourGuessed = false;
        page.halfPicked = false;
        const next = Loc.now().getHours() + 1;
        if (page.gone(9, 0) && next < 24 && !page.gone(next, 0)) {
            page.newHour = next;
            page.hourGuessed = true;
        }
    }

    function preferUpcoming() {
        if (Prefs.clock24h || page.halfPicked || !page.past) return;
        const flipped = (page.newHour + 12) % 24;
        if (!page.gone(flipped, page.newMinute)) page.newHour = flipped;
    }

    function focusName() {
        nameInput.forceActiveFocus();
    }

    function submit() {
        const name = nameInput.text.trim();
        if (name === "" || page.past) return;
        Agenda.add(page.selected.year, page.selected.month, page.selected.day, page.newHour, page.newMinute, name, page.newRepeat);
        nameInput.text = "";
        page.newRepeat = "";
    }

    function step(minutes) {
        page.hourGuessed = false;
        let t = (page.newHour * 60 + page.newMinute + minutes + 1440) % 1440;
        page.newHour = Math.floor(t / 60);
        page.newMinute = t % 60;
    }

    function typeHour(h) {
        page.hourGuessed = false;
        if (Prefs.clock24h) {
            page.newHour = Math.min(23, h);
        } else if (page.isToday() && !page.halfPicked) {
            const h12 = Math.min(12, h) % 12;
            page.newHour = page.gone(h12, 59) ? h12 + 12 : h12;
        } else {
            page.newHour = Math.min(12, h) % 12 + (page.pm ? 12 : 0);
            page.preferUpcoming();
        }
    }

    function typeMinute(m) {
        page.newMinute = Math.min(59, m);
        if (page.hourGuessed && page.isToday()) {
            const h = Loc.now().getHours();
            if (!page.gone(h, page.newMinute)) page.newHour = h;
            else if (h + 1 < 24) page.newHour = h + 1;
        }
        page.preferUpcoming();
    }

    function setPm(wantPm) {
        page.hourGuessed = false;
        page.halfPicked = true;
        page.newHour = page.newHour % 12 + (wantPm ? 12 : 0);
    }

    component TimeDigit: Item {
        id: digit
        property int value: 0
        property int span: 60
        property Item nextDigit: null
        readonly property bool typing: field.activeFocus

        signal typed(int v)
        signal meridiem(bool wantPm)
        signal accepted()

        function show() {
            field.text = String(digit.value).padStart(2, "0");
        }
        function take() {
            field.forceActiveFocus();
            field.selectAll();
        }
        function nudge(by) {
            digit.typed((digit.value + by + digit.span) % digit.span);
            digit.show();
        }

        width: 28
        height: 28
        onValueChanged: if (!field.activeFocus) digit.show()
        Component.onCompleted: digit.show()

        TextInput {
            id: field
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLength: 2
            inputMethodHints: Qt.ImhDigitsOnly
            selectByMouse: true
            color: digit.typing ? Theme.accent : Theme.text
            selectionColor: Qt.alpha(Theme.accent, 0.35)
            selectedTextColor: Theme.text
            font.family: "Google Sans Flex"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.variableAxes: ({ "wght": 620 })
            font.features: ({ "tnum": 1 })
            renderType: Text.QtRendering

            onTextEdited: {
                if (field.text !== "") digit.typed(parseInt(field.text, 10));
                if (field.text.length === 2 && digit.nextDigit) digit.nextDigit.take();
            }
            onActiveFocusChanged: {
                if (field.activeFocus) Qt.callLater(field.selectAll);
                else digit.show();
            }
            onAccepted: digit.accepted()
            Keys.onUpPressed: digit.nudge(1)
            Keys.onDownPressed: digit.nudge(-1)
            Keys.onTabPressed: digit.nextDigit ? digit.nextDigit.take() : digit.show()
            Keys.onPressed: (e) => {
                const c = e.text.toLowerCase();
                if (c === "a" || c === "p") digit.meridiem(c === "p");
            }

            validator: RegularExpressionValidator {
                regularExpression: /[0-9]{0,2}/
            }
        }
    }

    Connections {
        target: page.host
        function onExpandedChanged() {
            if (page.host && page.host.expanded) page.startVisit();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Left: Month Card
        Rectangle {
            id: monthCard
            Layout.preferredWidth: 304
            Layout.fillHeight: true
            radius: 18
            color: Qt.alpha(Theme.text, 0.055)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.07)

            CalMonth {
                id: month
                anchors.centerIn: parent
                cell: 39
                selected: page.selected
                onTodayRequested: page.selectToday()
                onPicked: (y, m, d) => {
                    page.selected = { "year": y, "month": m, "day": d };
                    if (m !== month.monthIndex)
                        month.page(y * 12 + m > month.year * 12 + month.monthIndex ? 1 : -1);
                    page.freshTime();
                }
            }
        }

        // Right: Day Agenda & Reminder Composer Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 18
            color: Qt.alpha(Theme.text, 0.055)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.07)

            Item {
                anchors.fill: parent
                anchors.margins: 16

                Column {
                    id: dayHead
                    width: parent.width
                    spacing: 2

                    CalText {
                        font.pixelSize: 17
                        weightAxis: 640
                        text: page.selectedDate.toLocaleDateString(I18n.locale, I18n.tr("dddd"))
                    }

                    CalText {
                        font.pixelSize: 12
                        weightAxis: 480
                        color: Theme.subtext
                        tabular: true
                        text: page.selectedDate.toLocaleDateString(I18n.locale, I18n.tr("d MMMM yyyy"))
                            + (page.dayItems.length
                                ? " · " + page.dayItems.length + (page.dayItems.length === 1 ? I18n.tr(" reminder") : I18n.tr(" reminders"))
                                : "")
                    }
                }

                Flickable {
                    id: list
                    anchors.top: dayHead.bottom
                    anchors.topMargin: 12
                    anchors.bottom: form.top
                    anchors.bottomMargin: 12
                    width: parent.width
                    contentHeight: itemsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: itemsCol
                        width: list.width
                        spacing: 6

                        Repeater {
                            model: page.dayItems

                            delegate: Rectangle {
                                required property var modelData
                                width: itemsCol.width
                                height: 48
                                radius: 12
                                color: Qt.alpha(Theme.text, 0.055)
                                border.width: 1
                                border.color: Qt.alpha(Theme.text, 0.06)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Qt.alpha(Theme.accent, 0.14)

                                        CalIcon {
                                            anchors.centerIn: parent
                                            text: modelData.repeat ? "repeat" : "notifications"
                                            font.pixelSize: 15
                                            filled: true
                                            color: Theme.accent
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        CalText {
                                            width: parent.width
                                            font.pixelSize: 13
                                            weightAxis: 580
                                            elide: Text.ElideRight
                                            text: modelData.name
                                        }

                                        CalText {
                                            width: parent.width
                                            font.pixelSize: 11
                                            weightAxis: 480
                                            color: Theme.subtext
                                            tabular: true
                                            text: Agenda.timeText(modelData) + (modelData.repeat ? " · " + Agenda.repeatText(modelData) : "")
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: delMouse.containsMouse ? Qt.alpha(Theme.colors.error || "#f38ba8", 0.18) : "transparent"

                                        CalIcon {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            font.pixelSize: 16
                                            color: delMouse.containsMouse ? (Theme.colors.error || "#f38ba8") : Qt.alpha(Theme.text, 0.55)
                                        }

                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Agenda.remove(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty day state (outside Flickable so it centers inside visible list bounds)
                Column {
                    visible: page.dayItems.length === 0
                    anchors.horizontalCenter: list.horizontalCenter
                    anchors.verticalCenter: list.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 44
                        radius: 14
                        color: Qt.alpha(Theme.accent, 0.10)

                        CalIcon {
                            anchors.centerIn: parent
                            text: "event_available"
                            font.pixelSize: 22
                            color: Qt.alpha(Theme.accent, 0.85)
                        }
                    }

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 13
                        weightAxis: 520
                        color: Theme.subtext
                        text: I18n.tr("A free day")
                    }
                }

                // Bottom Reminder Composer
                Column {
                    id: form
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 10

                    // Clean Matushell pill text input
                    Rectangle {
                        id: inputPill
                        width: parent.width
                        height: 38
                        radius: 19
                        color: nameInput.activeFocus ? Qt.alpha(Theme.text, 0.09) : Qt.alpha(Theme.text, 0.06)
                        border.width: 1
                        border.color: nameInput.activeFocus ? Qt.alpha(Theme.accent, 0.45) : Qt.alpha(Theme.text, 0.07)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            CalIcon {
                                text: "edit_calendar"
                                font.pixelSize: 16
                                color: nameInput.activeFocus ? Theme.accent : Theme.subtext
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                CalText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    visible: nameInput.text === ""
                                    font.pixelSize: 13
                                    weightAxis: 480
                                    color: Qt.alpha(Theme.text, 0.42)
                                    text: I18n.tr("New reminder…")
                                }

                                TextInput {
                                    id: nameInput
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
                                    onAccepted: page.submit()
                                }
                            }
                        }
                    }

                    // Past-time warning hint
                    CalText {
                        visible: page.past && nameInput.text.trim() !== ""
                        font.pixelSize: 11
                        weightAxis: 520
                        color: Theme.colors.error || "#f38ba8"
                        text: page.isToday()
                            ? I18n.tr("%1 has already gone by today", Agenda.timeText({ "hour": page.newHour, "minute": page.newMinute }))
                            : I18n.tr("That day has already gone by")
                    }

                    // Segmented Repeat Pill Bar
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 16
                        color: Qt.alpha(Theme.text, 0.05)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 3

                            Repeater {
                                model: Agenda.repeatOptions

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool active: page.newRepeat === modelData.key
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 13
                                    color: active
                                        ? Theme.accent
                                        : (repMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent")

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    CalText {
                                        anchors.centerIn: parent
                                        font.pixelSize: 11
                                        weightAxis: active ? 640 : 520
                                        color: active ? Theme.onAccent : Theme.subtext
                                        text: modelData.label
                                    }

                                    MouseArea {
                                        id: repMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.newRepeat = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    // Bottom Row: Time Pill + Add Action Pill
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            id: timeBox
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: timeRow.implicitWidth + 20
                            radius: 17
                            color: Qt.alpha(Theme.text, 0.06)
                            border.width: 1
                            border.color: Qt.alpha(Theme.text, 0.07)

                            Row {
                                id: timeRow
                                anchors.centerIn: parent
                                spacing: 2

                                TimeDigit {
                                    id: hourDigit
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: page.shownHour
                                    span: Prefs.clock24h ? 24 : 12
                                    nextDigit: minuteDigit
                                    onTyped: (v) => page.typeHour(v)
                                    onMeridiem: (wantPm) => page.setPm(wantPm)
                                    onAccepted: page.submit()
                                }

                                CalText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 13
                                    weightAxis: 640
                                    color: Theme.subtext
                                    text: ":"
                                }

                                TimeDigit {
                                    id: minuteDigit
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: page.newMinute
                                    span: 60
                                    onTyped: (v) => page.typeMinute(v)
                                    onMeridiem: (wantPm) => page.setPm(wantPm)
                                    onAccepted: page.submit()
                                }

                                Rectangle {
                                    visible: !Prefs.clock24h
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32
                                    height: 24
                                    radius: 12
                                    color: ampmMouse.containsMouse ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.accent, 0.10)

                                    CalText {
                                        anchors.centerIn: parent
                                        font.pixelSize: 11
                                        weightAxis: 640
                                        color: Theme.accent
                                        text: page.pm ? I18n.tr("PM") : I18n.tr("AM")
                                    }

                                    MouseArea {
                                        id: ampmMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setPm(!page.pm)
                                    }
                                }
                            }

                            WheelHandler {
                                onWheel: (e) => page.step(e.angleDelta.y > 0 ? 1 : -1)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: addBtn
                            readonly property bool enabledBtn: nameInput.text.trim() !== "" && !page.past
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: addRow.implicitWidth + 24
                            radius: 17
                            color: enabledBtn
                                ? (addMouse.pressed ? Qt.alpha(Theme.accent, 0.82) : Theme.accent)
                                : Qt.alpha(Theme.text, 0.08)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Row {
                                id: addRow
                                anchors.centerIn: parent
                                spacing: 5

                                CalIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "add"
                                    font.pixelSize: 16
                                    color: addBtn.enabledBtn ? Theme.onAccent : Qt.alpha(Theme.text, 0.35)
                                }

                                CalText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 12
                                    weightAxis: 640
                                    color: addBtn.enabledBtn ? Theme.onAccent : Qt.alpha(Theme.text, 0.35)
                                    text: I18n.tr("Add")
                                }
                            }

                            MouseArea {
                                id: addMouse
                                anchors.fill: parent
                                enabled: addBtn.enabledBtn
                                cursorShape: addBtn.enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: page.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
