pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../services"

// Matushell Cava backend ported directly to Dynamic You (reference-counted 60Hz pipewire FFT stream)
Singleton {
    id: root

    property var cavaData: []
    property bool isSilent: true
    property bool active: false
    property int bars: 60
    property int fps: 45
    property int retainedCount: 0
    property int _silenceCounter: 0
    property var _prevData: []
    property bool _zeroFrameSent: false
    property bool _pausedForSilence: false

    readonly property int effectiveBars: {
        const b = Math.max(8, Math.round(bars));
        return b % 2 === 0 ? b : b + 1;
    }
    readonly property int effectiveFps: Math.max(15, Math.min(90, Math.round(fps || 45)))

    readonly property bool mediaPlaying: (MprisController.activePlayer?.isPlaying ?? false)
        || (Mpris.players && Mpris.players.values.some(p => p && p.isPlaying === true))

    onMediaPlayingChanged: {
        if (mediaPlaying && _pausedForSilence) {
            _pausedForSilence = false;
            if (retainedCount > 0) root.active = true;
        }
    }

    readonly property bool runningWanted: retainedCount > 0 && (!_pausedForSilence || mediaPlaying)

    function retain() {
        root.retainedCount++;
        if (root.retainedCount === 1) {
            root._pausedForSilence = false;
            root.active = true;
            silenceStopTimer.stop();
        }
    }

    function release() {
        if (root.retainedCount <= 0) return;
        root.retainedCount--;
        if (root.retainedCount === 0) {
            root.active = false;
            root.isSilent = true;
            root._zeroFrameSent = false;
            root._pausedForSilence = false;
            root.cavaData = [];
            root._prevData = [];
        }
    }

    onBarsChanged: {
        if (cavaProc.running) restartTimer.restart();
    }

    onFpsChanged: {
        if (cavaProc.running) restartTimer.restart();
    }

    Timer {
        id: restartTimer
        interval: 150
        onTriggered: {
            cavaProc.running = false;
            Qt.callLater(() => { if (root.runningWanted) cavaProc.running = true; });
        }
    }

    Timer {
        id: silenceStopTimer
        interval: 6000
        onTriggered: {
            if (!root.mediaPlaying && root.isSilent) {
                root.active = false;
                root._pausedForSilence = true;
            }
        }
    }

    function processLine(line) {
        if (!line) return;
        const parts = line.split(";");
        const n = parts.length > 0 && parts[parts.length - 1] === "" ? parts.length - 1 : parts.length;
        if (n <= 0) return;

        if (root._prevData.length !== n) {
            root._prevData = new Array(n).fill(0);
            root._zeroFrameSent = false;
        }

        let maxVal = 0;
        let maxDelta = 0;
        const smoothFactor = 0.28;
        const out = new Array(n);

        for (let i = 0; i < n; i++) {
            const raw = parseInt(parts[i], 10);
            const target = isNaN(raw) ? 0 : Math.min(1.0, Math.max(0.0, raw / 1000.0));
            const prev = root._prevData[i];
            let val = prev + (target - prev) * smoothFactor;
            if (val < 0.002 && target === 0) val = 0;
            root._prevData[i] = val;
            const rounded = Math.round(val * 1000) / 1000;
            out[i] = rounded;
            if (val > maxVal) maxVal = val;
            const d = Math.abs(rounded - prev);
            if (d > maxDelta) maxDelta = d;
        }

        if (maxVal < 0.015) {
            if (root._silenceCounter < 20) root._silenceCounter++;
            if (root._silenceCounter >= 10 && !root.isSilent) {
                root.isSilent = true;
                silenceStopTimer.restart();
            }
            if (maxVal === 0 && root._zeroFrameSent) return;
            root._zeroFrameSent = (maxVal === 0);
        } else {
            root._silenceCounter = 0;
            root._zeroFrameSent = false;
            root._pausedForSilence = false;
            if (root.isSilent) root.isSilent = false;
            if (!root.active) root.active = true;
            silenceStopTimer.stop();
        }

        if (maxDelta < 0.002 && root.cavaData.length === n && maxVal > 0) return;
        root.cavaData = out;
    }

    Process {
        id: cavaProc
        running: root.runningWanted
        command: [
            "sh", "-c",
            "TMPCONF=\"/tmp/dy_matus_cava_$(id -u)_" + root.effectiveBars + ".conf\"; " +
            "printf '[general]\\nbars = %d\\nframerate = %d\\nautosens = 1\\n[input]\\nmethod = pipewire\\nsource = auto\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 1000\\nbar_delimiter = 59\\n[smoothing]\\nmonstercat = 1.5\\nwaves = 0\\ngravity = 110\\nnoise_reduction = 0.30\\n' " +
            root.effectiveBars + " " + root.effectiveFps + " > \"$TMPCONF\"; " +
            "exec setpriv --pdeathsig TERM cava -p \"$TMPCONF\" < /dev/null"
        ]
        stdout: SplitParser {
            onRead: (data) => root.processLine(data)
        }
        onRunningChanged: {
            if (!running) {
                root.cavaData = [];
                root.isSilent = true;
                root.active = false;
            }
        }
    }
}
