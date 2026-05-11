import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"

Item {
    id: root

    property string iconSource: ""
    property string appName: ""
    property string summary: ""
    property string body: ""
    property real progress: 0

    implicitHeight: Math.max(90, headerRow.implicitHeight + detailColumn.implicitHeight + 8 + 20)
    clip: true

    RowLayout {
        id: headerRow
        x: 14
        y: (10 * root.progress) + (Math.max(0, (root.height - implicitHeight) / 2) * (1 - root.progress))
        width: Math.max(0, parent.width - 28)
        spacing: 10

        AppIcon {
            text: root.iconSource
            font.pixelSize: 16 + (2 * root.progress)
            color: Theme.info
            Layout.alignment: Qt.AlignVCenter
        }

        AppText {
            text: root.appName
            color: Theme.textPrimary
            elide: Text.ElideRight
            font.pixelSize: 13 + root.progress
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Item {
        id: detailWrapper
        x: 14
        y: headerRow.y + headerRow.height + 8
        width: Math.max(0, parent.width - 28)
        height: detailColumn.implicitHeight * root.progress
        opacity: root.progress
        clip: true

        Column {
            id: detailColumn
            width: parent.width
            spacing: 4

            AppText {
                width: parent.width
                text: root.summary
                color: Theme.textPrimary
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            AppText {
                width: parent.width
                text: root.body
                visible: text !== ""
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                maximumLineCount: 5
                elide: Text.ElideRight
                font.pixelSize: 13
            }
        }
    }
}
