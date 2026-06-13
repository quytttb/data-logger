import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

// Reusable date picker popup using MonthGrid.
// Usage:
//   DatePickerPopup { id: picker; onDatePicked: (d) => field.text = formatDate(d) }
//   Button { onClicked: picker.open() }

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

        // ── Month / Year navigation ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Button {
                text: "◀"
                flat: true
                font.pixelSize: 16
                Layout.preferredWidth: 40
                Layout.preferredHeight: 36
                onClicked: {
                    var m = monthGrid.month - 1;
                    var y = monthGrid.year;
                    if (m < 0) { m = 11; y--; }
                    monthGrid.month = m;
                    monthGrid.year = y;
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
                text: "▶"
                flat: true
                font.pixelSize: 16
                Layout.preferredWidth: 40
                Layout.preferredHeight: 36
                onClicked: {
                    var m = monthGrid.month + 1;
                    var y = monthGrid.year;
                    if (m > 11) { m = 0; y++; }
                    monthGrid.month = m;
                    monthGrid.year = y;
                }
            }
        }

        // ── Day-of-week header ───────────────────────────────────────
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

        // ── Month grid ───────────────────────────────────────────────
        MonthGrid {
            id: monthGrid
            month: datePicker.selectedDate.getMonth()
            year: datePicker.selectedDate.getFullYear()
            locale: Qt.locale("en_US")
            Layout.fillWidth: true
            Layout.fillHeight: true

            delegate: Rectangle {
                required property var model
                // model.day, model.month, model.year, model.date

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

                color: isSelected ? Theme.accent
                     : mouseArea.containsMouse && isCurrentMonth ? Qt.rgba(1,1,1,0.08)
                     : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: model.day
                    font.pixelSize: 14
                    font.bold: isToday
                    color: !isCurrentMonth ? Theme.textFaint
                         : isSelected ? Theme.textOnColoredBtn
                         : isToday ? Theme.accent
                         : Theme.textPrimary
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        datePicker.selectedDate = model.date;
                        datePicker.datePicked(model.date);
                        datePicker.close();
                    }
                }
            }
        }

        // ── Today shortcut ───────────────────────────────────────────
        Button {
            text: "Today"
            flat: true
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                var now = new Date();
                datePicker.selectedDate = now;
                datePicker.datePicked(now);
                datePicker.close();
            }
        }
    }
}
