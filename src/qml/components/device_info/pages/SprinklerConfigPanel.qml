import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-09 [洒水控制-右侧面板] 洒水配置面板
// ✅ 2026-03-18 [Phase 7.48.54]: 重构布局-单列排列(启用/名称/通道号)+删除MQTT主题+统一自定义组件
// 旧：GridLayout 4列布局，5个参数(名称/启用/模块类型/通道号/MQTT主题)，使用标准TextField/SpinBox
Rectangle {
    id: root
    color: "transparent"
    clip: true

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int sprinklerIndex: 0  // 0-7（对应洒水1-洒水8）
    property var keyboardManager: null
    property int focusSubArea: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property var virtualKeyboard: null
    // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中参数冻结
    property bool beltIsRunning: false

    // ========== 布局常量（参照TensionControlConfigPanel） ==========
    readonly property int lblFs: 21
    readonly property string lblC: "#9E9E9E"
    readonly property int lblW: 160

    // ========== 标题栏 ==========
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "#2a3142"
        border.color: "#3d4556"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "洒水" + (root.sprinklerIndex + 1) + " 配置"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    ColumnLayout {
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 15
        spacing: 12

        // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中参数冻结提示横幅
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.beltIsRunning ? 36 : 0
            visible: root.beltIsRunning
            color: "#80FF9800"
            radius: 4
            Text { anchors.centerIn: parent; text: "\u26A0 皮带运行中，参数修改已锁定"; font.pixelSize: 16; font.bold: true; color: "#FFFFFF" }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
        }

        // ✅ 2026-03-30 [Phase 7.48.88.69]: 全局通道冲突��示信息
        // ✅ 2026-03-30 [Phase 7.48.88.70]: 增加可用通道列表显示
        Rectangle {
            Layout.fillWidth: true
            // 旧代码：Layout.preferredHeight: root.channelConflictMessage !== "" ? 36 : 0
            Layout.preferredHeight: root.channelConflictMessage !== "" ? 56 : 0
            visible: root.channelConflictMessage !== ""
            color: "#80FF5722"
            radius: 4
            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.channelConflictMessage
                    font.pixelSize: 16; font.bold: true; color: "#FFCCBC"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.availableChannelsText
                    font.pixelSize: 12; color: "#4CAF50"
                    visible: root.availableChannelsText !== ""
                }
            }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
        }

        // ========== Row 0: 启用状态 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            // ✅ 2026-03-30 [Phase 7.48.88.73]: 统一启用开关标签
            // 旧：Text { text: "启用状态:"; ... }
            Text { text: "是否启用:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: enabledSwitch.implicitHeight
                // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结
                Switch { id: enabledSwitch; checked: true; anchors.verticalCenter: parent.verticalCenter; enabled: !root.beltIsRunning }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 0 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== Row 1: 洒水名称 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "洒水名称:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            DeviceInfo.CustomTextField {
                id: sprinklerNameField
                text: "洒水" + (root.sprinklerIndex + 1)
                Layout.fillWidth: true; Layout.maximumWidth: 300
                placeholderText: "洒水" + (root.sprinklerIndex + 1)
                keyboardManager: root.keyboardManager
                // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结
                enabled: !root.beltIsRunning
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 1 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== Row 2: 通道号 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "通道号:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            DeviceInfo.CustomSpinBox {
                id: channelSpin
                // ✅ 2026-03-24 [Phase 7.48.88.7]: 洒水1-5通道11-15，洒水6-8通道-1
                // ✅ 2026-03-30 [Phase 7.48.88.70]: 洒水1-4通道11-14，洒水5-8通道-1（只占用4个通道，剩余4个为未分配）
                // 旧代码：from: -1; to: 15; value: root.sprinklerIndex < 5 ? root.sprinklerIndex + 11 : -1
                from: -1; to: 15; value: root.sprinklerIndex < 4 ? root.sprinklerIndex + 11 : -1
                Layout.fillWidth: true; Layout.maximumWidth: 300
                keyboardManager: root.keyboardManager
                // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结
                enabled: !root.beltIsRunning
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 2 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ✅ 2026-03-22 [Phase 7.48.74]: 新增启动延时 + 停止延时
        // ========== Row 3: 启动延时(3) ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "启动延时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: startupDelaySpin.implicitHeight
                // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结
                DeviceInfo.CustomSpinBox { id: startupDelaySpin; from: 0; to: 60; value: 1; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager; enabled: !root.beltIsRunning }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 3 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== Row 4: 停止延时(4) ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "停止延时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: stopDelaySpin.implicitHeight
                // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结
                DeviceInfo.CustomSpinBox { id: stopDelaySpin; from: 0; to: 60; value: 1; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager; enabled: !root.beltIsRunning }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 4 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== 状态监控（统一电机样式） ==========
        // ✅ 2026-04-07 [Phase 7.48.88.78]: 新增状态监控区域（参照电机BasicConfigTab）
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 16

            Text { text: "状态监控:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }

            Item {
                id: sprinklerRunItem
                implicitWidth: sprinklerRunRow.implicitWidth; implicitHeight: 40
                property bool sprinklerIsOn: false

                // ✅ 数据源1：DO通道状态变化
                Connections {
                    target: channelSpin
                    function onValueChanged() {
                        if (typeof doDataManager !== "undefined" && channelSpin.value >= 0) {
                            sprinklerRunItem.sprinklerIsOn = doDataManager.getDoState(channelSpin.value)
                        }
                    }
                }

                // ✅ 数据源2：doDataManager 全局DO状态
                Connections {
                    target: typeof doDataManager !== "undefined" ? doDataManager : null
                    function onDoStatesChanged() {
                        if (channelSpin.value >= 0) {
                            sprinklerRunItem.sprinklerIsOn = doDataManager.getDoState(channelSpin.value)
                        }
                    }
                }

                // ✅ 数据源3：commonControl 全局设备状态信号
                Connections {
                    target: typeof commonControl !== "undefined" ? commonControl : null
                    function onDeviceStatusChanged(beltNumber, deviceName, isRunning) {
                        var match = deviceName.match(/(\d+)号洒水/)
                        if (!match) return
                        var sprinklerIdx = parseInt(match[1]) - 1
                        if (sprinklerIdx === root.sprinklerIndex) {
                            sprinklerRunItem.sprinklerIsOn = isRunning
                        }
                    }
                }

                Component.onCompleted: {
                    if (typeof doDataManager !== "undefined" && channelSpin.value >= 0) {
                        sprinklerRunItem.sprinklerIsOn = doDataManager.getDoState(channelSpin.value)
                    }
                }

                Row {
                    id: sprinklerRunRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        id: sprinklerRunLed
                        width: 24; height: 24; radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        property bool isOn: sprinklerRunItem.sprinklerIsOn
                        color: isOn ? "#22C55E" : "#1a1a2e"
                        border.color: isOn ? "#86EFAC" : "#475569"; border.width: 2
                        Rectangle { width: 10; height: 10; radius: 5; anchors.centerIn: parent; color: sprinklerRunLed.isOn ? "#bbf7d0" : "#334155"; opacity: sprinklerRunLed.isOn ? 0.8 : 0.3 }
                        Rectangle { visible: sprinklerRunLed.isOn; width: 32; height: 32; radius: 16; anchors.centerIn: parent; color: "#22C55E"; opacity: 0.2; z: -1 }
                    }

                    Text {
                        text: sprinklerRunLed.isOn ? "运行中" : "已停止"
                        font.pixelSize: 18
                        color: sprinklerRunLed.isOn ? "#22C55E" : "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ========== 分隔线 ==========
        // ✅ 2026-03-18 [Phase 7.48.55]: 手动控制区域
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#3d4556"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        // ========== Row 3: 手动启动/停止按钮 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "手动控制:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            RowLayout {
                spacing: 16
                // 启动按钮（绿色）
                Rectangle {
                    id: startBtn
                    width: 120; height: 40
                    radius: 6
                    color: startBtnMa.pressed ? "#2E7D32" : (startBtnMa.containsMouse ? "#43A047" : "#388E3C")
                    border.color: "#4CAF50"; border.width: 1
                    // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结启动按钮
                    opacity: root.beltIsRunning ? 0.5 : 1.0
                    Text { anchors.centerIn: parent; text: "启 动"; font.pixelSize: 16; font.weight: Font.Bold; color: "#FFFFFF" }
                    MouseArea {
                        id: startBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        // ✅ 2026-03-30 [Phase 7.48.88.72]: 皮带运行中冻结
                        enabled: !root.beltIsRunning
                        onClicked: root.sendSprinklerCommand(true)
                    }
                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 0 ? "#2196F3" : "transparent"; border.width: 3; radius: 6; z: 10 }
                }
                // 停止按钮（红色）
                Rectangle {
                    id: stopBtn
                    width: 120; height: 40
                    radius: 6
                    color: stopBtnMa.pressed ? "#C62828" : (stopBtnMa.containsMouse ? "#E53935" : "#D32F2F")
                    border.color: "#F44336"; border.width: 1
                    Text { anchors.centerIn: parent; text: "停 止"; font.pixelSize: 16; font.weight: Font.Bold; color: "#FFFFFF" }
                    MouseArea {
                        id: stopBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.sendSprinklerCommand(false)
                    }
                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 1 ? "#2196F3" : "transparent"; border.width: 3; radius: 6; z: 10 }
                }
            }
        }

        // ========== 弹性空间 ==========
        Item { Layout.fillHeight: true }
    }

    // ========== 函数 ==========
    // 旧：function getParamFieldCount() { return 3 }  // 参数索引 0-2
    // ✅ 2026-03-22 [Phase 7.48.74]: 新增启动延时+停止延时，参数数量3→5
    function getParamFieldCount() { return 5 }  // 参数索引 0-4

    // ✅ 2026-03-18 [Phase 7.48.55]: 手动洒水控制 - 发送MQTT命令
    function sendSprinklerCommand(activate) {
        if (typeof mqttController === "undefined" || !mqttController) {
            console.log("⚠️ [SprinklerConfigPanel] mqttController 未定义，无法发送洒水命令")
            return
        }

        var topic = "belt_control/relay/module1/control"
        var cmd = {
            "cmd": "write",
            "channel": channelSpin.value,
            "value": activate ? 1 : 0,
            "timestamp": Math.floor(Date.now() / 1000)
        }
        var message = JSON.stringify(cmd)

        var success = mqttController.publish(topic, message, 1, false)
        if (success) {
            console.log("✅ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) +
                        (activate ? " 启动" : " 停止") + "命令已发送 channel:" + channelSpin.value)
        } else {
            console.log("❌ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) +
                        " 命令发送失败")
        }
    }

    function loadSprinklerConfig() {
        if (typeof deviceConfigMgr === "undefined") {
            console.log("⚠️ [SprinklerConfigPanel] deviceConfigMgr 未定义")
            return
        }

        var config = deviceConfigMgr.loadSprinklerConfig(root.sprinklerIndex + 1)
        console.log("✅ [SprinklerConfigPanel] 加载洒水" + (root.sprinklerIndex + 1) + "配置:", JSON.stringify(config))

        enabledSwitch.checked = (config.enabled === 1 || config.enabled === true)
        sprinklerNameField.text = config.sprinkler_name || ("洒水" + (root.sprinklerIndex + 1))
        // ✅ 2026-03-24 [Phase 7.48.88.7]: 洒水1-5默认通道11-15，洒水6-8通道-1
        // ✅ 2026-03-30 [Phase 7.48.88.70]: 洒水1-4默认通道11-14，洒水5-8通道-1（只占用4个通道）
        // 旧代码：var defaultChannel = root.sprinklerIndex < 5 ? (root.sprinklerIndex + 11) : -1
        var defaultChannel = root.sprinklerIndex < 4 ? (root.sprinklerIndex + 11) : -1
        channelSpin.value = (config.channel !== undefined) ? config.channel : defaultChannel
        // ✅ 2026-03-22 [Phase 7.48.74]: 加载启动延时+停止延时
        startupDelaySpin.value = (config.startup_delay !== undefined) ? config.startup_delay : 1
        stopDelaySpin.value = (config.stop_delay !== undefined) ? config.stop_delay : 1
    }

    // ✅ 2026-03-30 [Phase 7.48.88.69]: 全局通道冲突检查提示
    property string channelConflictMessage: ""
    // ✅ 2026-03-30 [Phase 7.48.88.70]: 可用通道列表提示
    property string availableChannelsText: ""
    Timer {
        id: sprinklerConflictMessageTimer
        interval: 4000; repeat: false
        // ✅ 2026-03-30 [Phase 7.48.88.70]: 同时清除可用通道提示
        onTriggered: { root.channelConflictMessage = ""; root.availableChannelsText = "" }
    }

    // ✅ 2026-03-30 [Phase 7.48.88.70]: 计算可用通道列表文本
    function getAvailableChannelsText(channelMap) {
        var available = []
        for (var ch = 0; ch <= 15; ch++) {
            if (!channelMap[ch]) available.push(ch)
        }
        return available.length > 0 ? "可用通道: " + available.join(", ") : "所有通道已被占用"
    }

    // ✅ 2026-03-30 [Phase 7.48.88.69]: 构建全局通道占用表（排除当前洒水）
    function buildGlobalChannelMapForSprinkler(excludeSprinklerIdx) {
        var channelMap = {}
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return channelMap
        for (var m = 0; m < 8; m++) {
            var motorCfg = deviceConfigMgr.loadMotorConfig(root.deviceId, m, 0)
            if (!motorCfg || Object.keys(motorCfg).length === 0) continue
            var mCh = (motorCfg["output_channel"] !== undefined) ? motorCfg["output_channel"] : -1
            if (mCh >= 0) channelMap[mCh] = (m + 1) + "号电机"
        }
        for (var b = 0; b < 8; b++) {
            var brakeCfg = deviceConfigMgr.loadBrakeConfig(root.deviceId, b)
            if (!brakeCfg || Object.keys(brakeCfg).length === 0) continue
            var relCh = (brakeCfg["release_output_channel"] !== undefined) ? brakeCfg["release_output_channel"] : -1
            if (relCh >= 0) channelMap[relCh] = (b + 1) + "号制动器松闸"
            var brkCh = (brakeCfg["brake_output_channel"] !== undefined) ? brakeCfg["brake_output_channel"] : -1
            if (brkCh >= 0) channelMap[brkCh] = (b + 1) + "号制动器抱闸"
        }
        for (var t = 0; t < 2; t++) {
            var tensionCfg = deviceConfigMgr.loadTensionConfig(root.deviceId, t)
            if (!tensionCfg || Object.keys(tensionCfg).length === 0) continue
            var tCh = (tensionCfg["output_channel"] !== undefined) ? tensionCfg["output_channel"] : -1
            if (tCh >= 0) channelMap[tCh] = "张紧控制" + (t + 1)
        }
        for (var s = 0; s < 8; s++) {
            if (s === excludeSprinklerIdx) continue
            var sprCfg = deviceConfigMgr.loadSprinklerConfig(s + 1)  // 洒水索引从1开始
            if (!sprCfg || Object.keys(sprCfg).length === 0) continue
            var sCh = (sprCfg["channel"] !== undefined) ? sprCfg["channel"] : -1
            if (sCh >= 0) channelMap[sCh] = "洒水" + (s + 1)
        }
        return channelMap
    }

    function saveSprinklerConfig() {
        if (typeof deviceConfigMgr === "undefined") {
            console.log("⚠️ [SprinklerConfigPanel] deviceConfigMgr 未定义")
            return
        }

        var config = {
            "sprinkler_name": sprinklerNameField.text,
            "enabled": enabledSwitch.checked ? 1 : 0,
            // 旧："module_type": moduleTypeCombo.currentText,  // 2026-03-18 删除模块类型（固定为继电器模块）
            "channel": channelSpin.value,
            // 旧："mqtt_topic": mqttTopicField.text  // 2026-03-18 删除MQTT主题（使用全局配置）
            // ✅ 2026-03-22 [Phase 7.48.74]: 新增启动延时+停止延时
            "startup_delay": startupDelaySpin.value,
            "stop_delay": stopDelaySpin.value
        }

        // ✅ 2026-03-30 [Phase 7.48.88.69]: 保存前全局通道冲突检查
        var channelMap = buildGlobalChannelMapForSprinkler(root.sprinklerIndex)
        var ch = config["channel"]
        if (ch >= 0 && channelMap[ch]) {
            root.channelConflictMessage = "⚠ 保存失败：通道 " + ch + " 已被「" + channelMap[ch] + "」占用，请先释放原通道"
            // ✅ 2026-03-30 [Phase 7.48.88.70]: 列出可用通道
            root.availableChannelsText = getAvailableChannelsText(channelMap)
            sprinklerConflictMessageTimer.restart()
            return
        }

        var success = deviceConfigMgr.saveSprinklerConfig(root.sprinklerIndex + 1, config)
        if (success) {
            console.log("✅ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) + "配置已保存")
        } else {
            console.log("❌ [SprinklerConfigPanel] 洒水" + (root.sprinklerIndex + 1) + "配置保存失败")
        }
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [SprinklerConfigPanel] triggerParamInput:", paramIndex)
        switch(paramIndex) {
        // 旧：case 2: channelSpin → 结束
        // ✅ 2026-03-22 [Phase 7.48.74]: 新增启动延时+停止延时导航
        case 0: enabledSwitch.toggle(); break
        case 1: sprinklerNameField.forceActiveFocus(); break
        case 2: channelSpin.forceActiveFocus(); break
        case 3: startupDelaySpin.forceActiveFocus(); break
        case 4: stopDelaySpin.forceActiveFocus(); break
        }
    }

    function triggerButton(buttonIndex) {
        console.log("✅ [SprinklerConfigPanel] triggerButton:", buttonIndex)
        switch(buttonIndex) {
        case 0: sendSprinklerCommand(true); break   // 启动洒水
        case 1: sendSprinklerCommand(false); break  // 停止洒水
        case 2: saveSprinklerConfig(); break         // 保存配置
        case 3: loadSprinklerConfig(); break         // 加载配置
        }
    }

    onSprinklerIndexChanged: {
        loadSprinklerConfig()
    }

    // ✅ 2026-03-30 [Phase 7.48.88.72]: 监听皮带运行状态，冻结参数修改
    Connections {
        target: typeof commonControl !== "undefined" ? commonControl : null
        function onBeltRunningChanged(beltNumber, running) {
            var currentBelt = (typeof systemConfig !== "undefined" && systemConfig) ? systemConfig.machineNumber : 1
            if (beltNumber === currentBelt) {
                root.beltIsRunning = running
            }
        }
    }

    Component.onCompleted: {
        loadSprinklerConfig()
        // ✅ 2026-03-30 [Phase 7.48.88.72]: 初始化皮带运行状态
        if (typeof commonControl !== "undefined" && commonControl) {
            var beltNum = (typeof systemConfig !== "undefined" && systemConfig) ? systemConfig.machineNumber : 1
            root.beltIsRunning = commonControl.isBeltRunning(beltNum)
        }
    }
}
