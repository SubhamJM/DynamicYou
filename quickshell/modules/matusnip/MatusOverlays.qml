pragma Singleton

import QtQuick

Item {
    id: root

    signal snipRequested()
    signal toolSwitched(int index)

    property var barContent: null
    property string activeTool: "snip"

    function requestToolSwitch(index) {
        root.toolSwitched(index)
    }
}
