import QtQuick
import "../../core"
import "../../modules/notifications"
import "../../modules/vicinae"
import "../../components"

Item {
    id: globalOverlays
    anchors.fill: parent
    z: 900

    property alias popupLayer: popupLayer
    property alias vicinaeLauncher: vicinaeLauncher
    property alias notifCardsWrapper: notifCardsWrapper

    property Item barContainer: null
    property Item centerSectionRef: null
    property Item rightSectionRef: null

    Item {
        id: popupLayer
        anchors.fill: parent
        z: 900
    }

    // ─── Notification cards below the island ────────────────────────────
    Item {
        id: notifCardsWrapper
        anchors.right: parent.right
        anchors.rightMargin: 20
        visible: !globalOverlays.rightSectionRef.ccModule.popoutOpen && globalOverlays.rightSectionRef.ccModule.isNotifIsland
        y: {
            if (!globalOverlays.rightSectionRef.ccModule.isNotifIsland) return globalOverlays.barContainer.height + 8
            var islandBottom = globalOverlays.barContainer.y + globalOverlays.rightSectionRef.y + globalOverlays.rightSectionRef.ccModule.parent.y + globalOverlays.rightSectionRef.ccModule.y + globalOverlays.rightSectionRef.ccModule.implicitHeight
            return islandBottom + 8
        }
        Behavior on y { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }

        readonly property int bottomFadeHeight: 260
        readonly property real availableHeight: Math.max(0, 800 - y - 20)
        readonly property bool contentOverflows: notifCards.implicitHeight > availableHeight
        width: notifCards.implicitWidth
        height: contentOverflows ? availableHeight : notifCards.implicitHeight
        clip: true

        NotifCardStack {
            id: notifCards
            width: notifCardsWrapper.width
            height: implicitHeight
            islandNotification: globalOverlays.rightSectionRef.ccModule.currentNotification
            viewportHeight: notifCardsWrapper.height
            bottomFadeHeight: notifCardsWrapper.bottomFadeHeight
            promotionOverlayParent: globalOverlays.parent
            promotionOverlayX: notifCardsWrapper.x
            promotionOverlayY: notifCardsWrapper.y
            promotionOverlayZ: globalOverlays.barContainer.z - 1
        }
    }

    VicinaePopup {
        id: vicinaeLauncher
        visible: false
        launchOriginX: globalOverlays.barContainer.x + globalOverlays.centerSectionRef.x + globalOverlays.centerSectionRef.wsModule.x + globalOverlays.centerSectionRef.wsModule.launcherAnchorX
        launchOriginY: globalOverlays.barContainer.y + globalOverlays.centerSectionRef.y + globalOverlays.centerSectionRef.wsModule.y + globalOverlays.centerSectionRef.wsModule.launcherAnchorY
    }

    NotificationOverlay {}
}
