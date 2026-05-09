import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import "." as Vicinae
import "../../components"
import "../../core"

PanelWindow {
    id: root

    readonly property var searchState: Vicinae.SearchState
    property bool autoFocusInput: true
    property bool resetOnVisible: false
    property int animationDuration: 220
    property real hiddenScale: 0.95
    property real launchOriginX: width * 0.5
    property real launchOriginY: 52
    property real orbTravelProgress: 0.0
    property real inputMorphProgress: 0.0
    property real contentRevealProgress: 0.0
    property bool opened: false
    property bool closing: false
    readonly property bool clipboardMode: searchState ? searchState.clipboardMode : false
    readonly property bool wallpaperMode: searchState ? searchState.wallpaperMode : false
    property real clipboardTransitionProgress: clipboardMode ? 1.0 : 0.0
    property real wallpaperTransitionProgress: wallpaperMode ? 1.0 : 0.0
    readonly property bool keyboardInteractive: visible && !closing && inputMorphProgress >= 0.5

    signal closeRequested()
    signal resultActivated(var item)

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "qs-vicinae-launcher"
    WlrLayershell.keyboardFocus: keyboardInteractive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Vicinae.VicinaeMetrics {
        id: metrics

        width: root.width
        height: root.height
        clipboardTransitionProgress: root.clipboardTransitionProgress
        wallpaperTransitionProgress: root.wallpaperTransitionProgress
        inputMorphProgress: root.inputMorphProgress
        contentRevealProgress: root.contentRevealProgress
        orbTravelProgress: root.orbTravelProgress
        launchOriginX: root.launchOriginX
        launchOriginY: root.launchOriginY
        searchHeight: input.implicitHeight
        closing: root.closing
    }

    mask: Region {
        Region {
            item: orbMaskItem
        }
        Region {
            item: searchShell
        }
        Region {
            item: contentShell
        }
    }

    function resetPhases() {
        orbTravelProgress = 0.0
        inputMorphProgress = 0.0
        contentRevealProgress = 0.0
    }

    function startOpenSequence() {
        closeSequence.stop()
        closing = false
        opened = false
        openSequence.start()
    }

    function focusInput() {
        input.inputItem.forceActiveFocus()
        input.inputItem.cursorPosition = input.inputItem.text.length
    }

    function syncListPosition() {
        contentArea.ensureCurrentVisible()
    }

    function handleContentItemPressed(index) {
        if (!searchState)
            return

        if (clipboardMode)
            searchState.selectClipboardIndex(index)
        else
            searchState.selectIndex(index)
    }

    function handleContentItemActivated(index) {
        if (!searchState)
            return

        if (clipboardMode) {
            searchState.selectClipboardIndex(index)
            searchState.activateClipboardCurrent()
        } else {
            if (wallpaperMode)
                searchState.selectIndex(index)

            searchState.activateIndex(index)
        }
    }

    function openLauncher() {
        if (!visible) {
            visible = true
            return
        }

        if (opened && !closing) {
            if (autoFocusInput)
                focusInput()
            return
        }

        startOpenSequence()
    }

    function closeLauncher() {
        beginClose()
    }

    function toggleLauncher() {
        if (visible && !opened && !closing) {
            if (inputMorphProgress > 0.15 || contentRevealProgress > 0.15 || orbTravelProgress > 0.55)
                closeLauncher()
            else
                startOpenSequence()
            return
        }

        if (visible && !closing)
            closeLauncher()
        else
            openLauncher()
    }

    function openClipboardHistory() {
        if (searchState) {
            if (searchState.wallpaperMode)
                searchState.exitWallpaperPicker(false)

            if (!searchState.clipboardMode)
                searchState.enterClipboardHistory()
        }

        openLauncher()
    }

    function toggleClipboardHistory() {
        if (visible && !opened && !closing) {
            if (clipboardMode && (inputMorphProgress > 0.15 || contentRevealProgress > 0.15 || orbTravelProgress > 0.55))
                closeLauncher()
            else
                openClipboardHistory()
            return
        }

        if (visible && !closing && clipboardMode) {
            closeLauncher()
            return
        }

        openClipboardHistory()
    }

    function beginClose() {
        if (!visible || closing)
            return

        openSequence.stop()
        closing = true
        opened = false
        closeSequence.start()
    }

    onVisibleChanged: {
        openSequence.stop()
        closeSequence.stop()

        if (visible) {
            closing = false
            opened = false
            resetPhases()

            if (resetOnVisible && searchState)
                searchState.clearQuery()

            Qt.callLater(function() {
                if (root.visible)
                    root.startOpenSequence()
            })
        } else {
            resetPhases()
            opened = false
            closing = false
        }
    }

    SequentialAnimation {
        id: openSequence

        NumberAnimation {
            target: root
            property: "orbTravelProgress"
            to: 1.0
            duration: AnimationConfig.durationVeryFast
            easing.type: AnimationConfig.easingSmoothOut
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "inputMorphProgress"
                to: 1.0
                duration: AnimationConfig.durationSlow
                easing.type: AnimationConfig.easingSpringOut
                easing.period: AnimationConfig.springPeriodPopout
                easing.amplitude: AnimationConfig.springAmplitudePopout
            }

            NumberAnimation {
                target: root
                property: "contentRevealProgress"
                to: 1.0
                duration: AnimationConfig.durationExtraSlow
                easing.type: AnimationConfig.easingMovement
            }
        }

        onFinished: {
            if (!root.visible || root.closing)
                return

            root.opened = true
        }
    }

    onInputMorphProgressChanged: {
        if (inputMorphProgress >= 0.5 && !opened && !closing && visible && autoFocusInput)
            focusInput()
    }

    Behavior on clipboardTransitionProgress {
        NumberAnimation {
            duration: AnimationConfig.durationModerate
            easing.type: AnimationConfig.easingMovement
        }
    }

    Behavior on wallpaperTransitionProgress {
        NumberAnimation {
            duration: AnimationConfig.durationModerate
            easing.type: AnimationConfig.easingMovement
        }
    }

    ParallelAnimation {
        id: closeSequence

        NumberAnimation {
            target: root
            property: "contentRevealProgress"
            to: 0.0
            duration: AnimationConfig.durationQuick
            easing.type: AnimationConfig.easingDefaultIn
        }

        NumberAnimation {
            target: root
            property: "inputMorphProgress"
            to: 0.0
            duration: AnimationConfig.durationQuick
            easing.type: AnimationConfig.easingDefaultIn
        }

        NumberAnimation {
            target: root
            property: "orbTravelProgress"
            to: 0.0
            duration: AnimationConfig.durationNormal 
            easing.type: Easing.InQuint
        }

        onFinished: {
            root.closing = false

            if (root.searchState)
                root.searchState.resetForClose()

            root.visible = false
            root.closeRequested()
        }
    }

    Item {
        anchors.fill: parent

        FocusScope {
            id: popupShell
            anchors.fill: parent
            focus: root.visible

            Item {
                id: orbMaskItem
                width: metrics.orbMaskSize
                height: width
                visible: root.visible && metrics.orbOpacity > 0.001
                x: metrics.orbMaskX
                y: metrics.orbMaskY
                opacity: metrics.orbOpacity
                scale: metrics.orbMaskScale
                z: 1

                layer.enabled: visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: AnimationConfig.blurMaxHeavy
                    blur: 0.28 + metrics.orbOpacity * 0.5
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: metrics.orbDiameter
                    height: width
                    radius: width * 0.5
                    color: Theme.bgElevated
                    border.width: 1
                    border.color: Theme.borderSubtle
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: metrics.orbHaloDiameter
                    height: width
                    radius: width * 0.5
                    color: Theme.bgHover
                }
            }

            Rectangle {
                id: searchShell
                x: metrics.searchShellX
                y: metrics.searchShellY
                width: metrics.searchShellWidth
                height: metrics.searchShellHeight
                radius: metrics.searchShellRadius
                opacity: metrics.searchShellOpacity
                color: Theme.bgElevated
                border.width: 1
                border.color: Theme.borderSubtle
                clip: true
                z: 3
                layer.enabled: metrics.launcherModeTransitionBlur > 0.001
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: AnimationConfig.blurMaxLight
                    blur: metrics.launcherModeTransitionBlur
                }

                VicinaeInput {
                    id: input
                    anchors.fill: parent
                    textValue: searchState ? searchState.query : ""
                    placeholderText: searchState ? searchState.placeholderText : "Search"
                    busy: searchState ? (searchState.loadingCatalog || searchState.loadingUsage || searchState.loadingFiles || searchState.loadingWallpapers || searchState.loadingClipboard || searchState.loadingClipboardPreview) : false
                    opacity: metrics.inputOpacity
                    onTextEdited: function(value) {
                        if (searchState)
                            searchState.setQuery(value)
                    }
                    onKeyPressed: function(key, modifiers, event) {
                        if (searchState && searchState.handleKeyPress(key, modifiers))
                            event.accepted = true
                    }
                }
            }

            Rectangle {
                id: contentShell
                x: metrics.finalSearchX
                y: metrics.contentShellY
                width: metrics.searchWidth
                height: metrics.contentShellHeight
                radius: 26
                opacity: metrics.contentShellOpacity
                color: Theme.bgPopout
                border.width: 1
                border.color: Theme.borderSubtle
                clip: true
                z: 2
                layer.enabled: metrics.launcherModeTransitionBlur > 0.001
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: AnimationConfig.blurMaxNormal
                    blur: metrics.launcherModeTransitionBlur
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 14
                    opacity: metrics.contentShellOpacity
                    y: metrics.contentInnerY

                    Vicinae.VicinaeContentArea {
                        id: contentArea

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: footer.top
                        anchors.bottomMargin: 10
                        state: root.clipboardMode ? "clipboard" : root.wallpaperMode ? "wallpaper" : "search"
                        searchState: root.searchState
                        clipboardTransitionProgress: root.clipboardTransitionProgress
                        onItemPressed: function(index) { root.handleContentItemPressed(index) }
                        onItemHovered: function(index) { root.handleContentItemPressed(index) }
                        onItemActivated: function(index) { root.handleContentItemActivated(index) }
                    }

                    VicinaeFooter {
                        id: footer
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: implicitHeight
                        statusText: searchState ? searchState.footerStatus : ""
                        primaryActionLabel: searchState ? searchState.primaryActionLabel : ""
                        secondaryActionLabel: searchState ? searchState.secondaryActionLabel : ""
                        secondaryActionShortcut: searchState ? searchState.secondaryActionShortcut : ""
                        escapeActionLabel: searchState ? searchState.escapeActionLabel : ""
                        onPrimaryTriggered: {
                            if (searchState) {
                                if (root.clipboardMode)
                                    searchState.activateClipboardCurrent()
                                else
                                    searchState.activateCurrent()
                            }
                        }
                        onSecondaryTriggered: {
                            if (searchState) {
                                if (root.clipboardMode)
                                    searchState.copyClipboardCurrent()
                                else
                                    searchState.toggleCurrentFavorite()
                            }
                        }
                    }
                }
            }
        }
    }
    Connections {
        target: searchState

        function onSelectedIndexChanged() {
            root.syncListPosition()
        }

        function onSelectedClipboardIndexChanged() {
            root.syncListPosition()
        }

        function onResultActivated(item) {
            root.resultActivated(item)
        }

        function onCloseRequested() {
            root.beginClose()
        }
    }
}
