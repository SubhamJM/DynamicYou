import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: launcher
    spacing: 8
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias searchInput: searchInput
    property var allApps: (typeof root !== "undefined" && root.cachedApps && root.cachedApps.length > 0) ? root.cachedApps : []
    property var runningClients: []
    property var clipboardEntries: []
    property var suggestions: []
    property int selectedTileIndex: 0

    ListModel { id: resultsModel }

    // Power User Card States
    property bool isMathActive: false
    property string mathResult: ""
    property string mathRawResult: ""
    property string mathExpr: ""

    property bool isBangActive: false
    property string bangType: ""
    property string bangQuery: ""
    property string bangLabel: ""
    property string bangIcon: ""

    property bool isCmdActive: false
    property string cmdText: ""
    property bool isCmdInteractive: false

    property bool isCopiedFeedback: false

    readonly property bool hasPowerCard: isMathActive || isBangActive || isCmdActive
    readonly property int calculatedCount: resultsModel.count + (hasPowerCard ? 1 : 0)
    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"

    // Search prefixes matching Iris
    readonly property string prefixClipboard: ";"
    readonly property string prefixMath: "="
    readonly property string prefixAction: "/"
    readonly property string prefixEmoji: ":"
    readonly property string prefixWeb: "?"
    readonly property string prefixCommand: "$"

    property string rawQuery: searchInput.text.trim()
    readonly property bool browsing: rawQuery.length === 0
    readonly property bool clipboardMode: rawQuery.startsWith(prefixClipboard)
    readonly property bool mathMode: rawQuery.startsWith(prefixMath) || (!rawQuery.startsWith(";") && !rawQuery.startsWith("/") && !rawQuery.startsWith(":") && !rawQuery.startsWith("?") && !rawQuery.startsWith("$") && !rawQuery.startsWith(">") && /[0-9]/.test(rawQuery) && /[\+\-\*\/\%]|sqrt|sin|cos|tan|\^|\bto\b|\bin\b/.test(rawQuery))
    readonly property bool actionMode: rawQuery.startsWith(prefixAction)
    readonly property bool emojiMode: rawQuery.startsWith(prefixEmoji)
    readonly property bool webMode: rawQuery.startsWith(prefixWeb)
    readonly property bool commandMode: rawQuery.startsWith(prefixCommand) || rawQuery.startsWith(">")

    // Iris liquid morph curve [0.16, 1, 0.3, 1]
    readonly property var motionCurve: [0.16, 1, 0.3, 1, 1, 1]

    // Emojis dataset
    readonly property var emojisList: [
        { emoji: "😀", name: "grinning face happy" },
        { emoji: "😂", name: "face with tears of joy laugh lol" },
        { emoji: "🤣", name: "rolling on the floor laughing rofl" },
        { emoji: "😊", name: "smiling face with smiling eyes smile" },
        { emoji: "😍", name: "smiling face with heart-eyes love heart" },
        { emoji: "🥰", name: "smiling face with hearts adore" },
        { emoji: "😘", name: "face blowing a kiss kiss" },
        { emoji: "😎", name: "smiling face with sunglasses cool" },
        { emoji: "🔥", name: "fire flame lit hot" },
        { emoji: "✨", name: "sparkles shiny magic" },
        { emoji: "🎉", name: "party popper celebration celebrate party" },
        { emoji: "🚀", name: "rocket ship blast off fast" },
        { emoji: "👍", name: "thumbs up approve yes good" },
        { emoji: "👎", name: "thumbs down disapprove no bad" },
        { emoji: "❤️", name: "red heart love" },
        { emoji: "💯", name: "hundred points perfect score 100" },
        { emoji: "🤔", name: "thinking face think wonder hmm" },
        { emoji: "👀", name: "eyes look see watching" },
        { emoji: "🙏", name: "folded hands please pray thank you" },
        { emoji: "⚡", name: "high voltage lightning bolt power" },
        { emoji: "💻", name: "laptop computer tech code" },
        { emoji: "💡", name: "light bulb idea smart" },
        { emoji: "☕", name: "hot beverage coffee tea" },
        { emoji: "✅", name: "check mark button check done ok" },
        { emoji: "❌", name: "cross mark x no wrong cancel" },
        { emoji: "⭐", name: "star favorite" },
        { emoji: "🥳", name: "partying face woohoo celebration" },
        { emoji: "😴", name: "sleeping face tired zzz sleep" },
        { emoji: "💀", name: "skull dead dying laugh" },
        { emoji: "🫡", name: "saluting face respect yes sir" },
        { emoji: "🥺", name: "pleading face please puppy eyes" },
        { emoji: "😭", name: "loudly crying face sob sad cry" }
    ]

    // System actions dataset
    readonly property var actionsList: [
        { name: "Lock Screen", cmd: "hyprlock", icon: "lock", action: "lock" },
        { name: "Suspend System", cmd: "systemctl suspend", icon: "bedtime", action: "suspend" },
        { name: "Restart Computer", cmd: "systemctl reboot", icon: "restart_alt", action: "restart" },
        { name: "Shut Down", cmd: "systemctl poweroff", icon: "power_settings_new", action: "shutdown" },
        { name: "Screen Snip / Capture", cmd: "grim -g \"$(slurp)\" - | wl-copy", icon: "screenshot_monitor", action: "screenshot" },
        { name: "Pomodoro: 25m Focus Sprint", cmd: "qs ipc call notch startPomo 25 focus", icon: "timer", action: "pomo" },
        { name: "Pomodoro: 5m Short Break", cmd: "qs ipc call notch startPomo 5 short_break", icon: "coffee", action: "break" },
        { name: "Stop Pomodoro Timer", cmd: "qs ipc call notch stopPomo", icon: "timer_off", action: "pomostop" },
        { name: "Toggle Do Not Disturb", cmd: "notify-send 'DND toggled'", icon: "notifications_off", action: "dnd" },
        { name: "Reload Shell", cmd: "~/.config/quickshell/reload.sh &", icon: "refresh", action: "reload" },
        { name: "Open Terminal", cmd: "kitty", icon: "terminal", action: "terminal" },
        { name: "Open File Manager", cmd: "xdg-open ~", icon: "folder_open", action: "files" }
    ]

    Component.onCompleted: {
        if (typeof root !== "undefined" && root.cachedApps && root.cachedApps.length > 0) {
            launcher.allApps = root.cachedApps;
            launcher.updateSuggestions();
            launcher.processSearch(searchInput.text);
        }
        appScanner.running = true;
        clientScanner.running = true;
    }

    function onOpened() {
        launcher.isCopiedFeedback = false;
        launcher.selectedTileIndex = 0;
        clientScanner.running = true;
        if (typeof root !== "undefined" && root.cachedApps && root.cachedApps.length > 0 && launcher.allApps.length === 0) {
            launcher.allApps = root.cachedApps;
        }
        launcher.updateSuggestions();
        launcher.processSearch(searchInput.text);
        if (!appScanner.running) {
            appScanner.running = true;
        }
        searchInput.forceActiveFocus();
        if (resultsModel.count > 0) appList.currentIndex = 0;
    }

    onVisibleChanged: {
        if (visible) {
            onOpened();
        } else {
            launcher.isCopiedFeedback = false;
        }
    }

    function updateSuggestions() {
        var list = [];
        var limit = Math.min(launcher.allApps.length, 8);
        for (var i = 0; i < limit; i++) {
            var app = launcher.allApps[i];
            var rc = launcher.getRunningClient(app.exec, app.name);
            list.push({
                name: app.name,
                exec: app.exec,
                iconName: app.iconName,
                comment: app.comment || app.exec,
                isRunning: rc !== null,
                winAddress: rc ? rc.address : ""
            });
        }
        launcher.suggestions = list;
    }

    function executeSuggestion(idx) {
        if (idx < 0 || idx >= launcher.suggestions.length) return;
        var s = launcher.suggestions[idx];
        if (s.isRunning && s.winAddress !== "") {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + s.winAddress + "\" })"]);
            root.collapseToIdle();
        } else {
            launcher.recordUsageAndLaunch(s.exec);
        }
    }

    function isSubsequence(query, target) {
        var qLen = query.length, tLen = target.length;
        if (qLen > tLen) return false;
        var qIdx = 0, tIdx = 0;
        while (qIdx < qLen && tIdx < tLen) {
            if (query[qIdx] === target[tIdx]) qIdx++;
            tIdx++;
        }
        return qIdx === qLen;
    }

    function escapeHtml(value) {
        return String(value || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function emphasised(name, query) {
        var q = (query || "").trim();
        if (q.length === 0) return launcher.escapeHtml(name);
        var at = name.toLowerCase().indexOf(q.toLowerCase());
        if (at < 0) return launcher.escapeHtml(name);
        var dimColor = Theme.colors.text_secondary ?? "#8a8f9e";
        var brightColor = Theme.colors.text_primary ?? "#ffffff";
        return "<font color='" + dimColor + "'>" + launcher.escapeHtml(name.slice(0, at)) + "</font>"
            + "<font color='" + brightColor + "'><b>" + launcher.escapeHtml(name.slice(at, at + q.length)) + "</b></font>"
            + "<font color='" + dimColor + "'>" + launcher.escapeHtml(name.slice(at + q.length)) + "</font>";
    }

    function sectionOf(modelData, index) {
        if (launcher.clipboardMode) return "Clipboard history";
        if (launcher.actionMode) return "System actions";
        if (launcher.emojiMode) return "Emojis";
        if (launcher.webMode) return "Web search";
        if (index === 0) return "Top hit";
        var type = modelData ? modelData.itemType : "";
        if (type === "app") return "Applications";
        if (type === "action") return "Actions";
        if (type === "math") return "Calculator";
        if (type === "web") return "Web Search";
        return "";
    }

    // ========================================================
    // POWER USER: MATH, BANGS, & SHELL COMMAND PARSING
    // ========================================================
    function safeMathEval(expr) {
        var trimmed = expr.trim();
        if (trimmed.startsWith("=")) trimmed = trimmed.substring(1).trim();
        if (trimmed.length < 2) return null;

        var s = trimmed.replace(/,/g, '').replace(/x/gi, '*').trim();
        s = s.replace(/(\d+(\.\d+)?)\s*%\s*of\s*(\d+(\.\d+)?)/gi, "($1/100)*$3");
        s = s.replace(/(\d+(\.\d+)?)\s*%/g, "($1/100)");
        s = s.replace(/\bsqrt\b/gi, "Math.sqrt")
             .replace(/\bsin\b/gi, "Math.sin")
             .replace(/\bcos\b/gi, "Math.cos")
             .replace(/\btan\b/gi, "Math.tan")
             .replace(/\babs\b/gi, "Math.abs")
             .replace(/\blog\b/gi, "Math.log")
             .replace(/\bpi\b/gi, "Math.PI")
             .replace(/\be\b/gi, "Math.E")
             .replace(/\^/g, "**");

        if (!/^[0-9\.\s\+\-\*\/\(\)\Math\.A-Z_]+$/.test(s)) return null;
        if (!/[\+\-\*\/\%]/.test(s) && !s.includes("Math.")) return null;

        try {
            var res = Function('"use strict"; return (' + s + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                var rawStr = res.toString();
                var formatted = Number.isInteger(res) ? res.toLocaleString() : parseFloat(res.toFixed(5)).toLocaleString();
                return { formatted: formatted, raw: rawStr };
            }
        } catch(e) {}
        return null;
    }

    Timer {
        id: unitCalcDebounce
        interval: 120
        repeat: false
        property string pendingQuery: ""
        onTriggered: {
            if (pendingQuery !== "") {
                calcProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/calc_helper.py", pendingQuery];
                calcProcess.running = true;
            }
        }
    }

    Process {
        id: calcProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out !== "" && !out.startsWith("error")) {
                    launcher.mathResult = out;
                    launcher.mathRawResult = out;
                    launcher.isMathActive = true;
                }
            }
        }
    }

    function isInteractiveTool(cmd) {
        var clean = cmd.trim();
        var firstWord = clean.split(/\s+/)[0].toLowerCase();
        var tools = [
            "htop", "btop", "top", "nvtop", "yazi", "ranger", "nnn", "mc",
            "nano", "vim", "nvim", "vi", "emacs", "micro",
            "less", "more", "man", "info",
            "bash", "zsh", "fish", "sh", "tmux", "screen",
            "ssh", "sftp", "gdb", "python", "python3", "ipython", "node"
        ];
        return tools.includes(firstWord);
    }

    // Hyprland running clients scanner
    Process {
        id: clientScanner
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcher.runningClients = JSON.parse(this.text) || [];
                } catch(e) {
                    launcher.runningClients = [];
                }
                launcher.updateSuggestions();
            }
        }
    }

    function getRunningClient(appExec, appName) {
        if (!launcher.runningClients || launcher.runningClients.length === 0) return null;
        var execLower = (appExec || "").toLowerCase();
        var nameLower = (appName || "").toLowerCase();
        for (var i = 0; i < launcher.runningClients.length; i++) {
            var c = launcher.runningClients[i];
            if (!c) continue;
            var cClass = (c.class || "").toLowerCase();
            var cInitial = (c.initialClass || "").toLowerCase();
            if ((cClass && (execLower.includes(cClass) || cClass.includes(nameLower) || nameLower.includes(cClass))) ||
                (cInitial && (execLower.includes(cInitial) || cInitial.includes(nameLower)))) {
                return c;
            }
        }
        return null;
    }

    // Clipboard history scanner for prefix ";"
    Process {
        id: clipScanner
        running: false
        command: ["sh", "-c", "cliphist list | head -n 40"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var items = [];
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (!l) continue;
                    var tabIdx = l.indexOf("\t");
                    var id = tabIdx > 0 ? l.substring(0, tabIdx) : "";
                    var val = tabIdx > 0 ? l.substring(tabIdx + 1) : l;
                    items.push({ "id": id, "text": val, "raw": l });
                }
                launcher.clipboardEntries = items;
                launcher.populateClipboardResults(launcher.rawQuery.substring(1).trim().toLowerCase());
            }
        }
    }

    function populateClipboardResults(query) {
        resultsModel.clear();
        var count = 0;
        for (var i = 0; i < launcher.clipboardEntries.length; i++) {
            var item = launcher.clipboardEntries[i];
            if (query === "" || item.text.toLowerCase().includes(query)) {
                resultsModel.append({
                    itemType: "clip",
                    name: item.text.replace(/[\r\n\t]+/g, " "),
                    comment: "Clipboard #" + item.id,
                    iconName: "",
                    matIcon: "content_paste",
                    nerdIcon: "",
                    execCmd: "",
                    rawVal: item.raw,
                    isRunning: false,
                    winAddress: "",
                    actionVerb: "Copy"
                });
                count++;
                if (count >= 7) break;
            }
        }
        appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
    }

    // Desktop Application Scanner
    Process {
        id: appScanner
        running: false
        command: ["sh", "-c", `
            python3 -c "
import os, glob, re, json

cache_file = os.path.expanduser('~/.cache/qs_icon_cache.json')
icon_cache = {}
if os.path.exists(cache_file):
    try:
        with open(cache_file, 'r') as f: icon_cache = json.load(f)
    except: pass

if not icon_cache:
    for base in ['/usr/share/pixmaps', os.path.expanduser('~/.local/share/icons')]:
        if os.path.exists(base):
            for root, dirs, files in os.walk(base):
                for f in files:
                    name, ext = os.path.splitext(f)
                    if ext.lower() in ('.png', '.svg', '.xpm') and name not in icon_cache:
                        icon_cache[name] = os.path.join(root, f)
    for theme in ['breeze-dark', 'breeze', 'Adwaita', 'hicolor']:
        base = f'/usr/share/icons/{theme}'
        if os.path.exists(base):
            for root, dirs, files in os.walk(base):
                for f in files:
                    name, ext = os.path.splitext(f)
                    if ext.lower() in ('.png', '.svg') and name not in icon_cache:
                        icon_cache[name] = os.path.join(root, f)
    try:
        with open(cache_file, 'w') as f: json.dump(icon_cache, f)
    except: pass

def resolve_icon(i):
    if not i: return ''
    if os.path.isabs(i) and os.path.exists(i): return i
    return icon_cache.get(i, '')

apps = []
usage = {}
try:
    with open(os.path.expanduser('~/.cache/qs_app_usage.json'), 'r') as f: usage = json.load(f)
except: pass

paths = ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]
for p in paths:
    for f in glob.glob(p + '/*.desktop'):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                if 'NoDisplay=true' in content: continue
                name = re.search(r'^Name=(.*)$', content, re.M)
                exec_cmd = re.search(r'^Exec=(.*)$', content, re.M)
                icon = re.search(r'^Icon=(.*)$', content, re.M)
                comment = re.search(r'^Comment=(.*)$', content, re.M)
                if name and exec_cmd:
                    n = name.group(1).strip()
                    e = re.sub(r'%[fFuUiDc]', '', exec_cmd.group(1)).strip()
                    i_raw = icon.group(1).strip() if (icon and icon.group(1)) else ''
                    i = resolve_icon(i_raw)
                    c = comment.group(1).strip() if comment else ''
                    u = usage.get(e, 0)
                    apps.append((u, n, e, i, c))
        except: pass
apps = sorted(list(set(apps)), key=lambda x: (-x[0], x[1].lower()))
for a in apps: print(f'{a[1]}|||{a[2]}|||{a[3]}|||{a[4]}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var tempList = [];
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 3) {
                        tempList.push({
                            "name": parts[0],
                            "exec": parts[1],
                            "iconName": parts[2],
                            "comment": parts.length > 3 ? parts[3] : ""
                        });
                    }
                }
                if (tempList.length > 0) {
                    if (typeof root !== "undefined") root.cachedApps = tempList;
                    launcher.allApps = tempList;
                    launcher.updateSuggestions();
                    launcher.processSearch(searchInput.text);
                }
            }
        }
    }

    Process { id: appRunner; running: false }

    Process {
        id: usageTracker
        running: false
        property string targetExec: ""
        command: ["python3", "-c", `
import sys, os, json
f = os.path.expanduser('~/.cache/qs_app_usage.json')
d = {}
try:
    with open(f, 'r') as file: d = json.load(file)
except: pass
cmd = sys.argv[1]
d[cmd] = d.get(cmd, 0) + 1
with open(f, 'w') as file: json.dump(d, file)
        `, targetExec]
    }

    function recordUsageAndLaunch(execCmd) {
        var cleanCmd = (execCmd || "").replace(/%[uUfFdiDnvmck]/g, "").trim();
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "sh", "-c", cleanCmd]);
        usageTracker.targetExec = cleanCmd;
        usageTracker.running = true;
        root.collapseToIdle();
    }

    // ========================================================
    // MAIN SEARCH DISPATCHER
    // ========================================================
    function processSearch(filterText) {
        var raw = filterText.trim();
        resultsModel.clear();

        // 1. Reset Power States
        launcher.isMathActive = false;
        launcher.isBangActive = false;
        launcher.isCmdActive = false;
        launcher.mathResult = "";
        launcher.mathRawResult = "";

        // 2. EMPTY / BROWSING STATE: Frequently used suggestions
        if (raw === "") {
            launcher.updateSuggestions();
            appList.currentIndex = -1;
            return;
        }

        // 3. CLIPBOARD MODE (";")
        if (raw.startsWith(prefixClipboard)) {
            var cQuery = raw.substring(1).trim().toLowerCase();
            if (launcher.clipboardEntries.length === 0) {
                clipScanner.running = true;
            } else {
                launcher.populateClipboardResults(cQuery);
            }
            return;
        }

        // 4. ACTIONS MODE ("/")
        if (raw.startsWith(prefixAction)) {
            var actQuery = raw.substring(1).trim().toLowerCase();
            for (var k = 0; k < launcher.actionsList.length; k++) {
                var act = launcher.actionsList[k];
                if (actQuery === "" || act.name.toLowerCase().includes(actQuery) || act.action.toLowerCase().includes(actQuery)) {
                    resultsModel.append({
                        itemType: "action",
                        name: act.name,
                        comment: "/" + act.action,
                        iconName: "",
                        matIcon: act.icon,
                        nerdIcon: "",
                        execCmd: act.cmd,
                        rawVal: "",
                        isRunning: false,
                        winAddress: "",
                        actionVerb: "Run"
                    });
                }
            }
            appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
            return;
        }

        // 5. EMOJI MODE (":")
        if (raw.startsWith(prefixEmoji)) {
            var emQuery = raw.substring(1).trim().toLowerCase();
            var emCount = 0;
            for (var em = 0; em < launcher.emojisList.length; em++) {
                var eObj = launcher.emojisList[em];
                if (emQuery === "" || eObj.name.toLowerCase().includes(emQuery)) {
                    resultsModel.append({
                        itemType: "emoji",
                        name: eObj.emoji + "  " + eObj.name,
                        comment: ":" + eObj.name.split(" ")[0],
                        iconName: "",
                        matIcon: "",
                        nerdIcon: eObj.emoji,
                        execCmd: "",
                        rawVal: eObj.emoji,
                        isRunning: false,
                        winAddress: "",
                        actionVerb: "Copy"
                    });
                    emCount++;
                    if (emCount >= 7) break;
                }
            }
            appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
            return;
        }

        // 6. WEB SEARCH MODE ("?")
        if (raw.startsWith(prefixWeb)) {
            var wQuery = raw.substring(1).trim();
            if (wQuery.length > 0) {
                resultsModel.append({
                    itemType: "web",
                    name: "Search Google for \"" + wQuery + "\"",
                    comment: "https://www.google.com/search?q=" + encodeURIComponent(wQuery),
                    iconName: "",
                    matIcon: "travel_explore",
                    nerdIcon: "",
                    execCmd: "https://www.google.com/search?q=" + encodeURIComponent(wQuery),
                    rawVal: "",
                    isRunning: false,
                    winAddress: "",
                    actionVerb: "Search"
                });
            }
            appList.currentIndex = 0;
            return;
        }

        // 7. SHELL COMMAND MODE (">" or "$")
        if (raw.startsWith(">") || raw.startsWith("$")) {
            var cmd = raw.substring(1).trim();
            if (cmd.length > 0) {
                launcher.isCmdActive = true;
                launcher.cmdText = cmd;
                launcher.isCmdInteractive = launcher.isInteractiveTool(cmd);
                return;
            }
        }

        // 8. BANGS ("!")
        if (raw.startsWith("!")) {
            var bangParts = raw.split(/\s+/);
            var bang = bangParts[0].toLowerCase();
            var bQuery = raw.substring(bang.length).trim();

            var bangMap = {
                "!g":     { label: "Search Google for \"" + bQuery + "\"", icon: "󰊭", type: "google" },
                "!gh":    { label: "Search GitHub for \"" + bQuery + "\"", icon: "󰊤", type: "github" },
                "!yt":    { label: "Search YouTube for \"" + bQuery + "\"", icon: "", type: "youtube" },
                "!w":     { label: "Search Wikipedia for \"" + bQuery + "\"", icon: "󰖟", type: "wikipedia" },
                "!aw":    { label: "Search ArchWiki for \"" + bQuery + "\"", icon: "󰣇", type: "archwiki" },
                "!arch":  { label: "Search ArchWiki for \"" + bQuery + "\"", icon: "󰣇", type: "archwiki" },
                "!d":     { label: "Search DuckDuckGo for \"" + bQuery + "\"", icon: "󰇥", type: "ddg" },
                "!ddg":   { label: "Search DuckDuckGo for \"" + bQuery + "\"", icon: "󰇥", type: "ddg" },
                "!keys":  { label: "Open Hyprland Keybind Cheat Sheet", icon: "󰌌", type: "keys" },
                "!?":     { label: "Open Hyprland Keybind Cheat Sheet", icon: "󰌌", type: "keys" },
                "!note":  { label: "Open Quick Scratchpad & Tasks", icon: "󰠮", type: "notes" },
                "!notes": { label: "Open Quick Scratchpad & Tasks", icon: "󰠮", type: "notes" },
                "!todo":  { label: "Open Quick Scratchpad & Tasks", icon: "󰠮", type: "notes" },
                "!pomo":   { label: "Start Focus Sprint (25m)", icon: "󱎫", type: "pomo" }
            };

            if (bangMap[bang]) {
                var bInfo = bangMap[bang];
                launcher.isBangActive = true;
                launcher.bangType = bInfo.type;
                launcher.bangQuery = bQuery;
                launcher.bangLabel = bInfo.label;
                launcher.bangIcon = bInfo.icon;
                return;
            }
        }

        // 9. INLINE MATH EVALUATION
        var mathRes = launcher.safeMathEval(raw);
        if (mathRes !== null) {
            launcher.isMathActive = true;
            launcher.mathExpr = raw;
            launcher.mathResult = mathRes.formatted;
            launcher.mathRawResult = mathRes.raw;
        } else if (/\d+\s*[a-zA-Z]+\s+(to|in)\s+[a-zA-Z]+/i.test(raw)) {
            launcher.mathExpr = raw;
            unitCalcDebounce.pendingQuery = raw;
            unitCalcDebounce.restart();
        }

        // 10. DESKTOP APPLICATIONS (Subsequence / Fuzzy / Usage ranking)
        var query = raw.toLowerCase();
        var appMatches = [];
        for (var i = 0; i < launcher.allApps.length; i++) {
            var app = launcher.allApps[i];
            var appNameLower = app.name.toLowerCase();
            var appExecLower = app.exec.toLowerCase();

            var score = -1;
            if (appNameLower === query) score = 100;
            else if (appNameLower.startsWith(query)) score = 80;
            else if (appNameLower.includes(query)) score = 60;
            else if (appExecLower.startsWith(query)) score = 50;
            else if (appExecLower.includes(query)) score = 40;
            else if (launcher.isSubsequence(query, appNameLower)) score = 20;

            if (score > 0) {
                var rcClient = getRunningClient(app.exec, app.name);
                appMatches.push({
                    score: score,
                    app: app,
                    rc: rcClient
                });
            }
        }

        appMatches.sort(function(a, b) { return b.score - a.score; });
        var appLimit = Math.min(appMatches.length, 7);
        for (var m = 0; m < appLimit; m++) {
            var match = appMatches[m];
            resultsModel.append({
                itemType: "app",
                name: match.app.name,
                comment: match.app.comment || match.app.exec,
                iconName: match.app.iconName,
                matIcon: "",
                nerdIcon: "",
                execCmd: match.app.exec,
                rawVal: "",
                isRunning: match.rc !== null,
                winAddress: match.rc ? match.rc.address : "",
                actionVerb: match.rc !== null ? "Switch to" : "Open"
            });
        }

        // 11. FALLBACK WEB SEARCH / SHELL CMD if no apps match
        if (resultsModel.count === 0 && !launcher.hasPowerCard && raw.length > 0) {
            resultsModel.append({
                itemType: "web",
                name: "Search Google for \"" + raw + "\"",
                comment: "https://www.google.com/search?q=" + encodeURIComponent(raw),
                iconName: "",
                matIcon: "travel_explore",
                nerdIcon: "",
                execCmd: "https://www.google.com/search?q=" + encodeURIComponent(raw),
                rawVal: "",
                isRunning: false,
                winAddress: "",
                actionVerb: "Search"
            });
            resultsModel.append({
                itemType: "action",
                name: "Run \"" + raw + "\" in terminal",
                comment: "Execute in Kitty",
                iconName: "",
                matIcon: "terminal",
                nerdIcon: "",
                execCmd: "kitty -e sh -c '" + raw.replace(/'/g, "'\\''") + "'",
                rawVal: "",
                isRunning: false,
                winAddress: "",
                actionVerb: "Run"
            });
        }

        appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
        appList.positionViewAtBeginning();
    }

    function copyMathResult() {
        var toCopy = launcher.mathRawResult || launcher.mathResult;
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(toCopy) + " | wl-copy"]);
        launcher.isCopiedFeedback = true;
        Qt.callLater(() => { copyHideTimer.restart(); });
    }

    Timer {
        id: copyHideTimer
        interval: 350
        repeat: false
        onTriggered: root.collapseToIdle()
    }

    function executeBang() {
        var q = launcher.bangQuery;
        var encoded = encodeURIComponent(q);
        root.collapseToIdle();

        if (launcher.bangType === "keys") {
            root.switchMode("cheatsheet", true);
        } else if (launcher.bangType === "notes") {
            root.switchMode("notes", true);
        } else if (launcher.bangType === "pomo") {
            var pMins = parseInt(launcher.bangQuery) || 25;
            root.startPomodoro(pMins, "focus");
        } else if (launcher.bangType === "google") {
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encoded]);
        } else if (launcher.bangType === "github") {
            Quickshell.execDetached(["xdg-open", "https://github.com/search?q=" + encoded]);
        } else if (launcher.bangType === "youtube") {
            Quickshell.execDetached(["xdg-open", "https://www.youtube.com/results?search_query=" + encoded]);
        } else if (launcher.bangType === "wikipedia") {
            Quickshell.execDetached(["xdg-open", "https://en.wikipedia.org/wiki/Special:Search?search=" + encoded]);
        } else if (launcher.bangType === "archwiki") {
            Quickshell.execDetached(["xdg-open", "https://wiki.archlinux.org/index.php?search=" + encoded]);
        } else if (launcher.bangType === "ddg") {
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encoded]);
        }
    }

    function executeShellCmd(forceTerminal = false) {
        var cmd = launcher.cmdText.trim();
        if (cmd === "") return;
        root.collapseToIdle();

        var lower = cmd.toLowerCase();
        if (lower === "pomo" || lower.startsWith("pomo ") || lower.startsWith("pomostop")) {
            var pParts = lower.split(/\s+/);
            if (lower === "pomostop" || (pParts.length > 1 && pParts[1] === "stop")) {
                root.stopPomodoro();
            } else {
                var pMins = (pParts.length > 1 && !isNaN(parseInt(pParts[1]))) ? parseInt(pParts[1]) : 25;
                var pMode = (pParts.length > 2 && pParts[2].includes("break")) ? "short_break" : "focus";
                root.startPomodoro(pMins, pMode);
            }
            return;
        }

        if (forceTerminal || launcher.isCmdInteractive) {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", cmd]);
        } else {
            Quickshell.execDetached(["sh", "-c", cmd + " &"]);
        }
    }

    function executeSelectedItem(idx) {
        if (idx < 0 || idx >= resultsModel.count) return;
        var item = resultsModel.get(idx);

        if (item.itemType === "app") {
            if (item.isRunning && item.winAddress !== "") {
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + item.winAddress + "\" })"]);
                root.collapseToIdle();
            } else {
                launcher.recordUsageAndLaunch(item.execCmd);
            }
        } else if (item.itemType === "action") {
            var actionCmd = (item.execCmd || "").replace(/%[uUfFdiDnvmck]/g, "").trim();
            Quickshell.execDetached(["systemd-run", "--user", "--scope", "sh", "-c", actionCmd]);
            root.collapseToIdle();
        } else if (item.itemType === "clip") {
            Quickshell.execDetached(["sh", "-c", "echo " + JSON.stringify(item.rawVal) + " | cliphist decode | wl-copy"]);
            root.collapseToIdle();
        } else if (item.itemType === "emoji") {
            Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(item.rawVal) + " | wl-copy"]);
            root.collapseToIdle();
        } else if (item.itemType === "web") {
            Quickshell.execDetached(["xdg-open", item.execCmd]);
            root.collapseToIdle();
        }
    }

    // ========================================================
    // 1. TOP SPOTLIGHT SEARCH BAR (ATTACHED TO NOTCH)
    // ========================================================
    Rectangle {
        id: searchBar
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        radius: 14
        color: Theme.colors.card_bg ?? "#141416"
        border.width: 1.5
        border.color: searchInput.activeFocus ? launcher.accentColor : Qt.rgba(1, 1, 1, 0.08)
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 10

            // Search Glyph (lights up on typing/focus like Iris)
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 22
                text: "search"
                color: (searchInput.text.length > 0 || searchInput.activeFocus) ? launcher.accentColor : (Theme.colors.text_secondary ?? "#6c7086")
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Text Input
            TextField {
                id: searchInput
                focus: true
                selectByMouse: true
                Layout.fillWidth: true
                color: Theme.colors.text_primary ?? "#ffffff"
                font.family: "Noto Sans"
                font.pixelSize: 15
                font.weight: Font.Normal
                placeholderText: "Spotlight Search"
                placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                background: Item {}

                onTextChanged: launcher.processSearch(text)

                Keys.onLeftPressed: (event) => {
                    if (launcher.browsing && launcher.suggestions.length > 0) {
                        launcher.selectedTileIndex = Math.max(0, launcher.selectedTileIndex - 1);
                        event.accepted = true;
                    }
                }
                Keys.onRightPressed: (event) => {
                    if (launcher.browsing && launcher.suggestions.length > 0) {
                        launcher.selectedTileIndex = Math.min(launcher.suggestions.length - 1, launcher.selectedTileIndex + 1);
                        event.accepted = true;
                    }
                }

                Keys.onDownPressed: (event) => {
                    if (!launcher.browsing && appList.currentIndex < resultsModel.count - 1) {
                        appList.currentIndex++;
                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                Keys.onUpPressed: (event) => {
                    if (!launcher.browsing && appList.currentIndex > 0) {
                        appList.currentIndex--;
                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                Keys.onEscapePressed: {
                    root.collapseToIdle();
                }

                Keys.onReturnPressed: (event) => {
                    var isShift = (event.modifiers & Qt.ShiftModifier);
                    if (launcher.browsing && launcher.suggestions.length > 0) {
                        launcher.executeSuggestion(launcher.selectedTileIndex);
                        event.accepted = true;
                    } else if (launcher.isMathActive) {
                        launcher.copyMathResult();
                        event.accepted = true;
                    } else if (launcher.isBangActive) {
                        launcher.executeBang();
                        event.accepted = true;
                    } else if (launcher.isCmdActive) {
                        launcher.executeShellCmd(isShift);
                        event.accepted = true;
                    } else if (resultsModel.count > 0 && appList.currentIndex >= 0) {
                        launcher.executeSelectedItem(appList.currentIndex);
                        event.accepted = true;
                    } else if (text.trim() !== "") {
                        appRunner.command = ["sh", "-c", text.trim() + " &"];
                        appRunner.running = true;
                        root.collapseToIdle();
                        event.accepted = true;
                    }
                }
            }

            // Active Mode Token Pill (Iris styled)
            Rectangle {
                id: activeModeToken
                readonly property var activeInfo: {
                    if (launcher.clipboardMode) return { glyph: "content_paste", label: "Clipboard" };
                    if (launcher.mathMode) return { glyph: "calculate", label: "Calculator" };
                    if (launcher.actionMode) return { glyph: "bolt", label: "Actions" };
                    if (launcher.emojiMode) return { glyph: "mood", label: "Emoji" };
                    if (launcher.webMode) return { glyph: "travel_explore", label: "Web" };
                    if (launcher.commandMode) return { glyph: "terminal", label: "Shell" };
                    return null;
                }

                visible: activeInfo !== null && searchInput.text.trim().length > 1
                Layout.preferredHeight: 24
                Layout.preferredWidth: modeRow.implicitWidth + 16
                radius: 12
                color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: activeModeToken.activeInfo ? activeModeToken.activeInfo.glyph : ""
                        iconSize: 13
                        color: launcher.accentColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: activeModeToken.activeInfo ? activeModeToken.activeInfo.label : ""
                        color: launcher.accentColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: "Noto Sans"
                    }
                }
            }

            // Clear Button
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                visible: searchInput.text.length > 0
                color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }
    }

    // ========================================================
    // 2. BROWSING VIEW (WHEN SEARCH QUERY IS EMPTY)
    // ========================================================
    ColumnLayout {
        id: browseContainer
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.bottomMargin: 4
        visible: launcher.browsing
        spacing: 6

        // Suggestions Label
        Text {
            Layout.leftMargin: 4
            text: "Suggestions"
            font.family: "Noto Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.colors.text_secondary ?? "#8a8f9e"
        }

        // Horizontal App Tiles Grid (Iris 1:1)
        Item {
            id: tilesItem
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            readonly property real tileWidth: launcher.suggestions.length > 0 ? (width / launcher.suggestions.length) : 60

            // Liquid Sliding Highlight Behind Selected Tile
            Rectangle {
                id: tileHighlight
                visible: launcher.suggestions.length > 0 && launcher.selectedTileIndex >= 0 && launcher.selectedTileIndex < launcher.suggestions.length
                x: launcher.selectedTileIndex * tilesItem.tileWidth + 2
                y: 2
                width: tilesItem.tileWidth - 4
                height: tilesItem.height - 4
                radius: 12
                color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.28)
                Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: launcher.motionCurve } }
            }

            Row {
                id: tilesRow
                anchors.fill: parent

                Repeater {
                    model: launcher.suggestions
                    delegate: Item {
                        id: tile
                        width: tilesItem.tileWidth
                        height: tilesItem.height

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: launcher.selectedTileIndex = index
                            onClicked: {
                                launcher.selectedTileIndex = index;
                                launcher.executeSuggestion(index);
                            }
                        }

                        // App Icon
                        Item {
                            id: tileIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8
                            width: 44
                            height: 44
                            scale: tileMouse.pressed ? 0.92 : (launcher.selectedTileIndex === index ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize.width: 40
                                sourceSize.height: 40
                                visible: status === Image.Ready && source != ""
                                source: {
                                    if (!modelData.iconName || modelData.iconName === "") return "";
                                    if (modelData.iconName.startsWith("/")) return "file://" + modelData.iconName;
                                    return "image://icon/" + modelData.iconName;
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !parent.children[0].visible
                                text: "apps"
                                iconSize: 26
                                color: Theme.colors.text_primary ?? "#ffffff"
                            }
                        }

                        // Running status indicator dot
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: tileIcon.bottom
                            anchors.topMargin: 2
                            visible: modelData.isRunning
                            width: 4
                            height: 4
                            radius: 2
                            color: "#73daca"
                        }

                        // App Name
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.name
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: launcher.selectedTileIndex === index ? Font.DemiBold : Font.Normal
                            color: launcher.selectedTileIndex === index ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#8a8f9e")
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // Mode Hint Chips Row (Iris 1:1)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            component HintChip: Rectangle {
                id: chipRoot
                property string prefixChar: ""
                property string labelText: ""
                Layout.fillWidth: true
                height: 28
                radius: 8
                color: chipMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: chipMouse.containsMouse ? launcher.accentColor : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 110 } }
                Behavior on border.color { ColorAnimation { duration: 110 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 4
                        color: chipMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                        Text {
                            anchors.centerIn: parent
                            text: chipRoot.prefixChar
                            font.family: "Noto Sans Mono"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: launcher.accentColor
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chipRoot.labelText
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: chipMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#8a8f9e")
                    }
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchInput.text = chipRoot.prefixChar;
                        searchInput.cursorPosition = searchInput.text.length;
                        searchInput.forceActiveFocus();
                    }
                }
            }

            HintChip { prefixChar: ";"; labelText: "Clipboard" }
            HintChip { prefixChar: "="; labelText: "Calculator" }
            HintChip { prefixChar: "/"; labelText: "Actions" }
            HintChip { prefixChar: ":"; labelText: "Emoji" }
            HintChip { prefixChar: "?"; labelText: "Web" }
            HintChip { prefixChar: "$"; labelText: "Command" }
        }
    }

    // ========================================================
    // 3. SEARCH RESULTS VIEW (WHEN SEARCH QUERY ACTIVE)
    // ========================================================
    ColumnLayout {
        id: searchContainer
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.bottomMargin: 0
        visible: !launcher.browsing
        spacing: 4

        // Math Evaluation Card
        Rectangle {
            id: mathCard
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: launcher.isMathActive && launcher.mathResult !== ""
            radius: 12
            color: launcher.isCopiedFeedback
                ? Qt.rgba(0.18, 0.83, 0.5, 0.22)
                : (mathMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18) : (Theme.colors.card_bg ?? "#141416"))
            border.width: 1.5
            border.color: launcher.isCopiedFeedback ? "#73daca" : launcher.accentColor
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: launcher.isCopiedFeedback ? Qt.rgba(0.18, 0.83, 0.5, 0.25) : Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: launcher.isCopiedFeedback ? "check" : "calculate"
                        iconSize: 20
                        color: launcher.isCopiedFeedback ? "#73daca" : launcher.accentColor
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                        text: "= " + launcher.mathResult
                        font.family: "Noto Sans"
                        font.pixelSize: 16
                        font.bold: true
                        color: launcher.isCopiedFeedback ? "#73daca" : (Theme.colors.text_primary ?? "#ffffff")
                    }

                    Text {
                        text: launcher.isCopiedFeedback ? "Copied answer to clipboard!" : (launcher.mathExpr + " · Press Enter to copy")
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        color: launcher.isCopiedFeedback ? "#73daca" : (Theme.colors.text_secondary ?? "#8a8f9e")
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 64
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: launcher.isCopiedFeedback ? "Copied" : "Copy ↵"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.colors.text_primary ?? "white"
                    }
                }
            }

            MouseArea {
                id: mathMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: launcher.copyMathResult()
            }
        }

        // Search Bang Card
        Rectangle {
            id: bangCard
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: launcher.isBangActive
            radius: 12
            color: bangMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18) : (Theme.colors.card_bg ?? "#141416")
            border.width: 1.5
            border.color: launcher.accentColor
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                    Text {
                        anchors.centerIn: parent
                        text: launcher.bangIcon || "󰊭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: launcher.accentColor
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: launcher.bangLabel
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.colors.text_primary ?? "#ffffff"
                        elide: Text.ElideRight
                    }

                    Text {
                        text: (launcher.bangType === "keys" || launcher.bangType === "notes") ? "Press Enter to open module" : "Press Enter to search in default browser"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#8a8f9e"
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 64
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "Search ↵"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.colors.text_primary ?? "white"
                    }
                }
            }

            MouseArea {
                id: bangMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: launcher.executeBang()
            }
        }

        // Shell Command Card (">" or "$")
        Rectangle {
            id: cmdCard
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: launcher.isCmdActive
            radius: 12
            color: cmdMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18) : (Theme.colors.card_bg ?? "#141416")
            border.width: 1.5
            border.color: launcher.accentColor
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "terminal"
                        iconSize: 20
                        color: launcher.accentColor
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Row {
                        spacing: 6
                        Text {
                            text: "Run: " + launcher.cmdText
                            font.family: "Noto Sans Mono"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.colors.text_primary ?? "#ffffff"
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            height: 16
                            width: badgeText.implicitWidth + 8
                            radius: 8
                            color: launcher.isCmdInteractive ? Qt.rgba(0.48, 0.63, 0.97, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: launcher.isCmdInteractive ? "kitty" : "background"
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                color: launcher.isCmdInteractive ? launcher.accentColor : (Theme.colors.text_secondary ?? "#8a8f9e")
                            }
                        }
                    }

                    Text {
                        text: "Press Enter to execute · Shift+Enter to force in Kitty terminal"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: Theme.colors.text_secondary ?? "#8a8f9e"
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 54
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "Run ↵"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.colors.text_primary ?? "white"
                    }
                }
            }

            MouseArea {
                id: cmdMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: launcher.executeShellCmd(false)
            }
        }

        // Results List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !launcher.isBangActive && !launcher.isCmdActive

            ListView {
                id: appList
                anchors.fill: parent
                clip: true
                spacing: 3
                bottomMargin: 2
                model: resultsModel
                currentIndex: 0

                highlightFollowsCurrentItem: true
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 40
                preferredHighlightEnd: height - 56

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < count) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar { 
                    policy: ScrollBar.AsNeeded
                    width: 4
                    contentItem: Rectangle { 
                        radius: 2
                        color: Theme.colors.text_secondary ?? "#565f89"
                        opacity: 0.4 
                    } 
                }

                delegate: Column {
                    id: delegateRoot
                    width: ListView.view ? ListView.view.width : 500
                    property bool isSelected: ListView.isCurrentItem
                    readonly property bool topHit: index === 0 && !launcher.clipboardMode
                    readonly property bool showHeader: index === 0 || launcher.sectionOf(model, index) !== launcher.sectionOf(resultsModel.get(index - 1), index - 1)

                    // Category Section Header (Top hit / Applications / etc.)
                    Text {
                        visible: delegateRoot.showHeader && text !== ""
                        x: 8
                        height: Math.round(index === 0 ? 20 : 24)
                        verticalAlignment: Text.AlignBottom
                        bottomPadding: 3
                        text: launcher.sectionOf(model, index)
                        color: Theme.colors.text_secondary ?? "#8a8f9e"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        id: rowRect
                        width: parent.width
                        height: delegateRoot.topHit ? 52 : 40
                        radius: 10
                        color: delegateRoot.isSelected
                            ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18)
                            : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                        border.width: delegateRoot.isSelected ? 1 : 0
                        border.color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.28)
                        Behavior on color { ColorAnimation { duration: 110 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            // Icon Container
                            Item {
                                readonly property real iconBoxSize: delegateRoot.topHit ? 34 : 26
                                Layout.preferredWidth: iconBoxSize
                                Layout.preferredHeight: iconBoxSize
                                Layout.alignment: Qt.AlignVCenter

                                // Material Icon
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: model.matIcon !== ""
                                    text: model.matIcon
                                    iconSize: delegateRoot.topHit ? 22 : 18
                                    color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#ffffff")
                                }

                                // Nerd Icon
                                Text {
                                    anchors.centerIn: parent
                                    visible: model.nerdIcon !== "" && model.matIcon === ""
                                    text: model.nerdIcon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: delegateRoot.topHit ? 20 : 16
                                    color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#ffffff")
                                }

                                // App Icon Image
                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    sourceSize.width: parent.width
                                    sourceSize.height: parent.height
                                    visible: model.matIcon === "" && model.nerdIcon === "" && status === Image.Ready && source != ""
                                    source: {
                                        if (!model.iconName || model.iconName === "") return "";
                                        if (model.iconName.startsWith("/")) return "file://" + model.iconName;
                                        return "image://icon/" + model.iconName;
                                    }
                                }

                                // Fallback Icon
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: model.matIcon === "" && model.nerdIcon === "" && !appIcon.visible
                                    text: "apps"
                                    iconSize: delegateRoot.topHit ? 20 : 16
                                    color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_secondary ?? "#8a8f9e")
                                }
                            }

                            // Title & Description Column
                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    textFormat: Text.StyledText
                                    text: launcher.emphasised(model.name, launcher.rawQuery)
                                    color: Theme.colors.text_primary ?? "#ffffff"
                                    font.family: "Noto Sans"
                                    font.pixelSize: delegateRoot.topHit ? 14 : 12.5
                                    font.weight: delegateRoot.topHit ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: (delegateRoot.topHit || model.comment !== "") && text !== ""
                                    text: model.comment
                                    color: delegateRoot.isSelected ? (Theme.colors.text_primary ?? "#a9b1d6") : (Theme.colors.text_secondary ?? "#8a8f9e")
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            // Running Badge Pill (if window is active)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                visible: model.isRunning
                                height: 18
                                width: runRow.implicitWidth + 10
                                radius: 9
                                color: Qt.rgba(0.2, 0.8, 0.4, 0.18)

                                Row {
                                    id: runRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        color: "#73daca"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Running"
                                        font.family: "Noto Sans"
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                        color: "#73daca"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Action Hint Pill (e.g. Open ↵ / Switch to ↵)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                height: 22
                                width: actionHintText.implicitWidth + 14
                                radius: 6
                                color: delegateRoot.isSelected ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                                visible: delegateRoot.isSelected || model.isRunning

                                Text {
                                    id: actionHintText
                                    anchors.centerIn: parent
                                    text: model.actionVerb + " ↵"
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_secondary ?? "#8a8f9e")
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: appList.currentIndex = index
                            onClicked: launcher.executeSelectedItem(index)
                        }
                    }
                }
            }

            // Empty state when search yields no results
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: resultsModel.count === 0 && searchInput.text.trim() !== "" && !launcher.isMathActive && !launcher.isCmdActive && !launcher.isBangActive

                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "search_off"
                    iconSize: 28
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No results found"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
            }
        }
    }
}