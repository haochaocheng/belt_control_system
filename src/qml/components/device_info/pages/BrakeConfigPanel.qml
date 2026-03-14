import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// 2026-03-14 [Phase 7.48.45]: v3 GridLayout统一对齐版
Rectangle {
    id: root
    implicitWidth: 1400; height: 600; color: "transparent"

    property int deviceId: 1
    property int brakeIndex: 0
    property var keyboardManager: null
    property var virtualKeyboard: null
    property int focusSubArea: 0
    property int focusUsageStatusIndex: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0
    property bool waitingForRelease: false
    property bool waitingForBrake: false

    // 统一尺寸常量
    readonly property int lblW: 110    // 标签宽度
    readonly property int fldW: 80     // 输入框宽度
    readonly property int lblFs: 15    // 标签字号
    readonly property string lblC: "#9E9E9E"  // 标签颜色

    focus: true; activeFocusOnTab: true

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 40; color: "transparent"
        Image { anchors.fill: parent; source: "../images/059.png"; fillMode: Image.Stretch; z: -1 }
        Text { anchors.centerIn: parent; text: (root.brakeIndex + 1) + "号制动器配置"
            font.pixelSize: 16; font.weight: Font.Bold; color: "#E0E0E0" }
    }

    // ========== 内容区域 ==========
    ColumnLayout {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
        spacing: 4

        // ========== 行0：使用状态 + 输出通道 ==========
        GridLayout {
            Layout.fillWidth: true; columns: 6; columnSpacing: 8; rowSpacing: 0
            RadioButton { id: statusEnabled; text: "投入"; checked: true; font.pixelSize: 14
                contentItem: Text { text: statusEnabled.text; font: statusEnabled.font; color: "#E0E0E0"
                    leftPadding: statusEnabled.indicator.width + statusEnabled.spacing; verticalAlignment: Text.AlignVCenter } }
            RadioButton { id: statusDisabled; text: "禁用"; font.pixelSize: 14
                contentItem: Text { text: statusDisabled.text; font: statusDisabled.font; color: "#E0E0E0"
                    leftPadding: statusDisabled.indicator.width + statusDisabled.spacing; verticalAlignment: Text.AlignVCenter } }
            Item { Layout.fillWidth: true }
            Text { text: "松闸输出通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight }
            DeviceInfo.CustomSpinBox { id: releaseOutputChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0 }
            Row { spacing: 8
                Text { text: "抱闸输出通道:"; font.pixelSize: root.lblFs; color: root.lblC; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomSpinBox { id: brakeOutputChannelSpin; width: root.fldW; from: -1; to: 15; value: 0 }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

        // ========== 行1-2：反馈配置（6列GridLayout对齐） ==========
        GridLayout {
            Layout.fillWidth: true; columns: 6; columnSpacing: 8; rowSpacing: 6
            // 行1：松闸反馈
            Text { text: "使用松闸反馈:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; Layout.alignment: Qt.AlignRight }
            Switch { id: useReleaseFeedbackSwitch; checked: false }
            Text { text: "反馈通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight
                opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: releasePositionChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0
                enabled: useReleaseFeedbackSwitch.checked; opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4 }
            Text { text: "超时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight
                opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: releaseTimeoutSpin; Layout.preferredWidth: root.fldW; from: 1; to: 60; value: 10
                enabled: useReleaseFeedbackSwitch.checked; opacity: useReleaseFeedbackSwitch.checked ? 1.0 : 0.4 }
            // 行2：抱闸反馈
            Text { text: "使用抱闸反馈:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; Layout.alignment: Qt.AlignRight }
            Switch { id: useBrakeFeedbackSwitch; checked: false }
            Text { text: "反馈通道:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight
                opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: brakePositionChannelSpin; Layout.preferredWidth: root.fldW; from: 0; to: 15; value: 0
                enabled: useBrakeFeedbackSwitch.checked; opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4 }
            Text { text: "超时(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight
                opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4 }
            DeviceInfo.CustomSpinBox { id: brakeTimeoutSpin; Layout.preferredWidth: root.fldW; from: 1; to: 60; value: 10
                enabled: useBrakeFeedbackSwitch.checked; opacity: useBrakeFeedbackSwitch.checked ? 1.0 : 0.4 }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

        // ========== 行3-5：原有参数（4列GridLayout，每列=Row(标签+输入框)） ==========
        GridLayout {
            Layout.fillWidth: true; columns: 4; columnSpacing: 4; rowSpacing: 6
            // 行3
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸保持:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: holdTimeField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "松闸保持:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: releaseTimeField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸动作延时:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: brakeDelayField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸释放延时:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: releaseDelayField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            // 行4
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸检测延时:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: detectDelayField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸故障延时:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: faultDelayField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸动作电流:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: brakeCurrentField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸释放电流:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: releaseCurrentField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            // 行5
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸动作电压:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: brakeVoltageField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Row { spacing: 2; Layout.fillWidth: true
                Text { text: "抱闸释放电压:"; font.pixelSize: root.lblFs; color: root.lblC; width: root.lblW; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                DeviceInfo.CustomTextField { id: releaseVoltageField; width: root.fldW; text: "0"; keyboardManager: root.keyboardManager } }
            Item { Layout.fillWidth: true }
            Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

        // ========== 行6：语音配置（6列GridLayout对齐） ==========
        GridLayout {
            Layout.fillWidth: true; columns: 6; columnSpacing: 4; rowSpacing: 0
            Text { text: "松闸预警:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight }
            DeviceInfo.CustomTextField { id: releaseWarningVoiceField; Layout.fillWidth: true
                text: "制动器" + (root.brakeIndex + 1) + "松闸"; keyboardManager: root.keyboardManager }
            Text { text: "松闸失败:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight }
            DeviceInfo.CustomTextField { id: releaseFailureVoiceField; Layout.fillWidth: true
                text: "制动器" + (root.brakeIndex + 1) + "松闸失败"; keyboardManager: root.keyboardManager }
            Text { text: "抱闸失败:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.alignment: Qt.AlignRight }
            DeviceInfo.CustomTextField { id: brakeFailureVoiceField; Layout.fillWidth: true
                text: "制动器" + (root.brakeIndex + 1) + "抱闸失败"; keyboardManager: root.keyboardManager }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#334155" }

        // ========== 行7：LED + 按钮 ==========
        RowLayout {
            Layout.fillWidth: true; spacing: 15
            Row { spacing: 6
                Rectangle { id: releasePositionLed; width: 14; height: 14; radius: 7; color: "#475569"; border.width: 1; border.color: "#1e3a5f"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "松闸到位"; font.pixelSize: 14; color: "#7dd3fc"; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 6
                Rectangle { id: brakePositionLed; width: 14; height: 14; radius: 7; color: "#475569"; border.width: 1; border.color: "#1e3a5f"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "抱闸到位"; font.pixelSize: 14; color: "#7dd3fc"; anchors.verticalCenter: parent.verticalCenter }
            }
            Item { Layout.fillWidth: true }
            Button { Layout.preferredWidth: 100; Layout.preferredHeight: 38; text: "松 闸"; font.pixelSize: 15; font.bold: true
                background: Rectangle { color: parent.pressed ? "#166534" : parent.hovered ? "#15803d" : "#16a34a"; radius: 4 }
                contentItem: Text { text: parent.text; font: parent.font; color: "#fff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: { doRelease() } }
            Button { Layout.preferredWidth: 100; Layout.preferredHeight: 38; text: "抱 闸"; font.pixelSize: 15; font.bold: true
                background: Rectangle { color: parent.pressed ? "#9a3412" : parent.hovered ? "#c2410c" : "#ea580c"; radius: 4 }
                contentItem: Text { text: parent.text; font: parent.font; color: "#fff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: { doBrake() } }
            Button { Layout.preferredWidth: 100; Layout.preferredHeight: 38; text: "停 止"; font.pixelSize: 15; font.bold: true
                background: Rectangle { color: parent.pressed ? "#7f1d1d" : parent.hovered ? "#991b1b" : "#dc2626"; radius: 4 }
                contentItem: Text { text: parent.text; font: parent.font; color: "#fff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: { doStop() } }
        }

        Item { Layout.fillHeight: true }
    }

    // ========== Timer ==========
    Timer { id: releaseTimeoutTimer; interval: releaseTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            console.log("[BrakeConfigPanel] 制动器", root.brakeIndex + 1, "松闸反馈超时")
            root.waitingForRelease = false
            mqttPublish(releaseOutputChannelSpin.value, 0)
            playVoice(releaseFailureVoiceField.text, "松闸失败")
        }
    }
    Timer { id: brakeTimeoutTimer; interval: brakeTimeoutSpin.value * 1000; repeat: false
        onTriggered: {
            console.log("[BrakeConfigPanel] 制动器", root.brakeIndex + 1, "抱闸反馈超时")
            root.waitingForBrake = false
            if (brakeOutputChannelSpin.value >= 0) mqttPublish(brakeOutputChannelSpin.value, 0)
            playVoice(brakeFailureVoiceField.text, "抱闸失败")
        }
    }

    // ========== DI反馈监听 ==========
    Connections {
        target: typeof mqttController !== "undefined" ? mqttController : null
        function onBitChanged(moduleType, channel, value) {
            if (moduleType !== "di") return
            if (useReleaseFeedbackSwitch.checked && channel === releasePositionChannelSpin.value) {
                releasePositionLed.color = (value === 1) ? "#22c55e" : "#475569"
                if (value === 1 && root.waitingForRelease) { root.waitingForRelease = false; releaseTimeoutTimer.stop() }
            }
            if (useBrakeFeedbackSwitch.checked && channel === brakePositionChannelSpin.value) {
                brakePositionLed.color = (value === 1) ? "#22c55e" : "#475569"
                if (value === 1 && root.waitingForBrake) { root.waitingForBrake = false; brakeTimeoutTimer.stop() }
            }
        }
    }

    // ========== 操作函数 ==========
    function mqttPublish(ch, val) {
        var topic = "belt_control/do/module1/cmd"
        var cmd = JSON.stringify({"action": "set", "channel": ch, "value": val})
        if (typeof mqttController !== "undefined") mqttController.publish(topic, cmd, 1, false)
    }
    function playVoice(fileName, desc) {
        if (typeof alarmPlayback === "undefined") return
        var beltNum = 1
        var audioPath = buildAudioPath(beltNum, fileName)
        var ttsText = beltNum + "号皮带" + (root.brakeIndex + 1) + "号制动器" + desc
        alarmPlayback.playAlarm(fileName, ttsText, audioPath, true, "count", 3, 5)
    }
    function doRelease() {
        console.log("[BrakeConfigPanel] 松闸 制动器", root.brakeIndex + 1)
        playVoice(releaseWarningVoiceField.text, "准备松闸，请注意安全")
        mqttPublish(releaseOutputChannelSpin.value, 1)
        if (useReleaseFeedbackSwitch.checked) { root.waitingForRelease = true; releaseTimeoutTimer.restart() }
    }
    function doBrake() {
        console.log("[BrakeConfigPanel] 抱闸 制动器", root.brakeIndex + 1)
        mqttPublish(releaseOutputChannelSpin.value, 0)
        if (brakeOutputChannelSpin.value >= 0) mqttPublish(brakeOutputChannelSpin.value, 1)
        if (useBrakeFeedbackSwitch.checked) { root.waitingForBrake = true; brakeTimeoutTimer.restart() }
    }
    function doStop() {
        console.log("[BrakeConfigPanel] 停止 制动器", root.brakeIndex + 1)
        releaseTimeoutTimer.stop(); brakeTimeoutTimer.stop()
        root.waitingForRelease = false; root.waitingForBrake = false
        mqttPublish(releaseOutputChannelSpin.value, 0)
        if (brakeOutputChannelSpin.value >= 0) mqttPublish(brakeOutputChannelSpin.value, 0)
    }

    // ========== 导航 ==========
    function getParamFieldCount() { return 13 }
    function triggerParamInput(idx) {
        var fields = [holdTimeField, releaseTimeField, brakeDelayField, releaseDelayField,
                      detectDelayField, faultDelayField, brakeCurrentField, releaseCurrentField,
                      brakeVoltageField, releaseVoltageField,
                      releaseWarningVoiceField, releaseFailureVoiceField, brakeFailureVoiceField]
        if (idx < fields.length && virtualKeyboard && fields[idx]) {
            virtualKeyboard.openForField(fields[idx], function(v) {}, idx >= 10 ? "text" : "numeric", root)
        }
    }
    function toggleUsageStatus() { if (statusEnabled.checked) statusDisabled.checked = true; else statusEnabled.checked = true }
    function triggerButton(idx) { if (idx===0) doRelease(); else if (idx===1) doBrake(); else if (idx===2) doStop() }
    function buildAudioPath(beltNum, fileName) {
        if (typeof audioPathMapper !== "undefined") return audioPathMapper.getAudioPath(beltNum, fileName)
        return "/home/linaro/belt-control-data/audio/paddlespeech-fastspeech2_csmsc-spk0/" + beltNum + "#PD/" + fileName + ".wav"
    }

    // ========== 持久化 ==========
    function collectConfig() {
        return {
            "enabled": statusEnabled.checked,
            "release_output_channel": releaseOutputChannelSpin.value,
            "brake_output_channel": brakeOutputChannelSpin.value,
            "use_release_feedback": useReleaseFeedbackSwitch.checked ? 1 : 0,
            "release_feedback_channel": releasePositionChannelSpin.value,
            "release_feedback_timeout": releaseTimeoutSpin.value,
            "use_brake_feedback": useBrakeFeedbackSwitch.checked ? 1 : 0,
            "brake_feedback_channel": brakePositionChannelSpin.value,
            "brake_feedback_timeout": brakeTimeoutSpin.value,
            "hold_time": parseFloat(holdTimeField.text) || 0,
            "release_time": parseFloat(releaseTimeField.text) || 0,
            "brake_delay": parseFloat(brakeDelayField.text) || 0,
            "release_delay": parseFloat(releaseDelayField.text) || 0,
            "detect_delay": parseFloat(detectDelayField.text) || 0,
            "fault_delay": parseFloat(faultDelayField.text) || 0,
            "brake_current": parseFloat(brakeCurrentField.text) || 0,
            "release_current": parseFloat(releaseCurrentField.text) || 0,
            "brake_voltage": parseFloat(brakeVoltageField.text) || 0,
            "release_voltage": parseFloat(releaseVoltageField.text) || 0,
            "release_warning_voice": releaseWarningVoiceField.text,
            "release_failure_voice": releaseFailureVoiceField.text,
            "brake_failure_voice": brakeFailureVoiceField.text
        }
    }
    function saveBrakeConfig() {
        var config = collectConfig()
        var success = deviceConfigMgr.saveBrakeConfig(root.deviceId, root.brakeIndex, config)
        console.log(success ? "[BrakeConfigPanel] 保存成功" : "[BrakeConfigPanel] 保存失败")
        return success
    }
    function loadBrakeConfig() {
        var config = deviceConfigMgr.loadBrakeConfig(root.deviceId, root.brakeIndex)
        if (!config || Object.keys(config).length === 0) return false
        if (config.hasOwnProperty("enabled")) { statusEnabled.checked = config["enabled"]; statusDisabled.checked = !config["enabled"] }
        if (config.hasOwnProperty("release_output_channel")) releaseOutputChannelSpin.value = config["release_output_channel"]
        if (config.hasOwnProperty("brake_output_channel")) brakeOutputChannelSpin.value = config["brake_output_channel"]
        if (config.hasOwnProperty("use_release_feedback")) useReleaseFeedbackSwitch.checked = (config["use_release_feedback"] === 1)
        if (config.hasOwnProperty("release_feedback_channel")) releasePositionChannelSpin.value = config["release_feedback_channel"]
        if (config.hasOwnProperty("release_feedback_timeout")) releaseTimeoutSpin.value = config["release_feedback_timeout"]
        if (config.hasOwnProperty("use_brake_feedback")) useBrakeFeedbackSwitch.checked = (config["use_brake_feedback"] === 1)
        if (config.hasOwnProperty("brake_feedback_channel")) brakePositionChannelSpin.value = config["brake_feedback_channel"]
        if (config.hasOwnProperty("brake_feedback_timeout")) brakeTimeoutSpin.value = config["brake_feedback_timeout"]
        if (config.hasOwnProperty("hold_time")) holdTimeField.text = config["hold_time"].toString()
        if (config.hasOwnProperty("release_time")) releaseTimeField.text = config["release_time"].toString()
        if (config.hasOwnProperty("brake_delay")) brakeDelayField.text = config["brake_delay"].toString()
        if (config.hasOwnProperty("release_delay")) releaseDelayField.text = config["release_delay"].toString()
        if (config.hasOwnProperty("detect_delay")) detectDelayField.text = config["detect_delay"].toString()
        if (config.hasOwnProperty("fault_delay")) faultDelayField.text = config["fault_delay"].toString()
        if (config.hasOwnProperty("brake_current")) brakeCurrentField.text = config["brake_current"].toString()
        if (config.hasOwnProperty("release_current")) releaseCurrentField.text = config["release_current"].toString()
        if (config.hasOwnProperty("brake_voltage")) brakeVoltageField.text = config["brake_voltage"].toString()
        if (config.hasOwnProperty("release_voltage")) releaseVoltageField.text = config["release_voltage"].toString()
        if (config.hasOwnProperty("release_warning_voice")) releaseWarningVoiceField.text = config["release_warning_voice"]
        if (config.hasOwnProperty("release_failure_voice")) releaseFailureVoiceField.text = config["release_failure_voice"]
        if (config.hasOwnProperty("brake_failure_voice")) brakeFailureVoiceField.text = config["brake_failure_voice"]
        return true
    }
    Component.onCompleted: { loadBrakeConfig() }
    onBrakeIndexChanged: { loadBrakeConfig() }
}
