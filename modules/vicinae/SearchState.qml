pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"

Item {
    id: root

    property string query: ""
    property int selectedIndex: -1
    readonly property string placeholderText: clipboardMode ? "Browse clipboard history..." : wallpaperMode ? "Search wallpapers..." : "Search apps, files, and the web..."
    property bool clipboardMode: false
    property bool wallpaperMode: false
    property string previousSearchQuery: ""
    property int selectedClipboardIndex: -1
    property bool loadingCatalog: false
    property bool loadingFiles: false
    property bool loadingUsage: false
    property bool loadingFavorites: false
    property bool loadingWallpapers: false
    property bool loadingClipboard: false
    property bool loadingClipboardPreview: false
    property var catalogBuffer: []
    property var fileResultsBuffer: []
    property var wallpaperItemsBuffer: []
    property var clipboardItemsBuffer: []
    property var catalog: []
    property var fileResults: []
    property var favoriteItems: []
    property var favoriteKeys: ({})
    property var wallpaperItems: []
    property var clipboardItems: []
    property var usageCounts: ({})
    property var usageRegisterQueue: []
    property int clipboardPreviewRevision: 0
    property string pendingFileSearchQuery: ""
    property string activeFileSearchQuery: ""
    property bool cancelingFileSearch: false
    property bool cancelingClipboardPreview: false
    property string activeClipboardPreviewToken: ""
    property string pendingClipboardPreviewToken: ""
    property string statusMessage: ""
    property string wallpaperStatusMessage: ""
    property string clipboardStatusMessage: ""
    readonly property string catalogScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_catalog.py"
    readonly property string fileSearchScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_file_search.py"
    readonly property string usageScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_usage.py"
    readonly property string favoritesScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_favorites.py"
    readonly property string wallpaperScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_wallpapers.py"
    readonly property string clipboardScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_clipboard.py"
    readonly property var quickActionsCatalog: [
        {
            "section": "Quick actions",
            "kind": "result",
            "title": "Clipboard History",
            "subtitle": "Browse and paste previous clipboard entries",
            "iconText": "󰅌",
            "accessoryText": "Open",
            "accessoryColor": "#ff9f43",
            "aliasText": "clip",
            "keywords": ["clipboard", "cliphist", "history", "copy", "paste", "буфер", "буфер обмена", "история буфера", "копировать", "вставить"],
            "actionLabel": "Open History",
            "launchType": "clipboardHistory",
            "launchValue": "",
            "launchKey": "quick:clipboard-history"
        },
        {
            "section": "Quick actions",
            "kind": "result",
            "title": "Wallpapers",
            "subtitle": "Choose wallpaper from ~/wallpapers",
            "iconText": "󰸉",
            "accessoryText": "Open",
            "accessoryColor": "#b8a1ff",
            "aliasText": "wall",
            "keywords": ["wallpaper", "wallpapers", "background", "mpvpaper", "обои", "фон", "сменить обои", "изменить обои"],
            "actionLabel": "Choose Wallpaper",
            "launchType": "wallpaperPicker",
            "launchValue": "",
            "launchKey": "quick:wallpapers"
        }
    ]
    readonly property var powerCatalog: [
        {
            "section": "System",
            "kind": "result",
            "title": "Power Off",
            "subtitle": "Turn the computer off",
            "iconText": "󰐥",
            "accessoryText": "Power",
            "accessoryColor": "#ff6b6b",
            "aliasText": "off",
            "keywords": ["shutdown", "poweroff", "power off", "выключение", "выключить", "завершение работы", "отключить компьютер"],
            "actionLabel": "Power Off",
            "launchType": "command",
            "launchValue": "systemctl poweroff",
            "launchKey": "power:poweroff"
        },
        {
            "section": "System",
            "kind": "result",
            "title": "Reboot",
            "subtitle": "Restart the computer",
            "iconText": "󰜉",
            "accessoryText": "Restart",
            "accessoryColor": "#ffaa55",
            "aliasText": "reboot",
            "keywords": ["reboot", "restart", "перезагрузка", "перезапуск", "restart system", "reboot system"],
            "actionLabel": "Reboot",
            "launchType": "command",
            "launchValue": "systemctl reboot",
            "launchKey": "power:reboot"
        },
        {
            "section": "System",
            "kind": "result",
            "title": "Suspend",
            "subtitle": "Put the computer to sleep",
            "iconText": "󰒲",
            "accessoryText": "Sleep",
            "accessoryColor": "#ffd166",
            "aliasText": "sleep",
            "keywords": ["suspend", "sleep", "standby", "спящий режим", "сон", "усыпить", "sleep mode"],
            "actionLabel": "Suspend",
            "launchType": "command",
            "launchValue": "systemctl suspend",
            "launchKey": "power:suspend"
        },
        {
            "section": "System",
            "kind": "result",
            "title": "Hibernate",
            "subtitle": "Save session to disk and power off",
            "iconText": "󰤄",
            "accessoryText": "Hibernate",
            "accessoryColor": "#b8a1ff",
            "aliasText": "hiber",
            "keywords": ["hibernate", "hibernation", "гибернация", "save session", "disk sleep"],
            "actionLabel": "Hibernate",
            "launchType": "command",
            "launchValue": "systemctl hibernate",
            "launchKey": "power:hibernate"
        },
        {
            "section": "System",
            "kind": "result",
            "title": "Lock Session",
            "subtitle": "Lock the current screen",
            "iconText": "󰌾",
            "accessoryText": "Lock",
            "accessoryColor": "#7dcfff",
            "aliasText": "lock",
            "keywords": ["lock", "lock screen", "блокировка", "заблокировать", "экран блокировки", "screen lock"],
            "actionLabel": "Lock",
            "launchType": "command",
            "launchValue": "command -v hyprlock >/dev/null 2>&1 && hyprlock || loginctl lock-sessions",
            "launchKey": "power:lock"
        },
        {
            "section": "System",
            "kind": "result",
            "title": "Log Out",
            "subtitle": "End the current graphical session",
            "iconText": "󰍃",
            "accessoryText": "Logout",
            "accessoryColor": "#f7768e",
            "aliasText": "exit",
            "keywords": ["logout", "log out", "exit session", "выход", "выйти", "выход из системы", "завершить сеанс"],
            "actionLabel": "Log Out",
            "launchType": "command",
            "launchValue": "if [ -n \"$XDG_SESSION_ID\" ]; then loginctl terminate-session \"$XDG_SESSION_ID\"; else hyprctl dispatch exit; fi",
            "launchKey": "power:logout"
        }
    ]
    property alias resultsModel: resultsModel
    property alias clipboardModel: clipboardModel
    readonly property int resultCount: clipboardMode ? clipboardModel.count : selectableCount()
    readonly property var currentItem: selectedIndex >= 0 && selectedIndex < resultsModel.count ? resultsModel.get(selectedIndex) : null
    readonly property var selectedClipboardItem: clipboardPreviewRevision >= 0 && selectedClipboardIndex >= 0 && selectedClipboardIndex < clipboardModel.count ? clipboardModel.get(selectedClipboardIndex) : null
    readonly property bool currentItemFavorite: !clipboardMode && !wallpaperMode && currentItem && currentItem.selectable ? isFavoriteItem(currentItem) : false
    readonly property string primaryActionLabel: clipboardMode ? (selectedClipboardItem ? "Paste" : "") : currentItem && currentItem.selectable ? currentItem.actionLabel || "Open" : ""
    readonly property string secondaryActionLabel: clipboardMode ? (selectedClipboardItem ? "Copy" : "") : !wallpaperMode && currentItem && currentItem.selectable ? (currentItemFavorite ? "Unfavorite" : "Favorite") : ""
    readonly property string secondaryActionShortcut: clipboardMode ? "Ctrl B" : "Ctrl D"
    readonly property string escapeActionLabel: clipboardMode || wallpaperMode ? "Back" : "Close"
    readonly property string resultSummary: resultCount === 0 ? "No results" : resultCount === 1 ? "1 result" : resultCount + " results"
    readonly property string clipboardSummary: clipboardModel.count === 0 ? "No clipboard items" : clipboardModel.count === 1 ? "1 clipboard item" : clipboardModel.count + " clipboard items"
    readonly property string wallpaperSummary: resultCount === 0 ? "No wallpapers" : resultCount === 1 ? "1 wallpaper" : resultCount + " wallpapers"
    readonly property string footerStatus: clipboardMode ? (loadingClipboard ? "Loading clipboard history..." : loadingClipboardPreview ? "Loading preview..." : clipboardStatusMessage !== "" ? clipboardStatusMessage : clipboardSummary) : wallpaperMode ? (loadingWallpapers ? "Loading wallpapers..." : wallpaperStatusMessage !== "" ? wallpaperStatusMessage : wallpaperSummary) : loadingCatalog ? "Loading applications..." : loadingUsage ? "Loading usage history..." : loadingFavorites ? "Loading favorites..." : loadingFiles ? "Searching files..." : statusMessage !== "" ? statusMessage : resultSummary

    signal resultActivated(var item)
    signal closeRequested()

    function normalizeText(value) {
        return (value || "").toString().toLowerCase().trim()
    }

    function stringContainsToken(text, token) {
        return normalizeText(text).indexOf(token) !== -1
    }

    function fuzzyScore(text, token) {
        const haystack = normalizeText(text)
        const needle = normalizeText(token)

        if (needle === "")
            return 0

        let score = 0
        let cursor = -1

        for (let i = 0; i < needle.length; i++) {
            const character = needle[i]
            const nextIndex = haystack.indexOf(character, cursor + 1)

            if (nextIndex === -1)
                return -1

            score += nextIndex === cursor + 1 ? 6 : 2

            if (nextIndex === 0 || haystack[nextIndex - 1] === " " || haystack[nextIndex - 1] === "/" || haystack[nextIndex - 1] === "-")
                score += 4

            cursor = nextIndex
        }

        score -= Math.max(0, haystack.length - needle.length) * 0.03
        return score
    }

    function matchScore(item, token) {
        const needle = normalizeText(token)

        if (needle === "")
            return 0

        const title = normalizeText(item.title)
        const subtitle = normalizeText(item.subtitle)
        const aliasText = normalizeText(item.aliasText)
        const keywords = (item.keywords || []).join(" ")
        const combined = [item.title, item.subtitle, item.aliasText, keywords, item.section].join(" ")

        let score = fuzzyScore(combined, needle)

        if (score < 0)
            return -1

        if (title.indexOf(needle) === 0)
            score += 18
        else if (stringContainsToken(title, needle))
            score += 10

        if (aliasText !== "" && stringContainsToken(aliasText, needle))
            score += 8

        if (subtitle !== "" && stringContainsToken(subtitle, needle))
            score += 4

        return score
    }

    function isMathExpression(text) {
        return /^[0-9\s()+\-*/%.]+$/.test((text || "").trim()) && (text || "").trim() !== ""
    }

    function buildCalculatorResult(expression) {
        if (!isMathExpression(expression))
            return null

        try {
            const answer = Function("return (" + expression + ")")()

            if (answer === undefined || answer === null || Number.isNaN(answer) || !Number.isFinite(answer))
                return null

            return {
                "section": "Quick actions",
                "kind": "calculator",
                "title": "Calculator",
                "subtitle": "",
                "iconText": "󰃬",
                "accessoryText": "Copy",
                "accessoryColor": "#55ff55",
                "aliasText": "",
                "keywords": ["calculator", "math", "result"],
                "actionLabel": "Use Result",
                "launchType": "copy",
                "launchValue": answer.toString(),
                "calcQuestion": expression,
                "calcQuestionUnit": "Expression",
                "calcAnswer": answer.toString(),
                "calcAnswerUnit": "Result"
            }
        } catch (error) {
            return null
        }
    }

    function looksLikeUrl(text) {
        const value = (text || "").trim()

        if (value === "")
            return false

        return /^(https?:\/\/|www\.)/i.test(value) || /^[\w.-]+\.[a-z]{2,}(\/.*)?$/i.test(value)
    }

    function buildWebSearchResult(text) {
        const value = (text || "").trim()

        if (value === "" || isMathExpression(value))
            return null

        const directUrl = looksLikeUrl(value)
        const finalUrl = directUrl
            ? (/^https?:\/\//i.test(value) ? value : "https://" + value.replace(/^www\./i, "www."))
            : "https://duckduckgo.com/?q=" + encodeURIComponent(value)

        return {
            "section": "Web",
            "kind": "result",
            "title": directUrl ? "Open “" + value + "”" : "Search the web for “" + value + "”",
            "subtitle": directUrl ? finalUrl : "DuckDuckGo search",
            "iconText": "󰖟",
            "accessoryText": directUrl ? "Open" : "Search",
            "accessoryColor": "#7dcfff",
            "aliasText": directUrl ? "url" : "web",
            "keywords": [value, "web", "internet", "browser", "search", "интернет", "поиск", "браузер", "гугл", "duckduckgo"],
            "actionLabel": directUrl ? "Open URL" : "Search the Web",
            "launchType": "url",
            "launchValue": finalUrl,
            "launchKey": directUrl ? "url:" + finalUrl : "web:" + normalizeText(value)
        }
    }

    function buildCommandResult(text, allowExpression) {
        const value = (text || "").trim()

        if (value === "" || (!allowExpression && isMathExpression(value)))
            return null

        return {
            "section": "Command",
            "kind": "result",
            "title": "Run “" + value + "”",
            "subtitle": "Execute command in shell",
            "iconText": "󰆍",
            "accessoryText": "Run",
            "accessoryColor": "#a6e3a1",
            "aliasText": "cmd",
            "keywords": [value, "command", "shell", "terminal", "run", "execute", "команда", "терминал", "выполнить", "запустить"],
            "actionLabel": "Run Command",
            "launchType": "command",
            "launchValue": value,
            "launchKey": "command:" + value
        }
    }

    function usageKeyForItem(item) {
        if (!item)
            return ""

        if (item.launchKey)
            return item.launchKey

        if (item.launchType && item.launchValue)
            return item.launchType + ":" + item.launchValue

        return ""
    }

    function usageCountForItem(item) {
        const key = usageKeyForItem(item)

        if (key === "" || usageCounts[key] === undefined)
            return 0

        return usageCounts[key]
    }

    function usageScoreForItem(item, token) {
        const count = usageCountForItem(item)

        if (count <= 0)
            return 0

        return Math.log(1 + count) * (token === "" ? 14 : 6)
    }

    function favoriteKeyForItem(item) {
        if (!item)
            return ""

        if (item.launchKey)
            return item.launchKey

        if (item.launchType && item.launchValue)
            return item.launchType + ":" + item.launchValue

        if (item.title)
            return "title:" + item.title

        return ""
    }

    function isFavoriteItem(item) {
        const key = favoriteKeyForItem(item)
        return key !== "" && favoriteKeys[key] === true
    }

    function rebuildFavoriteKeys() {
        const next = ({})

        for (let i = 0; i < favoriteItems.length; i++) {
            const key = favoriteKeyForItem(favoriteItems[i])
            if (key !== "")
                next[key] = true
        }

        favoriteKeys = next
    }

    function snapshotItem(item) {
        if (!item)
            return null

        try {
            return JSON.parse(JSON.stringify(item))
        } catch (error) {
            return {
                "isSection": item.isSection === true,
                "selectable": item.selectable === true,
                "kind": item.kind || "result",
                "sectionName": item.sectionName || item.section || "",
                "title": item.title || "",
                "subtitle": item.subtitle || "",
                "iconText": item.iconText || "",
                "iconName": item.iconName || "",
                "accessoryText": item.accessoryText || "",
                "accessoryColor": item.accessoryColor || "#55ccff",
                "aliasText": item.aliasText || "",
                "isActive": item.isActive === true,
                "actionLabel": item.actionLabel || "Open",
                "launchType": item.launchType || "",
                "launchValue": item.launchValue || "",
                "launchKey": item.launchKey || "",
                "calcQuestion": item.calcQuestion || "",
                "calcQuestionUnit": item.calcQuestionUnit || "",
                "calcAnswer": item.calcAnswer || "",
                "calcAnswerUnit": item.calcAnswerUnit || ""
            }
        }
    }

    function processNextUsageRegistration() {
        if (usageRegisterQueue.length === 0 || usageRegisterProcess.running)
            return

        const key = usageRegisterQueue[0]
        usageRegisterQueue = usageRegisterQueue.slice(1)
        usageRegisterProcess.command = ["python3", usageScriptPath, "register", key]
        usageRegisterProcess.running = true
    }

    function registerItemUsage(item) {
        const key = usageKeyForItem(item)

        if (key === "")
            return

        const next = ({})
        for (const existingKey in usageCounts)
            next[existingKey] = usageCounts[existingKey]

        next[key] = (next[key] || 0) + 1
        usageCounts = next
        usageRegisterQueue = usageRegisterQueue.concat([key])
        processNextUsageRegistration()
        rebuildResults()
    }

    function processUsageDumpLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            usageCounts = JSON.parse(line)
        } catch (error) {
            usageCounts = ({})
            statusMessage = "Failed to load launcher history"
        }
    }

    function loadUsageCounts() {
        if (loadingUsage)
            return

        loadingUsage = true
        usageCounts = ({})
        usageLoader.running = true
    }

    function processFavoritesDumpLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            const parsed = JSON.parse(line)
            favoriteItems = Array.isArray(parsed) ? parsed : []
            rebuildFavoriteKeys()
        } catch (error) {
            favoriteItems = []
            favoriteKeys = ({})
            statusMessage = "Failed to parse favorites"
        }
    }

    function processFavoriteToggleLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            const payload = JSON.parse(line)
            statusMessage = payload.added === true ? "Added to favorites" : "Removed from favorites"
        } catch (error) {
            statusMessage = "Updated favorites"
        }
    }

    function loadFavorites() {
        if (loadingFavorites)
            return

        loadingFavorites = true
        favoriteItems = []
        favoriteKeys = ({})
        favoritesLoader.command = ["python3", favoritesScriptPath, "dump"]
        favoritesLoader.running = true
    }

    function toggleCurrentFavorite() {
        if (clipboardMode || wallpaperMode || !currentItem || !currentItem.selectable)
            return false

        const item = snapshotItem(currentItem)
        const key = favoriteKeyForItem(item)

        if (!item || key === "")
            return false

        item.launchKey = key
        favoriteToggleProcess.command = ["python3", favoritesScriptPath, "toggle", JSON.stringify(item)]
        favoriteToggleProcess.running = true
        return true
    }

    function processCatalogLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            catalogBuffer.push(JSON.parse(line))
        } catch (error) {
            statusMessage = "Failed to parse application catalog"
        }
    }

    function processFileSearchLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            fileResultsBuffer.push(JSON.parse(line))
        } catch (error) {
            statusMessage = "Failed to parse file results"
        }
    }

    function stopFileSearch(clearPendingResults) {
        fileSearchDebounce.stop()

        if (clearPendingResults) {
            pendingFileSearchQuery = ""
            activeFileSearchQuery = ""
        }

        fileResultsBuffer = []

        if (fileSearchProcess.running) {
            cancelingFileSearch = true
            fileSearchProcess.running = false
        } else {
            loadingFiles = false
        }
    }

    function startFileSearch(searchQuery) {
        const trimmed = (searchQuery || "").trim()
        const normalized = normalizeText(trimmed)

        pendingFileSearchQuery = trimmed

        if ((normalized.length < 3) && !trimmed.startsWith("/")) {
            stopFileSearch(true)
            fileResults = []
            rebuildResults()
            return
        }

        if (fileSearchProcess.running) {
            stopFileSearch(false)
            return
        }

        activeFileSearchQuery = trimmed
        fileResultsBuffer = []
        fileResults = []
        loadingFiles = true
        fileSearchProcess.command = ["python3", fileSearchScriptPath, trimmed, "60"]
        fileSearchProcess.running = true
        rebuildResults()
    }

    function refreshFileSearch() {
        pendingFileSearchQuery = (query || "").trim()
        fileSearchDebounce.restart()
    }

    function refreshCatalog() {
        if (loadingCatalog)
            return

        loadingCatalog = true
        statusMessage = ""
        catalogBuffer = []
        catalogLoader.running = true
    }

    function enterClipboardHistory() {
        previousSearchQuery = query
        stopFileSearch(true)
        fileResults = []
        statusMessage = ""
        clipboardStatusMessage = ""
        clipboardMode = true
        query = ""
        selectedClipboardIndex = -1
        refreshClipboardHistory()
    }

    function exitClipboardHistory(restoreQuery) {
        if (!clipboardMode)
            return

        if (clipboardLoader.running)
            clipboardLoader.running = false

        if (clipboardPreviewProcess.running)
            clipboardPreviewProcess.running = false

        cancelingClipboardPreview = false

        clipboardMode = false
        loadingClipboard = false
        loadingClipboardPreview = false
        clipboardStatusMessage = ""
        selectedClipboardIndex = -1
        activeClipboardPreviewToken = ""
        pendingClipboardPreviewToken = ""
        query = restoreQuery ? previousSearchQuery : ""
        previousSearchQuery = ""
        refreshFileSearch()
        rebuildResults()
    }

    function enterWallpaperPicker() {
        previousSearchQuery = query
        stopFileSearch(true)
        fileResults = []
        statusMessage = ""
        wallpaperStatusMessage = ""
        wallpaperMode = true
        query = ""
        selectedIndex = -1
        resultsModel.clear()
        refreshWallpapers()
    }

    function exitWallpaperPicker(restoreQuery) {
        if (!wallpaperMode)
            return

        if (wallpaperLoader.running)
            wallpaperLoader.running = false

        wallpaperMode = false
        loadingWallpapers = false
        wallpaperStatusMessage = ""
        selectedIndex = -1
        query = restoreQuery ? previousSearchQuery : ""
        previousSearchQuery = ""
        refreshFileSearch()
        rebuildResults()
    }

    function resetForClose() {
        if (clipboardMode)
            exitClipboardHistory(false)
        else if (wallpaperMode)
            exitWallpaperPicker(false)
        else
            clearQuery()
    }

    function refreshWallpapers() {
        if (loadingWallpapers)
            return

        loadingWallpapers = true
        wallpaperStatusMessage = ""
        wallpaperItemsBuffer = []
        wallpaperLoader.command = ["python3", wallpaperScriptPath, "list"]
        wallpaperLoader.running = true
    }

    function processWallpaperLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            const item = JSON.parse(line)

            if (item.error) {
                wallpaperStatusMessage = item.error
                return
            }

            wallpaperItemsBuffer.push(item)
        } catch (error) {
            wallpaperStatusMessage = "Failed to parse wallpapers"
        }
    }

    function wallpaperMatchScore(item, token) {
        if (token === "")
            return 0

        const combined = [item.title, item.subtitle, item.aliasText, (item.keywords || []).join(" "), item.launchValue].join(" ")
        const score = fuzzyScore(combined, token)

        if (score >= 0)
            return score

        return stringContainsToken(combined, token) ? 1 : -1
    }

    function replaceWallpaperItems(items) {
        wallpaperItems = items || []
        rebuildWallpaperResults()
    }

    function rebuildWallpaperResults() {
        const token = normalizeText(query)
        const source = []

        for (let i = 0; i < wallpaperItems.length; i++) {
            const item = wallpaperItems[i]
            const score = wallpaperMatchScore(item, token)

            if (token !== "" && score < 0)
                continue

            source.push({ "item": item, "score": score, "order": i })
        }

        source.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score
            return left.order - right.order
        })

        resultsModel.clear()

        for (let j = 0; j < source.length; j++) {
            const item = source[j].item
            resultsModel.append({
                "isSection": false,
                "selectable": true,
                "kind": item.kind || "result",
                "sectionName": item.section || "Wallpapers",
                "title": item.title || "",
                "subtitle": item.subtitle || "",
                "iconText": item.iconText || "󰋩",
                "iconName": item.iconName || "",
                "accessoryText": item.accessoryText || "",
                "accessoryColor": item.accessoryColor || "#b8a1ff",
                "aliasText": item.aliasText || "",
                "isActive": item.isActive === true,
                "actionLabel": item.actionLabel || "Set Wallpaper",
                "launchType": item.launchType || "",
                "launchValue": item.launchValue || "",
                "launchKey": item.launchKey || "",
                "previewPath": item.previewPath || "",
                "isVideo": item.isVideo === true,
                "calcQuestion": "",
                "calcQuestionUnit": "",
                "calcAnswer": "",
                "calcAnswerUnit": ""
            })
        }

        selectedIndex = nextSelectableIndex(-1, 1)
    }

    function refreshClipboardHistory() {
        if (loadingClipboard)
            return

        loadingClipboard = true
        clipboardStatusMessage = ""
        clipboardItemsBuffer = []
        clipboardLoader.command = ["python3", clipboardScriptPath, "list", "", "750"]
        clipboardLoader.running = true
    }

    function processClipboardLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            const item = JSON.parse(line)

            if (item.error) {
                clipboardStatusMessage = item.error
                return
            }

            clipboardItemsBuffer.push(item)
        } catch (error) {
            clipboardStatusMessage = "Failed to parse clipboard history"
        }
    }

    function appendClipboardItem(item) {
        clipboardModel.append({
            "itemId": item.itemId || "",
            "rawToken": item.rawToken || "",
            "title": item.title || "",
            "subtitle": item.subtitle || "",
            "previewText": item.previewText || "",
            "iconText": item.iconText || "T",
            "isImage": item.isImage === true,
            "imagePath": item.imagePath || "",
            "mime": item.mime || "",
            "sizeText": item.sizeText || "",
            "dimensions": item.dimensions || "",
            "md5": item.md5 || "",
            "copiedAt": item.copiedAt || ""
        })
    }

    function clipboardMatchScore(item, token) {
        if (token === "")
            return 0

        const combined = [item.title, item.subtitle, item.previewText, item.mime, item.itemId].join(" ")
        const score = fuzzyScore(combined, token)

        if (score >= 0)
            return score

        return stringContainsToken(combined, token) ? 1 : -1
    }

    function replaceClipboardItems(items) {
        clipboardItems = items || []
        rebuildClipboardResults()
    }

    function rebuildClipboardResults() {
        const token = normalizeText(query)
        const source = []

        for (let i = 0; i < clipboardItems.length; i++) {
            const item = clipboardItems[i]
            const score = clipboardMatchScore(item, token)

            if (token !== "" && score < 0)
                continue

            source.push({ "item": item, "score": score, "order": i })
        }

        source.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score
            return left.order - right.order
        })

        clipboardModel.clear()

        for (let j = 0; j < source.length; j++)
            appendClipboardItem(source[j].item)

        selectedClipboardIndex = clipboardModel.count > 0 ? 0 : -1
        requestClipboardPreviewForCurrent()
    }

    function selectClipboardIndex(index) {
        if (index < 0 || index >= clipboardModel.count) {
            selectedClipboardIndex = -1
            return
        }

        selectedClipboardIndex = index
        requestClipboardPreviewForCurrent()
    }

    function moveClipboardSelection(direction) {
        if (clipboardModel.count === 0)
            return

        let nextIndex = selectedClipboardIndex + direction

        if (nextIndex < 0)
            nextIndex = clipboardModel.count - 1
        else if (nextIndex >= clipboardModel.count)
            nextIndex = 0

        selectClipboardIndex(nextIndex)
    }

    function clipboardItemSnapshot(item) {
        if (!item)
            return null

        try {
            return JSON.parse(JSON.stringify(item))
        } catch (error) {
            return {
                "itemId": item.itemId || "",
                "rawToken": item.rawToken || "",
                "title": item.title || "",
                "subtitle": item.subtitle || "",
                "previewText": item.previewText || "",
                "isImage": item.isImage === true,
                "imagePath": item.imagePath || "",
                "mime": item.mime || "",
                "sizeText": item.sizeText || "",
                "md5": item.md5 || "",
                "copiedAt": item.copiedAt || ""
            }
        }
    }

    function activateClipboardCurrent() {
        const item = clipboardItemSnapshot(selectedClipboardItem)

        if (!item || !item.rawToken)
            return false

        clipboardStatusMessage = "Pasting clipboard item..."
        clipboardActionProcess.command = ["python3", clipboardScriptPath, "paste", item.rawToken]
        clipboardActionProcess.running = true
        resultActivated(item)
        closeRequested()
        return true
    }

    function copyClipboardCurrent() {
        const item = clipboardItemSnapshot(selectedClipboardItem)

        if (!item || !item.rawToken)
            return false

        clipboardStatusMessage = "Copying clipboard item..."
        clipboardActionProcess.command = ["python3", clipboardScriptPath, "copy", item.rawToken]
        clipboardActionProcess.running = true
        return true
    }

    function startClipboardPreview(token) {
        if (!token) {
            loadingClipboardPreview = false
            return
        }

        activeClipboardPreviewToken = token
        pendingClipboardPreviewToken = token
        loadingClipboardPreview = true
        clipboardPreviewProcess.command = ["python3", clipboardScriptPath, "preview", token]
        clipboardPreviewProcess.running = true
    }

    function requestClipboardPreviewForCurrent() {
        const item = selectedClipboardItem

        if (!clipboardMode || !item || !item.rawToken) {
            loadingClipboardPreview = false
            return
        }

        pendingClipboardPreviewToken = item.rawToken

        if (clipboardPreviewProcess.running) {
            cancelingClipboardPreview = true
            clipboardPreviewProcess.running = false
            return
        }

        startClipboardPreview(item.rawToken)
    }

    function mergeClipboardPreview(payload) {
        if (!payload || !payload.rawToken)
            return

        const nextItems = []

        for (let i = 0; i < clipboardItems.length; i++) {
            const existing = clipboardItems[i]

            if (existing.rawToken === payload.rawToken) {
                const updated = ({})
                for (const key in existing)
                    updated[key] = existing[key]

                updated.imagePath = payload.imagePath || existing.imagePath || ""
                updated.mime = payload.mime || existing.mime || ""
                updated.sizeText = payload.sizeText || existing.sizeText || ""
                updated.md5 = payload.md5 || existing.md5 || ""
                updated.previewText = payload.previewText || existing.previewText || ""
                nextItems.push(updated)
            } else {
                nextItems.push(existing)
            }
        }

        clipboardItems = nextItems

        for (let j = 0; j < clipboardModel.count; j++) {
            if (clipboardModel.get(j).rawToken !== payload.rawToken)
                continue

            clipboardModel.setProperty(j, "imagePath", payload.imagePath || clipboardModel.get(j).imagePath || "")
            clipboardModel.setProperty(j, "mime", payload.mime || clipboardModel.get(j).mime || "")
            clipboardModel.setProperty(j, "sizeText", payload.sizeText || clipboardModel.get(j).sizeText || "")
            clipboardModel.setProperty(j, "md5", payload.md5 || clipboardModel.get(j).md5 || "")
            clipboardModel.setProperty(j, "previewText", payload.previewText || clipboardModel.get(j).previewText || "")
            break
        }

        clipboardPreviewRevision += 1
    }

    function processClipboardPreviewLine(data) {
        const line = (data || "").trim()

        if (line === "")
            return

        try {
            const payload = JSON.parse(line)

            if (payload.error) {
                clipboardStatusMessage = payload.error
                return
            }

            mergeClipboardPreview(payload)
        } catch (error) {
            clipboardStatusMessage = "Failed to parse clipboard preview"
        }
    }

    function handleClipboardKeyPress(key, modifiers) {
        switch (key) {
        case Qt.Key_Up:
            moveClipboardSelection(-1)
            return true
        case Qt.Key_Down:
            moveClipboardSelection(1)
            return true
        case Qt.Key_Tab:
            moveClipboardSelection(1)
            return true
        case Qt.Key_Backtab:
            moveClipboardSelection(-1)
            return true
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return activateClipboardCurrent()
        case Qt.Key_B:
            if ((modifiers & Qt.ControlModifier) === 0)
                return false

            return copyClipboardCurrent()
        case Qt.Key_Escape:
            if (modifiers !== Qt.NoModifier)
                return false

            exitClipboardHistory(true)
            return true
        default:
            return false
        }
    }

    function handleWallpaperKeyPress(key, modifiers) {
        switch (key) {
        case Qt.Key_Up:
            moveWallpaperSelection(-3)
            return true
        case Qt.Key_Down:
            moveWallpaperSelection(3)
            return true
        case Qt.Key_Left:
            moveWallpaperHorizontal(-1)
            return true
        case Qt.Key_Right:
            moveWallpaperHorizontal(1)
            return true
        case Qt.Key_Tab:
            moveWallpaperSelection(1)
            return true
        case Qt.Key_Backtab:
            moveWallpaperSelection(-1)
            return true
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return activateCurrent()
        case Qt.Key_Escape:
            if (modifiers !== Qt.NoModifier)
                return false

            exitWallpaperPicker(true)
            return true
        default:
            return false
        }
    }

    function detachedProgramCommand(program, args) {
        return ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1 || exit 127; nohup \"$@\" >/dev/null 2>&1 &", "qs-vicinae-launch", program].concat(args || [])
    }

    function detachedShellCommand(command) {
        return ["sh", "-c", "nohup sh -c \"$1\" >/dev/null 2>&1 &", "qs-vicinae-launch", command]
    }

    function launchDetached(command) {
        launcherProcess.command = command
        launcherProcess.running = true
    }

    function activateItem(item) {
        const launchItem = snapshotItem(item)

        if (!launchItem || !launchItem.selectable)
            return false

        statusMessage = ""
        const launchType = launchItem.launchType || ""
        const launchValue = launchItem.launchValue || ""

        if (launchType === "clipboardHistory") {
            enterClipboardHistory()
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            return true
        }

        if (launchType === "wallpaperPicker") {
            enterWallpaperPicker()
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            return true
        }

        if (launchType === "wallpaper" && launchValue) {
            wallpaperApplyProcess.command = ["python3", wallpaperScriptPath, "apply", launchValue]
            wallpaperApplyProcess.running = true
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if (launchType === "copy") {
            clipboardCopyProcess.command = ["wl-copy", launchValue || launchItem.calcAnswer || ""]
            clipboardCopyProcess.running = true
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if (launchType === "desktop" && launchValue) {
            launchDetached(detachedProgramCommand("gtk-launch", [launchValue]))
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if ((launchType === "file" || launchType === "url") && launchValue) {
            launchDetached(detachedProgramCommand("xdg-open", [launchValue]))
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if (launchType === "command" && launchValue) {
            launchDetached(detachedShellCommand(launchValue))
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        statusMessage = launchType === "" ? "Selected item is missing launch data" : "Selected item cannot be launched"
        return false
    }

    function appendSection(sectionName, items) {
        if (!items || items.length === 0)
            return

        resultsModel.append({
            "isSection": true,
            "selectable": false,
            "kind": "section",
            "sectionName": sectionName,
            "title": "",
            "subtitle": "",
            "iconText": "",
            "iconName": "",
            "accessoryText": "",
            "accessoryColor": "#00000000",
            "aliasText": "",
            "isActive": false,
            "actionLabel": "",
            "launchType": "",
            "launchValue": "",
            "launchKey": "",
            "previewPath": "",
            "isVideo": false,
            "calcQuestion": "",
            "calcQuestionUnit": "",
            "calcAnswer": "",
            "calcAnswerUnit": ""
        })

        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            resultsModel.append({
                "isSection": false,
                "selectable": true,
                "kind": item.kind || "result",
                "sectionName": item.section || sectionName,
                "title": item.title || "",
                "subtitle": item.subtitle || "",
                "iconText": item.iconText || "󰍉",
                "iconName": item.iconName || "",
                "accessoryText": item.accessoryText || "",
                "accessoryColor": item.accessoryColor || "#55ccff",
                "aliasText": item.aliasText || "",
                "isActive": item.isActive === true,
                "actionLabel": item.actionLabel || "Open",
                "launchType": item.launchType || "",
                "launchValue": item.launchValue || "",
                "launchKey": item.launchKey || "",
                "previewPath": item.previewPath || "",
                "isVideo": item.isVideo === true,
                "calcQuestion": item.calcQuestion || "",
                "calcQuestionUnit": item.calcQuestionUnit || "",
                "calcAnswer": item.calcAnswer || "",
                "calcAnswerUnit": item.calcAnswerUnit || ""
            })
        }
    }

    function nextSelectableIndex(fromIndex, direction) {
        if (resultsModel.count === 0)
            return -1

        let index = fromIndex

        for (let step = 0; step < resultsModel.count; step++) {
            index += direction

            if (index < 0)
                index = resultsModel.count - 1
            else if (index >= resultsModel.count)
                index = 0

            const candidate = resultsModel.get(index)
            if (candidate && candidate.selectable)
                return index
        }

        return -1
    }

    function selectIndex(index) {
        if (index < 0 || index >= resultsModel.count) {
            selectedIndex = -1
            return
        }

        const candidate = resultsModel.get(index)
        if (!candidate || !candidate.selectable)
            return

        selectedIndex = index
    }

    function moveSelection(direction) {
        const startIndex = selectedIndex >= 0 ? selectedIndex : direction > 0 ? -1 : 0
        const nextIndex = nextSelectableIndex(startIndex, direction)

        if (nextIndex >= 0)
            selectedIndex = nextIndex
    }

    function moveWallpaperSelection(delta) {
        const count = resultsModel.count

        if (count === 0)
            return

        let nextIndex = selectedIndex >= 0 ? selectedIndex + delta : 0

        if (nextIndex < 0)
            nextIndex = 0
        else if (nextIndex >= count)
            nextIndex = count - 1

        selectIndex(nextIndex)
    }

    function moveWallpaperHorizontal(direction) {
        const count = resultsModel.count

        if (count === 0)
            return

        const columns = 3
        const current = selectedIndex >= 0 ? selectedIndex : 0
        const column = current % columns

        if (direction < 0 && column === 0)
            return

        if (direction > 0 && (column === columns - 1 || current === count - 1))
            return

        selectIndex(current + direction)
    }

    function activateIndex(index) {
        if (index < 0 || index >= resultsModel.count)
            return false

        const item = resultsModel.get(index)
        if (!item || !item.selectable)
            return false

        return activateItem(item)
    }

    function activateCurrent() {
        return activateIndex(selectedIndex)
    }

    function runQueryAsCommand() {
        const item = buildCommandResult(query, true)

        if (!item)
            return false

        return activateItem(item)
    }

    function selectableCount() {
        let count = 0

        for (let i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).selectable)
                count++
        }

        return count
    }

    function clearQuery() {
        setQuery("")
    }

    function setQuery(value) {
        if (query === value)
            return

        if (clipboardMode) {
            clipboardStatusMessage = ""
            query = value
            rebuildClipboardResults()
            return
        }

        if (wallpaperMode) {
            wallpaperStatusMessage = ""
            query = value
            rebuildWallpaperResults()
            return
        }

        statusMessage = ""
        query = value
        refreshFileSearch()
        rebuildResults()
    }

    function replaceCatalog(items) {
        catalog = items || []
        rebuildResults()
    }

    function handleKeyPress(key, modifiers) {
        if (clipboardMode)
            return handleClipboardKeyPress(key, modifiers)

        if (wallpaperMode)
            return handleWallpaperKeyPress(key, modifiers)

        switch (key) {
        case Qt.Key_Up:
            moveSelection(-1)
            return true
        case Qt.Key_Down:
            moveSelection(1)
            return true
        case Qt.Key_Tab:
            moveSelection(1)
            return true
        case Qt.Key_Backtab:
            moveSelection(-1)
            return true
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if ((modifiers & Qt.ControlModifier) !== 0)
                return runQueryAsCommand()

            return activateCurrent()
        case Qt.Key_D:
            if ((modifiers & Qt.ControlModifier) === 0)
                return false

            return toggleCurrentFavorite()
        case Qt.Key_Escape:
            if (modifiers !== Qt.NoModifier)
                return false

            closeRequested()
            return true
        default:
            return false
        }
    }

    function rebuildResults() {
        if (clipboardMode || wallpaperMode)
            return

        const token = normalizeText(query)
        const groups = {}
        const order = []
        const source = []
        const calculatorItem = buildCalculatorResult(query)
        const webItem = buildWebSearchResult(query)
        const commandItem = buildCommandResult(query, false)

        if (calculatorItem)
            source.push({ "item": calculatorItem, "score": 9999 + usageScoreForItem(calculatorItem, token), "order": -1 })

        for (let favoriteIndex = 0; favoriteIndex < favoriteItems.length; favoriteIndex++) {
            const favoriteItem = favoriteItems[favoriteIndex]
            const favoriteScore = token === "" ? 30 : matchScore(favoriteItem, token)

            if (token !== "" && favoriteScore < 0)
                continue

            const favoriteClone = ({})
            for (const favoriteKey in favoriteItem)
                favoriteClone[favoriteKey] = favoriteItem[favoriteKey]

            favoriteClone.section = "Favorites"
            favoriteClone.accessoryText = favoriteClone.accessoryText || "Favorite"
            favoriteClone.accessoryColor = favoriteClone.accessoryColor || "#ffd166"

            source.push({
                "item": favoriteClone,
                "score": favoriteScore + 1000 + usageScoreForItem(favoriteClone, token),
                "order": favoriteIndex
            })
        }

        for (let quickIndex = 0; quickIndex < quickActionsCatalog.length; quickIndex++) {
            const item = quickActionsCatalog[quickIndex]
            const score = token === "" ? 2 : matchScore(item, token)

            if (token !== "" && score < 0)
                continue

            if (isFavoriteItem(item))
                continue

            source.push({
                "item": item,
                "score": score + usageScoreForItem(item, token),
                "order": quickIndex
            })
        }

        for (let i = 0; i < catalog.length; i++) {
            const item = catalog[i]
            const score = token === "" ? 0 : matchScore(item, token)

            if (token !== "" && score < 0)
                continue

            if (isFavoriteItem(item))
                continue

            source.push({
                "item": item,
                "score": score + usageScoreForItem(item, token),
                "order": 100 + i
            })
        }

        if (token !== "") {
            for (let powerIndex = 0; powerIndex < powerCatalog.length; powerIndex++) {
                const item = powerCatalog[powerIndex]
                const score = matchScore(item, token)

                if (score < 0)
                    continue

                if (isFavoriteItem(item))
                    continue

                source.push({
                    "item": item,
                    "score": score + usageScoreForItem(item, token),
                    "order": catalog.length + 10000 + powerIndex
                })
            }
        }

        for (let fileIndex = 0; fileIndex < fileResults.length; fileIndex++) {
            const item = fileResults[fileIndex]
            const score = token === "" ? 0 : matchScore(item, token)

            if (token !== "" && score < 0)
                continue

            if (isFavoriteItem(item))
                continue

            source.push({
                "item": item,
                "score": score + usageScoreForItem(item, token),
                "order": 100000 + fileIndex
            })
        }

        if (webItem && !isFavoriteItem(webItem))
            source.push({ "item": webItem, "score": (looksLikeUrl(query) ? 120 : 18) + usageScoreForItem(webItem, token), "order": 200000 })

        if (commandItem && !isFavoriteItem(commandItem))
            source.push({ "item": commandItem, "score": 16 + usageScoreForItem(commandItem, token), "order": 200001 })

        source.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score
            return left.order - right.order
        })

        for (let j = 0; j < source.length; j++) {
            const entry = source[j]
            const sectionName = entry.item.section || "Results"

            if (!groups[sectionName]) {
                groups[sectionName] = []
                order.push(sectionName)
            }

            groups[sectionName].push(entry.item)
        }

        resultsModel.clear()

        for (let sectionIndex = 0; sectionIndex < order.length; sectionIndex++) {
            const sectionName = order[sectionIndex]
            appendSection(sectionName, groups[sectionName])
        }

        selectedIndex = nextSelectableIndex(-1, 1)
    }

    ListModel {
        id: resultsModel
    }

    ListModel {
        id: clipboardModel
    }

    Timer {
        id: fileSearchDebounce
        interval: 220
        repeat: false
        onTriggered: root.startFileSearch(root.pendingFileSearchQuery)
    }

    Process {
        id: usageLoader
        command: ["python3", root.usageScriptPath, "dump"]

        stdout: SplitParser {
            onRead: data => root.processUsageDumpLine(data)
        }

        onExited: function(code, status) {
            root.loadingUsage = false

            if (code !== 0) {
                root.statusMessage = "Failed to load launcher history"
                root.usageCounts = ({})
            }

            root.rebuildResults()
        }
    }

    Process {
        id: favoritesLoader
        command: []

        stdout: SplitParser {
            onRead: data => root.processFavoritesDumpLine(data)
        }

        onExited: function(code, status) {
            root.loadingFavorites = false

            if (code !== 0) {
                root.favoriteItems = []
                root.favoriteKeys = ({})
                root.statusMessage = "Failed to load favorites"
            }

            root.rebuildResults()
        }
    }

    Process {
        id: catalogLoader
        command: ["python3", root.catalogScriptPath]

        stdout: SplitParser {
            onRead: data => root.processCatalogLine(data)
        }

        onExited: function(code, status) {
            root.loadingCatalog = false

            if (code === 0) {
                root.replaceCatalog(root.catalogBuffer.slice())
                root.statusMessage = root.catalog.length === 0 ? "No applications found" : ""
            } else {
                root.statusMessage = "Failed to load applications"
                root.replaceCatalog([])
            }
        }
    }

    Process {
        id: fileSearchProcess
        command: []

        stdout: SplitParser {
            onRead: data => root.processFileSearchLine(data)
        }

        onExited: function(code, status) {
            const completedQuery = root.activeFileSearchQuery
            const wasCanceled = root.cancelingFileSearch

            root.cancelingFileSearch = false

            root.loadingFiles = false

            if (wasCanceled) {
                root.fileResultsBuffer = []
                root.rebuildResults()

                if (root.normalizeText(root.pendingFileSearchQuery) !== root.normalizeText(completedQuery))
                    root.startFileSearch(root.pendingFileSearchQuery)

                return
            }

            if (code === 0) {
                if (root.normalizeText(completedQuery) === root.normalizeText(root.query))
                    root.fileResults = root.fileResultsBuffer.slice()
            } else {
                root.fileResults = []
                root.statusMessage = "Failed to search files"
            }

            root.fileResultsBuffer = []
            root.rebuildResults()

            if (root.normalizeText(root.pendingFileSearchQuery) !== root.normalizeText(completedQuery))
                root.startFileSearch(root.pendingFileSearchQuery)
        }
    }

    Process {
        id: wallpaperLoader
        command: []

        stdout: SplitParser {
            onRead: data => root.processWallpaperLine(data)
        }

        onExited: function(code, status) {
            root.loadingWallpapers = false

            if (!root.wallpaperMode) {
                root.wallpaperItemsBuffer = []
                return
            }

            if (code === 0) {
                root.replaceWallpaperItems(root.wallpaperItemsBuffer.slice())

                if (root.resultsModel.count === 0 && root.wallpaperStatusMessage === "")
                    root.wallpaperStatusMessage = "No wallpapers found in ~/wallpapers"
            } else {
                root.wallpaperStatusMessage = "Failed to load wallpapers"
                root.replaceWallpaperItems([])
            }

            root.wallpaperItemsBuffer = []
        }
    }

    Process {
        id: clipboardLoader
        command: []

        stdout: SplitParser {
            onRead: data => root.processClipboardLine(data)
        }

        onExited: function(code, status) {
            root.loadingClipboard = false

            if (code === 0) {
                root.replaceClipboardItems(root.clipboardItemsBuffer.slice())
                root.clipboardStatusMessage = root.clipboardModel.count === 0 ? "No clipboard items found" : ""
            } else {
                root.clipboardStatusMessage = "Failed to load clipboard history"
                root.replaceClipboardItems([])
            }

            root.clipboardItemsBuffer = []
        }
    }

    Process {
        id: clipboardPreviewProcess
        command: []

        stdout: SplitParser {
            onRead: data => root.processClipboardPreviewLine(data)
        }

        onExited: function(code, status) {
            const completedToken = root.activeClipboardPreviewToken
            const wasCanceled = root.cancelingClipboardPreview

            root.cancelingClipboardPreview = false
            root.loadingClipboardPreview = false

            if (code !== 0 && !wasCanceled && root.clipboardStatusMessage === "")
                root.clipboardStatusMessage = "Failed to load clipboard preview"

            if (root.clipboardMode && root.pendingClipboardPreviewToken !== "" && root.pendingClipboardPreviewToken !== completedToken)
                root.startClipboardPreview(root.pendingClipboardPreviewToken)
        }
    }

    Process {
        id: launcherProcess
        command: []

        onExited: function(code, status) {
            if (code !== 0)
                root.statusMessage = "Failed to launch application"
        }
    }

    Process {
        id: usageRegisterProcess
        command: []

        onExited: function(code, status) {
            if (code !== 0 && root.statusMessage === "")
                root.statusMessage = "Failed to save launcher history"

            root.processNextUsageRegistration()
        }
    }

    Process {
        id: favoriteToggleProcess
        command: []

        stdout: SplitParser {
            onRead: data => root.processFavoriteToggleLine(data)
        }

        onExited: function(code, status) {
            if (code !== 0) {
                root.statusMessage = "Failed to update favorites"
                return
            }

            root.loadFavorites()
        }
    }

    Process {
        id: wallpaperApplyProcess
        command: []

        stdout: SplitParser {
            onRead: data => Theme.processThemeLine(data)
        }

        onExited: function(code, status) {
            if (code !== 0)
                root.statusMessage = "Failed to apply wallpaper"
            else
                Theme.refreshWallpaperTheme()
        }
    }

    Process {
        id: clipboardCopyProcess
        command: []

        onExited: function(code, status) {
            if (code !== 0)
                root.statusMessage = "Failed to copy result"
        }
    }

    Process {
        id: clipboardActionProcess
        command: []

        onExited: function(code, status) {
            if (code === 0) {
                root.clipboardStatusMessage = ""
            } else {
                root.clipboardStatusMessage = "Failed to use clipboard item"
            }
        }
    }

    Component.onCompleted: {
        loadUsageCounts()
        loadFavorites()
        refreshCatalog()
    }
}
