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

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            visible: root.primaryActionLabel !== ""
            spacing: 6
            Layout.preferredHeight: 24

            Rectangle {
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)
                radius: 4
                Layout.preferredWidth: primaryKeyText.implicitWidth + 10
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                AppText {
                    id: primaryKeyText
                    anchors.centerIn: parent
                    text: "Enter"
                    color: Theme.textPrimary
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            AppText {
                text: root.primaryActionLabel
                color: Theme.textSecondary
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.primaryTriggered()
            }
        }

        RowLayout {
            visible: root.secondaryActionLabel !== ""
            spacing: 6
            Layout.preferredHeight: 24

            Rectangle {
                visible: root.secondaryActionShortcut !== ""
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)
                radius: 4
                Layout.preferredWidth: secondaryKeyText.implicitWidth + 10
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                AppText {
                    id: secondaryKeyText
                    anchors.centerIn: parent
                    text: root.secondaryActionShortcut
                    color: Theme.textPrimary
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            AppText {
                text: root.secondaryActionLabel
                color: Theme.textSecondary
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.secondaryTriggered()
            }
        }

        RowLayout {
            visible: root.escapeActionLabel !== ""
            spacing: 6
            Layout.preferredHeight: 24

            Rectangle {
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)
                radius: 4
                Layout.preferredWidth: escapeKeyText.implicitWidth + 10
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                AppText {
                    id: escapeKeyText
                    anchors.centerIn: parent
                    text: "Esc"
                    color: Theme.textPrimary
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            AppText {
                text: root.escapeActionLabel
                color: Theme.textSecondary
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
