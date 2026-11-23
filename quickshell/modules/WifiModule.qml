import QtQuick
import Quickshell
import Quickshell.Networking
import "lucidwifi" as Lucid

FocusScope {
    id: wifi

    property string activeTab: "wifi"
    readonly property int calculatedHeight: Math.min(680, Math.max(220, header.height + scroller.anchors.topMargin + panel.implicitHeight + 28))

    function refreshStatus() {
        panel.refreshActiveNetwork();
    }

    function navigate(method, args = []) {
        Quickshell.execDetached(["quickshell", "ipc", "--id", Quickshell.instanceId, "call", "notch", method].concat(args));
    }

    focus: true
    Keys.onEscapePressed: (event) => {
        if (panel.expandedKey !== "")
            panel.expandedKey = "";
        else if (panel.hiddenFormOpen)
            panel.hiddenFormOpen = false;
        else
            wifi.navigate("collapse");
        event.accepted = true;
    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Lucid.Theme.dp(44)

        Lucid.IconButton {
            id: backChip

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "arrow_back"
            tintOverride: Lucid.Theme.text
            onClicked: wifi.navigate("switchMode", ["utility"])
        }

        Lucid.LText {
            anchors.left: backChip.right
            anchors.leftMargin: Lucid.Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            role: "titleMedium"
            weight: 600
            text: Lucid.I18n.tr("Internet")
        }

        Lucid.Switch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    Flickable {
        id: scroller

        anchors.top: header.bottom
        anchors.topMargin: Lucid.Theme.dp(4)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: panel.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Lucid.WifiPanel {
            id: panel

            width: scroller.width
            height: implicitHeight
            active: wifi.visible && wifi.enabled
        }
    }
}
