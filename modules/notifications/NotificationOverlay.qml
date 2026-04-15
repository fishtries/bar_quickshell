import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../components"

/**
 * NotificationOverlay
 * 
 * An OSD (On-Screen Display) overlay that shows temporary popup notifications.
 * Features auto-close timers with hover-to-pause logic and smooth transitions.
 */
PanelWindow {
    id: root

    // Window Configuration - attach to top-right corner
    anchors.top: true
    anchors.right: true

    // Quickshell Layer Setup
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1 // Don't shift other windows
    WlrLayershell.namespace: "qs-notifications"

    color: "transparent"

    // Dynamic Window size (includes 10px padding for margins)
    width: 390  // 380 + 10px right margin
    height: 1010 // 1000 + 10px top margin

    // Input Mask: Only capture clicks on the actual notification cards
    mask: Region {
        item: contentArea
    }

    // Inner container that applies the visual margins
    Item {
        id: contentArea
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.rightMargin: 10
        width: 380
        height: 1000

        ListView {
            id: notificationList
            anchors.fill: parent
            spacing: Theme.spacingSmall
            interactive: false // Model manages items

            model: NotificationState.activeNotifications

            delegate: Item {
                id: delegateRoot
                width: notificationList.width
                height: card.height

                NotificationCard {
                    id: card
                    modelData: model
                    anchors.right: parent.right
                }

                // Auto-close Timer
                Timer {
                    interval: 5000
                    running: !card.hovered // Pause auto-close if user is reading
                    repeat: false
                    onTriggered: {
                        if (modelData) modelData.close();
                    }
                }
            }

            // --- Animations ---

            // Enter: Slide in from right and fade in
            add: Transition {
                NumberAnimation {
                    property: "x"
                    from: notificationList.width
                    to: 0
                    duration: 500
                    easing.type: Easing.OutBack
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 400
                }
            }

            // Exit: Fade out and slide right
            remove: Transition {
                SequentialAnimation {
                    PropertyAction { property: "ListView.delayRemove"; value: true }
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 300 }
                        NumberAnimation { property: "x"; to: notificationList.width; duration: 350 }
                    }
                    PropertyAction { property: "ListView.delayRemove"; value: false }
                }
            }

            // Layout shifts: Smoothly move remaining items when one is removed
            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 500
                    easing.type: Easing.OutQuint
                }
            }
        }
    }
}
