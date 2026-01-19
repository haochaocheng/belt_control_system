import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// Settings page for SIP account registration
Page {
    id: root

    // ✅ 2026-01-18 12:00 [FIX 100.246] 版本确认 - 前后端分离完成
    Component.onCompleted: {
        console.log("═══════════════════════════════════════════════════════")
        console.log("🔥🔥🔥 SIP SETTINGS PAGE LOADED - VERSION 2026-01-18-12:00")
        console.log("🔥🔥🔥 FIX 100.246: 前后端分离完成，设备枚举通过 signal 更新")
        console.log("═══════════════════════════════════════════════════════")
    }

    // Inline RisipButton component
    component RisipButton: Button {
        id: control
        property color buttonColor: "#2c3e50"
        property color hoverColor: "#34495e"
        property color pressColor: "#2980b9"
        property color textColor: "#ffffff"
        property color borderColor: "#00d4ff"
        property int borderWidth: 2
        property int buttonRadius: 10
        property bool isHovered: false

        background: Rectangle {
            color: control.pressed ? control.pressColor : (control.isHovered ? control.hoverColor : control.buttonColor)
            radius: control.buttonRadius
            border.color: control.borderColor
            border.width: control.borderWidth
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        HoverHandler {
            onHoveredChanged: control.isHovered = hovered
        }
    }

    // Inline RisipLineEdit component
    component RisipLineEdit: TextField {
        id: control
        property color backgroundColor: "#0f3460"
        property color borderColor: "#00d4ff"
        property color textColor: "#ffffff"
        property color placeholderColor: "#7f8c8d"
        property int borderWidth: 2
        property int inputRadius: 10

        background: Rectangle {
            color: control.backgroundColor
            radius: control.inputRadius
            border.color: control.activeFocus ? "#00ff88" : control.borderColor
            border.width: control.borderWidth
        }

        color: control.textColor
        placeholderTextColor: control.placeholderColor
        font.pixelSize: 16
        selectByMouse: true
        leftPadding: 15
        rightPadding: 15

        // When focused, ensure visible above keyboard
        // ✅ CRITICAL: Only call mainFlickable.ensureVisible if NOT in Dialog
        onActiveFocusChanged: {
            if (activeFocus && !addAccountDialog.opened) {
                mainFlickable.ensureVisible(control)
            }
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    // ✅ Track selected account for configuration
    property string selectedAccountUri: ""  // Selected account URI
    property bool hasSelectedAccount: selectedAccountUri !== ""

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        contentWidth: width
        contentHeight: mainContent.implicitHeight + 40

        interactive: contentHeight > height && !addAccountDialog.opened  // ✅ Disable when Dialog is open
        enabled: !addAccountDialog.opened  // ✅ CRITICAL: Disable all event handling when Dialog is open
        flickableDirection: Flickable.VerticalFlick

        property real scrollMarginVertical: 10  // Reduced from 50 to 10 - keep input close to keyboard top

        // Monitor keyboard visibility and reset scroll when keyboard hides
        Connections {
            target: Qt.inputMethod
            function onVisibleChanged() {
                if (!Qt.inputMethod.visible) {
                    scrollAnimation.to = 0
                    scrollAnimation.start()
                }
            }
        }

        // Smooth scroll animation
        NumberAnimation {
            id: scrollAnimation
            target: mainFlickable
            property: "contentY"
            duration: 300
            easing.type: Easing.OutQuad
        }

        // Function to ensure input field is visible
        function ensureVisible(item) {
            if (!item) return

            var yPos = item.mapToItem(mainFlickable.contentItem, 0, 0).y
            var itemHeight = item.height
            var keyboardHeight = Qt.inputMethod.keyboardRectangle.height
            var visibleAreaHeight = mainFlickable.height - keyboardHeight

            var targetY = 0
            if (yPos + itemHeight + scrollMarginVertical > contentY + visibleAreaHeight) {
                targetY = yPos + itemHeight + scrollMarginVertical - visibleAreaHeight
            } else if (yPos - scrollMarginVertical < contentY) {
                targetY = Math.max(0, yPos - scrollMarginVertical)
            } else {
                return
            }

            scrollAnimation.to = targetY
            scrollAnimation.start()
        }

        ColumnLayout {
            id: mainContent
            width: parent.width
            spacing: 20

            // Account status section
            Rectangle {
                Layout.fillWidth: true
                height: 100
                color: "#0f3460"
                radius: 10
                border.color: SipPhoneManager.isRegistered ? "#27ae60" : "#e74c3c"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: SipPhoneManager.isRegistered ? "#27ae60" : "#e74c3c"

                            SequentialAnimation on opacity {
                                running: SipPhoneManager.isRegistered
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                            }
                        }

                        Text {
                            text: SipPhoneManager.isRegistered ? "账号已注册" : "账号未注册"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    Text {
                        text: SipPhoneManager.serverStatus
                        font.pixelSize: 13
                        color: "#95a5a6"
                        Layout.fillWidth: true
                    }
                }
            }

            // Auto-login toggle section
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "应用启动时自动登录"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: "启用后应用启动时将自动注册已保存的账户"
                            font.pixelSize: 12
                            color: "#95a5a6"
                        }
                    }

                    Switch {
                        id: autoLoginSwitch
                        checked: SipPhoneManager.getAutoSignIn()

                        onToggled: {
                            SipPhoneManager.setAutoSignInEnabled(checked)
                            console.log("Auto-login toggled:", checked)
                        }

                        indicator: Rectangle {
                            implicitWidth: 56
                            implicitHeight: 28
                            x: autoLoginSwitch.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 14
                            color: autoLoginSwitch.checked ? "#27ae60" : "#7f8c8d"
                            border.color: autoLoginSwitch.checked ? "#00ff88" : "#95a5a6"

                            Rectangle {
                                x: autoLoginSwitch.checked ? parent.width - width - 2 : 2
                                y: 2
                                width: 24
                                height: 24
                                radius: 12
                                color: "#ffffff"
                                border.color: "#ecf0f1"

                                Behavior on x {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }
                    }
                }
            }

            // Saved accounts section
            Text {
                text: "已保存的账号"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(accountsListView.contentHeight + 40, 100)
                visible: true  // Always visible - let ListView handle empty state
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ListView {
                    id: accountsListView
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10
                    clip: true
                    interactive: false  // Disable scrolling since we're in a Flickable

                    // Use property binding to SipPhoneManager.accountsModel
                    model: SipPhoneManager.accountsModel

                    // Debug: Print model info when component loads
                    Component.onCompleted: {
                        console.log("[QML] ListView initialized")
                        console.log("[QML] Model object:", SipPhoneManager.accountsModel)
                        console.log("[QML] Model count:", count)
                        console.log("[QML] Model rowCount:", SipPhoneManager.accountsModel ? SipPhoneManager.accountsModel.rowCount() : "null")
                    }

                    Connections {
                        target: SipPhoneManager.accountsModel
                        function onLayoutChanged() {
                            console.log("[QML] Model layout changed, new count:", accountsListView.count)
                        }
                        function onRowsInserted() {
                            console.log("[QML] Rows inserted, new count:", accountsListView.count)
                        }
                    }

                    // Empty state indicator when count is 0
                    Text {
                        anchors.centerIn: parent
                        visible: accountsListView.count === 0
                        text: "暂无保存的账号,请先注册一个账户"
                        font.pixelSize: 14
                        color: "#95a5a6"
                    }

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 80
                        // ✅ Change background color based on selection state (use accountUri)
                        property string itemAccountUri: model.accountUri || model.uri || ""
                        color: root.selectedAccountUri === itemAccountUri ? "#1e3a5f" : "#16213e"
                        radius: 8
                        border.color: root.selectedAccountUri === itemAccountUri ? "#00ff88" : (model.isDefault ? "#00ff88" : "#00d4ff")
                        border.width: root.selectedAccountUri === itemAccountUri ? 3 : (model.isDefault ? 2 : 1)

                        // ✅ MouseArea covering entire Rectangle
                        MouseArea {
                            anchors.fill: parent

                            onClicked: function(mouse) {
                                // ✅ Check if click is NOT on buttons area (right 160px)
                                var buttonsWidth = 160  // Two 70px buttons + spacing
                                if (mouse.x < width - buttonsWidth) {
                                    // Clicked on account info area - select account
                                    var accountUri = model.accountUri || model.uri || ""
                                    console.log("[Account Delegate] Clicked account:", accountUri, "at x:", mouse.x)

                                    // Set as selected account
                                    root.selectedAccountUri = accountUri

                                    // Auto-fill configuration with this account's info
                                    var addr = model.serverAddress || ""
                                    var parts = addr.split(":")
                                    serverInput.text = parts[0] || ""
                                    portInput.text = parts.length > 1 ? parts[1] : "5060"
                                    // ✅ Use userName (correct role name)
                                    usernameInput.text = model.userName || model.username || ""
                                    passwordInput.text = model.password || ""  // Fill password from model

                                    console.log("[Account Delegate] Selected account:", root.selectedAccountUri)
                                    console.log("[Account Delegate] Auto-filled server:", serverInput.text, "port:", portInput.text, "username:", usernameInput.text)
                                } else {
                                    // Clicked on buttons area - don't handle, let buttons handle it
                                    console.log("[Account Delegate] Clicked on buttons area at x:", mouse.x, "- ignoring")
                                    mouse.accepted = false
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 15

                            // Account info - clickable area
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: itemAccountUri || "未知账号"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#ffffff"
                                    }

                                    Rectangle {
                                        visible: model.isDefault
                                        width: 50
                                        height: 20
                                        radius: 4
                                        color: "#00ff88"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "默认"
                                            font.pixelSize: 10
                                            color: "#000000"
                                        }
                                    }

                                    // ✅ Show "已选择" badge when selected
                                    Rectangle {
                                        visible: root.selectedAccountUri === itemAccountUri
                                        width: 60
                                        height: 20
                                        radius: 4
                                        color: "#2980b9"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "已选择"
                                            font.pixelSize: 10
                                            color: "#ffffff"
                                        }
                                    }
                                }

                                Text {
                                    text: "服务器: " + (model.serverAddress || "未知")
                                    font.pixelSize: 12
                                    color: "#95a5a6"
                                }
                            }

                            // ✅ Fixed-width spacer to keep buttons in same position
                            Item {
                                Layout.fillWidth: true
                            }

                            // Action buttons - fixed position on the right
                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: 8

                                RisipButton {
                                    Layout.preferredWidth: 70
                                    Layout.preferredHeight: 35
                                    text: model.isDefault ? "★默认" : "设为默认"
                                    buttonColor: model.isDefault ? "#27ae60" : "#7f8c8d"
                                    enabled: !model.isDefault
                                    font.pixelSize: 12

                                    onClicked: {
                                        SipPhoneManager.setAsDefaultAccount(itemAccountUri)
                                    }
                                }

                                RisipButton {
                                    Layout.preferredWidth: 70
                                    Layout.preferredHeight: 35
                                    text: "删除"
                                    buttonColor: "#e74c3c"
                                    font.pixelSize: 12

                                    onClicked: {
                                        SipPhoneManager.removeAccount(itemAccountUri)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // SIP server settings
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                spacing: 15

                Text {
                    text: "SIP 服务器配置"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#00d4ff"
                    Layout.fillWidth: true
                }

                // ✅ Show clear selection button when account is selected
                RisipButton {
                    visible: root.hasSelectedAccount
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 35
                    text: "清除选择"
                    buttonColor: "#7f8c8d"
                    hoverColor: "#95a5a6"
                    font.pixelSize: 12

                    onClicked: {
                        console.log("[SipSettingsPage] Clearing account selection")
                        root.selectedAccountUri = ""
                        // Optionally clear the form fields
                        serverInput.text = ""
                        portInput.text = "5060"
                        usernameInput.text = ""
                        passwordInput.text = ""
                    }
                }
            }

            // ✅ Hint text when account is selected
            Text {
                visible: root.hasSelectedAccount
                text: "已选择账户，配置为只读。点击 \"清除选择\" 可手动输入配置。"
                font.pixelSize: 12
                color: "#f39c12"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: serverSettingsLayout.implicitHeight + 40
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ColumnLayout {
                    id: serverSettingsLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    // SIP Server
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "SIP 服务器地址"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        RisipLineEdit {
                            id: serverInput
                            Layout.fillWidth: true
                            placeholderText: "例如: 192.168.10.243"
                            text: "192.168.10.243"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly  // Numbers and dots for IP
                            readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
                            backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
                        }
                    }

                    // Port
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "端口"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        RisipLineEdit {
                            id: portInput
                            Layout.fillWidth: true
                            placeholderText: "默认: 5060"
                            text: "5060"
                            validator: IntValidator { bottom: 1; top: 65535 }
                            inputMethodHints: Qt.ImhDigitsOnly  // Only numbers
                            readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
                            backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
                        }
                    }

                    // Username
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "用户名"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        RisipLineEdit {
                            id: usernameInput
                            Layout.fillWidth: true
                            placeholderText: "SIP 用户名"
                            text: "1000"
                            inputMethodHints: Qt.ImhDigitsOnly  // Typically numeric
                            readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
                            backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
                        }
                    }

                    // Password
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "密码"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        RisipLineEdit {
                            id: passwordInput
                            Layout.fillWidth: true
                            placeholderText: "SIP 密码"
                            echoMode: TextInput.Password
                            text: "1234"
                            inputMethodHints: Qt.ImhNoPredictiveText  // Password, no suggestions
                            readOnly: root.hasSelectedAccount  // ✅ Read-only when account selected
                            backgroundColor: root.hasSelectedAccount ? "#0a1f3a" : "#0f3460"  // Dimmed when read-only
                        }
                    }
                }
            }

            // Register/Unregister buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                RisipButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    text: root.hasSelectedAccount ? "注册所选账号" : "注册账号"
                    buttonColor: "#27ae60"
                    hoverColor: "#229954"
                    enabled: !SipPhoneManager.isRegistered &&
                             serverInput.text &&
                             usernameInput.text &&
                             passwordInput.text

                    onClicked: {
                        // Dismiss keyboard before registering
                        Qt.inputMethod.hide()

                        if (!SipPhoneManager.isInitialized) {
                            SipPhoneManager.initializeEndpoint()
                        }

                        // ✅ CRITICAL: Different logic for existing account vs new account
                        if (root.hasSelectedAccount) {
                            // Login to existing account (DON'T create new account!)
                            console.log("[SipSettingsPage] Logging in to existing account:", root.selectedAccountUri)
                            SipPhoneManager.loginExistingAccount(root.selectedAccountUri)
                        } else {
                            // Create and register new account
                            console.log("[SipSettingsPage] Registering new account with manual configuration")
                            var port = parseInt(portInput.text) || 5060
                            SipPhoneManager.registerAccount(
                                serverInput.text,
                                usernameInput.text,
                                passwordInput.text,
                                port
                            )
                        }
                    }
                }

                RisipButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    text: "注销账号"
                    buttonColor: "#e74c3c"
                    hoverColor: "#cb4335"
                    enabled: SipPhoneManager.isRegistered

                    onClicked: {
                        Qt.inputMethod.hide()
                        SipPhoneManager.unregisterAccount()
                    }
                }
            }

            // Audio settings section
            Text {
                text: "音频设置"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                Layout.topMargin: 20
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: audioSettingsLayout.implicitHeight + 40
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ColumnLayout {
                    id: audioSettingsLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // ✅ 2026-01-17 22:30 [FIX 100.246] 扬声器选择
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "扬声器设备"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        ComboBox {
                            id: speakerDeviceCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            // ✅ 2026-01-18 12:00 [FIX 100.246] 使用 property 绑定代替函数调用
                            // 原因：函数调用会立即求值触发 PJSIP 初始化，property 绑定响应 signal 更新
                            model: SipPhoneManager.audioOutputDevices
                            currentIndex: SipPhoneManager.getCurrentAudioOutputDevice()

                            // ✅ 2026-01-18 12:00 [DEBUG] 监控初始化和信号接收
                            Component.onCompleted: {
                                console.log("🔥 [QML Speaker] ComboBox initialized")
                                console.log("   Initial model count:", count)
                                console.log("   CurrentIndex:", currentIndex)
                            }

                            Connections {
                                target: SipPhoneManager
                                function onAudioOutputDevicesChanged(devices) {
                                    console.log("📱 [QML Speaker] Received audioOutputDevicesChanged signal")
                                    console.log("   New device count:", devices.length)
                                    // ✅ 2026-01-19 16:45 [FIX 100.250.3] 更新 currentIndex 到保存的设备索引
                                    // 原因：设备枚举完成后，从 QSettings 读取保存的设备索引并更新 UI
                                    // 时序：QML 加载 → 设备枚举 → 发射信号 → 更新 currentIndex
                                    speakerDeviceCombo.currentIndex = SipPhoneManager.getCurrentAudioOutputDevice()
                                    console.log("   Updated currentIndex to:", speakerDeviceCombo.currentIndex)
                                }
                            }

                            background: Rectangle {
                                color: "#0f3460"
                                radius: 10
                                border.color: speakerDeviceCombo.activeFocus ? "#00ff88" : "#00d4ff"
                                border.width: 2
                            }

                            contentItem: Text {
                                text: speakerDeviceCombo.displayText
                                color: "#ffffff"
                                font.pixelSize: 14
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 15
                                elide: Text.ElideRight
                            }

                            onActivated: function(index) {
                                console.log("🔊 Changing speaker device to index:", index)
                                SipPhoneManager.setAudioOutputDevice(index)
                            }
                        }
                    }

                    // ✅ 2026-01-17 22:30 [FIX 100.246] 麦克风选择
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "麦克风设备"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        ComboBox {
                            id: micDeviceCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            // ✅ 2026-01-18 12:00 [FIX 100.246] 使用 property 绑定代替函数调用
                            model: SipPhoneManager.audioInputDevices
                            currentIndex: SipPhoneManager.getCurrentAudioInputDevice()

                            // ✅ 2026-01-18 12:00 [DEBUG] 监控初始化和信号接收
                            Component.onCompleted: {
                                console.log("🔥 [QML Mic] ComboBox initialized")
                                console.log("   Initial model count:", count)
                                console.log("   CurrentIndex:", currentIndex)
                            }

                            Connections {
                                target: SipPhoneManager
                                function onAudioInputDevicesChanged(devices) {
                                    console.log("📱 [QML Mic] Received audioInputDevicesChanged signal")
                                    console.log("   New device count:", devices.length)
                                    // ✅ 2026-01-19 16:45 [FIX 100.250.3] 更新 currentIndex 到保存的设备索引
                                    // 原因：设备枚举完成后，从 QSettings 读取保存的设备索引并更新 UI
                                    // 时序：QML 加载 → 设备枚举 → 发射信号 → 更新 currentIndex
                                    micDeviceCombo.currentIndex = SipPhoneManager.getCurrentAudioInputDevice()
                                    console.log("   Updated currentIndex to:", micDeviceCombo.currentIndex)
                                }
                            }

                            background: Rectangle {
                                color: "#0f3460"
                                radius: 10
                                border.color: micDeviceCombo.activeFocus ? "#00ff88" : "#00d4ff"
                                border.width: 2
                            }

                            contentItem: Text {
                                text: micDeviceCombo.displayText
                                color: "#ffffff"
                                font.pixelSize: 14
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 15
                                elide: Text.ElideRight
                            }

                            onActivated: function(index) {
                                console.log("📢 Changing microphone device to index:", index)
                                SipPhoneManager.setAudioInputDevice(index)
                            }
                        }
                    }

                    // ✅ 2026-01-17 22:30 [FIX 100.246] 摄像头选择
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "摄像头设备"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        ComboBox {
                            id: cameraDeviceCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            // ✅ 2026-01-18 12:00 [FIX 100.246] 使用 property 绑定代替函数调用
                            model: SipPhoneManager.videoDevices
                            currentIndex: SipPhoneManager.getCurrentVideoDevice()

                            // ✅ 2026-01-18 12:00 [DEBUG] 监控初始化和信号接收
                            Component.onCompleted: {
                                console.log("🔥 [QML Camera] ComboBox initialized")
                                console.log("   Initial model count:", count)
                                console.log("   CurrentIndex:", currentIndex)
                            }

                            Connections {
                                target: SipPhoneManager
                                function onVideoDevicesChanged(devices) {
                                    console.log("📱 [QML Camera] Received videoDevicesChanged signal")
                                    console.log("   New device count:", devices.length)
                                    // ✅ 2026-01-19 17:30 [FIX 100.251] 更新 currentIndex 到保存的设备索引
                                    cameraDeviceCombo.currentIndex = SipPhoneManager.getCurrentVideoDevice()
                                    console.log("   Updated currentIndex to:", cameraDeviceCombo.currentIndex)
                                }
                            }

                            background: Rectangle {
                                color: "#0f3460"
                                radius: 10
                                border.color: cameraDeviceCombo.activeFocus ? "#00ff88" : "#00d4ff"
                                border.width: 2
                            }

                            contentItem: Text {
                                text: cameraDeviceCombo.displayText
                                color: "#ffffff"
                                font.pixelSize: 14
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 15
                                elide: Text.ElideRight
                            }

                            onActivated: function(index) {
                                console.log("📹 Changing camera device to index:", index)
                                SipPhoneManager.setVideoDevice(index)
                            }
                        }
                    }

                    // Microphone volume
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "麦克风音量"
                                font.pixelSize: 13
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: micVolumeSlider.value + "%"
                                font.pixelSize: 13
                                color: "#00d4ff"
                            }
                        }

                        Slider {
                            id: micVolumeSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: 80
                            stepSize: 1

                            onValueChanged: {
                                SipPhoneManager.setMicrophoneVolume(value)
                            }

                            background: Rectangle {
                                x: micVolumeSlider.leftPadding
                                y: micVolumeSlider.topPadding + micVolumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: micVolumeSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: "#34495e"

                                Rectangle {
                                    width: micVolumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#00d4ff"
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: micVolumeSlider.leftPadding + micVolumeSlider.visualPosition * (micVolumeSlider.availableWidth - width)
                                y: micVolumeSlider.topPadding + micVolumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: micVolumeSlider.pressed ? "#0099cc" : "#00d4ff"
                                border.color: "#ffffff"
                                border.width: 2
                            }
                        }
                    }

                    // Speaker volume
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "扬声器音量"
                                font.pixelSize: 13
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: speakerVolumeSlider.value + "%"
                                font.pixelSize: 13
                                color: "#00d4ff"
                            }
                        }

                        Slider {
                            id: speakerVolumeSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: 80
                            stepSize: 1

                            onValueChanged: {
                                SipPhoneManager.setSpeakerVolume(value)
                            }

                            background: Rectangle {
                                x: speakerVolumeSlider.leftPadding
                                y: speakerVolumeSlider.topPadding + speakerVolumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: speakerVolumeSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: "#34495e"

                                Rectangle {
                                    width: speakerVolumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#00d4ff"
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: speakerVolumeSlider.leftPadding + speakerVolumeSlider.visualPosition * (speakerVolumeSlider.availableWidth - width)
                                y: speakerVolumeSlider.topPadding + speakerVolumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: speakerVolumeSlider.pressed ? "#0099cc" : "#00d4ff"
                                border.color: "#ffffff"
                                border.width: 2
                            }
                        }
                    }

                    // Mute microphone checkbox
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        CheckBox {
                            id: muteCheckbox

                            indicator: Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                x: muteCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 5
                                border.color: "#00d4ff"
                                border.width: 2
                                color: muteCheckbox.checked ? "#00d4ff" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "#ffffff"
                                    font.pixelSize: 18
                                    visible: muteCheckbox.checked
                                }
                            }

                            contentItem: Text {
                                text: "静音麦克风"
                                font.pixelSize: 13
                                color: "#ffffff"
                                leftPadding: muteCheckbox.indicator.width + muteCheckbox.spacing
                                verticalAlignment: Text.AlignVCenter
                            }

                            onCheckedChanged: {
                                SipPhoneManager.muteMicrophone(checked)
                            }
                        }
                    }
                }
            }

            // ✅ 2026-01-19 18:00 [FIX 100.252] Audio Codec Selection (音频编解码器选择)
            Text {
                text: "音频编解码器"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                Layout.topMargin: 20
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: audioCodecLayout.implicitHeight + 40
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ColumnLayout {
                    id: audioCodecLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Repeater {
                        model: SipPhoneManager.getAudioCodecs()

                        CheckBox {
                            id: audioCodecCheckbox
                            Layout.fillWidth: true
                            checked: SipPhoneManager.isAudioCodecEnabled(modelData)

                            indicator: Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                x: audioCodecCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 5
                                border.color: "#00d4ff"
                                border.width: 2
                                color: audioCodecCheckbox.checked ? "#00d4ff" : "transparent"

                                Text {
                                    text: "✓"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#ffffff"
                                    anchors.centerIn: parent
                                    visible: audioCodecCheckbox.checked
                                }
                            }

                            contentItem: Text {
                                text: modelData
                                font.pixelSize: 13
                                color: "#ffffff"
                                leftPadding: audioCodecCheckbox.indicator.width + audioCodecCheckbox.spacing
                                verticalAlignment: Text.AlignVCenter
                            }

                            onCheckedChanged: {
                                console.log("🎵 [FIX 100.252] Audio codec", modelData, checked ? "enabled" : "disabled")
                                SipPhoneManager.setAudioCodecEnabled(modelData, checked)
                            }
                        }
                    }
                }
            }

            // ✅ 2026-01-19 18:00 [FIX 100.252] Video Codec Selection (视频编解码器选择)
            Text {
                text: "视频编解码器"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                Layout.topMargin: 20
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: videoCodecLayout.implicitHeight + 40
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ColumnLayout {
                    id: videoCodecLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Repeater {
                        model: SipPhoneManager.getVideoCodecs()

                        CheckBox {
                            id: videoCodecCheckbox
                            Layout.fillWidth: true
                            checked: SipPhoneManager.isVideoCodecEnabled(modelData)

                            indicator: Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                x: videoCodecCheckbox.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 5
                                border.color: "#00d4ff"
                                border.width: 2
                                color: videoCodecCheckbox.checked ? "#00d4ff" : "transparent"

                                Text {
                                    text: "✓"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#ffffff"
                                    anchors.centerIn: parent
                                    visible: videoCodecCheckbox.checked
                                }
                            }

                            contentItem: Text {
                                text: modelData
                                font.pixelSize: 13
                                color: "#ffffff"
                                leftPadding: videoCodecCheckbox.indicator.width + videoCodecCheckbox.spacing
                                verticalAlignment: Text.AlignVCenter
                            }

                            onCheckedChanged: {
                                console.log("📹 [FIX 100.252] Video codec", modelData, checked ? "enabled" : "disabled")
                                SipPhoneManager.setVideoCodecEnabled(modelData, checked)
                            }
                        }
                    }
                }
            }

            // Ringtone settings section (铃声设置)
            Text {
                text: "铃声设置"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                Layout.topMargin: 20
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: ringtoneSettingsLayout.implicitHeight + 40
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ColumnLayout {
                    id: ringtoneSettingsLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    // Current ringtone display
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "当前铃声"
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 45
                            color: "#0a1f3a"
                            radius: 8
                            border.color: "#00d4ff"
                            border.width: 1

                            Text {
                                id: ringtoneDisplay
                                anchors.centerIn: parent
                                text: SipPhoneManager.getRingtoneFilename()
                                font.pixelSize: 14
                                color: "#00d4ff"
                            }

                            // ✅ 监听铃声路径变化并更新显示
                            Connections {
                                target: SipPhoneManager
                                function onRingtonePathChanged(newPath) {
                                    console.log("🔔 [Settings] Ringtone changed, updating display")
                                    ringtoneDisplay.text = SipPhoneManager.getRingtoneFilename()
                                }
                            }
                        }
                    }

                    // Select ringtone button
                    RisipButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        text: "选择自定义铃声"
                        buttonColor: "#27ae60"
                        hoverColor: "#2ecc71"
                        font.pixelSize: 14
                        font.bold: true

                        onClicked: {
                            console.log("🔔 [UI] Opening ringtone file dialog...")
                            var success = SipPhoneManager.selectAndSetRingtone()
                            if (success) {
                                console.log("✅ [UI] Custom ringtone set successfully")
                            } else {
                                console.log("⚠️ [UI] Failed to set custom ringtone or cancelled")
                            }
                        }
                    }

                    // Info text
                    Text {
                        text: "支持的格式: WAV, MP3, OGG, M4A\n选择后将自动复制到应用程序目录"
                        font.pixelSize: 11
                        color: "#95a5a6"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Add Account Button
            RisipButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                text: "+ 添加新账户"
                buttonColor: "#27ae60"
                hoverColor: "#2ecc71"
                pressColor: "#229954"
                font.pixelSize: 16
                font.bold: true

                onClicked: {
                    addAccountDialog.open()
                }
            }

            // About section
            Text {
                text: "关于"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                Layout.topMargin: 20
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: aboutLayout.implicitHeight + 40
                color: "#0f3460"
                radius: 10
                border.color: "#00d4ff"
                border.width: 1

                ColumnLayout {
                    id: aboutLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Text {
                        text: "皮带控制系统 - SIP 电话模块"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: "版本: 1.0.0"
                        font.pixelSize: 12
                        color: "#95a5a6"
                    }

                    Text {
                        text: "基于 PJSIP 协议实现"
                        font.pixelSize: 12
                        color: "#95a5a6"
                    }

                    Text {
                        text: "支持语音通话、联系人管理、通话记录等功能"
                        font.pixelSize: 12
                        color: "#95a5a6"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.minimumHeight: 20
            }
        }
    }

    // ✅ Click on empty area (outside input fields) to close keyboard
    // IMPORTANT: Must be AFTER mainFlickable to be on top of it
    MouseArea {
        id: keyboardCloseArea
        anchors.fill: parent
        anchors.margins: 20  // Same as mainFlickable margins
        z: 10  // ✅ VERY HIGH Z - above Flickable (z: 0)
        enabled: Qt.inputMethod.visible && !addAccountDialog.opened
        propagateComposedEvents: true
        preventStealing: true  // ✅ CRITICAL: Prevent Flickable from stealing mouse events

        onPressed: function(mouse) {
            // Detect clicked element type
            var clickedItem = mainFlickable.contentItem.childAt(
                mouse.x,
                mouse.y + mainFlickable.contentY
            )

            if (clickedItem) {
                var itemType = clickedItem.toString()

                // If clicked on input field, keep keyboard open and propagate event
                if (itemType.indexOf("TextField") !== -1 ||
                    itemType.indexOf("TextInput") !== -1 ||
                    itemType.indexOf("SpinBox") !== -1 ||
                    itemType.indexOf("ComboBox") !== -1 ||
                    itemType.indexOf("LineEdit") !== -1) {
                    mouse.accepted = false  // Let input field handle it
                    return
                }
            }

            // Clicked outside input field - close keyboard
            Qt.inputMethod.commit()
            Qt.inputMethod.hide()
            mouse.accepted = true  // Don't propagate - we handled it
        }
    }

    // Add Account Dialog
    Dialog {
        id: addAccountDialog
        // ✅ Keep default parent - Dialog automatically uses Overlay.overlay
        modal: false  // ✅ 必须 false，否则会阻挡所有事件
        closePolicy: Popup.CloseOnEscape  // Allow Escape key to close
        dim: false  // ✅ CRITICAL: No dim overlay!
        // ✅ Position in upper portion - fixed at 30px from top
        x: (parent.width - width) / 2
        y: 30
        width: Math.min(500, parent.width * 0.9)
        height: 550  // ✅ Fixed height - no dynamic adjustment

        // Match SIP settings page theme
        background: Rectangle {
            color: "#1a1a2e"
            radius: 15
            border.color: "#00d4ff"
            border.width: 2

            // ✅ 调试: 监听 Dialog background 的点击
            MouseArea {
                anchors.fill: parent
                z: -999  // 最底层
                propagateComposedEvents: true

                Component.onCompleted: {
                    console.log("📋 [Dialog Background MouseArea] Initialized")
                }

                onPressed: function(mouse) {
                    console.log("📋📋📋 [Dialog Background] 👇 PRESSED at:", mouse.x, mouse.y)
                    mouse.accepted = false  // 传播到上层
                }

                onClicked: function(mouse) {
                    console.log("📋📋📋 [Dialog Background] 🖱️ CLICKED at:", mouse.x, mouse.y)
                    mouse.accepted = false  // 传播到上层
                }
            }
        }

        // ✅ Reduced header height from 60px to 40px
        header: Rectangle {
            height: 40
            color: "#16213e"
            radius: 15

            Text {
                anchors.centerIn: parent
                text: "添加 SIP 账户"
                font.pixelSize: 16  // Reduced from 18
                font.bold: true
                color: "#00d4ff"
            }

            // ✅ MouseArea to close keyboard when clicking header
            MouseArea {
                anchors.fill: parent
                enabled: true

                Component.onCompleted: {
                    console.log("🖱️ [Dialog Header MouseArea] Initialized")
                    console.log("   - Size:", width, "x", height)
                    console.log("   - Enabled:", enabled)
                }

                onPressed: function(mouse) {
                    console.log("🖱️ [Dialog Header MouseArea] 👇 PRESSED")
                }

                onClicked: {
                    console.log("🖱️ [Dialog Header] CLICKED - closing keyboard")
                    // Remove focus from TextField first
                    addAccountDialog.forceActiveFocus()
                    // Then close keyboard
                    Qt.inputMethod.commit()
                    Qt.inputMethod.hide()
                    console.log("   - Keyboard closed")
                }
            }
        }

        Component.onCompleted: {
            console.log("[AddAccountDialog] Dialog created")
        }

        onOpened: {
            console.log("==========================================")
            console.log("🔥🔥🔥 DIALOG VERSION: 2025-12-19-08:00 CLEAN 🔥🔥🔥")
            console.log("[AddAccountDialog] ✅ Dialog OPENED")
            console.log("[AddAccountDialog] Dialog modal:", modal)
            console.log("[AddAccountDialog] Dialog visible:", visible)
            console.log("[AddAccountDialog] Dialog z:", z)
            console.log("[AddAccountDialog] mainFlickable.enabled should be false:", mainFlickable.enabled)
            console.log("[AddAccountDialog] Keyboard visible:", Qt.inputMethod.visible)
            console.log("==========================================")

            // ✅ CRITICAL: Stop all mainFlickable animations and dragging
            mainFlickable.cancelFlick()  // Cancel any ongoing flick animation
            mainFlickable.returnToBounds()  // Stop any dragging
            console.log("[AddAccountDialog] Stopped mainFlickable animations")
        }

        onClosed: {
            console.log("==========================================")
            console.log("[AddAccountDialog] ❌ Dialog CLOSED")
            console.log("[AddAccountDialog] mainFlickable.enabled should be true:", mainFlickable.enabled)
            console.log("[AddAccountDialog] Keyboard visible:", Qt.inputMethod.visible)
            console.log("==========================================")
        }

        onAccepted: {
            console.log("Creating new account...")
            var success = SipPhoneManager.createAccount(
                usernameField.text,
                passwordField.text,
                serverField.text,
                proxyField.text,
                parseInt(portField.text) || 5060,
                networkTypeCombo.currentIndex
            )

            if (success) {
                console.log("Account created successfully")
                // Clear fields
                usernameField.text = ""
                passwordField.text = ""
                serverField.text = ""
                proxyField.text = ""
                portField.text = "5060"
                networkTypeCombo.currentIndex = 0
            } else {
                console.log("Failed to create account")
            }
        }

        onRejected: {
            // Clear fields on cancel
            usernameField.text = ""
            passwordField.text = ""
            serverField.text = ""
            proxyField.text = ""
            portField.text = "5060"
            networkTypeCombo.currentIndex = 0
        }

        contentItem: Item {
            // ✅ CRITICAL: 使用 Item 作为容器，让 Flickable 和 MouseArea 处于同一层级
            Flickable {
                id: dialogFlickable
                anchors.fill: parent
                clip: true
                contentHeight: dialogContent.implicitHeight
                interactive: contentHeight > height && !Qt.inputMethod.visible  // ✅ CRITICAL: Disable when keyboard is visible!
                z: 0  // ✅ 基础层

            Component.onCompleted: {
                console.log("📜 [dialogFlickable] Initialized")
                console.log("   - Size:", width, "x", height)
                console.log("   - contentHeight:", contentHeight)
                console.log("   - interactive:", interactive)
            }

            // Smooth scroll animation
            NumberAnimation {
                id: dialogScrollAnimation
                target: dialogFlickable
                property: "contentY"
                duration: 300
                easing.type: Easing.OutQuad
            }

            // Timer to delay ensureVisible call until keyboard is fully shown
            Timer {
                id: ensureVisibleTimer
                interval: 150  // Wait 150ms for keyboard to fully appear
                repeat: false
                property var targetItem: null

                onTriggered: {
                    if (targetItem) {
                        console.log("[Dialog Timer] Calling ensureVisible for:", targetItem)
                        dialogFlickable.ensureVisible(targetItem)
                        targetItem = null
                    }
                }
            }

            // Monitor keyboard visibility to auto-scroll to focused input
            Connections {
                target: Qt.inputMethod
                function onVisibleChanged() {
                    console.log("🎹 [Dialog Keyboard Monitor] Keyboard visibility changed:", Qt.inputMethod.visible)
                    if (!Qt.inputMethod.visible) {
                        // Keyboard hidden - scroll to top
                        console.log("[Dialog Flickable] Keyboard hidden - scrolling to top")
                        dialogScrollAnimation.to = 0
                        dialogScrollAnimation.start()
                    } else {
                        console.log("🎹 [Dialog Keyboard Monitor] Keyboard shown - height:", Qt.inputMethod.keyboardRectangle.height)
                    }
                }
            }

            // Function to ensure input field is visible when keyboard shows
            function ensureVisible(item) {
                if (!item || !Qt.inputMethod.visible) return

                // Get input field position in Flickable
                var itemY = item.mapToItem(dialogFlickable.contentItem, 0, 0).y
                var itemHeight = item.height

                // Calculate keyboard coverage
                var keyboardHeight = Qt.inputMethod.keyboardRectangle.height
                var windowHeight = addAccountDialog.parent.height
                var dialogY = addAccountDialog.y
                var dialogHeight = addAccountDialog.height

                // Calculate the part of dialog that's visible above keyboard
                var keyboardY = windowHeight - keyboardHeight
                var dialogBottom = dialogY + dialogHeight
                var visibleDialogHeight = 0

                if (dialogBottom > keyboardY) {
                    // Dialog is partially covered by keyboard
                    visibleDialogHeight = keyboardY - dialogY
                } else {
                    // Dialog is fully above keyboard
                    visibleDialogHeight = dialogHeight
                }

                // Subtract header and footer heights
                var headerHeight = 40
                var footerHeight = 60
                var availableHeight = visibleDialogHeight - headerHeight - footerHeight

                console.log("[Dialog Flickable] ensureVisible - itemY:", itemY, "itemHeight:", itemHeight)
                console.log("[Dialog Flickable] Keyboard:", keyboardHeight, "DialogY:", dialogY, "VisibleHeight:", availableHeight)

                // Check if input is visible in the available area
                var itemBottom = itemY + itemHeight
                var margin = 20

                // If input bottom is below available area, scroll down to make it visible
                if (itemBottom > contentY + availableHeight - margin) {
                    var targetY = itemBottom - availableHeight + margin
                    // ✅ Use contentHeight - availableHeight as maxScroll
                    // This allows scrolling even when contentHeight < flickable.height
                    var maxScroll = Math.max(0, contentHeight - availableHeight)
                    console.log("[Dialog Flickable] Input below visible area, scrolling to:", targetY)
                    console.log("[Dialog Flickable] contentHeight:", contentHeight, "availableHeight:", availableHeight, "maxScroll:", maxScroll)
                    console.log("[Dialog Flickable] Final scroll target:", Math.max(0, Math.min(targetY, maxScroll)))
                    dialogScrollAnimation.to = Math.max(0, Math.min(targetY, maxScroll))
                    dialogScrollAnimation.start()
                }
                // If input top is above visible area, scroll up
                else if (itemY < contentY + margin) {
                    var targetY = Math.max(0, itemY - margin)
                    console.log("[Dialog Flickable] Input above visible area, scrolling to:", targetY)
                    dialogScrollAnimation.to = targetY
                    dialogScrollAnimation.start()
                } else {
                    console.log("[Dialog Flickable] Input already visible, no scroll needed")
                }
            }

            // ✅ MouseArea to detect clicks on blank space (NOT on keyboard!)
            MouseArea {
                anchors.fill: parent
                z: 1  // ✅ CRITICAL FIX: Above Flickable (z:0) to catch clicks BEFORE Flickable intercepts them!
                enabled: true
                propagateComposedEvents: true  // ✅ CRITICAL: Still propagate to TextField for input

                Component.onCompleted: {
                    console.log("🖱️ [Dialog Content MouseArea] Initialized - z:", z)
                }

                onPressed: function(mouse) {
                    console.log("🖱️🖱️🖱️ [Dialog Content MouseArea] 👇 PRESSED at:", mouse.x, mouse.y)
                    console.log("   - mouse.accepted BEFORE:", mouse.accepted)
                    mouse.accepted = false  // 传播给子元素
                    console.log("   - mouse.accepted AFTER:", mouse.accepted)
                }

                onClicked: function(mouse) {
                    console.log("🖱️🖱️🖱️ [Dialog Content MouseArea] 🖱️ CLICKED at:", mouse.x, mouse.y)
                    console.log("   - mouse.accepted:", mouse.accepted)
                    console.log("   - Keyboard visible:", Qt.inputMethod.visible)

                    // Only close keyboard if click wasn't handled by child (TextField, Button, etc)
                    if (!mouse.accepted && Qt.inputMethod.visible) {
                        console.log("   ✅ Closing keyboard - click not handled by child")
                        addAccountDialog.forceActiveFocus()  // Remove focus from TextField
                        Qt.inputMethod.commit()
                        Qt.inputMethod.hide()
                    } else {
                        console.log("   ⚠️ NOT closing keyboard - click handled by child or keyboard not visible")
                    }
                }
            }

            ColumnLayout {
                id: dialogContent
                width: parent.width
                spacing: 15

                Text {
                    text: "输入账户信息"
                    font.pixelSize: 14
                    color: "#00d4ff"
                    Layout.fillWidth: true
                }

                RisipLineEdit {
                    id: usernameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    placeholderText: "用户名 (例如: 1000)"
                    inputMethodHints: Qt.ImhDigitsOnly

                    Component.onCompleted: {
                        console.log("📝 [usernameField] Initialized - z:", z)
                    }

                    onActiveFocusChanged: {
                        console.log("📝 [usernameField] 🎯 Focus changed:", activeFocus)
                        console.log("   - Keyboard visible:", Qt.inputMethod.visible)
                        if (activeFocus) {
                            console.log("   - Got focus, scheduling ensureVisible")
                            ensureVisibleTimer.targetItem = usernameField
                            ensureVisibleTimer.restart()
                        } else {
                            console.log("   - Lost focus")
                        }
                    }

                    // ✅ 调试: 添加 MouseArea 监听点击事件
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        propagateComposedEvents: true

                        onPressed: function(mouse) {
                            console.log("📝📝📝 [usernameField MouseArea] 👇 PRESSED at:", mouse.x, mouse.y)
                            console.log("   - Propagating to TextField")
                            mouse.accepted = false
                        }

                        onClicked: function(mouse) {
                            console.log("📝📝📝 [usernameField MouseArea] 🖱️ CLICKED at:", mouse.x, mouse.y)
                            console.log("   - TextField should receive focus")
                            mouse.accepted = false
                        }
                    }
                }

                RisipLineEdit {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    placeholderText: "密码"
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhDigitsOnly

                    Component.onCompleted: {
                        console.log("📝 [passwordField] Initialized - z:", z)
                    }

                    onActiveFocusChanged: {
                        console.log("📝 [passwordField] 🎯 Focus changed:", activeFocus)
                        console.log("   - Keyboard visible:", Qt.inputMethod.visible)
                        if (activeFocus) {
                            console.log("   - Got focus, scheduling ensureVisible")
                            ensureVisibleTimer.targetItem = passwordField
                            ensureVisibleTimer.restart()
                        } else {
                            console.log("   - Lost focus")
                        }
                    }

                    // ✅ REMOVED MouseArea - TextField handles clicks itself
                    // The MouseArea was causing events to propagate and close keyboard
                }

                RisipLineEdit {
                    id: serverField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    placeholderText: "SIP 服务器地址 (例如: 192.168.1.100)"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            console.log("[serverField] Got focus, scheduling ensureVisible")
                            ensureVisibleTimer.targetItem = serverField
                            ensureVisibleTimer.restart()
                        }
                    }
                }

                RisipLineEdit {
                    id: proxyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    placeholderText: "代理服务器 (可选)"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            console.log("[proxyField] Got focus, scheduling ensureVisible")
                            ensureVisibleTimer.targetItem = proxyField
                            ensureVisibleTimer.restart()
                        }
                    }
                }

                ComboBox {
                    id: networkTypeCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    model: ["UDP", "TCP", "TLS"]
                    currentIndex: 0

                    background: Rectangle {
                        color: "#0f3460"
                        radius: 10
                        border.color: networkTypeCombo.activeFocus ? "#00ff88" : "#00d4ff"
                        border.width: 2
                    }

                    contentItem: Text {
                        text: networkTypeCombo.displayText
                        color: "#ffffff"
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                    }
                }

                RisipLineEdit {
                    id: portField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    placeholderText: "本地端口 (默认: 5060)"
                    text: "5060"
                    inputMethodHints: Qt.ImhDigitsOnly

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            console.log("[portField] Got focus, scheduling ensureVisible")
                            ensureVisibleTimer.targetItem = portField
                            ensureVisibleTimer.restart()
                        }
                    }
                }
            }  // ColumnLayout
            }  // Flickable

            // ✅ 简化：只保留一个覆盖层用于关闭键盘
            Item {
                anchors.fill: parent
                z: 100
                visible: true
                enabled: Qt.inputMethod.visible

                Component.onCompleted: {
                    console.log("🔥 [Keyboard Overlay] Created in contentItem")
                }

                onEnabledChanged: {
                    console.log("🔥 [Keyboard Overlay] Enabled changed:", enabled)
                }

                MouseArea {
                    anchors.fill: parent
                    z: 200
                    enabled: true
                    hoverEnabled: true
                    propagateComposedEvents: true

                    Component.onCompleted: {
                        console.log("🔥 [Keyboard Close MouseArea] Created")
                        console.log("   - Size:", width, "x", height)
                        console.log("   - z:", z)
                    }

                    onPressed: function(mouse) {
                        console.log("🔥🔥🔥 [Keyboard Close] PRESSED at:", mouse.x, mouse.y)
                        mouse.accepted = false
                    }

                    onClicked: function(mouse) {
                        console.log("🔥🔥🔥 [Keyboard Close] CLICKED at:", mouse.x, mouse.y)
                        var keyboardTop = parent.height - Qt.inputMethod.keyboardRectangle.height
                        if (mouse.y < keyboardTop) {
                            console.log("   ✅ Closing keyboard!")
                            Qt.inputMethod.hide()
                            mouse.accepted = true
                        } else {
                            mouse.accepted = false
                        }
                    }
                }

                // 可视化调试边框
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "cyan"
                    border.width: 3
                    z: -1
                    enabled: false
                }
            }  // Item (Keyboard Overlay)
        }  // Item (contentItem)

        footer: DialogButtonBox {
            background: Rectangle {
                color: "#16213e"
                border.color: "#00d4ff"
                border.width: 1
            }

            Button {
                text: "取消"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                implicitHeight: 45
                property bool isHovered: false

                background: Rectangle {
                    color: parent.pressed ? "#c0392b" : (parent.isHovered ? "#e74c3c" : "#7f8c8d")
                    radius: 8
                    border.color: "#bdc3c7"
                    border.width: 2

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 15
                    font.bold: true
                }

                HoverHandler {
                    onHoveredChanged: parent.isHovered = hovered
                }
            }

            Button {
                text: "保存"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                implicitHeight: 45
                property bool isHovered: false

                background: Rectangle {
                    color: parent.pressed ? "#1e8449" : (parent.isHovered ? "#2ecc71" : "#27ae60")
                    radius: 8
                    border.color: "#00ff88"
                    border.width: 2

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 15
                    font.bold: true
                }

                HoverHandler {
                    onHoveredChanged: parent.isHovered = hovered
                }
            }
        }
    }
}
