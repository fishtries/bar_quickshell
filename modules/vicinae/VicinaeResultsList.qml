import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var model: null
    property int currentIndex: -1
    property int contentTopMargin: 4
    property int contentBottomMargin: 4
    property alias listView: listView

    signal itemPressed(int index)
    signal itemHovered(int index)
    signal itemActivated(int index)

    function ensureCurrentVisible() {
        if (currentIndex >= 0)
            listView.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        model: root.model
        currentIndex: root.currentIndex
        spacing: 2
        topMargin: root.contentTopMargin
        bottomMargin: root.contentBottomMargin
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        delegate: Loader {
            id: delegateLoader
            width: ListView.view.width

            required property int index
            required property bool isSection
            required property bool selectable
            required property string kind
            required property string sectionName
            required property string title
            required property string subtitle
            required property string iconText
            required property string accessoryText
            required property var accessoryColor
            required property string aliasText
            required property bool isActive
            required property string calcQuestion
            required property string calcQuestionUnit
            required property string calcAnswer
            required property string calcAnswerUnit

            sourceComponent: isSection ? sectionDelegate : kind === "calculator" ? calculatorDelegate : resultDelegate

            Component {
                id: sectionDelegate

                VicinaeSectionHeader {
                    width: delegateLoader.width
                    text: delegateLoader.sectionName
                }
            }

            Component {
                id: resultDelegate

                VicinaeResultItem {
                    width: delegateLoader.width
                    title: delegateLoader.title
                    subtitle: delegateLoader.subtitle
                    iconText: delegateLoader.iconText
                    accessoryText: delegateLoader.accessoryText
                    accessoryColor: delegateLoader.accessoryColor
                    aliasText: delegateLoader.aliasText
                    active: delegateLoader.isActive
                    selected: root.currentIndex === delegateLoader.index
                    onPressed: root.itemPressed(delegateLoader.index)
                    onHovered: root.itemHovered(delegateLoader.index)
                    onActivated: root.itemActivated(delegateLoader.index)
                }
            }

            Component {
                id: calculatorDelegate

                VicinaeCalculatorItem {
                    width: delegateLoader.width
                    question: delegateLoader.calcQuestion
                    questionUnit: delegateLoader.calcQuestionUnit
                    answer: delegateLoader.calcAnswer
                    answerUnit: delegateLoader.calcAnswerUnit
                    selected: root.currentIndex === delegateLoader.index
                    onPressed: root.itemPressed(delegateLoader.index)
                    onHovered: root.itemHovered(delegateLoader.index)
                    onActivated: root.itemActivated(delegateLoader.index)
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: listView.contentHeight > listView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }
    }
}
