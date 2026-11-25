import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import "../../"
import "../"
import "./cards"
import "WidgetCatalog.js" as Catalog

Item {
    id: root

    required property string tileId
    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property var notchRoot: null
    property bool useShellManagedSurface: true

    readonly property var catalogEntry: Catalog.definitionFor(root.tileId)
    readonly property bool preserveDefaultSurface: root.catalogEntry !== null
        && root.catalogEntry.preserveDefaultSurface === true
    readonly property bool shellManagedSurface: root.useShellManagedSurface && !root.preserveDefaultSurface
    readonly property bool hasRoundedRectFrame: [
        "cpu", "gpu", "memoryUsed", "wifi", "network", "storage", "storageCapacity", "calendar"
    ].indexOf(root.tileId) >= 0

    // Telemetry lookups
    readonly property var selectedNetItem: {
        const list = WidgetTelemetry.netInterfaces || [];
        const pref = WidgetStore.preferredNetInterface || "";
        if (pref === "__all__") {
            let dl = 0, ul = 0;
            for (let i = 0; i < list.length; i++) {
                dl += Number(list[i].downloadBps) || 0;
                ul += Number(list[i].uploadBps) || 0;
            }
            return { name: "__all__", downloadBps: dl, uploadBps: ul };
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === pref) return list[i];
        }
        const def = WidgetTelemetry.defaultInterface || "";
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === def) return list[i];
        }
        return list.length > 0 ? list[0] : { name: "", downloadBps: 0, uploadBps: 0 };
    }

    readonly property var netDownloadHistory: {
        const name = selectedNetItem.name || "";
        if (name === "__all__") {
            return (typeof Sys !== "undefined" && Array.isArray(Sys.downHistory)) ? Sys.downHistory : [];
        }
        return (WidgetTelemetry.downloadHistories && WidgetTelemetry.downloadHistories[name]) || [];
    }

    readonly property var netUploadHistory: {
        const name = selectedNetItem.name || "";
        if (name === "__all__") {
            return (typeof Sys !== "undefined" && Array.isArray(Sys.upHistory)) ? Sys.upHistory : [];
        }
        return (WidgetTelemetry.uploadHistories && WidgetTelemetry.uploadHistories[name]) || [];
    }

    readonly property var selectedDiskItem: {
        const list = WidgetTelemetry.disks || [];
        const pref = WidgetStore.preferredDiskDevice || "";
        for (let i = 0; i < list.length; i++) {
            if (list[i].device === pref) return list[i];
        }
        return list.length > 0 ? list[0] : { device: "", readBps: 0, writeBps: 0 };
    }

    readonly property var diskReadHistory: {
        const dev = selectedDiskItem.device || "";
        return (WidgetTelemetry.readHistories && WidgetTelemetry.readHistories[dev]) || [];
    }

    readonly property var diskWriteHistory: {
        const dev = selectedDiskItem.device || "";
        return (WidgetTelemetry.writeHistories && WidgetTelemetry.writeHistories[dev]) || [];
    }

    function cycleNetInterface() {
        const names = (WidgetTelemetry.netInterfaces || []).map(x => x.name);
        names.push("__all__");
        if (names.length === 0) return;
        const cur = selectedNetItem.name || names[0];
        const idx = names.indexOf(cur);
        const next = names[(idx + 1) % names.length];
        WidgetStore.setPreferredNetInterface(next);
    }

    function cycleDiskDevice() {
        const devs = (WidgetTelemetry.disks || []).map(x => x.device);
        if (devs.length <= 1) return;
        const cur = selectedDiskItem.device || devs[0];
        const idx = devs.indexOf(cur);
        const next = devs[(idx + 1) % devs.length];
        WidgetStore.setPreferredDiskDevice(next);
    }

    function cpuDetailText() {
        if (typeof Sys === "undefined") return "Processor";
        const cores = (Sys.info && Sys.info.cores) ? (Sys.info.cores + " threads") : "";
        const load = (Sys.load1 >= 0) ? ("Load " + Sys.load1.toFixed(2)) : "";
        if (cores && load) return cores + " · " + load;
        return cores || load || "Overall utilization";
    }

    function cpuSupportingText() {
        if (typeof Sys === "undefined") return "";
        const freq = Sys.cpuMhz > 0 ? (Math.round(Sys.cpuMhz) + " MHz") : "";
        const model = (Sys.info && Sys.info.cpuModel)
            ? String(Sys.info.cpuModel).split(/\s+/).slice(0, 3).join(" ")
            : "";
        if (freq && model) return freq + " · " + model;
        return freq || model;
    }

    function gpuSupportingText() {
        if (!WidgetTelemetry.hasGpu) return "Idle or integrated";
        if (WidgetTelemetry.gpuVramTotalMb > 0) {
            return "VRAM " + Math.round(WidgetTelemetry.gpuVramUsedMb) + " / " + Math.round(WidgetTelemetry.gpuVramTotalMb) + " MB";
        }
        return WidgetTelemetry.gpuName || "Active GPU";
    }

    Loader {
        id: cardLoader
        anchors.fill: parent
        active: root.tileId !== ""
        sourceComponent: {
            switch (root.tileId) {
                case "time": return clockComp;
                case "battery": return batteryComp;
                case "cpu": return cpuComp;
                case "gpu": return gpuComp;
                case "memoryUsed": return memoryComp;
                case "wifi": return wifiComp;
                case "network": return networkComp;
                case "storage": return storageIoComp;
                case "storageCapacity": return storageCapComp;
                case "calendar": return calendarComp;
                case "weather": return weatherComp;
                case "music": return musicComp;
                default: return null;
            }
        }
    }

    TapHandler {
        enabled: root.interactive && (root.tileId === "wifi" || root.tileId === "calendar" || root.tileId === "weather")
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (!root.notchRoot) return;
            if (root.tileId === "wifi" && typeof root.notchRoot.openUtility === "function") {
                WidgetStore.closeSidebar();
                root.notchRoot.openUtility("wifi", false);
            } else if (root.tileId === "calendar" && typeof root.notchRoot.openClockTab === "function") {
                WidgetStore.closeSidebar();
                root.notchRoot.openClockTab("calendar");
            } else if (root.tileId === "weather" && typeof root.notchRoot.openClockTab === "function") {
                WidgetStore.closeSidebar();
                root.notchRoot.openClockTab("today");
            }
        }
    }

    Component {
        id: clockComp
        ClockCard {
            active: root.active
        }
    }

    Component {
        id: batteryComp
        BatteryTankCard {}
    }

    Component {
        id: cpuComp
        ExpressiveMetricTileCard {
            label: "CPU"
            iconName: "memory"
            chartActive: root.active
            usage: (typeof Sys !== "undefined") ? Sys.cpu : -1
            valueText: (typeof Sys !== "undefined") ? (Math.round(Sys.cpu * 100) + "%") : "—"
            trendValues: (typeof Sys !== "undefined" && Array.isArray(Sys.cpuHistory)) ? Sys.cpuHistory : []
            temperatureText: (typeof Sys !== "undefined" && Sys.temp > 0) ? (Math.round(Sys.temp) + "°") : ""
            detailText: root.cpuDetailText()
            supportingText: root.cpuSupportingText()
            containerColor: Theme.m3.primary_container ?? Theme.colors.card_bg
            foregroundColor: Theme.m3.on_primary_container ?? Theme.colors.text_primary
            accentColor: Theme.m3.primary ?? Theme.accent
            accentForegroundColor: Theme.m3.on_primary ?? "#101014"
        }
    }

    Component {
        id: gpuComp
        ExpressiveMetricTileCard {
            label: "GPU"
            iconName: "developer_board"
            shapeOverride: "gem"
            chartActive: root.active
            usage: (WidgetTelemetry.hasGpu && WidgetTelemetry.gpuPercent >= 0)
                ? (WidgetTelemetry.gpuPercent / 100.0) : -1
            valueText: (WidgetTelemetry.hasGpu && WidgetTelemetry.gpuPercent >= 0)
                ? (Math.round(WidgetTelemetry.gpuPercent) + "%") : "Idle"
            trendValues: WidgetTelemetry.gpuHistory || []
            temperatureText: (WidgetTelemetry.hasGpu && WidgetTelemetry.gpuTemp > 0)
                ? (Math.round(WidgetTelemetry.gpuTemp) + "°") : ""
            detailText: WidgetTelemetry.hasGpu ? (WidgetTelemetry.gpuName || "Graphics") : "Integrated"
            supportingText: root.gpuSupportingText()
            containerColor: Theme.m3.secondary_container ?? Theme.colors.card_bg
            foregroundColor: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
            accentColor: Theme.m3.secondary ?? Theme.colors.text_secondary
            accentForegroundColor: Theme.m3.on_secondary ?? "#030a16"
        }
    }

    Component {
        id: memoryComp
        LiquidWaveCard {
            active: root.active
            iconName: "memory_alt"
            valueAvailable: (typeof Sys !== "undefined") && Sys.ramTotalGb > 0
            level: valueAvailable ? Sys.ram : 0
            valueText: valueAvailable ? (Math.round(Sys.ram * 100) + "%") : "—"
            supportingText: valueAvailable
                ? (Sys.ramUsedGb.toFixed(1) + " / " + Sys.ramTotalGb.toFixed(0) + " GB")
                : "Memory"
            shapeColor: Theme.m3.primary_container ?? Theme.colors.card_bg
            liquidColor: Theme.alpha(Theme.m3.primary ?? Theme.accent, 0.50)
            contentColor: Theme.m3.on_primary_container ?? Theme.colors.text_primary
        }
    }

    Component {
        id: wifiComp
        LiquidWaveCard {
            active: root.active
            iconName: WidgetTelemetry.wifiConnected ? "wifi" : (WidgetTelemetry.wifiEnabled ? "wifi_find" : "wifi_off")
            valueAvailable: WidgetTelemetry.wifiEnabled && WidgetTelemetry.wifiConnected && WidgetTelemetry.wifiSignal >= 0
            level: valueAvailable ? (WidgetTelemetry.wifiSignal / 100.0) : 0
            valueText: valueAvailable
                ? (Math.round(WidgetTelemetry.wifiSignal) + "%")
                : (WidgetTelemetry.wifiEnabled ? "No link" : "Off")
            supportingText: (WidgetTelemetry.wifiConnected && WidgetTelemetry.wifiSsid)
                ? WidgetTelemetry.wifiSsid
                : (WidgetTelemetry.wifiEnabled ? "Wi-Fi ready" : "Disabled")
            shapeColor: Theme.m3.tertiary_container ?? Theme.colors.hover_bg
            liquidColor: Theme.alpha(Theme.m3.tertiary ?? Theme.accent, 0.48)
            contentColor: Theme.m3.on_tertiary_container ?? Theme.colors.text_primary
        }
    }

    Component {
        id: networkComp
        DualChartWideCard {
            active: root.active
            title: "Network"
            selectorIcon: {
                const n = root.selectedNetItem.name || "";
                if (n === "__all__") return "swap_vert";
                if (n.indexOf("wl") === 0) return "wifi";
                return "lan";
            }
            selectorLabel: root.selectedNetItem.name === "__all__"
                ? "All"
                : (root.selectedNetItem.name || "No link")
            metric1Icon: "download"
            metric1Value: WidgetTelemetry.formatRate(root.selectedNetItem.downloadBps)
            metric2Icon: "upload"
            metric2Value: WidgetTelemetry.formatRate(root.selectedNetItem.uploadBps)
            primaryValues: root.netDownloadHistory
            secondaryValues: root.netUploadHistory
            leftColor: Theme.m3.primary ?? Theme.accent
            leftForeground: Theme.m3.on_primary ?? "#101014"
            rightColor: Theme.m3.primary_container ?? Theme.colors.card_bg
            rightForeground: Theme.m3.on_primary_container ?? Theme.colors.text_primary
            metric1Color: Theme.m3.primary ?? Theme.accent
            metric2Color: Theme.m3.secondary ?? Theme.colors.text_secondary
            onSelectorClicked: root.cycleNetInterface()
        }
    }

    Component {
        id: storageIoComp
        DualChartWideCard {
            active: root.active
            title: "Disk I/O"
            selectorIcon: "hard_drive"
            selectorLabel: root.selectedDiskItem.device || "No disk"
            metric1Icon: "south_west"
            metric1Value: WidgetTelemetry.formatRate(root.selectedDiskItem.readBps)
            metric2Icon: "north_east"
            metric2Value: WidgetTelemetry.formatRate(root.selectedDiskItem.writeBps)
            primaryValues: root.diskReadHistory
            secondaryValues: root.diskWriteHistory
            leftColor: Theme.m3.tertiary ?? Theme.accent
            leftForeground: Theme.m3.on_tertiary ?? "#101014"
            rightColor: Theme.m3.tertiary_container ?? Theme.colors.hover_bg
            rightForeground: Theme.m3.on_tertiary_container ?? Theme.colors.text_primary
            metric1Color: Theme.m3.tertiary ?? Theme.accent
            metric2Color: Theme.m3.secondary ?? Theme.colors.text_secondary
            onSelectorClicked: root.cycleDiskDevice()
        }
    }

    Component {
        id: storageCapComp
        LiquidWaveCard {
            active: root.active
            iconName: "data_usage"
            valueAvailable: (typeof Sys !== "undefined") && Sys.diskTotalGb > 0
            level: valueAvailable ? Sys.disk : 0
            valueText: valueAvailable ? (Math.round(Sys.disk * 100) + "%") : "—"
            supportingText: valueAvailable
                ? (Sys.diskUsedGb.toFixed(0) + " / " + Sys.diskTotalGb.toFixed(0) + " GB")
                : "Root /"
            shapeColor: Theme.m3.secondary_container ?? Theme.colors.card_bg
            liquidColor: Theme.alpha(Theme.m3.secondary ?? Theme.accent, 0.50)
            contentColor: Theme.m3.on_secondary_container ?? Theme.colors.text_primary
        }
    }

    Component {
        id: calendarComp
        CalendarCard {
            active: root.active
        }
    }

    Component {
        id: weatherComp
        WeatherPillCard {
            active: root.active
        }
    }

    Component {
        id: musicComp
        MusicLyricsCard {
            active: root.active
            onDesktop: root.onDesktop
            notchRoot: root.notchRoot
        }
    }
}
