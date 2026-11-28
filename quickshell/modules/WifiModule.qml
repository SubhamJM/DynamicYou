import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../"
import "lucidwifi" as Lucid

FocusScope {
    id: wifi

    property string activeTab: "wifi"
    readonly property bool resizingRows: panel.resizingRows > 0
    readonly property real pageContentHeight: wifi.activeTab === "hotspot"
        ? (hotspotPage.item ? hotspotPage.item.implicitHeight : 320)
        : panel.implicitHeight
    readonly property int calculatedHeight: Math.min(680, Math.max(220,
        header.height + 8 + tabs.height + 8 + pageContentHeight + 36))

    function refreshStatus() {
        scroller.contentY = 0;
        panel.refreshActiveNetwork();
    }

    function navigate(method, args = []) {
        if (typeof root !== "undefined") {
            if (method === "collapse" && typeof root.collapseToIdle === "function") {
                root.collapseToIdle();
                return;
            }
            if (method === "switchMode" && typeof root.switchMode === "function" && args.length > 0) {
                root.switchMode(String(args[0]), false);
                return;
            }
        }
        Quickshell.execDetached(["quickshell", "ipc", "--id", Quickshell.instanceId, "call", "notch", method].concat(args));
    }

    focus: true
    Keys.onEscapePressed: (event) => {
        if (wifi.activeTab === "hotspot")
            wifi.activeTab = "wifi";
        else if (panel.expandedKey !== "")
            panel.expandedKey = "";
        else if (panel.hiddenFormOpen)
            panel.hiddenFormOpen = false;
        else
            wifi.navigate("collapse");
        event.accepted = true;
    }

    ConnectivityHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: implicitHeight
        title: Lucid.I18n.tr("Internet")
        status: !Networking.wifiHardwareEnabled ? Lucid.I18n.tr("Wi-Fi hardware disabled")
            : !Networking.wifiEnabled ? Lucid.I18n.tr("Wi-Fi off") : panel.statusText
        powered: Networking.wifiEnabled
        powerAvailable: Networking.wifiHardwareEnabled
        onBackRequested: wifi.navigate("switchMode", ["utility"])
        onPowerRequested: enabled => Networking.wifiEnabled = enabled
    }

    RowLayout {
        id: tabs
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        spacing: 6

        Repeater {
            model: [
                { tab: "wifi", title: Lucid.I18n.tr("Wi-Fi"), icon: "wifi" },
                { tab: "hotspot", title: "Hotspot", icon: "wifi_tethering" }
            ]
            delegate: Button {
                id: tab
                required property var modelData
                readonly property bool selected: wifi.activeTab === modelData.tab
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 32
                text: modelData.title
                padding: 0
                hoverEnabled: true
                Accessible.role: Accessible.PageTab
                onClicked: wifi.activeTab = modelData.tab
                background: Rectangle {
                    radius: 8
                    color: tab.selected ? Theme.primaryContainer : tab.hovered ? Theme.surfaceHighest : Theme.surfaceHigh
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.icon
                            iconSize: 15
                            color: tab.selected ? Theme.accent : Theme.subtext
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.text
                            color: tab.selected ? Theme.fgPrimaryContainer : Theme.text
                            font.family: Theme.fontFamilyBody
                            font.pixelSize: 12
                            font.weight: tab.selected ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: scroller

        anchors.top: tabs.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: wifi.activeTab === "hotspot" ? (hotspotPage.item?.implicitHeight ?? 0) : panel.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Connections {
            target: wifi
            function onActiveTabChanged() { scroller.contentY = 0; }
        }

        Lucid.WifiPanel {
            id: panel

            width: scroller.width
            height: implicitHeight
            visible: wifi.activeTab === "wifi"
            active: visible && (typeof root === "undefined" || root.activeMode === "wifi")
        }

        Loader {
            id: hotspotPage
            width: scroller.width
            active: wifi.activeTab === "hotspot"
            sourceComponent: HotspotPanel { hotspot: root.hotspot }
        }
    }
}
