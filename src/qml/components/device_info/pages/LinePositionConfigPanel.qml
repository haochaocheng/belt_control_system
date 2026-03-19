import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-03-18 [Phase 7.48.56]: 沿线点位保护配置面板
Rectangle {
    id: root
    color: "transparent"
    clip: true

    property var keyboardManager: null
    property int focusSubArea: 0
    property int focusParamIndex: 0
    property int focusButtonIndex: 0

    readonly property int lblFs: 21
    readonly property string lblC: "#9E9E9E"
    readonly property int lblW: 140

    property int audioSourceMode: 1
    property int playModeSelection: 0
    property int protectionLevel: 1

    // ========== 标题栏 ==========
    Rectangle {
        id: headerBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 40; color: "#2a3142"; border.color: "#3d4556"; border.width: 1
        Text { anchors.centerIn: parent; text: nameField.text + " 配置"; font.pixelSize: 18; font.bold: true; color: "#E0E0E0" }
    }

    // ========== 参数区域 ==========
    Flickable {
        anchors.top: headerBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 10; contentHeight: paramGrid.height; clip: true

        GridLayout {
            id: paramGrid
            width: parent.width; columns: 4; columnSpacing: 10; rowSpacing: 10

            // Row 0: 保护名称 | 模块类型
            Text { text: "保护名称:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 0 }
            Item { Layout.column: 1; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: nameField.implicitHeight
                DeviceInfo.CustomTextField { id: nameField; anchors.fill: parent; text: ""; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 0 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 0 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "模块类型:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 0 }
            Text { text: "CS模块"; font.pixelSize: root.lblFs; color: "#E0E0E0"; Layout.column: 3; Layout.row: 0 }

            // Row 1: 点位编号 | 通道编号
            Text { text: "点位编号:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 1 }
            Item { Layout.column: 1; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: pointNumberSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: pointNumberSpin; anchors.fill: parent; from: 1; to: 64; value: 1; enabled: false; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 1 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 1 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "通道编号:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 1 }
            Item { Layout.column: 3; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: channelNumberSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: channelNumberSpin; anchors.fill: parent; from: 0; to: 263; value: 0; enabled: false; keyboardManager: root.keyboardManager }
            }

            // Row 2: 保护延时 | 播放次数
            Text { text: "保护延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 2 }
            Item { Layout.column: 1; Layout.row: 2; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: delaySpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: delaySpin; anchors.fill: parent; from: 0; to: 100; value: 10; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 2 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 2 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "播放次数:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 2 }
            Item { Layout.column: 3; Layout.row: 2; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: playCountSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: playCountSpin; anchors.fill: parent; from: 1; to: 100; value: 3; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 3 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 3 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 3: 播放时长 | 数据超时
            Text { text: "播放时长:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 3 }
            Item { Layout.column: 1; Layout.row: 3; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: playDurationSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: playDurationSpin; anchors.fill: parent; from: 1; to: 1000; value: 50; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 4 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 4 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "数据超时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 3 }
            Item { Layout.column: 3; Layout.row: 3; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: dataTimeoutSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: dataTimeoutSpin; anchors.fill: parent; from: 1; to: 60; value: 2; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 5 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 5 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 4: 连接超时 | 播放方式
            Text { text: "连接超时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 4 }
            Item { Layout.column: 1; Layout.row: 4; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: connectionTimeoutSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: connectionTimeoutSpin; anchors.fill: parent; from: 1; to: 120; value: 10; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 6 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 6 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "播放方式:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 4 }
            Item { Layout.column: 3; Layout.row: 4; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: 50
                RowLayout { anchors.fill: parent; spacing: 8
                    Button { id: playModeCountBtn; text: "按次数"; Layout.fillWidth: true; Layout.preferredHeight: 50; checkable: true; checked: root.playModeSelection === 0
                        background: Rectangle { color: playModeCountBtn.checked ? "#0d1b2e" : (playModeCountBtn.hovered ? "#1e2d42" : "#141920"); radius: 6; border.color: playModeCountBtn.checked ? "#00d4ff" : (playModeCountBtn.hovered ? "#2196F3" : "#334155"); border.width: playModeCountBtn.checked ? 2 : 1
                            Rectangle { visible: playModeCountBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#00d4ff" } }
                        contentItem: Item { Row { anchors.centerIn: parent; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: playModeCountBtn.checked ? "#00d4ff" : "#475569"
                                Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: playModeCountBtn.checked ? "#e0f7ff" : "#64748B" } }
                            Text { text: playModeCountBtn.text; font.pixelSize: 16; font.weight: playModeCountBtn.checked ? Font.Medium : Font.Normal; color: playModeCountBtn.checked ? "#00d4ff" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter } } }
                        onClicked: root.playModeSelection = 0 }
                    Button { id: playModeDurationBtn; text: "按时长"; Layout.fillWidth: true; Layout.preferredHeight: 50; checkable: true; checked: root.playModeSelection === 1
                        background: Rectangle { color: playModeDurationBtn.checked ? "#1b1500" : (playModeDurationBtn.hovered ? "#1e2d42" : "#141920"); radius: 6; border.color: playModeDurationBtn.checked ? "#F59E0B" : (playModeDurationBtn.hovered ? "#2196F3" : "#334155"); border.width: playModeDurationBtn.checked ? 2 : 1
                            Rectangle { visible: playModeDurationBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#F59E0B" } }
                        contentItem: Item { Row { anchors.centerIn: parent; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: playModeDurationBtn.checked ? "#F59E0B" : "#475569"
                                Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: playModeDurationBtn.checked ? "#FDE68A" : "#64748B" } }
                            Text { text: playModeDurationBtn.text; font.pixelSize: 16; font.weight: playModeDurationBtn.checked ? Font.Medium : Font.Normal; color: playModeDurationBtn.checked ? "#F59E0B" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter } } }
                        onClicked: root.playModeSelection = 1 }
                }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 7 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 7 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 5: 保护级别 | 超温洒水使能
            Text { text: "保护级别:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 5 }
            Item { Layout.column: 1; Layout.row: 5; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: protectionLevelCombo.implicitHeight
                DeviceInfo.CustomComboBox { id: protectionLevelCombo; anchors.fill: parent; model: ["预警+紧急停车", "预警+正常停车", "仅预警不停车", "不预警不停车"]; currentIndex: 1; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 8 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 8 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "超温洒水:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 5 }
            Item { Layout.column: 3; Layout.row: 5; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: sprinklerSwitch.implicitHeight
                Switch { id: sprinklerSwitch; checked: false }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 9 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 9 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 6: 洒水选择 | 洒水延时
            Text { text: "洒水选择:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 6 }
            Item { Layout.column: 1; Layout.row: 6; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: sprinklerCombo.implicitHeight
                DeviceInfo.CustomComboBox { id: sprinklerCombo; anchors.fill: parent; model: ["洒水1","洒水2","洒水3","洒水4","洒水5","洒水6","洒水7","洒水8"]; currentIndex: 0; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 10 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 10 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
            Text { text: "洒水延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 2; Layout.row: 6 }
            Item { Layout.column: 3; Layout.row: 6; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: sprinklerDelaySpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: sprinklerDelaySpin; anchors.fill: parent; from: 0; to: 300; value: 30; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 11 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 11 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 7: 音频来源
            Text { text: "音频来源:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 7 }
            Item { Layout.column: 1; Layout.row: 7; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: 50
                RowLayout { anchors.fill: parent; spacing: 8
                    Button { id: audioDefaultBtn; text: "默认"; Layout.fillWidth: true; Layout.preferredHeight: 50; checkable: true; checked: root.audioSourceMode === 0
                        background: Rectangle { color: audioDefaultBtn.checked ? "#0d1b2e" : (audioDefaultBtn.hovered ? "#1e2d42" : "#141920"); radius: 6; border.color: audioDefaultBtn.checked ? "#00d4ff" : (audioDefaultBtn.hovered ? "#2196F3" : "#334155"); border.width: audioDefaultBtn.checked ? 2 : 1
                            Rectangle { visible: audioDefaultBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#00d4ff" } }
                        contentItem: Item { Row { anchors.centerIn: parent; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: audioDefaultBtn.checked ? "#00d4ff" : "#475569"
                                Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: audioDefaultBtn.checked ? "#e0f7ff" : "#64748B" } }
                            Text { text: audioDefaultBtn.text; font.pixelSize: 16; font.weight: audioDefaultBtn.checked ? Font.Medium : Font.Normal; color: audioDefaultBtn.checked ? "#00d4ff" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter } } }
                        onClicked: root.audioSourceMode = 0 }
                    Button { id: audioTtsBtn; text: "TTS"; Layout.fillWidth: true; Layout.preferredHeight: 50; checkable: true; checked: root.audioSourceMode === 1
                        background: Rectangle { color: audioTtsBtn.checked ? "#1b1500" : (audioTtsBtn.hovered ? "#1e2d42" : "#141920"); radius: 6; border.color: audioTtsBtn.checked ? "#F59E0B" : (audioTtsBtn.hovered ? "#2196F3" : "#334155"); border.width: audioTtsBtn.checked ? 2 : 1
                            Rectangle { visible: audioTtsBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#F59E0B" } }
                        contentItem: Item { Row { anchors.centerIn: parent; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: audioTtsBtn.checked ? "#F59E0B" : "#475569"
                                Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: audioTtsBtn.checked ? "#FDE68A" : "#64748B" } }
                            Text { text: audioTtsBtn.text; font.pixelSize: 16; font.weight: audioTtsBtn.checked ? Font.Medium : Font.Normal; color: audioTtsBtn.checked ? "#F59E0B" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter } } }
                        onClicked: root.audioSourceMode = 1 }
                }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 12 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 12 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 8: TTS文字
            Text { text: "TTS文字:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 8 }
            Item { Layout.column: 1; Layout.row: 8; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: ttsTextField.implicitHeight
                DeviceInfo.CustomTextField { id: ttsTextField; anchors.fill: parent; text: ""; placeholderText: "TTS合成文本"; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 13 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 13 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }

            // Row 9: 音频文件
            Text { text: "音频文件:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight; Layout.column: 0; Layout.row: 9 }
            Item { Layout.column: 1; Layout.row: 9; Layout.columnSpan: 3; Layout.fillWidth: true; Layout.maximumWidth: 300; implicitHeight: audioFileField.implicitHeight
                DeviceInfo.CustomTextField { id: audioFileField; anchors.fill: parent; text: ""; placeholderText: "音频文件名"; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusParamIndex === 14 ? "#2196F3" : "transparent"; border.width: root.focusParamIndex === 14 ? 3 : 0; radius: 4; z: 10; enabled: false }
            }
        }
    }

    // ========== 函数 ==========
    function getParamFieldCount() { return 15 }

    function applyConfig(config) {
        nameField.text = config.protection_name || ""
        pointNumberSpin.value = (config.channel_number % 100) + 1
        channelNumberSpin.value = config.channel_number || 0
        delaySpin.value = Math.round((config.protection_delay || 1.0) * 10)
        playCountSpin.value = config.play_count || 3
        playDurationSpin.value = Math.round((config.play_duration || 5.0) * 10)
        dataTimeoutSpin.value = config.data_timeout || 2
        connectionTimeoutSpin.value = config.connection_timeout || 10
        root.playModeSelection = (config.play_mode === "duration") ? 1 : 0
        protectionLevelCombo.currentIndex = (config.protection_level !== undefined) ? config.protection_level : 1
        sprinklerSwitch.checked = (config.sprinkler_enabled === 1)
        sprinklerCombo.currentIndex = (config.sprinkler_index > 0) ? (config.sprinkler_index - 1) : 0
        sprinklerDelaySpin.value = config.sprinkler_delay || 30
        root.audioSourceMode = (config.use_text_to_speech === 1) ? 1 : 0
        ttsTextField.text = config.tts_text || ""
        audioFileField.text = config.audio_file || ""
    }

    function applyDefaults(item) {
        nameField.text = item.name || ""
        pointNumberSpin.value = item.pointNumber || 1
        channelNumberSpin.value = item.channelNumber || 0
        delaySpin.value = 10
        playCountSpin.value = 3
        playDurationSpin.value = 50
        dataTimeoutSpin.value = 2
        connectionTimeoutSpin.value = 10
        root.playModeSelection = 0
        protectionLevelCombo.currentIndex = 1
        sprinklerSwitch.checked = false
        sprinklerCombo.currentIndex = 0
        sprinklerDelaySpin.value = 30
        root.audioSourceMode = 1
        ttsTextField.text = (item.name || "") + "保护"
        audioFileField.text = (item.pointNumber || 1) + "号" + (item.groupName || "") + ".wav"
    }

    function getConfig() {
        return {
            "protection_name": nameField.text,
            "module_type": "CS模块",
            "register_address": 5,
            "channel_number": channelNumberSpin.value,
            "protection_delay": delaySpin.value / 10.0,
            "play_count": playCountSpin.value,
            "play_duration": playDurationSpin.value / 10.0,
            "data_timeout": dataTimeoutSpin.value,
            "connection_timeout": connectionTimeoutSpin.value,
            "play_mode": root.playModeSelection === 0 ? "count" : "duration",
            "protection_level": protectionLevelCombo.currentIndex,
            "sprinkler_enabled": sprinklerSwitch.checked ? 1 : 0,
            "sprinkler_index": sprinklerCombo.currentIndex + 1,
            "sprinkler_delay": sprinklerDelaySpin.value,
            "use_text_to_speech": root.audioSourceMode === 1 ? 1 : 0,
            "tts_text": ttsTextField.text,
            "audio_file": audioFileField.text
        }
    }

    function triggerParamInput(paramIndex) {
        switch(paramIndex) {
        case 0: nameField.forceActiveFocus(); break
        case 2: delaySpin.forceActiveFocus(); break
        case 3: playCountSpin.forceActiveFocus(); break
        case 4: playDurationSpin.forceActiveFocus(); break
        case 5: dataTimeoutSpin.forceActiveFocus(); break
        case 6: connectionTimeoutSpin.forceActiveFocus(); break
        case 7: root.playModeSelection = (root.playModeSelection + 1) % 2; break
        case 8: protectionLevelCombo.currentIndex = (protectionLevelCombo.currentIndex + 1) % 4; break
        case 9: sprinklerSwitch.toggle(); break
        case 10: sprinklerCombo.currentIndex = (sprinklerCombo.currentIndex + 1) % 8; break
        case 11: sprinklerDelaySpin.forceActiveFocus(); break
        case 12: root.audioSourceMode = (root.audioSourceMode + 1) % 2; break
        case 13: ttsTextField.forceActiveFocus(); break
        case 14: audioFileField.forceActiveFocus(); break
        }
    }
}