pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

// Tab quản lý tài khoản kiosk (chỉ admin). Mọi thao tác đi qua AuthService —
// lớp này kiểm tra quyền và ghi DB; QML chỉ hiển thị/disable theo quyền.
Rectangle {
    id: root

    color: AppColors.surfaceContainerLow
    radius: AppTheme.cardRadius
    border.color: AppColors.elevatedBorder
    border.width: 1

    property var userRows: []
    property int currentRow: -1

    readonly property var selectedUser: (currentRow >= 0 && currentRow < userRows.length)
                                        ? userRows[currentRow] : null
    readonly property bool selfSelected: selectedUser !== null
                                         && selectedUser.username === AuthService.currentUsername

    function cellValue(user, column) {
        if (column === 0) return user.username
        if (column === 1) return user.displayName
        if (column === 2) return capitalize(user.role)
        if (column === 3) return user.active ? qsTr("Active") : qsTr("Disabled")
        if (column === 4) return formatTime(user.lastLoginAt)
        return ""
    }

    function capitalize(value) {
        const s = String(value)
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s
    }

    function formatTime(iso) {
        if (!iso)
            return "—"
        const d = new Date(iso)
        if (isNaN(d.getTime()))
            return iso
        return d.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    function rebuildRows() {
        const list = AuthService.users()
        const keepId = selectedUser !== null ? selectedUser.id : -1
        const rows = []
        const tableRows = []

        for (let i = 0; i < list.length; ++i) {
            const u = list[i]
            const row = {
                id: u.id,
                username: u.username,
                displayName: u.displayName,
                role: u.role,
                active: u.active,
                lastLoginAt: u.lastLoginAt
            }
            rows.push(row)
            tableRows.push([
                cellValue(row, 0),
                cellValue(row, 1),
                cellValue(row, 2),
                cellValue(row, 3),
                cellValue(row, 4)
            ])
        }

        userRows = rows
        // qmllint disable unqualified
        userTableModel.setHeaders([
            qsTr("User"), qsTr("Display name"), qsTr("Role"),
            qsTr("Status"), qsTr("Last sign-in")])
        userTableModel.setRows(tableRows)
        // qmllint enable unqualified

        currentRow = -1
        if (keepId > 0) {
            for (let i = 0; i < rows.length; ++i) {
                if (rows[i].id === keepId) {
                    currentRow = i
                    break
                }
            }
        }
    }

    function syncRoleCombo() {
        const role = selectedUser !== null ? selectedUser.role : ""
        let index = 0
        for (let i = 0; i < roleCombo.count; ++i) {
            if (roleCombo.model[i].value === role) {
                index = i
                break
            }
        }
        roleCombo.currentIndex = index
    }

    function toggleActive() {
        if (selectedUser === null)
            return
        const id = selectedUser.id
        const name = selectedUser.username
        if (selectedUser.active) {
            confirmPopup.showConfirm(
                qsTr("Disable account"),
                qsTr("Disable account \"%1\"? The user will not be able to sign in.").arg(name),
                function() { AuthService.setUserActive(id, false) },
                qsTr("Disable"),
                AppColors.error)
        } else {
            AuthService.setUserActive(id, true)
        }
    }

    function applyRole() {
        if (selectedUser === null || roleCombo.currentIndex < 0)
            return
        const role = roleCombo.model[roleCombo.currentIndex].value
        if (role !== selectedUser.role)
            AuthService.setUserRole(selectedUser.id, role)
    }

    onCurrentRowChanged: syncRoleCombo()
    onVisibleChanged: {
        if (visible)
            AuthService.refreshUsers()
        else
            editor.close()
    }

    Component.onCompleted: rebuildRows()

    Connections {
        target: AuthService
        function onUsersChanged() { root.rebuildRows() }
        function onSessionChanged() {
            // Khóa phiên/đăng xuất: đóng form đang mở để không giữ mật khẩu
            // trong các ô nhập, rồi làm mới danh sách theo quyền hiện tại.
            if (!AuthService.authenticated || AuthService.locked)
                editor.close()
            root.rebuildRows()
        }
    }

    JsonTableModel {
        id: userTableModel
    }

    MessagePopup {
        id: confirmPopup
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: AppTheme.spacingSM
            Layout.rightMargin: AppTheme.spacingSM
            spacing: AppTheme.spacingS

            AppButton {
                text: qsTr("+ Add user")
                font.bold: true
                fillColor: AppColors.success
                onClicked: editor.openAdd()
            }

            AppButton {
                text: qsTr("Reset password")
                kind: AppButton.Secondary
                enabled: root.selectedUser !== null && !root.selfSelected && !AuthService.busy
                onClicked: editor.openReset(root.selectedUser)
            }

            AppButton {
                text: root.selectedUser !== null && root.selectedUser.active
                      ? qsTr("Disable") : qsTr("Enable")
                kind: AppButton.Neutral
                enabled: root.selectedUser !== null && !root.selfSelected && !AuthService.busy
                onClicked: root.toggleActive()
            }

            AppButton {
                text: qsTr("My password")
                kind: AppButton.Neutral
                enabled: !AuthService.busy
                onClicked: editor.openSelf()
            }

            Item { Layout.fillWidth: true }

            Text {
                text: qsTr("Role")
                color: AppColors.onSurfaceVariant
                font: AppTypography.bodyMedium
            }

            ComboBox {
                id: roleCombo
                Layout.preferredWidth: 130
                textRole: "label"
                model: [
                    { value: "viewer",   label: qsTr("Viewer") },
                    { value: "operator", label: qsTr("Operator") },
                    { value: "admin",    label: qsTr("Admin") }
                ]
            }

            AppButton {
                text: qsTr("Apply")
                font.bold: true
                enabled: root.selectedUser !== null && !root.selfSelected && !AuthService.busy
                         && roleCombo.currentIndex >= 0
                         && roleCombo.model[roleCombo.currentIndex].value !== root.selectedUser.role
                onClicked: root.applyRole()
            }
        }

        AppTableView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // qmllint disable unqualified
            model: userTableModel
            // qmllint enable unqualified
            hasData: root.userRows.length > 0
            colWeights: [0.24, 0.28, 0.14, 0.14, 0.20]
            colMinimums: [120, 140, 80, 80, 120]
            headerAlignCenter: function(col) { return col === 2 || col === 3 }
            emptyMessage: qsTr("No user accounts yet.")
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
                    onClicked: root.currentRow = (root.currentRow === cell.row) ? -1 : cell.row
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
                    color: (cell.column === 3 && root.selectedUser !== null
                            && root.selectedUser.active === false)
                           ? AppColors.error
                           : (cell.column === 0 ? AppColors.primaryText : AppColors.tableCellMuted)
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                    font.weight: cell.column === 0 ? Font.DemiBold : Font.Normal
                    horizontalAlignment: (cell.column === 2 || cell.column === 3)
                                         ? Text.AlignHCenter : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── Form thêm tài khoản / reset / đổi mật khẩu ──────────────────────
    // Không dùng Popup: popup nằm trong Overlay (trên bàn phím ảo), sẽ bị
    // bàn phím che khi nhập. Panel nội tuyến z thấp hơn bàn phím (999).
    Rectangle {
        id: editor
        anchors.fill: parent
        z: 20
        visible: false
        color: AppColors.withAlpha("#000000", 0.55)

        property string mode: "add"       // add | reset | self
        property int targetId: -1
        property string targetUsername: ""
        property string errorText: ""

        function openAdd() {
            mode = "add"
            targetId = -1
            targetUsername = ""
            errorText = ""
            usernameField.text = ""
            displayField.text = ""
            addRoleCombo.currentIndex = 1  // operator
            clearPasswords()
            visible = true
            usernameField.forceActiveFocus()
        }

        function openReset(user) {
            if (user === null)
                return
            mode = "reset"
            targetId = user.id
            targetUsername = user.username
            errorText = ""
            clearPasswords()
            visible = true
            newPasswordField.forceActiveFocus()
        }

        function openSelf() {
            mode = "self"
            targetId = -1
            targetUsername = AuthService.currentUsername
            errorText = ""
            clearPasswords()
            visible = true
            oldPasswordField.forceActiveFocus()
        }

        function close() {
            visible = false
            clearPasswords()
            errorText = ""
        }

        function clearPasswords() {
            oldPasswordField.text = ""
            newPasswordField.text = ""
            confirmPasswordField.text = ""
        }

        function submit() {
            if (AuthService.busy)
                return
            if (mode === "add" && usernameField.text.trim().length === 0) {
                errorText = qsTr("Enter a username.")
                return
            }
            if ((mode === "self" || mode === "reset")
                    && newPasswordField.text !== confirmPasswordField.text) {
                errorText = qsTr("Passwords do not match.")
                return
            }
            if (mode === "add" && newPasswordField.text !== confirmPasswordField.text) {
                errorText = qsTr("Passwords do not match.")
                return
            }
            errorText = ""
            if (mode === "add") {
                AuthService.createUser(usernameField.text, displayField.text,
                                       addRoleCombo.model[addRoleCombo.currentIndex].value,
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
                if (!editor.visible)
                    return
                if (title === "Success") {
                    editor.close()
                    return
                }
                editor.errorText = body
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Flickable {
            id: editorFlick
            anchors.fill: parent
            contentWidth: editorFlick.width
            contentHeight: Math.max(editorFlick.height, editorCard.height + 2 * AppTheme.spacingM)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ElevatedPane {
                id: editorCard
                width: Math.min(editorFlick.width - 2 * AppTheme.spacingL, 440)
                x: (editorFlick.width - width) / 2
                y: Math.max(AppTheme.spacingM, (editorFlick.height - height) / 2)
                height: editorBody.implicitHeight + 2 * AppTheme.cardPadding
                contentSpacing: AppTheme.spacingSM

                ColumnLayout {
                    id: editorBody
                    Layout.fillWidth: true
                    spacing: AppTheme.spacingS

                    Text {
                        Layout.fillWidth: true
                        text: editor.mode === "add" ? qsTr("Add user")
                            : editor.mode === "reset" ? qsTr("Reset password")
                            : qsTr("Change my password")
                        color: AppColors.primaryText
                        font: AppTypography.titleMediumBold
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: editor.mode !== "add"
                        text: editor.mode === "reset"
                              ? qsTr("Account: %1").arg(editor.targetUsername)
                              : qsTr("Account: %1").arg(AuthService.currentUsername)
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        visible: editor.mode === "add"
                        text: qsTr("Username")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: usernameField
                        visible: editor.mode === "add"
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        onTextEdited: editor.errorText = ""
                        onAccepted: displayField.forceActiveFocus()
                    }

                    Text {
                        visible: editor.mode === "add"
                        text: qsTr("Display name (optional)")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: displayField
                        visible: editor.mode === "add"
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhNoPredictiveText
                        onTextEdited: editor.errorText = ""
                        onAccepted: newPasswordField.forceActiveFocus()
                    }

                    Text {
                        visible: editor.mode === "add"
                        text: qsTr("Role")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    ComboBox {
                        id: addRoleCombo
                        visible: editor.mode === "add"
                        Layout.fillWidth: true
                        textRole: "label"
                        model: [
                            { value: "viewer",   label: qsTr("Viewer") },
                            { value: "operator", label: qsTr("Operator") },
                            { value: "admin",    label: qsTr("Admin") }
                        ]
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
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: editor.errorText = ""
                        onAccepted: newPasswordField.forceActiveFocus()
                    }

                    Text {
                        text: editor.mode === "add" ? qsTr("Password") : qsTr("New password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: newPasswordField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: editor.errorText = ""
                        onAccepted: confirmPasswordField.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("Confirm password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: confirmPasswordField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: editor.errorText = ""
                        onAccepted: editor.submit()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("At least 8 characters, including a letter and a digit.")
                        color: AppColors.textFaint
                        font: AppTypography.labelSmall
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: editor.errorText.length > 0
                        text: editor.errorText
                        color: AppColors.error
                        font: AppTypography.bodyMedium
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: AppTheme.spacingXS
                        spacing: AppTheme.spacingS

                        AppButton {
                            Layout.fillWidth: true
                            kind: AppButton.Neutral
                            text: qsTr("Cancel")
                            enabled: !AuthService.busy
                            onClicked: editor.close()
                        }

                        AppButton {
                            Layout.fillWidth: true
                            kind: AppButton.Primary
                            text: AuthService.busy ? qsTr("Please wait…")
                                : editor.mode === "add" ? qsTr("Create")
                                : editor.mode === "reset" ? qsTr("Reset")
                                : qsTr("Save")
                            enabled: !AuthService.busy
                            onClicked: editor.submit()
                        }
                    }
                }
            }
        }
    }
}
