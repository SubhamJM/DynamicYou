pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool overviewOpen: false
    property bool searchOnlyMode: false
    property bool searchConnectActive: false
    property bool searchPanelActive: false
    property bool panelOpenedDirectly: false
    property string activeSearchMonitor: ""
    property string activeSearchQuery: ""
    property string searchPendingPanel: ""
    property string searchPendingPanelQuery: ""
    property var searchPanelNavigationRequest: null
    property var scrollingOverviewNavigator: null
    property bool floatingNotchOwnsSearch: true

    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool settingsOpen: false
    property bool osdVolumeOpen: false
    property bool wallpaperSelectorOpen: false
    property bool cheatsheetOpen: false
    property bool notesAppOpen: false
    property bool clockAppOpen: false
    property bool healthAppOpen: false
    property bool sessionOpen: false
    property bool usageOpen: false
    property bool modesOpen: false
    property bool editMode: false
    property bool islandDashboardOpen: false
    property bool overlayOpen: false
    property bool barOpen: true

    function openSettings() {}
    function consumePendingSearchPanel() {
        var p = root.searchPendingPanel;
        root.searchPendingPanel = "";
        return p;
    }
    function consumePendingSearchPanelQuery() {
        var q = root.searchPendingPanelQuery;
        root.searchPendingPanelQuery = "";
        return q;
    }
    function closeSearchSurfaces() {
        overviewOpen = false;
    }
    function clearFileBrowserSearchResults() {}
}
