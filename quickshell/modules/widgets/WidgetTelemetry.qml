pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import "../../"

Singleton {
    id: root

    property var activeOwners: ({})
    readonly property bool active: Object.keys(activeOwners).length > 0
    readonly property int historyLength: 60

    // Network per-interface telemetry
    property string defaultInterface: ""
    property var netInterfaces: [] // [{ name, downloadBps, uploadBps }]
    property var downloadHistories: ({})
    property var uploadHistories: ({})
    property var _prevNetBytes: ({})
    property double _prevNetAt: 0

    // Disk I/O telemetry (/proc/diskstats)
    property var disks: [] // [{ device, readBps, writeBps }]
    property var readHistories: ({})
    property var writeHistories: ({})
    property var _prevDiskSectors: ({})
    property double _prevDiskAt: 0

    // GPU telemetry (nvidia-smi / drm sysfs)
    property bool hasGpu: false
    property string gpuName: ""
    property real gpuPercent: -1
    property real gpuTemp: -1
    property real gpuVramUsedMb: -1
    property real gpuVramTotalMb: -1
    property var gpuHistory: []

    // Battery extra health & power rate
    property real batteryHealth: -1
    property real batteryRateW: NaN

    // Shared desktop wallpaper & user avatar cache (eliminates per-card sh/awww forks)
    property string wallpaperPath: ""
    property string avatarUrl: ""
    property int _pollTick: 0

    // Wi-Fi live status (Quickshell.Networking)
    readonly property var wifiDevice: {
        if (typeof Networking === "undefined" || !Networking.devices) return null;
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }
    readonly property bool wifiEnabled: (typeof Networking !== "undefined") ? Networking.wifiEnabled : false
    readonly property bool wifiConnected: !!(wifiDevice && wifiDevice.connected)
    readonly property var activeWifiNetwork: {
        if (!wifiDevice || !wifiDevice.networks) return null;
        for (const n of wifiDevice.networks.values) {
            if (n.connected) return n;
        }
        return null;
    }
    readonly property string wifiSsid: activeWifiNetwork ? String(activeWifiNetwork.name || "") : ""
    readonly property real wifiSignal: {
        if (!wifiConnected || !activeWifiNetwork || activeWifiNetwork.signalStrength === undefined)
            return -1;
        const raw = Number(activeWifiNetwork.signalStrength);
        return Math.max(0, Math.min(100, raw <= 1.0 ? raw * 100 : raw));
    }

    function hold(tag, on) {
        const key = String(tag || "default");
        const currentlyHeld = !!root.activeOwners[key];
        if (currentlyHeld === !!on) return;
        const next = Object.assign({}, root.activeOwners);
        if (on) next[key] = true;
        else delete next[key];
        root.activeOwners = next;
    }

    onActiveChanged: {
        if (typeof Sys !== "undefined") Sys.hold("widgets", root.active, 1500);
        if (root.active) {
            if (typeof WeatherSource !== "undefined") WeatherSource.ensure();
            // Defer initial nvidia-smi / proc poll slightly so sidebar open slide never drops a frame
            deferredInitialPoll.restart();
        } else {
            deferredInitialPoll.stop();
            quickPrimeTimer.stop();
        }
    }

    function pushHist(map, key, val) {
        const prev = Array.isArray(map[key]) ? map[key] : [];
        const next = prev.concat([val]);
        while (next.length > root.historyLength) next.shift();
        map[key] = next;
    }

    function pollAll() {
        root._pollTick = (root._pollTick + 1) % 2;
        if (!statProc.running) statProc.running = true;
        if ((root._pollTick === 0 || !root.hasGpu) && !gpuProc.running) gpuProc.running = true;
    }

    function refreshEnvironment() {
        if (!envProbe.running) envProbe.running = true;
    }

    Component.onCompleted: refreshEnvironment()

    Connections {
        target: typeof Theme !== "undefined" ? Theme : null
        function onThemeReloaded() { root.refreshEnvironment(); }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/active-theme/current-wallpaper.txt"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            wallChangeRefreshTimer.restart();
        }
    }

    Timer {
        id: wallChangeRefreshTimer
        interval: 150
        repeat: false
        onTriggered: root.refreshEnvironment()
    }

    Process {
        id: envProbe
        running: false
        command: [
            "sh", "-c",
            "av=''; for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do " +
            "  if [ -f \"$f\" ]; then av=\"file://$f\"; break; fi; " +
            "done; " +
            "wp=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1); " +
            "if [ -z \"$wp\" ] || [ ! -f \"$wp\" ]; then " +
            "  cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/active-theme\"; " +
            "  for f in \"$cfg/current-wallpaper.txt\" \"$HOME/.cache/current_wallpaper\"; do " +
            "    if [ -f \"$f\" ]; then c=$(head -n1 \"$f\"); [ -f \"$c\" ] && wp=\"$c\" && break; fi; " +
            "  done; " +
            "  if [ -z \"$wp\" ] && [ -e \"$cfg/current-wallpaper\" ]; then wp=$(realpath -e -- \"$cfg/current-wallpaper\" 2>/dev/null || true); fi; " +
            "fi; " +
            "printf '%s\\n%s' \"$av\" \"$wp\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(this.text || "").split("\n");
                const av = (lines[0] || "").trim();
                const wp = (lines[1] || "").trim();
                if (av.indexOf("file://") === 0) root.avatarUrl = av;
                if (wp.indexOf("/") === 0) root.wallpaperPath = wp;
            }
        }
    }

    Timer {
        id: deferredInitialPoll
        interval: 220
        repeat: false
        onTriggered: {
            if (!root.active) return;
            root.pollAll();
            quickPrimeTimer.restart();
        }
    }

    Timer {
        id: quickPrimeTimer
        interval: 420
        repeat: false
        onTriggered: if (root.active) root.pollAll()
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: false
        onTriggered: root.pollAll()
    }

    Process {
        id: statProc
        command: [
            "sh", "-c",
            "echo @route; cat /proc/net/route 2>/dev/null; " +
            "echo @net; tail -n +3 /proc/net/dev 2>/dev/null; " +
            "echo @disk; cat /proc/diskstats 2>/dev/null; " +
            "echo @bat; for b in /sys/class/power_supply/BAT*; do " +
            "[ -d \"$b\" ] || continue; " +
            "ef=$(cat \"$b/energy_full\" 2>/dev/null || cat \"$b/charge_full\" 2>/dev/null); " +
            "ed=$(cat \"$b/energy_full_design\" 2>/dev/null || cat \"$b/charge_full_design\" 2>/dev/null); " +
            "pw=$(cat \"$b/power_now\" 2>/dev/null); " +
            "echo \"health=$ef:$ed\"; echo \"pw=$pw\"; break; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseStats(this.text)
        }
    }

    Process {
        id: gpuProc
        command: [
            "sh", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then " +
            "nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1; " +
            "else for c in /sys/class/drm/card*/device; do " +
            "[ -r \"$c/gpu_busy_percent\" ] || continue; " +
            "echo \"drm,$(cat \"$c/gpu_busy_percent\"),0,0,0\"; break; done; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseGpu(this.text)
        }
    }

    function parseGpu(raw) {
        const line = (raw || "").trim();
        if (!line) return;
        const parts = line.split(",").map(s => s.trim());
        if (parts.length < 5) return;
        root.hasGpu = true;
        if (parts[0] && parts[0] !== "drm") {
            root.gpuName = parts[0].replace(/^NVIDIA GeForce\s+/i, "").replace(/\s+Laptop GPU$/i, "");
        } else if (!root.gpuName) {
            root.gpuName = "Integrated GPU";
        }
        const util = parseFloat(parts[1]);
        if (!isNaN(util)) {
            root.gpuPercent = Math.max(0, Math.min(100, util));
            const nextH = root.gpuHistory.concat([root.gpuPercent / 100.0]);
            while (nextH.length > root.historyLength) nextH.shift();
            root.gpuHistory = nextH;
        }
        const vUsed = parseFloat(parts[2]);
        const vTot = parseFloat(parts[3]);
        const temp = parseFloat(parts[4]);
        if (!isNaN(vUsed) && vTot > 0) {
            root.gpuVramUsedMb = vUsed;
            root.gpuVramTotalMb = vTot;
        }
        if (!isNaN(temp) && temp > 0) root.gpuTemp = temp;
    }

    function parseStats(raw) {
        const now = Date.now();
        const lines = (raw || "").split("\n");
        let section = "";
        let defIface = "";
        const netRows = [];
        const diskRows = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            if (line.charAt(0) === "@") {
                section = line.slice(1);
                continue;
            }
            if (section === "route") {
                const cols = line.split(/\s+/);
                if (cols.length >= 2 && cols[1] === "00000000" && defIface === "") {
                    defIface = cols[0];
                }
            } else if (section === "net") {
                const m = /^([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/.exec(line);
                if (!m) continue;
                const iface = m[1].trim();
                if (/^(lo|virbr|docker|veth|br-)/.test(iface)) continue;
                netRows.push({ name: iface, rx: parseFloat(m[2]), tx: parseFloat(m[3]) });
            } else if (section === "disk") {
                const cols = line.split(/\s+/);
                if (cols.length < 10) continue;
                const dev = cols[2];
                // Whole physical block devices only (nvme0n1, sda, vda, mmcblk0)
                if (!/^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+)$/.test(dev)) continue;
                diskRows.push({ device: dev, rSec: parseFloat(cols[5]), wSec: parseFloat(cols[9]) });
            } else if (section === "bat") {
                if (line.startsWith("health=")) {
                    const p = line.slice(7).split(":");
                    const ef = parseFloat(p[0]), ed = parseFloat(p[1]);
                    if (ed > 0 && ef > 0) root.batteryHealth = Math.min(100, Math.round((ef / ed) * 100));
                } else if (line.startsWith("pw=")) {
                    const uw = parseFloat(line.slice(3));
                    if (!isNaN(uw)) root.batteryRateW = uw / 1000000.0;
                }
            }
        }

        if (defIface) root.defaultInterface = defIface;
        else if (netRows.length > 0 && !root.defaultInterface) root.defaultInterface = netRows[0].name;

        const dtNet = root._prevNetAt > 0 ? Math.max(0.2, (now - root._prevNetAt) / 1000.0) : 0;
        const nextNetPrev = {};
        const nextDownMap = Object.assign({}, root.downloadHistories);
        const nextUpMap = Object.assign({}, root.uploadHistories);
        const outInterfaces = [];

        netRows.forEach(item => {
            nextNetPrev[item.name] = { rx: item.rx, tx: item.tx };
            let dl = 0, ul = 0;
            if (dtNet > 0 && root._prevNetBytes[item.name]) {
                dl = Math.max(0, (item.rx - root._prevNetBytes[item.name].rx) / dtNet);
                ul = Math.max(0, (item.tx - root._prevNetBytes[item.name].tx) / dtNet);
                root.pushHist(nextDownMap, item.name, dl);
                root.pushHist(nextUpMap, item.name, ul);
            } else if (!Array.isArray(nextDownMap[item.name]) || nextDownMap[item.name].length === 0) {
                root.pushHist(nextDownMap, item.name, 0);
                root.pushHist(nextUpMap, item.name, 0);
            }
            outInterfaces.push({ name: item.name, downloadBps: dl, uploadBps: ul });
        });
        root._prevNetBytes = nextNetPrev;
        root._prevNetAt = now;
        root.netInterfaces = outInterfaces;
        root.downloadHistories = nextDownMap;
        root.uploadHistories = nextUpMap;

        const dtDisk = root._prevDiskAt > 0 ? Math.max(0.2, (now - root._prevDiskAt) / 1000.0) : 0;
        const nextDiskPrev = {};
        const nextReadMap = Object.assign({}, root.readHistories);
        const nextWriteMap = Object.assign({}, root.writeHistories);
        const outDisks = [];

        diskRows.forEach(d => {
            nextDiskPrev[d.device] = { rSec: d.rSec, wSec: d.wSec };
            let rb = 0, wb = 0;
            if (dtDisk > 0 && root._prevDiskSectors[d.device]) {
                rb = Math.max(0, (d.rSec - root._prevDiskSectors[d.device].rSec) * 512.0 / dtDisk);
                wb = Math.max(0, (d.wSec - root._prevDiskSectors[d.device].wSec) * 512.0 / dtDisk);
                root.pushHist(nextReadMap, d.device, rb);
                root.pushHist(nextWriteMap, d.device, wb);
            } else if (!Array.isArray(nextReadMap[d.device]) || nextReadMap[d.device].length === 0) {
                root.pushHist(nextReadMap, d.device, 0);
                root.pushHist(nextWriteMap, d.device, 0);
            }
            outDisks.push({ device: d.device, readBps: rb, writeBps: wb });
        });
        root._prevDiskSectors = nextDiskPrev;
        root._prevDiskAt = now;
        root.disks = outDisks;
        root.readHistories = nextReadMap;
        root.writeHistories = nextWriteMap;
    }

    function formatBytes(bytes) {
        const b = Number(bytes) || 0;
        if (b >= 1099511627776) return (b / 1099511627776).toFixed(1) + " TB";
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576) return (b / 1048576).toFixed(0) + " MB";
        return Math.round(b / 1024) + " KB";
    }

    function formatRate(bps) {
        const v = Number(bps) || 0;
        if (v >= 1048576) return (v / 1048576).toFixed(v >= 10485760 ? 0 : 1) + " MB/s";
        if (v >= 1024) return Math.round(v / 1024) + " KB/s";
        return Math.round(v) + " B/s";
    }
}
