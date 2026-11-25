import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../../../"
import "../../../services"
import "../../../modules/common"
import "../../"
import "../"

// Authentic end-4pc M3 Expressive User Card supporting 1x1, 1x2, 2x2, 2x3 + quip/uptime toggles
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "end4User"
    property var notchRoot: null

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "2x2")
    readonly property bool showQuip: opts.showQuip !== false
    readonly property bool showUptime: opts.showUptime !== false
    readonly property bool showActions: opts.showActions !== false
    readonly property bool showShadow: opts.showShadow !== false
    readonly property string customAvatar: String(opts.customAvatar || "")
    readonly property string customBanner: String(opts.customBanner || "")
    readonly property bool resizing: resizeHandle.resizing

    onActiveChanged: {
        if (typeof Sys !== "undefined") Sys.hold("end4user", root.active, 5000);
        if (root.active && typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }
    Component.onCompleted: {
        if (typeof Sys !== "undefined" && root.active) Sys.hold("end4user", true, 5000);
        if (typeof WeatherSource !== "undefined") WeatherSource.ensure();
    }
    Component.onDestruction: {
        if (typeof Sys !== "undefined") Sys.hold("end4user", false, 5000);
    }

    readonly property string userName: {
        if (typeof Sys !== "undefined" && Sys.info && Sys.info.user)
            return String(Sys.info.user);
        return String(Quickshell.env("USER") || "user");
    }
    readonly property string hostName: {
        if (typeof Sys !== "undefined" && Sys.info && Sys.info.host)
            return String(Sys.info.host);
        return "archlinux";
    }
    readonly property string userDisplay: userName.length > 10 ? userName : (userName + "@" + hostName)

    readonly property int uptimeDays: (typeof Sys !== "undefined" && Sys.uptime > 0) ? Math.floor(Sys.uptime / 86400) : 0
    readonly property int uptimeHours: (typeof Sys !== "undefined" && Sys.uptime > 0) ? Math.floor((Sys.uptime % 86400) / 3600) : 0
    readonly property int uptimeMinutes: (typeof Sys !== "undefined" && Sys.uptime > 0) ? Math.floor((Sys.uptime % 3600) / 60) : 0

    readonly property string greetingText: {
        const h = new Date().getHours();
        if (h < 12) return "Good Morning";
        if (h < 18) return "Good Afternoon";
        return "Good Evening";
    }
    readonly property string todayString: "Today • " + Qt.formatDate(new Date(), "ddd d MMM")

    property string avatarSource: ""
    property string wallpaperPath: ""

    readonly property string configuredWallpaper: {
        const bg = (Config.options && Config.options.background && Config.options.background.wallpaperPath)
            ? String(Config.options.background.wallpaperPath)
            : "";
        if (bg === "" || /\.(mp4|webm|mkv|avi|mov)$/i.test(bg)) return "";
        return bg;
    }
    readonly property string effectiveWallpaper: customBanner !== ""
        ? customBanner
        : (wallpaperPath !== "" ? wallpaperPath : configuredWallpaper)
    readonly property string effectiveAvatar: customAvatar !== ""
        ? ("file://" + encodeURI(customAvatar))
        : avatarSource

    Process {
        id: probeUserAssets
        running: true
        command: [
            "sh", "-c",
            "av=''; for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do " +
            "  if [ -f \"$f\" ]; then av=\"file://$f\"; break; fi; " +
            "done; " +
            "wp=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1); " +
            "if [ -z \"$wp\" ] || [ ! -f \"$wp\" ]; then " +
            "  cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/active-theme\"; " +
            "  for f in \"$cfg/current-wallpaper.txt\" \"$HOME/.cache/current_wallpaper\"; do " +
            "    if [ -f \"$f\" ]; then c=$(head -n1 \"$f\"); [ -f \"$c\" ] && wp=\"$c\" && break; fi; " +
            "  done; " +
            "fi; " +
            "printf '%s\\n%s' \"$av\" \"$wp\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(this.text || "").split("\n");
                const av = (lines[0] || "").trim();
                const wp = (lines[1] || "").trim();
                if (av.indexOf("file://") === 0) root.avatarSource = av;
                if (wp.indexOf("/") === 0) root.wallpaperPath = wp;
            }
        }
    }

    function uptimeText() {
        if (typeof Sys === "undefined" || !(Sys.uptime > 0)) return "—";
        if (uptimeDays > 0) return uptimeDays + "d " + uptimeHours + "h";
        if (uptimeHours > 0) return uptimeHours + "h " + uptimeMinutes + "m";
        return Math.max(1, uptimeMinutes) + "m";
    }

    function openSettingsPanel() {
        if (root.notchRoot && typeof root.notchRoot.openSettings === "function")
            root.notchRoot.openSettings();
        else if (typeof GlobalStates !== "undefined" && typeof GlobalStates.openSettings === "function")
            GlobalStates.openSettings();
    }

    readonly property var quip: {
        const rep = (typeof WeatherSource !== "undefined") ? WeatherSource.report : null;
        const desc = rep ? String(WeatherSource.descFor(rep.code) || "").toLowerCase() : "";
        if (desc.indexOf("rain") !== -1 || desc.indexOf("drizzle") !== -1)
            return { text: "• raining, grab a coffee", icon: "coffee" };
        if (desc.indexOf("clear") !== -1)
            return { text: "• good day to touch grass", icon: "eco" };
        if (desc.indexOf("cloud") !== -1 || desc.indexOf("overcast") !== -1)
            return { text: "• a bit cloudy today", icon: "cloud" };
        if (desc.indexOf("snow") !== -1)
            return { text: "• snowing outside", icon: "ac_unit" };
        return { text: "• " + (rep ? WeatherSource.descFor(rep.code) : "ready for the day"), icon: "thermostat" };
    }

    readonly property color containerBg: Theme.m3.primary_container ?? Theme.colors.card_bg
    readonly property color onContainer: Theme.m3.on_primary_container ?? Theme.colors.text_primary
    readonly property color layer1Bg: Theme.m3.surface_container ?? Theme.colors.card_bg
    readonly property color accent: Theme.m3.primary ?? Theme.accent

    HoverHandler { id: cardHover }

    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(28)
        color: root.sizeMode === "1x1" ? root.containerBg : root.layer1Bg

        layer.enabled: root.showShadow && root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * 2 * WidgetStore.qtScale))
        )
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.44)
            shadowBlur: 0.72
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
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

    // 1x1: rounded full avatar
    Component {
        id: oneByOneComp
        Item {
            anchors.fill: parent
            Rectangle { anchors.fill: parent; radius: WidgetStore.s(28); color: root.containerBg }
            Image {
                id: av1; anchors.fill: parent; source: root.effectiveAvatar; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(256, 256); visible: false
            }
            Rectangle { id: av1Mask; anchors.fill: parent; radius: WidgetStore.s(28); visible: false; layer.enabled: av1.status === Image.Ready; layer.smooth: true }
            OpacityMask { anchors.fill: parent; source: av1; maskSource: av1Mask; visible: av1.status === Image.Ready }
            Text {
                anchors.centerIn: parent; visible: av1.status !== Image.Ready
                text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "U"
                color: root.accent
                font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(46); font.weight: Font.Bold
                font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
            }
        }
    }

    // 1x2: avatar left + greeting
    Component {
        id: oneByTwoComp
        Item {
            anchors.fill: parent
            Rectangle { anchors.fill: parent; radius: WidgetStore.s(28); color: root.containerBg }
            RowLayout {
                anchors { fill: parent; margins: WidgetStore.s(12) }
                spacing: WidgetStore.s(12)

                Rectangle {
                    Layout.preferredWidth: parent.height
                    Layout.preferredHeight: parent.height
                    radius: WidgetStore.s(20)
                    color: root.accent

                    Image { id: av2; anchors.fill: parent; source: root.effectiveAvatar; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(220, 220); visible: false }
                    Rectangle { id: av2Mask; anchors.fill: parent; radius: WidgetStore.s(20); visible: false; layer.enabled: av2.status === Image.Ready; layer.smooth: true }
                    OpacityMask { anchors.fill: parent; source: av2; maskSource: av2Mask; visible: av2.status === Image.Ready }
                    Text {
                        anchors.centerIn: parent; visible: av2.status !== Image.Ready
                        text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "U"
                        color: Theme.m3.on_primary ?? "#101014"
                        font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(38); font.weight: Font.Bold
                        font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: WidgetStore.s(3)

                    Text {
                        Layout.fillWidth: true
                        text: "Hi, " + root.userName + "!"
                        color: root.onContainer
                        font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(15); font.weight: Font.Bold
                        font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.greetingText
                        color: root.onContainer; opacity: 0.82
                        font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12)
                        font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.showUptime ? ("Up • " + root.uptimeText()) : root.todayString
                        color: root.onContainer; opacity: 0.65
                        font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(11)
                        font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // 2x2 (default)
    Component {
        id: twoByTwoComp
        Item {
            id: cardBody
            anchors.fill: parent

            Image {
                id: rawBg
                anchors.fill: parent
                source: root.effectiveWallpaper !== "" ? ("file://" + root.effectiveWallpaper) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(360, 360)
                visible: false
            }

            FastBlur {
                anchors.fill: parent
                source: rawBg
                radius: 42
                visible: rawBg.status === Image.Ready
                layer.enabled: visible && width > 1 && height > 1
                layer.smooth: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: cardBody.width; height: cardBody.height; radius: WidgetStore.s(28) }
                }
            }

            Rectangle { anchors.fill: parent; radius: WidgetStore.s(28); color: Qt.rgba(0, 0, 0, 0.30) }

            Rectangle {
                id: contentBox
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: WidgetStore.s(16) }
                height: contentColumn.implicitHeight + WidgetStore.s(54)
                radius: WidgetStore.s(18)
                color: root.containerBg

                ColumnLayout {
                    id: contentColumn
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: WidgetStore.s(14) }
                    spacing: WidgetStore.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: WidgetStore.s(6)
                        visible: root.showQuip
                        MaterialSymbol { Layout.alignment: Qt.AlignVCenter; iconSize: WidgetStore.si(15); text: root.quip.icon; color: root.onContainer; opacity: 0.85 }
                        Text {
                            Layout.fillWidth: true; text: root.quip.text; color: root.onContainer; opacity: 0.88
                            font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12); font.weight: Font.Medium
                            font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                            wrapMode: Text.WordWrap; maximumLineCount: 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.showActions
                        spacing: WidgetStore.s(8)

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: WidgetStore.s(38)
                            radius: height / 2
                            color: root.onContainer
                            Row {
                                anchors.centerIn: parent; spacing: WidgetStore.s(5)
                                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "lock"; iconSize: WidgetStore.si(16); color: root.containerBg }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter; text: "Lock"; color: root.containerBg
                                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12); font.weight: Font.DemiBold
                                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; enabled: root.interactive; cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["sh", "-c", "loginctl lock-session"])
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: WidgetStore.s(38); Layout.preferredHeight: WidgetStore.s(38); radius: width / 2
                            color: setMouse.containsMouse ? Qt.alpha(root.onContainer, 0.14) : "transparent"
                            border.width: WidgetStore.s(1); border.color: root.onContainer
                            MaterialSymbol { anchors.centerIn: parent; text: "settings"; iconSize: WidgetStore.si(16); color: root.onContainer }
                            MouseArea { id: setMouse; anchors.fill: parent; enabled: root.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSettingsPanel() }
                        }

                        Rectangle {
                            Layout.preferredWidth: WidgetStore.s(38); Layout.preferredHeight: WidgetStore.s(38); radius: width / 2
                            color: pwrMouse.containsMouse ? Qt.alpha(root.onContainer, 0.14) : "transparent"
                            border.width: WidgetStore.s(1); border.color: root.onContainer
                            MaterialSymbol { anchors.centerIn: parent; text: "power_settings_new"; iconSize: WidgetStore.si(16); color: root.onContainer }
                            MouseArea {
                                id: pwrMouse; anchors.fill: parent; enabled: root.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (typeof GlobalStates !== "undefined") GlobalStates.sessionOpen = true; }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: avatarFrame
                x: contentBox.x + WidgetStore.s(14)
                y: contentBox.y - WidgetStore.s(36)
                width: WidgetStore.s(72); height: WidgetStore.s(72); radius: width / 2
                color: root.accent; border.width: WidgetStore.s(3); border.color: root.layer1Bg; z: 2

                Image { id: av3; anchors.fill: parent; anchors.margins: WidgetStore.s(3); source: root.effectiveAvatar; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(160, 160); visible: false }
                Rectangle { id: av3Mask; anchors.fill: av3; radius: width / 2; visible: false; layer.enabled: av3.status === Image.Ready; layer.smooth: true }
                OpacityMask { anchors.fill: av3; source: av3; maskSource: av3Mask; visible: av3.status === Image.Ready }
                Text {
                    anchors.centerIn: parent; visible: av3.status !== Image.Ready
                    text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "U"
                    color: Theme.m3.on_primary ?? "#101014"
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(28); font.weight: Font.Bold
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                }
            }

            ColumnLayout {
                anchors { left: avatarFrame.right; right: parent.right; verticalCenter: avatarFrame.verticalCenter; leftMargin: WidgetStore.s(12); rightMargin: WidgetStore.s(16) }
                spacing: WidgetStore.s(1); z: 2
                Text {
                    Layout.fillWidth: true; text: root.userDisplay; color: "#ffffff"
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(13); font.weight: Font.DemiBold
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true; visible: root.showUptime; text: "Up • " + root.uptimeText(); color: "#ffffff"; opacity: 0.78
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(11)
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }
            }
        }
    }

    // 2x3: hero wallpaper fade + uptime breakdown + buttons
    Component {
        id: twoByThreeComp
        Item {
            id: card23
            anchors.fill: parent

            Rectangle { anchors.fill: parent; radius: WidgetStore.s(28); color: root.containerBg }

            Item {
                id: heroWrap
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: parent.height * 0.58

                Image {
                    anchors.fill: parent
                    source: root.effectiveWallpaper !== "" ? ("file://" + root.effectiveWallpaper) : ""
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                    sourceSize: Qt.size(540, 260)
                    visible: false
                    id: heroImg
                }
                OpacityMask {
                    anchors.fill: parent
                    source: heroImg
                    visible: heroImg.status === Image.Ready
                    maskSource: Rectangle {
                        width: heroWrap.width; height: heroWrap.height
                        topLeftRadius: WidgetStore.s(28); topRightRadius: WidgetStore.s(28)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ffffff" }
                            GradientStop { position: 0.58; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }
            }

            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: WidgetStore.s(14) }
                width: WidgetStore.s(34); height: WidgetStore.s(34); radius: width / 2
                color: Qt.alpha(root.layer1Bg, 0.85); z: 3
                MaterialSymbol { anchors.centerIn: parent; text: "settings"; iconSize: WidgetStore.si(17); color: root.onContainer }
                MouseArea { anchors.fill: parent; enabled: root.interactive; cursorShape: Qt.PointingHandCursor; onClicked: root.openSettingsPanel() }
            }

            Rectangle {
                id: av23Frame
                x: WidgetStore.s(18)
                y: heroWrap.height - WidgetStore.s(54)
                width: WidgetStore.s(76); height: WidgetStore.s(76); radius: width / 2
                color: root.accent; border.width: WidgetStore.s(3); border.color: root.containerBg; z: 2

                Image { id: av23; anchors.fill: parent; anchors.margins: WidgetStore.s(3); source: root.effectiveAvatar; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(160, 160); visible: false }
                Rectangle { id: av23Mask; anchors.fill: av23; radius: width / 2; visible: false; layer.enabled: av23.status === Image.Ready; layer.smooth: true }
                OpacityMask { anchors.fill: av23; source: av23; maskSource: av23Mask; visible: av23.status === Image.Ready }
                Text {
                    anchors.centerIn: parent; visible: av23.status !== Image.Ready
                    text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "U"
                    color: Theme.m3.on_primary ?? "#101014"
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(30); font.weight: Font.Bold
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                }
            }

            ColumnLayout {
                anchors { left: parent.left; right: parent.right; top: av23Frame.bottom; bottom: parent.bottom; margins: WidgetStore.s(16); topMargin: WidgetStore.s(8) }
                spacing: WidgetStore.s(6)

                Text {
                    Layout.fillWidth: true; text: root.userDisplay; color: root.onContainer
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(16); font.weight: Font.Bold
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: WidgetStore.s(14)

                    Repeater {
                        model: root.showUptime ? [
                            { val: root.uptimeDays, unit: "days" },
                            { val: root.uptimeHours, unit: "hrs" },
                            { val: root.uptimeMinutes, unit: "mins" }
                        ] : []
                        Column {
                            required property var modelData
                            spacing: 0
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String(modelData.val); color: root.onContainer
                                font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(15); font.weight: Font.Bold
                                font.features: { "tnum": 1 }; font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.unit; color: root.onContainer; opacity: 0.65
                                font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(10)
                                font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(96); Layout.preferredHeight: WidgetStore.s(38); radius: height / 2
                        color: root.onContainer
                        Row {
                            anchors.centerIn: parent; spacing: WidgetStore.s(5)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "lock"; iconSize: WidgetStore.si(15); color: root.containerBg }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Lock"; color: root.containerBg; font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12); font.weight: Font.DemiBold; renderType: Text.NativeRendering }
                        }
                        MouseArea { anchors.fill: parent; enabled: root.interactive; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["sh", "-c", "loginctl lock-session"]) }
                    }

                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(38); Layout.preferredHeight: WidgetStore.s(38); radius: width / 2
                        color: "transparent"; border.width: WidgetStore.s(1); border.color: root.onContainer
                        MaterialSymbol { anchors.centerIn: parent; text: "power_settings_new"; iconSize: WidgetStore.si(16); color: root.onContainer }
                        MouseArea { anchors.fill: parent; enabled: root.interactive; cursorShape: Qt.PointingHandCursor; onClicked: { if (typeof GlobalStates !== "undefined") GlobalStates.sessionOpen = true; } }
                    }
                }
            }
        }
    }

    End4ResizeHandle {
        id: resizeHandle
        tileId: root.tileId
        hoverActive: cardHover.hovered
        enabledHandle: root.onDesktop && root.interactive
        currentMode: root.sizeMode
        snapModes: ["1x1", "1x2", "2x2", "2x3"]
        strokeColor: root.sizeMode === "2x2" ? "#ffffff" : root.onContainer
    }
}
