import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int screenWidth: 1920
    property int screenHeight: 1080
    property var panelScreen: null
    property real padding: 4

    property var inputField: tagInputField
    readonly property var responses: Wallhaven.responses
    property string previewDownloadPath: (typeof Directories !== "undefined" && Directories.booruPreviews) ? Directories.booruPreviews : ((Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/media/boorus")
    property string downloadPath: Quickshell.env("HOME") + "/Pictures/Wallpapers/Wallhaven"
    property string nsfwPath: Quickshell.env("HOME") + "/Pictures/Wallpapers/Wallhaven"
    property string commandPrefix: "/"
    property real scrollOnNewResponse: 100
    property int tagSuggestionDelay: 210
    property var suggestionQuery: ""
    property var suggestionList: []
    property bool discoveryAutoHidden: false
    property real previousListContentY: 0
    property int selectedDiscoveryIndex: 0
    property int selectedCommonsIndex: 0
    property int selectedRankingIndex: 0
    property real lastScrollDelta: 0
    readonly property var activeSearchTags: Wallhaven.activeSearchTags
    readonly property var providerOptions: [
        { id: "wallhaven", label: "Wallhaven", url: "https://wallhaven.cc", group: "wallpapers", groupLabel: Translation.tr("Wallpapers"), summary: Translation.tr("Best fit for desktop, ricing and weekly discovery"), searchable: true, suggestions: true, supportsNsfw: true }
    ]
    property int selectedProviderIndex: 0
    property bool providerPickerOpen: false
    property bool filtersOpen: false
    property bool showTagsOnHover: true
    property bool actionBusy: false
    property bool applyAfterDownload: false
    property string pendingDownloadPath: ""
    property string actionStatus: ""

    function startPreviewAction(applyWallpaper) {
        if (root.actionBusy || !Wallhaven.activePreview)
            return
        const preview = Wallhaven.activePreview
        const url = String(preview.file_url ?? "")
        if (!url.startsWith("https://")) {
            root.actionStatus = "Original image is unavailable"
            return
        }
        const id = String(preview.id ?? "wallpaper").replace(/[^a-zA-Z0-9_-]/g, "")
        const extension = String(preview.file_ext ?? "jpg").replace(/[^a-zA-Z0-9]/g, "") || "jpg"
        const directory = Quickshell.env("HOME") + "/Pictures/Wallpapers/Wallhaven"
        root.pendingDownloadPath = directory + "/" + id + "." + extension
        root.applyAfterDownload = applyWallpaper
        root.actionBusy = true
        root.actionStatus = applyWallpaper ? "Downloading and applying…" : "Downloading…"
        imageDownload.command = ["bash", "-c",
            "trap 'rm -f \"$2.part\"' EXIT; mkdir -p \"$1\" && curl --fail --location --silent --show-error --max-time 120 --output \"$2.part\" \"$3\" && mv -f \"$2.part\" \"$2\"",
            "wallhaven", directory, root.pendingDownloadPath, url]
        imageDownload.running = true
    }

    Process {
        id: imageDownload
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.actionStatus = "Download failed. Please try again."
                root.actionBusy = false
                return
            }
            if (root.applyAfterDownload) {
                wallpaperApply.command = ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/apply_wallpaper.sh", root.pendingDownloadPath]
                wallpaperApply.running = true
            } else {
                root.actionStatus = "Saved to Pictures/Wallpapers/Wallhaven"
                root.actionBusy = false
            }
        }
    }

    Process {
        id: wallpaperApply
        onExited: (exitCode, exitStatus) => {
            root.actionStatus = exitCode === 0 ? "Wallpaper applied" : "Could not apply wallpaper"
            root.actionBusy = false
        }
    }
    readonly property var fitModeIds: ["auto", "native", "aspect", "any"]
    property string fitMode: "auto"
    readonly property string activeProviderId: "wallhaven"
    readonly property var activeProvider: root.providerOptions[0]
    readonly property bool wallhavenControlsVisible: true
    readonly property bool providerSearchable: true
    readonly property bool providerSupportsSuggestions: true
    readonly property bool providerSupportsNsfw: Wallhaven.apiKey.length > 0
    readonly property string currentRankingLabel: (root.selectedRankingIndex >= 0 && root.selectedRankingIndex < root.rankingOptions.length) ? (root.rankingOptions[root.selectedRankingIndex]?.summary ?? root.rankingOptions[root.selectedRankingIndex]?.label ?? "Top weekly") : "Top weekly"
    readonly property string currentDiscoveryLabel: (root.selectedDiscoveryIndex >= 0 && root.selectedDiscoveryIndex < root.discoveryOptions.length) ? root.discoveryOptions[root.selectedDiscoveryIndex].label : (root.activeSearchTags.length > 0 ? root.activeSearchTags.join(" ") : "All")
    readonly property string currentFitLabel: root.fitMode === "any" ? "Any display"
        : root.fitMode === "aspect" ? ("Aspect · " + root.monitorRatioLabel)
        : (root.fitMode === "native" ? "Native+ · " : "Auto · ")
            + root.monitorRatioLabel + " · " + root.screenWidth + "×" + root.screenHeight
    readonly property string statusSummaryText: currentDiscoveryLabel + " · " + currentRankingLabel + " · " + currentFitLabel
    readonly property real monitorAspect: root.screenHeight > 0 ? root.screenWidth / root.screenHeight : 16 / 9
    readonly property string monitorRatioCode: root.closestRatioCode(root.monitorAspect)
    readonly property string monitorRatioLabel: root.monitorRatioCode.replace("x", ":")
    readonly property var fitOptions: [
        { id: "auto", label: Translation.tr("Auto"), summary: root.monitorRatioLabel + " · " + root.screenWidth + "×" + root.screenHeight },
        { id: "native", label: Translation.tr("Native+"), summary: Translation.tr("At least this monitor") },
        { id: "aspect", label: Translation.tr("Aspect"), summary: Translation.tr("Match shape only") },
        { id: "any", label: Translation.tr("Any"), summary: Translation.tr("No display filter") }
    ]
    readonly property var resultCountOptions: [12, 18, 24]
    readonly property int configuredResultCount: Number(Config.options?.wallhaven?.limit ?? 24)
    property int selectedResultCount: root.resultCountOptions.includes(root.configuredResultCount)
        ? root.configuredResultCount : 24
    readonly property int resultCount: root.selectedResultCount

    readonly property var discoveryOptions: [
        { label: Translation.tr("All"), category: "111", tags: [] },
        { label: Translation.tr("Ricing"), category: "111", tags: ["linux"] },
        { label: Translation.tr("Dark"), category: "111", tags: ["dark"] },
        { label: Translation.tr("Minimal"), category: "111", tags: ["minimal"] },
        { label: Translation.tr("Cyberpunk"), category: "111", tags: ["cyberpunk"] },
        { label: Translation.tr("Retro"), category: "111", tags: ["retro"] },
        { label: Translation.tr("Pixel art"), category: "111", tags: ["pixel art"] },
        { label: Translation.tr("Cars / JDM"), category: "100", tags: ["cars"] },
        { label: Translation.tr("Space"), category: "100", tags: ["space"] },
        { label: Translation.tr("Abstract"), category: "111", tags: ["abstract"] },
        { label: Translation.tr("Anime"), category: "010", tags: [] }
    ]
    readonly property var commonsDiscoveryOptions: [
        { label: Translation.tr("Featured"), query: "" },
        { label: Translation.tr("Nature"), query: "nature landscape" },
        { label: Translation.tr("Space"), query: "space astronomy" },
        { label: Translation.tr("Architecture"), query: "architecture" },
        { label: Translation.tr("Cities"), query: "city skyline" },
        { label: Translation.tr("Animals"), query: "animal wildlife" },
        { label: Translation.tr("Art"), query: "painting artwork" },
        { label: Translation.tr("Science"), query: "science" }
    ]
    readonly property var rankingOptions: [
        { label: Translation.tr("Week"), icon: "date_range", summary: Translation.tr("Top weekly"), sorting: "toplist", topRange: "1w" },
        { label: Translation.tr("Month"), icon: "calendar_month", summary: Translation.tr("Top monthly"), sorting: "toplist", topRange: "1M" },
        { label: Translation.tr("Latest"), icon: "new_releases", sorting: "date_added" },
        { label: Translation.tr("Random"), icon: "shuffle", sorting: "random" }
    ]

    function closestRatioCode(aspect: real): string {
        const ratios = [
            { code: "32x9", value: 32 / 9 },
            { code: "21x9", value: 21 / 9 },
            { code: "16x9", value: 16 / 9 },
            { code: "16x10", value: 16 / 10 },
            { code: "3x2", value: 3 / 2 },
            { code: "4x3", value: 4 / 3 },
            { code: "5x4", value: 5 / 4 },
            { code: "4x5", value: 4 / 5 },
            { code: "2x3", value: 2 / 3 },
            { code: "10x16", value: 10 / 16 },
            { code: "9x16", value: 9 / 16 }
        ]
        let best = ratios[0]
        let bestDistance = Math.abs(aspect - best.value)
        for (let i = 1; i < ratios.length; ++i) {
            const distance = Math.abs(aspect - ratios[i].value)
            if (distance < bestDistance) {
                best = ratios[i]
                bestDistance = distance
            }
        }
        return best.code
    }

    function currentFitProfile() {
        return {
            mode: root.fitMode,
            width: root.screenWidth,
            height: root.screenHeight,
            ratioCode: root.monitorRatioCode,
            aspect: root.monitorAspect
        }
    }

    function fitSummary(): string {
        const option = root.fitOptions.find(item => item.id === root.fitMode)
        return option?.id === "auto"
            ? option.summary
            : (option?.label ?? Translation.tr("Auto")) + " · " + root.monitorRatioLabel
    }

    property bool pullLoading: false
    property int pullLoadingGap: 80
    property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-wallhavenResponseListView.verticalOvershoot / 50)) * wallhavenResponseListView.dragging)

    // Used to auto-scroll to the next page section after the request completes.
    property int _pendingScrollToPage: -1
    property string _pendingScrollTagsKey: ""

    function _tryScrollToPendingPage() {
        if (root._pendingScrollToPage <= 0)
            return
        for (let i = 0; i < root.responses.length; ++i) {
            const r = root.responses[i]
            if (!r || r.provider !== root.activeProviderId)
                continue
            if (parseInt(r.page) !== root._pendingScrollToPage)
                continue
            if (root._tagsKey(r.tags) !== root._pendingScrollTagsKey)
                continue

            // Defer to next tick so delegates have a chance to size themselves.
            Qt.callLater(() => {
                wallhavenResponseListView.positionViewAtIndex(i, ListView.Beginning)
            })

            root._pendingScrollToPage = -1
            root._pendingScrollTagsKey = ""
            break
        }
    }

    function _tagsKey(tags) {
        return (tags || []).join(" ")
    }

    function requestWallpapers(tags, page: int, replaceExisting: bool, category, providerId): void {
        const requestedTags = Array.isArray(tags) ? [...tags] : []
        if (replaceExisting)
            Wallhaven.beginSearch()
        Wallhaven.makeRequest(
            requestedTags,
            Persistent.states.booru.allowNsfw,
            root.resultCount,
            page || 1,
            category ?? Wallhaven.activeSearchCategory,
            undefined,
            providerId ?? root.activeProviderId,
            root.currentFitProfile()
        )
    }

    function selectProvider(index: int): void {
        if (index < 0 || index >= root.providerOptions.length)
            return
        root.selectedProviderIndex = index
        root.providerPickerOpen = false
        root.filtersOpen = false
        root.suggestionQuery = ""
        root.suggestionList = []
        Wallhaven.cancelTagSuggestions()
        const providerId = root.providerOptions[index].id
        if (providerId === "wallhaven" && root.selectedDiscoveryIndex >= 0) {
            const option = root.discoveryOptions[root.selectedDiscoveryIndex]
            root.requestWallpapers(option.tags, 1, true, option.category, providerId)
        } else {
            root.requestWallpapers([], 1, true, Wallhaven.activeSearchCategory, providerId)
        }
    }

    function selectDiscovery(index: int): void {
        if (index < 0 || index >= root.discoveryOptions.length)
            return
        const option = root.discoveryOptions[index]
        root.selectedDiscoveryIndex = index
        root.requestWallpapers(option.tags, 1, true, option.category, "wallhaven")
    }

    function selectCommonsDiscovery(index: int): void {
        if (index < 0 || index >= root.commonsDiscoveryOptions.length)
            return
        root.selectedCommonsIndex = index
        const query = root.commonsDiscoveryOptions[index]?.query ?? ""
        const tags = query.length > 0 ? query.split(/\s+/) : []
        root.requestWallpapers(tags, 1, true, Wallhaven.activeSearchCategory, "commons")
    }

    function selectRanking(index: int): void {
        if (index < 0 || index >= root.rankingOptions.length)
            return
        const option = root.rankingOptions[index]
        root.selectedRankingIndex = index
        Wallhaven.sortingMode = option.sorting
        if (option?.topRange !== undefined)
            Wallhaven.topRange = option.topRange
        root.requestWallpapers(root.activeSearchTags, 1, true, Wallhaven.activeSearchCategory, "wallhaven")
    }

    function syncSelectionsFromService(): void {
        const providerIndex = root.providerOptions.findIndex(option =>
            option.id === Wallhaven.activeSearchProvider)
        root.selectedProviderIndex = providerIndex >= 0 ? providerIndex : 0
        root.selectedDiscoveryIndex = root.discoveryOptions.findIndex(option =>
            option.category === Wallhaven.activeSearchCategory
                && root._tagsKey(option.tags) === root._tagsKey(root.activeSearchTags))
        const rankingIndex = root.rankingOptions.findIndex(option =>
            option.sorting === Wallhaven.sortingMode
                && (option.sorting !== "toplist" || option.topRange === Wallhaven.topRange))
        root.selectedRankingIndex = rankingIndex >= 0 ? rankingIndex : 0
    }

    function providerLabel(): string {
        return root.providerOptions[root.selectedProviderIndex]?.label ?? "Wallhaven"
    }

    function providerSummary(): string {
        return root.providerOptions[root.selectedProviderIndex]?.summary ?? ""
    }

    function discoveryLabel(): string {
        const index = root.selectedDiscoveryIndex
        if (index >= 0)
            return root.discoveryOptions[index].label
        if (root.activeSearchTags.length > 0)
            return root.activeSearchTags.join(" ").replace(/id:\d+/g, Translation.tr("Custom"))
        return Translation.tr("All")
    }

    function rankingLabel(): string {
        const option = root.rankingOptions[root.selectedRankingIndex]
        return option?.summary ?? option?.label ?? Translation.tr("Top weekly")
    }

    function selectFitMode(mode: string): void {
        if (!root.fitModeIds.includes(mode))
            return
        root.fitMode = mode
        root.requestWallpapers(root.activeSearchTags, 1, true,
            Wallhaven.activeSearchCategory, "wallhaven")
    }

    function selectResultCount(count: int): void {
        if (!root.resultCountOptions.includes(count))
            return
        root.selectedResultCount = count
        root.requestWallpapers(root.activeSearchTags, 1, true,
            Wallhaven.activeSearchCategory, "wallhaven")
    }

    component FlatChoice: RippleButton {
        id: choice
        required property string label
        property bool selected: false
        signal chosen()

        implicitHeight: 32
        implicitWidth: 64
        buttonRadius: Appearance.rounding.verysmall
        toggled: choice.selected
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: colBackgroundToggled
        colRipple: Appearance.colors.colLayer1Active
        colRippleToggled: Appearance.colors.colLayer1Active
        onClicked: choice.chosen()

        contentItem: StyledText {
            text: choice.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: choice.selected ? Font.DemiBold : Font.Normal
            color: choice.selected ? (Appearance.colors.colPrimary ?? Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Accessible.name: choice.label
        Accessible.role: Accessible.Button
        Accessible.checked: choice.selected
    }

    component FitChoice: RippleButton {
        id: fitChoice
        required property var option
        property bool selected: false
        signal chosen()

        implicitHeight: 52
        buttonRadius: Appearance.rounding.small
        toggled: fitChoice.selected
        colBackground: Appearance.colors.colLayer1
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: colBackgroundToggled
        colRipple: Appearance.colors.colLayer1Active
        colRippleToggled: colRipple
        onClicked: fitChoice.chosen()

        contentItem: Item {
            Column {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 12)
                spacing: 0

                StyledText {
                    width: parent.width
                    text: fitChoice.option?.label ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: fitChoice.selected ? Font.DemiBold : Font.Medium
                    color: fitChoice.selected ? (Appearance.colors.colPrimary ?? Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnLayer1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                StyledText {
                    width: parent.width
                    text: fitChoice.option?.summary ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: fitChoice.selected ? (Appearance.colors.colPrimary ?? Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }

    component SourceRow: RippleButton {
        id: sourceRow
        required property var source
        required property bool selected

        implicitHeight: 48
        buttonRadius: Appearance.rounding.small
        colBackground: sourceRow.selected ? Appearance.colors.colLayer1Active : "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colLayer1Active

        contentItem: RowLayout {
            spacing: 10

            Favicon {
                url: sourceRow.source?.url ?? ""
                displayText: sourceRow.source?.label ?? ""
                size: 22
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                StyledText {
                    Layout.fillWidth: true
                    text: sourceRow.source?.label ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: sourceRow.selected ? Font.DemiBold : Font.Medium
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: sourceRow.source?.summary ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                visible: sourceRow.selected
                text: "check"
                iconSize: 16
                color: Appearance.colors.colPrimary
            }
        }
    }

    component FlatIconAction: RippleButton {
        id: action
        required property string symbol
        property string tooltip: ""
        property bool active: false
        signal triggered()

        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: Appearance.regaliaEverywhere
            ? Appearance.regalia.roundSmall : Appearance.rounding.verysmall
        toggled: action.active
        colBackground: Appearance.regaliaEverywhere
            ? Appearance.regalia.controlPlate : "transparent"
        colBackgroundHover: Appearance.regaliaEverywhere
            ? Appearance.regalia.controlPlateHover : Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.regaliaEverywhere
            ? Appearance.regalia.controlPlateActive : Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: Appearance.regaliaEverywhere
            ? Appearance.regalia.controlPlateActive : Appearance.colors.colPrimaryContainerHover
        colRipple: Appearance.regaliaEverywhere
            ? Appearance.regalia.pressPlate : Appearance.colors.colLayer1Active
        onClicked: action.triggered()

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: action.symbol
            iconSize: 17
            color: Appearance.regaliaEverywhere
                ? (action.active ? Appearance.regalia.onColor : Appearance.regalia.onMuted)
                : action.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
        }

        StyledToolTip {
            extraVisibleCondition: false
            alternativeVisibleCondition: (action.buttonHovered ?? false) && action.tooltip.length > 0
            text: action.tooltip
        }

        Accessible.name: action.tooltip
        Accessible.role: Accessible.Button
        Accessible.checked: action.active
    }

    Connections {
        target: Wallhaven
        function onActivePreviewChanged() {
            root.actionStatus = ""
        }
        function onResponseFinished() {
            pullLoading = false
            root._tryScrollToPendingPage()
        }
    }

    Connections {
        target: Wallhaven
        function onTagSuggestion(query, suggestions) {
            root.suggestionQuery = query
            root.suggestionList = suggestions
        }
    }

    Component.onCompleted: {
        root.syncSelectionsFromService()
        initialProvider.start()
    }
    // Not Qt.callLater: a queued call outlives this view when a reload tears it down first.
    Timer {
        id: initialProvider
        interval: 0
        onTriggered: root.selectProvider(root.selectedProviderIndex)
    }

    function requireWallhavenMode(): bool {
        if (root.wallhavenControlsVisible)
            return true
        Wallhaven.addSystemMessage(Translation.tr("This sorting mode is only available on Wallhaven."))
        return false
    }

    property var allCommands: [
        {
            name: "clear",
            description: Translation.tr("Clear the current list of images"),
            execute: () => {
                Wallhaven.beginSearch();
            }
        },
        {
            name: "clean",
            description: Translation.tr("Clear the current list of images"),
            execute: () => {
                Wallhaven.beginSearch();
            }
        },
        {
            name: "next",
            description: Translation.tr("Get the next page of results"),
            execute: () => {
                const lastResponse = [...root.responses].reverse().find(response =>
                    response && response.provider === root.activeProviderId && response.page > 0)
                if (lastResponse) {
                    root.handleInput(`${lastResponse.tags.join(" ")} ${parseInt(lastResponse.page) + 1}`);
                } else {
                    root.handleInput("");
                }
            }
        },
        {
            name: "safe",
            description: Translation.tr("Disable NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = false;
            }
        },
        {
            name: "lewd",
            description: Translation.tr("Allow NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = true;
            }
        },
        {
            name: "top",
            description: Translation.tr("Use monthly toplist (topRange=1M)"),
            execute: () => {
                if (!root.requireWallhavenMode()) return;
                root.selectedRankingIndex = 1;
                Wallhaven.sortingMode = "toplist";
                Wallhaven.topRange = "1M";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to toplist (1M)"));
            }
        },
        {
            name: "topw",
            description: Translation.tr("Use weekly toplist (topRange=1w)"),
            execute: () => {
                if (!root.requireWallhavenMode()) return;
                root.selectedRankingIndex = 0;
                Wallhaven.sortingMode = "toplist";
                Wallhaven.topRange = "1w";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to toplist (1w)"));
            }
        },
        {
            name: "latest",
            description: Translation.tr("Sort by newest wallpapers"),
            execute: () => {
                if (!root.requireWallhavenMode()) return;
                root.selectedRankingIndex = 2;
                Wallhaven.sortingMode = "date_added";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to latest"));
            }
        },
        {
            name: "random",
            description: Translation.tr("Show random wallpapers"),
            execute: () => {
                if (!root.requireWallhavenMode()) return;
                root.selectedRankingIndex = 3;
                Wallhaven.sortingMode = "random";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to random"));
            }
        }
    ]

    function parseTagsAndPage(inputText) {
        const parts = inputText.split(/\s+/).filter(p => p.length > 0)
        let pageIndex = 1
        let tags = []
        let hashParts = null

        for (let i = 0; i < parts.length; ++i) {
            const part = parts[i]

            if (part.startsWith("#")) {
                if (hashParts && hashParts.length > 0) {
                    const phrase = hashParts.join(" ").trim()
                    if (phrase.length > 0)
                        tags.push(root.wallhavenControlsVisible ? ("\"" + phrase + "\"") : phrase.replace(/\s+/g, "_"))
                }
                hashParts = [part.substring(1)]
            } else if (hashParts) {
                hashParts.push(part)
            } else {
                if (/^\d+$/.test(part)) {
                    pageIndex = parseInt(part, 10)
                    continue
                }
                tags.push(part)
            }
        }

        if (hashParts && hashParts.length > 0) {
            const phrase = hashParts.join(" ").trim()
            if (phrase.length > 0)
                tags.push(root.wallhavenControlsVisible ? ("\"" + phrase + "\"") : phrase.replace(/\s+/g, "_"))
        }

        return { tags, pageIndex }
    }

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Wallhaven.addSystemMessage(Translation.tr("Unknown command: ") + command);
            }
        }
        else if (inputText.trim() == "+") {
            root.handleInput(`${root.commandPrefix}next`);
        }
        else {
            if (!root.providerSearchable) {
                Wallhaven.addSystemMessage(Translation.tr("%1 is a browse-only source. Use paging or change source.").arg(root.providerLabel()))
                return
            }
            const parsed = root.parseTagsAndPage(inputText)
            if (root.wallhavenControlsVisible && parsed.pageIndex <= 1)
                root.selectedDiscoveryIndex = -1
            if (root.activeProviderId === "commons" && parsed.pageIndex <= 1)
                root.selectedCommonsIndex = -1
            root.requestWallpapers(parsed.tags, parsed.pageIndex, parsed.pageIndex <= 1,
                Wallhaven.activeSearchCategory, root.activeProviderId)
        }
    }

    onFocusChanged: (focus) => {
        if (focus) {
            tagInputField.forceActiveFocus()
        }
    }

    property real pageKeyScrollAmount: wallhavenResponseListView.height / 2
    Keys.onPressed: (event) => {
        tagInputField.forceActiveFocus()
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                if (wallhavenResponseListView.atYBeginning) return;
                wallhavenResponseListView.contentY = Math.max(0, wallhavenResponseListView.contentY - root.pageKeyScrollAmount)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                if (wallhavenResponseListView.atYEnd) return;
                wallhavenResponseListView.contentY = Math.min(wallhavenResponseListView.contentHeight, wallhavenResponseListView.contentY + root.pageKeyScrollAmount)
                event.accepted = true
            }
        }
    }

    // (Tag suggestion handling follows Anime.qml pattern: searchTimer + FlowButtonGroup acceptTag)

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            id: discoveryPanel
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            implicitHeight: root.discoveryAutoHidden ? 0 : discoveryContent.implicitHeight
            opacity: root.discoveryAutoHidden ? 0 : 1
            visible: opacity > 0
            enabled: !root.discoveryAutoHidden
            clip: true

            Behavior on implicitHeight {
                enabled: true
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
            Behavior on opacity {
                enabled: true
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            ColumnLayout {
                id: discoveryContent
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 4

                Rectangle {
                    id: contextBar
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Appearance.zzzEverywhere
                        ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    color: Appearance.colors.colLayer1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.small
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    text: "filter_vintage"
                                    iconSize: 18
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.statusSummaryText
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        FlatIconAction {
                            visible: root.providerSupportsNsfw
                            symbol: "18_up_rating"
                            tooltip: Persistent.states.booru.allowNsfw
                                ? Translation.tr("Adult content enabled")
                                : Translation.tr("Adult content disabled")
                            active: Persistent.states.booru.allowNsfw
                            onTriggered: {
                                Persistent.states.booru.allowNsfw = !Persistent.states.booru.allowNsfw
                                root.requestWallpapers(root.activeSearchTags, 1, true,
                                    Wallhaven.activeSearchCategory, root.activeProviderId)
                            }
                        }

                        FlatIconAction {
                            symbol: "tune"
                            tooltip: Translation.tr("Source and display filters")
                            active: root.filtersOpen
                            onTriggered: {
                                root.filtersOpen = !root.filtersOpen
                                if (root.filtersOpen)
                                    root.providerPickerOpen = false
                            }
                        }
                    }
                }

                // Quick Discovery Category Chips
                Flickable {
                    visible: root.wallhavenControlsVisible
                    Layout.fillWidth: true
                    implicitHeight: 30
                    contentWidth: categoryRow.implicitWidth
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    RowLayout {
                        id: categoryRow
                        spacing: 6

                        Repeater {
                            model: root.discoveryOptions
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                implicitWidth: catLabel.implicitWidth + 20
                                implicitHeight: 26
                                radius: 13
                                color: index === root.selectedDiscoveryIndex ? (Appearance.colors?.colPrimary ?? "#25b4e5") : (catMouse.containsMouse ? (Appearance.colors?.colLayer2Hover ?? "#383838") : (Appearance.colors?.colLayer1 ?? "#222222"))

                                Text {
                                    id: catLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: index === root.selectedDiscoveryIndex ? (Appearance.colors?.colOnPrimary ?? "#ffffff") : (Appearance.colors?.colOnLayer1 ?? "#cccccc")
                                    font.pixelSize: 12
                                    font.weight: index === root.selectedDiscoveryIndex ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectDiscovery(index)
                                }
                            }
                        }
                    }
                }


                ColumnLayout {
                    visible: root.filtersOpen
                    Layout.fillWidth: true
                    spacing: 5

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Display fit")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.screenWidth + "×" + root.screenHeight + " · " + root.monitorRatioLabel
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colSubtext
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        columns: 2
                        uniformCellWidths: true
                        uniformCellHeights: true
                        columnSpacing: 4
                        rowSpacing: 4

                        Repeater {
                            model: root.fitOptions
                            delegate: FitChoice {
                                required property var modelData
                                Layout.fillWidth: true
                                option: modelData
                                selected: root.fitMode === (modelData?.id ?? "auto")
                                onChosen: root.selectFitMode(modelData?.id ?? "auto")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            text: Translation.tr("Results per page")
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            font.weight: Font.Medium
                            color: Appearance.colors.colSubtext
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            spacing: 4

                            Repeater {
                                model: root.resultCountOptions

                                delegate: FlatChoice {
                                    required property int modelData
                                    Layout.fillWidth: true
                                    label: String(modelData)
                                    selected: root.resultCount === modelData
                                    onChosen: root.selectResultCount(modelData)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.topMargin: 2

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -1
                            StyledText {
                                text: Translation.tr("Tags on hover")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: Translation.tr("Show image tags only when you want them")
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledSwitch {
                            scale: 0.72
                            checked: root.showTagsOnHover
                            onToggled: root.showTagsOnHover = checked
                        }
                    }

                    StyledText {
                        visible: root.wallhavenControlsVisible
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        text: Translation.tr("Collection")
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }

                    GridLayout {
                        visible: root.wallhavenControlsVisible
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        columns: 4
                        uniformCellWidths: true
                        uniformCellHeights: true
                        columnSpacing: 2
                        rowSpacing: 2

                        Repeater {
                            model: root.discoveryOptions

                            delegate: FlatChoice {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                label: modelData?.label ?? ""
                                selected: index === root.selectedDiscoveryIndex
                                onChosen: root.selectDiscovery(index)
                            }
                        }
                    }

                    StyledText {
                        visible: root.wallhavenControlsVisible
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        text: Translation.tr("Sort")
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }

                    GridLayout {
                        visible: root.wallhavenControlsVisible
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        columns: 4
                        uniformCellWidths: true
                        uniformCellHeights: true
                        columnSpacing: 2
                        rowSpacing: 2

                        Repeater {
                            model: root.rankingOptions

                            delegate: FlatChoice {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                label: modelData?.label ?? ""
                                selected: index === root.selectedRankingIndex
                                onChosen: root.selectRanking(index)
                            }
                        }
                    }

                    StyledText {
                        visible: root.activeProviderId === "commons"
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        text: Translation.tr("Featured collection")
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }

                    GridLayout {
                        visible: root.activeProviderId === "commons"
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 2
                        rowSpacing: 2

                        Repeater {
                            model: root.commonsDiscoveryOptions
                            delegate: FlatChoice {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                label: modelData?.label ?? ""
                                selected: index === root.selectedCommonsIndex
                                onChosen: root.selectCommonsDiscovery(index)
                            }
                        }
                    }

                    StyledText {
                        visible: !root.wallhavenControlsVisible && root.activeProviderId !== "commons"
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        text: root.providerSearchable
                            ? Translation.tr("Use the search field for this source. Display fit is applied after results arrive.")
                            : Translation.tr("This source is browse-only. Use paging and display fit to refine the catalog.")
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: wallhavenResponseListView.width
                    height: wallhavenResponseListView.height
                    radius: Appearance.rounding.small
                }
            }

            ScrollEdgeFade {
                z: 1
                target: wallhavenResponseListView
                vertical: true
            }

            StyledListView {
                id: wallhavenResponseListView
                z: 0
                anchors.fill: parent
                spacing: 10

                touchpadScrollFactor: (Config.options?.interactions?.scrolling?.touchpadScrollFactor ?? 1.0) * 1.4
                mouseScrollFactor: (Config.options?.interactions?.scrolling?.mouseScrollFactor ?? 1.0) * 1.4

                footer: Item {
                    // Allow scrolling past the last response so paging buttons aren't covered
                    // by the input bar at the bottom.
                    implicitHeight: tagInputContainer.implicitHeight + 16
                }
                footerPositioning: ListView.InlineFooter

                onContentHeightChanged: {
                    // When a new page response lands, delegates need a tick to size.
                    // Retrying on contentHeightChanged makes auto-scroll reliable.
                    if (root._pendingScrollToPage > 0) {
                        Qt.callLater(() => root._tryScrollToPendingPage())
                    }
                }

                property int lastResponseLength: 0
                property bool userIsScrolling: false

                onContentYChanged: {
                    const delta = contentY - root.previousListContentY
                    root.lastScrollDelta = delta
                    if (atYBeginning || contentY <= 1)
                        root.discoveryAutoHidden = false
                    else if (delta > 1) {
                        root.providerPickerOpen = false
                        root.filtersOpen = false
                        root.discoveryAutoHidden = true
                    }
                    root.previousListContentY = contentY
                }
                
                onMovingChanged: {
                    if (moving) {
                        userIsScrolling = true
                    } else {
                        userIsScrolling = false
                        if (root.lastScrollDelta < -4)
                            root.discoveryAutoHidden = false
                    }
                }
                
                onDraggingChanged: {
                    if (dragging) userIsScrolling = true
                    else Qt.callLater(() => { userIsScrolling = false })
                }
                
                Connections {
                    target: root
                    function onResponsesChanged() {
                        const nextLength = root.responses.length
                        if (nextLength === 0) {
                            wallhavenResponseListView.lastResponseLength = 0
                            return
                        }

                        // Once the bounded list is full, a new page rotates the
                        // oldest response without changing the model length.
                        if (nextLength >= wallhavenResponseListView.lastResponseLength) {
                            if (!wallhavenResponseListView.userIsScrolling
                                    && wallhavenResponseListView.lastResponseLength > 0) {
                                wallhavenResponseListView.contentY += root.scrollOnNewResponse
                            }

                            // If a next-page click requested an auto-scroll, position the new page section.
                            root._tryScrollToPendingPage()
                        }
                        wallhavenResponseListView.lastResponseLength = nextLength
                    }
                }

                model: ScriptModel {
                    values: root.responses
                }
                delegate: BooruResponse {
                    responseData: modelData
                    tagInputField: root.inputField
                    previewDownloadPath: root.previewDownloadPath
                    downloadPath: root.downloadPath
                    nsfwPath: root.nsfwPath
                    // Clean layout - no card background, just images
                    cleanLayout: true
                    showPagingButtons: true
                    showTagsOnHover: root.showTagsOnHover
                    rowTooShortThreshold: 165
                    rowMaxHeight: 300
                    imageSpacing: 4
                    responsePadding: 0

                    onNextPageRequested: (resp) => {
                        if (!resp)
                            return
                        root._pendingScrollToPage = parseInt(resp.page) + 1
                        root._pendingScrollTagsKey = root._tagsKey(resp.tags)
                        Qt.callLater(() => root._tryScrollToPendingPage())
                    }
                    onClearRequested: () => Wallhaven.beginSearch()
                }

                onDragEnded: {
                    const gap = wallhavenResponseListView.verticalOvershoot
                    if (gap > root.pullLoadingGap) {
                        root.pullLoading = true
                        root.handleInput(`${root.commandPrefix}next`)
                    }
                }
            }

            MaterialPlaceholderMessage {
                id: placeholderHost
                z: 2
                shown: root.responses.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                maximumWidth: 420
                icon: (Network.wifi || Network.ethernet) ? "image" : "cloud_off"
                text: Translation.tr("%1 wallpapers").arg(root.providerLabel())
                explanation: !(Network.wifi || Network.ethernet) ? Translation.tr("Connect to the internet to browse Wallhaven")
                    : root.wallhavenControlsVisible
                    ? Translation.tr("Search Wallhaven by tags, or pick a collection above\nResults automatically match this monitor")
                    : root.providerSearchable
                        ? Translation.tr("Search %1 by tags\nDisplay fit follows this monitor automatically").arg(root.providerLabel())
                        : Translation.tr("Browse curated photography\nDisplay fit follows this monitor automatically")
                shape: MaterialShape.Shape.Bun
            }

            ScrollToBottomButton {
                z: 3
                target: wallhavenResponseListView
                compact: true
            }

            MaterialLoadingIndicator {
                id: loadingIndicator
                z: 4
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 20 + (root.pullLoading ? 0 : Math.max(0, (root.normalizedPullDistance - 0.5) * 50))
                    Behavior on bottomMargin {
                        enabled: Appearance.animationsEnabled ?? true
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
                loading: root.pullLoading || Wallhaven.runningRequests > 0
                pullProgress: Math.min(1, wallhavenResponseListView.verticalOvershoot / root.pullLoadingGap * wallhavenResponseListView.dragging)
                scale: root.pullLoading ? 1 : Math.min(1, root.normalizedPullDistance * 2)
            }
        }

        DescriptionBox {
            text: root.suggestionList[commandSuggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup {
            id: commandSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0 && tagInputField.text.startsWith(root.commandPrefix)
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: commandSuggestionRepeater
                model: {
                    commandSuggestions.selectedIndex = 0
                    return root.suggestionList.slice(0, 10)
                }
                delegate: ApiCommandButton {
                    id: cmdButton
                    colBackground: Appearance.angelEverywhere
                        ? (commandSuggestions.selectedIndex === index ? Appearance.angel.colGlassCardHover : Appearance.angel.colGlassCard)
                        : Appearance.auroraEverywhere
                        ? (commandSuggestions.selectedIndex === index ? Appearance.aurora.colSubSurface : "transparent")
                        : Appearance.zzzEverywhere
                        ? (commandSuggestions.selectedIndex === index ? Appearance.zzz.sticker : "transparent")
                        : (commandSuggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)
                    bounce: false
                    contentItem: StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.zzzEverywhere && commandSuggestions.selectedIndex === index
                            ? Appearance.zzz.onSticker : Appearance.colors.colOnSecondaryContainer
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                    }

                    onHoveredChanged: {
                        if (cmdButton.hovered) {
                            commandSuggestions.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        commandSuggestions.acceptCommand(modelData.name)
                    }
                }
            }

            function acceptCommand(cmd) {
                tagInputField.text = cmd + " "
                tagInputField.cursorPosition = tagInputField.text.length
                tagInputField.forceActiveFocus()
            }

            function acceptSelectedCommand() {
                if (commandSuggestions.selectedIndex >= 0 && commandSuggestions.selectedIndex < commandSuggestionRepeater.count) {
                    const cmd = root.suggestionList[commandSuggestions.selectedIndex].name;
                    commandSuggestions.acceptCommand(cmd);
                }
            }
        }

        DescriptionBox {
            text: ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup {
            id: tagSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0 && !tagInputField.text.startsWith(root.commandPrefix)
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: tagSuggestionRepeater
                model: {
                    tagSuggestions.selectedIndex = 0
                    return root.suggestionList.slice(0, 10)
                }
                delegate: ApiCommandButton {
                    id: tagButton
                    colBackground: Appearance.angelEverywhere
                        ? (tagSuggestions.selectedIndex === index ? Appearance.angel.colGlassCardHover : Appearance.angel.colGlassCard)
                        : Appearance.auroraEverywhere
                        ? (tagSuggestions.selectedIndex === index ? Appearance.aurora.colSubSurface : "transparent")
                        : Appearance.zzzEverywhere
                        ? (tagSuggestions.selectedIndex === index ? Appearance.zzz.sticker : "transparent")
                        : (tagSuggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)
                    bounce: false
                    contentItem: Item {
                        implicitWidth: centredRow1.implicitWidth
                        implicitHeight: centredRow1.implicitHeight
                        RowLayout {
                            id: centredRow1
                            width: Math.min(implicitWidth, parent.width)
                            anchors.centerIn: parent
                            spacing: 5
                            StyledText {
                                Layout.fillWidth: false
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.zzzEverywhere && tagSuggestions.selectedIndex === index
                                    ? Appearance.zzz.onSticker : Appearance.colors.colOnSecondaryContainer
                                horizontalAlignment: Text.AlignRight
                                text: (root.wallhavenControlsVisible ? "#" : "") + (modelData.name ?? "")
                            }
                            StyledText {
                                Layout.fillWidth: false
                                visible: modelData.count !== undefined
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.zzzEverywhere && tagSuggestions.selectedIndex === index
                                    ? Appearance.zzz.onSticker : Appearance.colors.colOnSecondaryContainer
                                horizontalAlignment: Text.AlignLeft
                                text: modelData.count ?? ""
                            }
                        }
                    }
                    onHoveredChanged: {
                        if (tagButton.hovered) {
                            tagSuggestions.selectedIndex = index
                        }
                    }
                    onClicked: {
                        tagSuggestions.acceptSuggestion(modelData)
                    }
                }
            }

            function acceptSuggestion(suggestion) {
                const raw = tagInputField.text.trim()
                const words = raw.length > 0 ? raw.split(/\s+/) : []

                const tagName = suggestion?.name ?? ""
                const tagId = suggestion?.id ?? ""
                if (tagName.length === 0)
                    return

                if (root.wallhavenControlsVisible && tagId.length > 0) {
                    tagInputField.text = "id:" + tagId + " "
                    tagInputField.cursorPosition = tagInputField.text.length
                    tagInputField.forceActiveFocus()
                    return
                }

                if (!root.wallhavenControlsVisible) {
                    if (words.length > 0)
                        words[words.length - 1] = tagName
                    else
                        words.push(tagName)
                } else if (words.length > 0) {
                    const last = words[words.length - 1]
                    const keepHash = last.startsWith("#")
                    const needsHash = keepHash || (/\s+/.test(tagName))
                    words[words.length - 1] = (needsHash ? "#" : "") + tagName
                } else {
                    words.push("#" + tagName)
                }
                const updatedText = words.join(" ") + " "
                tagInputField.text = updatedText
                tagInputField.cursorPosition = tagInputField.text.length
                tagInputField.forceActiveFocus()
            }

            function acceptSelectedTag() {
                if (tagSuggestions.selectedIndex >= 0 && tagSuggestions.selectedIndex < tagSuggestionRepeater.count) {
                    const s = root.suggestionList[tagSuggestions.selectedIndex]
                    tagSuggestions.acceptSuggestion(s)
                }
            }
        }

        Rectangle {
            id: tagInputContainer
            property real columnSpacing: 5
            Layout.fillWidth: true
            radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.normal - root.padding
            Behavior on radius {
                enabled: Appearance.animationsEnabled ?? true
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            color: Appearance.colors?.colLayer2 ?? "#242424"
            implicitWidth: tagInputField.implicitWidth
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + 10, 48)
            clip: true

            Behavior on implicitHeight {
                enabled: Appearance.animationsEnabled ?? true
                animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
            }

            RowLayout {
                id: inputFieldRowLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 5
                spacing: 0

                StyledTextArea {
                    id: tagInputField
                    wrapMode: TextArea.Wrap
                    Layout.fillWidth: true
                    padding: 10
                    color: activeFocus ? (Appearance.colors?.colOnSurface ?? "#ffffff") : (Appearance.colMetadataText ?? Appearance.colors?.colSubtext ?? "#a0a0a0")
                    renderType: Text.NativeRendering
                    placeholderText: !root.providerSearchable
                        ? Translation.tr('Browse %1 · use "%2" for commands').arg(root.providerLabel()).arg(root.commandPrefix)
                        : root.wallhavenControlsVisible
                            ? Translation.tr('Search Wallhaven tags, or "%1" for commands').arg(root.commandPrefix)
                            : Translation.tr('Search %1 tags, or "%2" for commands').arg(root.providerLabel()).arg(root.commandPrefix)
                    background: null

                    property Timer searchTimer: Timer {
                        interval: root.tagSuggestionDelay
                        repeat: false
                        onTriggered: {
                            const inputText = tagInputField.text
                            const trimmed = (inputText || "").trim()
                            if (trimmed.length === 0 || !root.providerSupportsSuggestions)
                                return
                            if (root.wallhavenControlsVisible && trimmed.startsWith("id:"))
                                return
                            // If user is typing a multi-word tag fragment after '#', use the whole fragment.
                            const hashIdx = trimmed.lastIndexOf("#")
                            let q = ""
                            if (hashIdx !== -1) {
                                q = trimmed.substring(hashIdx + 1).trim()
                            } else {
                                const words = trimmed.split(/\s+/)
                                q = words.length > 0 ? words[words.length - 1] : ""
                            }
                            if (!root.wallhavenControlsVisible)
                                q = q.replace(/\s+/g, "_")
                            if (q.length < 2)
                                return
                            Wallhaven.triggerTagSearch(q, undefined, root.activeProviderId)
                        }
                    }

                    onTextChanged: {
                        if (tagInputField.text.length === 0) {
                            root.suggestionQuery = ""
                            root.suggestionList = []
                            searchTimer.stop()
                            return
                        }

                        if (tagInputField.text.startsWith(root.commandPrefix)) {
                            root.suggestionQuery = tagInputField.text
                            root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(tagInputField.text.substring(1))).map(cmd => {
                                return {
                                    name: `${root.commandPrefix}${cmd.name}`,
                                    description: `${cmd.description}`,
                                }
                            })
                            searchTimer.stop()
                            return
                        }

                        searchTimer.restart()
                    }

                    function accept() {
                        root.handleInput(text)
                        text = ""
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            if (!tagInputField.text.startsWith(root.commandPrefix) && root.suggestionList.length > 0) {
                                tagSuggestions.acceptSelectedTag()
                            } else {
                                commandSuggestions.acceptSelectedCommand()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (!tagInputField.text.startsWith(root.commandPrefix) && root.suggestionList.length > 0) {
                                tagSuggestions.selectedIndex = Math.max(0, tagSuggestions.selectedIndex - 1)
                            } else {
                                commandSuggestions.selectedIndex = Math.max(0, commandSuggestions.selectedIndex - 1)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            if (!tagInputField.text.startsWith(root.commandPrefix) && root.suggestionList.length > 0) {
                                tagSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, tagSuggestions.selectedIndex + 1)
                            } else {
                                commandSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, commandSuggestions.selectedIndex + 1)
                            }
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                tagInputField.insert(tagInputField.cursorPosition, "\n")
                                event.accepted = true
                            } else {
                                const inputText = tagInputField.text
                                root.handleInput(inputText)
                                tagInputField.clear()
                                event.accepted = true
                            }
                        }
                    }
                 }

                Item {
                    id: sendButton
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 5
                    implicitWidth: 36
                    implicitHeight: 36
                    enabled: tagInputField.text.length > 0
                    opacity: enabled ? 1 : 0.32

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.zzzEverywhere
                            ? Appearance.zzz.controlRadius : Appearance.rounding.small
                        color: !sendButton.enabled ? "transparent"
                            : sendMouse.containsMouse ? Appearance.colors.colPrimaryHover
                            : Appearance.colors.colPrimary
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 20
                        color: Appearance.zzzEverywhere
                            ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimary
                        text: "arrow_upward"
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        enabled: sendButton.enabled
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const inputText = tagInputField.text
                            root.handleInput(inputText)
                            tagInputField.clear()
                        }
                    }
                }
            }

        }
    }

    // Lightbox / Wallpaper Preview Overlay
    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        z: 9999
        visible: Wallhaven.activePreview !== null
        color: Qt.rgba(0.04, 0.04, 0.06, 0.95)
        radius: 16

        // Trap mouse events
        MouseArea {
            anchors.fill: parent
            onClicked: Wallhaven.activePreview = null
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Top Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 8

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: resText.implicitWidth + 16
                    radius: 14
                    color: Appearance.colors.colLayer2

                    Text {
                        id: resText
                        anchors.centerIn: parent
                        text: (Wallhaven.activePreview?.width ?? 0) + " × " + (Wallhaven.activePreview?.height ?? 0)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurface
                    }
                }

                Rectangle {
                    visible: (Wallhaven.activePreview?.file_size ?? 0) > 0
                    implicitHeight: 28
                    implicitWidth: sizeText.implicitWidth + 16
                    radius: 14
                    color: Appearance.colors.colLayer2

                    Text {
                        id: sizeText
                        anchors.centerIn: parent
                        text: {
                            const bytes = Wallhaven.activePreview?.file_size ?? 0;
                            if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB";
                            if (bytes >= 1024) return (bytes / 1024).toFixed(0) + " KB";
                            return bytes + " B";
                        }
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.actionStatus
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: closeHover.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 18
                        color: Appearance.colors.colOnSurface
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallhaven.activePreview = null
                    }
                }
            }

            // Preview Image
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Image {
                    id: previewImg
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    source: Wallhaven.activePreview ? (Wallhaven.activePreview.sample_url ?? Wallhaven.activePreview.preview_url ?? Wallhaven.activePreview.file_url ?? "") : ""
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: previewImg.status === Image.Loading
                    visible: running
                }
            }

            // Bottom Actions Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 12

                Item { Layout.fillWidth: true }

                // Set Wallpaper Button (Accent)
                Rectangle {
                    id: setWallBtn
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: setWallRow.implicitWidth + 24
                    radius: 18
                    color: setWallMouse.pressed ? Qt.darker(Appearance.colors.colPrimary, 1.15) : (setWallMouse.containsMouse ? Qt.lighter(Appearance.colors.colPrimary, 1.1) : Appearance.colors.colPrimary)

                    RowLayout {
                        id: setWallRow
                        anchors.centerIn: parent
                        spacing: 8

                        MaterialSymbol {
                            text: "wallpaper"
                            iconSize: 18
                            color: Appearance.colors.colOnPrimary
                        }

                        Text {
                            text: "Set as Wallpaper"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    MouseArea {
                        id: setWallMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.actionBusy
                        onClicked: root.startPreviewAction(true)
                    }
                }

                // Download Button
                Rectangle {
                    id: dlBtn
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: dlRow.implicitWidth + 20
                    radius: 18
                    color: dlMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

                    RowLayout {
                        id: dlRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "download"
                            iconSize: 18
                            color: Appearance.colors.colOnSurface
                        }

                        Text {
                            text: "Download"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    MouseArea {
                        id: dlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.actionBusy
                        onClicked: root.startPreviewAction(false)
                    }
                }

                // Open on Wallhaven Button
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: webRow.implicitWidth + 20
                    radius: 18
                    color: webMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

                    RowLayout {
                        id: webRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "open_in_new"
                            iconSize: 18
                            color: Appearance.colors.colOnSurface
                        }

                        Text {
                            text: "Open Link"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    MouseArea {
                        id: webMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!Wallhaven.activePreview) return;
                            const url = Wallhaven.activePreview.source || Wallhaven.activePreview.file_url || ("https://wallhaven.cc/w/" + Wallhaven.activePreview.id);
                            Qt.openUrlExternally(url);
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
