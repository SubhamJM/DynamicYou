import QtQuick
import Quickshell
import Quickshell.Io

// Luxury smoothed Cava audio visualizer process with Sekai-Pop asymmetric DSP filter
Item {
    id: root
    
    property bool active: false
    property int bars: 5
    property var points: []
    property var peaks: []
    property real normalizationCeiling: 100
    property bool audioSignalActive: false

    // Internal smoothed buffer
    property var _smoothed: []
    property var _peaks: []
    property real lastAudioTime: 0

    Process {
        id: cavaProc
        running: root.active
        command: [
            Qt.resolvedUrl("../scripts/cava_runner.sh").toString().replace(/^file:\/\//, "") || (Quickshell.env("HOME") + "/.config/quickshell/scripts/cava_runner.sh"),
            root.bars.toString()
        ]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!root.active) return;
                var raw = data.trim();
                if (raw.length === 0) return;
                
                var fields = raw.split(";");
                var pts = [];
                var rawPeak = 0;
                var sum = 0;
                
                for (var i = 0; i < fields.length; i++) {
                    if (fields[i] === "") continue;
                    var v = parseFloat(fields[i]);
                    if (!isNaN(v)) {
                        pts.push(v);
                        rawPeak = Math.max(rawPeak, v);
                        sum += v;
                    }
                }
                
                if (pts.length >= root.bars) {
                    var now = Date.now();
                    var isSignaled = (rawPeak >= 2) || ((sum / root.bars) >= 0.35);
                    if (isSignaled) {
                        root.lastAudioTime = now;
                        root.audioSignalActive = true;
                    } else if (now - root.lastAudioTime > 2000) {
                        root.audioSignalActive = false;
                    }

                    // Sekai-Pop Asymmetric Attack/Release Filter
                    // Rising (attack): 0.48 multiplier for instant punch on drums and beats
                    // Falling (release): 0.14 multiplier for smooth natural logarithmic decay
                    var newSmooth = [];
                    var newPeaks = [];
                    var curSmooth = root._smoothed || [];
                    var curPeaks = root._peaks || [];

                    for (var b = 0; b < root.bars; b++) {
                        var target = pts[b] || 0;
                        var prev = (curSmooth.length > b) ? curSmooth[b] : 0;
                        var s = 0;
                        if (target > prev) {
                            s = prev + (target - prev) * 0.48;
                        } else {
                            s = prev + (target - prev) * 0.14;
                        }
                        if (s < 0.05) s = 0;
                        newSmooth.push(s);

                        var prevPk = (curPeaks.length > b) ? curPeaks[b] : 0;
                        var pk = Math.max(s, prevPk * 0.94);
                        if (pk < 0.05) pk = 0;
                        newPeaks.push(pk);
                    }

                    root._smoothed = newSmooth;
                    root._peaks = newPeaks;
                    root.points = newSmooth;
                    root.peaks = newPeaks;
                    
                    var targetCeil = Math.max(20, rawPeak * 1.15);
                    if (targetCeil >= root.normalizationCeiling) {
                        root.normalizationCeiling = targetCeil;
                    } else {
                        root.normalizationCeiling = Math.max(20, root.normalizationCeiling * 0.99);
                    }
                }
            }
        }
    }
    
    // Clean reset when inactive
    onActiveChanged: {
        if (!active) {
            _smoothed = [];
            _peaks = [];
            points = [];
            peaks = [];
            normalizationCeiling = 100;
            audioSignalActive = false;
        }
    }
}
