pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool locked: false
    property bool editing: false
    property bool peeking: false
    property string selection: ""
    property string activeGroup: "Layouts"
    property string desktopWallpaper: ""
    property string avatarPath: ""
    property int revision: 0

    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/iris_lock.json"

    readonly property var zones: ["top", "center", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight", "left", "right"]
    readonly property var groups: ["Layouts", "Scene", "Type", "Clock", "At a glance", "Now playing", "Activity", "Sign in", "Status"]
    readonly property var blockDefs: [
        { id: "clock", label: "Clock", description: "The time, with the date over it." },
        { id: "glance", label: "At a glance", description: "Weather, next reminder and battery as glass chips." },
        { id: "media", label: "Now playing", description: "Cover art, track info and transport controls." },
        { id: "activity", label: "Activity", description: "Recording or running timer countdown plate." },
        { id: "session", label: "Sign in", description: "Your avatar, name and password capsule." },
        { id: "status", label: "Status", description: "Keyboard layout, network and battery." }
    ]
    readonly property var blockIds: ["clock", "glance", "media", "activity", "session", "status"]
    readonly property var groupByBlock: ({
        clock: "Clock",
        glance: "At a glance",
        media: "Now playing",
        activity: "Activity",
        session: "Sign in",
        status: "Status"
    })

    readonly property var presets: [
        {
            id: "iris",
            label: "iRiS",
            description: "The clock and the day up top, the player and sign-in below.",
            type: { clockSize: 112, clockWeight: 700 },
            blocks: {
                clock: { enable: true, zone: "top", style: "stack", date: true },
                glance: { enable: true, zone: "top" },
                media: { enable: true, zone: "bottom", style: "card" },
                activity: { enable: true, zone: "top" },
                session: { enable: true, zone: "bottom" },
                status: { enable: false, zone: "topRight" }
            }
        },
        {
            id: "centered",
            label: "Centered",
            description: "Everything stacked in the middle, status in the corner.",
            type: { clockSize: 128, clockWeight: 700 },
            blocks: {
                clock: { enable: true, zone: "center", style: "stack", date: true },
                glance: { enable: true, zone: "center" },
                media: { enable: true, zone: "center", style: "card" },
                activity: { enable: true, zone: "topLeft" },
                session: { enable: true, zone: "center" },
                status: { enable: true, zone: "topRight" }
            }
        },
        {
            id: "corner",
            label: "Corner",
            description: "A big clock in the bottom corner, sign-in across from it.",
            type: { clockSize: 144, clockWeight: 800 },
            blocks: {
                clock: { enable: true, zone: "bottomLeft", style: "stack", date: true },
                glance: { enable: true, zone: "bottomLeft" },
                media: { enable: true, zone: "bottomRight", style: "card" },
                activity: { enable: true, zone: "topLeft" },
                session: { enable: true, zone: "bottomRight" },
                status: { enable: true, zone: "topRight" }
            }
        },
        {
            id: "bill",
            label: "Bill",
            description: "Oversized clock at top-left, sign-in top-right, chips below.",
            type: { clockSize: 168, clockWeight: 800 },
            blocks: {
                clock: { enable: true, zone: "topLeft", style: "stack", date: true },
                glance: { enable: true, zone: "bottom" },
                media: { enable: true, zone: "bottomRight", style: "bare" },
                activity: { enable: true, zone: "top" },
                session: { enable: true, zone: "topRight" },
                status: { enable: true, zone: "bottomLeft" }
            }
        },
        {
            id: "minimal",
            label: "Minimal",
            description: "A large light clock and sign-in. Nothing else asks for attention.",
            type: { clockSize: 168, clockWeight: 300 },
            blocks: {
                clock: { enable: true, zone: "center", style: "inline", date: true },
                glance: { enable: false, zone: "center" },
                media: { enable: false, zone: "top", style: "bare" },
                activity: { enable: true, zone: "top" },
                session: { enable: true, zone: "bottom" },
                status: { enable: false, zone: "topRight" }
            }
        }
    ]

    function defaultData() {
        return {
            preset: "iris",
            material: "glass",
            enableAnimation: true,
            scene: {
                source: "desktop",
                path: "",
                fit: "cover",
                blur: 88,
                dim: 8,
                saturation: 18,
                scrim: "gradient",
                scrimStrength: 100,
                vignette: 26,
                motion: "none",
                driftTime: 40
            },
            type: {
                clockFont: "numbers",
                clockSize: 112,
                clockWeight: 700,
                clockTracking: -2,
                clockFormat: "auto",
                dateFormat: "long",
                seconds: false,
                accent: "plain",
                scale: 100
            },
            blocks: {
                clock: { enable: true, zone: "top", fx: 0.5, fy: 0.15, scale: 100, style: "stack", date: true },
                glance: { enable: true, zone: "top", fx: 0.5, fy: 0.28, scale: 100, weather: true, events: true, battery: true },
                media: { enable: true, zone: "bottom", fx: 0.5, fy: 0.65, scale: 100, style: "card" },
                activity: { enable: true, zone: "top", fx: 0.5, fy: 0.35, scale: 100 },
                session: { enable: true, zone: "bottom", fx: 0.5, fy: 0.85, scale: 100, avatar: true, name: true, hint: true, width: 260 },
                status: { enable: false, zone: "topRight", fx: 0.85, fy: 0.08, scale: 100, keyboard: true, network: true, battery: true }
            }
        };
    }

    property var data: defaultData()

    readonly property var scene: root.data.scene ?? ({})
    readonly property var typeOptions: root.data.type ?? ({})
    readonly property string material: String(root.data.material ?? "glass")
    readonly property string presetId: String(root.data.preset ?? "iris")

    readonly property real typeScale: Math.max(0.6, Math.min(1.6, Number(typeOptions.scale ?? 100) / 100))
    readonly property string clockFamily: {
        const chosen = String(typeOptions.clockFont ?? "numbers");
        if (chosen === "mono") return "JetBrainsMono Nerd Font";
        return "Google Sans Flex";
    }

    function save(): void {
        root.revision++;
        configFile.setText(JSON.stringify(root.data, null, 2));
    }

    function clone(obj) {
        return JSON.parse(JSON.stringify(obj));
    }

    function updateScene(patch): void {
        const next = root.clone(root.data);
        next.scene = Object.assign(next.scene || {}, patch);
        root.data = next;
        root.save();
    }

    function updateType(patch): void {
        const next = root.clone(root.data);
        next.type = Object.assign(next.type || {}, patch);
        root.data = next;
        root.save();
    }

    function updateRoot(patch): void {
        const next = root.clone(root.data);
        for (const k of Object.keys(patch)) next[k] = patch[k];
        root.data = next;
        root.save();
    }

    function entry(id: string): var {
        return root.data?.blocks?.[id] ?? ({});
    }

    function enabled(id: string): bool {
        return Boolean(root.entry(id)?.enable ?? false);
    }

    function zoneOf(id: string): string {
        return String(root.entry(id)?.zone ?? "top");
    }

    function scaleOf(id: string): real {
        return Math.max(0.5, Math.min(2.0, Number(root.entry(id)?.scale ?? 100) / 100));
    }

    function blockOf(id: string): var {
        return root.blockDefs.find(b => b.id === id) ?? null;
    }

    function labelOf(id: string): string {
        return root.blockOf(id)?.label ?? id;
    }

    function groupOf(id: string): string {
        return root.groupByBlock[id] ?? "Scene";
    }

    function blockForGroup(group: string): string {
        return root.blockIds.find(id => root.groupByBlock[id] === group) ?? "";
    }

    function writeBlock(id: string, values: var): void {
        const next = root.clone(root.data);
        next.preset = "custom";
        if (!next.blocks) next.blocks = ({});
        next.blocks[id] = Object.assign(next.blocks[id] || {}, values);
        root.data = next;
        root.save();
    }

    function toggle(id: string): void {
        root.writeBlock(id, { enable: !root.enabled(id) });
    }

    function place(id: string, zone: string, fx: real, fy: real): void {
        root.writeBlock(id, {
            zone: zone,
            fx: Math.round(fx * 10000) / 10000,
            fy: Math.round(fy * 10000) / 10000
        });
    }

    function nudge(id: string, dx: real, dy: real): void {
        const e = root.entry(id);
        const z = root.zoneOf(id);
        const fx = root.zones.includes(z) ? 0.5 : Number(e.fx ?? 0.5);
        const fy = root.zones.includes(z) ? 0.5 : Number(e.fy ?? 0.5);
        root.place(id, "free", Math.max(0, Math.min(1, fx + dx)), Math.max(0, Math.min(1, fy + dy)));
    }

    function applyPreset(id: string): bool {
        const preset = root.presets.find(p => p.id === id);
        if (!preset) return false;
        const next = root.clone(root.data);
        next.preset = preset.id;
        next.type = Object.assign(next.type || {}, preset.type);
        for (const blk of Object.keys(preset.blocks)) {
            next.blocks[blk] = Object.assign(next.blocks[blk] || {}, preset.blocks[blk]);
        }
        root.data = next;
        root.save();
        return true;
    }

    function shown(zone: string, includeOff: bool): var {
        return root.blockIds.filter(id => (includeOff || root.enabled(id)) && root.zoneOf(id) === zone);
    }

    function loose(includeOff: bool): var {
        return root.blockIds.filter(id => (includeOff || root.enabled(id)) && !root.zones.includes(root.zoneOf(id)));
    }

    function zoneAnchor(zone: string, width: real, height: real, margin: real): var {
        const top = zone.startsWith("top");
        const bottom = zone.startsWith("bottom");
        const x = zone === "left" || zone.endsWith("Left") ? margin
            : zone === "right" || zone.endsWith("Right") ? width - margin : width / 2;
        const y = top ? Math.round(height * 0.09) : bottom ? Math.round(height * 0.89) : height / 2;
        return {
            x: x,
            y: y,
            up: bottom,
            align: zone === "left" || zone.endsWith("Left") ? Qt.AlignLeft
                : zone === "right" || zone.endsWith("Right") ? Qt.AlignRight : Qt.AlignHCenter
        };
    }

    function refreshEnvironment(): void {
        if (!wallProc.running) wallProc.running = true;
        if (!avatarProc.running) avatarProc.running = true;
    }

    Component.onCompleted: {
        refreshEnvironment();
    }

    FileView {
        id: configFile
        path: root.configPath
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(configFile.text());
                if (parsed && typeof parsed === "object") {
                    const def = root.defaultData();
                    def.preset = parsed.preset ?? def.preset;
                    def.material = parsed.material ?? def.material;
                    def.enableAnimation = parsed.enableAnimation ?? def.enableAnimation;
                    if (parsed.scene) def.scene = Object.assign(def.scene, parsed.scene);
                    if (parsed.type) def.type = Object.assign(def.type, parsed.type);
                    if (parsed.blocks) {
                        for (const k of Object.keys(def.blocks)) {
                            if (parsed.blocks[k]) def.blocks[k] = Object.assign(def.blocks[k], parsed.blocks[k]);
                        }
                    }
                    root.data = def;
                    root.revision++;
                }
            } catch (_) {}
        }
        onLoadFailed: {
            Qt.callLater(() => root.save());
        }
    }

    Process {
        id: wallProc
        running: false
        command: ["sh", "-c", "awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p.length > 0) root.desktopWallpaper = p;
            }
        }
    }

    Process {
        id: avatarProc
        running: false
        command: ["sh", "-c", "for p in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -f \"$p\" ] && { echo \"$p\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.avatarPath = text.trim();
            }
        }
    }
}
