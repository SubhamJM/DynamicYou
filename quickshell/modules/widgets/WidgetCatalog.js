.pragma library

var baseCellWidth = 152;
var baseCellHeight = 160;
var cellGap = 8;
var canvasWidth = 472; // 3 * 152 + 2 * 8
var cardGridStep = 8;
var cardGridGuideStep = 24;

var sourceMeta = [
    { id: "all",       label: "All",            icon: "apps" },
    { id: "resources", label: "Resources",      icon: "monitoring" },
    { id: "time",      label: "Time & Weather", icon: "schedule" },
    { id: "media",     label: "Media",          icon: "music_note" },
    { id: "system",    label: "System",         icon: "sensors" },
    { id: "personal",  label: "Personal",       icon: "person" }
];

var cardDefinitions = [
    {
        id: "time",
        name: "Clock",
        source: "time",
        icon: "schedule",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "battery",
        name: "Battery",
        source: "system",
        icon: "battery_full",
        columnSpan: 1,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "cpu",
        name: "CPU",
        source: "resources",
        icon: "memory",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: ["cpu"],
        preserveDefaultSurface: true
    },
    {
        id: "gpu",
        name: "GPU",
        source: "resources",
        icon: "developer_board",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: ["gpu"],
        preserveDefaultSurface: true
    },
    {
        id: "memoryUsed",
        name: "Memory",
        source: "resources",
        icon: "memory_alt",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["memory"],
        preserveDefaultSurface: true
    },
    {
        id: "wifi",
        name: "Wi-Fi",
        source: "system",
        icon: "wifi",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "network",
        name: "Network Traffic",
        source: "system",
        icon: "swap_vert",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["network"]
    },
    {
        id: "storage",
        name: "Disk I/O",
        source: "resources",
        icon: "hard_drive",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["disk"]
    },
    {
        id: "storageCapacity",
        name: "Disk Usage",
        source: "resources",
        icon: "data_usage",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["disk"],
        preserveDefaultSurface: true
    },
    {
        id: "calendar",
        name: "Calendar",
        source: "time",
        icon: "calendar_month",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: []
    },
    {
        id: "weather",
        name: "Weather Card",
        source: "time",
        icon: "cloud",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "1x3", "2x3"],
        defaultOptions: { sizeMode: "1x3", styleMode: "material", unitMode: "auto" }
    },
    {
        id: "music",
        name: "Music & Lyrics",
        source: "media",
        icon: "music_note",
        columnSpan: 3,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        defaultOptions: { wordByWord: true, dimPaused: true, textScale: "md", tagMode: "always" }
    },
    {
        id: "media",
        name: "Media Deck",
        source: "media",
        icon: "play_circle",
        columnSpan: 3,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        defaultOptions: { showDuration: true, showArt: true, showBadge: true }
    },
    {
        id: "bgVisualiser",
        name: "Audio Visualiser",
        source: "media",
        icon: "graphic_eq",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        defaultOptions: {
            visStyle: "wave_outlined",
            colorMode: "inverse",
            barCount: 60,
            gain: 0.55,
            rounding: 6,
            spacing: 4,
            heightScale: 0.42,
            edgeInset: 0,
            visOpacity: 0.70,
            fps: 45,
            alwaysVisible: false
        }
    },
    {
        id: "resources",
        name: "Resources Deck",
        source: "resources",
        icon: "monitor_heart",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["cpu", "gpu", "memory", "disk"],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x3", "3x1", "2x2", "2x3"],
        defaultOptions: { sizeMode: "1x3", styleMode: "material", fillMode: "wave", showBattery: false }
    },
    {
        id: "usercard",
        name: "User Card",
        source: "personal",
        icon: "person",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "2x2", "2x3"],
        defaultOptions: { sizeMode: "2x2", styleMode: "material", customAvatar: "", customBanner: "" }
    },
    {
        id: "image",
        name: "Polaroid Frame",
        source: "personal",
        icon: "image",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        defaultOptions: { customPath: "", fitMode: "fill", zoom: 1.0, frameStyle: "polaroid", roundness: 12, opacityLevel: 1.0, showBorder: true, showCaption: true, tilted: true }
    },
    {
        id: "end4Weather",
        name: "Weather Pill",
        source: "time",
        icon: "partly_cloudy_day",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "1x3", "2x2", "2x3"],
        defaultOptions: { sizeMode: "1x3", unitMode: "auto", showShadow: true }
    },
    {
        id: "end4Media",
        name: "Media Pill",
        source: "media",
        icon: "album",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "1x3", "2x2", "2x3"],
        defaultOptions: { sizeMode: "1x3", showLyrics: false, showControls: true, showTitles: true, showShadow: true }
    },
    {
        id: "end4Resources",
        name: "Stat Trio",
        source: "resources",
        icon: "speed",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["cpu", "memory"],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x3", "3x1"],
        defaultOptions: { sizeMode: "1x3", thirdMetric: "auto", showShadow: true }
    },
    {
        id: "end4User",
        name: "User Hero",
        source: "personal",
        icon: "account_circle",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "2x2", "2x3"],
        defaultOptions: { sizeMode: "2x2", showQuip: true, showUptime: true, showActions: true, showShadow: true, customAvatar: "", customBanner: "" }
    },
    {
        id: "end4Image",
        name: "Shaped Photo",
        source: "personal",
        icon: "photo",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "1x3", "2x2", "2x3"],
        defaultOptions: { sizeMode: "1x2", customPath: "", shapeMode: "rounded", fitMode: "fill", opacityLevel: 1.0, showShadow: true }
    },
    {
        id: "github",
        name: "GitHub",
        source: "personal",
        icon: "commit",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x2", "1x3", "2x2"],
        defaultOptions: { sizeMode: "1x3", user: "", colorMode: "accent", showShadow: true }
    },
    {
        id: "nothingBuds",
        name: "Buds & Volume",
        source: "media",
        icon: "earbuds",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2"],
        defaultOptions: { sizeMode: "1x1", accentMode: "glyph", showShadow: true }
    },
    {
        id: "nothingGreeting",
        name: "Dot Clock",
        source: "time",
        icon: "waving_hand",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x2", "1x3", "2x2"],
        defaultOptions: { sizeMode: "1x2", use24h: true, blinkColon: true, showWeatherMeta: true, customName: "", accentMode: "glyph", showShadow: true }
    },
    {
        id: "nothingResources",
        name: "Dot-Matrix Stats",
        source: "resources",
        icon: "memory",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: ["cpu", "memory", "gpu", "disk"],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x1", "1x2", "1x3", "2x2"],
        defaultOptions: { sizeMode: "1x2", singleMetric: "cpu", accentMode: "glyph", showShadow: true }
    },
    {
        id: "nothingPlayer",
        name: "Vinyl Player",
        source: "media",
        icon: "play_circle",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        isM3: true,
        sizeModes: ["1x2", "1x3", "2x2"],
        defaultOptions: { sizeMode: "2x2", spinArt: true, dotMatrixArt: true, accentMode: "glyph", showShadow: true }
    }
];

