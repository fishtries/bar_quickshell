import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Rectangle {
    id: root

    property string statusText: ""
    property string primaryActionLabel: ""
    property string secondaryActionLabel: ""
    property string secondaryActionShortcut: ""
    property string escapeActionLabel: ""

    signal primaryTriggered()
    signal secondaryTriggered()

    radius: 18
    color: Theme.bgSubtle
    implicitHeight: 42

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        AppText {
            Layout.fillWidth: true
            text: root.statusText
            color: Theme.textSecondary
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Rectangle {
            visible: root.primaryActionLabel !== ""
            radius: 10
            color: Theme.bgHover
            implicitWidth: primaryLabel.implicitWidth + 14
            implicitHeight: 24

            AppText {
                id: primaryLabel
                anchors.centerIn: parent
                text: "↵ " + root.primaryActionLabel
                color: Theme.textPrimary
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.primaryTriggered()
            }
        }

        Rectangle {
            visible: root.secondaryActionLabel !== ""
            radius: 10
            color: Theme.bgHover
            implicitWidth: secondaryLabel.implicitWidth + 14
            implicitHeight: 24

            AppText {
                id: secondaryLabel
                anchors.centerIn: parent
                text: (root.secondaryActionShortcut !== "" ? root.secondaryActionShortcut + " " : "") + root.secondaryActionLabel
                color: Theme.textSecondary
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.secondaryTriggered()
            }
        }

        Rectangle {
            visible: root.escapeActionLabel !== ""
            radius: 10
            color: Theme.bgHover
            implicitWidth: escapeLabel.implicitWidth + 14
            implicitHeight: 24

            AppText {
                id: escapeLabel
                anchors.centerIn: parent
                text: "Esc " + root.escapeActionLabel
                color: Theme.textSecondary
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }
}
