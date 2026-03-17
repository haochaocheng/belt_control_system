import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-17 [Phase 7.48.48]: 完整重写-匹配BrakeConfigPanel布局风格
// 原始文件: 2026-01-27 [张紧控制-右侧面板] 控制配置面板
Rectangle {
    id: root
    implicitWidth: 1400; implicitHeight: 600; color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int controlIndex: 0  // 0=张力传感器, 1=独立张紧控制
    property var keyboardManager: null
    property var virtualKeyboard: null
    property int focusSubArea: 0   // 0:列表 1:参数 2:按钮
    property int focusUsageStatusIndex: 0  // 保留兼容
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property bool waitingForFeedback: false

    // ✅ 2026-03-17 [Phase 7.48.48]: 统一尺寸常量（匹配BrakeConfigPanel）
    readonly property int lblFs: 21
    readonly property string lblC: "#9E9E9E"
    readonly property int fldW: 120
    readonly property int lblW: 130

    focus: true; activeFocusOnTab: true
    signal requestFocusParamIndex(int paramIndex)

    // ========== 标题栏 ==========
    // ✅ 2026-03-17 [修改1]: header高度从50px改为40px
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 40; color: "transparent"
        Image { anchors.fill: parent; source: "../images/059.png"; fillMode: Image.Stretch; z: -1 }
        Text {
            anchors.centerIn: parent
            text: root.controlIndex === 0 ? "张力传感器配置" : "独立张紧控制配置"
            font.pixelSize: 16; font.weight: Font.Bold; color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    // ✅ 2026-03-17 [修改1]: margins从15改为10，移除ScrollView包装
    ColumnLayout {
        id: contentArea
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
        spacing: 6

        // ========== 统一8列GridLayout ==========
        // ✅ 2026-03-17 [修改3/5]: 8列布局，三列间距平均分配
        GridLayout {
            Layout.fillWidth: true
            columns: 8
            columnSpacing: 8
            rowSpacing: 8

            // ---- 行0：传感器启用 + 名称 + 单位 ----
            // ✅ 2026-03-17 [修改1/2]: 传感器启用在第一行（匹配制动器启用位置）
            Text { text: "传感器启用:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Switch { id: enabledSwitch; checked: true }
            Text { text: "名称:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            TextField {
                id: nameField; Layout.preferredWidth: root.fldW; text: "张力传感器"
                color: "#E0E0E0"; font.pixelSize: 18
                background: Rectangle { color: "#1E293B"; border.color: nameField.activeFocus ? "#4FC3F7" : "#334155"; radius: 4 }
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 0
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 0 }
            }
            Text { text: "单位:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            ComboBox {
                id: unitCombo; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.minimumWidth: root.fldW
                model: ["N", "kN", "kg", "t"]
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 1
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 1 }
            }

            // ---- 分隔线 ----
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行1：使用反馈 + 反馈通道 + 超时 ----
            // ✅ 2026-03-17 [修改2]: 使用反馈放在传感器启用下面
            // ✅ 2026-03-17 [修改3]: 反馈通道和超时向右移动一列
            Text { text: "使用反馈:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Switch { id: useFeedbackSwitch; checked: false; enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            Text { text: "反馈通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: (enabledSwitch.checked && useFeedbackSwitch.checked) ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: feedbackChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0
                enabled: enabledSwitch.checked && useFeedbackSwitch.checked
                opacity: (enabledSwitch.checked && useFeedbackSwitch.checked) ? 1.0 : 0.4
                // ✅ focusParamIndex: 2
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 2 }
            }
            Text { text: "超时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: (enabledSwitch.checked && useFeedbackSwitch.checked) ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: feedbackTimeoutSpin; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.minimumWidth: root.fldW; from: 1; to: 60; value: 10
                enabled: enabledSwitch.checked && useFeedbackSwitch.checked
                opacity: (enabledSwitch.checked && useFeedbackSwitch.checked) ? 1.0 : 0.4
                // ✅ focusParamIndex: 3
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 3 }
            }

            // ---- 分隔线 ----
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行2：输入类型 + 模块类型 + 寄存器地址 ----
            Text { text: "输入类型:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            ComboBox {
                id: typeCombo; Layout.preferredWidth: root.fldW
                model: ["模拟量", "数字量", "MODBUS"]
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 4
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 4 }
            }
            Text { text: "模块类型:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            ComboBox {
                id: moduleTypeCombo; Layout.preferredWidth: root.fldW
                // 2026-03-17: 修正模块类型选项（原MCP3208/ADS1115/HX711错误）
                model: ["无", "模拟量模块1", "模拟量模块2"]
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 5
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 5 }
            }
            Text { text: "寄存器地址:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: registerAddressSpin; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.minimumWidth: root.fldW; from: 0; to: 65535; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 6
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 6 }
            }

            // ---- 行3：保护延时 + 上限值 + 量程 ----
            Text { text: "保护延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: delaySpin; Layout.preferredWidth: root.fldW; from: 0; to: 9999; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 7
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 7 }
            }
            Text { text: "上限值:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: upperLimitSpin; Layout.preferredWidth: root.fldW; from: 0; to: 99999; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 8
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 8 }
            }
            Text { text: "量程:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: rangeSpin; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.minimumWidth: root.fldW; from: 0; to: 99999; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 9
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 9 }
            }

            // ---- 行4：额定值 + 播放次数 + 播放时长 ----
            Text { text: "额定值:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: ratedValueSpin; Layout.preferredWidth: root.fldW; from: 0; to: 99999; value: 0
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 10
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 10 }
            }
            Text { text: "播放次数:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: playCountSpin; Layout.preferredWidth: root.fldW; from: 1; to: 10; value: 3
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 11
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 11 }
            }
            Text { text: "播放时长:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox {
                id: durationSpin; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.minimumWidth: root.fldW; from: 1; to: 60; value: 5
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 12
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 12 }
            }

            // ---- 分隔线 ----
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行5：语音类型选择 ----
            // ✅ 2026-03-17 [修改6]: 语音标签字体统一为21px/#9E9E9E
            Text { text: "语音类型:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            RowLayout {
                Layout.columnSpan: 7; Layout.fillWidth: true
                spacing: 20
                RadioButton {
                    id: ttsRadio; text: "TTS合成"; checked: true
                    enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                    contentItem: Text { text: ttsRadio.text; font.pixelSize: root.lblFs; color: root.lblC; leftPadding: ttsRadio.indicator.width + 4; verticalAlignment: Text.AlignVCenter }
                }
                RadioButton {
                    id: fileRadio; text: "音频文件"
                    enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                    contentItem: Text { text: fileRadio.text; font.pixelSize: root.lblFs; color: root.lblC; leftPadding: fileRadio.indicator.width + 4; verticalAlignment: Text.AlignVCenter }
                }
            }

            // ---- 行6：TTS文本（ttsRadio选中时显示） ----
            Text { text: "TTS文本:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                visible: ttsRadio.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            TextField {
                id: ttsTextField; Layout.columnSpan: 7; Layout.fillWidth: true
                text: "张力传感器报警"; color: "#E0E0E0"; font.pixelSize: 18
                visible: ttsRadio.checked
                background: Rectangle { color: "#1E293B"; border.color: ttsTextField.activeFocus ? "#4FC3F7" : "#334155"; radius: 4 }
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 13
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 13 }
            }

            // ---- 行7：音频文件路径（fileRadio选中时显示） ----
            Text { text: "音频文件:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                visible: fileRadio.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            TextField {
                id: audioFileField; Layout.columnSpan: 7; Layout.fillWidth: true
                text: ""; placeholderText: "音频文件路径"; color: "#E0E0E0"; font.pixelSize: 18
                visible: fileRadio.checked
                background: Rectangle { color: "#1E293B"; border.color: audioFileField.activeFocus ? "#4FC3F7" : "#334155"; radius: 4 }
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 14
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 14 }
            }

            // ---- 分隔线 ----
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ---- 行8：预警语音 + 失败语音 ----
            // ✅ 2026-03-17 [修改6]: 预警语音/失败语音字体修复为21px/#9E9E9E
            Text { text: "预警语音:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            TextField {
                id: warningVoiceField; Layout.columnSpan: 2; Layout.fillWidth: true
                text: ""; placeholderText: "预警语音路径"; color: "#E0E0E0"; font.pixelSize: 18
                background: Rectangle { color: "#1E293B"; border.color: warningVoiceField.activeFocus ? "#4FC3F7" : "#334155"; radius: 4 }
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 15
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 15 }
            }
            Text { text: "失败语音:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight
                opacity: enabledSwitch.checked ? 1.0 : 0.4 }
            TextField {
                id: failureVoiceField; Layout.columnSpan: 4; Layout.fillWidth: true
                text: ""; placeholderText: "失败语音路径"; color: "#E0E0E0"; font.pixelSize: 18
                background: Rectangle { color: "#1E293B"; border.color: failureVoiceField.activeFocus ? "#4FC3F7" : "#334155"; radius: 4 }
                enabled: enabledSwitch.checked; opacity: enabledSwitch.checked ? 1.0 : 0.4
                // ✅ focusParamIndex: 16
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 4; visible: root.focusSubArea === 1 && root.focusParamIndex === 16 }
            }
        } // GridLayout end

        // ========== 状态指示灯 + 启动/停止按钮 ==========
        // ✅ 2026-03-17 [修改7]: 启动按钮带预警语音，匹配BrakeConfigPanel
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            // 状态LED
            Rectangle {
                width: 20; height: 20; radius: 10
                color: root.waitingForFeedback ? "#FFA726" : (enabledSwitch.checked ? "#4CAF50" : "#616161")
                border.color: "#334155"; border.width: 1
            }
            Text {
                text: root.waitingForFeedback ? "等待反馈..." : (enabledSwitch.checked ? "就绪" : "已禁用")
                font.pixelSize: root.lblFs; color: root.lblC
            }

            Item { Layout.fillWidth: true }

            // 启动按钮
            Button {
                id: startButton
                text: "启 动"
                Layout.preferredWidth: 120; Layout.preferredHeight: 40
                enabled: enabledSwitch.checked && !root.waitingForFeedback
                background: Rectangle {
                    color: startButton.enabled ? (startButton.pressed ? "#2E7D32" : "#4CAF50") : "#424242"
                    radius: 6
                }
                contentItem: Text { text: startButton.text; font.pixelSize: 18; font.weight: Font.Bold; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                // ✅ focusButtonIndex: 0
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 6; visible: root.focusSubArea === 2 && root.focusButtonIndex === 0 }
                onClicked: { startTensionControl() }
            }

            // 停止按钮
            Button {
                id: stopButton
                text: "停 止"
                Layout.preferredWidth: 120; Layout.preferredHeight: 40
                enabled: enabledSwitch.checked
                background: Rectangle {
                    color: stopButton.enabled ? (stopButton.pressed ? "#C62828" : "#F44336") : "#424242"
                    radius: 6
                }
                contentItem: Text { text: stopButton.text; font.pixelSize: 18; font.weight: Font.Bold; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                // ✅ focusButtonIndex: 1
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#4FC3F7"; border.width: 2; radius: 6; visible: root.focusSubArea === 2 && root.focusButtonIndex === 1 }
                onClicked: { stopTensionControl() }
            }
        }

        // 底部填充
        Item { Layout.fillHeight: true; Layout.maximumHeight: 10 }
    } // ColumnLayout end

    // ========== 预警语音定时器 ==========
    Timer {
        id: warningVoiceTimer
        interval: 3000; repeat: false
        onTriggered: {
            // 预警语音播放完毕，发送MQTT启动命令
            var cmd = {
                "action": "start",
                "device_id": root.deviceId,
                "control_index": root.controlIndex,
                "config": collectConfig()
            }
            if (typeof mqttClient !== "undefined") {
                mqttClient.publish("belt_control/do/module1/cmd", JSON.stringify(cmd))
            }
            if (useFeedbackSwitch.checked) {
                root.waitingForFeedback = true
                feedbackTimeoutTimer.start()
            }
        }
    }

    // ========== 反馈超时定时器 ==========
    Timer {
        id: feedbackTimeoutTimer
        interval: feedbackTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            root.waitingForFeedback = false
            console.log("[TensionControl] 反馈超时，控制索引:", root.controlIndex)
            // 播放失败语音
            var failPath = buildAudioPath(failureVoiceField.text)
            if (failPath !== "" && typeof audioPlayer !== "undefined") {
                audioPlayer.play(failPath)
            }
        }
    }

    // ========== 函数 ==========

    // ✅ 2026-03-17 [修改7]: buildAudioPath匹配批量生成语音路径
    function buildAudioPath(voicePath) {
        if (!voicePath || voicePath === "") return ""
        // 如果已经是绝对路径，直接返回
        if (voicePath.startsWith("/")) return voicePath
        // 拼接默认音频目录
        return "/app/audio/" + voicePath
    }

    function startTensionControl() {
        console.log("[TensionControl] 启动控制，索引:", root.controlIndex)
        // 先播放预警语音
        var warnPath = buildAudioPath(warningVoiceField.text)
        if (warnPath !== "" && typeof audioPlayer !== "undefined") {
            audioPlayer.play(warnPath)
            warningVoiceTimer.start()
        } else {
            // 无预警语音，直接发送启动命令
            warningVoiceTimer.triggered()
        }
    }

    function stopTensionControl() {
        console.log("[TensionControl] 停止控制，索引:", root.controlIndex)
        warningVoiceTimer.stop()
        feedbackTimeoutTimer.stop()
        root.waitingForFeedback = false
        var cmd = {
            "action": "stop",
            "device_id": root.deviceId,
            "control_index": root.controlIndex
        }
        if (typeof mqttClient !== "undefined") {
            mqttClient.publish("belt_control/do/module1/cmd", JSON.stringify(cmd))
        }
    }

    function collectConfig() {
        return {
            "protection_name": nameField.text,
            "unit": unitCombo.currentText,
            "input_type": typeCombo.currentIndex,
            "protection_delay": delaySpin.value,
            "module_type": moduleTypeCombo.currentIndex,
            "play_count": playCountSpin.value,
            "register_address": registerAddressSpin.value,
            "play_duration": durationSpin.value,
            "upper_limit": upperLimitSpin.value,
            "use_text_to_speech": ttsRadio.checked ? 1 : 0,
            "tts_text": ttsTextField.text,
            "range_value": rangeSpin.value,
            "rated_value": ratedValueSpin.value,
            "audio_file": audioFileField.text,
            "enabled": enabledSwitch.checked ? 1 : 0,
            "use_feedback": useFeedbackSwitch.checked ? 1 : 0,
            "feedback_channel": feedbackChannelSpin.value,
            "feedback_timeout": feedbackTimeoutSpin.value,
            "warning_voice": warningVoiceField.text,
            "failure_voice": failureVoiceField.text
        }
    }

    function saveTensionConfig() {
        var config = collectConfig()
        if (typeof deviceConfigMgr !== "undefined") {
            deviceConfigMgr.saveTensionConfig(root.deviceId, root.controlIndex, config)
            console.log("[TensionControl] 配置已保存，索引:", root.controlIndex)
        }
        return true
    }

    function loadTensionConfig() {
        if (typeof deviceConfigMgr === "undefined") return false
        var config = deviceConfigMgr.loadTensionConfig(root.deviceId, root.controlIndex)
        if (!config || Object.keys(config).length === 0) return false

        if (config.hasOwnProperty("protection_name")) nameField.text = config["protection_name"]
        if (config.hasOwnProperty("unit")) {
            var idx = unitCombo.find(config["unit"])
            if (idx >= 0) unitCombo.currentIndex = idx
        }
        if (config.hasOwnProperty("input_type")) typeCombo.currentIndex = config["input_type"]
        if (config.hasOwnProperty("protection_delay")) delaySpin.value = config["protection_delay"]
        if (config.hasOwnProperty("module_type")) moduleTypeCombo.currentIndex = config["module_type"]
        if (config.hasOwnProperty("play_count")) playCountSpin.value = config["play_count"]
        if (config.hasOwnProperty("register_address")) registerAddressSpin.value = config["register_address"]
        if (config.hasOwnProperty("play_duration")) durationSpin.value = config["play_duration"]
        if (config.hasOwnProperty("upper_limit")) upperLimitSpin.value = config["upper_limit"]
        if (config.hasOwnProperty("use_text_to_speech")) ttsRadio.checked = (config["use_text_to_speech"] === 1)
        if (config.hasOwnProperty("tts_text")) ttsTextField.text = config["tts_text"]
        if (config.hasOwnProperty("range_value")) rangeSpin.value = config["range_value"]
        if (config.hasOwnProperty("rated_value")) ratedValueSpin.value = config["rated_value"]
        if (config.hasOwnProperty("audio_file")) audioFileField.text = config["audio_file"]
        if (config.hasOwnProperty("enabled")) enabledSwitch.checked = (config["enabled"] === 1)
        if (config.hasOwnProperty("use_feedback")) useFeedbackSwitch.checked = (config["use_feedback"] === 1)
        if (config.hasOwnProperty("feedback_channel")) feedbackChannelSpin.value = config["feedback_channel"]
        if (config.hasOwnProperty("feedback_timeout")) feedbackTimeoutSpin.value = config["feedback_timeout"]
        if (config.hasOwnProperty("warning_voice")) warningVoiceField.text = config["warning_voice"]
        if (config.hasOwnProperty("failure_voice")) failureVoiceField.text = config["failure_voice"]
        return true
    }

    Component.onCompleted: { loadTensionConfig() }

    // 2026-03-17: 切换控制索引时先保存当前配置再加载新配置
    property int _previousControlIndex: -1
    onControlIndexChanged: {
        if (_previousControlIndex >= 0) {
            var prevConfig = collectConfig()
            if (typeof deviceConfigMgr !== "undefined") {
                deviceConfigMgr.saveTensionConfig(root.deviceId, _previousControlIndex, prevConfig)
            }
        }
        _previousControlIndex = controlIndex
        loadTensionConfig()
    }
}