var defaultAnchors = {
    time:             { column: 0, row: 0 },
    battery:          { column: 2, row: 0 },
    cpu:              { column: 0, row: 2 },
    memoryUsed:       { column: 2, row: 2 },
    gpu:              { column: 0, row: 3 },
    calendar:         { column: 2, row: 3 },
    network:          { column: 0, row: 4 },
    storage:          { column: 0, row: 5 },
    wifi:             { column: 0, row: 6 },
    weather:          { column: 1, row: 6 },
    storageCapacity:  { column: 0, row: 7 },
    music:            { column: 0, row: 8 },
    media:            { column: 0, row: 10 },
    resources:        { column: 0, row: 12 },
    usercard:         { column: 0, row: 14 },
    image:            { column: 1, row: 14 },
    end4Weather:      { column: 0, row: 16 },
    end4Media:        { column: 0, row: 17 },
    end4Resources:    { column: 0, row: 18 },
    end4User:         { column: 0, row: 19 },
    end4Image:        { column: 0, row: 21 },
    github:           { column: 0, row: 22 },
    nothingBuds:      { column: 0, row: 23 },
    nothingGreeting:  { column: 1, row: 23 },
    nothingResources: { column: 0, row: 24 },
    nothingPlayer:    { column: 0, row: 25 },
    bgVisualiser:     { column: 0, row: 27 }
};

