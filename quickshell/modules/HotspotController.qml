import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: hotspot

    property bool monitoring: false
    readonly property bool busy: pending !== null || (worker.running && action !== "status")
    property bool ready: false
    property bool active: false
    property string ssid: ""
    property string password: ""
    property var clients: null
    property bool sharingAvailable: true
    property string statusError: ""
    property string feedback: ""
    property bool operationFailed: false

    property string action: ""
    property var input: null
    property var reply: null
    property var pending: null

    onMonitoringChanged: {
        if (monitoring) refresh();
    }

    function refresh() {
        if (!worker.running && !pending) run("status", null);
    }

    function request(operation, credentials = null) {
        if (busy) return;
        feedback = "";
        operationFailed = false;
        if (worker.running) {
            pending = { action: operation, credentials };
        } else {
            run(operation, credentials);
        }
    }

    function run(operation, credentials) {
        action = operation;
        input = credentials;
        reply = null;
        let args = ["python3", Quickshell.shellPath("scripts/hotspot_manager.py"), operation];
        if (credentials !== null) args.push("--stdin");
        worker.command = args;
        worker.running = true;
    }

    property Timer poll: Timer {
        interval: 3500
        repeat: true
        running: hotspot.monitoring
        onTriggered: hotspot.refresh()
    }

    property Process worker: Process {
        stdinEnabled: true
        onStarted: {
            if (hotspot.input !== null) {
                write(JSON.stringify(hotspot.input) + "\n");
                hotspot.input = null;
            }
        }
        stdout: SplitParser {
            onRead: line => {
                try { hotspot.reply = JSON.parse(line); } catch (_) {}
            }
        }
        onExited: code => {
            const response = hotspot.reply;
            const ok = code === 0 && response?.success === true;
            if (ok) {
                hotspot.ready = true;
                hotspot.ssid = response.ssid;
                hotspot.password = response.password;
                hotspot.active = response.active;
                hotspot.clients = response.clients;
                hotspot.sharingAvailable = response.dnsmasq_installed;
                hotspot.statusError = "";
            }
            if (hotspot.action === "status") {
                if (!ok) {
                    hotspot.ready = false;
                    hotspot.statusError = response?.message || "Couldn’t read hotspot status.";
                }
            } else {
                if (!ok) {
                    hotspot.feedback = response?.message || "Couldn’t update the hotspot.";
                } else if (hotspot.action === "set-config") {
                    hotspot.feedback = hotspot.active ? "Saved. Restart the hotspot to apply these settings." : "Settings saved.";
                } else {
                    hotspot.feedback = "";
                }
                hotspot.operationFailed = !ok;
            }

            hotspot.input = null;
            hotspot.reply = null;
            if (hotspot.pending !== null) {
                Qt.callLater(() => {
                    const request = hotspot.pending;
                    hotspot.pending = null;
                    hotspot.run(request.action, request.credentials);
                });
            }
        }
    }
}
