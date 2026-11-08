pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.modules.ii.overview
import qs.modules.common
import qs.services
import "../"

FocusScope {
    id: launcher
    focus: true
    Keys.forwardTo: [searchWidget]

    Keys.onEscapePressed: {
        GlobalStates.overviewOpen = false;
        if (typeof root !== "undefined" && typeof root.collapseToIdle === "function") {
            root.collapseToIdle();
        }
    }

    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias searchInput: searchWidget.searchBar.searchInput
    property alias searchWidget: searchWidget

    function activateSelected(): bool {
        return searchWidget ? searchWidget.activateSelected() : false;
    }
    property var allApps: (typeof root !== "undefined" && root.cachedApps && root.cachedApps.length > 0) ? root.cachedApps : []
    readonly property int calculatedCount: searchWidget.realResultCount
    readonly property bool browsing: searchWidget.searchingText === ""
    readonly property real targetWidth: (searchWidget && searchWidget.contentTargetWidth > 0)
        ? searchWidget.contentTargetWidth
        : 580
    readonly property real targetHeight: {
        if (!searchWidget) return 500;
        const wanted = searchWidget.contentTargetHeight;
        return (wanted > 0) ? wanted : (searchWidget.collapsedHeight > 0 ? searchWidget.collapsedHeight : 500);
    }

    function onOpened() {
        GlobalStates.overviewOpen = true;
        searchWidget.forceActiveFocus();
        Qt.callLater(() => {
            searchWidget.focusSearchInput();
            if (searchWidget.searchBar && searchWidget.searchBar.searchInput) {
                searchWidget.searchBar.searchInput.forceActiveFocus();
                searchWidget.searchBar.searchInput.cursorPosition = searchWidget.searchBar.searchInput.text.length;
            }
            if (searchWidget.appResults) {
                searchWidget.appResults.selectFirst();
            }
        });
    }

    function processSearch(query) {
        if (searchWidget) {
            console.warn("[LAUNCHER_DEBUG] Query set:", query, "stack:", new Error().stack);
            searchWidget.setSearchingText(query || "");
        }
    }

    function updateSuggestions() {}

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen && typeof root !== "undefined" && root.activeMode === "launcher") {
                root.collapseToIdle();
            }
        }
    }

    Component.onCompleted: {
        console.log("[LAUNCHER_DEBUG] Launcher loaded. width:", launcher.width, "height:", launcher.height,
                    "searchWidget w:", searchWidget.width, "h:", searchWidget.height,
                    "targetHeight:", launcher.targetHeight,
                    "contentTargetHeight:", searchWidget.contentTargetHeight,
                    "contentTargetWidth:", searchWidget.contentTargetWidth);
    }

    SearchWidget {
        id: searchWidget
        anchors.fill: parent
        inNotchMode: true
        hostWidth: launcher.width
        hostHeight: launcher.height
    }
}
