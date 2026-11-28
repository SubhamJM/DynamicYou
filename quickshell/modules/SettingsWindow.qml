import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../"

Rectangle {
    id: root
    focus: true

    signal closeRequested()

    width: 1040
    height: 680
    radius: 26
    color: "transparent"
    clip: true
    focus: true

    // ─── State ────────────────────────────────────────────────
    property string activePageId: "keybinds"
    property string searchQuery: ""
    property var searchResults: []
    property int searchSelected: 0
    property var searchIndex: []
    property var searchTargetRow: null
    property bool searchJumpPending: false
    readonly property bool searching: searchQuery.trim().length > 0
    readonly property var pageOrder: ["themes", "keybinds", "tiling", "animations", "input", "notch", "bar", "launcher", "battery", "network", "displays", "about"]
    property string selectedKeybindCat: "All"
    property var wifiStatus: ({ "radio": true, "connected_ssid": "", "active_ip": "", "active_dev": "wlan0" })
    property var hyprConfig: ({
        "gaps_in": 6,
        "gaps_out": 12,
        "border_size": 2,
        "active_opacity": 1.0,
        "inactive_opacity": 0.9,
        "blur_enabled": 0,
        "blur_size": 8,
        "blur_passes": 2,
        "animations_enabled": true,
        "touchpad_tap": true,
        "natural_scroll": true,
        "disable_while_typing": true,
        "sensitivity": 0.0
    })
    property var keybindsList: []
    property var themePresets: []
    property string powerProfile: ""
    property bool nightLightOn: false
    property string toast: ""
    readonly property var btAdapter: (typeof Bluetooth !== "undefined") ? Bluetooth.defaultAdapter : null

    function setPage(pageId) {
        if (pageId && pageId.length > 0) {
            root.activePageId = pageId;
            contentFlick.contentY = 0;
        }
    }

    function setHyprKeyword(keyword, val) {
        hyprExecProc.command = ["hyprctl", "keyword", keyword, String(val)];
        hyprExecProc.running = false;
        hyprExecProc.running = true;
    }

    function runShellCmd(cmdArr) {
        hyprExecProc.command = cmdArr;
        hyprExecProc.running = false;
        hyprExecProc.running = true;
    }

    function flashToast(message) {
        root.toast = message;
        toastTimer.restart();
    }

    // ─── Tokens ───────────────────────────────────────────────
    readonly property color cBg: (typeof Theme !== "undefined" && Theme.m3) ? Theme.m3.background : "#0a0c12"
    readonly property color cInk: (typeof Theme !== "undefined" && Theme.m3) ? Theme.m3.on_surface : "#eef2f7"
    readonly property color cMuted: (typeof Theme !== "undefined" && Theme.m3) ? Theme.m3.on_surface_variant : "#9aa4b2"
    readonly property color cAccent: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
    readonly property color cOnAccent: (typeof Theme !== "undefined" && Theme.onAccent) ? Theme.onAccent : "#0a0c12"
    readonly property bool lightTheme: (cBg.r * 0.299 + cBg.g * 0.587 + cBg.b * 0.114) > 0.5
    readonly property string fontBody: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
    readonly property string fontMono: (typeof Theme !== "undefined" && Theme.fontFamilyNerd) ? Theme.fontFamilyNerd : "monospace"

    // Iris-shaped scale: one step per job, nothing invented per row.
    readonly property int typeCaption: 10
    readonly property int typeFootnote: 11
    readonly property int typeMeta: 12
    readonly property int typeLabel: 13
    readonly property int typeHeadline: 15
    readonly property int typeTitle: 26
    readonly property real radiusPanel: 18
    readonly property real radiusTile: 14
    readonly property real radiusRow: 9
    readonly property color cHairline: tint(lightTheme ? 0.10 : 0.07)
    readonly property color cHairlineSoft: tint(lightTheme ? 0.055 : 0.04)
    readonly property color cSidebarSurface: tint(lightTheme ? 0.03 : 0.045)
    readonly property color cPaneSurface: tint(lightTheme ? 0.012 : 0.014)
    readonly property color cRowSurface: tint(lightTheme ? 0.025 : 0.022)
    readonly property color cRowHover: tint(lightTheme ? 0.045 : 0.038)
    readonly property bool reduceMotion: (typeof Prefs !== "undefined" && Prefs.reduceMotion !== undefined) ? !!Prefs.reduceMotion : false
    function motion(ms) { return root.reduceMotion ? 0 : ms; }

    function tint(a) {
        return lightTheme ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a);
    }
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property var pageMeta: ({
        "themes":     { "group": "Look & Feel", "title": "Colors & Themes", "desc": "A palette for every surface — notch, bar, widgets and windows." },
        "keybinds":   { "group": "Hyprland", "title": "Keybinds & Shortcuts", "desc": "Parsed live from your Hyprland configuration. Click a row to copy." },
        "tiling":     { "group": "Hyprland", "title": "Windows & Tiling", "desc": "Gaps and borders applied to every workspace." },
        "animations": { "group": "Hyprland", "title": "Animations & Blur", "desc": "Motion and glass effects for windows and layers." },
        "input":      { "group": "Hyprland", "title": "Input & Touchpad", "desc": "Pointing, scrolling and typing behaviour." },
        "notch":      { "group": "Shell", "title": "Dynamic Notch", "desc": "The island the whole desktop lives inside." },
        "bar":        { "group": "Shell", "title": "Top Bar & Dash", "desc": "Visibility, clock and hover behaviour of the bar." },
        "launcher":   { "group": "Shell", "title": "Launcher & Clipboard", "desc": "Quick actions and the clipboard history." },
        "battery":    { "group": "Hardware", "title": "Battery & Power", "desc": "Power profiles and display refresh." },
        "network":    { "group": "Hardware", "title": "Bluetooth & Network", "desc": "Radios, Wi-Fi and the active link." },
        "displays":   { "group": "Hardware", "title": "Displays & Audio", "desc": "The panel, its scale and night light." },
        "about":      { "group": "System", "title": "About & Actions", "desc": "What this desktop is made of, and quick repairs." }
    })
    readonly property var meta: root.pageMeta[root.activePageId] || root.pageMeta["keybinds"]

    readonly property var navGroups: [
        { name: "Look & Feel", pages: [
            { id: "themes", name: "Colors & Themes", icon: "palette" } ] },
        { name: "Shell", pages: [
            { id: "notch", name: "Dynamic Notch", icon: "notifications_active" },
            { id: "bar", name: "Top Bar & Dash", icon: "toolbar" },
            { id: "launcher", name: "Launcher & Clipboard", icon: "apps" } ] },
        { name: "Hyprland", pages: [
            { id: "keybinds", name: "Keybinds & Shortcuts", icon: "keyboard" },
            { id: "tiling", name: "Windows & Tiling", icon: "grid_view" },
            { id: "animations", name: "Animations & Blur", icon: "animation" },
            { id: "input", name: "Input & Touchpad", icon: "touch_app" } ] },
        { name: "Hardware", pages: [
            { id: "battery", name: "Battery & Power", icon: "battery_5_bar" },
            { id: "network", name: "Bluetooth & Network", icon: "wifi" },
            { id: "displays", name: "Displays & Audio", icon: "monitor" } ] },
        { name: "System", pages: [
            { id: "about", name: "About & Actions", icon: "info" } ] }
    ]

    readonly property var filteredKeybinds: {
        var q = (root.searchQuery || "").toLowerCase().trim();
        var cat = root.selectedKeybindCat;
        return root.keybindsList.filter(function(kb) {
            if (cat !== "All" && kb.cat !== cat) return false;
            if (!q) return true;
            return (kb.desc || "").toLowerCase().indexOf(q) !== -1
                || (kb.key || "").toLowerCase().indexOf(q) !== -1
                || (kb.cmd || "").toLowerCase().indexOf(q) !== -1;
        });
    }

    function pageMatches(pageName, groupName) {
        var q = (root.searchQuery || "").toLowerCase().trim();
        if (!q) return true;
        return (pageName + " " + groupName).toLowerCase().indexOf(q) !== -1;
    }

    function pageLabel(pageId) {
        for (var g = 0; g < root.navGroups.length; g++) {
            var pages = root.navGroups[g].pages;
            for (var p = 0; p < pages.length; p++)
                if (pages[p].id === pageId) return pages[p].name;
        }
        return pageId;
    }

    function collectRows(item, pageId, out) {
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var kid = kids[i];
            if (!kid) continue;
            if (kid.objectName === "settingRow")
                out.push({ "title": kid.title || "", "desc": kid.desc || "", "page": pageId, "row": kid });
            root.collectRows(kid, pageId, out);
        }
    }

    function rebuildSearchIndex() {
        var out = [];
        var cols = pagesColumn.children;
        for (var i = 0; i < cols.length && i < root.pageOrder.length; i++)
            root.collectRows(cols[i], root.pageOrder[i], out);
        root.searchIndex = out;
    }

    function refreshSearch() {
        var q = (root.searchQuery || "").toLowerCase().trim();
        root.searchSelected = 0;
        if (!q.length) {
            root.searchResults = [];
            return;
        }
        var out = [];
        for (var g = 0; g < root.navGroups.length; g++) {
            var group = root.navGroups[g];
            for (var p = 0; p < group.pages.length; p++) {
                var page = group.pages[p];
                var meta = root.pageMeta[page.id] || {};
                if ((page.name + " " + group.name).toLowerCase().indexOf(q) !== -1)
                    out.push({ "title": page.name, "desc": meta.desc || "", "page": page.id, "row": null });
            }
        }
        for (var i = 0; i < root.searchIndex.length; i++) {
            var entry = root.searchIndex[i];
            var hay = (entry.title + " " + entry.desc + " " + root.pageLabel(entry.page)).toLowerCase();
            if (hay.indexOf(q) !== -1)
                out.push(entry);
        }
        root.searchResults = out.slice(0, 24);
    }

    function openSearchResult(index) {
        var r = root.searchResults[index];
        if (!r) return;
        if (typeof searchInput !== "undefined" && searchInput)
            searchInput.text = "";
        root.searchQuery = "";
        root.setPage(r.page);
        if (r.row) {
            root.searchTargetRow = r.row;
            jumpTimer.restart();
        } else {
            contentFlick.contentY = 0;
        }
    }

    function revealRow(rowObj) {
        if (!rowObj) return;
        var p = rowObj.mapToItem(contentFlick, 0, 0);
        var docY = contentFlick.contentY + p.y;
        findGlow.x = p.x;
        findGlow.y = docY - 4;
        findGlow.width = rowObj.width;
        findGlow.height = rowObj.height;
        contentFlick.contentY = Math.max(0, docY - 120);
        findGlow.visible = true;
        findGlowFlash.restart();
    }

    function moveSearchSelection(delta) {
        if (!root.searchResults.length) return;
        root.searchSelected = Math.max(0, Math.min(root.searchResults.length - 1, root.searchSelected + delta));
    }

    // ─── Processes ────────────────────────────────────────────
    Process { id: hyprExecProc }

    Process {
        id: wifiStatusProc
        running: false
        command: ["python3", Quickshell.shellDir + "/scripts/wifi_manager.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.wifiStatus = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    Timer {
        id: wifiReloadTimer
        interval: 1500
        repeat: false
        onTriggered: wifiStatusProc.running = true
    }

    Process {
        id: hyprQueryProc
        running: false
        command: ["python3", "-c", "import json, subprocess
def get(k):
    try: return json.loads(subprocess.check_output(['hyprctl', '-j', 'getoption', k], text=True))
    except: return {}
res = {
    'gaps_in': 6,
    'gaps_out': 12,
    'border_size': get('general:border_size').get('int', 2),
    'active_opacity': get('decoration:active_opacity').get('float', 1.0),
    'inactive_opacity': get('decoration:inactive_opacity').get('float', 0.9),
    'blur_enabled': get('decoration:blur:enabled').get('int', 0),
    'blur_size': get('decoration:blur:size').get('int', 8),
    'blur_passes': get('decoration:blur:passes').get('int', 2),
    'animations_enabled': get('animations:enabled').get('bool', True),
    'touchpad_tap': get('input:touchpad:tap-to-click').get('bool', True),
    'natural_scroll': get('input:touchpad:natural_scroll').get('bool', True),
    'disable_while_typing': get('input:touchpad:disable_while_typing').get('bool', True),
    'sensitivity': get('input:sensitivity').get('float', 0.0)
}
print(json.dumps(res))
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.hyprConfig = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    Process {
        id: keybindsProc
        running: false
        command: ["python3", Quickshell.shellDir + "/scripts/keybinds_parser.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybindsList = JSON.parse(this.text.trim());
                    contentFlick.contentY = 0;
                } catch (e) {}
            }
        }
    }

    Process {
        id: themeScanProc
        running: false
        command: ["bash", "-c", "for d in \"$HOME\"/.config/themes/*/; do n=$(basename \"$d\"); a=$(jq -r '.primary // .accent // empty' \"$d\"/quickshell-colors.json 2>/dev/null); if [ -n \"$a\" ]; then printf '%s|%s\\n' \"$n\" \"$a\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                this.text.trim().split("\n").forEach(function(line) {
                    var parts = line.split("|");
                    if (parts.length >= 2 && parts[0].length > 0)
                        out.push({ "name": parts[0], "accent": parts[1] });
                });
                root.themePresets = out;
            }
        }
    }

    Process {
        id: powerProfileProc
        running: false
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.powerProfile = this.text.trim()
        }
    }

    Timer {
        id: toastTimer
        interval: 1600
        repeat: false
        onTriggered: root.toast = ""
    }

    Timer {
        id: jumpTimer
        interval: 60
        repeat: false
        onTriggered: root.revealRow(root.searchTargetRow)
    }

    Timer {
        id: findGlowFlash
        interval: 1600
        repeat: false
        onTriggered: findGlow.visible = false
    }

    Component.onCompleted: {
        hyprQueryProc.running = true;
        keybindsProc.running = true;
        wifiStatusProc.running = true;
        themeScanProc.running = true;
        powerProfileProc.running = true;
        contentFlick.contentY = 0;
        root.rebuildSearchIndex();
    }

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
            hyprQueryProc.running = true;
            keybindsProc.running = true;
            wifiStatusProc.running = true;
            themeScanProc.running = true;
            powerProfileProc.running = true;
            contentFlick.contentY = 0;
            root.rebuildSearchIndex();
        }
    }

    onActivePageIdChanged: contentFlick.contentY = 0

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            searchInput.forceActiveFocus();
            searchInput.selectAll();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Slash && !searchInput.activeFocus && !root.searching) {
            searchInput.forceActiveFocus();
            event.accepted = true;
            return;
        }
        if (root.searching) {
            if (event.key === Qt.Key_Down) {
                root.moveSearchSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.moveSearchSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.openSearchResult(root.searchSelected);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                searchInput.text = "";
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    // ─── Components ───────────────────────────────────────────
    component SectionLabel: Text {
        font.family: root.fontBody
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        font.capitalization: Font.AllUppercase
        color: root.alpha(root.cMuted, 0.62)
        topPadding: 2
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: root.cHairlineSoft
    }

    component NavRow: Rectangle {
        id: nav
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal activated()

        width: parent ? parent.width : 0
        height: 30
        radius: root.radiusRow
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: nav.selected || navHover.containsMouse || navHover.activeFocus ? root.cRowHover : "transparent"
            Behavior on color { ColorAnimation { duration: root.motion(120) } }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: nav.selected
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.alpha(root.cAccent, 0.16) }
                GradientStop { position: 1.0; color: root.alpha(root.cAccent, 0.03) }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: nav.icon
                iconSize: nav.selected ? 17 : 16
                fill: nav.selected ? 1 : 0
                color: nav.selected ? root.cAccent : root.alpha(root.cInk, 0.52)
                Behavior on color { ColorAnimation { duration: root.motion(120) } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nav.label
                font.family: root.fontBody
                font.pixelSize: root.typeLabel
                font.weight: nav.selected ? Font.DemiBold : Font.Medium
                color: nav.selected ? root.alpha(root.cInk, 0.96) : root.alpha(root.cInk, 0.68)
            }
        }

        MouseArea {
            id: navHover
            anchors.fill: parent
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.PageTab
            Accessible.name: nav.label
            onClicked: { nav.forceActiveFocus(); nav.activated(); }
            Keys.onReturnPressed: nav.activated()
            Keys.onSpacePressed: nav.activated()
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        signal picked()

        width: chipText.implicitWidth + 22
        height: 26
        radius: 7
        color: chip.active ? root.alpha(root.cAccent, 0.18)
                           : chipHover.activeFocus ? root.cRowHover
                           : (chipHover.containsMouse ? root.cRowHover : root.tint(lightTheme ? 0.03 : 0.045))
        Behavior on color { ColorAnimation { duration: root.motion(120) } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: root.fontBody
            font.pixelSize: root.typeFootnote
            font.weight: chip.active ? Font.DemiBold : Font.Medium
            color: chip.active ? root.alpha(root.cInk, 0.95) : root.alpha(root.cInk, 0.62)
        }

        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.RadioButton
            Accessible.name: chip.label
            Accessible.checked: chip.active
            Accessible.onPressAction: chip.picked()
            onClicked: { chip.forceActiveFocus(); chip.picked(); }
            Keys.onReturnPressed: chip.picked()
            Keys.onSpacePressed: chip.picked()
        }
    }

    component ToggleSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled(bool value)

        width: 40
        height: 22
        radius: 11
        color: sw.checked ? root.cAccent : root.tint(lightTheme ? 0.09 : 0.12)
        Behavior on color { ColorAnimation { duration: root.motion(140) } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 2.5
            x: sw.checked ? sw.width - 19 : 3
            color: sw.checked ? root.cOnAccent : root.alpha(root.cInk, 0.8)
            Behavior on x { NumberAnimation { duration: root.motion(160); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: root.motion(140) } }
        }

        MouseArea {
            id: swMouse
            anchors.fill: parent
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.CheckBox
            Accessible.name: "Toggle"
            Accessible.checked: sw.checked
            Accessible.onPressAction: sw.toggled(!sw.checked)
            onClicked: { sw.forceActiveFocus(); sw.toggled(!sw.checked); }
            Keys.onReturnPressed: sw.toggled(!sw.checked)
            Keys.onSpacePressed: sw.toggled(!sw.checked)
        }
    }

    component ActionButton: Rectangle {
        id: btn
        property string label: ""
        property string icon: ""
        property bool primary: false
        signal clicked()

        width: btnRow.implicitWidth + 24
        height: 30
        radius: 8
        color: primary ? (btnHover.containsMouse ? Qt.lighter(root.cAccent, 1.06) : root.cAccent)
                       : (btnHover.containsMouse || btnHover.activeFocus ? root.cRowHover : root.cRowSurface)
        opacity: enabled ? 1.0 : 0.45
        Behavior on color { ColorAnimation { duration: root.motion(120) } }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                visible: btn.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: btn.icon
                iconSize: 14
                color: btn.primary ? root.cOnAccent : root.alpha(root.cInk, 0.72)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                font.family: root.fontBody
                font.pixelSize: root.typeFootnote
                font.weight: Font.DemiBold
                color: btn.primary ? root.cOnAccent : root.alpha(root.cInk, 0.82)
            }
        }

        MouseArea {
            id: btnHover
            anchors.fill: parent
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: btn.label
            Accessible.onPressAction: btn.clicked()
            onClicked: { btn.forceActiveFocus(); btn.clicked(); }
            Keys.onReturnPressed: btn.clicked()
            Keys.onSpacePressed: btn.clicked()
        }
    }

    component KeyCap: Rectangle {
        property string label: ""
        height: 20
        width: capText.implicitWidth + 12
        radius: 5
        color: root.tint(0.09)

        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.label
            font.family: root.fontBody
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            color: root.alpha(root.cInk, 0.8)
        }
    }

    component SettingRow: Item {
        id: row
        objectName: "settingRow"
        property string title: ""
        property string desc: ""
        default property alias control: slot.data

        width: parent ? parent.width : 0
        height: row.desc.length > 0 ? 58 : 46

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: rowHover.containsMouse ? root.cRowHover : "transparent"
            Behavior on color { ColorAnimation { duration: root.motion(120) } }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Column {
            id: labels
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - slot.width - 24)
            spacing: 2

            Text {
                text: row.title
                width: labels.width
                elide: Text.ElideRight
                font.family: root.fontBody
                font.pixelSize: root.typeLabel
                font.weight: Font.Medium
                color: root.alpha(root.cInk, 0.93)
            }
            Text {
                visible: row.desc.length > 0
                text: row.desc
                width: labels.width
                elide: Text.ElideRight
                font.family: root.fontBody
                font.pixelSize: root.typeMeta
                color: root.alpha(root.cMuted, 0.78)
            }
        }

        Row {
            id: slot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    component Card: Rectangle {
        id: card
        default property alias body: inner.data

        width: parent ? parent.width : 0
        height: inner.implicitHeight + 24
        radius: root.radiusTile
        color: root.cRowSurface

        Column {
            id: inner
            x: 14
            y: 12
            width: card.width - 28
            spacing: 0
        }
    }

    // ─── Background ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.alpha(root.cBg, 0.985)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.tint(root.lightTheme ? 0.0 : 0.05) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
    }

    // ─── Sidebar ──────────────────────────────────────────────
    Rectangle {
        id: sidebar
        x: 12
        y: 12
        width: 248
        height: parent.height - 24
        radius: 16
        color: root.cSidebarSurface

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.alpha(root.cAccent, 0.035) }
                GradientStop { position: 0.45; color: "transparent" }
            }
        }

        Item {
            id: brand
            x: 16
            y: 18
            width: parent.width - 32
            height: 34

            Rectangle {
                id: brandMark
                width: 32
                height: 32
                radius: 10
                color: root.alpha(root.cAccent, 0.14)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "auto_awesome"
                    iconSize: 16
                    fill: 1
                    color: root.cAccent
                }
            }

            Column {
                anchors.left: brandMark.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Dynamic You"
                    font.family: root.fontBody
                    font.pixelSize: root.typeLabel + 1
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.1
                    color: root.cInk
                }
                Text {
                    text: "SHELL SETTINGS"
                    font.family: root.fontBody
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                    color: root.alpha(root.cMuted, 0.62)
                }
            }
        }

        Rectangle {
            id: searchBox
            x: 14
            y: 66
            width: parent.width - 28
            height: 34
            radius: 9
            color: searchInput.activeFocus ? root.tint(0.075) : root.tint(0.045)
            Behavior on color { ColorAnimation { duration: root.motion(140) } }

            MaterialSymbol {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                iconSize: 15
                color: searchInput.activeFocus ? root.cAccent : root.alpha(root.cMuted, 0.7)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: "Find a setting…"
                visible: searchInput.text.length === 0
                font.family: root.fontBody
                font.pixelSize: root.typeMeta
                color: root.alpha(root.cMuted, 0.62)
            }

            KeyCap {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                label: "ctrl f"
            }

            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.fontBody
                font.pixelSize: root.typeMeta
                color: root.cInk
                selectionColor: root.alpha(root.cAccent, 0.4)
                selectedTextColor: root.cInk
                clip: true
                Accessible.role: Accessible.EditableText
                Accessible.name: "Search settings"
                onTextChanged: {
                    root.searchQuery = text;
                    root.refreshSearch();
                }
                Keys.onEscapePressed: {
                    if (text.length > 0) {
                        text = "";
                    } else {
                        root.closeRequested();
                    }
                }
                Keys.onDownPressed: root.moveSearchSelection(1)
                Keys.onUpPressed: root.moveSearchSelection(-1)
                Keys.onReturnPressed: root.openSearchResult(root.searchSelected)
                Keys.onEnterPressed: root.openSearchResult(root.searchSelected)
            }
        }

        Flickable {
            id: navFlick
            x: 8
            y: 114
            width: parent.width - 16
            height: parent.height - 114 - 60
            contentWidth: width
            contentHeight: navColumn.implicitHeight + 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: navColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.navGroups

                    Column {
                        width: navColumn.width
                        spacing: 1

                        Item {
                            width: parent.width
                            height: 26

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 5
                                text: modelData.name
                                font.family: root.fontBody
                                font.pixelSize: root.typeCaption
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.35
                                font.capitalization: Font.AllUppercase
                                color: root.alpha(root.cMuted, 0.55)
                            }
                        }

                        Repeater {
                            model: modelData.pages

                            NavRow {
                                icon: modelData.icon
                                label: modelData.name
                                selected: root.activePageId === modelData.id
                                opacity: root.searching && !root.pageMatches(modelData.name, "") ? 0.32 : 1.0
                                Behavior on opacity { NumberAnimation { duration: root.motion(140) } }
                                onActivated: root.setPage(modelData.id)
                            }
                        }

                        Item { width: 1; height: 10 }
                    }
                }
            }
        }

        Item {
            id: sidebarFooter
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            height: 30

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: root.cAccent
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: String((typeof Theme !== "undefined" && Theme.currentThemeName) ? Theme.currentThemeName : "Custom")
                font.family: root.fontBody
                font.pixelSize: 11
                font.weight: Font.Medium
                color: root.alpha(root.cMuted, 0.85)
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Hyprland"
                font.family: root.fontBody
                font.pixelSize: 10
                color: root.alpha(root.cMuted, 0.5)
            }
        }
    }

    // ─── Content pane ────────────────────────────────────────
    Rectangle {
        id: contentPane
        x: sidebar.x + sidebar.width + 10
        y: 12
        width: parent.width - x - 12
        height: parent.height - 24
        radius: root.radiusPanel
        color: root.cPaneSurface
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.alpha(root.cAccent, 0.022) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        Rectangle {
            id: closeBtn
            width: 30
            height: 30
            radius: 8
            color: closeHover.containsMouse ? root.alpha("#ff5f57", 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: root.motion(120) } }
            x: parent.width - 46
            y: 18

            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: 16
                color: closeHover.containsMouse ? "#ff8a80" : root.alpha(root.cInk, 0.5)
            }

            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                activeFocusOnTab: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: "Close settings"
                onClicked: root.closeRequested()
                Keys.onReturnPressed: root.closeRequested()
                Keys.onSpacePressed: root.closeRequested()
            }
        }

        Item {
            id: pageHeader
            x: 28
            y: 22
            width: parent.width - 76
            height: 100

            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                width: parent.width - 148
                spacing: 3

                Text {
                    text: root.meta.group
                    font.family: root.fontBody
                    font.pixelSize: root.typeCaption
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                    color: root.alpha(root.cAccent, 0.9)
                }

                Text {
                    text: root.meta.title
                    width: parent.width
                    elide: Text.ElideRight
                    font.family: root.fontBody
                    font.pixelSize: root.typeTitle
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.6
                    color: root.cInk
                }

                Text {
                    text: root.meta.desc
                    width: parent.width
                    elide: Text.ElideRight
                    font.family: root.fontBody
                    font.pixelSize: root.typeMeta
                    color: root.alpha(root.cMuted, 0.8)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 8

                ActionButton {
                    visible: root.activePageId === "themes"
                    label: "Reload"
                    icon: "refresh"
                    onClicked: { if (typeof Theme !== "undefined" && Theme.reload) Theme.reload(); }
                }

                ActionButton {
                    visible: root.activePageId === "keybinds"
                    label: "Reload binds"
                    icon: "refresh"
                    onClicked: keybindsProc.running = true
                }
            }
        }

        Rectangle {
            x: 28
            y: 124
            width: parent.width - 56
            height: 1
            color: root.cHairlineSoft
        }

        Flickable {
            id: contentFlick
            y: 125
            width: parent.width
            height: parent.height - 125
            contentWidth: width
            contentHeight: Math.max(pagesColumn.implicitHeight + 48, searchResults.implicitHeight + 48)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: pagesColumn
                x: 28
                y: 20
                width: contentFlick.width - 56
                spacing: 18
                visible: !root.searching

                // ── Colors & Themes ──────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "themes"

                    SectionLabel { text: "Active" }

                    Card {
                        SettingRow {
                            title: "Theme preset"
                            desc: "Accent, surfaces and contrast are rebuilt from this theme"
                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.cAccent
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String((typeof Theme !== "undefined" && Theme.currentThemeName) ? Theme.currentThemeName : "Custom")
                                    font.family: root.fontBody
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: root.alpha(root.cInk, 0.9)
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Accent follows the theme"
                            desc: "Wallpapers do not generate Dynamic You colors"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [root.cAccent,
                                            (typeof Theme !== "undefined" && Theme.m3) ? Theme.m3.primary_container : root.cAccent,
                                            (typeof Theme !== "undefined" && Theme.m3) ? Theme.m3.secondary : root.cAccent,
                                            (typeof Theme !== "undefined" && Theme.m3) ? Theme.m3.tertiary : root.cAccent]

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Presets" }

                    Item {
                        width: parent.width
                        height: themeGrid.implicitHeight

                        Grid {
                            id: themeGrid
                            width: parent.width
                            columns: 3
                            spacing: 10

                            Repeater {
                                model: root.themePresets

                                Rectangle {
                                    id: themeTile
                                    width: (themeGrid.width - 20) / 3
                                    height: 58
                                    radius: 12
                                    readonly property bool current: String(Theme.currentThemeName || "").toLowerCase() === String(modelData.name).toLowerCase()
                                    color: current ? root.alpha(modelData.accent, 0.13)
                                                   : (tileHover.containsMouse ? root.tint(0.07) : root.tint(0.04))

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 9

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.accent
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1
                                            Text {
                                                text: modelData.name
                                                font.family: root.fontBody
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: root.cInk
                                            }
                                            Text {
                                                text: themeTile.current ? "Active" : "Preset"
                                                font.family: root.fontBody
                                                font.pixelSize: 10
                                                color: root.alpha(root.cMuted, 0.75)
                                            }
                                        }
                                    }

                                    MaterialSymbol {
                                        visible: themeTile.current
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "check"
                                        iconSize: 15
                                        color: modelData.accent
                                    }

                                    MouseArea {
                                        id: tileHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (typeof Theme !== "undefined" && Theme.applyPreset)
                                                Theme.applyPreset(modelData.name);
                                            root.flashToast("Applying " + modelData.name + "…");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.themePresets.length === 0
                        text: "No themes found in ~/.config/themes"
                        font.family: root.fontBody
                        font.pixelSize: 11
                        color: root.alpha(root.cMuted, 0.6)
                    }
                }

                // ── Keybinds ─────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 12
                    visible: root.activePageId === "keybinds"

                    Row {
                        spacing: 6
                        Repeater {
                            model: ["All", "Launchers", "Workspaces", "Windows", "Media", "System"]
                            Chip {
                                label: modelData
                                active: root.selectedKeybindCat === modelData
                                onPicked: root.selectedKeybindCat = modelData
                            }
                        }
                    }

                    Card {
                        id: kbCard

                        Item {
                            width: parent.width
                            height: 30

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.filteredKeybinds.length + " binding" + (root.filteredKeybinds.length === 1 ? "" : "s")
                                font.family: root.fontBody
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.alpha(root.cMuted, 0.75)
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "SUPER is your main modifier"
                                font.family: root.fontBody
                                font.pixelSize: 10
                                color: root.alpha(root.cMuted, 0.45)
                            }
                        }

                        Column {
                            visible: keybindsProc.running && root.filteredKeybinds.length === 0
                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: 5
                                Item {
                                    width: parent.width
                                    height: 50

                                    Rectangle {
                                        anchors.top: parent.top
                                        width: parent.width
                                        height: 1
                                        color: root.cHairlineSoft
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2
                                        spacing: 12

                                        Rectangle { width: 42; height: 20; radius: 5; color: root.tint(0.055) }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 34 + (index % 3) * 16
                                            height: 11
                                            radius: 4
                                            color: root.tint(0.045)
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 96 + (index % 4) * 24
                                            height: 11
                                            radius: 4
                                            color: root.tint(0.035)
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.filteredKeybinds

                            Item {
                                id: kbRowItem
                                readonly property var kb: modelData
                                width: parent.width
                                height: 50

                                Rectangle {
                                    anchors.top: parent.top
                                    width: parent.width
                                    height: 1
                                    color: root.tint(0.05)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: kbHover.containsMouse ? root.tint(0.045) : "transparent"
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Repeater {
                                        model: kbRowItem.kb.keys
                                        delegate: KeyCap { label: modelData }
                                    }
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 186
                                    anchors.right: catBadge.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: kbRowItem.kb.desc
                                        elide: Text.ElideRight
                                        font.family: root.fontBody
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: root.alpha(root.cInk, 0.92)
                                    }
                                    Text {
                                        width: parent.width
                                        visible: text.length > 0
                                        text: kbRowItem.kb.cmd || ""
                                        elide: Text.ElideRight
                                        font.family: root.fontMono
                                        font.pixelSize: 10
                                        color: root.alpha(root.cMuted, 0.62)
                                    }
                                }

                                Rectangle {
                                    id: catBadge
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: catText.implicitWidth + 14
                                    height: 19
                                    radius: 6
                                    color: root.tint(0.05)

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: kbRowItem.kb.cat || "System"
                                        font.family: root.fontBody
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: root.alpha(root.cMuted, 0.75)
                                    }
                                }

                                MouseArea {
                                    id: kbHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (kbRowItem.kb.cmd) {
                                            root.runShellCmd(["bash", "-c", "printf '%s' \"$0\" | wl-copy", kbRowItem.kb.cmd]);
                                            root.flashToast("Command copied");
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 40
                            visible: root.filteredKeybinds.length === 0 && !keybindsProc.running
                            Text {
                                anchors.centerIn: parent
                                text: "No bindings match this filter."
                                font.family: root.fontBody
                                font.pixelSize: root.typeFootnote
                                color: root.alpha(root.cMuted, 0.65)
                            }
                        }
                    }
                }

                // ── Tiling ───────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "tiling"

                    SectionLabel { text: "Geometry" }

                    Card {
                        SettingRow {
                            title: "Window border"
                            desc: "Applies to every tiled and floating window"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [1, 2, 3, 4]
                                    Chip {
                                        label: modelData + " px"
                                        active: Number(root.hyprConfig.border_size) === modelData
                                        onPicked: {
                                            root.setHyprKeyword("general:border_size", modelData);
                                            root.hyprConfig.border_size = modelData;
                                        }
                                    }
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Outer gaps"
                            desc: "Space between windows and the screen edge"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [6, 10, 14, 20]
                                    Chip {
                                        label: modelData + " px"
                                        active: Number(root.hyprConfig.gaps_out) === modelData
                                        onPicked: {
                                            root.setHyprKeyword("general:gaps_out", modelData);
                                            root.hyprConfig.gaps_out = modelData;
                                        }
                                    }
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Inner gaps"
                            desc: "Space between neighbouring windows"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [2, 6, 10]
                                    Chip {
                                        label: modelData + " px"
                                        active: Number(root.hyprConfig.gaps_in) === modelData
                                        onPicked: {
                                            root.setHyprKeyword("general:gaps_in", modelData);
                                            root.hyprConfig.gaps_in = modelData;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Animations ───────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "animations"

                    SectionLabel { text: "Effects" }

                    Card {
                        SettingRow {
                            title: "Window animations"
                            desc: "Open and close transitions from your Hyprland config"
                            ToggleSwitch {
                                checked: !!root.hyprConfig.animations_enabled
                                onToggled: function(value) {
                                    root.setHyprKeyword("animations:enabled", value ? 1 : 0);
                                    root.hyprConfig.animations_enabled = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Blur"
                            desc: "Frosted glass behind translucent surfaces"
                            ToggleSwitch {
                                checked: !!root.hyprConfig.blur_enabled
                                onToggled: function(value) {
                                    root.setHyprKeyword("decoration:blur:enabled", value ? 1 : 0);
                                    root.hyprConfig.blur_enabled = value ? 1 : 0;
                                }
                            }
                        }
                    }
                }

                // ── Input ────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "input"

                    SectionLabel { text: "Touchpad" }

                    Card {
                        SettingRow {
                            title: "Tap to click"
                            desc: "Lighter taps register as clicks"
                            ToggleSwitch {
                                checked: !!root.hyprConfig.touchpad_tap
                                onToggled: function(value) {
                                    root.setHyprKeyword("input:touchpad:tap-to-click", value ? 1 : 0);
                                    root.hyprConfig.touchpad_tap = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Natural scrolling"
                            desc: "Mimics touch screens and macOS tracks"
                            ToggleSwitch {
                                checked: !!root.hyprConfig.natural_scroll
                                onToggled: function(value) {
                                    root.setHyprKeyword("input:touchpad:natural_scroll", value ? 1 : 0);
                                    root.hyprConfig.natural_scroll = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Disable while typing"
                            desc: "Ignores accidental palm touches"
                            ToggleSwitch {
                                checked: !!root.hyprConfig.disable_while_typing
                                onToggled: function(value) {
                                    root.setHyprKeyword("input:touchpad:disable_while_typing", value ? 1 : 0);
                                    root.hyprConfig.disable_while_typing = value;
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Pointer" }

                    Card {
                        SettingRow {
                            title: "Pointer sensitivity"
                            desc: "Negative slows the cursor, positive speeds it up"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [-0.5, 0, 0.5, 1.0]
                                    Chip {
                                        label: (modelData > 0 ? "+" : "") + modelData.toFixed(1)
                                        active: Math.abs(Number(root.hyprConfig.sensitivity) - modelData) < 0.01
                                        onPicked: {
                                            root.setHyprKeyword("input:sensitivity", modelData);
                                            root.hyprConfig.sensitivity = modelData;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Notch ────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "notch"

                    SectionLabel { text: "Island geometry" }

                    Row {
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: [
                                { "label": "Idle", "value": "184 × 38", "icon": "line_weight" },
                                { "label": "Hover", "value": "440 × 44", "icon": "open_in_full" },
                                { "label": "Expanded", "value": "840 × 480", "icon": "unfold_more" }
                            ]

                            Rectangle {
                                width: (parent.width - 20) / 3
                                height: 62
                                radius: 13
                                color: root.tint(0.04)

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.label
                                        font.family: root.fontBody
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1
                                        font.capitalization: Font.AllUppercase
                                        color: root.alpha(root.cMuted, 0.65)
                                    }
                                    Text {
                                        text: modelData.value
                                        font.family: root.fontBody
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        color: root.cInk
                                    }
                                }

                                MaterialSymbol {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    iconSize: 17
                                    color: root.alpha(root.cAccent, 0.65)
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Behaviour" }

                    Card {
                        SettingRow {
                            title: "Popups open under the island"
                            desc: "Wi-Fi, Bluetooth and battery panels grow out of the notch"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.barPopupNotched : true
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.barPopupNotched = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Notch flare"
                            desc: "Draws a soft accent glow around the island"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.barNotchFlare : true
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.barNotchFlare = value;
                                }
                            }
                        }
                    }
                }

                // ── Bar ──────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "bar"

                    SectionLabel { text: "Visibility" }

                    Card {
                        SettingRow {
                            title: "Top bar"
                            desc: "Show the bar above windows"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.barEnabled : true
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.barEnabled = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Auto hide"
                            desc: "Slide the bar away when nothing is open"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.barAutoHide : false
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.barAutoHide = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Reveal on hover"
                            desc: "Bring the bar back when the pointer reaches the top edge"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.barHoverOpen : true
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.barHoverOpen = value;
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Clock" }

                    Card {
                        SettingRow {
                            title: "24-hour time"
                            desc: "Show 21:40 instead of 9:40 PM"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.clock24h : true
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.clock24h = value;
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Seconds"
                            desc: "Include seconds in the bar clock"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.clockShowSeconds : false
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.clockShowSeconds = value;
                                }
                            }
                        }
                    }
                }

                // ── Launcher ─────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "launcher"

                    SectionLabel { text: "Clipboard" }

                    Card {
                        SettingRow {
                            title: "Clipboard history"
                            desc: "SUPER + V reopens everything you copied recently"
                            ToggleSwitch {
                                checked: (typeof Prefs !== "undefined") ? !!Prefs.clipboardEnabled : true
                                onToggled: function(value) {
                                    if (typeof Prefs !== "undefined") Prefs.clipboardEnabled = value;
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Launcher shortcuts" }

                    Card {
                        Repeater {
                            model: root.keybindsList.filter(function(kb) { return kb.cat === "Launchers"; }).slice(0, 6)

                            Item {
                                width: parent.width
                                height: 44

                                Rectangle {
                                    anchors.top: parent.top
                                    width: parent.width
                                    height: 1
                                    color: root.tint(0.05)
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Repeater {
                                        model: modelData.keys
                                        delegate: KeyCap { label: modelData }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 186
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.desc
                                    elide: Text.ElideRight
                                    font.family: root.fontBody
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: root.alpha(root.cInk, 0.88)
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 38
                            visible: root.keybindsList.length === 0
                            Text {
                                anchors.centerIn: parent
                                text: "Loading bindings…"
                                font.family: root.fontBody
                                font.pixelSize: 11
                                color: root.alpha(root.cMuted, 0.6)
                            }
                        }
                    }
                }

                // ── Battery ──────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "battery"

                    SectionLabel { text: "Power" }

                    Card {
                        SettingRow {
                            title: "Battery"
                            desc: (typeof UPower !== "undefined" && UPower.displayDevice)
                                  ? ("Level " + Math.round(UPower.displayDevice.percentage <= 1 ? UPower.displayDevice.percentage * 100 : UPower.displayDevice.percentage) + "% · "
                                     + (UPower.displayDevice.state === UPowerDeviceState.Charging ? "Charging" : "Discharging"))
                                  : "Battery information is unavailable"
                            MaterialSymbol {
                                text: "battery_5_bar"
                                iconSize: 20
                                color: root.alpha(root.cAccent, 0.8)
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Power profile"
                            desc: "Controls the CPU governor for battery or speed"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: ["power-saver", "balanced", "performance"]
                                    Chip {
                                        label: modelData
                                        active: String(root.powerProfile).toLowerCase() === modelData
                                        onPicked: {
                                            root.runShellCmd(["powerprofilesctl", "set", modelData]);
                                            root.powerProfile = modelData;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Display refresh" }

                    Card {
                        SettingRow {
                            title: "Refresh rate"
                            desc: "60 Hz saves power · 144 Hz feels fluid"
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [60, 144]
                                    Chip {
                                        label: modelData + " Hz"
                                        active: false
                                        onPicked: root.runShellCmd(["hyprctl", "keyword", "monitor", "eDP-1,1920x1200@" + modelData + ",0x0,1.0"])
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Network ──────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "network"

                    SectionLabel { text: "Wi-Fi" }

                    Card {
                        SettingRow {
                            title: "Wi-Fi radio"
                            desc: root.wifiStatus.connected_ssid
                                  ? ("Connected to " + root.wifiStatus.connected_ssid)
                                  : (root.wifiStatus.radio ? "Not connected" : "Radio is off")
                            ToggleSwitch {
                                checked: !!root.wifiStatus.radio
                                onToggled: {
                                    root.runShellCmd(["python3", Quickshell.shellDir + "/scripts/wifi_manager.py", "toggle-radio"]);
                                    wifiReloadTimer.restart();
                                }
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Interface"
                            desc: (root.wifiStatus.active_dev || "wlan0") + " · " + (root.wifiStatus.active_ip || "no address")
                            Row {
                                spacing: 6
                                ActionButton {
                                    label: "Scan"
                                    icon: "wifi_find"
                                    onClicked: {
                                        root.runShellCmd(["python3", Quickshell.shellDir + "/scripts/wifi_manager.py", "scan"]);
                                        wifiReloadTimer.restart();
                                    }
                                }
                                ActionButton {
                                    label: "Refresh"
                                    icon: "refresh"
                                    onClicked: wifiStatusProc.running = true
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Bluetooth" }

                    Card {
                        SettingRow {
                            title: "Bluetooth adapter"
                            desc: (root.btAdapter && root.btAdapter.enabled)
                                  ? ((root.btAdapter.name || "Adapter") + " · on")
                                  : "Off · enable to connect devices"
                            ToggleSwitch {
                                checked: !!(root.btAdapter && root.btAdapter.enabled)
                                onToggled: function(value) {
                                    if (root.btAdapter) root.btAdapter.enabled = value;
                                }
                            }
                        }
                    }
                }

                // ── Displays ─────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "displays"

                    SectionLabel { text: "Panel" }

                    Card {
                        SettingRow {
                            title: "eDP-1"
                            desc: "1920 × 1200 · 144 Hz · scale 1.00×"
                            Text {
                                text: "CSOT MNG007QX2-2"
                                font.family: root.fontBody
                                font.pixelSize: 10
                                color: root.alpha(root.cMuted, 0.7)
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Night light"
                            desc: "Warm the panel after sunset"
                            ToggleSwitch {
                                checked: root.nightLightOn
                                onToggled: function(value) {
                                    root.nightLightOn = value;
                                    if (value) root.runShellCmd(["bash", "-c", "pkill hyprsunset 2>/dev/null; hyprsunset -t 4500 &"]);
                                    else root.runShellCmd(["bash", "-c", "pkill hyprsunset 2>/dev/null || true"]);
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Audio" }

                    Card {
                        SettingRow {
                            title: "Output volume"
                            desc: "Adjust with the Audio module in the notch"
                            Text {
                                text: "Live in the notch"
                                font.family: root.fontBody
                                font.pixelSize: 10
                                color: root.alpha(root.cMuted, 0.6)
                            }
                        }
                    }
                }

                // ── About ────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.activePageId === "about"

                    SectionLabel { text: "This desktop" }

                    Row {
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: [
                                { "k": "Compositor", "v": "Hyprland" },
                                { "k": "Shell", "v": "Quickshell" },
                                { "k": "Theme", "v": String((typeof Theme !== "undefined" && Theme.currentThemeName) ? Theme.currentThemeName : "Custom") },
                                { "k": "User", "v": Quickshell.env("USER") || "kuro" }
                            ]

                            Rectangle {
                                width: (parent.width - 30) / 4
                                height: 58
                                radius: 13
                                color: root.tint(0.04)

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.k
                                        font.family: root.fontBody
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1
                                        font.capitalization: Font.AllUppercase
                                        color: root.alpha(root.cMuted, 0.6)
                                    }
                                    Text {
                                        text: modelData.v
                                        font.family: root.fontBody
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: root.cInk
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Quick actions" }

                    Card {
                        SettingRow {
                            title: "Restart shell"
                            desc: "Reloads every module without restarting Hyprland"
                            ActionButton {
                                label: "Restart"
                                icon: "refresh"
                                onClicked: root.runShellCmd(["bash", "-c", "quickshell kill && sleep 0.4 && quickshell -d &"])
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Reload Hyprland"
                            desc: "Re-reads the compositor configuration"
                            ActionButton {
                                label: "Reload"
                                icon: "restart_alt"
                                onClicked: root.runShellCmd(["hyprctl", "reload"])
                            }
                        }

                        Divider {}

                        SettingRow {
                            title: "Settings file"
                            desc: "~/git/dynamic_you/quickshell/modules/SettingsWindow.qml"
                            Text {
                                text: "QML"
                                font.family: root.fontBody
                                font.pixelSize: 10
                                color: root.alpha(root.cMuted, 0.6)
                            }
                        }
                    }
                }

                Item { width: 1; height: 6 }
            }

            Column {
                id: searchResults
                x: 28
                y: 20
                width: contentFlick.width - 56
                spacing: 2
                visible: root.searching

                Text {
                    text: root.searchResults.length + (root.searchResults.length === 1 ? " setting" : " settings") + " matches “" + root.searchQuery.trim() + "”"
                    font.family: root.fontBody
                    font.pixelSize: root.typeFootnote
                    font.weight: Font.DemiBold
                    color: root.alpha(root.cMuted, 0.7)
                    bottomPadding: 10
                }

                Repeater {
                    model: root.searchResults

                    Rectangle {
                        id: resultRow
                        required property var modelData
                        required property int index
                        width: searchResults.width
                        height: 54
                        radius: 10
                        color: root.searchSelected === resultRow.index
                               ? root.alpha(root.cAccent, 0.10)
                               : (resultHover.containsMouse ? root.cRowHover : "transparent")
                        Behavior on color { ColorAnimation { duration: root.motion(100) } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: resultRow.modelData.row ? "tune" : "dashboard"
                                iconSize: 16
                                color: root.alpha(root.cAccent, 0.85)
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 70
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: resultRow.modelData.title
                                    elide: Text.ElideRight
                                    font.family: root.fontBody
                                    font.pixelSize: root.typeLabel
                                    font.weight: Font.Medium
                                    color: root.alpha(root.cInk, 0.92)
                                }
                                Text {
                                    width: parent.width
                                    text: root.pageLabel(resultRow.modelData.page) + (resultRow.modelData.desc.length > 0 ? " · " + resultRow.modelData.desc : "")
                                    elide: Text.ElideRight
                                    font.family: root.fontBody
                                    font.pixelSize: root.typeFootnote
                                    color: root.alpha(root.cMuted, 0.72)
                                }
                            }
                        }

                        MaterialSymbol {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "arrow_outward"
                            iconSize: 14
                            color: root.alpha(root.cMuted, 0.5)
                        }

                        MouseArea {
                            id: resultHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: resultRow.modelData.title
                            onClicked: root.openSearchResult(resultRow.index)
                        }
                    }
                }

                Item {
                    visible: root.searchResults.length === 0
                    width: parent.width
                    height: 250

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        MaterialSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "search_off"
                            iconSize: 26
                            color: root.alpha(root.cMuted, 0.45)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No setting matches “" + root.searchQuery.trim() + "”"
                            font.family: root.fontBody
                            font.pixelSize: root.typeLabel
                            font.weight: Font.Medium
                            color: root.alpha(root.cInk, 0.75)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Try a control name like blur, gaps, battery or keybind"
                            font.family: root.fontBody
                            font.pixelSize: root.typeMeta
                            color: root.alpha(root.cMuted, 0.65)
                        }
                    }
                }
            }

            Rectangle {
                id: findGlow
                visible: false
                z: 100
                radius: 10
                color: root.alpha(root.cAccent, 0.10)
            }
        }
    }

    // ─── Toast ────────────────────────────────────────────────
    Rectangle {
        id: toastPill
        visible: root.toast.length > 0
        x: contentPane.x + (contentPane.width - width) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: toastRow.implicitWidth + 32
        height: 36
        radius: 10
        color: root.alpha(root.cBg, 0.97)

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: root.cAccent
            }

            Text {
                id: toastText
                anchors.verticalCenter: parent.verticalCenter
                text: root.toast
                font.family: root.fontBody
                font.pixelSize: root.typeMeta
                font.weight: Font.Medium
                color: root.cInk
            }
        }
    }
}
