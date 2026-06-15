pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Components

Popup {
    id: datePicker
    width: 320
    height: 380
    padding: 12
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property date selectedDate: new Date()

    signal datePicked(date picked)

    background: Rectangle {
        color: Theme.bgPanel
        radius: Theme.radiusCard
        border.color: Theme.accent
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Button {
                id: prevMonthBtn
                implicitWidth: 36
                implicitHeight: 36
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                onClicked: {
                    var m = monthGrid.month - 1;
                    var y = monthGrid.year;
                    if (m < 0) { m = 11; y--; }
                    monthGrid.month = m;
                    monthGrid.year = y;
                }
                contentItem: Item {
                    anchors.fill: parent
                    UiIcon {
                        anchors.centerIn: parent
                        name: "chevron_left"
                        size: 24
                        iconColor: Theme.accent
                        opacity: prevMonthBtn.pressed ? 0.7 : 1.0
                    }
                }
                background: Rectangle {
                    anchors.fill: parent
                    color: prevMonthBtn.pressed || prevMonthBtn.hovered ? AppColors.hoverFill : "transparent"
                    border.color: Theme.borderDefault
                    border.width: 1
                    radius: Theme.radiusMedium
                }
            }

            Label {
                Layout.fillWidth: true
                text: monthGrid.title
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 15
                font.bold: true
                color: Theme.textPrimary
            }

            Button {
                id: nextMonthBtn
                implicitWidth: 36
                implicitHeight: 36
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                onClicked: {
                    var m = monthGrid.month + 1;
                    var y = monthGrid.year;
                    if (m > 11) { m = 0; y++; }
                    monthGrid.month = m;
                    monthGrid.year = y;
                }
                contentItem: Item {
                    anchors.fill: parent
                    UiIcon {
                        anchors.centerIn: parent
                        name: "chevron_right"
                        size: 24
                        iconColor: Theme.accent
                        opacity: nextMonthBtn.pressed ? 0.7 : 1.0
                    }
                }
                background: Rectangle {
                    anchors.fill: parent
                    color: nextMonthBtn.pressed || nextMonthBtn.hovered ? AppColors.hoverFill : "transparent"
                    border.color: Theme.borderDefault
                    border.width: 1
                    radius: Theme.radiusMedium
                }
            }
        }

        DayOfWeekRow {
            locale: monthGrid.locale
            Layout.fillWidth: true

            delegate: Text {
                required property string shortName
                text: shortName
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12
                font.bold: true
                color: Theme.textSecondary
            }
        }

        MonthGrid {
            id: monthGrid
            month: datePicker.selectedDate.getMonth()
            year: datePicker.selectedDate.getFullYear()
            locale: Qt.locale("en_US")
            Layout.fillWidth: true
            Layout.fillHeight: true

            delegate: Rectangle {
                id: dayCell
                required property var model

                width: Math.floor(monthGrid.width / 7)
                height: Math.floor((monthGrid.height) / 6)
                radius: 4

                readonly property bool isCurrentMonth: model.month === monthGrid.month
                readonly property bool isToday: {
                    var now = new Date();
                    return model.day === now.getDate()
                        && model.month === now.getMonth()
                        && model.year === now.getFullYear();
                }
                readonly property bool isSelected: {
                    var s = datePicker.selectedDate;
                    return model.day === s.getDate()
                        && model.month === s.getMonth()
                        && model.year === s.getFullYear();
                }

                color: dayCell.isSelected ? Theme.accent
                     : dayMouseArea.containsMouse && dayCell.isCurrentMonth ? Qt.rgba(1,1,1,0.08)
                     : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: dayCell.model.day
                    font.pixelSize: 14
                    font.bold: dayCell.isToday
                    color: !dayCell.isCurrentMonth ? Theme.textFaint
                         : dayCell.isSelected ? Theme.textOnColoredBtn
                         : dayCell.isToday ? Theme.accent
                         : Theme.textPrimary
                }

                MouseArea {
                    id: dayMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        datePicker.selectedDate = dayCell.model.date;
                        datePicker.datePicked(dayCell.model.date);
                        datePicker.close();
                    }
                }
            }
        }

        Button {
            id: todayBtn
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                var now = new Date();
                datePicker.selectedDate = now;
                datePicker.datePicked(now);
                datePicker.close();
            }
            contentItem: Text {
                text: "Today (" + Qt.formatDate(new Date(), "dd/MM") + ")"
                font.pixelSize: 13
                font.bold: true
                color: Theme.accent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: todayBtn.pressed ? 0.7 : 1.0
            }
            background: Item {}
        }
    }
}
