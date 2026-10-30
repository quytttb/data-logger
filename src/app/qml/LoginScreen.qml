pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

// Lớp phủ đăng nhập/khóa phiên của kiosk.
//
// Bốn trạng thái, suy ra từ AuthService (không lưu cờ riêng trong QML):
//   setup  — DB chưa có tài khoản: bắt buộc tạo admin đầu tiên.
//   login  — chưa đăng nhập.
//   unlock — phiên bị khóa do không hoạt động: chỉ cần nhập lại mật khẩu.
//   change — tài khoản phải đổi mật khẩu (admin tạo/reset) trước khi dùng.
//
// Keyboard: lớp phủ nằm dưới bàn phím ảo (z 999), nên đẩy vùng cuộn lên bằng
// keyboardHeight để không bị che; nội dung cao hơn màn hình vẫn cuộn được.
Item {
    id: root

    // Chiều cao bàn phím ảo đang hiện (0 khi ẩn), do Main truyền vào.
    property int keyboardHeight: 0

    // Chuyển message của AuthService ra Main khi lớp phủ đang ẩn (quản lý tài
    // khoản ở Settings). Khi đang hiện, lỗi được hiển thị ngay trong form.
    signal messageForwarded(string title, string body)

    readonly property string mode: AuthService.firstRun ? "setup"
        : !AuthService.authenticated ? "login"
        : AuthService.locked ? "unlock"
        : AuthService.mustChangePassword ? "change"
        : "done"

    readonly property string headline: {
        if (mode === "setup")
            return qsTr("Set up this device")
        if (mode === "unlock")
            return qsTr("Session locked")
        if (mode === "change")
            return qsTr("Change password")
        return qsTr("Sign in")
    }

    readonly property string subtitle: {
        if (mode === "setup")
            return qsTr("Create the administrator account to finish setting up the data logger.")
        if (mode === "unlock")
            return qsTr("Signed in as %1.").arg(AuthService.currentDisplayName.length > 0
                                               ? AuthService.currentDisplayName
                                               : AuthService.currentUsername)
        if (mode === "change")
            return qsTr("This account must set a new password before it can be used.")
        return qsTr("Sign in to use the data logger.")
    }

    property string messageText: ""
    property bool messageIsError: true

    visible: mode !== "done"

    function clearMessage() {
        messageText = ""
    }

    function showMessage(text, isError) {
        messageText = text
        messageIsError = isError
    }

    function clearInputs() {
        setupPassword.text = ""
        setupConfirm.text = ""
        loginPassword.text = ""
        unlockPassword.text = ""
        oldPassword.text = ""
        newPassword.text = ""
        confirmPassword.text = ""
        clearMessage()
    }

    function submitSetup() {
        if (AuthService.busy)
            return
        if (setupUsername.text.trim().length === 0) {
            showMessage(qsTr("Enter a username."), true)
            return
        }
        if (setupPassword.text !== setupConfirm.text) {
            showMessage(qsTr("Passwords do not match."), true)
            return
        }
        clearMessage()
        AuthService.createFirstAdmin(setupUsername.text, setupDisplayName.text,
                                     setupPassword.text, setupConfirm.text)
    }

    function submitLogin() {
        if (AuthService.busy)
            return
        if (loginUsername.text.trim().length === 0 || loginPassword.text.length === 0) {
            showMessage(qsTr("Enter username and password."), true)
            return
        }
        clearMessage()
        AuthService.login(loginUsername.text, loginPassword.text)
    }

    function submitUnlock() {
        if (AuthService.busy)
            return
        if (unlockPassword.text.length === 0) {
            showMessage(qsTr("Enter your password."), true)
            return
        }
        clearMessage()
        AuthService.unlock(unlockPassword.text)
    }

    function submitPasswordChange() {
        if (AuthService.busy)
            return
        if (oldPassword.text.length === 0) {
            showMessage(qsTr("Enter your current password."), true)
            return
        }
        if (newPassword.text !== confirmPassword.text) {
            showMessage(qsTr("Passwords do not match."), true)
            return
        }
        clearMessage()
        AuthService.changePassword(oldPassword.text, newPassword.text, confirmPassword.text)
    }

    // Xóa mật khẩu đang gõ khi đổi trạng thái (đăng nhập xong, khóa phiên...).
    onModeChanged: clearInputs()

    Connections {
        target: AuthService
        function onMessageSent(title, body) {
            if (root.visible) {
                root.showMessage(body, title !== "Success")
            } else {
                root.messageForwarded(title, body)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: AppColors.surface
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: root.keyboardHeight
        contentWidth: flick.width
        contentHeight: Math.max(flick.height, card.height + 2 * AppTheme.spacingM)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        ElevatedPane {
            id: card
            width: Math.min(flick.width - 2 * AppTheme.spacingL, 420)
            x: (flick.width - width) / 2
            y: Math.max(AppTheme.spacingM, (flick.height - height) / 2)
            height: body.implicitHeight + 2 * AppTheme.cardPadding
            contentSpacing: AppTheme.spacingSM

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: AppTheme.spacingSM

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: "qrc:/qt/qml/LoggerKit/Components/resources/icons/brand_4m_technologies_blue.svg"
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    Layout.fillWidth: true
                    text: root.headline
                    color: AppColors.primaryText
                    font: AppTypography.headlineSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: AppColors.onSurfaceVariant
                    font: AppTypography.bodyMedium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                // ── Lần chạy đầu: tạo admin ─────────────────────────────
                ColumnLayout {
                    visible: root.mode === "setup"
                    Layout.fillWidth: true
                    spacing: AppTheme.spacingS

                    Text {
                        text: qsTr("Username")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: setupUsername
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        onTextEdited: root.clearMessage()
                        onAccepted: setupDisplayName.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("Display name (optional)")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: setupDisplayName
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhNoPredictiveText
                        onTextEdited: root.clearMessage()
                        onAccepted: setupPassword.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("Password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: setupPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: setupConfirm.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("Confirm password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: setupConfirm
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: root.submitSetup()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("At least 8 characters, including a letter and a digit.")
                        color: AppColors.textFaint
                        font: AppTypography.labelSmall
                        wrapMode: Text.WordWrap
                    }

                    AppButton {
                        Layout.fillWidth: true
                        Layout.topMargin: AppTheme.spacingXS
                        kind: AppButton.Primary
                        text: AuthService.busy ? qsTr("Please wait…") : qsTr("Create account")
                        enabled: !AuthService.busy
                        onClicked: root.submitSetup()
                    }
                }

                // ── Đăng nhập ───────────────────────────────────────────
                ColumnLayout {
                    visible: root.mode === "login"
                    Layout.fillWidth: true
                    spacing: AppTheme.spacingS

                    Text {
                        text: qsTr("Username")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: loginUsername
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        onTextEdited: root.clearMessage()
                        onAccepted: loginPassword.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("Password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: loginPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: root.submitLogin()
                    }

                    AppButton {
                        Layout.fillWidth: true
                        Layout.topMargin: AppTheme.spacingXS
                        kind: AppButton.Primary
                        text: AuthService.busy ? qsTr("Please wait…") : qsTr("Sign in")
                        enabled: !AuthService.busy
                        onClicked: root.submitLogin()
                    }
                }

                // ── Phiên bị khóa ───────────────────────────────────────
                ColumnLayout {
                    visible: root.mode === "unlock"
                    Layout.fillWidth: true
                    spacing: AppTheme.spacingS

                    Text {
                        text: qsTr("Password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: unlockPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: root.submitUnlock()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: AppTheme.spacingXS
                        spacing: AppTheme.spacingS

                        AppButton {
                            Layout.fillWidth: true
                            kind: AppButton.Neutral
                            text: qsTr("Sign out")
                            enabled: !AuthService.busy
                            onClicked: AuthService.logout()
                        }

                        AppButton {
                            Layout.fillWidth: true
                            kind: AppButton.Primary
                            text: AuthService.busy ? qsTr("Please wait…") : qsTr("Unlock")
                            enabled: !AuthService.busy
                            onClicked: root.submitUnlock()
                        }
                    }
                }

                // ── Bắt buộc đổi mật khẩu ───────────────────────────────
                ColumnLayout {
                    visible: root.mode === "change"
                    Layout.fillWidth: true
                    spacing: AppTheme.spacingS

                    Text {
                        text: qsTr("Current password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: oldPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: newPassword.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("New password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: newPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: confirmPassword.forceActiveFocus()
                    }

                    Text {
                        text: qsTr("Confirm new password")
                        color: AppColors.onSurfaceVariant
                        font: AppTypography.bodyMedium
                    }
                    TextField {
                        id: confirmPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                     | Qt.ImhNoAutoUppercase
                        onTextEdited: root.clearMessage()
                        onAccepted: root.submitPasswordChange()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("At least 8 characters, including a letter and a digit.")
                        color: AppColors.textFaint
                        font: AppTypography.labelSmall
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: AppTheme.spacingXS
                        spacing: AppTheme.spacingS

                        AppButton {
                            Layout.fillWidth: true
                            kind: AppButton.Neutral
                            text: qsTr("Sign out")
                            enabled: !AuthService.busy
                            onClicked: AuthService.logout()
                        }

                        AppButton {
                            Layout.fillWidth: true
                            kind: AppButton.Primary
                            text: AuthService.busy ? qsTr("Please wait…") : qsTr("Save")
                            enabled: !AuthService.busy
                            onClicked: root.submitPasswordChange()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.messageText.length > 0
                    text: root.messageText
                    color: root.messageIsError ? AppColors.error : AppColors.success
                    font: AppTypography.bodyMedium
                    wrapMode: Text.WordWrap
                }

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    visible: AuthService.busy
                    running: AuthService.busy
                    implicitWidth: 32
                    implicitHeight: 32
                }
            }
        }
    }
}
