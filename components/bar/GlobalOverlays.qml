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

    property Item barContainer: null
    property Item centerSectionRef: null
    property Item rightSectionRef: null

    Item {
        id: popupLayer
        anchors.fill: parent
        z: 900
    }

    VicinaePopup {
        id: vicinaeLauncher
        visible: false
        launchOriginX: globalOverlays.barContainer.x + globalOverlays.centerSectionRef.x + globalOverlays.centerSectionRef.wsModule.x + globalOverlays.centerSectionRef.wsModule.launcherAnchorX
        launchOriginY: globalOverlays.barContainer.y + globalOverlays.centerSectionRef.y + globalOverlays.centerSectionRef.wsModule.y + globalOverlays.centerSectionRef.wsModule.launcherAnchorY
    }

    NotificationOverlay {}
}
