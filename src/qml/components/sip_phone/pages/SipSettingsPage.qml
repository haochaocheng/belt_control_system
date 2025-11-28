import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// Settings page for SIP account registration
Page {
    id: root

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
        onActiveFocusChanged: {
            if (activeFocus) {
                mainFlickable.ensureVisible(control)
            }
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    // Click anywhere to dismiss keyboard
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.forceActiveFocus()  // Remove focus from any TextField
            Qt.inputMethod.hide()
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        contentWidth: width
        contentHeight: mainContent.implicitHeight + 40

        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        property real scrollMarginVertical: 50

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

            // SIP server settings
            Text {
                text: "SIP 服务器配置"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
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
                    text: "注册账号"
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

                        var port = parseInt(portInput.text) || 5060
                        SipPhoneManager.registerAccount(
                            serverInput.text,
                            usernameInput.text,
                            passwordInput.text,
                            port
                        )
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
}
