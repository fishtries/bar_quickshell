import QtQuick

Item {
    id: layoutContainer
    z: 10
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 65
    anchors.leftMargin: 20
    anchors.rightMargin: 20

    property alias leftSection: leftSection
    property alias centerSection: centerSection
    property alias rightSection: rightSection

    property Item popoutParent: null

    // Common Y coordinate for all popout tops (bar height + gap)
    readonly property real popoutTopY: height - 5

    // ─── Левая группа: Часы и Задачи ───────────────────────────────────────────
    LeftSection {
        id: leftSection
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        popoutParent: layoutContainer.popoutParent
        popoutTopY: layoutContainer.popoutTopY
    }

    // ─── Центральная группа: ИДЕАЛЬНЫЙ ЦЕНТР ───────────────────────────
    CenterSection {
        id: centerSection
        anchors.centerIn: parent
        popoutParent: layoutContainer.popoutParent
        popoutTopY: layoutContainer.popoutTopY
    }

    // ─── Правая группа: У КРАЯ ─────────────────────────────────────────
    RightSection {
        id: rightSection
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        popoutTopY: layoutContainer.popoutTopY
    }
}
