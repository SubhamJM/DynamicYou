.pragma library

var baseCellWidth = 152;
var baseCellHeight = 160;
var cellGap = 8;
var canvasWidth = 472; // 3 * 152 + 2 * 8
var cardGridStep = 8;
var cardGridGuideStep = 24;

var cardDefinitions = [
    {
        id: "time",
        name: "Clock",
        icon: "schedule",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "battery",
        name: "Battery",
        icon: "battery_full",
        columnSpan: 1,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "cpu",
        name: "CPU",
        icon: "memory",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: ["cpu"],
        preserveDefaultSurface: true
    },
    {
        id: "gpu",
        name: "GPU",
        icon: "developer_board",
        columnSpan: 2,
        rowSpan: 1,
        monitorModules: ["gpu"],
        preserveDefaultSurface: true
    },
    {
        id: "memoryUsed",
        name: "Memory",
        icon: "memory_alt",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["memory"],
        preserveDefaultSurface: true
    },
    {
        id: "wifi",
        name: "Wi-Fi",
        icon: "wifi",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "network",
        name: "Network",
        icon: "swap_vert",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["network"]
    },
    {
        id: "storage",
        name: "Disk I/O",
        icon: "hard_drive",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["disk"]
    },
    {
        id: "storageCapacity",
        name: "Disk capacity",
        icon: "data_usage",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["disk"],
        preserveDefaultSurface: true
    },
    {
        id: "calendar",
        name: "Calendar",
        icon: "calendar_month",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: []
    },
    {
        id: "weather",
        name: "Weather",
        icon: "cloud",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "music",
        name: "Music & Lyrics",
        icon: "music_note",
        columnSpan: 3,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    }
];

var defaultAnchors = {
    time:            { column: 0, row: 0 },
    battery:         { column: 2, row: 0 },
    cpu:             { column: 0, row: 2 },
    memoryUsed:      { column: 2, row: 2 },
    gpu:             { column: 0, row: 3 },
    calendar:        { column: 2, row: 3 },
    network:         { column: 0, row: 4 },
    storage:         { column: 0, row: 5 },
    wifi:            { column: 0, row: 6 },
    weather:         { column: 1, row: 6 },
    storageCapacity: { column: 0, row: 7 },
    music:           { column: 0, row: 8 }
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

function sizeFor(id) {
    var definition = definitionFor(String(id));
    if (!definition)
        return { width: baseCellWidth, height: baseCellHeight };
    return {
        width: widthForSpan(definition.columnSpan),
        height: heightForSpan(definition.rowSpan)
    };
}

function widthFor(id) { return sizeFor(id).width; }
function heightFor(id) { return sizeFor(id).height; }

function defaultAnchorFor(id) {
    var anchor = defaultAnchors[id];
    return anchor ? { column: anchor.column, row: anchor.row } : { column: 0, row: 0 };
}

function sidebarDefinitions(activeIds) {
    var allowed = activeIds || ids();
    return cardDefinitions.filter(function(definition) {
        return allowed.indexOf(definition.id) !== -1;
    }).map(cloneDefinition);
}
