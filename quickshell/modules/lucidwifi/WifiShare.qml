import QtQuick
import "." as WifiUi

// a saved Wi-Fi network as a QR code a phone camera can join from, with the
// password beside it. the password is read when this appears and dropped
// when it goes, and it stays dotted until asked for
Item {
    id: share

    required property string ssid
    // stacks the code over the password, for the narrow bar panel
    property bool compact: false
    property int qrSize: share.compact ? WifiUi.Theme.dp(124) : WifiUi.Theme.dp(156)
    property bool revealed: false
    property bool copied: false

    readonly property var info: WifiUi.Net.sharedSsid === share.ssid ? WifiUi.Net.shared : ({})
    readonly property bool loading: WifiUi.Net.sharedSsid === share.ssid && WifiUi.Net.shareLoading
    readonly property var rows: share.info.qr || []
    readonly property bool open: share.info.security === "nopass"
    readonly property string problem: {
        if (share.loading || share.info.found === undefined)
            return "";

        if (!share.info.found)
            return WifiUi.I18n.tr("There is no saved profile for this network, so there is nothing to share.");

        if (share.info.security === "enterprise")
            return WifiUi.I18n.tr("This network signs in with an account, not a password a phone could scan.");

        if (!share.open && !share.info.psk)
            return share.info.agentOwned ? WifiUi.I18n.tr("The password is kept in your keyring, not by NetworkManager, so it can't be read from here.") : WifiUi.I18n.tr("No password is saved for this network.");

        return "";
    }
    readonly property bool ready: share.problem === "" && share.info.found === true
    readonly property color paper: "#ffffff"
    readonly property color ink: "#000000"

    implicitHeight: grid.implicitHeight
    Component.onCompleted: WifiUi.Net.loadShare(share.ssid)
    Component.onDestruction: WifiUi.Net.clearShare(share.ssid)
    onSsidChanged: {
        share.revealed = false;
        WifiUi.Net.loadShare(share.ssid);
    }

    Timer {
        id: copiedTimer

        interval: 1600
        onTriggered: share.copied = false
    }

    component QrTile: Rectangle {
        width: share.qrSize
        height: share.qrSize
        radius: WifiUi.Theme.rad(14)
        color: share.paper
        border.width: 1
        border.color: WifiUi.Theme.alpha(WifiUi.Theme.outlineStrong, 0.4)

        Canvas {
            id: qr

            // a quiet zone of about three modules keeps phones locking on
            anchors.fill: parent
            anchors.margins: Math.round(share.qrSize * 0.08)
            visible: share.rows.length > 0
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const rows = share.rows;
                const n = rows.length;
                if (n === 0)
                    return ;

                // whole pixels per module, or the edges blur and scanners slip
                const m = Math.max(1, Math.floor(Math.min(width, height) / n));
                const ox = Math.floor((width - m * n) / 2);
                const oy = Math.floor((height - m * n) / 2);
                ctx.fillStyle = share.ink;
                for (let y = 0; y < n; y++) {
                    const row = rows[y];
                    for (let x = 0; x < row.length; x++) {
                        if (row.charAt(x) === "1")
                            ctx.fillRect(ox + x * m, oy + y * m, m, m);

                    }
                }
            }

            Connections {
                function onRowsChanged() {
                    qr.requestPaint();
                }

                function onInkChanged() {
                    qr.requestPaint();
                }

                target: share
            }

        }

        Text {
            anchors.centerIn: parent
            width: parent.width - WifiUi.Theme.dp(28)
            visible: share.rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: share.loading ? WifiUi.I18n.tr("Reading…") : (share.ready ? WifiUi.I18n.tr("Install qrencode to show a code.") : WifiUi.I18n.tr("No code"))
            color: WifiUi.Theme.alpha(share.ink, 0.6)
            font.family: WifiUi.Theme.fontFamily
            font.pixelSize: WifiUi.Theme.fontLabel
        }

    }

    component Details: Column {
        spacing: WifiUi.Theme.dp(10)

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: share.compact ? Text.AlignHCenter : Text.AlignLeft
            text: share.problem !== "" ? share.problem : (share.open ? WifiUi.I18n.tr("Point a phone's camera at the code to join %1. It's an open network, so there is no password.", share.ssid) : WifiUi.I18n.tr("Point a phone's camera at the code to join %1, or type the password in.", share.ssid))
            color: share.problem !== "" ? WifiUi.Theme.error : WifiUi.Theme.subtext
            font.family: WifiUi.Theme.fontFamily
            font.pixelSize: WifiUi.Theme.fs(11)
            lineHeight: 1.2
        }

        Rectangle {
            width: parent.width
            height: WifiUi.Theme.dp(36)
            radius: WifiUi.Theme.rad(10)
            visible: share.ready && !share.open
            color: WifiUi.Theme.alpha(WifiUi.Theme.text, 0.06)
            border.width: 1
            border.color: WifiUi.Theme.outlineStrong

            Text {
                anchors.left: parent.left
                anchors.leftMargin: WifiUi.Theme.dp(12)
                anchors.right: eye.left
                anchors.rightMargin: WifiUi.Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                // a fixed row of dots, so hidden it doesn't give the length away
                text: share.revealed ? (share.info.psk || "") : "••••••••••"
                color: WifiUi.Theme.text
                font.family: WifiUi.Theme.fontFamily
                font.pixelSize: WifiUi.Theme.fs(13)
                font.letterSpacing: share.revealed ? 0.5 : 2
                elide: Text.ElideRight
            }

            M3IconButton {
                id: eye

                anchors.right: parent.right
                anchors.rightMargin: WifiUi.Theme.dp(4)
                anchors.verticalCenter: parent.verticalCenter
                size: WifiUi.Theme.dp(28)
                // eye / eye-off, Material Design Icons
                iconPath: share.revealed ? "visibility_off" : "visibility"
                onClicked: share.revealed = !share.revealed
            }

        }

        M3Button {
            visible: share.ready && !share.open
            width: parent.width
            height: WifiUi.Theme.dp(36)
            variant: "tonal"
            text: share.copied ? WifiUi.I18n.tr("Copied") : WifiUi.I18n.tr("Copy password")
            onClicked: {
                WifiUi.Net.copyShared();
                share.copied = true;
                copiedTimer.restart();
            }
        }

    }

    Grid {
        id: grid

        width: parent.width
        topPadding: WifiUi.Theme.dp(6)
        bottomPadding: WifiUi.Theme.dp(6)
        columns: share.compact ? 1 : 2
        columnSpacing: WifiUi.Theme.dp(20)
        rowSpacing: WifiUi.Theme.dp(12)
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: share.compact ? Grid.AlignHCenter : Grid.AlignLeft

        QrTile {
        }

        Details {
            width: share.compact ? grid.width : grid.width - share.qrSize - grid.columnSpacing
        }

    }

}
