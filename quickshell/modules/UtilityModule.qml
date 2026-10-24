import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

Item {
    id: utilModule
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true
    Keys.onEscapePressed: (event) => {
        if (utilModule.activeSection !== "") {
            utilModule.activeSection = "";
        } else {
            root.collapseToIdle();
        }
        event.accepted = true;
    }

    // ========================================================
    // STATE PROPERTIES & CONTROLS
    // ========================================================
    property string activeSection: "" // "" (main), "audio", "vpn"
    onActiveSectionChanged: {
        if (activeSection === "audio") {
            fetchAudioDevices.running = true;
        } else if (activeSection === "vpn") {
            fetchVpnStatus.running = true;
        }
    }

    Component.onCompleted: {
        fetchAudioDevices.running = true;
        fetchVpnStatus.running = true;
    }
    property bool nightLightActive: false
    property bool caffeineActive: false
    property bool audioMuted: false
    property real audioVolume: 0.5
    property bool audioMicMuted: false
    property real audioMicVolume: 0.5
    property real displayBrightness: 0.5

    property bool isDraggingVolume: false
    property bool isDraggingMic: false
    property bool isDraggingBrightness: false

    readonly property color colBg: "#000000"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.055)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.12)
    readonly property color colCardActive: Qt.rgba(255, 255, 255, 0.18)
    readonly property color colAccent: Theme.accent
    readonly property color colText: "#f5f5f7"
    readonly property color colSubtext: Qt.rgba(255, 255, 255, 0.60)
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.38)
    readonly property color colBorder: "transparent"
    readonly property color colBorderHover: "transparent"

    // Reactive Connectivity Data
    property bool wifiEnabled: true
    property bool isTogglingWifi: false
    readonly property bool btEnabled: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property string activeNetName: typeof dashMod !== "undefined" ? dashMod.activeNetName : ""
    readonly property string activeNetType: typeof dashMod !== "undefined" ? dashMod.activeNetType : "wifi"
    readonly property int activeNetSignal: typeof dashMod !== "undefined" ? dashMod.activeNetSignal : 0
    readonly property string activeBtName: typeof dashMod !== "undefined" ? dashMod.btDeviceName : ""
    readonly property string activeBtBattery: typeof dashMod !== "undefined" ? dashMod.btIslandBattery : ""

    function forceNotesFocus() {}

    // ========================================================
    // HARDWARE ACTIONS & PROCESSES
    // ========================================================

    // 1. Wi-Fi Toggle & Monitoring
    Process {
        id: checkWifiRadio
        running: true
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (utilModule.isTogglingWifi) return;
                var isEnabled = this.text.trim() === "enabled";
                utilModule.wifiEnabled = isEnabled;
                if (root.wifiMod) root.wifiMod.wifiEnabled = isEnabled;
            }
        }
    }

    Timer {
        id: wifiSettleTimer
        interval: 350
        repeat: false
        onTriggered: {
            utilModule.isTogglingWifi = false;
            checkWifiRadio.running = true;
            if (root.wifiMod) root.wifiMod.refreshStatus();
        }
    }

    function toggleWifi() {
        var targetState = !utilModule.wifiEnabled;
        utilModule.isTogglingWifi = true;
        utilModule.wifiEnabled = targetState;
        if (root.wifiMod) {
            root.wifiMod.wifiEnabled = targetState;
        }
        Quickshell.execDetached(["nmcli", "radio", "wifi", targetState ? "on" : "off"]);
        wifiSettleTimer.restart();
    }

    // 1b. Hotspot Toggle & Monitoring
    property bool hotspotActive: root.wifiMod ? root.wifiMod.hotspotActive : false

    Process {
        id: checkHotspotStatus
        running: true
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show --active | grep -iE '^(802-11-wireless|wifi).*:.*hotspot' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var isActive = (this.text.trim().length > 0);
                utilModule.hotspotActive = isActive;
                if (root.wifiMod) root.wifiMod.hotspotActive = isActive;
            }
        }
    }

    Timer {
        id: hotspotSettleTimer
        interval: 400
        repeat: false
        onTriggered: {
            checkHotspotStatus.running = true;
            if (root.wifiMod) root.wifiMod.refreshStatus();
        }
    }

    Process {
        id: utilHotspotRunner
        running: false
        onExited: {
            checkHotspotStatus.running = true;
            if (root.wifiMod) root.wifiMod.refreshStatus();
        }
    }

    function toggleHotspot() {
        var targetState = !utilModule.hotspotActive;
        utilModule.hotspotActive = targetState;
        if (targetState) {
            utilHotspotRunner.command = ["sh", "-c", "nmcli radio wifi on && sleep 0.4 && (nmcli connection up Hotspot 2>/dev/null || nmcli device wifi hotspot 2>/dev/null || nmcli device wifi hotspot ssid 'SubhamLaptop' password '000000001')"];
        } else {
            utilHotspotRunner.command = ["sh", "-c", "for uuid in $(nmcli -t -f UUID,TYPE,NAME con show --active | grep -iE ':(wifi|802-11-wireless):.*hotspot' | cut -d: -f1); do nmcli con down uuid \"$uuid\" 2>/dev/null; done; nmcli connection down Hotspot 2>/dev/null || true"];
        }
        utilHotspotRunner.running = true;
        if (root.wifiMod) root.wifiMod.toggleHotspot(targetState);
        hotspotSettleTimer.restart();
    }

    // 2. Bluetooth Toggle & Open
    function toggleBluetooth() {
        if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
        } else {
            Quickshell.execDetached(["rfkill", "toggle", "bluetooth"]);
        }
    }

    // 3. Night Light (hyprsunset / wlsunset)
    Process {
        id: checkNightLight
        running: false
        command: ["sh", "-c", "(pgrep -x hyprsunset >/dev/null || pgrep -x wlsunset >/dev/null) && echo 'active' || echo 'inactive'"]
        stdout: StdioCollector {
            onStreamFinished: {
                utilModule.nightLightActive = (this.text.trim() === "active");
            }
        }
    }

    function toggleNightLight() {
        if (nightLightActive) {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset wlsunset 2>/dev/null"]);
            nightLightActive = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset wlsunset 2>/dev/null; if command -v hyprsunset >/dev/null 2>&1; then hyprsunset -t 4500; else wlsunset -t 4500; fi"]);
            nightLightActive = true;
        }
        checkNightLight.running = true;
    }

    // 4. Caffeine / Keep Me Awake (hypridle inhibitor)
    Process {
        id: caffeineInhibitor
        running: false
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=Keep Me Awake", "sleep", "infinity"]
    }

    Process {
        id: checkCaffeineState
        running: false
        command: ["sh", "-c", "if [ -f /tmp/quickshell_keep_awake ]; then if pidof hypridle >/dev/null 2>&1; then rm -f /tmp/quickshell_keep_awake; echo 'inactive'; else echo 'active'; fi; else echo 'inactive'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                utilModule.caffeineActive = (this.text.trim() === "active");
            }
        }
    }

    function toggleCaffeine() {
        if (caffeineActive) {
            caffeineInhibitor.running = false;
            caffeineActive = false;
            Quickshell.execDetached(["sh", "-c", "rm -f /tmp/quickshell_keep_awake; pidof hypridle >/dev/null 2>&1 || hyprctl dispatch exec hypridle || hypridle &"]);
        } else {
            caffeineActive = true;
            Quickshell.execDetached(["sh", "-c", "touch /tmp/quickshell_keep_awake; killall -9 hypridle 2>/dev/null; hyprctl dispatch dpms on 2>/dev/null"]);
            caffeineInhibitor.running = true;
        }
        checkCaffeineState.running = true;
    }

    // 6. Color Picker (hyprpicker)
    function triggerColorPicker() {
        root.collapseToIdle();
        Quickshell.execDetached(["sh", "-c", "sleep 0.15; hyprpicker -a && notify-send 'Color Picker' \"Copied $(wl-paste) to clipboard\""]);
    }

    // 7. Area Screenshot Hub (grim + slurp -> Dynamic Island annotation hub)
    function triggerScreenshot() {
        root.collapseToIdle();
        var hubScript = Quickshell.env("HOME") + "/.config/quickshell/scripts/screenshot_hub.sh";
        Quickshell.execDetached(["bash", hubScript]);
    }

    // 8. Audio Volume & Mute (wpctl)
    Process {
        id: fetchVolumeProcess
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                utilModule.audioMuted = txt.includes("[MUTED]");
                var parts = txt.split(/\s+/);
                if (parts.length >= 2 && !utilModule.isDraggingVolume) {
                    var v = parseFloat(parts[1]);
                    if (!isNaN(v)) {
                        utilModule.audioVolume = Math.max(0.0, Math.min(1.0, v));
                    }
                }
            }
        }
    }

    Process {
        id: fetchMicProcess
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                utilModule.audioMicMuted = txt.includes("[MUTED]");
                if (!utilModule.isDraggingMic) {
                    var parts = txt.split(/\s+/);
                    if (parts.length >= 2) {
                        var v = parseFloat(parts[1]);
                        if (!isNaN(v)) {
                            utilModule.audioMicVolume = Math.max(0.0, Math.min(1.0, v));
                        }
                    }
                }
            }
        }
    }

    function setVolume(ratio) {
        var v = Math.max(0.0, Math.min(1.0, ratio));
        utilModule.audioVolume = v;
        if (v > 0.001) {
            utilModule.audioMuted = false;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
        } else {
            utilModule.audioMuted = true;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"]);
        }
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
    }

    function toggleMute() {
        var willMute = !utilModule.audioMuted;
        utilModule.audioMuted = willMute;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", willMute ? "1" : "0"]);
        fetchVolumeProcess.running = true;
    }

    function toggleMicMute() {
        utilModule.audioMicMuted = !utilModule.audioMicMuted;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        fetchMicProcess.running = true;
    }

    function setMicVolume(ratio) {
        var v = Math.max(0.0, Math.min(1.0, ratio));
        utilModule.audioMicVolume = v;
        if (v > 0 && utilModule.audioMicMuted) {
            utilModule.audioMicMuted = false;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"]);
        }
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", v.toFixed(2)]);
    }

    // 9. Display Brightness (brightnessctl)
    Process {
        id: fetchBrightnessProcess
        running: false
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseInt(this.text.trim());
                if (!isNaN(val) && !utilModule.isDraggingBrightness) {
                    utilModule.displayBrightness = Math.max(0.01, Math.min(1.0, val / 100.0));
                }
            }
        }
    }

    function setBrightness(ratio) {
        var pct = Math.max(1, Math.min(100, Math.round(ratio * 100)));
        utilModule.displayBrightness = pct / 100.0;
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
    }

    // 10. Audio Devices Data (Sinks & Sources)
    property var audioSinks: []
    property var audioSources: []
    readonly property var defaultSink: {
        for (var i = 0; i < utilModule.audioSinks.length; i++) {
            if (utilModule.audioSinks[i].isDefault) return utilModule.audioSinks[i];
        }
        return utilModule.audioSinks.length > 0 ? utilModule.audioSinks[0] : null;
    }

    Process {
        id: fetchAudioDevices
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    utilModule.audioSinks = data.sinks || [];
                    utilModule.audioSources = data.sources || [];
                } catch (e) {}
            }
        }
    }

    function cleanDeviceName(name, desc) {
        var d = (desc && desc.length > 0) ? desc : (name || "Audio Device");
        d = d.replace(/^(Alder|Raptor)\s*Lake(-P\/U\/H)?\s*(cAVS|High Definition Audio Controller)?\s*/i, "");
        d = d.replace(/\bHDMI\s*\/\s*DisplayPort\s*\d+\s*Output\b/i, "HDMI Output");
        return d.trim() || desc || name;
    }

    function getSinkIcon(name, desc) {
        var n = ((name || "") + " " + (desc || "")).toLowerCase();
        if (n.includes("bluez") || n.includes("buds") || n.includes("headset") || n.includes("headphone") || n.includes("ear")) return "headphones";
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("tv")) return "tv";
        return "speaker";
    }

    function setDefaultSink(sinkName) {
        var updated = [];
        for (var i = 0; i < utilModule.audioSinks.length; i++) {
            var item = utilModule.audioSinks[i];
            updated.push({
                id: item.id,
                name: item.name,
                desc: item.desc,
                isDefault: (item.name === sinkName)
            });
        }
        utilModule.audioSinks = updated;

        Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-sink", sinkName]);
        Quickshell.execDetached(["pactl", "set-default-sink", sinkName]);
        audioRefreshTimer.restart();
    }

    function setDefaultSource(sourceName) {
        var updated = [];
        for (var i = 0; i < utilModule.audioSources.length; i++) {
            var item = utilModule.audioSources[i];
            updated.push({
                id: item.id,
                name: item.name,
                desc: item.desc,
                isDefault: (item.name === sourceName)
            });
        }
        utilModule.audioSources = updated;

        Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-source", sourceName]);
        Quickshell.execDetached(["pactl", "set-default-source", sourceName]);
        audioRefreshTimer.restart();
    }

    Timer {
        id: audioRefreshTimer
        interval: 350
        repeat: false
        running: false
        onTriggered: {
            fetchAudioDevices.running = true;
            fetchVolumeProcess.running = true;
            fetchMicProcess.running = true;
        }
    }

    // 11. VPN State & Management (Cloudflare WARP, Tailscale, WireGuard, NM VPNs)
    property bool vpnActive: false
    property bool vpnConnecting: false
    property string activeVpnName: "Disconnected"
    property string activeVpnId: "none"
    property string defaultVpnId: "warp"
    property var vpnProviders: []

    Process {
        id: fetchVpnStatus
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/vpn_manager.py").toString().replace("file://", ""), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text.trim());
                    utilModule.vpnActive = data.connected || false;
                    utilModule.vpnConnecting = data.connecting || false;
                    utilModule.activeVpnName = data.active_name || (data.connecting ? "Connecting..." : "Disconnected");
                    utilModule.activeVpnId = data.active_id || "none";
                    utilModule.defaultVpnId = data.default_id || "warp";
                    utilModule.vpnProviders = data.providers || [];
                } catch (e) {}
            }
        }
    }

    function toggleVpn(providerId) {
        var isBusy = utilModule.vpnActive || utilModule.vpnConnecting;
        if (providerId) {
            var targetRunning = false;
            for (var i = 0; i < utilModule.vpnProviders.length; i++) {
                var p = utilModule.vpnProviders[i];
                if (p.id === providerId && (p.active || p.connecting)) {
                    targetRunning = true;
                    break;
                }
            }
            if (targetRunning || isBusy) {
                // User wants to turn off
                utilModule.vpnActive = false;
                utilModule.vpnConnecting = false;
                utilModule.activeVpnName = "Disconnected";
                Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/vpn_manager.py").toString().replace("file://", ""), "disconnect", providerId]);
                if (providerId === "warp") {
                    Quickshell.execDetached(["warp-cli", "--accept-tos", "disconnect"]);
                }
            } else {
                // User wants to connect
                utilModule.vpnConnecting = true;
                utilModule.activeVpnName = "Connecting...";
                Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/vpn_manager.py").toString().replace("file://", ""), "toggle", providerId]);
            }
        } else {
            // Main VPN toggle
            if (isBusy) {
                // Immediately turn off warp-cli regardless of whether it is connecting right now or already connected!
                utilModule.vpnActive = false;
                utilModule.vpnConnecting = false;
                utilModule.activeVpnName = "Disconnected";
                Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/vpn_manager.py").toString().replace("file://", ""), "disconnect"]);
                Quickshell.execDetached(["warp-cli", "--accept-tos", "disconnect"]);
            } else {
                // Immediately show connecting visual cues!
                utilModule.vpnConnecting = true;
                utilModule.activeVpnName = "Connecting...";
                Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/vpn_manager.py").toString().replace("file://", ""), "toggle"]);
            }
        }
        vpnPollTimer.ticks = 0;
        vpnPollTimer.restart();
    }

    Timer {
        id: vpnPollTimer
        interval: 400
        repeat: true
        running: false
        property int ticks: 0
        onTriggered: {
            fetchVpnStatus.running = true;
            ticks++;
            if (ticks > 8) {
                running = false;
                ticks = 0;
            }
        }
    }

    Timer {
        interval: 1000
        running: utilModule.visible && root.activeMode === "utility"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            checkWifiRadio.running = true;
            checkHotspotStatus.running = true;
            checkNightLight.running = true;
            checkCaffeineState.running = true;
            fetchVolumeProcess.running = true;
            fetchMicProcess.running = true;
            fetchBrightnessProcess.running = true;
            fetchVpnStatus.running = true;
            if (utilModule.activeSection === "audio") fetchAudioDevices.running = true;
            if (utilModule.activeSection === "vpn") fetchVpnStatus.running = true;
        }
    }

    // ========================================================
    // REUSABLE MODERN BENTO GRID COMPONENTS
    // ========================================================

    // ========================================================
    // IRIS 1:1 REUSABLE DESIGN COMPONENTS (ZERO BORDERS, MATERIAL YOU)
    // ========================================================

    // 1. Iris 1:1 Wide Action Plate (2x1) - Neutral Dark Glass with Accent Disc
    component IrisActionPlate: Rectangle {
        id: iplate
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool lit: false
        property bool isSplit: true
        property color tint: utilModule.colAccent
        property bool showChevron: true
        signal clicked()
        signal iconClicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 44
        radius: 14

        // Clean neutral dark frosted glass (never whole-card colored)
        color: plateMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.055)
        border.width: 0

        scale: plateMouse.pressed ? 0.985 : (plateMouse.containsMouse ? 1.01 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        // Whole card click area (opens popup / details)
        MouseArea {
            id: plateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iplate.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 5.25

            // Left: Circular Icon Disc (toggles state specifically)
            Rectangle {
                id: iplateDisc
                z: 10
                width: 33
                height: 33
                radius: 16.5
                color: iplate.lit
                    ? iplate.tint
                    : (discMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.085))
                scale: discMouse.pressed ? 0.88 : (discMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 110 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: iplate.glyph
                    fill: iplate.lit ? 1 : 0
                    iconSize: 18.5
                    color: iplate.lit ? "#101318" : "#f5f5f7"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: discMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: (mouse) => {
                        mouse.accepted = true;
                        iplate.iconClicked();
                    }
                }
            }

            // Middle: Text Area
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    text: iplate.title
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: iplate.subtitle
                    visible: iplate.subtitle !== ""
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Normal
                    color: Qt.rgba(255, 255, 255, 0.70)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Right: Chevron / Status Indicator
            MaterialSymbol {
                visible: iplate.showChevron
                text: "chevron_right"
                iconSize: 14
                color: Qt.rgba(255, 255, 255, 0.40)
                opacity: 0.8
            }
        }
    }

    // 2. Iris 1:1 Action Square Tile (Hotspot, Caffeine, Night Light, DND, Color, Timer)
    component IrisGridTile: Rectangle {
        id: gtile
        property string glyph: ""
        property string label: ""
        property bool lit: false
        property color tint: utilModule.colAccent
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 14

        // Solid accent when active, clean glass container when off
        color: gtile.lit
            ? gtile.tint
            : (tileMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.065))
        border.width: 0

        scale: tileMouse.pressed ? 0.92 : (tileMouse.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: gtile.glyph
            fill: gtile.lit ? 1 : 0
            iconSize: 18
            color: gtile.lit ? (Theme.colors.bg ?? "#000000") : (tileMouse.containsMouse ? "#ffffff" : "#f5f5f7")
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: gtile.clicked()
        }
    }

    // 3. Iris 1:1 Vertical Capsule Slider
    component IrisVerticalCapsuleSlider: Item {
        id: vslider
        property real value: 0.5
        property string icon: "volume_up"
        property string percentText: "50%"
        property bool muted: false
        property color activeColor: "#ffffff"
        signal moved(real val)
        signal iconClicked()

        property real dragVal: -1
        readonly property real currentRatio: Math.max(0.0, Math.min(1.0, vslider.dragVal >= 0 ? vslider.dragVal : vslider.value))

        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            id: track
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 0
            clip: true

            scale: vsliderMouse.pressed ? 0.985 : (vsliderMouse.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            // Fluid Rising Fill with rounded top and bottom - strictly pure white (#ffffff)
            Rectangle {
                id: fillFace
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: vslider.currentRatio > 0.02
                height: vslider.muted ? 0 : Math.max(0, Math.min(parent.height, parent.height * vslider.currentRatio))
                radius: 18
                color: vslider.muted ? Qt.rgba(255, 255, 255, 0.20) : "#ffffff"

                Behavior on height {
                    enabled: vslider.dragVal < 0
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }
            }

            // Top Numeric Percentage Readout
            Text {
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                z: 5
                text: vslider.percentText
                font.family: "Noto Sans"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
                color: vslider.muted
                    ? "#ff6961"
                    : (vslider.currentRatio >= 0.85 ? "#101318" : "#ffffff")
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Bottom Icon Circle Pocket (Interactive Mute / Action)
            Rectangle {
                id: viconPocket
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 30
                height: 30
                radius: 15
                z: 6
                color: viconMouse.containsMouse
                    ? (vslider.currentRatio >= 0.25 ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(255, 255, 255, 0.18))
                    : "transparent"
                scale: viconMouse.pressed ? 0.88 : (viconMouse.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 75 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: vslider.icon
                    fill: 1
                    iconSize: 17
                    color: vslider.muted
                        ? "#ff453a"
                        : (vslider.currentRatio >= 0.22 ? "#101318" : "#ffffff")
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: viconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: (mouse) => {
                        mouse.accepted = true;
                        vslider.iconClicked();
                    }
                }
            }

            // Tactile Drag & Scroll Mouse Area
            MouseArea {
                id: vsliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function calcRatio(mouseY) {
                    return Math.max(0.0, Math.min(1.0, (height - mouseY) / Math.max(1, height)));
                }

                onPressed: (mouse) => {
                    if (mouse.y >= height - 36) return; // Handled by icon pocket
                    vslider.dragVal = calcRatio(mouse.y);
                    vslider.moved(vslider.dragVal);
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || vslider.dragVal < 0) return;
                    vslider.dragVal = calcRatio(mouse.y);
                    vslider.moved(vslider.dragVal);
                }

                onReleased: {
                    vslider.dragVal = -1;
                    utilModule.isDraggingBrightness = false;
                    utilModule.isDraggingVolume = false;
                    utilModule.isDraggingMic = false;
                }

                onWheel: (wheel) => {
                    var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    vslider.moved(Math.max(0.0, Math.min(1.0, vslider.currentRatio + step)));
                }
            }
        }
    }

    // ========================================================
    // REUSABLE MATERIAL YOU COMPONENTS
    // ========================================================

    // 1. Material You Pill Toggle (Wi-Fi, Bluetooth, Focus, Night Light)
    component MaterialPill: Rectangle {
        id: pill
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool isActive: false
        property bool isSplit: false // If true, left circle toggles on/off, body opens detail
        property color activeColor: utilModule.colAccent
        signal toggleClicked()
        signal detailClicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 44
        radius: 14

        color: pill.isActive
            ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.16)
            : ((discMouse.containsMouse || pillBodyMouse.containsMouse) ? utilModule.colCardHover : utilModule.colCard)
        border.width: 0

        scale: pillBodyMouse.pressed ? 0.982 : ((discMouse.containsMouse || pillBodyMouse.containsMouse) ? 1.008 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 10
            spacing: 8

            // Left: Circular Icon Disc
            Rectangle {
                id: discRect
                width: 32
                height: 32
                radius: 16
                color: pill.isActive ? pill.activeColor : (discMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.085))

                scale: discMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: pill.glyph
                    fill: pill.isActive ? 1 : 0
                    iconSize: 18
                    color: pill.isActive ? "#101318" : utilModule.colText
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: discMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.toggleClicked()
                }
            }

            // Right: Text Content Area
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    text: pill.title
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: pill.isActive ? "#ffffff" : utilModule.colText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: pill.subtitle
                    visible: pill.subtitle !== "" && pill.width >= 105
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Normal
                    color: pill.isActive ? pill.activeColor : utilModule.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MaterialSymbol {
                visible: pill.isSplit && pill.width >= 120
                text: "chevron_right"
                iconSize: 16
                color: pill.isActive ? pill.activeColor : utilModule.colSubtext
                opacity: 0.65
            }
        }

        MouseArea {
            id: pillBodyMouse
            anchors.fill: parent
            anchors.leftMargin: 40
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pill.isSplit) {
                    pill.detailClicked();
                } else {
                    pill.toggleClicked();
                }
            }
        }
    }

    // 2. Material You Circular Action Button (Lock, Power, etc.)
    component MaterialCircleBtn: Rectangle {
        id: cbtn
        property string glyph: ""
        property int fill: 0
        property color iconColor: utilModule.colText
        property color customBg: utilModule.colCard
        property color hoverBg: utilModule.colCardHover
        signal clicked()

        implicitWidth: 46
        implicitHeight: 46
        radius: 23
        color: cmouse.containsMouse ? cbtn.hoverBg : cbtn.customBg
        border.width: 0

        scale: cmouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: cbtn.glyph
            fill: cbtn.fill
            iconSize: 20
            color: cbtn.iconColor
        }

        MouseArea {
            id: cmouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: cbtn.clicked()
        }
    }

    // 3. Material 3 Unified Stadium Slider (split track, tactile icon button, auto-inverting labels, chevron routing)
    component MaterialSliderCard: Rectangle {
        id: scard
        property string title: ""
        property real value: 0.5
        property string icon: "volume_up"
        property string percentText: "50%"
        property bool muted: false
        property bool showChevron: false
        property color activeColor: utilModule.colAccent
        signal moved(real val)
        signal iconClicked()
        signal headerClicked()

        property real dragVal: -1
        readonly property real currentRatio: Math.max(0.0, Math.min(1.0, scard.dragVal >= 0 ? scard.dragVal : scard.value))

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 44
        radius: 14
        color: Qt.rgba(255, 255, 255, 0.08)
        border.width: 0

        scale: scardMouse.pressed ? 0.985 : (scardMouse.containsMouse ? 1.006 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        // Dynamic Fill Stadium Track
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: scard.muted ? 0 : Math.max(0, Math.min(parent.width, parent.width * scard.currentRatio))
                radius: scard.radius
                color: scard.muted ? Qt.rgba(255, 255, 255, 0.15) : scard.activeColor

                Behavior on width {
                    enabled: scard.dragVal < 0
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }
        }

        // Left Icon Interactive Button Circle
        Rectangle {
            id: iconBtn
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            z: 6
            color: iconMouse.containsMouse ? (scard.currentRatio >= 0.14 ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(255, 255, 255, 0.10)) : "transparent"
            scale: iconMouse.pressed ? 0.90 : 1.0
            Behavior on scale { NumberAnimation { duration: 75 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: scard.icon
                fill: 1
                iconSize: 18
                color: scard.muted
                    ? "#ff6961"
                    : (scard.currentRatio >= 0.12 ? "#101318" : utilModule.colText)
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: scard.iconClicked()
            }
        }

        // Right Percentage Readout + Chevron Row
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            z: 6

            Text {
                text: scard.percentText
                font.family: "Noto Sans"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                color: scard.muted
                    ? "#ff6961"
                    : (scard.currentRatio >= 0.85 ? "#101318" : "#ffffff")
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                visible: scard.showChevron
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: chevronMouse.containsMouse ? (scard.currentRatio >= 0.94 ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(255, 255, 255, 0.12)) : "transparent"
                scale: chevronMouse.pressed ? 0.88 : 1.0
                Behavior on scale { NumberAnimation { duration: 75 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    iconSize: 15
                    color: scard.currentRatio >= 0.94 ? "#101318" : (chevronMouse.containsMouse ? "#ffffff" : utilModule.colSubtext)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: chevronMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: scard.headerClicked()
                }
            }
        }

        // Tactile Drag & Wheel Handler for the whole slider
        MouseArea {
            id: scardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function calcRatio(mouseX) {
                return Math.max(0.0, Math.min(1.0, mouseX / Math.max(1, width)));
            }

            onPressed: (mouse) => {
                if (mouse.x <= 40) return; // Handled by iconBtn
                if (scard.showChevron && mouse.x >= width - 36) return; // Handled by chevron
                scard.dragVal = calcRatio(mouse.x);
                scard.moved(scard.dragVal);
            }

            onPositionChanged: (mouse) => {
                if (!pressed || scard.dragVal < 0) return;
                scard.dragVal = calcRatio(mouse.x);
                scard.moved(scard.dragVal);
            }

            onReleased: {
                scard.dragVal = -1;
                utilModule.isDraggingBrightness = false;
                utilModule.isDraggingVolume = false;
            }

            onWheel: (wheel) => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                scard.moved(Math.max(0.0, Math.min(1.0, scard.currentRatio + step)));
            }
        }
    }

    // 5. Compact Tonal Squircle for Secondary Hardware Tools (Icon-only)
    component MaterialChipBtn: Rectangle {
        id: chip
        property string glyph: ""
        property bool lit: false
        property bool isSplit: true
        property color tint: utilModule.colAccent
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 36
        radius: 12

        color: chip.lit
            ? Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, 0.20)
            : (chipMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
        border.width: 0

        scale: chipMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: chip.glyph
            fill: chip.lit ? 1 : 0
            iconSize: 18
            color: chip.lit ? chip.tint : (chipMouse.containsMouse ? utilModule.colText : utilModule.colSubtext)
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    // 6. Compact Header Quick Action Button
    component HeaderQuickBtn: Rectangle {
        id: hbtn
        property string glyph: ""
        property color iconColor: utilModule.colSubtext
        property color customBg: utilModule.colCard
        property color hoverBg: utilModule.colCardHover
        signal clicked()

        width: 26
        height: 26
        radius: 13
        color: hmouse.containsMouse ? hbtn.hoverBg : hbtn.customBg
        border.width: 0

        scale: hmouse.pressed ? 0.90 : (hmouse.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: hbtn.glyph
            iconSize: 14.5
            color: hmouse.containsMouse ? "#f5f5f7" : hbtn.iconColor
        }

        MouseArea {
            id: hmouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: hbtn.clicked()
        }
    }

    // ========================================================
    // MAIN LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 4
        spacing: 10

        // ── TOP HEADER BAR ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 10

            // Tactile Back / Exit Button
            Rectangle {
                width: 29; height: 29; radius: 14.5
                color: headerBackMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard
                border.width: 0
                scale: headerBackMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: utilModule.activeSection !== "" ? "arrow_back" : "tune"
                    iconSize: 15.5
                    color: utilModule.activeSection !== "" ? utilModule.colAccent : utilModule.colText
                }

                MouseArea {
                    id: headerBackMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (utilModule.activeSection !== "") {
                            utilModule.activeSection = "";
                        } else {
                            root.collapseToIdle();
                        }
                    }
                }
            }

            // Title & Date Subtitle
            ColumnLayout {
                spacing: 0
                Layout.preferredWidth: 150

                Text {
                    text: utilModule.activeSection === "audio" ? "Sound Devices" : (utilModule.activeSection === "vpn" ? "VPN & Privacy" : (utilModule.activeSection === "pomo" ? "Focus & Pomodoro" : "Control Center"))
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: "#f5f5f7"
                }

                Text {
                    text: utilModule.activeSection === "audio" ? "Select output sink & microphone source" : (utilModule.activeSection === "vpn" ? "Select network provider or quick-connect" : (utilModule.activeSection === "pomo" ? "Distraction-free focus & timer" : Qt.formatDate(clock.date, "dddd, d MMMM")))
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    color: utilModule.colSubtext
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            // Quick Shortcut Badges & System Actions (Notes, Clipboard, Theme, Tasks, Lock, Power)
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignRight
                visible: utilModule.activeSection === ""

                // 1. Notes
                HeaderQuickBtn {
                    glyph: "edit_note"
                    onClicked: root.switchMode("notes", false)
                }

                // 2. Clipboard History
                HeaderQuickBtn {
                    glyph: "assignment"
                    onClicked: root.switchMode("clipboard", false)
                }

                // 3. Theme Selector
                HeaderQuickBtn {
                    glyph: "palette"
                    onClicked: root.switchMode("theme", false)
                }

                // 4. Task Manager
                HeaderQuickBtn {
                    glyph: "monitoring"
                    onClicked: root.switchMode("taskmanager", false)
                }

                // 5. Screen Lock
                HeaderQuickBtn {
                    glyph: "lock"
                    onClicked: {
                        root.collapseToIdle();
                        Quickshell.execDetached(["hyprlock"]);
                    }
                }

                // 6. Power Menu
                HeaderQuickBtn {
                    glyph: "power_settings_new"
                    iconColor: "#ff453a"
                    hoverBg: Qt.rgba(255, 69, 58, 0.18)
                    onClicked: root.switchMode("powermenu", false)
                }
            }

            // Quick Disconnect Button in Header when in VPN subview
            Rectangle {
                visible: utilModule.activeSection === "vpn" && (utilModule.vpnActive || utilModule.vpnConnecting)
                Layout.alignment: Qt.AlignRight
                width: headerDisconnectText.implicitWidth + 16
                height: 24
                radius: 12
                color: headerDiscMouse.containsMouse ? Qt.rgba(255, 105, 97, 0.25) : Qt.rgba(255, 105, 97, 0.14)
                border.width: 0

                Text {
                    id: headerDisconnectText
                    anchors.centerIn: parent
                    text: utilModule.vpnConnecting ? "Cancel" : "Disconnect"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: "#ff6961"
                }

                MouseArea {
                    id: headerDiscMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: utilModule.toggleVpn()
                }
            }
        }

        // ── 1. MAIN CONTROL CENTER VIEW (IRIS 1:1 REFINED & PACKED) ─────────────
        ColumnLayout {
            id: mainViewContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            spacing: 10
            visible: utilModule.activeSection === ""

            // UPPER SECTION (Rows 1 to 4):
            RowLayout {
                id: upperSection
                Layout.fillWidth: true
                Layout.preferredHeight: 206
                spacing: 10

                // LEFT STACK: Ethernet, Bluetooth, Hotspot & Caffeine, Night Light & DND
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 195
                    Layout.fillHeight: true
                    spacing: 10

                    // 1. Ethernet / Wi-Fi Plate
                    IrisActionPlate {
                        implicitHeight: 44
                        glyph: (utilModule.activeNetType === "eth") ? "lan" : (utilModule.wifiEnabled ? "wifi" : "wifi_off")
                        title: (utilModule.activeNetType === "eth") ? "Ethernet" : "Wi-Fi"
                        subtitle: {
                            if (utilModule.activeNetType === "eth") return "Connected";
                            if (!utilModule.wifiEnabled) return "Off";
                            if (utilModule.activeNetName !== "") {
                                return utilModule.activeNetSignal > 0 ? (utilModule.activeNetName + " • " + utilModule.activeNetSignal + "%") : utilModule.activeNetName;
                            }
                            return "Disconnected";
                        }
                        lit: (utilModule.activeNetType === "eth") || utilModule.wifiEnabled
                        tint: utilModule.colAccent
                        onIconClicked: utilModule.toggleWifi()
                        onClicked: root.switchMode("wifi", false)
                    }

                    // 2. Bluetooth Plate
                    IrisActionPlate {
                        implicitHeight: 44
                        glyph: utilModule.btEnabled ? "bluetooth" : "bluetooth_disabled"
                        title: "Bluetooth"
                        subtitle: {
                            if (!utilModule.btEnabled) return "Off";
                            if (utilModule.activeBtName !== "") {
                                return utilModule.activeBtBattery !== "" ? (utilModule.activeBtName + " • " + utilModule.activeBtBattery) : utilModule.activeBtName;
                            }
                            return "Disconnected";
                        }
                        lit: utilModule.btEnabled
                        tint: utilModule.colAccent
                        onIconClicked: utilModule.toggleBluetooth()
                        onClicked: root.switchMode("bluetooth", false)
                    }

                    // 3. Upper Action Buttons (Hotspot, Caffeine)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 10

                        // Hotspot
                        IrisGridTile {
                            glyph: "wifi_tethering"
                            label: "Hotspot"
                            lit: utilModule.hotspotActive
                            tint: "#2dd4bf"
                            onClicked: utilModule.toggleHotspot()
                        }

                        // Caffeine
                        IrisGridTile {
                            glyph: "coffee"
                            label: "Caffeine"
                            lit: utilModule.caffeineActive
                            tint: "#fbbf24"
                            onClicked: utilModule.toggleCaffeine()
                        }
                    }

                    // 4. Lower Action Buttons (Night Light, DND) - Aligned with Color & Timer
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 10

                        // Night Light
                        IrisGridTile {
                            glyph: "nightlight"
                            label: "Night Light"
                            lit: utilModule.nightLightActive
                            tint: "#f59e0b"
                            onClicked: utilModule.toggleNightLight()
                        }

                        // DND
                        IrisGridTile {
                            glyph: root.dndEnabled ? "do_not_disturb_on" : "do_not_disturb_off"
                            label: "DND"
                            lit: root.dndEnabled
                            tint: "#a855f7"
                            onClicked: root.dndEnabled = !root.dndEnabled
                        }
                    }
                }

                // RIGHT STACK: 3 Sliders (Volume, Brightness, Mic) + [Color & Pomodoro] (Square tiles)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 195
                    Layout.fillHeight: true
                    spacing: 10

                    // 3 Vertical Capsule Sliders side-by-side with 9.5px spacing (Volume, Brightness, Mic)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 152
                        spacing: 9.5

                        // 1. Volume Capsule Slider
                        IrisVerticalCapsuleSlider {
                            value: utilModule.audioVolume
                            icon: utilModule.audioMuted ? "volume_off" : (utilModule.audioVolume > 0.5 ? "volume_up" : (utilModule.audioVolume > 0 ? "volume_down" : "volume_mute"))
                            percentText: utilModule.audioMuted ? "Muted" : (Math.round(utilModule.audioVolume * 100) + "%")
                            muted: utilModule.audioMuted
                            onMoved: (val) => {
                                utilModule.isDraggingVolume = true;
                                utilModule.setVolume(val);
                            }
                            onIconClicked: utilModule.toggleMute()
                        }

                        // 2. Brightness Capsule Slider
                        IrisVerticalCapsuleSlider {
                            value: utilModule.displayBrightness
                            icon: "light_mode"
                            percentText: Math.round(utilModule.displayBrightness * 100) + "%"
                            muted: false
                            onMoved: (val) => {
                                utilModule.isDraggingBrightness = true;
                                utilModule.setBrightness(val);
                            }
                            onIconClicked: utilModule.setBrightness(utilModule.displayBrightness > 0.5 ? 0.2 : 0.8)
                        }

                        // 3. Microphone Capsule Slider (Last)
                        IrisVerticalCapsuleSlider {
                            value: utilModule.audioMicVolume
                            icon: utilModule.audioMicMuted ? "mic_off" : "mic"
                            percentText: utilModule.audioMicMuted ? "Muted" : (Math.round(utilModule.audioMicVolume * 100) + "%")
                            muted: utilModule.audioMicMuted
                            onMoved: (val) => {
                                utilModule.isDraggingMic = true;
                                utilModule.setMicVolume(val);
                            }
                            onIconClicked: utilModule.toggleMicMute()
                        }
                    }

                    // Directly Under Sliders: Color Picker & Pomodoro (Square tiles matching the grid)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 10

                        IrisGridTile {
                            glyph: "colorize"
                            label: "Color"
                            lit: false
                            tint: "#ec4899"
                            onClicked: utilModule.triggerColorPicker()
                        }

                        IrisGridTile {
                            glyph: "timer"
                            label: root.pomoRunning
                                ? (root.pomoPaused ? "Paused" : (Math.floor(root.pomoSecondsRemaining / 60) + ":" + ((root.pomoSecondsRemaining % 60) < 10 ? "0" : "") + (root.pomoSecondsRemaining % 60)))
                                : "Timer"
                            lit: root.pomoRunning
                            tint: "#f43f5e"
                            onClicked: utilModule.activeSection = "pomo"
                        }
                    }
                }
            }

            // LOWER SECTION (Bottom Row - Wide Plates: Audio Output & Screen Record)
            RowLayout {
                id: lowerSection
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 10

                // Audio Output (wide plate)
                IrisActionPlate {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 195
                    implicitHeight: 44
                    glyph: utilModule.audioMuted ? "volume_off" : (utilModule.defaultSink ? utilModule.getSinkIcon(utilModule.defaultSink.name, utilModule.defaultSink.desc) : "speaker")
                    title: "Audio Output"
                    subtitle: utilModule.defaultSink ? utilModule.cleanDeviceName(utilModule.defaultSink.name, utilModule.defaultSink.desc) : "Default Device"
                    lit: !utilModule.audioMuted
                    tint: utilModule.colAccent
                    onIconClicked: utilModule.toggleMute()
                    onClicked: {
                        utilModule.activeSection = "audio";
                        fetchAudioDevices.running = true;
                    }
                }

                // Screen Record (wide plate)
                IrisActionPlate {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 195
                    implicitHeight: 44
                    glyph: root.isScreenRecording ? "stop_circle" : "radio_button_checked"
                    title: "Screen Record"
                    subtitle: root.isScreenRecording ? "Recording" : "Ready"
                    lit: root.isScreenRecording
                    tint: root.isScreenRecording ? "#ff453a" : utilModule.colAccent
                    onIconClicked: {
                        if (root.isScreenRecording) {
                            root.stopRecording();
                        } else {
                            root.startRecording(false);
                        }
                    }
                    onClicked: root.switchMode("recorder", false)
                }
            }
        }

        // ── 2. SOUND DEVICES SUBVIEW ───────────────────────────────
        Item {
            id: audioSubviewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: utilModule.activeSection === "audio"
            clip: true

            Flickable {
                id: audioScroll
                anchors.fill: parent
                contentWidth: width
                contentHeight: audioContentCol.implicitHeight + 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        var maxY = Math.max(0, audioScroll.contentHeight - audioScroll.height);
                        audioScroll.contentY = Math.max(0, Math.min(maxY, audioScroll.contentY - event.angleDelta.y));
                    }
                }

                ColumnLayout {
                    id: audioContentCol
                    width: audioScroll.width
                    spacing: 8

                    Text {
                        text: "OUTPUT AUDIO SINKS"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: utilModule.colMuted
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: utilModule.audioSinks
                        delegate: Rectangle {
                            id: sinkItemRect
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            implicitHeight: 40
                            radius: 12
                            color: modelData.isDefault
                                ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.20)
                                : (sinkMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                            border.width: 0

                            scale: sinkMouse.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 12

                                MaterialSymbol {
                                    text: utilModule.getSinkIcon(modelData.name, modelData.desc)
                                    fill: modelData.isDefault ? 1 : 0
                                    iconSize: 18
                                    color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: utilModule.cleanDeviceName(modelData.name, modelData.desc)
                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                    font.weight: modelData.isDefault ? Font.DemiBold : Font.Normal
                                    color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    visible: modelData.isDefault
                                    text: "check_circle"
                                    fill: 1
                                    iconSize: 18
                                    color: utilModule.colAccent
                                }
                            }

                            MouseArea {
                                id: sinkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: utilModule.setDefaultSink(modelData.name)
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 6 }

                    Text {
                        text: "INPUT MICROPHONE SOURCES"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: utilModule.colSubtext
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: utilModule.audioSources
                        delegate: Rectangle {
                            id: sourceItemRect
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            implicitHeight: 40
                            radius: 12
                            color: modelData.isDefault
                                ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.20)
                                : (sourceMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                            border.width: 0

                            scale: sourceMouse.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 12

                                MaterialSymbol {
                                    text: "mic"
                                    fill: modelData.isDefault ? 1 : 0
                                    iconSize: 18
                                    color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: utilModule.cleanDeviceName(modelData.name, modelData.desc)
                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                    font.weight: modelData.isDefault ? Font.DemiBold : Font.Normal
                                    color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    visible: modelData.isDefault
                                    text: "check_circle"
                                    fill: 1
                                    iconSize: 18
                                    color: utilModule.colAccent
                                }
                            }

                            MouseArea {
                                id: sourceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: utilModule.setDefaultSource(modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // ── 3. VPN & PRIVACY PROVIDERS SUBVIEW ─────────────────────────
        Item {
            id: vpnSubviewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: utilModule.activeSection === "vpn"
            clip: true

            Flickable {
                id: vpnScroll
                anchors.fill: parent
                contentWidth: width
                contentHeight: vpnContentCol.implicitHeight + 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: (event) => {
                        var maxY = Math.max(0, vpnScroll.contentHeight - vpnScroll.height);
                        vpnScroll.contentY = Math.max(0, Math.min(maxY, vpnScroll.contentY - event.angleDelta.y));
                    }
                }

                ColumnLayout {
                    id: vpnContentCol
                    width: vpnScroll.width
                    spacing: 8

                    Repeater {
                        model: utilModule.vpnProviders
                        delegate: Rectangle {
                            id: vpnCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            implicitHeight: 48
                            radius: 14
                            color: (modelData.active || modelData.connecting)
                                ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, cardMouse.containsMouse ? 0.24 : 0.18)
                                : (cardMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                            border.width: 0

                            scale: cardMouse.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 12

                                // Provider Icon Disc
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: (modelData.active || modelData.connecting) ? utilModule.colAccent : (modelData.installed ? Qt.rgba(255, 255, 255, 0.085) : Qt.rgba(255, 255, 255, 0.04))
                                    border.width: 0

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: modelData.icon || "shield"
                                        fill: (modelData.active || modelData.connecting) ? 1 : 0
                                        iconSize: 17
                                        color: (modelData.active || modelData.connecting) ? "#101318" : (modelData.installed ? utilModule.colText : utilModule.colMuted)
                                    }
                                }

                                // Provider Info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: modelData.name
                                            font.family: "Noto Sans"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: (modelData.active || modelData.connecting) ? utilModule.colAccent : utilModule.colText
                                        }

                                        Rectangle {
                                            visible: modelData.is_default && !modelData.active && !modelData.connecting
                                            width: defText.implicitWidth + 8
                                            height: 16
                                            radius: 8
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                            border.width: 0

                                            Text {
                                                id: defText
                                                anchors.centerIn: parent
                                                text: "Default"
                                                font.family: "Noto Sans"
                                                font.pixelSize: 9
                                                font.weight: Font.Normal
                                                color: utilModule.colMuted
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.connecting ? "Connecting to network..." : (modelData.installed ? modelData.subtitle : "Not installed on system")
                                        font.family: "Noto Sans"
                                        font.pixelSize: 10
                                        color: (modelData.active || modelData.connecting) ? utilModule.colAccent : utilModule.colMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                // Status Indicator / Connect Button
                                Rectangle {
                                    width: statusLabel.implicitWidth + 14
                                    height: 26
                                    radius: 13
                                    color: (modelData.active || modelData.connecting) ? utilModule.colAccent : (modelData.installed ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                                    border.width: 0

                                    Text {
                                        id: statusLabel
                                        anchors.centerIn: parent
                                        text: modelData.connecting ? "Connecting..." : (modelData.active ? "Connected" : (modelData.installed ? "Connect" : "Install"))
                                        font.family: "Noto Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: (modelData.active || modelData.connecting) ? "#101318" : (modelData.installed ? utilModule.colText : utilModule.colMuted)
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                cursorShape: modelData.installed ? Qt.PointingHandCursor : Qt.ArrowCursor
                                hoverEnabled: true
                                enabled: modelData.installed
                                onClicked: {
                                    utilModule.toggleVpn(modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 4. FOCUS & POMODORO TIMER SUBVIEW ─────────────────────────
        Item {
            id: pomoSubviewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: utilModule.activeSection === "pomo"
            clip: true

            property int customMinutes: 25

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // 1. Big Timer Hero Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 136
                    radius: 18
                    color: utilModule.colCard
                    border.width: 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        // Mode Tag Pill
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            height: 22
                            width: pomoModeTagText.implicitWidth + 16
                            radius: 11
                            color: root.pomoRunning
                                ? (root.pomoPaused ? Qt.rgba(1, 1, 1, 0.1) : (root.pomoMode === "focus" ? Qt.alpha(Theme.accent, 0.2) : Qt.rgba(0.18, 0.82, 0.34, 0.2)))
                                : Qt.rgba(255, 255, 255, 0.08)

                            Text {
                                id: pomoModeTagText
                                anchors.centerIn: parent
                                text: root.pomoRunning
                                    ? (root.pomoPaused ? "PAUSED" : root.pomoTag.toUpperCase())
                                    : "READY TO FOCUS"
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.pomoRunning
                                    ? (root.pomoPaused ? utilModule.colMuted : (root.pomoMode === "focus" ? Theme.accent : "#30d158"))
                                    : utilModule.colMuted
                            }
                        }

                        // Big Time Digits
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.pomoRunning
                                ? root.formatPomoTime(root.pomoSecondsRemaining)
                                : root.formatPomoTime(pomoSubviewContainer.customMinutes * 60)
                            font.family: "Readex Pro"
                            font.pixelSize: 42
                            font.weight: Font.Bold
                            color: utilModule.colText
                            renderType: Text.NativeRendering
                        }

                        // DND Status Indicator
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5
                            visible: root.pomoRunning && root.pomoMode === "focus"

                            MaterialSymbol {
                                text: "notifications_off"
                                iconSize: 13
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Do Not Disturb Active"
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Progress bar when running
                        Rectangle {
                            Layout.preferredWidth: 240
                            Layout.preferredHeight: 4
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            radius: 2
                            color: Qt.rgba(255, 255, 255, 0.08)
                            visible: root.pomoRunning

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: {
                                    if (!root.pomoRunning || root.pomoTotalSeconds <= 0) return 0;
                                    var pct = 1.0 - (root.pomoSecondsRemaining / root.pomoTotalSeconds);
                                    return Math.max(0, Math.min(parent.width, parent.width * pct));
                                }
                                radius: 2
                                color: root.pomoMode === "focus" ? Theme.accent : "#30d158"
                            }
                        }
                    }
                }

                // 2. Preset Chips Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "25m Focus", mins: 25, mode: "focus", tag: "Focus Sprint", icon: "timer" },
                            { label: "50m Deep", mins: 50, mode: "focus", tag: "Deep Work", icon: "bolt" },
                            { label: "5m Break", mins: 5, mode: "short_break", tag: "Short Break", icon: "coffee" },
                            { label: "15m Rest", mins: 15, mode: "long_break", tag: "Long Break", icon: "self_improvement" }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 12
                            color: (root.pomoRunning && root.pomoTotalSeconds === modelData.mins * 60)
                                ? Qt.alpha(Theme.accent, 0.20)
                                : (chipMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                            border.width: 0
                            scale: chipMouse.pressed ? 0.96 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 15
                                    color: (root.pomoRunning && root.pomoTotalSeconds === modelData.mins * 60) ? Theme.accent : utilModule.colText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.label
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: (root.pomoRunning && root.pomoTotalSeconds === modelData.mins * 60) ? Theme.accent : utilModule.colText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.startPomodoro(modelData.mins, modelData.mode, modelData.tag);
                                }
                            }
                        }
                    }
                }

                // 3. Actions Row (Pause/Resume/Stop or Stepper/Start)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // When Running: Pause/Resume + Stop
                    Rectangle {
                        visible: root.pomoRunning
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 14
                        color: root.pomoPaused ? Qt.alpha(Theme.accent, 0.22) : utilModule.colCard
                        border.width: 0
                        scale: pauseMouse.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: root.pomoPaused ? "play_arrow" : "pause"
                                iconSize: 18
                                color: root.pomoPaused ? Theme.accent : utilModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.pomoPaused ? "Resume" : "Pause"
                                font.family: "Noto Sans"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: root.pomoPaused ? Theme.accent : utilModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: pauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePomodoroPause()
                        }
                    }

                    Rectangle {
                        visible: root.pomoRunning
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 40
                        radius: 14
                        color: add5Mouse.containsMouse ? utilModule.colCardHover : utilModule.colCard
                        scale: add5Mouse.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }

                        Text {
                            anchors.centerIn: parent
                            text: "+5 min"
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: utilModule.colText
                        }

                        MouseArea {
                            id: add5Mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pomoSecondsRemaining += 300;
                                root.pomoTotalSeconds += 300;
                            }
                        }
                    }

                    Rectangle {
                        visible: root.pomoRunning
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 14
                        color: stopMouse.containsMouse ? Qt.rgba(255, 69, 58, 0.25) : Qt.rgba(255, 69, 58, 0.15)
                        scale: stopMouse.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: "stop"
                                iconSize: 18
                                color: "#ff453a"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Reset"
                                font.family: "Noto Sans"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#ff453a"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: stopMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stopPomodoro()
                        }
                    }

                    // When Idle: Stepper [- / +] + Big Start Button
                    Rectangle {
                        visible: !root.pomoRunning
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        radius: 14
                        color: utilModule.colCard

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 0

                            IrisIconButton {
                                width: 28; height: 28; buttonSize: 28; buttonRadius: 14
                                flat: true
                                icon: "remove"
                                iconSize: 16
                                onClicked: {
                                    pomoSubviewContainer.customMinutes = Math.max(1, pomoSubviewContainer.customMinutes - 5);
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: pomoSubviewContainer.customMinutes + "m"
                                font.family: "Noto Sans"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: utilModule.colText
                            }

                            IrisIconButton {
                                width: 28; height: 28; buttonSize: 28; buttonRadius: 14
                                flat: true
                                icon: "add"
                                iconSize: 16
                                onClicked: {
                                    pomoSubviewContainer.customMinutes = Math.min(120, pomoSubviewContainer.customMinutes + 5);
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: !root.pomoRunning
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 14
                        color: startCustomMouse.containsMouse ? Qt.lighter(utilModule.colAccent, 1.1) : utilModule.colAccent
                        scale: startCustomMouse.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialSymbol {
                                text: "play_arrow"
                                iconSize: 18
                                color: "#101318"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Start Focus (" + pomoSubviewContainer.customMinutes + "m)"
                                font.family: "Noto Sans"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#101318"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: startCustomMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.startPomodoro(pomoSubviewContainer.customMinutes, "focus", "Custom Focus");
                            }
                        }
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
