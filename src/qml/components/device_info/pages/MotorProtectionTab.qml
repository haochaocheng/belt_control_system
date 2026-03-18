import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// 2026-03-10 [Phase 7.48.29]: 统一电机保护Tab组件
// 替代9个独立保护Tab文件（CurrentProtectionTab, FrontBearingTempTab 等）
// 参考 AnalogInputPage 的 GridLayout 4列布局
Rectangle {
    id: root
    color: "transparent"

    // ========== 对外属性 ==========
    property int tabIndex: 1
    property string protectionName: "电流保护"
    property string defaultUnit: "A"
    property real defaultUpperLimit: 80
    property real defaultLowerLimit: 0
    property real defaultRange: 100
    property string defaultInputType: "4-20mA电流型"
    property int defaultProtectionDelay: 30
    property real defaultFilterDelay: 5.0
    property int defaultProtectionLevel: 3
    property bool defaultSprinklerEnabled: false
    property int motorIndex: 0
    property int deviceId: 1

    // ========== 焦点属性 ==========
    property int focusParamIndex: 0
    property var virtualKeyboard: null
    signal requestFocusParamIndex(int paramIndex)

    // ========== 音频来源模式 ==========
    property string audioSourceMode: "default"  // "default" or "tts"

    // ✅ 2026-03-10 [Phase 7.48.32]: 切换音频来源时自动更新音频文件名
    onAudioSourceModeChanged: {
        if (audioFileField) {
            audioFileField.text = getAudioFileName(root.protectionName)
        }
    }

    ScrollView {
        id: paramScrollView
        anchors.fill: parent
        clip: true

        GridLayout {
            id: paramGrid
            width: paramScrollView.width * 0.9
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            // ========== Row 0: 保护名称 | 播放次数 ==========
            Text {
                text: "保护名称:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 0
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: protectionNameText.implicitHeight
                Text {
                    id: protectionNameText
                    anchors.fill: parent
                    text: root.protectionName
                    font.pixelSize: 21; color: "#E0E0E0"
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(0); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "播放次数:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 0
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: playCountSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: playCountSpin
                    anchors.fill: parent
                    from: 1; to: 100; value: 3
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(1); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 1) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 1: 模块类型 | 播放时长 ==========
            Text {
                text: "模块类型:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 1
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: moduleTypeCombo.implicitHeight
                DeviceInfo.CustomComboBox {
                    id: moduleTypeCombo
                    anchors.fill: parent
                    model: ["模拟量模块1", "模拟量模块2", "未分配"]
                    currentIndex: 0
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(2); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "播放时长:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 1
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: playDurationSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: playDurationSpin
                    anchors.fill: parent
                    from: 0; to: 6000; value: 50
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(3); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 2: 音频来源 | TTS文字 ==========
            // ✅ 2026-03-10 [Phase 7.48.32]: 音频来源按钮组升级为Cyberpunk工业风（匹配AnalogInputPage）
            // 旧代码：简单的 Row { Button "默认" / Button "TTS" } 蓝色高亮
            Text {
                text: "音频来源:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 2
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 48

                RowLayout {
                    id: audioSourceButtonGroup
                    anchors.fill: parent
                    spacing: 8

                    // [默认] 按钮 - 深蓝背景 + 青色边框 + LED点
                    Button {
                        id: defaultAudioButton
                        text: "默认"
                        checkable: true
                        checked: root.audioSourceMode === "default"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        background: Rectangle {
                            color: defaultAudioButton.checked ? "#0a1929" :
                                   (defaultAudioButton.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: defaultAudioButton.checked ? "#00d4ff" :
                                          (defaultAudioButton.hovered ? "#2196F3" : "#334155")
                            border.width: defaultAudioButton.checked ? 2 : 1

                            Rectangle {
                                visible: defaultAudioButton.checked
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1
                                height: 2; radius: 1; color: "#00d4ff"
                            }
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: defaultAudioButton.checked ? "#00d4ff" : "#475569"
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        anchors.centerIn: parent
                                        color: defaultAudioButton.checked ? "#7dd3fc" : "#64748B"
                                    }
                                }
                                Text {
                                    text: defaultAudioButton.text
                                    font.pixelSize: 13
                                    font.bold: defaultAudioButton.checked
                                    color: defaultAudioButton.checked ? "#E0E0E0" : "#9E9E9E"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        onClicked: {
                            root.audioSourceMode = "default"
                            ttsAudioButton.checked = false
                        }
                    }

                    // [TTS] 按钮 - 深绿背景 + 绿色边框 + LED点
                    Button {
                        id: ttsAudioButton
                        text: "TTS"
                        checkable: true
                        checked: root.audioSourceMode === "tts"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        background: Rectangle {
                            color: ttsAudioButton.checked ? "#0d2218" :
                                   (ttsAudioButton.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: ttsAudioButton.checked ? "#22C55E" :
                                          (ttsAudioButton.hovered ? "#2196F3" : "#334155")
                            border.width: ttsAudioButton.checked ? 2 : 1

                            Rectangle {
                                visible: ttsAudioButton.checked
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1
                                height: 2; radius: 1; color: "#22C55E"
                            }
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: ttsAudioButton.checked ? "#22C55E" : "#475569"
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        anchors.centerIn: parent
                                        color: ttsAudioButton.checked ? "#86EFAC" : "#64748B"
                                    }
                                }
                                Text {
                                    text: ttsAudioButton.text
                                    font.pixelSize: 13
                                    font.bold: ttsAudioButton.checked
                                    color: ttsAudioButton.checked ? "#E0E0E0" : "#9E9E9E"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        onClicked: {
                            root.audioSourceMode = "tts"
                            defaultAudioButton.checked = false
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(4); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            // ✅ 2026-03-10 [Phase 7.48.32]: TTS文字输入框样式修复（匹配AnalogInputPage）
            // 旧代码：placeholderText: "输入TTS文字"（无颜色设置，黑色文字）
            Text {
                text: "TTS文字:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 2
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: ttsTextField.implicitHeight
                DeviceInfo.CustomTextField {
                    id: ttsTextField
                    anchors.fill: parent
                    placeholderText: "输入报警文字内容..."
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(5); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 3: 通道编号 | 音频文件 ==========
            Text {
                text: "通道编号:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 3
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: channelSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: channelSpin
                    anchors.fill: parent
                    from: -1; to: 7; value: -1
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(6); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "音频文件:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 3
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: audioFileField.implicitHeight
                // ✅ 2026-03-10 [Phase 7.48.32]: 音频文件输入框样式修复（匹配AnalogInputPage）
                // 旧代码：无 placeholderText/placeholderTextColor/color 设置
                DeviceInfo.CustomTextField {
                    id: audioFileField
                    anchors.fill: parent
                    readOnly: true
                    placeholderText: "未配置音频文件"
                    placeholderTextColor: "#6E6E6E"
                    color: "#E0E0E0"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(7); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 4: 上限值 | 保护延时 ==========
            Text {
                text: "上限值:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 4
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: upperLimitSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: upperLimitSpin
                    anchors.fill: parent
                    from: 0; to: 99999; value: root.defaultUpperLimit
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(8); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "保护延时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 4
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: protectionDelaySpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: protectionDelaySpin
                    anchors.fill: parent
                    from: 0; to: 9999; value: root.defaultProtectionDelay
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(9); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 9) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 5: 下限值 | 过滤干扰延时 ==========
            Text {
                text: "下限值:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 5
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: lowerLimitSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: lowerLimitSpin
                    anchors.fill: parent
                    from: 0; to: 99999; value: root.defaultLowerLimit
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(10); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 10) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 10) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "过滤干扰延时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 5
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: filterDelaySpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: filterDelaySpin
                    anchors.fill: parent
                    from: 0; to: 9999; value: root.defaultFilterDelay
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(11); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 11) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 11) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 6: 单位 | 数据超时 ==========
            Text {
                text: "单位:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 6
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 6
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: unitCombo.implicitHeight
                DeviceInfo.CustomComboBox {
                    id: unitCombo
                    anchors.fill: parent
                    model: ["A", "℃", "mm/s", "kW", "%", "V", "mA", "RPM"]
                    currentIndex: 0
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(12); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 12) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 12) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "数据超时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 6
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 6
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: dataTimeoutSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: dataTimeoutSpin
                    anchors.fill: parent
                    from: 0; to: 999; value: 2
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(13); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 13) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 13) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 7: 量程 | 连接超时 ==========
            Text {
                text: "量程:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 7
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 7
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: rangeSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: rangeSpin
                    anchors.fill: parent
                    from: 0; to: 99999; value: root.defaultRange
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(14); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 14) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 14) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "连接超时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 7
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 7
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: connectionTimeoutSpin.implicitHeight
                DeviceInfo.CustomSpinBox {
                    id: connectionTimeoutSpin
                    anchors.fill: parent
                    from: 0; to: 999; value: 10
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(15); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 15) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 15) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 8: 输入类型 | 保护级别 ==========
            Text {
                text: "输入类型:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 8
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 8
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: inputTypeCombo.implicitHeight
                DeviceInfo.CustomComboBox {
                    id: inputTypeCombo
                    anchors.fill: parent
                    model: ["4-20mA电流型", "0-20mA电流型", "0-5V电压型", "0-10V电压型", "1-5V电压型", "PT100热电阻"]
                    currentIndex: 0
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(16); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 16) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 16) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "保护级别:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 8
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 8
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: protectionLevelCombo.implicitHeight
                DeviceInfo.CustomComboBox {
                    id: protectionLevelCombo
                    anchors.fill: parent
                    model: ["无", "预警", "预警+正常停车", "预警+紧急停车"]
                    currentIndex: 0
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(17); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 17) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 17) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 9: 播放方式 | 洒水使能 ==========
            Text {
                text: "播放方式:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 9
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            // ✅ 2026-03-18 [Phase 7.48.55]: 播放方式切换按钮（Cyberpunk工业风，与开关量输入统一）
            // 旧：简单Button蓝色/灰色切换  // 2026-03-18 删除，改为Cyberpunk切换按钮
            Item {
                Layout.column: 1; Layout.row: 9
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 50
                // 保留 playModeRow 兼容性（保存/加载函数引用 playModeRow.selectedMode）
                Item {
                    id: playModeRow
                    visible: false
                    property string selectedMode: "count"
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Button {
                        id: playModeCountBtn
                        text: "按次数"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        checkable: true
                        checked: playModeRow.selectedMode === "count"
                        background: Rectangle {
                            color: playModeCountBtn.checked ? "#0d1b2e" : (playModeCountBtn.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: playModeCountBtn.checked ? "#00d4ff" : (playModeCountBtn.hovered ? "#2196F3" : "#334155")
                            border.width: playModeCountBtn.checked ? 2 : 1
                            Rectangle { visible: playModeCountBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#00d4ff" }
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: playModeCountBtn.checked ? "#00d4ff" : "#475569"; Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: playModeCountBtn.checked ? "#e0f7ff" : "#64748B" } }
                                Text { text: playModeCountBtn.text; font.pixelSize: 16; font.weight: playModeCountBtn.checked ? Font.Medium : Font.Normal; color: playModeCountBtn.checked ? "#00d4ff" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                        onClicked: playModeRow.selectedMode = "count"
                    }

                    Button {
                        id: playModeDurationBtn
                        text: "按时长"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        checkable: true
                        checked: playModeRow.selectedMode === "duration"
                        background: Rectangle {
                            color: playModeDurationBtn.checked ? "#1b1500" : (playModeDurationBtn.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: playModeDurationBtn.checked ? "#F59E0B" : (playModeDurationBtn.hovered ? "#2196F3" : "#334155")
                            border.width: playModeDurationBtn.checked ? 2 : 1
                            Rectangle { visible: playModeDurationBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#F59E0B" }
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: playModeDurationBtn.checked ? "#F59E0B" : "#475569"; Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: playModeDurationBtn.checked ? "#FDE68A" : "#64748B" } }
                                Text { text: playModeDurationBtn.text; font.pixelSize: 16; font.weight: playModeDurationBtn.checked ? Font.Medium : Font.Normal; color: playModeDurationBtn.checked ? "#F59E0B" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                        onClicked: playModeRow.selectedMode = "duration"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(18); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 18) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 18) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "洒水使能:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 9
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 9
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: sprinklerSwitch.implicitHeight
                Switch {
                    id: sprinklerSwitch
                    checked: false
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(19); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 19) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 19) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== Row 10: 保护启用 ==========
            Text {
                text: "保护启用:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 10
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 10
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: enabledSwitch.implicitHeight
                Switch {
                    id: enabledSwitch
                    checked: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) { root.requestFocusParamIndex(20); mouse.accepted = false }
                }
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 20) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 20) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
        }  // GridLayout end

            // ✅ 2026-03-10 [Phase 7.48.29]: 删除内置底部按钮（保存/删除/重置）
            // 原因：按钮已在 MotorControlPage 底部统一实现，此处重复
            // 旧代码：RowLayout { Button "保存" / "删除" / "重置" }
    }  // ScrollView end

    // ========== 导航函数 ==========
    function getParamFieldCount() {
        return 21
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [MotorProtectionTab] 触发参数输入 - 索引:", paramIndex)
        var inputField = null
        switch(paramIndex) {
        case 0: break  // 保护名称（只读）
        case 1: inputField = playCountSpin; break
        case 2:  // 模块类型（ComboBox切换）
            moduleTypeCombo.currentIndex = (moduleTypeCombo.currentIndex + 1) % moduleTypeCombo.model.length; break
        case 3: inputField = playDurationSpin; break
        case 4:  // 音频来源（切换）
            // ✅ 2026-03-10 [Phase 7.48.32]: 同步按钮选中状态
            if (root.audioSourceMode === "default") {
                root.audioSourceMode = "tts"
                defaultAudioButton.checked = false
                ttsAudioButton.checked = true
            } else {
                root.audioSourceMode = "default"
                defaultAudioButton.checked = true
                ttsAudioButton.checked = false
            }
            break
        case 5: inputField = ttsTextField; break
        case 6: inputField = channelSpin; break
        case 7: break  // 音频文件（只读）
        case 8: inputField = upperLimitSpin; break
        case 9: inputField = protectionDelaySpin; break
        case 10: inputField = lowerLimitSpin; break
        case 11: inputField = filterDelaySpin; break
        case 12:  // 单位（ComboBox切换）
            unitCombo.currentIndex = (unitCombo.currentIndex + 1) % unitCombo.model.length; break
        case 13: inputField = dataTimeoutSpin; break
        case 14: inputField = rangeSpin; break
        case 15: inputField = connectionTimeoutSpin; break
        case 16:  // 输入类型（ComboBox切换）
            inputTypeCombo.currentIndex = (inputTypeCombo.currentIndex + 1) % inputTypeCombo.model.length; break
        case 17:  // 保护级别（ComboBox切换）
            protectionLevelCombo.currentIndex = (protectionLevelCombo.currentIndex + 1) % protectionLevelCombo.model.length; break
        case 18:  // 播放方式（切换）
            playModeRow.selectedMode = (playModeRow.selectedMode === "count") ? "duration" : "count"; break
        case 19:  // 洒水使能（Switch切换）
            sprinklerSwitch.checked = !sprinklerSwitch.checked; break
        case 20:  // 保护启用（Switch切换）
            enabledSwitch.checked = !enabledSwitch.checked; break
        }
        if (inputField) {
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                inputField.forceActiveFocus()
            }
        }
    }

    // ========== 音频文件名生成（匹配AnalogInputPage） ==========
    // ✅ 2026-03-10 [Phase 7.48.32]: 新增 - 根据保护名称和音频来源模式生成音频文件名
    function getAudioFileName(protectionName) {
        if (root.audioSourceMode === "default") {
            return protectionName + ".mp3"
        } else {
            return protectionName + ".wav"
        }
    }

    // ========== 配置收集 ==========
    function collectConfig() {
        var config = {}
        config["protection_name"] = root.protectionName
        config["module_type"] = moduleTypeCombo.currentText
        config["register_address"] = channelSpin.value
        config["upper_limit"] = upperLimitSpin.value
        config["lower_limit"] = lowerLimitSpin.value
        config["unit"] = unitCombo.currentText
        config["range_value"] = rangeSpin.value
        config["input_type"] = inputTypeCombo.currentText
        config["protection_delay"] = protectionDelaySpin.value
        config["filter_delay"] = filterDelaySpin.value
        config["play_count"] = playCountSpin.value
        config["play_duration"] = playDurationSpin.value
        config["use_text_to_speech"] = (root.audioSourceMode === "tts") ? 1 : 0
        config["voice_alarm_type"] = root.audioSourceMode
        config["tts_text"] = ttsTextField.text
        config["audio_file"] = audioFileField.text
        config["play_mode"] = playModeRow.selectedMode
        config["protection_level"] = protectionLevelCombo.currentIndex
        config["data_timeout"] = dataTimeoutSpin.value
        config["connection_timeout"] = connectionTimeoutSpin.value
        config["sprinkler_enabled"] = sprinklerSwitch.checked ? 1 : 0
        config["enabled"] = enabledSwitch.checked ? 1 : 0
        console.log("✅ [MotorProtectionTab] collectConfig:", JSON.stringify(config))
        return config
    }

    // ========== 配置应用 ==========
    function applyConfig(config) {
        console.log("✅ [MotorProtectionTab] applyConfig:", JSON.stringify(config))
        if (!config || Object.keys(config).length === 0) return

        // 模块类型
        var mt = config.module_type || "模拟量模块1"
        var mtIdx = moduleTypeCombo.model.indexOf(mt)
        if (mtIdx >= 0) moduleTypeCombo.currentIndex = mtIdx

        // 通道编号
        channelSpin.value = config.register_address !== undefined ? config.register_address : -1

        // 上下限、量程
        upperLimitSpin.value = config.upper_limit !== undefined ? config.upper_limit : root.defaultUpperLimit
        lowerLimitSpin.value = config.lower_limit !== undefined ? config.lower_limit : root.defaultLowerLimit
        rangeSpin.value = config.range_value !== undefined ? config.range_value : root.defaultRange

        // 单位
        var u = config.unit || root.defaultUnit
        var uIdx = unitCombo.model.indexOf(u)
        if (uIdx >= 0) unitCombo.currentIndex = uIdx

        // 输入类型
        var it = config.input_type || root.defaultInputType
        var itIdx = inputTypeCombo.model.indexOf(it)
        if (itIdx >= 0) inputTypeCombo.currentIndex = itIdx

        // 延时
        protectionDelaySpin.value = config.protection_delay !== undefined ? config.protection_delay : root.defaultProtectionDelay
        filterDelaySpin.value = config.filter_delay !== undefined ? config.filter_delay : root.defaultFilterDelay

        // 播放
        playCountSpin.value = config.play_count !== undefined ? config.play_count : 3
        playDurationSpin.value = config.play_duration !== undefined ? config.play_duration : 50

        // 音频来源
        root.audioSourceMode = (config.use_text_to_speech === 1 || config.voice_alarm_type === "tts") ? "tts" : "default"
        // ✅ 2026-03-10 [Phase 7.48.32]: 同步按钮选中状态
        defaultAudioButton.checked = (root.audioSourceMode === "default")
        ttsAudioButton.checked = (root.audioSourceMode === "tts")
        ttsTextField.text = config.tts_text || (root.protectionName + "保护报警")
        // ✅ 2026-03-10 [Phase 7.48.32]: 音频文件自动填充（匹配AnalogInputPage的getAudioFileName逻辑）
        // 旧代码：audioFileField.text = config.audio_file || ""
        audioFileField.text = config.audio_file || getAudioFileName(root.protectionName)

        // 播放方式
        playModeRow.selectedMode = config.play_mode || "count"

        // 保护级别
        var pl = config.protection_level !== undefined ? config.protection_level : root.defaultProtectionLevel
        if (pl >= 0 && pl < protectionLevelCombo.model.length) protectionLevelCombo.currentIndex = pl

        // 超时
        dataTimeoutSpin.value = config.data_timeout !== undefined ? config.data_timeout : 2
        connectionTimeoutSpin.value = config.connection_timeout !== undefined ? config.connection_timeout : 10

        // 开关
        sprinklerSwitch.checked = (config.sprinkler_enabled === 1)
        enabledSwitch.checked = (config.enabled !== undefined) ? (config.enabled === 1) : true
    }

    // ========== 保存配置 ==========
    function saveConfig() {
        var config = collectConfig()
        config["tab_name"] = root.protectionName
        var success = deviceConfigMgr.saveMotorConfig(root.deviceId, root.motorIndex, root.tabIndex, config)
        if (success) {
            console.log("✅ [MotorProtectionTab] 保存成功 - Tab:", root.tabIndex)
        } else {
            console.log("❌ [MotorProtectionTab] 保存失败 - Tab:", root.tabIndex)
        }
    }

    // ========== 加载配置 ==========
    function loadConfig() {
        var config = deviceConfigMgr.loadMotorConfig(root.deviceId, root.motorIndex, root.tabIndex)
        if (config && Object.keys(config).length > 0) {
            applyConfig(config)
        } else {
            console.log("⚠️ [MotorProtectionTab] 未找到配置，使用默认值")
            resetToDefaults()
        }
    }

    // ========== 重置为默认值 ==========
    function resetToDefaults() {
        moduleTypeCombo.currentIndex = 0
        channelSpin.value = -1
        upperLimitSpin.value = root.defaultUpperLimit
        lowerLimitSpin.value = root.defaultLowerLimit
        rangeSpin.value = root.defaultRange
        var itIdx = inputTypeCombo.model.indexOf(root.defaultInputType)
        if (itIdx >= 0) inputTypeCombo.currentIndex = itIdx
        var uIdx = unitCombo.model.indexOf(root.defaultUnit)
        if (uIdx >= 0) unitCombo.currentIndex = uIdx
        protectionDelaySpin.value = root.defaultProtectionDelay
        filterDelaySpin.value = root.defaultFilterDelay
        protectionLevelCombo.currentIndex = root.defaultProtectionLevel
        sprinklerSwitch.checked = root.defaultSprinklerEnabled
        enabledSwitch.checked = true
        playCountSpin.value = 3
        playDurationSpin.value = 50
        // ✅ 2026-03-10 [Phase 7.48.32]: 重置时自动填充音频字段（匹配AnalogInputPage）
        // 旧代码：root.audioSourceMode = "default"; ttsTextField.text = ""; audioFileField.text = ""
        root.audioSourceMode = "tts"
        defaultAudioButton.checked = false
        ttsAudioButton.checked = true
        ttsTextField.text = root.protectionName + "保护报警"
        audioFileField.text = getAudioFileName(root.protectionName)
        playModeRow.selectedMode = "count"
        dataTimeoutSpin.value = 2
        connectionTimeoutSpin.value = 10
    }

    Component.onCompleted: {
        loadConfig()
    }

}