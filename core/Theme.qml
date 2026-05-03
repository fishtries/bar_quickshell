pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string colorMode: "dark"
    property real wallpaperLuminance: -1
    property string wallpaperPath: ""
    property var wallpaperSamples: []
    readonly property bool isLight: colorMode === "light"
    readonly property string wallpaperScriptPath: "/home/fish/.config/quickshell/scripts/vicinae_wallpapers.py"

    // Цвета
    property color bgPanel: isLight ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0.05, 0.05, 0.05, 0.15)
    property color bgPopout: isLight ? Qt.rgba(0.96, 0.96, 0.96, 0.98) : Qt.rgba(0, 0, 0, 1)
    property color bgActive: isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10)
    property color bgHover: isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08)
    property color bgSubtle: isLight ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.04)
    property color bgElevated: isLight ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0, 0, 0, 0.94)
    property color borderSubtle: isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
    property color borderStrong: isLight ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(1, 1, 1, 0.18)
    
    // Акценты
    property color textPrimary: isLight ? "#111111" : "#ffffff"
    property color textSecondary: isLight ? "#555555" : "#aaaaaa"
    property color textDark: "#1f1f1f"
    property color foregroundOnWallpaper: isLight ? "#1f1f1f" : "#ffffff"
    property color foregroundOnWallpaperSecondary: isLight ? "#555555" : "#aaaaaa"
    property color success: "#55ff55"
    property color error: "#ff5555"
    property color warning: "#ffaa00"
    property color info: "#55ccff"

    // Метрики
    property int radiusPanel: 18
    property int radiusPopout: 16
    property int spacingDefault: 12
    property int spacingSmall: 8

    // Шрифты
    property string fontPrimary: "SF Pro Display" // предполагаемый дефолт
    property string fontClock: "MariosBlack"
    property string fontIcon: "JetBrainsMono Nerd Font"

    function applyWallpaperTheme(mode, luminance, path, samples) {
        root.colorMode = mode === "light" ? "light" : "dark"

        let numericLuminance = Number(luminance)
        if (!isNaN(numericLuminance))
            root.wallpaperLuminance = numericLuminance

        if (path !== undefined)
            root.wallpaperPath = path || ""

        if (samples instanceof Array)
            root.wallpaperSamples = samples
    }

    function itemCenterX(item) {
        if (!item)
            return 0.5

        if (item.mapToGlobal && item.Screen && item.Screen.width) {
            let globalPoint = item.mapToGlobal(item.width * 0.5, item.height * 0.5)
            return Math.max(0, Math.min(1, globalPoint.x / item.Screen.width))
        }

        let point = item.mapToItem(null, item.width * 0.5, item.height * 0.5)
        let window = item.Window ? item.Window.window : null
        let windowWidth = window && window.width ? window.width : 1
        return Math.max(0, Math.min(1, point.x / windowWidth))
    }

    function luminanceAtRatio(xRatio) {
        let samples = root.wallpaperSamples
        if (!samples || samples.length === 0)
            return root.wallpaperLuminance >= 0 ? root.wallpaperLuminance : (root.isLight ? 1.0 : 0.0)

        let normalized = Math.max(0, Math.min(1, Number(xRatio)))
        let index = Math.max(0, Math.min(samples.length - 1, Math.floor(normalized * samples.length)))
        let value = Number(samples[index])
        return isNaN(value) ? (root.wallpaperLuminance >= 0 ? root.wallpaperLuminance : 0.0) : value
    }

    function luminanceForItem(item) {
        return root.luminanceAtRatio(root.itemCenterX(item))
    }

    function foregroundForLuminance(luminance) {
        return luminance >= 0.52 ? Qt.rgba(0.07, 0.07, 0.07, 1) : Qt.rgba(1, 1, 1, 1)
    }

    function secondaryForegroundForLuminance(luminance) {
        return luminance >= 0.52 ? Qt.rgba(0.26, 0.26, 0.26, 1) : Qt.rgba(0.82, 0.82, 0.82, 1)
    }

    function inverseForegroundForLuminance(luminance) {
        return luminance >= 0.52 ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0.07, 0.07, 0.07, 1)
    }

    function foregroundForItem(item) {
        return root.foregroundForLuminance(root.luminanceForItem(item))
    }

    function secondaryForegroundForItem(item) {
        return root.secondaryForegroundForLuminance(root.luminanceForItem(item))
    }

    function inverseForegroundForItem(item) {
        return root.inverseForegroundForLuminance(root.luminanceForItem(item))
    }

    function translucentForegroundForItem(item, alpha) {
        let color = root.foregroundForItem(item)
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function localHoverForItem(item) {
        let luminance = root.luminanceForItem(item)
        return luminance >= 0.52 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12)
    }

    function localPanelForItem(item) {
        let luminance = root.luminanceForItem(item)
        return luminance >= 0.52 ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0.05, 0.05, 0.05, 0.15)
    }

    function refreshWallpaperTheme() {
        if (themeReader.running)
            return

        themeReader.command = ["python3", root.wallpaperScriptPath, "theme"]
        themeReader.running = true
    }

    function processThemeLine(data) {
        let line = (data || "").trim()
        if (line === "")
            return

        try {
            let payload = JSON.parse(line)
            root.applyWallpaperTheme(payload.mode, payload.luminance, payload.wallpaper, payload.samples)
        } catch (error) {
        }
    }

    Process {
        id: themeReader
        command: []

        stdout: SplitParser {
            onRead: data => root.processThemeLine(data)
        }
    }

    Component.onCompleted: refreshWallpaperTheme()
}
