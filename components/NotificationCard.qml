import QtQuick
import QtQuick.Layouts
import "../core"

/**
 * NotificationCard
 * 
 * A reusable UI component for displaying a system notification.
 * Designed to be used in both popups and the Control Center list.
 */
Rectangle {
    id: root
    
    // Properties
    property var modelData: null
    readonly property bool hovered: mouseArea.containsMouse
    
    // Styling
    width: ListView.view ? ListView.view.width : 300
    implicitHeight: layout.implicitHeight + (Theme.spacingDefault * 2)
    radius: 12
    color: Theme.bgActive
    border.color: mouseArea.containsMouse ? Theme.info : "transparent"
    border.width: 1
    clip: true
    
    // Visual Feedback
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // Interactivity: Background Click
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            if (root.modelData) {
                root.modelData.invokeDefaultAction();
                root.modelData.dismiss();
            }
        }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingDefault
        spacing: Theme.spacingSmall

        // --- Header Section ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            AppText {
                text: root.modelData ? root.modelData.appName : "System"
                font.weight: Font.DemiBold
                font.pixelSize: 12
                color: Theme.textSecondary
                elide: Text.ElideRight
                Layout.maximumWidth: parent.width * 0.6
            }

            AppText {
                text: "•"
                font.pixelSize: 12
                color: Theme.textSecondary
            }

            AppText {
                text: "🔔" // Placeholder for notification icon/emoji
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            // Close Button
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeMouse.containsMouse ? Theme.bgHover : "transparent"
                
                AppText {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.modelData) root.modelData.dismiss()
                }
            }
        }

        // --- Summary Section ---
        AppText {
            Layout.fillWidth: true
            text: root.modelData ? root.modelData.summary : "Notification Summary"
            font.weight: Font.Bold
            font.pixelSize: 15
            color: Theme.textPrimary
            wrapMode: Text.WordWrap
        }

        // --- Body Section ---
        AppText {
            Layout.fillWidth: true
            text: root.modelData ? root.modelData.body : ""
            visible: text !== ""
            font.pixelSize: 13
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
}
