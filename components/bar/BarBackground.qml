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

    // ─── Левая группа: Часы и Задачи ───────────────────────────────────────────
    LeftSection {
        id: leftSection
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        popoutParent: layoutContainer.popoutParent
    }

    // ─── Центральная группа: ИДЕАЛЬНЫЙ ЦЕНТР ───────────────────────────
    CenterSection {
        id: centerSection
        anchors.centerIn: parent
        popoutParent: layoutContainer.popoutParent
    }

    // ─── Правая группа: У КРАЯ ─────────────────────────────────────────
    RightSection {
        id: rightSection
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }
}
