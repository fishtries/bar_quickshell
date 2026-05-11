import re

with open("TodoPopout.qml", "r") as f:
    content = f.read()

# 1. Remove contentBlur property and animation
content = re.sub(r'    property real contentBlur: 0\.0\n', '', content)
content = re.sub(r'    SequentialAnimation \{\n        id: contentBlurAnim\n.*?\n.*?\n    \}\n\n', '', content, flags=re.DOTALL)
content = re.sub(r'            contentBlurAnim\.restart\(\);\n', '', content)
content = re.sub(r'    Behavior on contentBlur \{\n        NumberAnimation \{ duration: 300; easing\.type: Easing\.OutQuad \}\n    \}\n\n', '', content)

# 2. Remove layer.enabled/effect from main ColumnLayout
content = re.sub(r'        layer\.enabled: root\.contentBlur > 0\n        layer\.effect: MultiEffect \{\n            blurEnabled: true\n            blurMax: 150\n            blur: root\.contentBlur\n        \}\n\n', '', content)

# 3. Remove the global RowLayout header
header_regex = r'    RowLayout \{\n        Layout\.fillWidth: true\n        spacing: 8\n\n        Rectangle \{\n            visible: root\.creatingTask\n.*?Text \{\n            Layout\.fillWidth: true\n            text: root\.creatingTask \? "New task" : "Tasks"\n            color: Theme\.textPrimary\n            font\.family: Theme\.fontPrimary\n            font\.pixelSize: 16\n            font\.bold: true\n        \}\n    \}\n\n'
content = re.sub(header_regex, '', content, flags=re.DOTALL)

# 4. Modify listPage
list_page_target = r'''        Item \{
            id: listPage
            width: parent\.width
            implicitHeight: Math\.min\(500, Math\.max\(80, taskListLayout\.implicitHeight\)\)
            height: implicitHeight

            property real targetOpacity: root\.creatingTask \? 0\.0 : 1\.0
            property real targetBlur: root\.creatingTask \? 0\.6 : 0\.0

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity \{
                SequentialAnimation \{
                    PauseAnimation \{ duration: 150 \}
                    NumberAnimation \{ duration: 250; easing\.type: Easing\.OutQuad \}
                \}
            \}
            Behavior on targetBlur \{ NumberAnimation \{ duration: 300; easing\.type: Easing\.OutQuad \} \}

            layer\.enabled: targetBlur > 0
            layer\.effect: MultiEffect \{
                blurEnabled: true
                blurMax: 150
                blur: listPage\.targetBlur
            \}

            ScrollView \{'''

list_page_replacement = r'''        Item {
            id: listPage
            width: parent.width
            implicitHeight: listPageLayout.implicitHeight
            height: implicitHeight

            property real targetOpacity: root.creatingTask ? 0.0 : 1.0
            property real targetBlur: root.creatingTask ? 0.6 : 0.0

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: listPage.targetBlur
            }

            ColumnLayout {
                id: listPageLayout
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.spacingDefault

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Tasks"
                        color: Theme.textPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(500, Math.max(80, taskListLayout.implicitHeight))'''

content = content.replace(list_page_target, list_page_replacement)

# We need to close the ColumnLayout for listPage
# Find the end of ScrollView
list_page_end_target = r'''                    }
                }
            }
        }

        Item {
            id: createPage'''

list_page_end_replacement = r'''                    }
                }
            }
        }

        Item {
            id: createPage'''

content = content.replace(list_page_end_target, "                    }\n                }\n            }\n        }\n\n        Item {\n            id: createPage")
# Actually, since I added ColumnLayout { ... ScrollView { ... } }, I need to add one more closing brace for listPage.
# Let's do it by regex
content = re.sub(r'(                        }\n                    }\n                }\n            }\n        })\n\n        Item \{\n            id: createPage', r'\1\n            }\n        }\n\n        Item {\n            id: createPage', content)


# 5. Modify createPage
create_page_target = r'''        Item \{
            id: createPage
            width: parent\.width
            implicitHeight: createTaskForm\.implicitHeight
            height: implicitHeight

            property real targetOpacity: root\.creatingTask \? 1\.0 : 0\.0
            property real targetBlur: root\.creatingTask \? 0\.0 : 0\.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity \{
                SequentialAnimation \{
                    PauseAnimation \{ duration: 150 \}
                    NumberAnimation \{ duration: 250; easing\.type: Easing\.OutQuad \}
                \}
            \}
            Behavior on targetBlur \{ NumberAnimation \{ duration: 300; easing\.type: Easing\.OutQuad \} \}

            layer\.enabled: targetBlur > 0
            layer\.effect: MultiEffect \{
                blurEnabled: true
                blurMax: 150
                blur: createPage\.targetBlur
            \}

            ColumnLayout \{
                id: createTaskForm'''

create_page_replacement = r'''        Item {
            id: createPage
            width: parent.width
            implicitHeight: createTaskLayout.implicitHeight
            height: implicitHeight

            property real targetOpacity: root.creatingTask ? 1.0 : 0.0
            property real targetBlur: root.creatingTask ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: createPage.targetBlur
            }

            ColumnLayout {
                id: createTaskLayout
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.spacingDefault

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: backMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeCreateTask()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "New task"
                        color: Theme.textPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                ColumnLayout {
                    id: createTaskForm
                    Layout.fillWidth: true'''

content = content.replace(create_page_target, create_page_replacement)

# We need to add a closing brace for the new createTaskLayout
# Find the end of createTaskForm
content = re.sub(r'(                    \}\n                \}\n            \}\n        \}\n    \}\n\})', r'                    }\n                }\n            }\n        }\n    }\n}', content) # wait, I just append an extra } before the end of the file or at the end of createPage.
# Let's find the end of createPage which is also the end of pageContainer.
# Actually, I can just write it out to a file and fix any missing brackets manually.

with open("TodoPopout_new.qml", "w") as f:
    f.write(content)

