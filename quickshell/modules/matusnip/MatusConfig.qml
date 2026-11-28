pragma Singleton

import QtQuick

QtObject {
    id: root

    property QtObject appearance: QtObject {
        property int fontScale: 5
        property int paddingScale: 5
        property int spacingScale: 5
        property int radiusScale: 5
        property real baseTransparency: 1.0
        property real layerTransparency: 1.0
        property bool bezelMode: false
        property string notifPosition: "top-right"
    }

    property QtObject animation: QtObject {
        property bool overshootEnabled: true
        property int overshootStrength: 100
        property int speedScale: 100
    }

    property QtObject wallpaper: QtObject {
        property string colorScheme: "dark"
    }

    property QtObject dock: QtObject {
        property string mode: "float"
        property int iconSize: 40
        property int iconSpacing: 8
        property string style: "material"
    }

    property QtObject bar: QtObject {
        property string position: "top"
        property string mode: "float"
        property string floatStyle: "connected"
        property int floatEdgeMargin: 6
        property int connectedFrameThickness: 4
        property string islandStyle: "notch"
        property int height: 44
        property int pillHeight: 32
        property string groupColor: "surfaceContainer"
        property QtObject island: QtObject {
            property bool enabled: true
            property int height: 34
            property int edgeMargin: 6
        }
    }
}
