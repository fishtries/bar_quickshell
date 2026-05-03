import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Item {
    id: root

    property var model: null
    property int currentIndex: -1
    property int itemCount: 0
    property var selectedItem: null
    property real transitionProgress: 1.0
    readonly property real listPanelTargetWidth: 266
    readonly property real dividerTargetWidth: 1
    readonly property real infoPanelTargetWidth: Math.max(0, width - listPanelTargetWidth - dividerTargetWidth)
    readonly property bool hasSelection: selectedItem !== null && selectedItem !== undefined
    readonly property bool selectedIsImage: hasSelection && selectedItem.isImage === true
    readonly property string selectedImagePath: hasSelection ? selectedItem.imagePath || "" : ""
    readonly property string selectedPreviewText: hasSelection ? selectedItem.previewText || "" : ""
    readonly property string selectedMime: hasSelection ? selectedItem.mime || "" : ""
    readonly property string selectedSize: hasSelection ? selectedItem.sizeText || "" : ""
    readonly property string selectedCopiedAt: hasSelection ? selectedItem.copiedAt || "" : ""
    readonly property string selectedMd5: hasSelection ? selectedItem.md5 || "" : ""

    signal itemPressed(int index)
    signal itemHovered(int index)
    signal itemActivated(int index)

    function ensureCurrentVisible() {
        if (currentIndex >= 0)
            listView.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: Math.max(220, root.width - (root.infoPanelTargetWidth + root.dividerTargetWidth) * root.transitionProgress)
            Layout.fillHeight: true
            clip: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                spacing: 8

                AppText {
                    Layout.fillWidth: true
                    text: root.itemCount === 1 ? "1 Item" : root.itemCount + " Items"
                    color: Theme.textPrimary
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                AppText {
                    text: "Enter to paste"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.model
                currentIndex: root.currentIndex
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: delegateRoot
                    required property int index
                    required property string title
                    required property string subtitle
                    required property string iconText
                    required property bool isImage

                    width: ListView.view.width
                    height: 54
                    radius: 9
                    color: root.currentIndex === index ? Theme.bgActive : mouse.containsMouse ? Theme.bgHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: root.currentIndex === delegateRoot.index ? Theme.bgActive : Theme.bgSubtle

                            AppIcon {
                                anchors.centerIn: parent
                                text: delegateRoot.isImage ? "󰋩" : delegateRoot.iconText
                                color: Theme.textPrimary
                                font.pixelSize: delegateRoot.isImage ? 16 : 18
                                font.family: delegateRoot.isImage ? Theme.fontIcon : Theme.fontPrimary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            AppText {
                                Layout.fillWidth: true
                                text: delegateRoot.title
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                font.weight: root.currentIndex === delegateRoot.index ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            AppText {
                                Layout.fillWidth: true
                                text: delegateRoot.subtitle
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.itemHovered(delegateRoot.index)
                        onClicked: root.itemPressed(delegateRoot.index)
                        onDoubleClicked: root.itemActivated(delegateRoot.index)
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: root.dividerTargetWidth * root.transitionProgress
            Layout.fillHeight: true
            opacity: root.transitionProgress
            color: Theme.borderSubtle
        }

        Item {
            id: infoPanel
            Layout.preferredWidth: root.infoPanelTargetWidth * root.transitionProgress
            Layout.fillHeight: true
            clip: true
            opacity: Math.max(0, Math.min(1, root.transitionProgress * 1.35))

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 10
                visible: root.hasSelection
                transform: Translate {
                    x: (1.0 - root.transitionProgress) * 48
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 202
                    radius: 16
                    color: Theme.bgSubtle
                    border.width: 1
                    border.color: Theme.borderSubtle
                    clip: true

                    Image {
                        visible: root.selectedIsImage && root.selectedImagePath !== ""
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 24, implicitWidth)
                        height: Math.min(parent.height - 24, implicitHeight)
                        source: root.selectedImagePath !== "" ? "file://" + root.selectedImagePath : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    ColumnLayout {
                        visible: root.selectedIsImage && root.selectedImagePath === ""
                        anchors.centerIn: parent
                        spacing: 8

                        AppIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰋩"
                            color: Theme.textSecondary
                            font.pixelSize: 32
                        }

                        AppText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Loading image preview..."
                            color: Theme.textSecondary
                            font.pixelSize: 12
                        }
                    }

                    Flickable {
                        visible: !root.selectedIsImage
                        anchors.fill: parent
                        anchors.margins: 14
                        clip: true
                        contentWidth: width
                        contentHeight: previewText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: previewText
                            width: parent.width
                            text: root.selectedPreviewText
                            color: Theme.textPrimary
                            selectedTextColor: Theme.textPrimary
                            selectionColor: Qt.rgba(0.33, 0.8, 1.0, 0.35)
                            font.pixelSize: 13
                            readOnly: true
                            wrapMode: TextEdit.WrapAnywhere
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 8

                    AppText {
                        text: "Mime"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: root.selectedMime !== "" ? root.selectedMime : "—"
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    AppText {
                        text: "Size"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: root.selectedSize !== "" ? root.selectedSize : "—"
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    AppText {
                        text: "Copied at"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: root.selectedCopiedAt !== "" ? root.selectedCopiedAt : "—"
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    AppText {
                        text: "MD5"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: root.selectedMd5 !== "" ? root.selectedMd5 : "—"
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: !root.hasSelection
                transform: Translate {
                    x: (1.0 - root.transitionProgress) * 48
                }

                AppIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰅌"
                    color: Theme.textSecondary
                    opacity: 0.75
                    font.pixelSize: 30
                }

                AppText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No clipboard items"
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
    }
}
