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
    readonly property real normalSearchWidth: Math.max(560, Math.min(720, width - 120))
    readonly property real clipboardSearchWidth: Math.max(720, Math.min(860, width - 120))
    readonly property real wallpaperSearchWidth: Math.max(760, Math.min(920, width - 120))
    readonly property real searchWidth: lerp(lerp(normalSearchWidth, clipboardSearchWidth, clipboardTransitionProgress), wallpaperSearchWidth, wallpaperTransitionProgress)
    readonly property real searchHeight: input.implicitHeight
    readonly property real contentGap: 10
    readonly property real normalContentHeight: Math.max(280, Math.min(450, height - 180))
    readonly property real clipboardContentHeight: Math.max(430, Math.min(560, height - 160))
    readonly property real wallpaperContentHeight: Math.max(360, Math.min(440, height - 160))
    readonly property real contentHeight: lerp(lerp(normalContentHeight, clipboardContentHeight, clipboardTransitionProgress), wallpaperContentHeight, wallpaperTransitionProgress)
    readonly property real launcherHeight: searchHeight + contentGap + contentHeight
    readonly property real finalSearchX: (width - searchWidth) * 0.5
    readonly property real finalSearchRightX: finalSearchX + searchWidth
    readonly property real finalSearchY: Math.max(36, (height - launcherHeight) * 0.5)
    readonly property real finalSearchCenterX: finalSearchX + searchWidth * 0.5
    readonly property real finalSearchCenterY: finalSearchY + searchHeight * 0.5
    readonly property real finalContentY: finalSearchY + searchHeight + contentGap
    readonly property real orbDiameter: 28
    readonly property real orbTargetCenterX: finalSearchRightX - orbDiameter * 0.5
    readonly property real orbControlX: Math.max(launchOriginX, orbTargetCenterX) + Math.max(96, Math.abs(orbTargetCenterX - launchOriginX) * 0.28)
    readonly property real orbControlY: (launchOriginY + finalSearchCenterY) * 0.5
    readonly property real orbCenterX: quadBezier(launchOriginX, orbControlX, orbTargetCenterX, orbTravelProgress)
    readonly property real orbCenterY: quadBezier(launchOriginY, orbControlY, finalSearchCenterY, orbTravelProgress)
    readonly property real orbRightX: orbCenterX + orbDiameter * 0.5
    readonly property bool collapseSearchToOrb: closing && contentRevealProgress <= 0.001
    readonly property real morphHeightProgress: Math.min(1.0, inputMorphProgress * 2.4)
    readonly property real morphWidthProgress: inputMorphProgress
    readonly property real orbTravelOpacity: closing ? Math.pow(Math.max(0, orbTravelProgress), 8) : Math.max(0.22, Math.min(1.0, 0.22 + orbTravelProgress * 0.78))
    readonly property real orbOpacity: Math.max(0, 1.0 - inputMorphProgress * 0.92) * orbTravelOpacity
    readonly property real searchShellRight: collapseSearchToOrb ? orbRightX : lerp(orbRightX, finalSearchRightX, morphWidthProgress)
    readonly property real searchShellX: searchShellRight - searchShellWidth
    readonly property real searchShellY: collapseSearchToOrb ? orbCenterY - searchShellHeight * 0.5 : lerp(orbCenterY - orbDiameter * 0.5, finalSearchY, morphHeightProgress)
    readonly property real searchShellWidth: lerp(orbDiameter, searchWidth, morphWidthProgress)
    readonly property real searchShellHeight: lerp(orbDiameter, searchHeight, morphHeightProgress)
    readonly property real searchShellRadius: lerp(orbDiameter * 0.5, 22, morphWidthProgress)
    readonly property real searchShellOpacity: Math.max(0, Math.min(1, inputMorphProgress * 1.15))
    readonly property real inputOpacity: Math.max(0, Math.min(1, (inputMorphProgress - 0.18) / 0.82))
    readonly property real contentShellOpacity: Math.max(0, Math.min(1, contentRevealProgress * 1.1))
    readonly property real contentShellY: finalContentY - (1.0 - contentRevealProgress) * 34
    readonly property real contentShellHeight: contentHeight * contentRevealProgress
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

    function lerp(from, to, progress) {
        return from + (to - from) * progress
    }

    function quadBezier(from, control, to, progress) {
        const inv = 1.0 - progress
        return inv * inv * from + 2.0 * inv * progress * control + progress * progress * to
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
        if (clipboardMode)
            clipboardView.ensureCurrentVisible()
        else if (wallpaperMode)
            wallpaperGallery.ensureCurrentVisible()
        else
            results.ensureCurrentVisible()
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
        if (visible && !closing)
            closeLauncher()
        else
            openLauncher()
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
                width: root.orbDiameter + 44
                height: width
                visible: root.visible && root.orbOpacity > 0.001
                x: root.orbCenterX - width * 0.5
                y: root.orbCenterY - height * 0.5
                opacity: root.orbOpacity
                scale: 0.92 + root.inputMorphProgress * 0.18
                z: 1

                layer.enabled: visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: AnimationConfig.blurMaxHeavy
                    blur: 0.28 + root.orbOpacity * 0.5
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.orbDiameter
                    height: width
                    radius: width * 0.5
                    color: Theme.bgElevated
                    border.width: 1
                    border.color: Theme.borderSubtle
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.orbDiameter + 18
                    height: width
                    radius: width * 0.5
                    color: Theme.bgHover
                }
            }

            Rectangle {
                id: searchShell
                x: root.searchShellX
                y: root.searchShellY
                width: root.searchShellWidth
                height: root.searchShellHeight
                radius: root.searchShellRadius
                opacity: root.searchShellOpacity
                color: Theme.bgElevated
                border.width: 1
                border.color: Theme.borderSubtle
                clip: true
                z: 3

                VicinaeInput {
                    id: input
                    anchors.fill: parent
                    textValue: searchState ? searchState.query : ""
                    placeholderText: searchState ? searchState.placeholderText : "Search"
                    busy: searchState ? (searchState.loadingCatalog || searchState.loadingUsage || searchState.loadingFiles || searchState.loadingWallpapers || searchState.loadingClipboard || searchState.loadingClipboardPreview) : false
                    opacity: root.inputOpacity
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
                x: root.finalSearchX
                y: root.contentShellY
                width: root.searchWidth
                height: root.contentShellHeight
                radius: 26
                opacity: root.contentShellOpacity
                color: Theme.bgPopout
                border.width: 1
                border.color: Theme.borderSubtle
                clip: true
                z: 2

                Item {
                    anchors.fill: parent
                    anchors.margins: 14
                    opacity: root.contentShellOpacity
                    y: (1.0 - root.contentRevealProgress) * -26

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: footer.top
                        anchors.bottomMargin: 10

                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: Theme.bgSubtle
                        }

                        VicinaeResultsList {
                            id: results
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: root.clipboardTransitionProgress < 0.999 && root.wallpaperTransitionProgress < 0.999
                            opacity: Math.max(0, Math.min(1, 1.0 - Math.max(root.clipboardTransitionProgress, root.wallpaperTransitionProgress) * 1.25))
                            model: searchState ? searchState.resultsModel : null
                            currentIndex: searchState ? searchState.selectedIndex : -1
                            onItemPressed: function(index) {
                                if (searchState)
                                    searchState.selectIndex(index)
                            }
                            onItemHovered: function(index) {
                                if (searchState)
                                    searchState.selectIndex(index)
                            }
                            onItemActivated: function(index) {
                                if (searchState)
                                    searchState.activateIndex(index)
                            }
                        }

                        VicinaeWallpaperGallery {
                            id: wallpaperGallery
                            anchors.fill: parent
                            visible: root.wallpaperMode || root.wallpaperTransitionProgress > 0.001
                            opacity: Math.max(0, Math.min(1, root.wallpaperTransitionProgress * 1.25))
                            model: searchState ? searchState.resultsModel : null
                            currentIndex: searchState ? searchState.selectedIndex : -1
                            itemCount: searchState ? searchState.resultCount : 0
                            onItemPressed: function(index) {
                                if (searchState)
                                    searchState.selectIndex(index)
                            }
                            onItemHovered: function(index) {
                                if (searchState)
                                    searchState.selectIndex(index)
                            }
                            onItemActivated: function(index) {
                                if (searchState) {
                                    searchState.selectIndex(index)
                                    searchState.activateIndex(index)
                                }
                            }
                        }

                        VicinaeClipboardView {
                            id: clipboardView
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: root.clipboardMode || root.clipboardTransitionProgress > 0.001
                            opacity: Math.max(0, Math.min(1, root.clipboardTransitionProgress * 1.25))
                            transitionProgress: root.clipboardTransitionProgress
                            model: searchState ? searchState.clipboardModel : null
                            currentIndex: searchState ? searchState.selectedClipboardIndex : -1
                            itemCount: searchState ? searchState.clipboardModel.count : 0
                            selectedItem: searchState ? searchState.selectedClipboardItem : null
                            onItemPressed: function(index) {
                                if (searchState)
                                    searchState.selectClipboardIndex(index)
                            }
                            onItemHovered: function(index) {
                                if (searchState)
                                    searchState.selectClipboardIndex(index)
                            }
                            onItemActivated: function(index) {
                                if (searchState) {
                                    searchState.selectClipboardIndex(index)
                                    searchState.activateClipboardCurrent()
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: searchState ? root.clipboardTransitionProgress < 0.001 && root.wallpaperTransitionProgress < 0.001 && searchState.resultCount === 0 : false

                            AppIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰍉"
                                color: Theme.textSecondary
                                opacity: 0.75
                                font.pixelSize: 28
                            }

                            AppText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No matches"
                                color: Theme.textPrimary
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            AppText {
                                Layout.alignment: Qt.AlignHCenter
                                text: searchState && searchState.query !== "" ? "Try a different keyword" : "Start typing to search"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
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
