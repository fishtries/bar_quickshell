import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Item {
    id: root

    property var searchState: null
    property real clipboardTransitionProgress: 1.0
    readonly property bool searchMode: state === "search"
    readonly property bool clipboardMode: state === "clipboard"
    readonly property bool wallpaperMode: state === "wallpaper"
    readonly property bool showNoMatches: searchMode && searchState !== null && searchState.resultCount === 0

    signal itemPressed(int index)
    signal itemHovered(int index)
    signal itemActivated(int index)

    state: "search"
    states: [
        State {
            name: "search"
        },
        State {
            name: "clipboard"
        },
        State {
            name: "wallpaper"
        }
    ]

    function ensureCurrentVisible() {
        if (viewLoader.item && viewLoader.item.ensureCurrentVisible)
            viewLoader.item.ensureCurrentVisible()
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.bgSubtle
    }

    Loader {
        id: viewLoader

        anchors.fill: parent
        anchors.margins: wallpaperMode || showNoMatches ? 0 : 6
        asynchronous: true
        sourceComponent: showNoMatches ? noMatchesComponent : clipboardMode ? clipboardComponent : wallpaperMode ? wallpaperComponent : resultsComponent
        onLoaded: root.ensureCurrentVisible()
    }

    Component {
        id: resultsComponent

        VicinaeResultsList {
            anchors.fill: parent
            model: root.searchState ? root.searchState.resultsModel : null
            currentIndex: root.searchState ? root.searchState.selectedIndex : -1
            onItemPressed: function(index) {
                root.itemPressed(index)
            }
            onItemHovered: function(index) {
                root.itemHovered(index)
            }
            onItemActivated: function(index) {
                root.itemActivated(index)
            }
        }
    }

    Component {
        id: wallpaperComponent

        VicinaeWallpaperGallery {
            anchors.fill: parent
            model: root.searchState ? root.searchState.resultsModel : null
            currentIndex: root.searchState ? root.searchState.selectedIndex : -1
            itemCount: root.searchState ? root.searchState.resultCount : 0
            onItemPressed: function(index) {
                root.itemPressed(index)
            }
            onItemHovered: function(index) {
                root.itemHovered(index)
            }
            onItemActivated: function(index) {
                root.itemActivated(index)
            }
        }
    }

    Component {
        id: clipboardComponent

        VicinaeClipboardView {
            anchors.fill: parent
            transitionProgress: root.clipboardTransitionProgress
            model: root.searchState ? root.searchState.clipboardModel : null
            currentIndex: root.searchState ? root.searchState.selectedClipboardIndex : -1
            itemCount: root.searchState ? root.searchState.clipboardModel.count : 0
            selectedItem: root.searchState ? root.searchState.selectedClipboardItem : null
            onItemPressed: function(index) {
                root.itemPressed(index)
            }
            onItemHovered: function(index) {
                root.itemHovered(index)
            }
            onItemActivated: function(index) {
                root.itemActivated(index)
            }
        }
    }

    Component {
        id: noMatchesComponent

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

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
                text: root.searchState && root.searchState.query !== "" ? "Try a different keyword" : "Start typing to search"
                color: Theme.textSecondary
                font.pixelSize: 11
            }
        }
    }
}
