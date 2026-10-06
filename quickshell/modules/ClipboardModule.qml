import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: clipModule
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // Material You (Material 3) Tonal Palette
    readonly property color colAccent: Theme.accent ?? "#89b4fa"
    readonly property color colOnAccent: "#0a0e14"
    readonly property color colAccentContainer: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.18)
    readonly property color colSurface: "#000000"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.05)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.09)
    readonly property color colCardActive: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.16)
    readonly property color colChipBg: Qt.rgba(255, 255, 255, 0.08)
    readonly property color colText: "#f8fafc"
    readonly property color colSubtext: Qt.rgba(255, 255, 255, 0.65)
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.38)
    readonly property color colGreen: "#51cf66"
    readonly property color colRed: "#f87171"
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    property alias searchInput: searchInput
    property var allClips: []
    property string activeFilterChip: "all" // "all", "text", "image"
    ListModel { id: clipModel }

    readonly property int calculatedCount: clipModel.count
    readonly property int imageClipCount: {
        var cnt = 0;
        for (var i = 0; i < allClips.length; i++) {
            if (allClips[i].isImage) cnt++;
        }
        return cnt;
    }
    readonly property int textClipCount: Math.max(0, allClips.length - imageClipCount)

    function refresh() {
        if (clipScanner.running) clipScanner.running = false;
        clipScanner.running = true;
    }

    function applyFilter() {
        clipModel.clear();
        var query = searchInput.text.toLowerCase().trim();
        for (var i = 0; i < allClips.length; i++) {
            var item = allClips[i];
            var matchesChip = (clipModule.activeFilterChip === "all") ||
                              (clipModule.activeFilterChip === "image" && item.isImage) ||
                              (clipModule.activeFilterChip === "text" && !item.isImage);
            if (!matchesChip) continue;

            if (query === "" || item.description.toLowerCase().includes(query) || (item.isImage && "image".includes(query))) {
                clipModel.append(item);
            }
        }
        if (clipModel.count > 0) clipList.currentIndex = 0;
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "clipboard") {
                clipModule.refresh();
            }
        }
    }

    onVisibleChanged: {
        if (visible && root.activeMode === "clipboard") {
            clipModule.refresh();
        }
    }

    Component.onCompleted: clipModule.refresh()

    Process {
        id: clipScanner
        running: false
        command: ["sh", "-c", `
            python3 -c "
import subprocess, os, re

thumb_dir = '/tmp/cliphist_thumbs'
os.makedirs(thumb_dir, exist_ok=True)

try:
    p = subprocess.run(['cliphist', 'list'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    raw = p.stdout.decode('utf-8', errors='ignore')
except Exception:
    raw = ''

lines = [l for l in raw.splitlines() if l.strip()][:60]

for line in lines:
    parts = line.split('\t', 1)
    if len(parts) < 2:
        continue
    c_id = parts[0].strip()
    c_desc = parts[1].strip()
    
    is_img = ('binary data' in c_desc.lower() or bool(re.search(r'\\b(png|jpe?g|webp|bmp|gif)\\b', c_desc, re.I)))
    img_path = ''
    
    if is_img:
        img_path = f'{thumb_dir}/clip_{c_id}.png'
        if not os.path.exists(img_path) or os.path.getsize(img_path) == 0:
            try:
                dec = subprocess.run(['cliphist', 'decode', c_id], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=0.5)
                if dec.stdout:
                    with open(img_path, 'wb') as f:
                        f.write(dec.stdout)
            except Exception:
                pass
        
        if not (os.path.exists(img_path) and os.path.getsize(img_path) > 0):
            img_path = ''

    clean_desc = c_desc.replace('|||', ' ')
    print(f'{c_id}|||{is_img}|||{img_path}|||{clean_desc}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var textRaw = this.text ? this.text.trim() : "";
                if (!textRaw) {
                    clipModule.allClips = [];
                    clipModel.clear();
                    return;
                }

                var lines = textRaw.split("\n");
                var temp = [];

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 4) {
                        temp.push({
                            "clipId": parts[0].trim(),
                            "isImage": (parts[1].trim() === "True"),
                            "imgPath": parts[2].trim(),
                            "description": parts[3].trim()
                        });
                    }
                }
                clipModule.allClips = temp;
                clipModule.applyFilter();
            }
        }
    }

    Process { id: clipPaster; running: false }

    function copyItemToTop(id) {
        if (clipPaster.running) clipPaster.running = false;
        clipPaster.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        clipPaster.running = true;
        root.collapseToIdle();
    }

    // ========================================================
    // 1. TOP SEARCH & ACTION BAR (Material You M3 Capsule)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // Back to Utility Button — Circular M3 Pill
        Rectangle {
            width: 40; height: 40; radius: 20
            color: clipBackMouse.containsMouse ? clipModule.colCardHover : clipModule.colChipBg
            border.width: 0
            scale: clipBackMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: 20
                color: clipModule.colText
            }
            MouseArea {
                id: clipBackMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.switchMode("utility", true)
            }
        }

        // Search Bar Capsule
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 21
            color: clipModule.colChipBg
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 10

                MaterialSymbol {
                    text: "search"
                    iconSize: 20
                    color: searchInput.activeFocus ? clipModule.colAccent : clipModule.colMuted
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextField {
                    id: searchInput
                    focus: true
                    Layout.fillWidth: true
                    color: clipModule.colText
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    placeholderText: "Search clipboard history…"
                    placeholderTextColor: clipModule.colMuted
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    background: Item {}

                    onTextChanged: clipModule.applyFilter()

                    Keys.onDownPressed: (event) => {
                        if (clipList.currentIndex < clipModel.count - 1) {
                            clipList.currentIndex++;
                            clipList.positionViewAtIndex(clipList.currentIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    }
                    Keys.onUpPressed: (event) => {
                        if (clipList.currentIndex > 0) {
                            clipList.currentIndex--;
                            clipList.positionViewAtIndex(clipList.currentIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: root.collapseToIdle()
                    Keys.onReturnPressed: {
                        if (clipModel.count > 0 && clipList.currentIndex >= 0) {
                            copyItemToTop(clipModel.get(clipList.currentIndex).clipId);
                        }
                    }
                }

                // Clear Search Text Icon
                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 26; height: 26; radius: 13
                    color: clearTextMouse.containsMouse ? clipModule.colCardHover : "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: clipModule.colSubtext
                    }
                    MouseArea {
                        id: clearTextMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Clear All History — Material 3 Tonal Error Pill
        Rectangle {
            Layout.preferredHeight: 42
            Layout.preferredWidth: clearRow.implicitWidth + 26
            radius: 21
            color: clearMouse.containsMouse ? Qt.alpha(clipModule.colRed, 0.25) : Qt.alpha(clipModule.colRed, 0.15)
            border.width: 0
            Behavior on color { ColorAnimation { duration: 140 } }

            RowLayout {
                id: clearRow
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: "delete_sweep"
                    iconSize: 18
                    color: clipModule.colRed
                }
                Text {
                    text: "Clear"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: clipModule.colRed
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "cliphist wipe && rm -rf /tmp/cliphist_thumbs/*"]);
                    clipModule.allClips = [];
                    clipModel.clear();
                    root.collapseToIdle();
                }
            }
        }
    }

    // ========================================================
    // 2. MATERIAL YOU FILTER CHIPS (All / Text / Images)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Chip: All
        Rectangle {
            Layout.preferredHeight: 30
            Layout.preferredWidth: chipAllRow.implicitWidth + 20
            radius: 15
            color: clipModule.activeFilterChip === "all" ? clipModule.colAccent : (chipAllMouse.containsMouse ? clipModule.colCardHover : clipModule.colChipBg)
            border.width: 0
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: chipAllRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "All"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: clipModule.activeFilterChip === "all" ? Font.DemiBold : Font.Medium
                    color: clipModule.activeFilterChip === "all" ? clipModule.colOnAccent : clipModule.colText
                    renderType: Text.NativeRendering
                }
                Rectangle {
                    height: 18
                    radius: 9
                    color: clipModule.activeFilterChip === "all" ? Qt.alpha(clipModule.colOnAccent, 0.18) : clipModule.colCardHover
                    implicitWidth: allCountText.implicitWidth + 10
                    Text {
                        id: allCountText
                        anchors.centerIn: parent
                        text: "" + clipModule.allClips.length
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: clipModule.activeFilterChip === "all" ? clipModule.colOnAccent : clipModule.colSubtext
                        renderType: Text.NativeRendering
                    }
                }
            }
            MouseArea {
                id: chipAllMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    clipModule.activeFilterChip = "all";
                    clipModule.applyFilter();
                }
            }
        }

        // Chip: Text
        Rectangle {
            Layout.preferredHeight: 30
            Layout.preferredWidth: chipTextRow.implicitWidth + 20
            radius: 15
            color: clipModule.activeFilterChip === "text" ? clipModule.colAccent : (chipTextMouse.containsMouse ? clipModule.colCardHover : clipModule.colChipBg)
            border.width: 0
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: chipTextRow
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "description"
                    iconSize: 14
                    color: clipModule.activeFilterChip === "text" ? clipModule.colOnAccent : clipModule.colSubtext
                }
                Text {
                    text: "Text"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: clipModule.activeFilterChip === "text" ? Font.DemiBold : Font.Medium
                    color: clipModule.activeFilterChip === "text" ? clipModule.colOnAccent : clipModule.colText
                    renderType: Text.NativeRendering
                }
                Rectangle {
                    height: 18
                    radius: 9
                    color: clipModule.activeFilterChip === "text" ? Qt.alpha(clipModule.colOnAccent, 0.18) : clipModule.colCardHover
                    implicitWidth: textCountText.implicitWidth + 10
                    Text {
                        id: textCountText
                        anchors.centerIn: parent
                        text: "" + clipModule.textClipCount
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: clipModule.activeFilterChip === "text" ? clipModule.colOnAccent : clipModule.colSubtext
                        renderType: Text.NativeRendering
                    }
                }
            }
            MouseArea {
                id: chipTextMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    clipModule.activeFilterChip = "text";
                    clipModule.applyFilter();
                }
            }
        }

        // Chip: Images
        Rectangle {
            Layout.preferredHeight: 30
            Layout.preferredWidth: chipImgRow.implicitWidth + 20
            radius: 15
            color: clipModule.activeFilterChip === "image" ? clipModule.colAccent : (chipImgMouse.containsMouse ? clipModule.colCardHover : clipModule.colChipBg)
            border.width: 0
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: chipImgRow
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "image"
                    iconSize: 14
                    color: clipModule.activeFilterChip === "image" ? clipModule.colOnAccent : clipModule.colSubtext
                }
                Text {
                    text: "Images"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: clipModule.activeFilterChip === "image" ? Font.DemiBold : Font.Medium
                    color: clipModule.activeFilterChip === "image" ? clipModule.colOnAccent : clipModule.colText
                    renderType: Text.NativeRendering
                }
                Rectangle {
                    height: 18
                    radius: 9
                    color: clipModule.activeFilterChip === "image" ? Qt.alpha(clipModule.colOnAccent, 0.18) : clipModule.colCardHover
                    implicitWidth: imgCountText.implicitWidth + 10
                    Text {
                        id: imgCountText
                        anchors.centerIn: parent
                        text: "" + clipModule.imageClipCount
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: clipModule.activeFilterChip === "image" ? clipModule.colOnAccent : clipModule.colSubtext
                        renderType: Text.NativeRendering
                    }
                }
            }
            MouseArea {
                id: chipImgMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    clipModule.activeFilterChip = "image";
                    clipModule.applyFilter();
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Hint: Enter to copy
        Text {
            text: "↵ click or Enter to copy"
            font.family: "Noto Sans"
            font.pixelSize: 11
            color: clipModule.colMuted
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 4
        }
    }

    // ========================================================
    // 3. CLIPBOARD ITEMS LIST (Dynamic Material You Tonal Cards)
    // ========================================================
    ListView {
        id: clipList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: clipModel
        currentIndex: 0
        boundsBehavior: Flickable.StopAtBounds

        highlightFollowsCurrentItem: true
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 40
        preferredHighlightEnd: height - 60

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex < count) {
                positionViewAtIndex(currentIndex, ListView.Contain);
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: clipScroll
            active: clipList.moving || clipList.flicking
            policy: ScrollBar.AsNeeded
            width: 3
            contentItem: Rectangle {
                radius: 1.5
                color: clipModule.colChipBg
            }
        }

        WheelHandler {
            target: clipList
            onWheel: (event) => {
                var step = event.angleDelta.y > 0 ? -60 : 60;
                clipList.contentY = Math.max(0, Math.min(Math.max(0, clipList.contentHeight - clipList.height), clipList.contentY + step));
            }
        }

        // Empty State — Material 3 Squircle Badge
        Item {
            anchors.fill: parent
            visible: clipModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 48
                    height: 48
                    radius: 16
                    color: clipModule.colChipBg
                    border.width: 0

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "content_paste_off"
                        iconSize: 24
                        color: clipModule.colMuted
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: searchInput.text.trim() !== "" ? "No matching clips found" : "Clipboard history is empty"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    color: clipModule.colSubtext
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: searchInput.text.trim() !== "" ? "Try a different search term" : "Items you copy will automatically appear here"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                    color: clipModule.colMuted
                }
            }
        }

        // Delegate — Dynamic Height Material 3 Tonal Card
        delegate: Rectangle {
            id: clipCard
            width: ListView.view ? (ListView.view.width - (clipScroll.visible ? 6 : 0)) : 500
            implicitHeight: Math.max(isImage ? 96 : 64, cardLayout.implicitHeight + 24)
            height: implicitHeight
            readonly property bool isSelected: ListView.isCurrentItem
            radius: 14
            color: isSelected 
                ? Qt.rgba(clipModule.colAccent.r, clipModule.colAccent.g, clipModule.colAccent.b, 0.18)
                : (clipMouse.containsMouse ? clipModule.colCardHover : clipModule.colCard)
            border.width: 0

            Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

            RowLayout {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12

                // Preview Thumbnail or Format Squircle Badge
                Rectangle {
                    Layout.preferredWidth: isImage ? 92 : 40
                    Layout.preferredHeight: isImage ? 72 : 40
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: isImage ? 0 : 2
                    radius: isImage ? 12 : 14
                    color: isImage ? clipModule.colChipBg : (isSelected ? clipModule.colAccent : clipModule.colChipBg)
                    border.width: 0
                    clip: true
                    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    Image {
                        id: clipImg
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: isImage && imgPath !== "" && status === Image.Ready
                        source: (isImage && imgPath !== "") ? ("file://" + imgPath) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        sourceSize.width: 140
                        sourceSize.height: 100
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !isImage || imgPath === "" || (isImage && clipImg.status !== Image.Ready)
                        text: isImage ? "image" : "content_paste"
                        iconSize: isImage ? 20 : 18
                        color: isImage ? clipModule.colSubtext : (isSelected ? clipModule.colOnAccent : clipModule.colSubtext)
                    }
                }

                // Description Text & Metadata Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: isImage ? "Image Clip" : description
                        color: clipModule.colText
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        renderType: Text.NativeRendering
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: isImage ? 1 : 4
                        elide: Text.ElideRight
                        lineHeight: 1.2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: isImage ? (description || "Image preview") : (description.length + " characters")
                            color: isSelected ? clipModule.colAccent : clipModule.colSubtext
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 110 } }
                        }

                        // Format / Type Pill tag
                        Rectangle {
                            height: 16
                            radius: 8
                            color: isSelected ? Qt.alpha(clipModule.colAccent, 0.20) : clipModule.colChipBg
                            implicitWidth: typeTagText.implicitWidth + 10
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                id: typeTagText
                                anchors.centerIn: parent
                                text: isImage ? "IMAGE" : (description.startsWith("http://") || description.startsWith("https://") ? "URL" : (description.startsWith("{") || description.startsWith("[") ? "JSON" : "TEXT"))
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: isSelected ? clipModule.colAccent : clipModule.colMuted
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // Quick Copy Pill Button
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 2
                    radius: 18
                    color: isSelected ? clipModule.colAccent : (copyBtnMouse.containsMouse ? clipModule.colCardHover : clipModule.colChipBg)
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "content_copy"
                        iconSize: 16
                        color: isSelected ? clipModule.colOnAccent : (copyBtnMouse.containsMouse ? clipModule.colText : clipModule.colSubtext)
                    }

                    MouseArea {
                        id: copyBtnMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            clipList.currentIndex = index;
                            clipModule.copyItemToTop(clipId);
                        }
                    }
                }
            }

            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: -1
                onEntered: clipList.currentIndex = index
                onClicked: {
                    clipList.currentIndex = index;
                    clipModule.copyItemToTop(clipId);
                }
                onWheel: (wheel) => {
                    var step = wheel.angleDelta.y > 0 ? -60 : 60;
                    clipList.contentY = Math.max(0, Math.min(Math.max(0, clipList.contentHeight - clipList.height), clipList.contentY + step));
                }
            }
        }
    }
}
