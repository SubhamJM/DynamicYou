import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../../../"
import "../../"
import "../"

// Matushell UserCardWidget ported 1:1 to Dynamic You:
// Styles: "material" | "glass" | "blur" (ditherglass.frag.qsb)
// Sizes: "1x1" | "1x2" | "2x2" | "2x3"
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property var notchRoot: null
    property string tileId: "usercard"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "2x2")
    readonly property string cardStyle: {
        const s = String(opts.styleMode || "material");
        return (s === "glass" || s === "blur") ? s : "material";
    }
    readonly property string customAvatar: String(opts.customAvatar || "")
    readonly property string customBanner: String(opts.customBanner || "")

    readonly property bool isMaterial: cardStyle === "material"
    readonly property bool isBlur: cardStyle === "blur"
    readonly property bool isGlass: cardStyle === "glass"

    onActiveChanged: { if (typeof Sys !== "undefined") Sys.hold("usercard", root.active, 5000); }
    Component.onCompleted: {
        if (typeof Sys !== "undefined" && root.active) Sys.hold("usercard", true, 5000);
        if (typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }
    Component.onDestruction: { if (typeof Sys !== "undefined") Sys.hold("usercard", false, 5000); }

    readonly property string username: {
        if (typeof Sys !== "undefined" && Sys.info && Sys.info.user) return String(Sys.info.user);
        return String(Quickshell.env("USER") || "kuro");
    }
    readonly property string hostname: {
        if (typeof Sys !== "undefined" && Sys.info && Sys.info.host) return String(Sys.info.host);
        return "archlinux";
    }

    readonly property string probedAvatar: (typeof WidgetTelemetry !== "undefined") ? WidgetTelemetry.avatarUrl : ""
    readonly property string probedWall: (typeof WidgetTelemetry !== "undefined") ? WidgetTelemetry.wallpaperPath : ""
    readonly property string avatarUrl: customAvatar !== ""
        ? (customAvatar.indexOf("://") >= 0 ? customAvatar : ("file://" + encodeURI(customAvatar)))
        : probedAvatar
    readonly property string bannerUrl: customBanner !== ""
        ? (customBanner.indexOf("://") >= 0 ? customBanner : ("file://" + encodeURI(customBanner)))
        : (probedWall !== "" ? ("file://" + encodeURI(probedWall)) : "")

    readonly property int uptimeSec: (typeof Sys !== "undefined" && Sys.uptime > 0) ? Math.floor(Sys.uptime) : 0
    readonly property int uptimeDays: Math.floor(uptimeSec / 86400)
    readonly property int uptimeHours: Math.floor((uptimeSec % 86400) / 3600)
    readonly property int uptimeMinutes: Math.floor((uptimeSec % 3600) / 60)
    readonly property string compactUptime: uptimeDays > 0
        ? (uptimeDays + "d " + uptimeHours + "h")
        : (uptimeHours > 0 ? (uptimeHours + "h " + uptimeMinutes + "m") : (Math.max(1, uptimeMinutes) + "m"))

    readonly property date nowDate: new Date()
    readonly property string greetingIcon: {
        const h = nowDate.getHours();
        return h >= 5 && h < 12 ? "wb_sunny" : (h < 18 ? "wb_twilight" : "nights_stay");
    }
    readonly property string greetingText: {
        const h = nowDate.getHours();
        return h >= 5 && h < 12 ? "Good Morning" : (h < 18 ? "Good Afternoon" : "Good Evening");
    }
    readonly property string todayString: "Today · " + Qt.formatDate(nowDate, "ddd, d MMM")

    readonly property var quip: {
        const rep = (typeof WeatherSource !== "undefined") ? WeatherSource.report : null;
        const desc = rep ? String(WeatherSource.descFor(rep.code) || "").toLowerCase() : "";
        if (desc.indexOf("rain") >= 0 || desc.indexOf("drizzle") >= 0 || desc.indexOf("shower") >= 0) {
            return { text: "Raining, grab a warm drink", icon: "coffee" };
        }
        if (desc.indexOf("clear") >= 0 || desc.indexOf("sun") >= 0) {
            return { text: "Clear skies, good day out", icon: "eco" };
        }
        if (desc.indexOf("cloud") >= 0 || desc.indexOf("overcast") >= 0 || desc.indexOf("fog") >= 0) {
            return { text: "A bit cloudy outside today", icon: "cloud" };
        }
        if (desc.indexOf("snow") >= 0) {
            return { text: "Snowing outside, stay cozy", icon: "ac_unit" };
        }
        return { text: "Ready when you are", icon: "auto_awesome" };
    }

    function lockNow() { Quickshell.execDetached(["sh", "-c", "loginctl lock-session"]); }
    function openSettingsNow() {
        if (root.notchRoot && typeof root.notchRoot.openSettings === "function") root.notchRoot.openSettings();
    }
    function openPowerMenuNow() {
        if (typeof GlobalStates !== "undefined") GlobalStates.sessionOpen = true;
    }

    readonly property color bgColor: Theme.m3.primary_container ?? Theme.colors.card_bg
    readonly property color onSurface: isMaterial ? (Theme.m3.on_primary_container ?? Theme.colors.text_primary) : (Theme.m3.on_surface ?? Theme.colors.text_primary)
    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color accentOn: Theme.m3.on_primary ?? "#101014"
    readonly property color chipFill: isMaterial
        ? Qt.alpha(onSurface, 0.08)
        : (isBlur ? Qt.rgba(1, 1, 1, 0.16) : Qt.alpha(Theme.m3.surface_container_high ?? "#2b2930", 0.72))
    readonly property color iconBtnBg: chipFill
    readonly property color lockBtnFill: isMaterial ? onSurface : accent
    readonly property color lockBtnOn: isMaterial ? bgColor : accentOn

    MatusBackdrop {
        anchors.fill: parent
        style: root.cardStyle
        cornerRadius: WidgetStore.s(26)
        materialColor: root.bgColor
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.sizeMode === "1x1") return oneByOneComp;
            if (root.sizeMode === "1x2") return oneByTwoComp;
            if (root.sizeMode === "2x3") return twoByThreeComp;
            return twoByTwoComp;
        }
    }

    component AvatarView: Item {
        property string url: ""
        property real rad: WidgetStore.s(18)
        property real borderPx: 0

        Rectangle {
            id: avBg
            anchors.fill: parent
            radius: parent.rad
            color: Theme.m3.surface_container_high ?? Theme.colors.hover_bg
            clip: true

            Image {
                id: avImg
                anchors.fill: parent
                source: parent.parent.url
                sourceSize: Qt.size(160, 160)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }

            Rectangle {
                id: avMask
                anchors.fill: parent
                radius: parent.radius
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: avImg
                maskSource: avMask
                visible: avImg.status === Image.Ready
            }

            MaterialSymbol {
                visible: avImg.status !== Image.Ready
                anchors.centerIn: parent
                text: "person"
                iconSize: WidgetStore.si(Math.round(Math.min(avBg.width, avBg.height) * 0.44 / WidgetStore.uiScale))
                fill: 1
                color: Qt.alpha(root.onSurface, 0.72)
            }

            Rectangle {
                visible: parent.parent.borderPx > 0
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: parent.parent.borderPx
                border.color: root.isMaterial ? root.bgColor : (Theme.m3.surface_container ?? "#11131a")
            }
        }
    }

    component HeroBanner: Item {
        property real rad: WidgetStore.s(16)
        clip: true

        Rectangle {
            id: bannerBg
            anchors.fill: parent
            radius: parent.rad
            color: Theme.m3.surface_container_high ?? Theme.colors.hover_bg

            Image {
                id: bannerImg
                anchors.fill: parent
                source: root.bannerUrl
                sourceSize: Qt.size(480, 220)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }

            Rectangle {
                id: bannerMask
                anchors.fill: parent
                radius: parent.radius
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: bannerImg
                maskSource: bannerMask
                visible: bannerImg.status === Image.Ready
            }
        }
    }

    component MatusActionButton: Rectangle {
        property string icon: ""
        property real btnSize: WidgetStore.s(36)
        property bool isError: false
        signal triggered()

        Layout.preferredWidth: btnSize
        Layout.preferredHeight: btnSize
        width: btnSize
        height: btnSize
        radius: btnMouse.containsMouse ? WidgetStore.s(12) : width / 2
        Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        color: btnMouse.containsMouse
            ? (isError ? (Theme.m3.error ?? "#ffb4ab") : root.accent)
            : root.iconBtnBg

        MaterialSymbol {
            anchors.centerIn: parent
            text: parent.icon
            iconSize: WidgetStore.si(16)
            color: btnMouse.containsMouse
                ? (parent.isError ? (Theme.m3.on_error ?? "#101014") : root.accentOn)
                : root.onSurface
        }

        MouseArea {
            id: btnMouse
            enabled: root.interactive
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }

    // 1x1 Full-bleed Avatar Tile
    Component {
        id: oneByOneComp
        Item {
            anchors.fill: parent
            AvatarView {
                anchors.fill: parent
                url: root.avatarUrl
                rad: WidgetStore.s(26)
            }
            MouseArea {
                enabled: root.interactive
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openSettingsNow()
                onDoubleClicked: root.lockNow()
            }
        }
    }

    // 1x2 Horizontal Greeting Card
    Component {
        id: oneByTwoComp
        RowLayout {
            anchors { fill: parent; margins: WidgetStore.s(12) }
            spacing: WidgetStore.s(12)

            AvatarView {
                Layout.preferredWidth: WidgetStore.s(86)
                Layout.preferredHeight: WidgetStore.s(86)
                Layout.alignment: Qt.AlignVCenter
                url: root.avatarUrl
                rad: WidgetStore.s(18)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: WidgetStore.s(2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(4)
                    MaterialSymbol { text: root.greetingIcon; iconSize: WidgetStore.si(14); color: root.accent }
                    Text {
                        text: root.greetingText
                        color: root.accent
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(10.5)
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Hi, " + root.username + "!"
                    color: root.onSurface
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(16)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: root.todayString
                    color: root.onSurface
                    opacity: 0.70
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(11)
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(6)

                    Rectangle {
                        height: WidgetStore.s(26)
                        width: up1Row.implicitWidth + WidgetStore.s(12)
                        radius: height / 2
                        color: root.chipFill
                        Row {
                            id: up1Row
                            anchors.centerIn: parent
                            spacing: WidgetStore.s(4)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "schedule"; iconSize: WidgetStore.si(12); color: Qt.alpha(root.onSurface, 0.72) }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Up " + root.compactUptime; color: Qt.alpha(root.onSurface, 0.75); font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(10); renderType: Text.NativeRendering }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MatusActionButton {
                        icon: "lock"
                        btnSize: WidgetStore.s(28)
                        onTriggered: root.lockNow()
                    }
                }
            }
        }
    }

    // 2x2 Square Hero Profile Card
    Component {
        id: twoByTwoComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(12) }
            spacing: WidgetStore.s(8)

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(92)

                HeroBanner {
                    anchors.fill: parent
                    rad: WidgetStore.s(16)
                }

                AvatarView {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: WidgetStore.s(10); bottomMargin: -WidgetStore.s(14) }
                    width: WidgetStore.s(64)
                    height: WidgetStore.s(64)
                    rad: width / 2
                    borderPx: WidgetStore.s(2)
                    url: root.avatarUrl
                }
            }

            Item { Layout.preferredHeight: WidgetStore.s(8) }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(6)

                    Text {
                        text: root.username
                        color: root.onSurface
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(16)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        height: WidgetStore.s(18)
                        width: hostTxt.implicitWidth + WidgetStore.s(10)
                        radius: height / 2
                        color: Qt.alpha(root.accent, 0.16)
                        Text {
                            id: hostTxt
                            anchors.centerIn: parent
                            text: "@" + root.hostname
                            color: root.accent
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(10)
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.greetingText + " · Up " + root.compactUptime
                    color: root.onSurface
                    opacity: 0.72
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(11)
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }

            // Weather Quip chip
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(28)
                radius: WidgetStore.s(9)
                color: root.chipFill

                RowLayout {
                    anchors { fill: parent; leftMargin: WidgetStore.s(8); rightMargin: WidgetStore.s(8) }
                    spacing: WidgetStore.s(6)
                    MaterialSymbol { text: root.quip.icon; iconSize: WidgetStore.si(14); color: root.accent }
                    Text {
                        Layout.fillWidth: true
                        text: root.quip.text
                        color: root.onSurface
                        opacity: 0.85
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(11)
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Lock pill + Settings + Power
            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(6)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: WidgetStore.s(36)
                    radius: height / 2
                    color: lockMouse22.pressed ? Qt.alpha(root.lockBtnFill, 0.82) : root.lockBtnFill

                    Row {
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(6)
                        MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "lock"; iconSize: WidgetStore.si(16); color: root.lockBtnOn }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Lock"; color: root.lockBtnOn; font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12); font.weight: Font.DemiBold; renderType: Text.NativeRendering }
                    }
                    MouseArea {
                        id: lockMouse22
                        enabled: root.interactive
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lockNow()
                    }
                }

                MatusActionButton { icon: "settings"; btnSize: WidgetStore.s(36); onTriggered: root.openSettingsNow() }
                MatusActionButton { icon: "power_settings_new"; btnSize: WidgetStore.s(36); isError: true; onTriggered: root.openPowerMenuNow() }
            }
        }
    }

    // 2x3 Wide Banner Stats Deck
    Component {
        id: twoByThreeComp
        ColumnLayout {
            anchors { fill: parent; margins: WidgetStore.s(14) }
            spacing: WidgetStore.s(8)

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(112)

                HeroBanner {
                    anchors.fill: parent
                    rad: WidgetStore.s(18)
                }

                MatusActionButton {
                    anchors { top: parent.top; right: parent.right; margins: WidgetStore.s(8) }
                    icon: "settings"
                    btnSize: WidgetStore.s(30)
                    onTriggered: root.openSettingsNow()
                }

                AvatarView {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: WidgetStore.s(14); bottomMargin: -WidgetStore.s(16) }
                    width: WidgetStore.s(72)
                    height: WidgetStore.s(72)
                    rad: width / 2
                    borderPx: WidgetStore.s(2)
                    url: root.avatarUrl
                }
            }

            Item { Layout.preferredHeight: WidgetStore.s(8) }

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(10)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(1)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)
                        Text {
                            text: root.username
                            color: root.onSurface
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(16)
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                        Rectangle {
                            height: WidgetStore.s(20)
                            width: host23.implicitWidth + WidgetStore.s(10)
                            radius: height / 2
                            color: Qt.alpha(root.accent, 0.16)
                            Text {
                                id: host23
                                anchors.centerIn: parent
                                text: "@" + root.hostname
                                color: root.accent
                                font.family: "Google Sans Flex"
                                font.pixelSize: WidgetStore.si(10)
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.greetingText + " · " + root.todayString
                        color: root.onSurface
                        opacity: 0.72
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(11)
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Rectangle {
                    height: WidgetStore.s(28)
                    width: Math.min(WidgetStore.s(180), quipRow.implicitWidth + WidgetStore.s(14))
                    radius: WidgetStore.s(9)
                    color: root.chipFill

                    RowLayout {
                        id: quipRow
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(5)
                        MaterialSymbol { text: root.quip.icon; iconSize: WidgetStore.si(14); color: root.accent }
                        Text {
                            text: root.quip.text
                            color: root.onSurface
                            opacity: 0.85
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(10)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // Segmented Uptime Counters + Actions Row
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: WidgetStore.s(10)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: WidgetStore.s(16)
                    color: root.chipFill

                    RowLayout {
                        anchors { fill: parent; margins: WidgetStore.s(8) }
                        spacing: 0

                        Repeater {
                            model: [
                                { val: String(root.uptimeDays), lbl: "days" },
                                { val: String(root.uptimeHours), lbl: "hours" },
                                { val: String(root.uptimeMinutes), lbl: "min" }
                            ]

                            RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 0

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignCenter
                                    spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.val
                                        color: root.onSurface
                                        font.family: "Google Sans Flex"
                                        font.pixelSize: WidgetStore.si(18)
                                        font.weight: Font.DemiBold
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.lbl
                                        color: root.onSurface
                                        opacity: 0.65
                                        font.family: "Google Sans Flex"
                                        font.pixelSize: WidgetStore.si(10)
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Rectangle {
                                    visible: index < 2
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: WidgetStore.s(26)
                                    color: Qt.alpha(root.onSurface, 0.16)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: WidgetStore.s(6)

                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(102)
                        Layout.preferredHeight: WidgetStore.s(42)
                        radius: height / 2
                        color: lockMouse23.pressed ? Qt.alpha(root.lockBtnFill, 0.82) : root.lockBtnFill

                        Row {
                            anchors.centerIn: parent
                            spacing: WidgetStore.s(6)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "lock"; iconSize: WidgetStore.si(17); color: root.lockBtnOn }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Lock"; color: root.lockBtnOn; font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12.5); font.weight: Font.DemiBold; renderType: Text.NativeRendering }
                        }
                        MouseArea {
                            id: lockMouse23
                            enabled: root.interactive
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.lockNow()
                        }
                    }

                    MatusActionButton { icon: "power_settings_new"; btnSize: WidgetStore.s(42); isError: true; onTriggered: root.openPowerMenuNow() }
                }
            }
        }
    }
}
