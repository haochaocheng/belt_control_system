import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

// 2026-03-17 [Phase 7.48.51] 张力传感器配置面板
// 参数参照 AnalogInputPage，布局参照 BrakeConfigPanel 8列GridLayout
Rectangle {
    id: root
    color: "transparent"
    clip: true

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int controlIndex: 0      // 0=张力传感器
    property int focusSubArea: 0      // 1=参数区域
    property int focusParamIndex: -1
    property int focusButtonIndex: -1
    property var virtualKeyboard: null

    // ========== 布局常量 ==========
    readonly property int lblFs: 21
    readonly property string lblC: "#9E9E9E"
    readonly property int fldW: 120
    readonly property int lblW: 130
    readonly property int cmbW: 160

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
            text: "张力传感器配置"
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
        GridLayout {
            id: paramGrid
            columns: 8
            columnSpacing: 8
            rowSpacing: 8
            Layout.fillWidth: true

            // ===== Row 0: 传感器启用 + 名称(0) + 单位(1) =====
            Text { text: "传感器启用"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            Switch {
                id: sensorEnabledSwitch
                checked: true
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === -1 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "名称"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            TextField {
                id: nameField
                text: "张力传感器"
                font.pixelSize: 14; color: "#E0E0E0"; Layout.preferredWidth: root.fldW
                background: Rectangle { color: "#3d4556"; radius: 4; border.color: "#556070" }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 0 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "单位"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            ComboBox {
                id: unitCombo
                model: ["kN", "N", "kg", "t", "MPa", "bar"]
                currentIndex: 0
                Layout.preferredWidth: root.cmbW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 1 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }

            // ===== Row 1: 模块类型(2) + 通道号(3) + 输入类型(4) =====
            Text { text: "模块类型"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            ComboBox {
                id: moduleTypeCombo
                model: ["未分配", "模拟量模块1", "模拟量模块2"]
                currentIndex: 1
                Layout.preferredWidth: root.cmbW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 2 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "通道号"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: channelSpin
                from: -1; to: 7; value: -1
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 3 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "输入类型"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            ComboBox {
                id: inputTypeCombo
                model: ["4-20mA电流型", "0-20mA电流型", "0-5V电压型", "0-10V电压型", "1-5V电压型", "PT100热电阻"]
                currentIndex: 0
                Layout.preferredWidth: root.cmbW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 4 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }

            // ===== Row 2: 上限值(5) + 下限值(6) + 量程(7) =====
            Text { text: "上限值"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: upperLimitSpin
                from: 0; to: 99999; value: 100
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 5 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "下限值"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: lowerLimitSpin
                from: 0; to: 99999; value: 0
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 6 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "量程"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: rangeSpin
                from: 1; to: 99999; value: 200
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 7 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }

            // ===== Row 3: 保护延时(8) + 播放次数(9) + 播放时长(10) =====
            Text { text: "保护延时"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: protectionDelaySpin
                from: 0; to: 9999; value: 30
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 8 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "播放次数"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: playCountSpin
                from: 1; to: 99; value: 3
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 9 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Text { text: "播放时长"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            SpinBox {
                id: playDurationSpin
                from: 1; to: 999; value: 10
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 10 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            Item { Layout.columnSpan: 2; Layout.fillWidth: true }
        } // GridLayout end

        // ========== 分隔线 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== 语音配置区 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text { text: "音频来源"; font.pixelSize: root.lblFs; color: root.lblC }
            ButtonGroup { id: audioSourceGroup }
            RadioButton {
                id: audioDefaultRadio; text: "默认"; checked: true
                ButtonGroup.group: audioSourceGroup
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
            }
            RadioButton {
                id: audioTtsRadio; text: "TTS"
                ButtonGroup.group: audioSourceGroup
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
            }

            Item { width: 20 }

            Text { text: "播放方式"; font.pixelSize: root.lblFs; color: root.lblC }
            ButtonGroup { id: playModeGroup }
            RadioButton {
                id: playCountRadio; text: "按次数"; checked: true
                ButtonGroup.group: playModeGroup
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
            }
            RadioButton {
                id: playDurationRadio; text: "按时长"
                ButtonGroup.group: playModeGroup
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 }
            }
        }

        // ========== TTS文本(11) / 音频文件(12) ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: audioTtsRadio.checked ? "TTS文本" : "音频文件"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW }
            TextField {
                id: ttsTextField
                text: "张力传感器报警"
                font.pixelSize: 14; color: "#E0E0E0"
                Layout.fillWidth: true
                visible: audioTtsRadio.checked
                background: Rectangle { color: "#3d4556"; radius: 4; border.color: "#556070" }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 11 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
            TextField {
                id: audioFileField
                text: ""
                font.pixelSize: 14; color: "#E0E0E0"
                Layout.fillWidth: true
                readOnly: true
                visible: audioDefaultRadio.checked
                placeholderText: "自动生成"
                background: Rectangle { color: "#3d4556"; radius: 4; border.color: "#556070" }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 12 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
        }

        // ========== 分隔线2 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== 保护级别(13) + 洒水启用 + 洒水编号(14) ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: "保护级别"; font.pixelSize: root.lblFs; color: root.lblC }
            ComboBox {
                id: protectionLevelCombo
                model: ["仅预警", "预警+正常停车", "预警+紧急停车"]
                currentIndex: 2
                Layout.preferredWidth: root.cmbW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 13 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }

            Item { width: 16 }

            Text { text: "洒水启用"; font.pixelSize: root.lblFs; color: root.lblC }
            Switch {
                id: sprinklerSwitch
                checked: false
            }

            Text { text: "洒水编号"; font.pixelSize: root.lblFs; color: root.lblC }
            SpinBox {
                id: sprinklerIndexSpin
                from: 0; to: 7; value: 0
                enabled: sprinklerSwitch.checked
                Layout.preferredWidth: root.fldW
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 14 ? "#4FC3F7" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }
        }

        // ========== 弹性空间 ==========
        Item { Layout.fillHeight: true }

        // ========== 底部按钮行 ==========
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 16

            Item { Layout.fillWidth: true }

            Button {
                id: saveBtn
                text: "保存"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                background: Rectangle { color: saveBtn.pressed ? "#1e8449" : "#27ae60"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: saveTensionSensorConfig()
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 0 ? "#FFFFFF" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }

            Button {
                id: resetBtn
                text: "重置"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                background: Rectangle { color: resetBtn.pressed ? "#5d6d7e" : "#7f8c8d"; radius: 4 }
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: loadTensionSensorConfig()
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 1 ? "#FFFFFF" : "transparent"; border.width: 2; radius: 4; z: 100 }
            }

            Item { Layout.fillWidth: true }
        }
    } // ColumnLayout end

    // ========== 函数 ==========

    function getParamFieldCount() { return 15 }  // 参数索引 0-14

    function collectConfig() {
        return {
            "sensor_enabled": sensorEnabledSwitch.checked,
            "name": nameField.text,
            "unit": unitCombo.currentText,
            "module_type": moduleTypeCombo.currentText,
            "channel": channelSpin.value,
            "input_type": inputTypeCombo.currentText,
            "upper_limit": upperLimitSpin.value,
            "lower_limit": lowerLimitSpin.value,
            "range_value": rangeSpin.value,
            "protection_delay": protectionDelaySpin.value,
            "play_count": playCountSpin.value,
            "play_duration": playDurationSpin.value,
            "audio_source": audioTtsRadio.checked ? "tts" : "default",
            "play_mode": playCountRadio.checked ? "count" : "duration",
            "tts_text": ttsTextField.text,
            "audio_file": audioFileField.text,
            "protection_level": protectionLevelCombo.currentIndex,
            "sprinkler_enabled": sprinklerSwitch.checked,
            "sprinkler_index": sprinklerIndexSpin.value
        }
    }

    function applyConfig(config) {
        if (!config) return
        if (config.sensor_enabled !== undefined) sensorEnabledSwitch.checked = config.sensor_enabled
        if (config.name !== undefined) nameField.text = config.name
        if (config.unit !== undefined) { var idx = unitCombo.find(config.unit); if (idx >= 0) unitCombo.currentIndex = idx }
        if (config.module_type !== undefined) { var idx2 = moduleTypeCombo.find(config.module_type); if (idx2 >= 0) moduleTypeCombo.currentIndex = idx2 }
        if (config.channel !== undefined) channelSpin.value = config.channel
        if (config.input_type !== undefined) { var idx3 = inputTypeCombo.find(config.input_type); if (idx3 >= 0) inputTypeCombo.currentIndex = idx3 }
        if (config.upper_limit !== undefined) upperLimitSpin.value = config.upper_limit
        if (config.lower_limit !== undefined) lowerLimitSpin.value = config.lower_limit
        if (config.range_value !== undefined) rangeSpin.value = config.range_value
        if (config.protection_delay !== undefined) protectionDelaySpin.value = config.protection_delay
        if (config.play_count !== undefined) playCountSpin.value = config.play_count
        if (config.play_duration !== undefined) playDurationSpin.value = config.play_duration
        if (config.audio_source !== undefined) { audioTtsRadio.checked = (config.audio_source === "tts"); audioDefaultRadio.checked = (config.audio_source !== "tts") }
        if (config.play_mode !== undefined) { playCountRadio.checked = (config.play_mode === "count"); playDurationRadio.checked = (config.play_mode !== "count") }
        if (config.tts_text !== undefined) ttsTextField.text = config.tts_text
        if (config.audio_file !== undefined) audioFileField.text = config.audio_file
        if (config.protection_level !== undefined) protectionLevelCombo.currentIndex = config.protection_level
        if (config.sprinkler_enabled !== undefined) sprinklerSwitch.checked = config.sprinkler_enabled
        if (config.sprinkler_index !== undefined) sprinklerIndexSpin.value = config.sprinkler_index
    }

    function saveTensionSensorConfig() {
        var config = collectConfig()
        console.log("✅ [TensionSensorConfigPanel] 保存张力传感器配置:", JSON.stringify(config))
        if (typeof deviceConfigMgr !== "undefined") {
            deviceConfigMgr.saveTensionSensorConfig(root.deviceId, config)
        }
    }

    function loadTensionSensorConfig() {
        console.log("✅ [TensionSensorConfigPanel] 加载张力传感器配置, deviceId:", root.deviceId)
        if (typeof deviceConfigMgr !== "undefined") {
            var config = deviceConfigMgr.loadTensionSensorConfig(root.deviceId)
            applyConfig(config)
        }
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [TensionSensorConfigPanel] triggerParamInput:", paramIndex)
        switch(paramIndex) {
        case 0: nameField.forceActiveFocus(); break
        case 1: unitCombo.popup.open(); break
        case 2: moduleTypeCombo.popup.open(); break
        case 3: channelSpin.forceActiveFocus(); break
        case 4: inputTypeCombo.popup.open(); break
        case 5: upperLimitSpin.forceActiveFocus(); break
        case 6: lowerLimitSpin.forceActiveFocus(); break
        case 7: rangeSpin.forceActiveFocus(); break
        case 8: protectionDelaySpin.forceActiveFocus(); break
        case 9: playCountSpin.forceActiveFocus(); break
        case 10: playDurationSpin.forceActiveFocus(); break
        case 11: ttsTextField.forceActiveFocus(); break
        case 12: audioFileField.forceActiveFocus(); break
        case 13: protectionLevelCombo.popup.open(); break
        case 14: sprinklerIndexSpin.forceActiveFocus(); break
        }
    }

    function triggerButton(buttonIndex) {
        console.log("✅ [TensionSensorConfigPanel] triggerButton:", buttonIndex)
        switch(buttonIndex) {
        case 0: saveTensionSensorConfig(); break
        case 1: loadTensionSensorConfig(); break
        }
    }

    Component.onCompleted: {
        console.log("✅ [TensionSensorConfigPanel] 初始化完成, deviceId:", root.deviceId)
        loadTensionSensorConfig()
    }
}
