pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

Item {
    id: root

    property rect avoid: Qt.rect(0, 0, 0, 0)
    readonly property bool peeking: peekBtnMouse.pressed || LockConfig.peeking
    readonly property bool onRight: root.avoid.width > 0
        && root.avoid.x < panel.width + 56
        && root.avoid.y + root.avoid.height > root.height - panel.height - 56

    readonly property string group: LockConfig.groups.includes(LockConfig.activeGroup) ? LockConfig.activeGroup : "Layouts"

    component InspText: Text {
        property bool tabular: false
        property int weightAxis: 540
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: weightAxis >= 640 ? Font.Bold : (weightAxis >= 560 ? Font.DemiBold : Font.Medium)
        font.variableAxes: ({ "wght": weightAxis })
        font.features: tabular ? ({ "tnum": 1 }) : ({})
        renderType: Text.QtRendering
        font.hintingPreference: Font.PreferNoHinting
        color: Theme.text
    }

    component InspIcon: Text {
        property bool filled: false
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 18
        font.variableAxes: ({ "FILL": filled ? 1 : 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
        renderType: Text.CurveRendering
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Theme.text
    }

    component InspSwitchRow: Rectangle {
        property string label: ""
        property bool checked: false
        signal toggled(bool val)

        width: rowColumn.width
        height: 40
        radius: 12
        color: swM.containsMouse ? Qt.alpha(Theme.text, 0.08) : Qt.alpha(Theme.text, 0.05)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            InspText {
                Layout.fillWidth: true
                text: label
                font.pixelSize: 13
                weightAxis: 540
            }

            Rectangle {
                width: 38
                height: 22
                radius: 11
                color: checked ? Theme.accent : Qt.alpha(Theme.text, 0.16)
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    x: checked ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: checked ? Theme.onAccent : Qt.alpha(Theme.text, 0.85)
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: swM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggled(!checked)
        }
    }

    component InspSliderRow: Rectangle {
        id: slRow
        property string label: ""
        property real value: 0
        property real minVal: 0
        property real maxVal: 100
        property real step: 1
        property string suffix: ""
        signal moved(real v)

        width: rowColumn.width
        height: 52
        radius: 12
        color: Qt.alpha(Theme.text, 0.05)

        readonly property real norm: maxVal > minVal ? Math.max(0, Math.min(1, (value - minVal) / (maxVal - minVal))) : 0

        Column {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 6

            RowLayout {
                width: parent.width

                InspText {
                    Layout.fillWidth: true
                    text: slRow.label
                    font.pixelSize: 12
                    weightAxis: 540
                }

                InspText {
                    font.pixelSize: 11
                    weightAxis: 620
                    tabular: true
                    color: Theme.accent
                    text: Math.round(slRow.value) + slRow.suffix
                }
            }

            Item {
                id: track
                width: parent.width
                height: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.14)

                    Rectangle {
                        width: parent.width * slRow.norm
                        height: parent.height
                        radius: 3
                        color: Theme.accent
                    }
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * slRow.norm - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function applyX(mx) {
                        const r = Math.max(0, Math.min(1, mx / Math.max(1, width)));
                        let v = slRow.minVal + r * (slRow.maxVal - slRow.minVal);
                        if (slRow.step > 0) v = Math.round(v / slRow.step) * slRow.step;
                        v = Math.max(slRow.minVal, Math.min(slRow.maxVal, v));
                        slRow.moved(v);
                    }
                    onPressed: m => applyX(m.x)
                    onPositionChanged: m => { if (pressed) applyX(m.x); }
                }
            }
        }
    }

    component InspChoiceRow: Rectangle {
        id: chRow
        property string label: ""
        property var options: [] // [{ key, label }]
        property string current: ""
        signal picked(string k)

        width: rowColumn.width
        height: 62
        radius: 12
        color: Qt.alpha(Theme.text, 0.05)

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            InspText {
                font.pixelSize: 12
                weightAxis: 540
                color: Theme.subtext
                text: chRow.label
            }

            RowLayout {
                width: parent.width
                spacing: 4

                Repeater {
                    model: chRow.options

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: chRow.current === modelData.key
                        Layout.fillWidth: true
                        height: 26
                        radius: 13
                        color: on ? Theme.accent : (cm.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05))

                        InspText {
                            anchors.centerIn: parent
                            font.pixelSize: 11
                            weightAxis: on ? 640 : 520
                            color: on ? Theme.onAccent : Theme.subtext
                            text: modelData.label
                        }

                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chRow.picked(modelData.key)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: panel
        readonly property int panelMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        x: root.onRight ? root.width - width - panelMargin : panelMargin
        width: 380
        height: Math.min(Math.round(root.height * 0.84), 660)
        radius: 24
        color: Qt.alpha(Theme.colors.bg || "#0e0e14", 0.90)
        opacity: root.peeking ? 0 : 1
        visible: opacity > 0.01

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Prevent clicks inside inspector from clearing lock selection
        MouseArea { anchors.fill: parent; z: -1 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Qt.alpha(Theme.accent, 0.16)

                    InspIcon {
                        anchors.centerIn: parent
                        text: "lock"
                        filled: true
                        font.pixelSize: 17
                        color: Theme.accent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    InspText {
                        text: "Lock screen"
                        font.pixelSize: 15
                        weightAxis: 660
                    }

                    InspText {
                        text: LockConfig.selection.length > 0
                            ? "Drag or use Arrows (Shift: ignore snap)"
                            : "Drag blocks or customize below"
                        font.pixelSize: 11
                        weightAxis: 480
                        color: Theme.subtext
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: root.peeking ? Theme.accent : (peekBtnMouse.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.06))

                    InspIcon {
                        anchors.centerIn: parent
                        text: "visibility"
                        font.pixelSize: 16
                        color: root.peeking ? Theme.onAccent : Theme.subtext
                    }

                    MouseArea {
                        id: peekBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: doneTxt.implicitWidth + 24
                    radius: 16
                    color: Theme.accent

                    InspText {
                        id: doneTxt
                        anchors.centerIn: parent
                        text: "Done"
                        font.pixelSize: 12
                        weightAxis: 660
                        color: Theme.onAccent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            LockConfig.editing = false;
                            LockConfig.selection = "";
                        }
                    }
                }
            }

            // Category Group Chips
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: LockConfig.groups

                    delegate: Rectangle {
                        required property string modelData
                        readonly property string blockId: LockConfig.blockForGroup(modelData)
                        readonly property bool current: root.group === modelData
                        readonly property bool off: {
                            LockConfig.revision;
                            return blockId.length > 0 && !LockConfig.enabled(blockId);
                        }

                        width: chipTxt.implicitWidth + 20
                        height: 28
                        radius: 14
                        opacity: off && !current ? 0.50 : 1.0
                        color: current ? Theme.accent : (gm.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.06))

                        InspText {
                            id: chipTxt
                            anchors.centerIn: parent
                            font.pixelSize: 11
                            weightAxis: current ? 640 : 520
                            color: current ? Theme.onAccent : Theme.text
                            text: modelData
                        }

                        MouseArea {
                            id: gm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LockConfig.activeGroup = modelData;
                                LockConfig.selection = blockId;
                            }
                        }
                    }
                }
            }

            // Scrollable Settings Body
            Flickable {
                id: rowList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: rowColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rowColumn
                    width: rowList.width
                    spacing: 8

                    // --- LAYOUT PRESETS ---
                    Repeater {
                        model: root.group === "Layouts" ? LockConfig.presets : []

                        delegate: Rectangle {
                            id: lcard
                            required property var modelData
                            readonly property bool current: {
                                LockConfig.revision;
                                return LockConfig.presetId === modelData.id;
                            }

                            width: rowColumn.width
                            height: 76
                            radius: 14
                            color: current ? Qt.alpha(Theme.accent, 0.16) : (lcM.containsMouse ? Qt.alpha(Theme.text, 0.09) : Qt.alpha(Theme.text, 0.05))

                            // Mini Wireframe Preview
                            Rectangle {
                                id: mini
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 104
                                height: 58
                                radius: 8
                                color: "#0b0b10"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: LockConfig.desktopWallpaper !== "" ? "file://" + LockConfig.desktopWallpaper : ""
                                    fillMode: Image.PreserveAspectCrop
                                    opacity: 0.45
                                }

                                Repeater {
                                    model: LockConfig.blockIds.filter(id => lcard.modelData.blocks[id]?.enable)
                                    delegate: Rectangle {
                                        required property string modelData
                                        readonly property string zName: lcard.modelData.blocks[modelData].zone
                                        readonly property var anc: LockConfig.zoneAnchor(zName, mini.width, mini.height, 8)
                                        readonly property var sizes: ({
                                            clock: [28, 10], glance: [32, 4], media: [26, 8],
                                            activity: [18, 4], session: [22, 6], status: [16, 3]
                                        })
                                        width: sizes[modelData][0]
                                        height: sizes[modelData][1]
                                        x: Math.round(anc.align === Qt.AlignLeft ? anc.x : (anc.align === Qt.AlignRight ? anc.x - width : anc.x - width / 2))
                                        y: Math.round(anc.up ? anc.y - height : (zName === "center" ? anc.y - height / 2 : anc.y))
                                        radius: 2
                                        color: modelData === "clock" ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                    }
                                }
                            }

                            Column {
                                anchors.left: mini.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                InspText {
                                    text: modelData.label
                                    font.pixelSize: 13
                                    weightAxis: 640
                                    color: current ? Theme.accent : Theme.text
                                }

                                InspText {
                                    width: parent.width
                                    text: modelData.description
                                    font.pixelSize: 11
                                    weightAxis: 480
                                    color: Theme.subtext
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: lcM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: LockConfig.applyPreset(modelData.id)
                            }
                        }
                    }

                    // --- SCENE CONTROLS ---
                    InspChoiceRow {
                        visible: root.group === "Scene"
                        label: "Material"
                        current: LockConfig.material
                        options: [{ key: "glass", label: "Glass" }, { key: "tint", label: "Tint" }, { key: "none", label: "Minimal" }]
                        onPicked: k => LockConfig.updateRoot({ material: k })
                    }
                    InspChoiceRow {
                        visible: root.group === "Scene"
                        label: "Backdrop source"
                        current: String(LockConfig.scene.source ?? "desktop")
                        options: [{ key: "desktop", label: "Wallpaper" }, { key: "colour", label: "Solid" }]
                        onPicked: k => LockConfig.updateScene({ source: k })
                    }
                    InspSliderRow {
                        visible: root.group === "Scene"
                        label: "Blur"
                        minVal: 0; maxVal: 100; step: 5; suffix: "%"
                        value: Number(LockConfig.scene.blur ?? 88)
                        onMoved: v => LockConfig.updateScene({ blur: v })
                    }
                    InspSliderRow {
                        visible: root.group === "Scene"
                        label: "Colour left"
                        minVal: 0; maxVal: 100; step: 5; suffix: "%"
                        value: Number(LockConfig.scene.saturation ?? 18)
                        onMoved: v => LockConfig.updateScene({ saturation: v })
                    }
                    InspSliderRow {
                        visible: root.group === "Scene"
                        label: "Dim"
                        minVal: 0; maxVal: 80; step: 4; suffix: "%"
                        value: Number(LockConfig.scene.dim ?? 8)
                        onMoved: v => LockConfig.updateScene({ dim: v })
                    }
                    InspSliderRow {
                        visible: root.group === "Scene"
                        label: "Vignette"
                        minVal: 0; maxVal: 100; step: 5; suffix: "%"
                        value: Number(LockConfig.scene.vignette ?? 26)
                        onMoved: v => LockConfig.updateScene({ vignette: v })
                    }
                    InspChoiceRow {
                        visible: root.group === "Scene"
                        label: "Scrim style"
                        current: String(LockConfig.scene.scrim ?? "gradient")
                        options: [{ key: "gradient", label: "Gradient" }, { key: "flat", label: "Flat" }, { key: "none", label: "None" }]
                        onPicked: k => LockConfig.updateScene({ scrim: k })
                    }
                    InspSwitchRow {
                        visible: root.group === "Scene"
                        label: "Subtle wallpaper drift"
                        checked: String(LockConfig.scene.motion ?? "none") === "drift"
                        onToggled: val => LockConfig.updateScene({ motion: val ? "drift" : "none" })
                    }

                    // --- TYPE CONTROLS ---
                    InspChoiceRow {
                        visible: root.group === "Type"
                        label: "Clock font"
                        current: String(LockConfig.typeOptions.clockFont ?? "numbers")
                        options: [{ key: "numbers", label: "Sans Flex" }, { key: "mono", label: "Mono" }]
                        onPicked: k => LockConfig.updateType({ clockFont: k })
                    }
                    InspSliderRow {
                        visible: root.group === "Type"
                        label: "Clock size"
                        minVal: 64; maxVal: 184; step: 4; suffix: "px"
                        value: Number(LockConfig.typeOptions.clockSize ?? 112)
                        onMoved: v => LockConfig.updateType({ clockSize: v })
                    }
                    InspSliderRow {
                        visible: root.group === "Type"
                        label: "Clock weight"
                        minVal: 200; maxVal: 800; step: 50; suffix: ""
                        value: Number(LockConfig.typeOptions.clockWeight ?? 700)
                        onMoved: v => LockConfig.updateType({ clockWeight: v })
                    }
                    InspChoiceRow {
                        visible: root.group === "Type"
                        label: "Clock colour"
                        current: String(LockConfig.typeOptions.accent ?? "plain")
                        options: [{ key: "plain", label: "White" }, { key: "accent", label: "Theme accent" }]
                        onPicked: k => LockConfig.updateType({ accent: k })
                    }
                    InspChoiceRow {
                        visible: root.group === "Type"
                        label: "Time format"
                        current: String(LockConfig.typeOptions.clockFormat ?? "auto")
                        options: [{ key: "auto", label: "System" }, { key: "12h", label: "12h" }, { key: "24h", label: "24h" }]
                        onPicked: k => LockConfig.updateType({ clockFormat: k })
                    }
                    InspSwitchRow {
                        visible: root.group === "Type"
                        label: "Show seconds"
                        checked: Boolean(LockConfig.typeOptions.seconds ?? false)
                        onToggled: val => LockConfig.updateType({ seconds: val })
                    }

                    // --- PER-BLOCK CONTROLS ---
                    readonly property string activeBlk: LockConfig.blockForGroup(root.group)

                    InspSwitchRow {
                        visible: rowColumn.activeBlk !== ""
                        label: "Show " + root.group
                        checked: rowColumn.activeBlk !== "" ? LockConfig.enabled(rowColumn.activeBlk) : false
                        onToggled: val => { if (rowColumn.activeBlk !== "") LockConfig.writeBlock(rowColumn.activeBlk, { enable: val }); }
                    }
                    InspSliderRow {
                        visible: rowColumn.activeBlk !== ""
                        label: "Scale"
                        minVal: 60; maxVal: 160; step: 5; suffix: "%"
                        value: rowColumn.activeBlk !== "" ? Math.round(LockConfig.scaleOf(rowColumn.activeBlk) * 100) : 100
                        onMoved: v => { if (rowColumn.activeBlk !== "") LockConfig.writeBlock(rowColumn.activeBlk, { scale: v }); }
                    }
                    InspChoiceRow {
                        visible: root.group === "Clock"
                        label: "Style"
                        current: String(LockConfig.entry("clock").style ?? "stack")
                        options: [{ key: "stack", label: "Stacked" }, { key: "inline", label: "Inline" }, { key: "minimal", label: "Compact" }]
                        onPicked: k => LockConfig.writeBlock("clock", { style: k })
                    }
                    InspSwitchRow {
                        visible: root.group === "Clock"
                        label: "Show date"
                        checked: Boolean(LockConfig.entry("clock").date ?? true)
                        onToggled: val => LockConfig.writeBlock("clock", { date: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "At a glance"
                        label: "Weather chip"
                        checked: Boolean(LockConfig.entry("glance").weather ?? true)
                        onToggled: val => LockConfig.writeBlock("glance", { weather: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "At a glance"
                        label: "Upcoming reminder chip"
                        checked: Boolean(LockConfig.entry("glance").events ?? true)
                        onToggled: val => LockConfig.writeBlock("glance", { events: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "At a glance"
                        label: "Battery chip"
                        checked: Boolean(LockConfig.entry("glance").battery ?? true)
                        onToggled: val => LockConfig.writeBlock("glance", { battery: val })
                    }
                    InspChoiceRow {
                        visible: root.group === "Now playing"
                        label: "Card style"
                        current: String(LockConfig.entry("media").style ?? "card")
                        options: [{ key: "card", label: "Glass card" }, { key: "bare", label: "Bare" }]
                        onPicked: k => LockConfig.writeBlock("media", { style: k })
                    }
                    InspSwitchRow {
                        visible: root.group === "Sign in"
                        label: "Show avatar"
                        checked: Boolean(LockConfig.entry("session").avatar ?? true)
                        onToggled: val => LockConfig.writeBlock("session", { avatar: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "Sign in"
                        label: "Show username"
                        checked: Boolean(LockConfig.entry("session").name ?? true)
                        onToggled: val => LockConfig.writeBlock("session", { name: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "Sign in"
                        label: "Show helper hint"
                        checked: Boolean(LockConfig.entry("session").hint ?? true)
                        onToggled: val => LockConfig.writeBlock("session", { hint: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "Status"
                        label: "Keyboard layout"
                        checked: Boolean(LockConfig.entry("status").keyboard ?? true)
                        onToggled: val => LockConfig.writeBlock("status", { keyboard: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "Status"
                        label: "Network status"
                        checked: Boolean(LockConfig.entry("status").network ?? true)
                        onToggled: val => LockConfig.writeBlock("status", { network: val })
                    }
                    InspSwitchRow {
                        visible: root.group === "Status"
                        label: "Battery readout"
                        checked: Boolean(LockConfig.entry("status").battery ?? true)
                        onToggled: val => LockConfig.writeBlock("status", { battery: val })
                    }
                }
            }
        }
    }
}
