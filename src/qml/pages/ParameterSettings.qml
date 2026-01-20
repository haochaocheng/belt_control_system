import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import "../components/common"
import "../components/parameter_settings"
import "../components/control_panel"

Item {
    id: root
    // ✅ 2026-01-20 [FIX 100.273]: 添加默认尺寸，方便可视化设计
    // 实际运行时，SwipeView 会自动覆盖这些值，不影响运行
    width: 1920   // 默认宽度（设计尺寸 1920x1080）
    height: 1080  // 默认高度（设计尺寸 1920x1080）

    // 监听设备状态改变信号
    Connections {
        target: commonControl
        function onDeviceStatusChanged(deviceName, isRunning) {
            console.log("🔗 ParameterSettings: 收到设备状态改变信号 -", deviceName, isRunning ? "运行" : "停止")
            outputDevicePanel.setDeviceStatus(deviceName, isRunning)
        }
    }

    // 初始化时同步设备反馈配置到 CommonControl
    Component.onCompleted: {
        syncDeviceFeedbackConfigs()
    }

    // 同步所有设备的反馈配置
    function syncDeviceFeedbackConfigs() {
        if (!commonControl) {
            console.warn("⚠️ ParameterSettings: commonControl 未初始化")
            return
        }

        var devices = outputDevicePanel.getAllDevices()
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            commonControl.setDeviceFeedbackConfig(
                device.name,
                device.useFeedback,
                device.feedbackChannel,
                device.feedbackDelay
            )
        }
        console.log("✅ ParameterSettings: 已同步", devices.length, "个设备的反馈配置")
    }

    // Background
    Rectangle {
        anchors.fill: parent
        color: "#0a1628"
    }

    // Header
    Header {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // Main content area - Flickable to support keyboard auto-scroll
    Flickable {
        id: mainFlickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10

        contentWidth: width
        contentHeight: Math.max(height, mainContentColumn.implicitHeight + 20)
        clip: true

        // Enable keyboard auto-scroll
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        property real scrollMarginVertical: 50

        // Monitor keyboard visibility (不再自动滚回顶部)
        Connections {
            target: Qt.inputMethod
            function onVisibleChanged() {
                // 键盘隐藏时不做任何操作，保持当前滚动位置
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
            // Scroll up if item is below visible area
            if (yPos + itemHeight + scrollMarginVertical > contentY + visibleAreaHeight) {
                targetY = yPos + itemHeight + scrollMarginVertical - visibleAreaHeight
            }
            // Scroll down if item is above visible area
            else if (yPos - scrollMarginVertical < contentY) {
                targetY = Math.max(0, yPos - scrollMarginVertical)
            } else {
                return // Already visible, no need to scroll
            }

            // Animate scroll
            scrollAnimation.to = targetY
            scrollAnimation.start()
        }

        ColumnLayout {
            id: mainContentColumn
            width: parent.width
            spacing: 8

                // Title
                Text {
                    text: "参数设置"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#00d4ff"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 2
                    color: "#00d4ff"
                    opacity: 0.5
                }

            // Main content layout - 3x2 grid using Item containers
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 920

                // Left Column Container
                Item {
                    id: leftColumn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (parent.width - 15) / 2  // 减去间距后平分

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Row 1 Left - Basic Parameters
                        BasicParametersSection {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            dateTimePopup: dateTimePopup
                        }

                        // Row 2 Left - Master Control Settings
                        MasterControlSection {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            flickableParent: mainFlickable
                        }

                        // Row 3 Left - Network Settings (Modbus TCP)
                        NetworkSettingsSection {
                            id: networkSettingsSection
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                        }
                    }
                }

                // Right Column Container
                Item {
                    id: rightColumn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (parent.width - 15) / 2  // 减去间距后平分

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Row 1 Right - Network Parameters
                        NetworkParametersSection {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                        }

                        // Row 2 Right - Device Startup Sequence List
                        DeviceSequenceSection {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                        }

                        // Row 3 Right - Output Device Settings
                        OutputDevicePanel {
                            id: outputDevicePanel
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300

                            onDeviceClicked: function(deviceName, sourceItem) {
                                console.log("Device clicked:", deviceName)
                                // 获取设备的所有反馈参数
                                var channel = outputDevicePanel.getDeviceChannel(deviceName)
                                var feedbackChannel = outputDevicePanel.getDeviceFeedbackChannel(deviceName)
                                var useFeedback = outputDevicePanel.getDeviceUseFeedback(deviceName)
                                var feedbackDelay = outputDevicePanel.getDeviceFeedbackDelay(deviceName)
                                deviceSettingsPopup.openForDevice(deviceName, sourceItem, channel, feedbackChannel, useFeedback, feedbackDelay)
                            }

                            onAddDeviceClicked: function(sourceItem) {
                                console.log("Add device clicked")
                                deviceSettingsPopup.openForNew(sourceItem)
                            }
                        }
                    }
                }
            }

            // Bottom buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 55
                spacing: 20

                Item { Layout.fillWidth: true }

                Button {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#00ff88")
                        radius: 8
                        border.color: "#00d4ff"
                        border.width: 2
                    }

                    contentItem: Text {
                        text: "保存设置"
                        color: "#0a1628"
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (systemConfig) {
                            systemConfig.saveConfig()
                            console.log("设置已保存")
                        }
                    }
                }

                Button {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#ff4757")
                        radius: 8
                        border.color: "#00d4ff"
                        border.width: 2
                    }

                    contentItem: Text {
                        text: "恢复默认"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (systemConfig) {
                            systemConfig.resetToDefaults()
                            console.log("设置已恢复为默认值")
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // DateTime Picker Popup
    DateTimePickerPopup {
        id: dateTimePopup
    }

    // Output Device Settings Popup
    OutputDeviceSettingsPopup {
        id: deviceSettingsPopup

        onAccepted: {
            if (deviceSettingsPopup.isNewDevice) {
                outputDevicePanel.addDevice(deviceSettingsPopup.deviceName)
                console.log("新增设备:", deviceSettingsPopup.deviceName,
                           "[输出:", deviceSettingsPopup.outputModule,
                           "通道:", deviceSettingsPopup.channelNumber, "]")
            } else {
                console.log("修改设备参数:", deviceSettingsPopup.deviceName,
                           "[输出:", deviceSettingsPopup.outputModule,
                           "通道:", deviceSettingsPopup.channelNumber,
                           "继电器:", deviceSettingsPopup.relayType, "]")
            }

            // 同步反馈配置到 CommonControl
            if (commonControl) {
                commonControl.setDeviceFeedbackConfig(
                    deviceSettingsPopup.deviceName,
                    deviceSettingsPopup.useFeedback,
                    deviceSettingsPopup.feedbackChannel,
                    deviceSettingsPopup.feedbackDelay
                )
            }
        }

        onRejected: {
            console.log("取消操作")
        }

        onDeleteRequested: {
            outputDevicePanel.removeDevice(deviceSettingsPopup.deviceName)
            console.log("删除设备:", deviceSettingsPopup.deviceName)
        }
    }

    // ✅ Click on empty area (outside input fields) to close keyboard
    // IMPORTANT: Must be AFTER mainFlickable to be on top of it
    MouseArea {
        id: keyboardCloseArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10
        z: 10  // ✅ VERY HIGH Z - above Flickable (z: 0)
        enabled: Qt.inputMethod.visible
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
                    itemType.indexOf("ComboBox") !== -1) {
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
}
