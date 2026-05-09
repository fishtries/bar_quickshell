import QtQml

QtObject {
    id: root

    property real width: 0
    property real height: 0
    property real clipboardTransitionProgress: 0.0
    property real wallpaperTransitionProgress: 0.0
    property real inputMorphProgress: 0.0
    property real contentRevealProgress: 0.0
    property real orbTravelProgress: 0.0
    property real launchOriginX: width * 0.5
    property real launchOriginY: 52
    property real searchHeight: 60
    property bool closing: false

    readonly property real normalSearchWidth: Math.max(560, Math.min(720, width - 120))
    readonly property real clipboardSearchWidth: Math.max(720, Math.min(860, width - 120))
    readonly property real wallpaperSearchWidth: Math.max(760, Math.min(920, width - 120))
    readonly property real searchWidth: lerp(lerp(normalSearchWidth, clipboardSearchWidth, clipboardTransitionProgress), wallpaperSearchWidth, wallpaperTransitionProgress)
    readonly property real contentGap: 10
    readonly property real normalContentHeight: Math.max(280, Math.min(450, height - 180))
    readonly property real clipboardContentHeight: Math.max(430, Math.min(560, height - 160))
    readonly property real wallpaperContentHeight: Math.max(420, Math.min(580, height - 120))
    readonly property real contentHeight: lerp(lerp(normalContentHeight, clipboardContentHeight, clipboardTransitionProgress), wallpaperContentHeight, wallpaperTransitionProgress)
    readonly property real launcherHeight: searchHeight + contentGap + contentHeight
    readonly property real finalSearchX: (width - searchWidth) * 0.5
    readonly property real finalSearchRightX: finalSearchX + searchWidth
    readonly property real finalSearchY: Math.max(36, (height - launcherHeight) * 0.5)
    readonly property real finalSearchCenterX: finalSearchX + searchWidth * 0.5
    readonly property real finalSearchCenterY: finalSearchY + searchHeight * 0.5
    readonly property real finalContentY: finalSearchY + searchHeight + contentGap
    readonly property real orbDiameter: 28
    readonly property real orbTargetCenterX: finalSearchRightX - orbDiameter * 0.5
    readonly property real orbControlX: Math.max(launchOriginX, orbTargetCenterX) + Math.max(96, Math.abs(orbTargetCenterX - launchOriginX) * 0.28)
    readonly property real orbControlY: (launchOriginY + finalSearchCenterY) * 0.5
    readonly property real orbCenterX: quadBezier(launchOriginX, orbControlX, orbTargetCenterX, orbTravelProgress)
    readonly property real orbCenterY: quadBezier(launchOriginY, orbControlY, finalSearchCenterY, orbTravelProgress)
    readonly property real orbRightX: orbCenterX + orbDiameter * 0.5
    readonly property real orbMaskSize: orbDiameter + 44
    readonly property real orbMaskX: orbCenterX - orbMaskSize * 0.5
    readonly property real orbMaskY: orbCenterY - orbMaskSize * 0.5
    readonly property real orbMaskScale: 0.92 + inputMorphProgress * 0.18
    readonly property real orbHaloDiameter: orbDiameter + 18
    readonly property bool collapseSearchToOrb: closing && contentRevealProgress <= 0.001
    readonly property real morphHeightProgress: Math.min(1.0, inputMorphProgress * 2.4)
    readonly property real morphWidthProgress: inputMorphProgress
    readonly property real orbTravelOpacity: closing ? Math.pow(Math.max(0, orbTravelProgress), 8) : Math.max(0.22, Math.min(1.0, 0.22 + orbTravelProgress * 0.78))
    readonly property real orbOpacity: Math.max(0, 1.0 - inputMorphProgress * 0.92) * orbTravelOpacity
    readonly property real searchShellWidth: lerp(orbDiameter, searchWidth, morphWidthProgress)
    readonly property real searchShellHeight: lerp(orbDiameter, searchHeight, morphHeightProgress)
    readonly property real searchShellRight: collapseSearchToOrb ? orbRightX : lerp(orbRightX, finalSearchRightX, morphWidthProgress)
    readonly property real searchShellX: searchShellRight - searchShellWidth
    readonly property real searchShellY: collapseSearchToOrb ? orbCenterY - searchShellHeight * 0.5 : lerp(orbCenterY - orbDiameter * 0.5, finalSearchY, morphHeightProgress)
    readonly property real searchShellRadius: lerp(orbDiameter * 0.5, 22, morphWidthProgress)
    readonly property real searchShellOpacity: Math.max(0, Math.min(1, inputMorphProgress * 1.15))
    readonly property real inputOpacity: Math.max(0, Math.min(1, (inputMorphProgress - 0.18) / 0.82))
    readonly property real contentShellOpacity: Math.max(0, Math.min(1, contentRevealProgress * 1.1))
    readonly property real contentShellY: finalContentY - (1.0 - contentRevealProgress) * 34
    readonly property real contentShellHeight: contentHeight * contentRevealProgress
    readonly property real contentInnerY: (1.0 - contentRevealProgress) * -26
    readonly property real launcherModeTransitionProgress: Math.max(clipboardTransitionProgress, wallpaperTransitionProgress)
    readonly property real launcherModeTransitionBlur: Math.sin(Math.max(0, Math.min(1, launcherModeTransitionProgress)) * Math.PI) * 0.45

    function lerp(from, to, progress) {
        return from + (to - from) * progress
    }

    function quadBezier(from, control, to, progress) {
        const inv = 1.0 - progress
        return inv * inv * from + 2.0 * inv * progress * control + progress * progress * to
    }
}
