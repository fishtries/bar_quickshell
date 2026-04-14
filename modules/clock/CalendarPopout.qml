import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt.labs.calendar 1.0
import "../../components"
import "../../core"
import "../../core/state"

PopoutWrapper {
    id: root

    popoutWidth: 650
    property string selectedDate: ""
    property var tasksModel: []

    // Обновление модели при изменении данных или выбранной даты
    onSelectedDateChanged: updateModel()
    
    Connections {
        target: EventsState
        function onRemindersDataChanged() { updateModel() }
    }

    function updateModel() {
        let result = [];
        if (selectedDate === "") {
            // Все задачи, отсортированные по времени
            let dates = Object.keys(EventsState.remindersData).sort();
            for (let d of dates) {
                let tasks = EventsState.remindersData[d];
                for (let t of tasks) {
                    let item = Object.assign({}, t); // Копируем объект
                    item.fullDate = d;
                    result.push(item);
                }
            }
            // Сортировка: дата + время (если времени нет, ставим в конец дня)
            result.sort((a, b) => {
                let dtA = a.fullDate + " " + (a.time || "23:59");
                let dtB = b.fullDate + " " + (b.time || "23:59");
                return dtA.localeCompare(dtB);
            });
        } else {
            // Только задачи на выбранную дату
            let tasks = EventsState.remindersData[selectedDate] || [];
            result = tasks.slice().sort((a, b) => {
                let tA = a.time || "23:59";
                let tB = b.time || "23:59";
                return tA.localeCompare(tB);
            });
        }
        root.tasksModel = result;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // ─── ЛЕВАЯ ЧАСТЬ: КАЛЕНДАРЬ ─────────────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: 16

            AppText {
                text: Qt.formatDate(new Date(), "MMMM yyyy")
                font { pixelSize: 18; weight: Font.Bold }
                Layout.alignment: Qt.AlignHCenter
                color: Theme.textPrimary
            }

            MonthGrid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                locale: Qt.locale("ru_RU")
                month: new Date().getMonth()
                year: new Date().getFullYear()

                delegate: Item {
                    implicitWidth: 40
                    implicitHeight: 40

                    readonly property date date: new Date(model.year, model.month, model.day)
                    readonly property string dateStr: Qt.formatDate(date, "yyyy-MM-dd")
                    readonly property bool isSelected: root.selectedDate === dateStr
                    readonly property bool hasEvents: EventsState.remindersData[dateStr] !== undefined

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: isSelected ? Theme.info : (hoverHandler.hovered ? Theme.bgHover : "transparent")
                        opacity: model.month === grid.month ? 1.0 : 0.3
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        AppText {
                            text: model.day
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.bold: model.today
                            color: isSelected ? Theme.textDark : Theme.textPrimary
                            opacity: model.month === grid.month ? 1.0 : 0.5
                        }

                        // Цветной индикатор под числом
                        Rectangle {
                            width: 4; height: 4
                            radius: 2
                            color: isSelected ? Theme.textDark : Theme.info
                            visible: hasEvents
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    HoverHandler { id: hoverHandler }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.selectedDate === dateStr) {
                                root.selectedDate = "";
                            } else {
                                root.selectedDate = dateStr;
                            }
                        }
                    }
                }
            }
        }

        // Разделитель
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Theme.textPrimary
            opacity: 0.1
        }

        // ─── ПРАВАЯ ЧАСТЬ: СПИСОК ЗАДАЧ ─────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AppText {
                text: root.selectedDate === "" ? "Все предстоящие" : "Задачи на " + Qt.formatDate(new Date(root.selectedDate), "d MMMM")
                font { pixelSize: 14; weight: Font.Bold }
                color: Theme.textSecondary
            }

            ListView {
                id: taskList
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: root.tasksModel

                delegate: Rectangle {
                    width: taskList.width
                    height: 50
                    radius: 12
                    color: Theme.bgHover
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // Категория / Иконка
                        Rectangle {
                            width: 4; height: 16
                            radius: 2
                            color: Theme.info
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            AppText {
                                text: modelData.title
                                font { pixelSize: 14; weight: Font.Medium }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            AppText {
                                text: (root.selectedDate === "" ? modelData.fullDate + " • " : "") + modelData.list
                                font.pixelSize: 11
                                color: Theme.textSecondary
                                opacity: 0.8
                            }
                        }

                        AppText {
                            text: modelData.time || "--:--"
                            font { pixelSize: 13; weight: Font.Bold }
                            color: Theme.info
                        }
                    }
                }

                // Empty State
                AppText {
                    anchors.centerIn: parent
                    text: "Нет задач"
                    visible: taskList.count === 0
                    color: Theme.textSecondary
                    opacity: 0.5
                }
            }
        }
    }

    Component.onCompleted: updateModel()
}
