import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Button {
    id: root
    property var imageData
    property var fallbackTags: []
    property real rowHeight: 180
    property bool aspectCrop: false
    property bool lazyTagFetch: false
    property bool manualDownload: false
    property string previewDownloadPath: ""
    property string downloadPath: ""
    property string nsfwPath: ""
    property real imageRadius: Appearance.rounding.small
    property bool showBackground: true
    property bool enableTooltip: true
    property int maxTagStringLineLength: 50

    readonly property real imageAspect: Math.max(0.3, Number(imageData?.aspect_ratio ?? 1))
    readonly property string tagText: String(imageData?.tags || fallbackTags?.join(" ") || "")

    hoverEnabled: true
    implicitWidth: rowHeight * imageAspect
    implicitHeight: rowHeight
    onClicked: Wallhaven.activePreview = imageData
    onHoveredChanged: {
        if (hovered && lazyTagFetch && imageData?.id && !imageData?.tags)
            tagFetchTimer.restart()
        else
            tagFetchTimer.stop()
    }

    Timer {
        id: tagFetchTimer
        interval: 450
        onTriggered: {
            if (root.hovered && root.imageData?.id)
                Wallhaven.ensureWallpaperTags(root.imageData.id)
        }
    }

    StyledToolTip {
        delay: 750
        extraVisibleCondition: root.enableTooltip && root.tagText.length > 0
        alternativeVisibleCondition: root.hovered
        text: StringUtils.wordWrap(root.tagText, root.maxTagStringLineLength)
    }

    background: Rectangle {
        radius: root.imageRadius
        color: root.showBackground ? Appearance.colors.colLayer2 : "transparent"
    }

    contentItem: Item {
        StyledImage {
            anchors.fill: parent
            fillMode: root.aspectCrop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            source: root.imageData?.preview_url ?? ""
            sourceSize.width: root.implicitWidth
            sourceSize.height: root.implicitHeight

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: root.width
                    height: root.height
                    radius: root.imageRadius
                }
            }
        }
    }
}
