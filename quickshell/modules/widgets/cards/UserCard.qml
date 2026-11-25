import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../../../"
import "../../../services"
import "../../"
import "../"

Item {
    id: root

    property bool active: true
    readonly property var opts: WidgetStore.cardOptions("usercard")
    readonly property bool showHost: opts.showHost !== false
    readonly property bool showBadges: opts.showBadges !== false
    readonly property bool showBanner: opts.showBanner !== false
    readonly property string customAvatar: String(opts.customAvatar || "")

    onActiveChanged: {
        if (typeof Sys !== "undefined") Sys.hold("usercard", root.active, 5000);
    }
    Component.onCompleted: {
        if (typeof Sys !== "undefined" && root.active) Sys.hold("usercard", true, 5000);
    }
    Component.onDestruction: {
        if (typeof Sys !== "undefined") Sys.hold("usercard", false, 5000);
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
    readonly property string shellName: {
        if (typeof Sys !== "undefined" && Sys.info && Sys.info.shell)
            return String(Sys.info.shell);
        const s = String(Quickshell.env("SHELL") || "sh").split("/").pop();
        return s || "sh";
    }
    readonly property string deskName: String(Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland")
    property string avatarSource: ""

    Process {
        id: probeAvatar
        running: true
        command: [
            "sh", "-c",
            "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do " +
            "  if [ -f \"$f\" ]; then printf 'file://%s' \"$f\"; exit 0; fi; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const u = String(this.text || "").trim();
                if (u.indexOf("file://") === 0) root.avatarSource = u;
            }
        }
    }

    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"
    readonly property color secondary: Theme.m3.secondary ?? "#67e8f9"
    readonly property color onSecondary: Theme.m3.on_secondary ?? "#030a16"
    readonly property color fg: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color muted: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary

    function uptimeText() {
        if (typeof Sys === "undefined" || !(Sys.uptime > 0))
            return "—";
        const total = Math.floor(Sys.uptime);
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0) return days + "d " + hours + "h";
        if (hours > 0) return hours + "h " + minutes + "m";
        return Math.max(1, minutes) + "m";
    }

    SekaiPill {
        anchors.fill: parent
        cornerRadius: WidgetStore.s(22)
        borderWidth: WidgetStore.s(2.5)
        ringWidth: WidgetStore.s(3)
        shadowDx: WidgetStore.s(3)
        shadowDy: WidgetStore.s(4)
        fillColor: Theme.m3.surface_container ?? Theme.colors.card_bg
        ringColor: Qt.alpha(root.accent, 0.24)

        // Banner glow
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: WidgetStore.s(72)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(root.accent, 0.26) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: WidgetStore.s(10)
                rightMargin: WidgetStore.s(10)
                topMargin: WidgetStore.s(10)
                bottomMargin: WidgetStore.s(10)
            }
            spacing: WidgetStore.s(6)

            // Tilted HELLO chip
            SekaiPill {
                visible: root.showBanner
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: WidgetStore.s(66)
                Layout.preferredHeight: WidgetStore.s(22)
                cornerRadius: WidgetStore.s(8)
                borderWidth: WidgetStore.s(2)
                ringWidth: WidgetStore.s(1.5)
                shadowDy: WidgetStore.s(2)
                rotation: -3
                fillColor: root.accent

                Text {
                    anchors.centerIn: parent
                    text: "USER"
                    color: root.onAccent
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(9)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.0
                    renderType: Text.NativeRendering
                }
            }

            // Avatar circle
            SekaiPill {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: WidgetStore.s(72)
                Layout.preferredHeight: WidgetStore.s(72)
                cornerRadius: WidgetStore.s(36)
                borderWidth: WidgetStore.s(2.5)
                ringWidth: WidgetStore.s(2)
                shadowDy: WidgetStore.s(3)
                fillColor: Theme.m3.primary_container ?? Theme.colors.hover_bg
                ringColor: root.accent

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: root.customAvatar !== "" ? ("file://" + encodeURI(root.customAvatar)) : root.avatarSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(
                        Math.max(64, Math.round(width * 2 * WidgetStore.qtScale)),
                        Math.max(64, Math.round(height * 2 * WidgetStore.qtScale))
                    )
                    visible: false
                }

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: avatarImage.status === Image.Ready
                    layer.smooth: true
                    layer.textureSize: Qt.size(
                        Math.max(64, Math.round(width * 2 * WidgetStore.qtScale)),
                        Math.max(64, Math.round(height * 2 * WidgetStore.qtScale))
                    )
                }

                OpacityMask {
                    anchors.fill: parent
                    source: avatarImage
                    maskSource: avatarMask
                    visible: avatarImage.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "U"
                    color: root.accent
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(28)
                    font.weight: Font.ExtraBold
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }

            // Name & @host
            Column {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.userName
                    color: root.fg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(14)
                    font.weight: Font.ExtraBold
                    elide: Text.ElideRight
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }

                Text {
                    visible: root.showHost
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "@" + root.hostName
                    color: root.muted
                    font.family: "Noto Sans"
                    font.pixelSize: WidgetStore.si(10)
                    elide: Text.ElideRight
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }

            Item { Layout.fillHeight: true }

            // Sekai Pop bordered stat keycaps (UPTIME, SHELL, DESKTOP)
            StatKey {
                visible: root.showBadges
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(36)
                kLabel: "UPTIME"
                kValue: root.uptimeText()
                chipBg: root.accent
                chipFg: root.onAccent
            }

            StatKey {
                visible: root.showBadges
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(36)
                kLabel: "SHELL"
                kValue: root.shellName
                chipBg: Theme.m3.surface_container_high ?? Theme.colors.hover_bg
                chipFg: root.fg
            }

            StatKey {
                visible: root.showBadges
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(36)
                kLabel: "WM"
                kValue: root.deskName
                chipBg: root.secondary
                chipFg: root.onSecondary
            }
        }
    }

    component StatKey: SekaiPill {
        property string kLabel: ""
        property string kValue: ""
        property color chipBg: root.accent
        property color chipFg: root.onAccent

        cornerRadius: WidgetStore.s(10)
        borderWidth: WidgetStore.s(1.8)
        ringWidth: WidgetStore.s(1.5)
        shadowDy: WidgetStore.s(2)
        fillColor: chipBg

        Column {
            anchors.centerIn: parent
            width: parent.width - WidgetStore.s(10)
            spacing: -1

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: kLabel
                color: chipFg
                opacity: 0.78
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(8)
                font.weight: Font.ExtraBold
                font.letterSpacing: 0.7
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: kValue
                color: chipFg
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(11)
                font.weight: Font.ExtraBold
                elide: Text.ElideRight
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }
        }
    }
}
