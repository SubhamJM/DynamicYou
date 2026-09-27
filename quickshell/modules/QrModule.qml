import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: qrModule
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    function forceQrFocus() {
        qrModule.forceActiveFocus();
    }

    property string qrText: root.qrContentText || ""
    property int reloadCounter: 0
    property bool copiedFeedback: false

    readonly property bool isUrl: {
        var t = qrText.trim();
        return t.startsWith("http://") || t.startsWith("https://") || t.startsWith("ftp://");
    }

    Timer {
        id: copiedTimer
        interval: 1400
        repeat: false
        onTriggered: qrModule.copiedFeedback = false
    }

    function regenerateFromClipboard() {
        Quickshell.execDetached(["bash", Qt.resolvedUrl("../scripts/qr_utils.sh").toString().replace(/^file:\/\//, ""), "encode"]);
    }

    function copyText() {
        if (!qrText) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(qrText) + " | wl-copy"]);
        qrModule.copiedFeedback = true;
        copiedTimer.restart();
    }

    function openUrl() {
        if (!isUrl) return;
        Quickshell.execDetached(["xdg-open", qrText.trim()]);
        root.collapseToIdle();
    }

    Connections {
        target: root
        function onQrContentTextChanged() {
            qrModule.qrText = root.qrContentText;
            qrModule.reloadCounter++;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ==========================================
        // 1. HEADER ROW: ICON, TITLE, BADGE, CLOSE
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: Qt.alpha(Theme.accent, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "qr_code_2"
                    iconSize: 18
                    color: Theme.accent
                }
            }

            Text {
                text: "QR Code"
                color: Theme.colors.text_primary ?? "#ffffff"
                font.family: "Readex Pro"
                font.pixelSize: 15
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }

            Rectangle {
                height: 20
                width: charCountText.implicitWidth + 12
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                Text {
                    id: charCountText
                    anchors.centerIn: parent
                    text: (qrModule.qrText.length) + " chars"
                    color: Theme.colors.text_muted ?? "#8e8e93"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }

            Item { Layout.fillWidth: true }

            // Close button
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                scale: closeMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 15
                    color: Theme.colors.text_secondary ?? "#8e8e93"
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.collapseToIdle()
                }
            }
        }

        // ==========================================
        // 2. TEXT SNIPPET PREVIEW
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                MaterialSymbol {
                    text: qrModule.isUrl ? "link" : "subject"
                    iconSize: 16
                    color: qrModule.isUrl ? Theme.accent : (Theme.colors.text_muted ?? "#8e8e93")
                }

                Text {
                    Layout.fillWidth: true
                    text: qrModule.qrText !== "" ? qrModule.qrText : "No content encoded"
                    color: qrModule.isUrl ? Theme.accent : (Theme.colors.text_secondary ?? "#c0caf5")
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    elide: Text.ElideMiddle
                    renderType: Text.NativeRendering
                }
            }
        }

        // ==========================================
        // 3. QR CODE DISPLAY (High contrast white card)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 200

            Rectangle {
                anchors.centerIn: parent
                width: 196
                height: 196
                radius: 16
                color: "#ffffff"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.1)

                Image {
                    id: qrImg
                    anchors.centerIn: parent
                    width: 180
                    height: 180
                    fillMode: Image.PreserveAspectFit
                    smooth: false // crisp pixel rendering for mobile camera scanners
                    cache: false
                    asynchronous: false
                    source: "file:///tmp/quickshell_qr.png?r=" + qrModule.reloadCounter
                }
            }
        }

        // ==========================================
        // 4. ACTION BUTTONS ROW
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Refresh from clipboard
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 10
                color: refMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                scale: refMouse.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "refresh"
                        iconSize: 16
                        color: Theme.colors.text_primary ?? "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Clipboard"
                        color: Theme.colors.text_primary ?? "#ffffff"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: refMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: qrModule.regenerateFromClipboard()
                }
            }

            // Copy text
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 10
                color: qrModule.copiedFeedback ? Qt.rgba(0.18, 0.82, 0.34, 0.2) : (copyMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                scale: copyMouse.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: qrModule.copiedFeedback ? "check" : "content_copy"
                        iconSize: 16
                        color: qrModule.copiedFeedback ? "#30d158" : (Theme.colors.text_primary ?? "#ffffff")
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: qrModule.copiedFeedback ? "Copied!" : "Copy"
                        color: qrModule.copiedFeedback ? "#30d158" : (Theme.colors.text_primary ?? "#ffffff")
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: qrModule.copyText()
                }
            }

            // Open Link (if URL)
            Rectangle {
                visible: qrModule.isUrl
                Layout.fillWidth: true
                height: 34
                radius: 10
                color: openMouse.containsMouse ? Qt.alpha(Theme.accent, 0.28) : Qt.alpha(Theme.accent, 0.18)
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.4)
                scale: openMouse.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "open_in_new"
                        iconSize: 16
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Open"
                        color: Theme.accent
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: qrModule.openUrl()
                }
            }
        }
    }
}
