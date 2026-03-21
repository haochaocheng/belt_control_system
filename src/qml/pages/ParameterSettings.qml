import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import "../components/common"
import "../components/parameter_settings"
import "../components/control_panel"
import "../Input1/Input1Content"  // ✅ 2026-01-20 [FIX 100.255]

Item {
    id: root
    // ✅ 2026-02-11 [Phase 7.45.25]: 移除固定尺寸，避免与SwipeView冲突导致polish()循环
    // width: 1920   // ❌ 注释掉，SwipeView会自动管理尺寸
    // height: 1080  // ❌ 注释掉，SwipeView会自动管理尺寸
    // ✅ SwipeView 子页由 SwipeView 自动管理几何，不要在根节点设置 anchors

    // ✅ 2026-01-20 [FIX 100.255]
    property int currentPageIndex: 0

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
    // ✅ 2026-03-21 [Phase 7.48.65]: 从数据库加载张紧/制动器/电机的反馈通道和延时
    // 原因：OutputDevicePanel.qml 的 ListElement 硬编码值（channel=0-15, delay=3）与
    //       device_tension_config / device_brake_config / device_motor_config 数据库表中
    //       用户配置的反馈通道不一致，统一改为从DB读取
    function syncDeviceFeedbackConfigs() {
        if (!commonControl) {
            console.warn("⚠️ ParameterSettings: commonControl 未初始化")
            return
        }

        var deviceId = 1  // 主设备ID（当前系统固定为1）
        var devices = outputDevicePanel.getAllDevices()
        var dbLoaded = 0

        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            var name = device.name
            var useFeedback = device.useFeedback
            var feedbackChannel = device.feedbackChannel
            var feedbackDelay = device.feedbackDelay

            // ——— 张紧控制 ———
            if (name === "张紧控制" || name === "张紧") {
                if (typeof deviceConfigMgr !== "undefined" && deviceConfigMgr !== null) {
                    var tensionCfg = deviceConfigMgr.loadTensionConfig(deviceId, 0)
                    if (tensionCfg && tensionCfg["feedback_channel"] !== undefined) {
                        useFeedback    = (tensionCfg["use_feedback"] === 1 || tensionCfg["use_feedback"] === true)
                        feedbackChannel = tensionCfg["feedback_channel"]
                        feedbackDelay   = tensionCfg["feedback_timeout"] || 10
                        dbLoaded++
                        console.log("📋 ParameterSettings: 张紧反馈参数来自DB - 通道:", feedbackChannel, "延时:", feedbackDelay)
                    }
                }
            }
            // ——— N号制动器 ———
            else if (name.indexOf("制动器") >= 0) {
                if (typeof deviceConfigMgr !== "undefined" && deviceConfigMgr !== null) {
                    var brakeNumMatch = name.match(/(\d+)/)
                    var brakeIdx = brakeNumMatch ? parseInt(brakeNumMatch[1]) - 1 : 0
                    var brakeCfg = deviceConfigMgr.loadBrakeConfig(deviceId, brakeIdx)
                    if (brakeCfg && brakeCfg["release_feedback_channel"] !== undefined) {
                        useFeedback    = (brakeCfg["use_release_feedback"] === 1 || brakeCfg["use_release_feedback"] === true)
                        feedbackChannel = brakeCfg["release_feedback_channel"]
                        feedbackDelay   = brakeCfg["release_feedback_timeout"] || 10
                        dbLoaded++
                        console.log("📋 ParameterSettings:", name, "反馈参数来自DB - 通道:", feedbackChannel, "延时:", feedbackDelay)
                    }
                }
            }
            // ——— N号电机 ———
            else if (name.indexOf("电机") >= 0) {
                if (typeof deviceConfigMgr !== "undefined" && deviceConfigMgr !== null) {
                    var motorNumMatch = name.match(/(\d+)/)
                    var motorIdx = motorNumMatch ? parseInt(motorNumMatch[1]) - 1 : 0
                    var motorCfg = deviceConfigMgr.loadMotorConfig(deviceId, motorIdx, 0)
                    if (motorCfg && motorCfg["feedback_channel"] !== undefined && motorCfg["feedback_channel"] >= 0) {
                        // motor_config 只有 feedback_channel（无 use_feedback / feedback_timeout）
                        useFeedback    = true
                        feedbackChannel = motorCfg["feedback_channel"]
                        // feedbackDelay 沿用 OutputDevicePanel 默认值（3秒）
                        dbLoaded++
                        console.log("📋 ParameterSettings:", name, "反馈通道来自DB - 通道:", feedbackChannel)
                    }
                }
            }
            // 其余设备（洒水、破碎机等）保留 OutputDevicePanel 硬编码默认值

            commonControl.setDeviceFeedbackConfig(name, useFeedback, feedbackChannel, feedbackDelay)
        }
        console.log("✅ ParameterSettings: 已同步", devices.length, "个设备的反馈配置（其中", dbLoaded, "个来自DB）")
    }

    // ✅ 2026-01-20 [FIX 100.271]: 使用 Back 组件作为背景（与模块状态页面一致）
    // ✅ 2026-01-20 [FIX 100.272]: 禁用鼠标交互，避免拦截 MouseArea 事件
    Back {
        anchors.fill: parent
        z: 0  // 确保在最底层
        enabled: false  // ✅ 不接收鼠标事件，只作为视觉背景
    }

    // 2026-01-20: 注释掉 Rectangle 纯色背景，改用 Back 组件
    // Rectangle {
    //     anchors.fill: parent
    //     color: "#000a1628"
    // }

    // ✅ 2026-01-20 [FIX 100.268] 修复高度缩放问题
    // 问题：anchors.right 覆盖了 Scale transform 的 yScale 效果
    // 解决：移除 anchors，使用固定尺寸，让 Scale 完全控制缩放
    Item {
        id: headerContainer
        anchors.top: parent.top
        anchors.left: parent.left
        width: 1920
        height: 80
        clip: true

        transform: Scale {
            property real scaleFactor: root.width / 1920  // 0.667（1280屏）
            xScale: scaleFactor
            yScale: scaleFactor  // ✅ 等比缩放（高度也使用相同比例）
            origin.x: 0
            origin.y: 0
        }

        Head {
            id: header
            // ✅ 2026-01-20 [FIX 100.268]: 移除 anchors，使用固定尺寸
            width: 1920  // ✅ 固定宽度（不使用 anchors.right）
            height: 80
            currentPageIndex: root.currentPageIndex
        }
    }

    // Main content area - Flickable to support keyboard auto-scroll
    Flickable {
        id: mainFlickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerContainer.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 0
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 8  // ✅ 2026-01-20 [FIX 100.271]: 从 -50 改为 10，避免遮住 Head 底部
        anchors.bottomMargin: 0
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

        // ✅ 2026-01-28 [FIX 100.300.64]: 修复 Anchor 错误
        // 原因：ColumnLayout 在 mainFlickable 内部，不能 anchor 到外部的 headerContainer
        // 解决：anchor 到 parent.top（mainFlickable.contentItem.top）
        ColumnLayout {
            id: mainContentColumn
            x: 0
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 5
            spacing: 8

                // Title

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
        anchors.top: headerContainer.bottom  // FIX 100.300.61: 修复 anchor 目标
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

