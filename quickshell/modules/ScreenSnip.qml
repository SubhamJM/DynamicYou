import QtQuick
import "./matusnip" as MatusSnip

Item {
    id: root

    readonly property alias snipOpen: impl.snipOpen
    readonly property alias previewOpen: impl.previewOpen

    function open(filePath, outputName) {
        impl.open(filePath, outputName)
    }

    MatusSnip.ScreenSnip {
        id: impl
    }
}
