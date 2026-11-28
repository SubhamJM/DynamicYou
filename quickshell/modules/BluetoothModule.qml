import QtQuick
import Quickshell
import "lucidbt" as Lucid

FocusScope {
    id: bt

    Lucid.BtAgent { id: agent }
    Lucid.BtReceive { id: receiver }

    property string activeTab: "bluetooth"
    property alias expandedKey: panel.expandedKey
    readonly property bool resizingRows: panel.resizingRows > 0
    readonly property int calculatedHeight: Math.min(680, Math.max(220,
        header.height + scroller.anchors.topMargin + panel.implicitHeight + 36))

    function refreshStatus() {
        scroller.contentY = 0;
        Lucid.Bt.refresh();
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
        if (panel.expandedKey !== "")
            panel.expandedKey = "";
        else
            bt.navigate("collapse");
        event.accepted = true;
    }

    ConnectivityHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: implicitHeight
        title: Lucid.I18n.tr("Bluetooth")
        status: panel.label
        powered: Lucid.Bt.on
        powerAvailable: Lucid.Bt.present && !Lucid.Bt.hardBlocked && !Lucid.Bt.powerPending
        onBackRequested: bt.navigate("switchMode", ["utility"])
        onPowerRequested: enabled => Lucid.Bt.setEnabled(enabled)
    }

    Flickable {
        id: scroller

        anchors.top: header.bottom
        anchors.topMargin: 8
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
            active: typeof root === "undefined" || root.activeMode === "bluetooth"
            onCloseRequested: bt.navigate("collapse")
        }
    }
}
