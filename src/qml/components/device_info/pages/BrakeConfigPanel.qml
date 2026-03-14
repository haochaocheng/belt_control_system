import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-14 [Phase 7.48.45]: 紧凑布局重写，一屏显示无需滚动
// 旧版：两列布局+大间距，需要滚动
// 新版：4列紧凑布局，8行内容，约380px高度
Rectangle {
    id: root
    implicitWidth: 1400
    height: 600
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int brakeIndex: 0
    property var keyboardManager: null
    property var virtualKeyboard: null
    property int focusSubArea: 0   // 0:制动器列表 1:使用状态 2:参数区域 3:底部按钮区域
    property int focusUsageStatusIndex: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property bool waitingForRelease: false
    property bool waitingForBrake: false

    focus: true
    activeFocusOnTab: true

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "transparent"

        Image {
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch
            z: -1
        }

        Text {
            anchors.centerIn: parent
            text: (root.brakeIndex + 1) + "号制动器配置"
            font.pixelSize: 16; font.weight: Font.Bold; color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    Rectangle {
        id: contentArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // ========== 行0：使用状态 + 松闸/抱闸输出通道 ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                RadioButton {
                    id: statusEnabled; text: "投入"; checked: true; font.pixelSize: 14
                    contentItem: Text { text: statusEnabled.text; font: statusEnabled.font; color: "#E0E0E0"
                        leftPadding: statusEnabled.indicator.width + statusEnabled.spacing; verticalAlignment: Text.AlignVCenter }
                }
                RadioButton {
                    id: statusDisabled; text: "禁用"; font.pixelSize: 14
                    contentItem: Text { text: statusDisabled.text; font: statusDisabled.font; color: "#E0E0E0"
                        leftPadding: statusDisabled.indicator.width + statusDisabled.spacing; verticalAlignment: Text.AlignVCenter }
                }

                Item { Layout.preferredWidth: 20 }

                Text { text: "松闸输出通道:"; font.pixelSize: 16; color: "#9E9E9E" }
                DeviceInfo.CustomSpinBox {
                    id: releaseOutputChannelSpin
                    Layout.preferredWidth: 100; from: 0; to: 15; value: 0
                }
                Text { text: "抱闸输出通道:"; font.pixelSize: 16; color: "#9E9E9E" }
                DeviceInfo.CustomSpinBox {
                    id: brakeOutputChannelSpin
                    Layout.preferredWidth: 100; from: -1; to: 15; value: 0
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ========== 行1：松闸反馈（开关+通道+超时 同行） ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text { text: "使用松闸反馈:"; font.pixelSize: 16; color: "#9E9E9E" }
                Switch { id: useReleaseFeedbackSwitch; checked: false }
                Text { text: "反馈通道:"; font.pixelSize: 16; color: "#9E9E9E"
                    opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4 }
                DeviceInfo.CustomSpinBox {
                    id: releasePositionChannelSpin
                    Layout.preferredWidth: 90; from: 0; to: 15; value: 0
                    enabled: useReleaseFeedbackSwitch.checked
                    opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4
                }
                Text { text: "超时:"; font.pixelSize: 16; color: "#9E9E9E"
                    opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4 }
                DeviceInfo.CustomSpinBox {
                    id: releaseTimeoutSpin
                    Layout.preferredWidth: 90; from: 1; to: 60; value: 10
                    enabled: useReleaseFeedbackSwitch.checked
                    opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4
                }
                Text { text: "秒"; font.pixelSize: 14; color: "#666" }
            }

            // ========== 行2：抱闸反馈（开关+通道+超时 同行） ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text { text: "使用抱闸反馈:"; font.pixelSize: 16; color: "#9E9E9E" }
                Switch { id: useBrakeFeedbackSwitch; checked: false }
                Text { text: "反馈通道:"; font.pixelSize: 16; color: "#9E9E9E"
                    opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4 }
                DeviceInfo.CustomSpinBox {
                    id: brakePositionChannelSpin
                    Layout.preferredWidth: 90; from: 0; to: 15; value: 0
                    enabled: useBrakeFeedbackSwitch.checked
                    opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4
                }
                Text { text: "超时:"; font.pixelSize: 16; color: "#9E9E9E"
                    opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4 }
                DeviceInfo.CustomSpinBox {
                    id: brakeTimeoutSpin
                    Layout.preferredWidth: 90; from: 1; to: 60; value: 10
                    enabled: useBrakeFeedbackSwitch.checked
                    opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4
                }
                Text { text: "秒"; font.pixelSize: 14; color: "#666" }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ========== 行3-5：原有参数（4列紧凑） ==========
            GridLayout {
                Layout.fillWidth: true
                columns: 8
                columnSpacing: 6
                rowSpacing: 6

                Text { text: "抱闸保持:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: holdTimeField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "松闸保持:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: releaseTimeField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "抱闸动作延时:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: brakeDelayField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "抱闸释放延时:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: releaseDelayField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }

                Text { text: "抱闸检测延时:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: detectDelayField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "抱闸故障延时:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: faultDelayField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "抱闸动作电流:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: brakeCurrentField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "抱闸释放电流:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: releaseCurrentField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }

                Text { text: "抱闸动作电压:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: brakeVoltageField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Text { text: "抱闸释放电压:"; font.pixelSize: 16; color: "#9E9E9E"; Layout.alignment: Qt.AlignRight }
                DeviceInfo.CustomTextField { id: releaseVoltageField; Layout.preferredWidth: 80; text: "0"; placeholderText: "0"; keyboardManager: root.keyboardManager }
                Item { Layout.columnSpan: 4 }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ========== 行6：语音配置（3列） ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text { text: "松闸预警:"; font.pixelSize: 16; color: "#9E9E9E" }
                DeviceInfo.CustomTextField {
                    id: releaseWarningVoiceField; Layout.fillWidth: true
                    text: "制动器" + (root.brakeIndex + 1) + "松闸"; placeholderText: "松闸预警音频"
                    keyboardManager: root.keyboardManager
                }
                Text { text: "松闸失败:"; font.pixelSize: 16; color: "#9E9E9E" }
                DeviceInfo.CustomTextField {
                    id: releaseFailureVoiceField; Layout.fillWidth: true
                    text: "制动器" + (root.brakeIndex + 1) + "松闸失败"; placeholderText: "松闸失败音频"
                    keyboardManager: root.keyboardManager
                }
                Text { text: "抱闸失败:"; font.pixelSize: 16; color: "#9E9E9E" }
                DeviceInfo.CustomTextField {
                    id: brakeFailureVoiceField; Layout.fillWidth: true
                    text: "制动器" + (root.brakeIndex + 1) + "抱闸失败"; placeholderText: "抱闸失败音频"
                    keyboardManager: root.keyboardManager
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

            // ========== 行7：LED状态 + 操作按钮 ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Row {
                    spacing: 6
                    Rectangle { id: releasePositionLed; width: 14; height: 14; radius: 7; color: "#475569"; border.width: 1; border.color: "#1e3a5f"
                        anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "松闸到位"; font.pixelSize: 14; color: "#7dd3fc"; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 6
                    Rectangle { id: brakePositionLed; width: 14; height: 14; radius: 7; color: "#475569"; border.width: 1; border.color: "#1e3a5f"
                        anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "抱闸到位"; font.pixelSize: 14; color: "#7dd3fc"; anchors.verticalCenter: parent.verticalCenter }
                }

                Item { Layout.fillWidth: true }

                Button {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 38
                    text: "松 闸"; font.pixelSize: 15; font.bold: true
                    background: Rectangle { color: parent.pressed ? "#166534" : parent.hovered ? "#15803d" : "#16a34a"; radius: 4 }
                    contentItem: Text { text: parent.text; font: parent.font; color: "#fff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        console.log("[BrakeConfigPanel] 松闸 制动器", root.brakeIndex + 1)
                        var beltNum = 1
                        if (releaseWarningVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
                            var audioPath = buildAudioPath(beltNum, releaseWarningVoiceField.text)
                            var ttsText = beltNum + "号皮带" + (root.brakeIndex + 1) + "号制动器准备松闸，请注意安全"
                            alarmPlayback.playAlarm(releaseWarningVoiceField.text, ttsText, audioPath, true, "count", 1, 5)
                        }
                        var ch = releaseOutputChannelSpin.value
                        var topic = "belt_control/do/module1/cmd"
                        var cmd = JSON.stringify({"action": "set", "channel": ch, "value": 1})
                        if (typeof mqttController !== "undefined") { mqttController.publish(topic, cmd, 1, false) }
                        if (useReleaseFeedbackSwitch.checked) { root.waitingForRelease = true; releaseTimeoutTimer.restart() }
                    }
                }
                Button {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 38
                    text: "抱 闸"; font.pixelSize: 15; font.bold: true
                    background: Rectangle { color: parent.pressed ? "#9a3412" : parent.hovered ? "#c2410c" : "#ea580c"; radius: 4 }
                    contentItem: Text { text: parent.text; font: parent.font; color: "#fff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        console.log("[BrakeConfigPanel] 抱闸 制动器", root.brakeIndex + 1)
                        var ch = releaseOutputChannelSpin.value
                        var topic = "belt_control/do/module1/cmd"
                        var cmd = JSON.stringify({"action": "set", "channel": ch, "value": 0})
                        if (typeof mqttController !== "undefined") { mqttController.publish(topic, cmd, 1, false) }
                        var brCh = brakeOutputChannelSpin.value
                        if (brCh >= 0) {
                            var cmd2 = JSON.stringify({"action": "set", "channel": brCh, "value": 1})
                            if (typeof mqttController !== "undefined") { mqttController.publish(topic, cmd2, 1, false) }
                        }
                        if (useBrakeFeedbackSwitch.checked) { root.waitingForBrake = true; brakeTimeoutTimer.restart() }
                    }
                }
                Button {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 38
                    text: "停 止"; font.pixelSize: 15; font.bold: true
                    background: Rectangle { color: parent.pressed ? "#7f1d1d" : parent.hovered ? "#991b1b" : "#dc2626"; radius: 4 }
                    contentItem: Text { text: parent.text; font: parent.font; color: "#fff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: {
                        console.log("[BrakeConfigPanel] 停止 制动器", root.brakeIndex + 1)
                        releaseTimeoutTimer.stop(); brakeTimeoutTimer.stop()
                        root.waitingForRelease = false; root.waitingForBrake = false
                        var topic = "belt_control/do/module1/cmd"
                        var ch1 = releaseOutputChannelSpin.value
                        if (typeof mqttController !== "undefined") {
                            mqttController.publish(topic, JSON.stringify({"action": "set", "channel": ch1, "value": 0}), 1, false)
                            var brCh = brakeOutputChannelSpin.value
                            if (brCh >= 0) { mqttController.publish(topic, JSON.stringify({"action": "set", "channel": brCh, "value": 0}), 1, false) }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }  // ColumnLayout
    }  // contentArea

    // ========== Timer ==========
    Timer {
        id: releaseTimeoutTimer
        interval: releaseTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            console.log("[BrakeConfigPanel] 制动器", root.brakeIndex + 1, "松闸反馈超时")
            root.waitingForRelease = false
            var ch = releaseOutputChannelSpin.value
            var topic = "belt_control/do/module1/cmd"
            var cmd = JSON.stringify({"action": "set", "channel": ch, "value": 0})
            if (typeof mqttController !== "undefined") { mqttController.publish(topic, cmd, 1, false) }
            if (typeof alarmPlayback !== "undefined") {
                var beltNum = 1
                var audioPath = buildAudioPath(beltNum, releaseFailureVoiceField.text)
                var ttsText = beltNum + "号皮带" + (root.brakeIndex + 1) + "号制动器松闸失败"
                alarmPlayback.playAlarm(releaseFailureVoiceField.text, ttsText, audioPath, true, "count", 3, 5)
            }
        }
    }
    Timer {
        id: brakeTimeoutTimer
        interval: brakeTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            console.log("[BrakeConfigPanel] 制动器", root.brakeIndex + 1, "抱闸反馈超时")
            root.waitingForBrake = false
            var brCh = brakeOutputChannelSpin.value
            if (brCh >= 0) {
                var topic = "belt_control/do/module1/cmd"
                var cmd = JSON.stringify({"action": "set", "channel": brCh, "value": 0})
                if (typeof mqttController !== "undefined") { mqttController.publish(topic, cmd, 1, false) }
            }
            if (typeof alarmPlayback !== "undefined") {
                var beltNum = 1
                var audioPath = buildAudioPath(beltNum, brakeFailureVoiceField.text)
                var ttsText = beltNum + "号皮带" + (root.brakeIndex + 1) + "号制动器抱闸失败"
                alarmPlayback.playAlarm(brakeFailureVoiceField.text, ttsText, audioPath, true, "count", 3, 5)
            }
        }
    }

    // ========== DI反馈监听 ==========
    Connections {
        target: typeof mqttController !== "undefined" ? mqttController : null
        function onBitChanged(moduleType, channel, value) {
            if (moduleType !== "di") return
            if (useReleaseFeedbackSwitch.checked && channel === releasePositionChannelSpin.value) {
                releasePositionLed.color = (value === 1) ? "#22c55e" : "#475569"
                if (value === 1 && root.waitingForRelease) {
                    root.waitingForRelease = false; releaseTimeoutTimer.stop()
                    console.log("[BrakeConfigPanel] 制动器", root.brakeIndex + 1, "松闸到位反馈已收到")
                }
            }
            if (useBrakeFeedbackSwitch.checked && channel === brakePositionChannelSpin.value) {
                brakePositionLed.color = (value === 1) ? "#22c55e" : "#475569"
                if (value === 1 && root.waitingForBrake) {
                    root.waitingForBrake = false; brakeTimeoutTimer.stop()
                    console.log("[BrakeConfigPanel] 制动器", root.brakeIndex + 1, "抱闸到位反馈已收到")
                }
            }
        }
    }

    // ========== 导航函数 ==========
    function getParamFieldCount() { return 18 }

    function triggerParamInput(paramIndex) {
        console.log("[BrakeConfigPanel] triggerParamInput:", paramIndex)
        var fields = [holdTimeField, releaseTimeField, brakeDelayField, releaseDelayField,
                      detectDelayField, faultDelayField, brakeCurrentField, releaseCurrentField,
                      brakeVoltageField, releaseVoltageField,
                      releaseWarningVoiceField, releaseFailureVoiceField, brakeFailureVoiceField]
        if (paramIndex < fields.length && virtualKeyboard && fields[paramIndex]) {
            var mode = paramIndex >= 10 ? "text" : "numeric"
            virtualKeyboard.openForField(fields[paramIndex], function(v) {}, mode, root)
        }
    }

    function toggleUsageStatus() {
        if (statusEnabled.checked) { statusDisabled.checked = true } else { statusEnabled.checked = true }
    }

    function triggerButton(buttonIndex) {
        console.log("[BrakeConfigPanel] triggerButton:", buttonIndex)
    }

    function buildAudioPath(beltNum, fileName) {
        if (typeof audioPathMapper !== "undefined") { return audioPathMapper.getAudioPath(beltNum, fileName) }
        return "/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/" + beltNum + "#PD/" + fileName + ".wav"
    }

    // ========== 持久化 ==========
    function collectConfig() {
        var config = {}
        config["enabled"] = statusEnabled.checked
        config["release_output_channel"] = releaseOutputChannelSpin.value
        config["brake_output_channel"] = brakeOutputChannelSpin.value
        config["use_release_feedback"] = useReleaseFeedbackSwitch.checked ? 1 : 0
        config["release_feedback_channel"] = releasePositionChannelSpin.value
        config["release_feedback_timeout"] = releaseTimeoutSpin.value
        config["use_brake_feedback"] = useBrakeFeedbackSwitch.checked ? 1 : 0
        config["brake_feedback_channel"] = brakePositionChannelSpin.value
        config["brake_feedback_timeout"] = brakeTimeoutSpin.value
        config["hold_time"] = parseFloat(holdTimeField.text) || 0
        config["release_time"] = parseFloat(releaseTimeField.text) || 0
        config["brake_delay"] = parseFloat(brakeDelayField.text) || 0
        config["release_delay"] = parseFloat(releaseDelayField.text) || 0
        config["detect_delay"] = parseFloat(detectDelayField.text) || 0
        config["fault_delay"] = parseFloat(faultDelayField.text) || 0
        config["brake_current"] = parseFloat(brakeCurrentField.text) || 0
        config["release_current"] = parseFloat(releaseCurrentField.text) || 0
        config["brake_voltage"] = parseFloat(brakeVoltageField.text) || 0
        config["release_voltage"] = parseFloat(releaseVoltageField.text) || 0
        config["release_warning_voice"] = releaseWarningVoiceField.text
        config["release_failure_voice"] = releaseFailureVoiceField.text
        config["brake_failure_voice"] = brakeFailureVoiceField.text
        return config
    }

    function saveBrakeConfig() {
        console.log("[BrakeConfigPanel] 保存制动器配置 - 设备:", root.deviceId, "制动器:", root.brakeIndex + 1)
        var config = collectConfig()
        var success = deviceConfigMgr.saveBrakeConfig(root.deviceId, root.brakeIndex, config)
        if (success) { console.log("[BrakeConfigPanel] 保存成功") }
        else { console.log("[BrakeConfigPanel] 保存失败") }
        return success
    }

    function loadBrakeConfig() {
        console.log("[BrakeConfigPanel] 加载制动器配置 - 设备:", root.deviceId, "制动器:", root.brakeIndex + 1)
        var config = deviceConfigMgr.loadBrakeConfig(root.deviceId, root.brakeIndex)
        if (!config || Object.keys(config).length === 0) {
            console.log("[BrakeConfigPanel] 未找到配置，使用默认值")
            return false
        }
        console.log("[BrakeConfigPanel] 应用配置:", JSON.stringify(config))
        if (config.hasOwnProperty("enabled")) { statusEnabled.checked = config["enabled"]; statusDisabled.checked = !config["enabled"] }
        if (config.hasOwnProperty("release_output_channel")) { releaseOutputChannelSpin.value = config["release_output_channel"] }
        if (config.hasOwnProperty("brake_output_channel")) { brakeOutputChannelSpin.value = config["brake_output_channel"] }
        if (config.hasOwnProperty("use_release_feedback")) { useReleaseFeedbackSwitch.checked = config["use_release_feedback"] === 1 }
        if (config.hasOwnProperty("release_feedback_channel")) { releasePositionChannelSpin.value = config["release_feedback_channel"] }
        if (config.hasOwnProperty("release_feedback_timeout")) { releaseTimeoutSpin.value = config["release_feedback_timeout"] }
        if (config.hasOwnProperty("use_brake_feedback")) { useBrakeFeedbackSwitch.checked = config["use_brake_feedback"] === 1 }
        if (config.hasOwnProperty("brake_feedback_channel")) { brakePositionChannelSpin.value = config["brake_feedback_channel"] }
        if (config.hasOwnProperty("brake_feedback_timeout")) { brakeTimeoutSpin.value = config["brake_feedback_timeout"] }
        if (config.hasOwnProperty("hold_time")) { holdTimeField.text = config["hold_time"].toString() }
        if (config.hasOwnProperty("release_time")) { releaseTimeField.text = config["release_time"].toString() }
        if (config.hasOwnProperty("brake_delay")) { brakeDelayField.text = config["brake_delay"].toString() }
        if (config.hasOwnProperty("release_delay")) { releaseDelayField.text = config["release_delay"].toString() }
        if (config.hasOwnProperty("detect_delay")) { detectDelayField.text = config["detect_delay"].toString() }
        if (config.hasOwnProperty("fault_delay")) { faultDelayField.text = config["fault_delay"].toString() }
        if (config.hasOwnProperty("brake_current")) { brakeCurrentField.text = config["brake_current"].toString() }
        if (config.hasOwnProperty("release_current")) { releaseCurrentField.text = config["release_current"].toString() }
        if (config.hasOwnProperty("brake_voltage")) { brakeVoltageField.text = config["brake_voltage"].toString() }
        if (config.hasOwnProperty("release_voltage")) { releaseVoltageField.text = config["release_voltage"].toString() }
        if (config.hasOwnProperty("release_warning_voice")) { releaseWarningVoiceField.text = config["release_warning_voice"] }
        if (config.hasOwnProperty("release_failure_voice")) { releaseFailureVoiceField.text = config["release_failure_voice"] }
        if (config.hasOwnProperty("brake_failure_voice")) { brakeFailureVoiceField.text = config["brake_failure_voice"] }
        return true
    }

    Component.onCompleted: {
        console.log("[BrakeConfigPanel] onCompleted - 制动器:", root.brakeIndex + 1)
        loadBrakeConfig()
    }

    onBrakeIndexChanged: {
        console.log("[BrakeConfigPanel] 制动器索引变化:", root.brakeIndex + 1)
        loadBrakeConfig()
    }
}