function cloneDefinition(definition) {
    var result = {};
    for (var key in definition)
        result[key] = definition[key];
    result.monitorModules = (definition.monitorModules || []).slice();
    return result;
}

function all() {
    return cardDefinitions.map(cloneDefinition);
}

function ids() {
    return cardDefinitions.map(function(definition) { return definition.id; });
}

function definitionFor(id) {
    for (var i = 0; i < cardDefinitions.length; i += 1) {
        if (cardDefinitions[i].id === id)
            return cardDefinitions[i];
    }
    return null;
}

function widthForSpan(columnSpan) {
    var span = Math.max(1, Math.round(Number(columnSpan) || 1));
    return span * baseCellWidth + (span - 1) * cellGap;
}

function heightForSpan(rowSpan) {
    var span = Math.max(1, Math.round(Number(rowSpan) || 1));
    return span * baseCellHeight + (span - 1) * cellGap;
}

function spanForSizeMode(mode, fallbackCols, fallbackRows) {
    var m = String(mode || "");
    if (m === "1x1") return { columnSpan: 1, rowSpan: 1 };
    if (m === "1x2") return { columnSpan: 2, rowSpan: 1 };
    if (m === "1x3") return { columnSpan: 3, rowSpan: 1 };
    if (m === "2x2") return { columnSpan: 2, rowSpan: 2 };
    if (m === "2x3") return { columnSpan: 3, rowSpan: 2 };
    if (m === "3x1") return { columnSpan: 1, rowSpan: 3 };
    return {
        columnSpan: Math.max(1, Math.round(Number(fallbackCols) || 1)),
        rowSpan: Math.max(1, Math.round(Number(fallbackRows) || 1))
    };
}

function sizeFor(id, options) {
    var definition = definitionFor(String(id));
    if (!definition)
        return { width: baseCellWidth, height: baseCellHeight };
    var opts = (options && typeof options === "object") ? options : (definition.defaultOptions || {});
    var span = spanForSizeMode(opts.sizeMode, definition.columnSpan, definition.rowSpan);
    if (definition.id === "end4Media" && opts.showLyrics && span.rowSpan === 1 && span.columnSpan === 3) {
        span = { columnSpan: 3, rowSpan: 2 };
    }
    return {
        width: widthForSpan(span.columnSpan),
        height: heightForSpan(span.rowSpan)
    };
}

function widthFor(id) { return sizeFor(id).width; }
function heightFor(id) { return sizeFor(id).height; }

function defaultAnchorFor(id) {
    var anchor = defaultAnchors[id];
    return anchor ? { column: anchor.column, row: anchor.row } : { column: 0, row: 0 };
}

function sources() {
    return sourceMeta.map(function(s) {
        return {
            id: s.id,
            label: s.label,
            icon: s.icon,
            count: s.id === "all"
                ? cardDefinitions.length
                : cardDefinitions.filter(function(d) { return d.source === s.id; }).length
        };
    });
}

function sourceLabel(sourceId) {
    for (var i = 0; i < sourceMeta.length; i += 1) {
        if (sourceMeta[i].id === sourceId) return sourceMeta[i].label;
    }
    return "Other";
}

function definitionsForSource(sourceId) {
    if (!sourceId || sourceId === "all") return all();
    return cardDefinitions.filter(function(d) {
        return d.source === sourceId;
    }).map(cloneDefinition);
}

function sidebarDefinitions(activeIds) {
    var allowed = activeIds || ids();
    return cardDefinitions.filter(function(definition) {
        return allowed.indexOf(definition.id) !== -1;
    }).map(cloneDefinition);
}
