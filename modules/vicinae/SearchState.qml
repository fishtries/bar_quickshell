pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string query: ""
    property int selectedIndex: -1
    property string placeholderText: "Search apps, files, and the web..."
    property bool loadingCatalog: false
    property bool loadingFiles: false
    property bool loadingUsage: false
    property var catalogBuffer: []
    property var fileResultsBuffer: []
    property var catalog: []
    property var fileResults: []
    property var usageCounts: ({})
    property var usageRegisterQueue: []
    property string pendingFileSearchQuery: ""
    property string activeFileSearchQuery: ""
    property bool cancelingFileSearch: false
    property string statusMessage: ""
    readonly property string catalogScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_catalog.py"
    readonly property string fileSearchScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_file_search.py"
    readonly property string usageScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_usage.py"
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
    readonly property int resultCount: selectableCount()
    readonly property var currentItem: selectedIndex >= 0 && selectedIndex < resultsModel.count ? resultsModel.get(selectedIndex) : null
    readonly property string primaryActionLabel: currentItem && currentItem.selectable ? currentItem.actionLabel || "Open" : ""
    readonly property string escapeActionLabel: "Close"
    readonly property string resultSummary: resultCount === 0 ? "No results" : resultCount === 1 ? "1 result" : resultCount + " results"
    readonly property string footerStatus: loadingCatalog ? "Loading applications..." : loadingUsage ? "Loading usage history..." : loadingFiles ? "Searching files..." : statusMessage !== "" ? statusMessage : resultSummary

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

    function activateItem(item) {
        const launchItem = snapshotItem(item)

        if (!launchItem || !launchItem.selectable)
            return false

        statusMessage = ""
        const launchType = launchItem.launchType || ""
        const launchValue = launchItem.launchValue || ""

        if (launchType === "copy") {
            clipboardCopyProcess.command = ["wl-copy", launchValue || launchItem.calcAnswer || ""]
            clipboardCopyProcess.running = true
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if (launchType === "desktop" && launchValue) {
            launcherProcess.command = ["gtk-launch", launchValue]
            launcherProcess.running = true
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if ((launchType === "file" || launchType === "url") && launchValue) {
            launcherProcess.command = ["xdg-open", launchValue]
            launcherProcess.running = true
            resultActivated(launchItem)
            registerItemUsage(launchItem)
            closeRequested()
            return true
        }

        if (launchType === "command" && launchValue) {
            launcherProcess.command = ["sh", "-c", launchValue]
            launcherProcess.running = true
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
            "accessoryText": "",
            "accessoryColor": "#00000000",
            "aliasText": "",
            "isActive": false,
            "actionLabel": "",
            "launchType": "",
            "launchValue": "",
            "launchKey": "",
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
            return activateCurrent()
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
        const token = normalizeText(query)
        const groups = {}
        const order = []
        const source = []
        const calculatorItem = buildCalculatorResult(query)
        const webItem = buildWebSearchResult(query)

        if (calculatorItem)
            source.push({ "item": calculatorItem, "score": 9999 + usageScoreForItem(calculatorItem, token), "order": -1 })

        for (let i = 0; i < catalog.length; i++) {
            const item = catalog[i]
            const score = token === "" ? 0 : matchScore(item, token)

            if (token !== "" && score < 0)
                continue

            source.push({
                "item": item,
                "score": score + usageScoreForItem(item, token),
                "order": i
            })
        }

        if (token !== "") {
            for (let powerIndex = 0; powerIndex < powerCatalog.length; powerIndex++) {
                const item = powerCatalog[powerIndex]
                const score = matchScore(item, token)

                if (score < 0)
                    continue

                source.push({
                    "item": item,
                    "score": score + usageScoreForItem(item, token),
                    "order": catalog.length + powerIndex
                })
            }
        }

        for (let fileIndex = 0; fileIndex < fileResults.length; fileIndex++) {
            const item = fileResults[fileIndex]
            const score = token === "" ? 0 : matchScore(item, token)

            if (token !== "" && score < 0)
                continue

            source.push({
                "item": item,
                "score": score + usageScoreForItem(item, token),
                "order": 100000 + fileIndex
            })
        }

        if (webItem)
            source.push({ "item": webItem, "score": (looksLikeUrl(query) ? 120 : 18) + usageScoreForItem(webItem, token), "order": 200000 })

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
        id: clipboardCopyProcess
        command: []

        onExited: function(code, status) {
            if (code !== 0)
                root.statusMessage = "Failed to copy result"
        }
    }

    Component.onCompleted: {
        loadUsageCounts()
        refreshCatalog()
    }
}
