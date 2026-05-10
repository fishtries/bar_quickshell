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
    readonly property bool hasSearchQuery: searchState !== null && searchState.query !== undefined && searchState.query.toString().trim() !== ""
    readonly property bool searchLoading: searchState !== null && (searchState.loadingCatalog || searchState.loadingUsage || searchState.loadingFiles || searchState.loadingFavorites || searchState.loadingWallpapers || searchState.loadingClipboard || searchState.loadingClipboardPreview)
    readonly property bool showNoMatches: searchMode && searchState !== null && searchState.resultCount === 0 && hasSearchQuery && !searchLoading

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
        if (searchMode)
            results.ensureCurrentVisible()
        else if (clipboardMode)
            clipboardView.ensureCurrentVisible()
        else if (wallpaperMode)
            wallpaperGallery.ensureCurrentVisible()
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.bgSubtle
    }

    StackLayout {
        id: viewStack

        anchors.fill: parent
        currentIndex: clipboardMode ? 1 : wallpaperMode ? 2 : 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 6

            VicinaeResultsList {
                id: results

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

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: root.showNoMatches
                z: 2

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
                    text: "Try a different keyword"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }
            }
        }

        VicinaeClipboardView {
            id: clipboardView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 6
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

        VicinaeWallpaperGallery {
            id: wallpaperGallery

            Layout.fillWidth: true
            Layout.fillHeight: true
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
}
