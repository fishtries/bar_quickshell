import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"
import "../../core"

PopoutWrapper {
    id: root
    
    popoutWidth: root.editingReminder ? 720 : 600
    Behavior on popoutWidth { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    
    animateContentResize: true
    contentResizeDuration: AnimationConfig.durationQuick
    contentResizeEasingType: AnimationConfig.easingDefaultInOut
    autoClose: !root.editingReminder

    property string selectedReminderDateKey: EventsState.dateKey(TimeState.day, TimeState.month, TimeState.year)
    property bool editingReminder: false
    property var editingReminderData: null
    property string editingDateKey: selectedReminderDateKey
    property int editingHour: 9
    property int editingMinute: 0
    property bool editingHasTime: true
    property bool needsKeyboard: root.isOpen && root.editingReminder
    readonly property int editLabelWidth: 42

    function formatDateHeading(dateStr) {
        let parts = dateStr.split("-");
        if (parts.length !== 3)
            return dateStr;

        let dateObj = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return Qt.formatDate(dateObj, "dddd, d MMMM");
    }

    function reminderCountLabel(count) {
        return count === 1 ? `${count} reminder` : `${count} reminders`;
    }

    function dayCountLabel(count) {
        return count === 1 ? `${count} day` : `${count} days`;
    }

    function formatReminderTime(timeStr) {
        return timeStr && timeStr.length > 0 ? timeStr : "No time";
    }

    function pad(value) {
        let normalized = Number(value);
        return normalized < 10 ? "0" + normalized : "" + normalized;
    }

    function parseDateKey(dateKey) {
        let parts = dateKey.split("-");
        if (parts.length !== 3)
            return null;

        let dateObj = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return isNaN(dateObj.getTime()) ? null : dateObj;
    }

    function editingTimeValue() {
        return root.editingHasTime ? `${root.pad(root.editingHour)}:${root.pad(root.editingMinute)}` : "";
    }

    function syncCalendarToDateKey(dateKey, forceView) {
        let dateObj = root.parseDateKey(dateKey);
        if (!dateObj)
            return;

        calendar.selectedDay = dateObj.getDate();
        calendar.selectedMonth = dateObj.getMonth() + 1;
        calendar.selectedYear = dateObj.getFullYear();

        if (forceView) {
            calendar.viewMonth = calendar.selectedMonth;
            calendar.viewYear = calendar.selectedYear;
        }
    }

    function setEditingDateKey(dateKey, forceView) {
        if (!root.parseDateKey(dateKey))
            return;

        root.editingDateKey = dateKey;
        root.selectedReminderDateKey = dateKey;
        root.syncCalendarToDateKey(dateKey, forceView === true);
    }

    function setEditingTime(timeStr) {
        let timeParts = timeStr ? String(timeStr).split(":") : [];
        root.editingHasTime = timeParts.length === 2;

        if (root.editingHasTime) {
            let parsedHour = Number(timeParts[0]);
            let parsedMinute = Number(timeParts[1]);

            root.editingHour = isNaN(parsedHour) ? 9 : Math.max(0, Math.min(23, parsedHour));
            root.editingMinute = isNaN(parsedMinute) ? 0 : Math.max(0, Math.min(59, parsedMinute));
        } else {
            root.editingHour = 9;
            root.editingMinute = 0;
        }
    }

    function adjustEditingHour(delta) {
        root.editingHasTime = true;
        root.editingHour = (root.editingHour + delta + 24) % 24;
    }

    function adjustEditingMinute(delta) {
        root.editingHasTime = true;

        let total = root.editingHour * 60 + root.editingMinute + delta;
        while (total < 0)
            total += 24 * 60;
        while (total >= 24 * 60)
            total -= 24 * 60;

        root.editingHour = Math.floor(total / 60);
        root.editingMinute = total % 60;
    }

    function beginEditReminder(dateKey, taskIndex, task) {
        let reminder = EventsState.createReminderPayload(dateKey, taskIndex, task);

        root.editingReminderData = reminder;
        root.editingReminder = true;
        root.setEditingDateKey(dateKey, true);
        root.setEditingTime(reminder.time || "");

        editTitleInput.text = reminder.title || "";

        editFocusTimer.stop();
        editFocusTimer.start();
    }

    function closeEditReminder() {
        editFocusTimer.stop();
        root.editingReminder = false;
        root.editingReminderData = null;
        editTitleInput.text = "";
    }

    function submitEditReminder() {
        if (!root.editingReminderData || EventsState.reminderActionBusy)
            return;

        let listName = root.editingReminderData.list || "";
        let saved = EventsState.editReminder(root.editingReminderData, root.editingDateKey, root.editingTimeValue(), editTitleInput.text, listName);
        if (saved)
            root.closeEditReminder();
    }

    function deleteEditReminder() {
        if (!root.editingReminderData || EventsState.reminderActionBusy)
            return;

        EventsState.completeReminder(root.editingReminderData);
        root.closeEditReminder();
    }

    function scrollToReminderDate(dateKey) {
        let targetIndex = EventsState.indexOfDateKey(dateKey);
        if (targetIndex >= 0)
            remindersList.positionViewAtIndex(targetIndex, ListView.Beginning);
    }

    onIsOpenChanged: {
        if (!isOpen)
            root.closeEditReminder();
    }

    Timer {
        id: editFocusTimer
        interval: AnimationConfig.durationUltraFast
        repeat: false
        onTriggered: {
            if (root.needsKeyboard) {
                editTitleInput.forceActiveFocus();
                editTitleInput.cursorPosition = editTitleInput.text.length;
            }
        }
    }
     
    RowLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.bottomMargin: 20
        Layout.topMargin: 10
        spacing: 24
        
        // --- Левая колонка (Часы + Календарь) ---
        ColumnLayout {
            Layout.preferredWidth: 160
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 24
            
            // ─── Большая цифровая панель ──────────────────────────────────
            ColumnLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 0
                
                AppText {
                    text: TimeState.currentTimeWithSeconds
                    Layout.alignment: Qt.AlignLeft
                    font {
                        pixelSize: 48
                        family: Theme.fontClock
                        weight: Font.Black
                    }
                    color: Theme.textPrimary
                }
                
                AppText {
                    text: Qt.formatDate(new Date(TimeState.year, TimeState.month - 1, TimeState.day), "dddd, d MMMM")
                    Layout.alignment: Qt.AlignLeft
                    font { pixelSize: 14; weight: Font.Medium }
                    color: Theme.info
                    opacity: 0.9
                }
            }
            
            // Разделитель
            Rectangle {
                Layout.preferredWidth: 260
                height: 1
                color: Theme.textPrimary
                opacity: 0.1
            }
            
            // ─── Модуль календаря ────────────────────────────────────────
            CalendarModule {
                id: calendar
                Layout.alignment: Qt.AlignLeft
                Layout.preferredWidth: 260
                onDaySelected: function(dateKey, hasEvents) {
                    root.selectedReminderDateKey = dateKey;

                    if (root.editingReminder) {
                        root.setEditingDateKey(dateKey, false);
                        return;
                    }

                    if (hasEvents)
                        root.scrollToReminderDate(dateKey);
                }
            }
        }

        // --- Правая колонка (Список всех событий) ---
        Rectangle {
            id: remindersContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Item {
                anchors.fill: parent

                Rectangle {
                    id: editPanel
                    anchors.fill: parent
                    color: "transparent"
                    opacity: root.editingReminder ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                    layer.enabled: opacity > 0 && opacity < 1
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: AnimationConfig.blurMaxHeavy
                        blur: 1.0 - editPanel.opacity
                    }

                    ColumnLayout {
                        id: editPanelLayout
                        anchors.fill: parent
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            AppText {
                                text: "Edit reminder"
                                Layout.fillWidth: true
                                font { pixelSize: 15; weight: Font.DemiBold }
                                color: Theme.info
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: deleteEditText.implicitWidth + 18
                                implicitHeight: 26
                                radius: 13
                                color: deleteEditMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : "transparent"
                                opacity: EventsState.reminderActionBusy ? 0.45 : 1.0

                                AppText {
                                    id: deleteEditText
                                    anchors.centerIn: parent
                                    text: "Delete"
                                    color: deleteEditMouse.containsMouse ? Theme.error : Theme.textSecondary
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: deleteEditMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !EventsState.reminderActionBusy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteEditReminder()
                                }
                            }

                            Rectangle {
                                implicitWidth: cancelEditText.implicitWidth + 18
                                implicitHeight: 26
                                radius: 13
                                color: cancelEditMouse.containsMouse ? Theme.bgHover : "transparent"

                                AppText {
                                    id: cancelEditText
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: cancelEditMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: cancelEditMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeEditReminder()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: 8
                            color: editTitleInput.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: editTitleInput.activeFocus ? Theme.info : "transparent"

                            TextInput {
                                id: editTitleInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.textPrimary
                                font.pixelSize: 14
                                clip: true
                                selectByMouse: true
                                activeFocusOnTab: true

                                Keys.onEscapePressed: root.closeEditReminder()
                                Keys.onReturnPressed: root.submitEditReminder()
                                Keys.onEnterPressed: root.submitEditReminder()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Title"
                                    color: Theme.textSecondary
                                    font: editTitleInput.font
                                    enabled: false
                                    visible: !editTitleInput.text && !editTitleInput.preeditText
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.03)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                AppText {
                                    Layout.preferredWidth: root.editLabelWidth
                                    text: "Date"
                                    color: Theme.textSecondary
                                    font.pixelSize: 12
                                }

                                AppText {
                                    Layout.fillWidth: true
                                    text: root.formatDateHeading(root.editingDateKey)
                                    color: Theme.textPrimary
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                AppText {
                                    text: "pick in calendar"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                    opacity: 0.75
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            AppText {
                                Layout.preferredWidth: root.editLabelWidth
                                text: "Time"
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }

                            Rectangle {
                                implicitWidth: editTimeToggleText.implicitWidth + 24
                                implicitHeight: 26
                                radius: 13
                                color: editTimeToggleMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                                AppText {
                                    id: editTimeToggleText
                                    anchors.centerIn: parent
                                    text: root.editingHasTime ? "Remove time" : "Add time"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: editTimeToggleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editingHasTime = !root.editingHasTime
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            opacity: root.editingHasTime ? 1.0 : 0.35
                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 76
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.04)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    AppText {
                                        text: "Hour"
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 6

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: editHourDownMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)
                                            AppText {
                                                anchors.centerIn: parent
                                                text: "−"
                                                color: Theme.textPrimary
                                                font { pixelSize: 16; weight: Font.Bold }
                                            }
                                            MouseArea {
                                                id: editHourDownMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.editingHasTime
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.adjustEditingHour(-1)
                                            }
                                        }

                                        AppText {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: root.pad(root.editingHour)
                                            color: Theme.textPrimary
                                            font { pixelSize: 26; weight: Font.Bold }
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: editHourUpMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)
                                            AppText {
                                                anchors.centerIn: parent
                                                text: "+"
                                                color: Theme.textPrimary
                                                font { pixelSize: 16; weight: Font.Bold }
                                            }
                                            MouseArea {
                                                id: editHourUpMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.editingHasTime
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.adjustEditingHour(1)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 76
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.04)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    AppText {
                                        text: "Minute"
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 6

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: editMinuteDownMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)
                                            AppText {
                                                anchors.centerIn: parent
                                                text: "−"
                                                color: Theme.textPrimary
                                                font { pixelSize: 16; weight: Font.Bold }
                                            }
                                            MouseArea {
                                                id: editMinuteDownMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.editingHasTime
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.adjustEditingMinute(-5)
                                            }
                                        }

                                        AppText {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: root.pad(root.editingMinute)
                                            color: Theme.textPrimary
                                            font { pixelSize: 26; weight: Font.Bold }
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: editMinuteUpMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)
                                            AppText {
                                                anchors.centerIn: parent
                                                text: "+"
                                                color: Theme.textPrimary
                                                font { pixelSize: 16; weight: Font.Bold }
                                            }
                                            MouseArea {
                                                id: editMinuteUpMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: root.editingHasTime
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.adjustEditingMinute(5)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: saveEditButton
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: 10
                            color: saveEditMouse.containsMouse && canSave ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: saveEditMouse.containsMouse && canSave ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.45) : "transparent"
                            opacity: canSave ? 1 : 0.45
                            property bool canSave: editTitleInput.text.trim().length > 0 && !EventsState.reminderActionBusy

                            AppText {
                                anchors.centerIn: parent
                                text: EventsState.reminderActionBusy ? "Saving…" : "Save changes"
                                color: Theme.textPrimary
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: saveEditMouse
                                anchors.fill: parent
                                enabled: saveEditButton.canSave
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitEditReminder()
                            }
                        }
                    }
                }

                ListView {
                    id: remindersList
                    anchors.fill: parent
                    opacity: !root.editingReminder && EventsState.sortedEventsList.length > 0 ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                    layer.enabled: opacity > 0 && opacity < 1
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: AnimationConfig.blurMaxHeavy
                        blur: 1.0 - remindersList.opacity
                    }
                    clip: true
                    spacing: 12
                    boundsBehavior: Flickable.StopAtBounds
                    model: EventsState.sortedEventsList

                    delegate: Item {
                        id: dayDelegate
                        width: remindersList.width
                        height: sectionColumn.implicitHeight + 12

                        readonly property string sectionDateKey: modelData.dateStr
                        readonly property var sectionTasks: modelData.tasks
                        readonly property bool isSelected: sectionDateKey === root.selectedReminderDateKey

                        Column {
                            id: sectionColumn
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width
                                height: headerColumn.implicitHeight + 14
                                radius: 12
                                color: isSelected ? Theme.bgHover : Theme.bgActive
                                border.width: isSelected ? 1 : 0
                                border.color: Theme.info

                                Column {
                                    id: headerColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 2

                                    AppText {
                                        width: parent.width
                                        text: root.formatDateHeading(dayDelegate.sectionDateKey)
                                        font { pixelSize: 14; weight: Font.DemiBold }
                                        color: isSelected ? Theme.info : Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    AppText {
                                        width: parent.width
                                        text: root.reminderCountLabel(dayDelegate.sectionTasks.length)
                                        color: Theme.textSecondary
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                }
                            }

                            Repeater {
                                model: dayDelegate.sectionTasks

                                delegate: Rectangle {
                                    width: sectionColumn.width
                                    height: taskColumn.implicitHeight + 14
                                    radius: 10
                                    color: eventCardMouse.containsMouse ? Theme.bgHover : Theme.bgPanel

                                    Column {
                                        id: taskColumn
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        AppText {
                                            width: parent.width
                                            text: modelData.title
                                            color: Theme.textPrimary
                                            wrapMode: Text.Wrap
                                        }

                                        AppText {
                                            width: parent.width
                                            text: root.formatReminderTime(modelData.time) + (modelData.list ? ` · ${modelData.list}` : "")
                                            color: Theme.textSecondary
                                            font.pixelSize: 11
                                            wrapMode: Text.Wrap
                                            opacity: 0.85
                                        }
                                    }

                                    MouseArea {
                                        id: eventCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.beginEditReminder(dayDelegate.sectionDateKey, index, modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                AppText {
                    anchors.fill: parent
                    opacity: !root.editingReminder && EventsState.sortedEventsList.length === 0 ? 0.5 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                    text: "No reminders yet"
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
