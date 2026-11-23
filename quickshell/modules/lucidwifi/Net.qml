pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("modules/lucidwifi/wifi_share.py")
    // a saved network's password and QR code, read only while a Share view
    // is open for it and dropped when that view goes away
    property var shared: ({})
    property string sharedSsid: ""
    readonly property bool shareLoading: shareProc.running

    function loadShare(ssid) {
        root.sharedSsid = ssid;
        root.shared = ({});
        shareProc.running = false;
        shareProc.command = ["python3", root.helper, ssid];
        shareProc.running = true;
    }

    function clearShare(ssid) {
        if (root.sharedSsid !== ssid)
            return ;

        shareProc.running = false;
        root.sharedSsid = "";
        root.shared = ({});
    }

    // through stdin, so the password never shows on a command line, and
    // marked sensitive, so clipboard history leaves it out
    function copyShared() {
        if (!root.shared.psk)
            return ;

        copyProc.running = false;
        copyProc.stdinEnabled = true;
        copyProc.running = true;
        copyProc.write(root.shared.psk);
        copyProc.stdinEnabled = false;
    }

    Process {
        id: shareProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text.trim() || "{}");
                    if (d.ssid === root.sharedSsid)
                        root.shared = d;

                } catch (e) {
                    root.shared = ({
                        "ssid": root.sharedSsid,
                        "found": false
                    });
                }
            }
        }

    }

    Process {
        id: copyProc

        command: ["wl-copy", "--sensitive"]
    }

}
