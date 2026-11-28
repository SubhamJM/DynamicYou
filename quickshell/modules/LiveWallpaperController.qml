import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string home: Quickshell.env("HOME")
    property string selectedPath: ""
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov|m4v)$/i.test(selectedPath)

    FileView {
        path: root.home + "/.config/active-theme/current-wallpaper.txt"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.selectedPath = text().trim()
        onLoadFailed: root.selectedPath = ""
    }

    Process {
        id: livePlayer
        command: ["qs", "-p", root.home + "/.config/quickshell/modules/livewall/LiveShell.qml"]
        environment: ({
            QT_FFMPEG_DECODING_HW_DEVICE_TYPES: "vaapi,cuda",
            QT_FFMPEG_ENCODING_HW_DEVICE_TYPES: "",
            QS_NO_RELOAD_POPUP: "1"
        })
        running: root.isVideo
    }
}
