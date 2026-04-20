import Quickshell
import Quickshell.Wayland
import QtQuick
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
    property bool opened: false
    property bool closing: false
    readonly property bool keyboardInteractive: visible && opened && !closing && popupShell.opacity >= 0.999

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
        item: popupShell
    }

    function focusInput() {
        input.inputItem.forceActiveFocus()
        input.inputItem.cursorPosition = input.inputItem.text.length
    }

    function syncListPosition() {
        results.ensureCurrentVisible()
    }

    function openLauncher() {
        closeTimer.stop()
        closing = false

        if (!visible) {
            visible = true
            return
        }

        opened = true

        if (autoFocusInput)
            openFocusTimer.restart()
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

        openFocusTimer.stop()
        closing = true
        opened = false
        closeTimer.restart()
    }

    onVisibleChanged: {
        closeTimer.stop()
        openFocusTimer.stop()

        if (visible) {
            closing = false
            opened = false

            if (resetOnVisible && searchState)
                searchState.clearQuery()

            Qt.callLater(function() {
                if (root.visible)
                    root.opened = true
            })

            if (autoFocusInput)
                openFocusTimer.start()
        } else {
            opened = false
            closing = false
        }
    }

    Timer {
        id: openFocusTimer
        interval: root.animationDuration
        repeat: false
        onTriggered: {
            if (root.visible && root.opened)
                root.focusInput()
        }
    }

    Timer {
        id: closeTimer
        interval: root.animationDuration
        repeat: false
        onTriggered: {
            root.closing = false
            if (root.searchState)
                root.searchState.clearQuery()
            root.visible = false
            root.closeRequested()
        }
    }

    Item {
        anchors.fill: parent

        FocusScope {
            id: popupShell
            anchors.centerIn: parent
            width: 720
            height: 520
            opacity: root.opened ? 1.0 : 0.0
            scale: root.opened ? 1.0 : root.hiddenScale
            transformOrigin: Item.Center
            focus: root.visible

            Behavior on opacity {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.OutBack
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: Qt.rgba(0, 0, 0, 0.98)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                VicinaeInput {
                    id: input
                    Layout.fillWidth: true
                    textValue: searchState ? searchState.query : ""
                    placeholderText: searchState ? searchState.placeholderText : "Search"
                    busy: searchState ? (searchState.loadingCatalog || searchState.loadingUsage || searchState.loadingFiles) : false
                    onTextEdited: function(value) {
                        if (searchState)
                            searchState.setQuery(value)
                    }
                    onKeyPressed: function(key, modifiers, event) {
                        if (searchState && searchState.handleKeyPress(key, modifiers))
                            event.accepted = true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: Qt.rgba(1, 1, 1, 0.025)
                    }

                    VicinaeResultsList {
                        id: results
                        anchors.fill: parent
                        anchors.margins: 6
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

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: searchState ? searchState.resultCount === 0 : false

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
                    Layout.fillWidth: true
                    statusText: searchState ? searchState.footerStatus : ""
                    primaryActionLabel: searchState ? searchState.primaryActionLabel : ""
                    escapeActionLabel: searchState ? searchState.escapeActionLabel : ""
                    onPrimaryTriggered: {
                        if (searchState)
                            searchState.activateCurrent()
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

        function onResultActivated(item) {
            root.resultActivated(item)
        }

        function onCloseRequested() {
            root.beginClose()
        }
    }
}
