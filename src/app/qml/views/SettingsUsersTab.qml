pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

// Users và Audit dùng cùng một tab chính; quyền vẫn được backend kiểm tra.
Item {
    id: root

    property var userRows: []
    property int currentRow: -1
    readonly property var selectedUser: currentRow >= 0 && currentRow < userRows.length
                                        ? userRows[currentRow] : null
    readonly property bool selfSelected: selectedUser !== null
                                         && selectedUser.username === AuthService.currentUsername
    readonly property bool formActive: editor.mode !== ""
    readonly property bool listActive: !formActive && accountsTabBar.currentIndex === 0
                                       && AuthService.canManageUsers

    function capitalize(value) {
        const s = String(value)
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s
    }

    function formatTime(iso) {
        if (!iso)
            return "—"
        const d = new Date(iso)
        return isNaN(d.getTime()) ? iso : d.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    function rebuildRows() {
        const keepId = selectedUser !== null ? selectedUser.id : -1
        const list = AuthService.users()
        const rows = []
        const tableRows = []
        for (let i = 0; i < list.length; ++i) {
            const u = list[i]
            rows.push(u)
            tableRows.push([u.username, u.displayName, capitalize(u.role),
                            u.active ? qsTr("Active") : qsTr("Disabled"),
                            formatTime(u.lastLoginAt)])
        }
        userRows = rows
        // qmllint disable unqualified
        userTableModel.setHeaders([qsTr("User"), qsTr("Display name"), qsTr("Role"),
                                   qsTr("Status"), qsTr("Last sign-in")])
        userTableModel.setRows(tableRows)
        // qmllint enable unqualified
        currentRow = -1
        for (let i = 0; i < rows.length; ++i) {
            if (rows[i].id === keepId) {
                currentRow = i
                break
            }
        }
    }

    function ensureAllowedTab() {
        if (!AuthService.canManageUsers && AuthService.canViewAudit)
            accountsTabBar.currentIndex = 1
        else if (!AuthService.canViewAudit && AuthService.canManageUsers)
            accountsTabBar.currentIndex = 0
    }

    function openAdd() {
        if (listActive && !AuthService.busy)
            editor.openAdd()
    }

    function openEdit() {
        if (listActive && selectedUser !== null && !AuthService.busy)
            editor.openEdit(selectedUser)
    }

    function deleteSelected() {
        if (!listActive || selectedUser === null || selfSelected || AuthService.busy)
            return
        const id = selectedUser.id
        const name = selectedUser.username
        confirmPopup.showConfirm(
            qsTr("Delete user"),
            qsTr("Delete account \"%1\"? Existing audit and calibration history will be kept.").arg(name),
            function() { AuthService.deleteUser(id) },
            qsTr("Delete"), AppColors.error)
    }

    function saveForm() { editor.submit() }
    function closeForm() { editor.cancel() }

    onVisibleChanged: {
        if (visible) {
            ensureAllowedTab()
            AuthService.refreshUsers()
        } else {
            editor.close()
            confirmPopup.close()
            currentRow = -1
        }
    }

    Component.onCompleted: rebuildRows()

    Connections {
        target: AuthService
        function onUsersChanged() { root.rebuildRows() }
        function onSessionChanged() {
            if (!AuthService.canManageUsers) {
                editor.close()
                confirmPopup.close()
            }
            root.ensureAllowedTab()
            root.rebuildRows()
        }
    }

    JsonTableModel { id: userTableModel }
    MessagePopup { id: confirmPopup }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: accountsTabBar
            visible: !root.formActive
            Layout.alignment: Qt.AlignLeft
            Layout.bottomMargin: AppTheme.spacingS
            background: Rectangle { color: "transparent" }
            onCurrentIndexChanged: root.currentRow = -1

            ThemedTabButton {
                text: qsTr("Users")
                width: implicitWidth + 30
                visible: AuthService.canManageUsers
            }
            ThemedTabButton {
                text: qsTr("Audit log")
                width: implicitWidth + 30
                visible: AuthService.canViewAudit
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.formActive ? 2 : accountsTabBar.currentIndex

            Rectangle {
                color: AppColors.surfaceContainerLow
                radius: AppTheme.cardRadius
                border.color: AppColors.elevatedBorder
                border.width: 1

                AppTableView {
                    anchors.fill: parent
                    // qmllint disable unqualified
                    model: userTableModel
                    // qmllint enable unqualified
                    hasData: root.userRows.length > 0
                    colWeights: [0.24, 0.28, 0.14, 0.14, 0.20]
                    colMinimums: [120, 140, 80, 80, 120]
                    headerAlignCenter: function(col) { return col === 2 || col === 3 }
                    emptyMessage: qsTr("No user accounts yet.\nClick [+ Add] to create one.")
                    emptyIconName: "server"

                    delegate: Rectangle {
                        id: cell
                        required property int row
                        required property int column
                        required property var display
                        implicitHeight: 44
                        color: "transparent"

                        TableCellBackground { cellHovered: false }
                        Rectangle {
                            anchors.fill: parent
                            color: root.currentRow === cell.row
                                   ? AppColors.withAlpha(AppColors.primaryColor, 0.16)
                                   : "transparent"
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 3
                                visible: root.currentRow === cell.row && cell.column === 0
                                color: AppColors.primaryColor
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.currentRow = root.currentRow === cell.row ? -1 : cell.row
                        }
                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: cell.column === 0 ? AppTheme.spacingM : AppTheme.spacingS
                                right: parent.right
                                rightMargin: AppTheme.spacingS
                                verticalCenter: parent.verticalCenter
                            }
                            text: String(cell.display)
                            color: cell.column === 3 && cell.row < root.userRows.length
                                   && !root.userRows[cell.row].active ? AppColors.error
                                   : cell.column === 0 ? AppColors.primaryText : AppColors.tableCellMuted
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
                            font.weight: cell.column === 0 ? Font.DemiBold : Font.Normal
                            horizontalAlignment: cell.column === 2 || cell.column === 3
                                                 ? Text.AlignHCenter : Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            SettingsAuditTab { }

            // Form nội tuyến giống Sensors: toolbar Save/Cancel nằm ở header,
            // không dùng Popup để bàn phím ảo không bị che bởi Overlay.
            Flickable {
                id: editor
                contentWidth: width
                contentHeight: Math.max(height, editorPane.implicitHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                property string mode: "" // add | edit | reset | self
                property int targetId: -1
                property string targetUsername: ""
                property bool targetSelf: false
                property bool originalActive: true
                property string errorText: ""

                function clearPasswords() {
                    oldPasswordField.text = ""
                    newPasswordField.text = ""
                    confirmPasswordField.text = ""
                }

                function openAdd() {
                    targetId = -1
                    targetUsername = ""
                    targetSelf = false
                    originalActive = true
                    errorText = ""
                    usernameField.text = ""
                    displayField.text = ""
                    roleCombo.currentIndex = 1
                    activeSwitch.checked = true
                    clearPasswords()
                    mode = "add"
                    usernameField.forceActiveFocus()
                }

                function openEdit(user) {
                    targetId = user.id
                    targetUsername = user.username
                    targetSelf = user.username === AuthService.currentUsername
                    originalActive = user.active
                    errorText = ""
                    usernameField.text = user.username
                    displayField.text = user.displayName
                    roleCombo.currentIndex = Math.max(0, ["viewer", "operator", "admin"].indexOf(user.role))
                    activeSwitch.checked = user.active
                    clearPasswords()
                    mode = "edit"
                }

                function openPassword() {
                    errorText = ""
                    clearPasswords()
                    mode = targetSelf ? "self" : "reset"
                    if (targetSelf)
                        oldPasswordField.forceActiveFocus()
                    else
                        newPasswordField.forceActiveFocus()
                }

                function close() {
                    mode = ""
                    targetId = -1
                    targetUsername = ""
                    errorText = ""
                    clearPasswords()
                }

                function cancel() {
                    if (mode === "self" || mode === "reset") {
                        clearPasswords()
                        errorText = ""
                        mode = "edit"
                    } else {
                        close()
                    }
                }

                function commitEdit() {
                    if (AuthService.updateUser(targetId, displayField.text,
                                               roleCombo.model[roleCombo.currentIndex].value,
                                               activeSwitch.checked))
                        close()
                }

                function submit() {
                    if (AuthService.busy || !AuthService.canManageUsers || mode === "")
                        return
                    errorText = ""
                    if (mode === "edit") {
                        if (originalActive && !activeSwitch.checked) {
                            confirmPopup.showConfirm(
                                qsTr("Disable account"),
                                qsTr("Disable account \"%1\"? The user will not be able to sign in.")
                                    .arg(targetUsername),
                                function() { editor.commitEdit() }, qsTr("Disable"), AppColors.error)
                        } else {
                            commitEdit()
                        }
                        return
                    }
                    if (mode === "add" && usernameField.text.trim().length === 0) {
                        errorText = qsTr("Enter a username.")
                        return
                    }
                    if (newPasswordField.text !== confirmPasswordField.text) {
                        errorText = qsTr("Passwords do not match.")
                        return
                    }
                    if (mode === "add") {
                        AuthService.createUser(usernameField.text, displayField.text,
                                               roleCombo.model[roleCombo.currentIndex].value,
                                               newPasswordField.text, confirmPasswordField.text)
                    } else if (mode === "reset") {
                        AuthService.resetPassword(targetId, newPasswordField.text,
                                                  confirmPasswordField.text)
                    } else {
                        AuthService.changePassword(oldPasswordField.text, newPasswordField.text,
                                                   confirmPasswordField.text)
                    }
                }

                Connections {
                    target: AuthService
                    function onMessageSent(title, body) {
                        if (!root.formActive)
                            return
                        if (title === "Success") {
                            if (editor.mode === "add")
                                editor.close()
                            else if (editor.mode === "reset" || editor.mode === "self")
                                editor.cancel()
                        } else {
                            editor.errorText = body
                        }
                    }
                }

                ElevatedPane {
                    id: editorPane
                    width: editor.width
                    implicitHeight: editorLayout.implicitHeight + 2 * padding
                    padding: AppTheme.cardPadding

                    ColumnLayout {
                        id: editorLayout
                        Layout.fillWidth: true
                        spacing: AppTheme.spacingM

                        Text {
                            Layout.fillWidth: true
                            text: editor.mode === "add" ? qsTr("Add user")
                                  : editor.mode === "edit" ? qsTr("Edit user")
                                  : editor.mode === "reset" ? qsTr("Reset password")
                                  : qsTr("Change my password")
                            color: AppColors.accentColor
                            font: AppTypography.titleMediumBold
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: AppTheme.spacingL

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: AppTheme.spacingS

                                Text { text: qsTr("Username"); color: AppColors.onSurfaceVariant; font: AppTypography.bodyMedium }
                                TextField {
                                    id: usernameField
                                    Layout.fillWidth: true
                                    readOnly: editor.mode !== "add"
                                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                                    onTextEdited: editor.errorText = ""
                                    onAccepted: displayField.forceActiveFocus()
                                }

                                Text {
                                    visible: editor.mode === "add" || editor.mode === "edit"
                                    text: qsTr("Display name (optional)")
                                    color: AppColors.onSurfaceVariant
                                    font: AppTypography.bodyMedium
                                }
                                TextField {
                                    id: displayField
                                    visible: editor.mode === "add" || editor.mode === "edit"
                                    Layout.fillWidth: true
                                    inputMethodHints: Qt.ImhNoPredictiveText
                                    onTextEdited: editor.errorText = ""
                                    onAccepted: if (editor.mode === "add") newPasswordField.forceActiveFocus()
                                }

                                Text {
                                    visible: editor.mode === "edit" && editor.targetSelf
                                    Layout.fillWidth: true
                                    text: qsTr("Your own role and active status cannot be changed.")
                                    color: AppColors.textFaint
                                    font: AppTypography.bodySmall
                                    wrapMode: Text.WordWrap
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: AppTheme.spacingS

                                Text {
                                    visible: editor.mode === "add" || editor.mode === "edit"
                                    text: qsTr("Role")
                                    color: AppColors.onSurfaceVariant
                                    font: AppTypography.bodyMedium
                                }
                                ComboBox {
                                    id: roleCombo
                                    visible: editor.mode === "add" || editor.mode === "edit"
                                    enabled: editor.mode === "add" || !editor.targetSelf
                                    Layout.fillWidth: true
                                    textRole: "label"
                                    model: [
                                        { value: "viewer", label: qsTr("Viewer") },
                                        { value: "operator", label: qsTr("Operator") },
                                        { value: "admin", label: qsTr("Admin") }
                                    ]
                                }

                                RowLayout {
                                    visible: editor.mode === "edit"
                                    Layout.fillWidth: true
                                    Text { text: qsTr("Active"); color: AppColors.onSurfaceVariant; font: AppTypography.bodyMedium; Layout.fillWidth: true }
                                    Switch { id: activeSwitch; enabled: !editor.targetSelf }
                                }
                                AppButton {
                                    visible: editor.mode === "edit"
                                    Layout.fillWidth: true
                                    kind: AppButton.Secondary
                                    text: editor.targetSelf ? qsTr("Change my password") : qsTr("Reset password")
                                    enabled: !AuthService.busy
                                    onClicked: editor.openPassword()
                                }

                                Text {
                                    visible: editor.mode === "self"
                                    text: qsTr("Current password")
                                    color: AppColors.onSurfaceVariant
                                    font: AppTypography.bodyMedium
                                }
                                TextField {
                                    id: oldPasswordField
                                    visible: editor.mode === "self"
                                    Layout.fillWidth: true
                                    echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                    onTextEdited: editor.errorText = ""
                                    onAccepted: newPasswordField.forceActiveFocus()
                                }

                                Text {
                                    visible: editor.mode === "add" || editor.mode === "reset" || editor.mode === "self"
                                    text: editor.mode === "add" ? qsTr("Password") : qsTr("New password")
                                    color: AppColors.onSurfaceVariant
                                    font: AppTypography.bodyMedium
                                }
                                TextField {
                                    id: newPasswordField
                                    visible: editor.mode === "add" || editor.mode === "reset" || editor.mode === "self"
                                    Layout.fillWidth: true
                                    echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                    onTextEdited: editor.errorText = ""
                                    onAccepted: confirmPasswordField.forceActiveFocus()
                                }

                                Text {
                                    visible: editor.mode === "add" || editor.mode === "reset" || editor.mode === "self"
                                    text: qsTr("Confirm password")
                                    color: AppColors.onSurfaceVariant
                                    font: AppTypography.bodyMedium
                                }
                                TextField {
                                    id: confirmPasswordField
                                    visible: editor.mode === "add" || editor.mode === "reset" || editor.mode === "self"
                                    Layout.fillWidth: true
                                    echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                    onTextEdited: editor.errorText = ""
                                    onAccepted: editor.submit()
                                }

                                Text {
                                    visible: editor.mode === "add" || editor.mode === "reset" || editor.mode === "self"
                                    Layout.fillWidth: true
                                    text: qsTr("At least 8 characters, including a letter and a digit.")
                                    color: AppColors.textFaint
                                    font: AppTypography.bodySmall
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: editor.errorText.length > 0
                            text: editor.errorText
                            color: AppColors.error
                            font: AppTypography.bodyMedium
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
