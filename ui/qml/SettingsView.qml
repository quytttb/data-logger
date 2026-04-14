import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: settingsRoot
    color: "transparent"

    // ── Message Popup ─────────────────────────────────────────────────────
    Popup {
        id: settingsPopup
        anchors.centerIn: parent
        width: 340; height: 160
        modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: Theme.bgSeparator; radius: 8; border.color: Theme.accent; border.width: 2 }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 15
            Text { id: popTitle; font.bold: true; font.pixelSize: 18; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
            Text { id: popMsg; wrapMode: Text.WordWrap; color: Theme.accentText; font.pixelSize: 14; Layout.fillWidth: true; Layout.fillHeight: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            Button { text: qsTr("Close"); Layout.alignment: Qt.AlignHCenter; onClicked: settingsPopup.close() }
        }
    }

    Connections {
        target: settingsController
        function onMessageSent(t, m) { popTitle.text = t; popMsg.text = m; settingsPopup.open() }
    }
    Connections {
        target: sensorModel
        function onMessageSent(t, m) { popTitle.text = t; popMsg.text = m; settingsPopup.open() }
    }

    Component.onCompleted: { sensorModel.refresh() }

    // Ngôn ngữ: main.py nối settingsController.uiLocaleChanged → install_locale + retranslate (kể cả khi chỉ đổi ComboBox).

    // ── Sensor Add/Edit Dialog ────────────────────────────────────────────
    Popup {
        id: sensorDialog
        anchors.centerIn: parent
        width: 480; height: 500
        modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property int editId: -1
        background: Rectangle { color: Theme.bgPanel; radius: Theme.radiusCard; border.color: Theme.accent; border.width: 2 }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 8
            Text {
                text: sensorDialog.editId < 0 ? qsTr("Add sensor") : qsTr("Edit sensor")
                color: Theme.accentText; font.pixelSize: 18; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: dialogGrid.implicitHeight; clip: true
                boundsBehavior: Flickable.StopAtBounds

                GridLayout {
                    id: dialogGrid; columns: 2; width: parent.width; columnSpacing: 10; rowSpacing: 8

                    Text { text: qsTr("Name:"); color: Theme.textSecondary }
                    TextField { id: dName; Layout.fillWidth: true; color: Theme.textPrimary; background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny } }

                    Text { text: qsTr("Unit:"); color: Theme.textSecondary }
                    TextField { id: dUnit; Layout.fillWidth: true; color: Theme.textPrimary; background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny } }

                    Text { text: qsTr("Slave ID:"); color: Theme.textSecondary }
                    SpinBox { id: dSlave; from: 1; to: 247; value: 1; Layout.fillWidth: true }

                    Text { text: qsTr("Address:"); color: Theme.textSecondary }
                    SpinBox { id: dAddr; from: 0; to: 65535; value: 0; Layout.fillWidth: true; editable: true }

                    Text { text: qsTr("Register type:"); color: Theme.textSecondary }
                    ComboBox { id: dRegType; model: ["holding", "input"]; Layout.fillWidth: true }

                    Text { text: qsTr("Data type:"); color: Theme.textSecondary }
                    ComboBox { id: dDataType; model: ["int16", "uint16", "float32"]; Layout.fillWidth: true }

                    Text { text: qsTr("Endian:"); color: Theme.textSecondary }
                    ComboBox { id: dDataFmt; model: ["AB", "BA", "ABCD", "CDAB"]; Layout.fillWidth: true }

                    Text { text: qsTr("Coefficients:"); color: Theme.textSecondary }
                    TextField { id: dCoeff; text: "{}"; Layout.fillWidth: true; color: Theme.textPrimary; background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny } }

                    Text { text: qsTr("Poll interval (s):"); color: Theme.textSecondary }
                    SpinBox { id: dPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true }

                    Text { text: qsTr("Report column:"); color: Theme.textSecondary }
                    SpinBox { id: dReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true }

                    Text { text: qsTr("Active:"); color: Theme.textSecondary }
                    Switch { id: dActive; checked: true }
                }
            }

            RowLayout { Layout.fillWidth: true; spacing: 10
                Button { text: qsTr("Cancel"); Layout.fillWidth: true; onClicked: sensorDialog.close() }
                Button {
                    text: sensorDialog.editId < 0 ? qsTr("Add") : qsTr("Save"); Layout.fillWidth: true
                    onClicked: {
                        if (sensorDialog.editId < 0) {
                            sensorModel.add_sensor(dName.text, dUnit.text, dSlave.value, dAddr.value,
                                dRegType.currentText, dDataType.currentText, dDataFmt.currentText,
                                dCoeff.text, dPollInterval.value, dReportIdx.value, dActive.checked)
                        } else {
                            sensorModel.update_sensor(sensorDialog.editId, dName.text, dUnit.text,
                                dSlave.value, dAddr.value, dRegType.currentText, dDataType.currentText,
                                dDataFmt.currentText, dCoeff.text, dPollInterval.value, dReportIdx.value,
                                dActive.checked)
                        }
                        sensorDialog.close()
                    }
                }
            }
        }
    }

    function openAddSensor() {
        sensorDialog.editId = -1
        dName.text = ""; dUnit.text = ""; dSlave.value = 1; dAddr.value = 0
        dRegType.currentIndex = 0; dDataType.currentIndex = 0; dDataFmt.currentIndex = 0
        dCoeff.text = "{}"; dPollInterval.value = 3; dReportIdx.value = 0; dActive.checked = true
        sensorDialog.open()
    }
    function openEditSensor(idx) {
        var s = sensorModel.get_sensor(idx)
        if (!s || !s.sensorId) return
        sensorDialog.editId = s.sensorId
        dName.text = s.name; dUnit.text = s.unit; dSlave.value = s.slaveId; dAddr.value = s.registerAddress
        dRegType.currentIndex = dRegType.model.indexOf(s.registerType)
        dDataType.currentIndex = dDataType.model.indexOf(s.dataType)
        dDataFmt.currentIndex = dDataFmt.model.indexOf(s.dataFormat)
        dCoeff.text = s.coefficient; dPollInterval.value = s.pollInterval || 3
        dReportIdx.value = s.reportIndex; dActive.checked = s.active
        sensorDialog.open()
    }

    // ── Confirm Delete Dialog ─────────────────────────────────────────────
    Popup {
        id: deleteConfirm
        anchors.centerIn: parent
        width: 340; height: 160
        modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property int targetId: -1
        property string targetName: ""
        background: Rectangle { color: Theme.bgSeparator; radius: 8; border.color: Theme.borderErr; border.width: 2 }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 15
            Text { text: qsTr("Confirm delete"); font.bold: true; font.pixelSize: 18; color: Theme.statusErr; Layout.alignment: Qt.AlignHCenter }
            Text { text: qsTr("Delete sensor \"%1\"?").arg(deleteConfirm.targetName); wrapMode: Text.WordWrap; color: Theme.textPrimary; font.pixelSize: 14; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            RowLayout { Layout.fillWidth: true; spacing: 10
                Button { text: qsTr("Cancel"); Layout.fillWidth: true; onClicked: deleteConfirm.close() }
                Button {
                    text: qsTr("Delete"); Layout.fillWidth: true
                    background: Rectangle { color: Theme.btnStop; radius: 6; opacity: parent.pressed ? 0.7 : 1.0 }
                    contentItem: Text { text: qsTr("Delete"); color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { sensorModel.remove_sensor(deleteConfirm.targetId); deleteConfirm.close() }
                }
            }
        }
    }

    // ── Main layout ──────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 0

        TabBar {
            id: settingsTabBar
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            currentIndex: 0

            TabButton {
                text: qsTr("Report & SFTP")
                font.pixelSize: 13; font.bold: true
                width: implicitWidth
            }
            TabButton {
                text: qsTr("Sensors")
                font.pixelSize: 13; font.bold: true
                width: implicitWidth
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: settingsTabBar.currentIndex

            // ── Tab 0: Báo cáo & FTP — 2 cột ─────────────────────────────
            Flickable {
                clip: true
                contentHeight: ftpCard.implicitHeight + 36
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: ftpCard
                    width: parent.width
                    spacing: 12

                    Item { Layout.preferredHeight: 12 }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: ftpInner.implicitHeight + 36
                        color: Theme.bgPanel; radius: Theme.radiusCard
                        border.color: Theme.borderDefault; border.width: 1

                        ColumnLayout {
                            id: ftpInner
                            anchors.fill: parent; anchors.margins: 15
                            spacing: 14

                            Text { text: qsTr("Report & SFTP"); color: Theme.accentText; font.pixelSize: 18; font.bold: true }

                            GridLayout {
                                columns: 4; Layout.fillWidth: true
                                columnSpacing: 12; rowSpacing: 10

                                Text { text: qsTr("UI language:"); color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                ComboBox {
                                    id: langCombo
                                    Layout.columnSpan: 3
                                    Layout.fillWidth: true
                                    model: [qsTr("Vietnamese"), qsTr("English")]
                                    currentIndex: settingsController.uiLocale === "en" ? 1 : 0
                                    onActivated: function (ix) {
                                        settingsController.uiLocale = (ix === 1) ? "en" : "vi"
                                    }
                                }

                                Text { text: qsTr("Station code:"); color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                TextField {
                                    Layout.fillWidth: true; color: Theme.textPrimary
                                    background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                                    text: settingsController.stationCode
                                    onTextChanged: settingsController.stationCode = text
                                }

                                Text { text: qsTr("Station name:"); color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                TextField {
                                    Layout.fillWidth: true; color: Theme.textPrimary
                                    background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                                    text: settingsController.stationName
                                    onTextChanged: settingsController.stationName = text
                                }

                                Text { text: qsTr("SFTP host:"); color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                TextField {
                                    Layout.fillWidth: true; color: Theme.textPrimary
                                    background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                                    text: settingsController.ftpAddress
                                    onTextChanged: settingsController.ftpAddress = text
                                }

                                Text { text: qsTr("Port:"); color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                SpinBox {
                                    from: 1; to: 65535; value: settingsController.ftpPort
                                    onValueChanged: settingsController.ftpPort = value
                                    Layout.fillWidth: true
                                }

                                Text { text: "Username:"; color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                TextField {
                                    Layout.fillWidth: true; color: Theme.textPrimary
                                    background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                                    text: settingsController.ftpUsername
                                    onTextChanged: settingsController.ftpUsername = text
                                }

                                Text { text: "Password:"; color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                TextField {
                                    Layout.fillWidth: true; color: Theme.textPrimary
                                    echoMode: TextInput.Password
                                    background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                                    text: settingsController.ftpPassword
                                    onTextChanged: settingsController.ftpPassword = text
                                }

                                Text { text: qsTr("Remote folder:"); color: Theme.textSecondary; Layout.alignment: Qt.AlignRight | Qt.AlignVCenter }
                                TextField {
                                    Layout.columnSpan: 3; Layout.fillWidth: true; color: Theme.textPrimary
                                    background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                                    text: settingsController.ftpRemotePath
                                    onTextChanged: settingsController.ftpRemotePath = text
                                }
                            }

                            Button {
                                text: qsTr("Save configuration")
                                Layout.fillWidth: true; Layout.preferredHeight: 48
                                font.pixelSize: 16; font.bold: true
                                onClicked: settingsController.save_config()
                            }
                        }
                    }
                }
            }

            // ── Tab 1: Danh sách cảm biến ─────────────────────────────────
            ColumnLayout {
                spacing: 10

                Item { Layout.preferredHeight: 12 }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Sensor list")
                        color: Theme.accentText; font.pixelSize: 18; font.bold: true
                        Layout.fillWidth: true
                    }
                    Button {
                        text: qsTr("+ Add"); font.bold: true
                        Layout.preferredHeight: 40
                        onClicked: settingsRoot.openAddSensor()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 36
                    color: Theme.bgSeparator; radius: Theme.radiusTiny
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 5
                        Text { text: qsTr("Name");    color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 110 }
                        Text { text: qsTr("Slave");  color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50 }
                        Text { text: qsTr("Addr");   color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50 }
                        Text { text: qsTr("Type");   color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 60 }
                        Text { text: qsTr("Interval"); color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 55 }
                        Item { Layout.fillWidth: true }
                    }
                }

                ListView {
                    id: sensorListView
                    Layout.fillWidth: true; Layout.fillHeight: true
                    model: sensorModel
                    clip: true; spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property int index
                        required property string name
                        required property int sensorId
                        required property int slaveId
                        required property int registerAddress
                        required property string dataType
                        required property int pollInterval
                        required property bool active

                        width: sensorListView.width
                        height: 52
                        color: index % 2 === 0 ? Theme.bgPanel : Theme.bgStripe
                        radius: Theme.radiusTiny

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 5
                            Text { text: name;            color: active ? Theme.textPrimary : "#666"; font.pixelSize: 14; Layout.preferredWidth: 110; elide: Text.ElideRight }
                            Text { text: slaveId;         color: Theme.textSecondary; font.pixelSize: 14; Layout.preferredWidth: 50 }
                            Text { text: registerAddress; color: Theme.textSecondary; font.pixelSize: 14; Layout.preferredWidth: 50 }
                            Text { text: dataType;        color: Theme.textSecondary; font.pixelSize: 14; Layout.preferredWidth: 60 }
                            Text { text: pollInterval + "s"; color: Theme.textSecondary; font.pixelSize: 14; Layout.preferredWidth: 55 }
                            Item { Layout.fillWidth: true }
                            Button {
                                Layout.preferredWidth: 50; Layout.preferredHeight: 40
                                icon.source: "../../assets/icons/edit.svg"
                                icon.color: Theme.accentText
                                icon.width: 22; icon.height: 22
                                background: Rectangle { color: Theme.bgSeparator; radius: Theme.radiusTiny; border.color: Theme.borderDefault; border.width: 1 }
                                onClicked: settingsRoot.openEditSensor(index)
                            }
                            Button {
                                Layout.preferredWidth: 50; Layout.preferredHeight: 40
                                icon.source: "../../assets/icons/delete.svg"
                                icon.color: Theme.statusErr
                                icon.width: 22; icon.height: 22
                                background: Rectangle { color: "#3a2020"; radius: Theme.radiusTiny; border.color: Theme.borderErr; border.width: 1 }
                                onClicked: {
                                    deleteConfirm.targetId = sensorId
                                    deleteConfirm.targetName = name
                                    deleteConfirm.open()
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: sensorListView.count === 0
                        text: qsTr("No sensors yet.\nPress [+ Add] or use the Modbus tester page\nto add sensors.")
                        color: Theme.textSecondary; font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
