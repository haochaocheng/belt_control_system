import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import com.belt.control 1.0  // ✅ 2026-03-17 [Phase 7.48.53]: 导入TTSConfig单例（用于音频路径构建）
import ".." as DeviceInfo

// 2026-03-17 [Phase 7.48.51] 张紧控制配置面板（重写）
// 参数参照 BasicConfigTab（电机基本配置）
Rectangle {
    id: root
    color: "transparent"
    clip: true

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int controlIndex: 1      // 1=张紧控制
    property int focusSubArea: 0      // 1=参数区域, 2=按钮区域
    property int focusParamIndex: -1
    property int focusButtonIndex: -1
    property var virtualKeyboard: null
    property var keyboardManager: null  // ✅ 2026-03-17 [Phase 7.48.52]: 键盘管理器（CustomSpinBox/CustomTextField需要）
    property bool tensionOpened: false  // 张紧打开状态

    // ========== 布局常量 ==========
    // ✅ 2026-03-17 [Phase 7.48.52]: 参照 BasicConfigTab 调整布局常量
    readonly property int lblFs: 21  // 标签字体大小（与BasicConfigTab一致）
    readonly property string lblC: "#9E9E9E"  // 标签颜色（与BasicConfigTab一致）
    readonly property int fldW: 120  // 输入框宽度（与BasicConfigTab一致）
    readonly property int lblW: 160  // 标签宽度（从130改为160，与BasicConfigTab一致）
    readonly property int cmbW: 300  // ComboBox宽度（从160改为300，与BasicConfigTab一致）

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
            text: "张紧控制配置"
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
        anchors.margins: 10
        spacing: 6

        // ========== GridLayout 8列参数区 ==========
        // ✅ 2026-03-17 [Phase 7.48.52]: 改为4列GridLayout，参照BasicConfigTab布局
        GridLayout {
            id: paramGrid
            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
            columnSpacing: 10  // 参照BasicConfigTab
            rowSpacing: 12  // 参照BasicConfigTab
            Layout.fillWidth: true

            // ✅ 2026-03-17 [Phase 7.48.52]: 参照BasicConfigTab 4列布局重排参数
            // Row 0: 张紧启用(Switch) | 输出通道(0)
            // Row 1: 使用反馈(Switch) | 反馈通道(1)
            // Row 2: 反馈超时(2) | 启动延时(3)

            // ===== Row 0: 张紧启用 | 输出通道(0) =====
            Text { text: "张紧启用:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: tensionEnabledSwitch.implicitHeight
                Switch { id: tensionEnabledSwitch; checked: true; anchors.verticalCenter: parent.verticalCenter }
            }
            Text { text: "输出通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: outputChannelSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: outputChannelSpin; from: 0; to: 7; value: 0; editable: true; anchors.fill: parent; enabled: tensionEnabledSwitch.checked; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 0 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 1: 使用反馈 | 反馈通道(1) =====
            Text { text: "使用反馈:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 1; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: useFeedbackSwitch.implicitHeight
                Switch { id: useFeedbackSwitch; checked: false; anchors.verticalCenter: parent.verticalCenter; enabled: tensionEnabledSwitch.checked }
            }
            Text { text: "反馈通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 1; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: feedbackChannelSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: feedbackChannelSpin; from: 0; to: 7; value: 0; editable: true; anchors.fill: parent; enabled: tensionEnabledSwitch.checked && useFeedbackSwitch.checked; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 1 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 2: 反馈超时(2) | 启动延时(3) =====
            Text { text: "反馈超时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 2; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 2; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: feedbackTimeoutSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: feedbackTimeoutSpin; from: 1; to: 60; value: 10; editable: true; anchors.fill: parent; enabled: tensionEnabledSwitch.checked && useFeedbackSwitch.checked; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 2 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "启动延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 2; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 2; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: startupDelaySpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: startupDelaySpin; from: 0; to: 60; value: 0; editable: true; anchors.fill: parent; enabled: tensionEnabledSwitch.checked; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 3 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        } // GridLayout end

        // ========== 分隔线 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== 音频来源 ==========
        // ✅ 2026-03-17 [Phase 7.48.53]: 默认使用TTS（因为没有预录音频文件）
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text { text: "音频来源:"; font.pixelSize: root.lblFs; color: root.lblC }
            ButtonGroup { id: audioSourceGroup }
            RadioButton {
                id: audioDefaultRadio; text: "默认"
                ButtonGroup.group: audioSourceGroup
                enabled: tensionEnabledSwitch.checked
                contentItem: Text { text: parent.text; font.pixelSize: 21; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
            }
            RadioButton {
                id: audioTtsRadio; text: "TTS"; checked: true
                ButtonGroup.group: audioSourceGroup
                enabled: tensionEnabledSwitch.checked
                contentItem: Text { text: parent.text; font.pixelSize: 21; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
            }
        }

        // ========== 预警语音(4) + 失败语音(5) ==========
        // ✅ 2026-03-17 [Phase 7.48.53]: 设置默认TTS文本
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: "预警语音:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            DeviceInfo.CustomTextField {
                id: warningVoiceField
                // ✅ 2026-03-17 [Phase 7.48.53]: 改为音频文件名（不含扩展名），参照BasicConfigTab命名规范
                // 旧：text: "一号皮带张紧准备启动，请注意安全"（TTS全文，不是文件名）
                // 新：匹配BatchAudioGenerator生成的文件名 "{tensionNum}号张紧启动.wav"
                text: root.controlIndex + "号张紧启动"
                Layout.fillWidth: true
                placeholderText: audioTtsRadio.checked ? "TTS文本" : "音频文件名"
                enabled: tensionEnabledSwitch.checked
                keyboardManager: root.keyboardManager
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 4 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: "失败语音:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            DeviceInfo.CustomTextField {
                id: failureVoiceField
                // ✅ 2026-03-17 [Phase 7.48.53]: 改为音频文件名（不含扩展名），参照BasicConfigTab命名规范
                // 旧：text: "一号皮带张紧运行失败"（TTS全文，不是文件名）
                // 新：匹配BatchAudioGenerator生成的文件名 "{tensionNum}号张紧运行失败.wav"
                text: root.controlIndex + "号张紧运行失败"
                Layout.fillWidth: true
                placeholderText: audioTtsRadio.checked ? "TTS文本" : "音频文件名"
                enabled: tensionEnabledSwitch.checked
                keyboardManager: root.keyboardManager
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 5 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== 弹性空间 ==========
        Item { Layout.fillHeight: true }

        // ========== 分隔线2 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== LED状态 + 启动/停止按钮 ==========
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            spacing: 16

            // 张紧打开LED
            Rectangle {
                width: 20; height: 20; radius: 10
                color: root.tensionOpened ? "#4CAF50" : "#616161"
                border.color: "#334155"; border.width: 1
            }
            Text {
                text: "张紧打开"
                font.pixelSize: root.lblFs; color: root.lblC
            }

            Item { width: 20 }

            // 张紧关闭LED
            Rectangle {
                width: 20; height: 20; radius: 10
                color: !root.tensionOpened ? "#4CAF50" : "#616161"
                border.color: "#334155"; border.width: 1
            }
            Text {
                text: "张紧关闭"
                font.pixelSize: root.lblFs; color: root.lblC
            }

            Item { Layout.fillWidth: true }

            // 启动按钮
            Button {
                id: startBtn
                text: "启动"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                enabled: tensionEnabledSwitch.checked
                background: Rectangle { color: startBtn.pressed ? "#2E7D32" : "#4CAF50"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: startTensionControl()
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 0 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 100 }
            }

            // 停止按钮
            Button {
                id: stopBtn
                text: "停止"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                enabled: tensionEnabledSwitch.checked
                background: Rectangle { color: stopBtn.pressed ? "#C62828" : "#F44336"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: stopTensionControl()
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 1 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 100 }
            }
        }
    } // ColumnLayout end

    // ========== 启动延时定时器 ==========
    Timer {
        id: startupDelayTimer
        interval: startupDelaySpin.value * 1000
        repeat: false
        onTriggered: {
            // ✅ 2026-03-17 [Phase 7.48.53]: 重写语音播放逻辑，参照BasicConfigTab
            // 旧：playVoice(warningVoiceField.text, "预警")  // 使用commonControl.testTTS()，错误
            // 新：使用alarmPlayback.playAlarm()播放预合成音频文件，TTS文本作为回退
            if (warningVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
                var beltNum = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
                var audioPath = buildAudioPath(beltNum, warningVoiceField.text)
                var ttsText = beltNum + "号皮带张紧准备启动，请注意安全"
                console.log("🗣️ [TensionControlConfigPanel] 播放预警语音:", audioPath)
                alarmPlayback.playAlarm(warningVoiceField.text, ttsText, audioPath, true, "count", 1, 5)
            }

            // 发送MQTT启动命令
            sendMqttCommand("start")

            // 如果使用反馈，启动反馈超时定时器
            if (useFeedbackSwitch.checked) {
                feedbackTimeoutTimer.start()
            } else {
                root.tensionOpened = true
            }
        }
    }

    // ========== 反馈超时定时器 ==========
    Timer {
        id: feedbackTimeoutTimer
        interval: feedbackTimeoutSpin.value * 1000
        repeat: false
        onTriggered: {
            console.log("✅ [TensionControlConfigPanel] 反馈超时")
            // ✅ 2026-03-17 [Phase 7.48.53]: 重写语音播放逻辑，参照BasicConfigTab
            // 旧：playVoice(failureVoiceField.text, "失败")  // 使用commonControl.testTTS()，错误
            // 新：使用alarmPlayback.playAlarm()播放预合成音频文件，TTS文本作为回退
            if (failureVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
                var beltNum = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
                var audioPath = buildAudioPath(beltNum, failureVoiceField.text)
                var ttsText = beltNum + "号皮带张紧运行失败"
                console.log("🗣️ [TensionControlConfigPanel] 播放失败语音:", audioPath)
                alarmPlayback.playAlarm(failureVoiceField.text, ttsText, audioPath, true, "count", 3, 5)
            }

            // 停止张紧控制
            sendMqttCommand("stop")
            root.tensionOpened = false
        }
    }

    // ========== 函数 ==========

    function getParamFieldCount() { return 6 }  // 参数索引 0-5

    // ✅ 2026-03-17 [Phase 7.48.53]: 删除旧playVoice函数
    // 旧：function playVoice(voiceText, label) { ... commonControl.testTTS() ... }
    // 原因：语音播放方法不对，应该使用alarmPlayback.playAlarm()播放预合成音频文件
    // 新：直接在定时器onTriggered中调用alarmPlayback.playAlarm()（参照BasicConfigTab）

    // ✅ 2026-03-17 [Phase 7.48.53]: 重写buildAudioPath，参照BasicConfigTab
    // 旧：function buildAudioPath(filename) { return "/app/audio/" + filename }
    // 新：根据音频来源（默认/TTS）构建正确路径，使用audioBaseDir全局属性
    function buildAudioPath(beltNum, filename) {
        if (!filename || filename === "") return ""
        if (audioDefaultRadio.checked) {
            // 默认音频：{audioBaseDir}/{beltNum}#PD/{filename}.wav
            return audioBaseDir + "/" + beltNum + "#PD/" + filename + ".wav"
        } else {
            // TTS合成音频：{audioBaseDir}/paddlespeech-{model}-spk{id}/{beltNum}#PD/{filename}.wav
            var modelIdx = typeof TTSConfig !== "undefined" ? TTSConfig.modelIndex(TTSConfig.Test) : 0
            var modelName = typeof TTSConfig !== "undefined" ? TTSConfig.modelName(modelIdx) : "fastspeech2_csmsc"
            var spkId = typeof TTSConfig !== "undefined" ? TTSConfig.speakerId(TTSConfig.Test) : 0
            var engineFolder = "paddlespeech-" + modelName + "-spk" + spkId
            return audioBaseDir + "/" + engineFolder + "/" + beltNum + "#PD/" + filename + ".wav"
        }
    }

    function sendMqttCommand(action) {
        var cmd = {
            "action": action,
            "device_id": root.deviceId,
            "control_index": root.controlIndex,
            "output_channel": outputChannelSpin.value,
            "config": collectConfig()
        }
        console.log("✅ [TensionControlConfigPanel] 发送MQTT命令:", action)
        if (typeof mqttClient !== "undefined") {
            mqttClient.publish("belt_control/tension/cmd", JSON.stringify(cmd))
        }
    }

    function startTensionControl() {
        console.log("✅ [TensionControlConfigPanel] 启动张紧控制")
        if (startupDelaySpin.value > 0) {
            startupDelayTimer.start()
        } else {
            startupDelayTimer.triggered()
        }
    }

    function stopTensionControl() {
        console.log("✅ [TensionControlConfigPanel] 停止张紧控制")
        startupDelayTimer.stop()
        feedbackTimeoutTimer.stop()
        sendMqttCommand("stop")
        root.tensionOpened = false
    }

    function collectConfig() {
        return {
            "tension_enabled": tensionEnabledSwitch.checked,
            "output_channel": outputChannelSpin.value,
            "use_feedback": useFeedbackSwitch.checked,
            "feedback_channel": feedbackChannelSpin.value,
            "feedback_timeout": feedbackTimeoutSpin.value,
            "startup_delay": startupDelaySpin.value,
            "audio_source": audioTtsRadio.checked ? "tts" : "default",
            "warning_voice": warningVoiceField.text,
            "failure_voice": failureVoiceField.text
        }
    }

    function applyConfig(config) {
        if (!config) return
        if (config.tension_enabled !== undefined) tensionEnabledSwitch.checked = config.tension_enabled
        if (config.output_channel !== undefined) outputChannelSpin.value = config.output_channel
        if (config.use_feedback !== undefined) useFeedbackSwitch.checked = config.use_feedback
        if (config.feedback_channel !== undefined) feedbackChannelSpin.value = config.feedback_channel
        if (config.feedback_timeout !== undefined) feedbackTimeoutSpin.value = config.feedback_timeout
        if (config.startup_delay !== undefined) startupDelaySpin.value = config.startup_delay
        if (config.audio_source !== undefined) { audioTtsRadio.checked = (config.audio_source === "tts"); audioDefaultRadio.checked = (config.audio_source !== "tts") }
        if (config.warning_voice !== undefined) warningVoiceField.text = config.warning_voice
        if (config.failure_voice !== undefined) failureVoiceField.text = config.failure_voice
    }

    function saveTensionControlConfig() {
        var config = collectConfig()
        console.log("✅ [TensionControlConfigPanel] 保存张紧控制配置:", JSON.stringify(config))
        if (typeof deviceConfigMgr !== "undefined") {
            deviceConfigMgr.saveTensionControlConfig(root.deviceId, config)
        }
    }

    function loadTensionControlConfig() {
        console.log("✅ [TensionControlConfigPanel] 加载张紧控制配置, deviceId:", root.deviceId)
        if (typeof deviceConfigMgr !== "undefined") {
            var config = deviceConfigMgr.loadTensionControlConfig(root.deviceId)
            applyConfig(config)
        }
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [TensionControlConfigPanel] triggerParamInput:", paramIndex)
        switch(paramIndex) {
        case 0: outputChannelSpin.forceActiveFocus(); break
        case 1: feedbackChannelSpin.forceActiveFocus(); break
        case 2: feedbackTimeoutSpin.forceActiveFocus(); break
        case 3: startupDelaySpin.forceActiveFocus(); break
        case 4: warningVoiceField.forceActiveFocus(); break
        case 5: failureVoiceField.forceActiveFocus(); break
        }
    }

    function triggerButton(buttonIndex) {
        console.log("✅ [TensionControlConfigPanel] triggerButton:", buttonIndex)
        switch(buttonIndex) {
        case 0: startTensionControl(); break
        case 1: stopTensionControl(); break
        }
    }

    Component.onCompleted: {
        console.log("✅ [TensionControlConfigPanel] 初始化完成, deviceId:", root.deviceId)
        loadTensionControlConfig()
    }
}
