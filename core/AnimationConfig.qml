pragma Singleton
import QtQuick

QtObject {
    id: root

    // ==========================================
    // Durations
    // ==========================================
    // Micro & Tiny interactions
    readonly property int durationMicro: 10
    readonly property int durationHoverProgress: 18
    readonly property int durationTiny: 20
    readonly property int durationStep: 30
    readonly property int durationSwift: 80

    // Fast animations
    readonly property int durationUltraFast: 100
    readonly property int durationVeryFast: 150
    readonly property int durationQuick: 180
    readonly property int durationFast: 200

    // Medium & Moderate animations
    readonly property int durationIslandFade: 220
    readonly property int durationDragSnap: 250
    readonly property int durationNormal: 300
    readonly property int durationModerate: 400
    readonly property int durationIslandSpring: 450
    readonly property int durationMedium: 500

    // Slow & Very Slow animations
    readonly property int durationSlow: 600
    readonly property int durationVerySlow: 800
    readonly property int durationExtraSlow: 900

    // ==========================================
    // Easing Types
    // ==========================================
    readonly property int easingDefaultOut: Easing.OutQuad
    readonly property int easingDefaultIn: Easing.InQuad
    readonly property int easingDefaultInOut: Easing.InOutQuad
    readonly property int easingMovement: Easing.OutQuint
    readonly property int easingMovementInOut: Easing.InOutQuint
    readonly property int easingSpring: Easing.OutElastic
    readonly property int easingSpringOut: Easing.OutElastic
    readonly property int easingOvershootOut: Easing.OutBack
    readonly property int easingSmoothOut: Easing.OutSine

    // ==========================================
    // Spring Parameters (Amplitude & Period)
    // ==========================================
    // Common Defaults
    readonly property real springPeriodDefault: 0.5
    readonly property real springAmplitudeDefault: 0.5

    // Control Center & Panels
    readonly property real springPeriodCC: 0.7
    readonly property real springAmplitudeCC: 0.8
    readonly property real springPeriodCCRadius: 0.6

    // Popout Effects
    readonly property real springPeriodPopout: 0.9
    readonly property real springAmplitudePopout: 0.5
    readonly property real springAmplitudePopoutY: 0.1
    readonly property real springPeriodPopoutY: 0.7
    readonly property real springPeriodPopoutScale: 0.4

    // Dynamic Island
    readonly property real springPeriodIsland: 0.6
    readonly property real springAmplitudeIsland: 0.9

    // Drag Interactions
    readonly property real dragOvershoot: 0.5

    // ==========================================
    // Radius Parameters
    // ==========================================
    readonly property int radiusPopout: 16
    readonly property int radiusCCNotifCompact: 22
    readonly property int radiusCCNotifExpanded: 24
    readonly property int radiusIslandCompact: 18
    readonly property int radiusIslandExpanded: 24

    // ==========================================
    // Blur Parameters
    // ==========================================
    readonly property real blurMaxHeavy: 50     // e.g. PopoutWrapper
    readonly property real blurMaxNormal: 32    // e.g. Base elements (Bar, CC main)
    readonly property real blurMaxLight: 16     // e.g. Notification details

    // ==========================================
    // Timers & Intervals
    // ==========================================
    readonly property int timerSnapBack: 1
    readonly property int timerHoverTick: 16
    readonly property int timerIslandExpand: 700
    readonly property int timerPopoutAutoClose: 5000
    readonly property int timerNotifAutoHide: 8000
    readonly property int timerIslandAutoHide: 9000
}
