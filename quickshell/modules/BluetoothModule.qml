import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "lucidbt" as Lucid

FocusScope {
    id: bt

    Lucid.BtAgent { id: agent }
    Lucid.BtReceive { id: receiver }

    property string activeTab: "bluetooth"
    property alias expandedKey: panel.expandedKey
    readonly property int calculatedHeight: Math.min(680, Math.max(220, header.height + scroller.anchors.topMargin + panel.implicitHeight + 28))

    function refreshStatus() {
        Lucid.Bt.refresh();
    }

    function navigate(method, args = []) {
        Quickshell.execDetached(["quickshell", "ipc", "--id", Quickshell.instanceId, "call", "notch", method].concat(args));
    }

    focus: true
    Keys.onEscapePressed: (event) => {
        if (panel.expandedKey !== "")
            panel.expandedKey = "";
        else
            bt.navigate("collapse");
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
            onClicked: bt.navigate("switchMode", ["utility"])
        }

        Lucid.LText {
            anchors.left: backChip.right
            anchors.leftMargin: Lucid.Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            role: "titleMedium"
            weight: 600
            text: Lucid.I18n.tr("Bluetooth")
        }

        Lucid.Switch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Lucid.Bt.on
            onToggled: Lucid.Bt.setEnabled(!Lucid.Bt.on)
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

        Lucid.BluetoothPanel {
            id: panel

            width: scroller.width
            height: implicitHeight
            active: bt.visible && bt.enabled
            onCloseRequested: bt.navigate("collapse")
        }
    }
}
