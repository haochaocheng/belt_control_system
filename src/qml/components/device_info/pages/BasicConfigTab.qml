import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import com.belt.control 1.0  // ✅ 2026-03-12: 导入TTSConfig单例（用于音频路径构建）
import ".." as DeviceInfo

// ✅ 2026-01-25 [电机控制-基本配置] 基本配置Tab内容
// ✅ 2026-01-25 [FIX 100.313]: 调整为标签和输入框同一行布局
// ✅ 2026-01-28 [FIX 100.300.60]: 替换所有 SpinBox 为 DeviceInfo.CustomSpinBox
// ✅ 2026-01-28 [虚拟键盘集成]: 接收并传递键盘管理器
// ✅ 2026-01-30 [FIX 100.300.106.4]: 改为两列布局，参考 AnalogInputPage
Rectangle {
    id: root
    width: 800  // 默认宽度（用于QDS预览）
    height: 500  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0  // 当前电机索引 (0-7)
    property int deviceId: 1    // ✅ 2026-03-10 [Phase 7.48.33]: 设备ID（用于电机控制命令）
    // ✅ 2026-02-02 [FIX 100.300.112.8.23]: 恢复键盘管理器属性（与 AnalogInputPage 保持一致）
    property var keyboardManager: null

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusParamIndex: 0  // 参数区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.7]: 监听 focusParamIndex 变化，确认属性传递
    onFocusParamIndexChanged: {
        console.log("🟢 [BasicConfigTab] focusParamIndex 变化:", focusParamIndex)
    }

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 信号 - 请求更新焦点索引
    // 用于鼠标点击时通知父组件，避免直接赋值打破 Qt.binding
    signal requestFocusParamIndex(int paramIndex)

    // ✅ 2026-01-30 [FIX 100.300.106.3]: 布局模式（两列布局）
    // ✅ 2026-01-30 [FIX 100.300.106.4]: 改为两列布局，参考 AnalogInputPage
    readonly property string layoutMode: "two-column"  // "single-column" 或 "two-column"

    // ✅ 2026-03-10 [Phase 7.48.36]: 反馈超时检测
    // 电机启动后，如果在反馈延时时间内没有收到反馈，播放"运行失败"报警
    property bool waitingForFeedback: false  // 是否正在等待反馈

    // ✅ 2026-03-12: 根据音频来源构建音频文件路径
    // default模式：{baseDir}/{belt}#PD/{filename}.wav
    // tts模式：{baseDir}/paddlespeech-{model}-spk{id}/{belt}#PD/{filename}.wav
    function buildAudioPath(beltNum, filename) {
        if (audioSourceCombo.currentIndex === 0) {
            // 默认音频
            return audioBaseDir + "/" + beltNum + "#PD/" + filename + ".wav"
        } else {
            // TTS合成音频（含引擎子目录）
            var modelIdx = typeof TTSConfig !== "undefined" ? TTSConfig.modelIndex(TTSConfig.Test) : 0
            var modelName = typeof TTSConfig !== "undefined" ? TTSConfig.modelName(modelIdx) : "fastspeech2_csmsc"
            var spkId = typeof TTSConfig !== "undefined" ? TTSConfig.speakerId(TTSConfig.Test) : 0
            var engineFolder = "paddlespeech-" + modelName + "-spk" + spkId
            return audioBaseDir + "/" + engineFolder + "/" + beltNum + "#PD/" + filename + ".wav"
        }
    }

    // ✅ 2026-03-12 [Phase 7.48.41]: 启动延时计时器
    // 点击启动按钮后，先播放预警语音，等待启动延时结束后才发送MQTT启动命令
    Timer {
        id: startupDelayTimer
        interval: startupDelaySpin.value * 1000  // 启动延时（秒→毫秒）
        repeat: false
        onTriggered: {
            // 延时结束，发送MQTT启动命令
            var ch = outputChannelSpin.value
            var topic = "belt_control/do/module1/cmd"
            var cmd = JSON.stringify({"action": "set", "channel": ch, "value": 1})
            console.log("🔌 [BasicConfigTab] 启动延时结束，发送启动命令 电机", (root.motorIndex + 1), "通道:", ch)
            if (typeof mqttController !== "undefined") {
                mqttController.publish(topic, cmd, 1, false)
            }
            // 启动反馈超时检测
            if (useFeedbackSwitch.checked) {
                root.waitingForFeedback = true
                feedbackTimeoutTimer.restart()
            }
        }
    }

    Timer {
        id: feedbackTimeoutTimer
        interval: feedbackDelaySpin.value * 1000  // 反馈延时（秒→毫秒）
        repeat: false
        onTriggered: {
            if (root.waitingForFeedback && useFeedbackSwitch.checked) {
                // 超时未收到反馈 → 报警 + 停止电机
                console.log("⚠️ [BasicConfigTab] 电机", (root.motorIndex + 1), "反馈超时！延时:", feedbackDelaySpin.value, "秒")
                root.waitingForFeedback = false

                // ✅ 2026-03-13 [Phase 7.48.43]: 反馈超时必须停止电机运行
                var ch = outputChannelSpin.value
                var topic = "belt_control/do/module1/cmd"
                var stopCmd = JSON.stringify({"action": "set", "channel": ch, "value": 0})
                console.log("🛑 [BasicConfigTab] 反馈超时，停止电机", (root.motorIndex + 1), "通道:", ch)
                if (typeof mqttController !== "undefined") {
                    mqttController.publish(topic, stopCmd, 1, false)
                }

                // ✅ 2026-03-11 [Phase 7.48.37]: 播放失败语音（音频文件名 + TTS回退）
                // 旧：alarmPlayback.playAlarm(failureVoiceField.text, failureVoiceField.text, "", ...)
                if (typeof alarmPlayback !== "undefined") {
                    var beltNum2 = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
                    // ✅ 2026-03-12: 使用buildAudioPath根据音频来源构建正确路径
                    // 旧：var audioPath2 = audioBaseDir + "/" + beltNum2 + "#PD/" + failureVoiceField.text + ".wav"
                    var audioPath2 = buildAudioPath(beltNum2, failureVoiceField.text)
                    var ttsText2 = beltNum2 + "号皮带" + (root.motorIndex + 1) + "号电机运行失败"
                    alarmPlayback.playAlarm(failureVoiceField.text, ttsText2, audioPath2, true, "count", 3, 5)
                }
            }
        }
    }

    // 监听反馈LED变化：收到反馈时取消超时计时
    onWaitingForFeedbackChanged: {
        if (!waitingForFeedback) {
            feedbackTimeoutTimer.stop()
        }
    }

    // ========== 滚动区域 ==========
    ScrollView {
        id: paramScrollView  // ✅ 2026-01-30 [FIX 100.300.107]: 添加 ID，用于 GridLayout 宽度计算
        anchors.fill: parent
        clip: true

        // ✅ 2026-01-30 [FIX 100.300.107]: 改为 GridLayout，参考 SwitchInputPage
        // ✅ 2026-01-30 [FIX 100.300.107.1]: 修改宽度为 90%，避免标签文字被覆盖
        // ✅ 2026-01-30 [FIX 100.300.107.3]: 增加标签宽度从 120 到 160，确保长标签完整显示
        GridLayout {
            width: paramScrollView.width * 0.9  // ✅ 占 ScrollView 宽度的 90%
            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
            columnSpacing: 10
            rowSpacing: 12

            // ========== 第一行：运行状态（左侧，索引0）、模块类型（右侧，索引1）==========

            // 运行状态标签
            Text {
                text: "运行状态:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 160  // ✅ 2026-01-30 [FIX 100.300.107.3]: 从 120 增加到 160
                horizontalAlignment: Text.AlignRight
            }

            // 运行状态输入（RadioButton 组）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: runningStateRow.implicitHeight  // ✅ 引用 Row 的 implicitHeight

                Row {
                    id: runningStateRow
                    anchors.fill: parent
                    spacing: 30

                    // 投入选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: true  // 默认选中
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    console.log((root.motorIndex + 1) + "号电机: 投入")
                                }
                            }
                        }

                        Text {
                            text: "投入"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 禁用选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: false  // 默认不选中
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    console.log((root.motorIndex + 1) + "号电机: 禁用")
                                }
                            }
                        }

                        Text {
                            text: "禁用"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 模块类型标签
            Text {
                text: "模块类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 160  // ✅ 2026-01-30 [FIX 100.300.107.3]: 从 120 增加到 160
                horizontalAlignment: Text.AlignRight
            }

            // 模块类型输入（只读显示框）
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: moduleTypeDisplay.implicitHeight  // ✅ 引用 Rectangle 的 implicitHeight

                Rectangle {
                    id: moduleTypeDisplay
                    anchors.fill: parent
                    color: "#2d3548"
                    border.color: "#3d4556"
                    border.width: 1
                    radius: 2
                    implicitHeight: 60  // ✅ 设置固定高度

                    Text {
                        anchors.centerIn: parent
                        text: "继电器模块"
                        font.pixelSize: 21
                        color: "#E0E0E0"
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 1) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第二行：模块地址（左侧，索引2）、输出通道（右侧，索引3）==========

            // 模块地址标签
            Text {
                text: "模块地址:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160  // ✅ 2026-01-30 [FIX 100.300.107.3]: 从 120 增加到 160
                horizontalAlignment: Text.AlignRight
            }

            // 模块地址输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: moduleAddressSpin.implicitHeight  // ✅ 引用 SpinBox 的 implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: moduleAddressSpin
                    anchors.fill: parent
                    from: 1
                    to: 8
                    value: 1
                    editable: true
                    keyboardManager: root.keyboardManager  // ✅ 2026-02-02 [FIX 100.300.112.8.23]: 添加键盘管理器
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24]: 鼠标点击同步焦点索引
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.5]: 添加详细调试日志
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.5.1]: 修复 mouse 参数声明
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 发射信号而不是直接赋值，避免打破 Qt.binding
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [BasicConfigTab] 鼠标点击模块地址，发射信号: requestFocusParamIndex(2)")

                        // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 发射信号，而不是直接赋值
                        // 避免打破 Qt.binding
                        root.requestFocusParamIndex(2)

                        mouse.accepted = false  // 让事件继续传递给 SpinBox
                    }
                }

                // 焦点指示器
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.2]: 大幅增加 z 值，确保在所有元素之上
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.5]: 移除测试背景色，添加渲染状态日志
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.5.2]: 移除无效的 onBorderColorChanged，改用 Connections
                Rectangle {
                    id: moduleAddressFocusIndicator
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false

                    Component.onCompleted: {
                        console.log("🔵 [模块地址焦点指示器] 组件加载完成")
                        console.log("  - 初始 border.color:", border.color)
                        console.log("  - 初始 root.focusParamIndex:", root.focusParamIndex)
                        console.log("  - 初始 width:", width, "height:", height)
                        console.log("  - 初始 x:", x, "y:", y)
                        console.log("  - 初始 z:", z)
                    }

                    // ✅ 使用 Connections 监听 focusParamIndex 变化
                    Connections {
                        target: root
                        function onFocusParamIndexChanged() {
                            if (root.focusParamIndex === 2) {
                                console.log("🔵 [模块地址焦点指示器] 获得焦点")
                                console.log("  - border.color:", moduleAddressFocusIndicator.border.color)
                                console.log("  - border.width:", moduleAddressFocusIndicator.border.width)
                                console.log("  - visible:", moduleAddressFocusIndicator.visible)
                                console.log("  - opacity:", moduleAddressFocusIndicator.opacity)
                                console.log("  - z:", moduleAddressFocusIndicator.z)
                                console.log("  - width:", moduleAddressFocusIndicator.width, "height:", moduleAddressFocusIndicator.height)
                                console.log("  - x:", moduleAddressFocusIndicator.x, "y:", moduleAddressFocusIndicator.y)
                            }
                        }
                    }
                }
            }

            // 输出通道标签
            Text {
                text: "输出通道:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160  // ✅ 2026-01-30 [FIX 100.300.107.3]: 从 120 增加到 160
                horizontalAlignment: Text.AlignRight
            }

            // 输出通道输入
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: outputChannelSpin.implicitHeight  // ✅ 引用 SpinBox 的 implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: outputChannelSpin
                    anchors.fill: parent
                    from: 0
                    to: 15
                    // ✅ 2026-03-24 [Phase 7.48.88.6]: 默认通道=motorIndex+1，16通道均匀分配（电机1-5，制动器6-10，洒水11-15）
                    // 旧代码：value: root.motorIndex + 3  // Phase 7.48.88.5 的分配方案
                    value: root.motorIndex + 1
                    editable: true
                    keyboardManager: root.keyboardManager  // ✅ 2026-02-02 [FIX 100.300.112.8.23]: 添加键盘管理器
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24]: 鼠标点击同步焦点索引
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 发射信号而不是直接赋值，避免打破 Qt.binding
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [BasicConfigTab] 鼠标点击输出通道，发射信号: requestFocusParamIndex(3)")
                        root.requestFocusParamIndex(3)
                        mouse.accepted = false  // 让事件继续传递给 SpinBox
                    }
                }

                // 焦点指示器
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.2]: 大幅增加 z 值，确保在所有元素之上
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 1000  // ✅ 2026-02-02 [FIX 100.300.112.8.24.2]: 从 10 增加到 1000
                    enabled: false  // ✅ 不拦截鼠标事件
                }
            }

            // ========== 第三行：是否使用反馈（左侧，索引4）、反馈通道（右侧，索引5）==========
            // ✅ 2026-03-10 [Phase 7.48.34]: 反馈通道右移，左侧新增"是否使用反馈"开关

            // 是否使用反馈标签
            Text {
                text: "使用反馈:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 是否使用反馈开关
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: useFeedbackSwitch.implicitHeight

                Switch {
                    id: useFeedbackSwitch
                    anchors.verticalCenter: parent.verticalCenter
                    checked: true  // 默认启用反馈

                    indicator: Rectangle {
                        implicitWidth: 52; implicitHeight: 26
                        x: useFeedbackSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: useFeedbackSwitch.checked ? "#0d2218" : "#1a1a2e"
                        border.color: useFeedbackSwitch.checked ? "#22C55E" : "#475569"
                        border.width: 2

                        Rectangle {
                            x: useFeedbackSwitch.checked ? parent.width - width - 2 : 2
                            y: 2
                            width: 22; height: 22; radius: 11
                            color: useFeedbackSwitch.checked ? "#22C55E" : "#64748B"
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                    }

                    contentItem: Text {
                        text: useFeedbackSwitch.checked ? "启用" : "禁用"
                        font.pixelSize: 16
                        color: useFeedbackSwitch.checked ? "#22C55E" : "#9E9E9E"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: useFeedbackSwitch.indicator.width + useFeedbackSwitch.spacing
                    }
                }

                // ✅ 2026-03-10 [Phase 7.48.36]: 修复Switch无法点击问题
                // 旧：MouseArea onClicked mouse.accepted=false（太晚，事件已被消费）
                // 新：propagateComposedEvents + onPressed 放行，让Switch可以接收点击
                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onPressed: function(mouse) {
                        root.requestFocusParamIndex(4)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // 反馈通道标签（右侧）
            Text {
                text: "反馈通道:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4
            }

            // 反馈通道输入（右侧）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: feedbackChannelSpin.implicitHeight
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4
                enabled: useFeedbackSwitch.checked

                DeviceInfo.CustomSpinBox {
                    id: feedbackChannelSpin
                    anchors.fill: parent
                    from: 0
                    to: 7
                    value: root.motorIndex
                    editable: true
                    keyboardManager: root.keyboardManager
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(5)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    id: feedbackChannelFocusIndicator
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== 第四行：反馈延时（左侧，索引6）==========
            // ✅ 2026-03-10 [Phase 7.48.36]: 新增运行反馈延时参数
            Text {
                text: "反馈延时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4
            }
            Item {
                Layout.column: 1; Layout.row: 3
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: feedbackDelaySpin.implicitHeight
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4
                enabled: useFeedbackSwitch.checked

                DeviceInfo.CustomSpinBox {
                    id: feedbackDelaySpin
                    anchors.fill: parent
                    from: 1
                    to: 60
                    value: 3  // 默认3秒
                    editable: true
                    keyboardManager: root.keyboardManager
                    // suffix 不支持，用标签说明单位
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(6)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "秒"
                font.pixelSize: 18; color: "#7dd3fc"
                Layout.column: 2; Layout.row: 3
                Layout.preferredWidth: 40
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4
            }

            // ========== 第四行右侧：启动延时（索引7）==========
            // ✅ 2026-03-10 [Phase 7.48.37]: 新增启动延时参数
            Text {
                text: "启动延时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 3
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: startupDelaySpin.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: startupDelaySpin
                    anchors.fill: parent
                    from: 0
                    to: 60
                    value: 8  // ✅ 2026-03-12: 默认8秒（原5秒）
                    editable: true
                    keyboardManager: root.keyboardManager
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(7)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
            Text {
                text: "秒"
                font.pixelSize: 18; color: "#7dd3fc"
                Layout.column: 3; Layout.row: 3
                visible: false  // 启动延时单位由SpinBox右侧显示，此处隐藏避免冲突
            }

            // ✅ 2026-03-22 [Phase 7.48.74]: 新增停止延时参数（索引8）
            // 原因：启动延时和停止延时需要独立配置
            Text {
                text: "停止延时:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 4
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: stopDelaySpin.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: stopDelaySpin
                    anchors.fill: parent
                    from: 0
                    to: 60
                    value: 8
                    editable: true
                    keyboardManager: root.keyboardManager
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(8)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== 第五行：预警语音（左，索引9）、失败语音（右，索引10）==========
            // ✅ 2026-03-10 [Phase 7.48.37]: 新增预警语音和失败语音参数
            // ✅ 2026-03-22 [Phase 7.48.74]: 索引从8/9调整为9/10（新增停止延时占用索引8）
            Text {
                text: "预警语音:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 5
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: warningVoiceField.implicitHeight

                // ✅ 2026-03-12 [Phase 7.48.40]: 从TextField改为CustomTextField（参照AnalogInputPage组件风格）
                // 旧：普通TextField，无keyboardManager支持
                DeviceInfo.CustomTextField {
                    id: warningVoiceField
                    anchors.fill: parent
                    // ✅ 2026-03-11 [Phase 7.48.37]: 改为音频文件名（不含扩展名）
                    // 旧：text: "电机" + (root.motorIndex + 1) + "启动预警"
                    text: "电机" + (root.motorIndex + 1) + "启动"
                    placeholderText: "预警音频文件名"
                    placeholderTextColor: "#6E6E6E"
                    color: "#E0E0E0"
                    keyboardManager: root.keyboardManager
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(9)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 9) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            Text {
                text: "失败语音:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 5
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: failureVoiceField.implicitHeight

                // ✅ 2026-03-12 [Phase 7.48.40]: 从TextField改为CustomTextField（参照AnalogInputPage组件风格）
                DeviceInfo.CustomTextField {
                    id: failureVoiceField
                    anchors.fill: parent
                    // ✅ 2026-03-11 [Phase 7.48.37]: 改为音频文件名（不含扩展名）
                    // 旧：text: "电机" + (root.motorIndex + 1) + "运行失败"
                    text: "电机" + (root.motorIndex + 1) + "失败"
                    placeholderText: "失败音频文件名"
                    placeholderTextColor: "#6E6E6E"
                    color: "#E0E0E0"
                    keyboardManager: root.keyboardManager
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(10)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 10) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 10) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== 第七行：启动键（左，索引11）==========
            // ✅ 2026-03-10 [Phase 7.48.37]: 新增启���键选择（键盘按键）
            // ✅ 2026-03-22 [Phase 7.48.74]: 索引从10调整为11
            Text {
                text: "启动键:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 6
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 6
                Layout.fillWidth: true; Layout.maximumWidth: 300
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 统一高度为50（与其他输入框一致）
                // 旧：implicitHeight: startupKeyCombo.implicitHeight
                implicitHeight: 50

                // ✅ 2026-03-12 [Phase 7.48.41]: 从ComboBox改为CustomComboBox（统一组件风格）
                DeviceInfo.CustomComboBox {
                    id: startupKeyCombo
                    anchors.fill: parent
                    keyboardManager: root.keyboardManager
                    model: ["无", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
                            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                            "A", "B", "C", "D", "E", "F", "G", "H"]
                    currentIndex: 0
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        // ✅ 2026-03-22 [Phase 7.48.74.1]: 修复索引12→11
                        root.requestFocusParamIndex(11)
                        mouse.accepted = false
                    }
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    // ✅ 2026-03-22 [Phase 7.48.74.1]: 修复索引12→11
                    border.color: (root.focusParamIndex === 11) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 11) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ✅ 2026-03-12: 音频来源（右侧，索引12）
            // ✅ 2026-03-22 [Phase 7.48.74]: 索引从11调整为12
            Text {
                text: "音频来源:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 6
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 6
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 50

                // ✅ 2026-03-12 [Phase 7.48.40]: 从ComboBox改为ButtonGroup双按钮（参照AnalogInputPage音频来源风格）
                // 旧：ComboBox audioSourceCombo
                // 提供兼容属性，让collectConfig/applyConfig中的audioSourceCombo引用仍然有效
                property int audioSourceIndex: 1  // 0=默认, 1=TTS合成（默认TTS）
                Item {
                    id: audioSourceCombo
                    property int currentIndex: parent.audioSourceIndex
                    onCurrentIndexChanged: parent.audioSourceIndex = currentIndex
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    // [默认] 按钮 - 深蓝背景 + 青色边框
                    Button {
                        id: defaultAudioBtn
                        text: "默认"
                        checkable: true
                        checked: parent.parent.audioSourceIndex === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        background: Rectangle {
                            color: defaultAudioBtn.checked ? "#0a1929" :
                                   (defaultAudioBtn.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: defaultAudioBtn.checked ? "#00d4ff" :
                                          (defaultAudioBtn.hovered ? "#2196F3" : "#334155")
                            border.width: defaultAudioBtn.checked ? 2 : 1

                            Rectangle {
                                visible: defaultAudioBtn.checked
                                anchors.top: parent.top
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1
                                height: 2; radius: 1; color: "#00d4ff"
                            }
                        }

                        contentItem: Text {
                            text: defaultAudioBtn.text
                            font.pixelSize: 16; font.bold: defaultAudioBtn.checked
                            color: defaultAudioBtn.checked ? "#00d4ff" : "#9E9E9E"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            parent.parent.parent.audioSourceIndex = 0
                            ttsAudioBtn.checked = false
                        }
                    }

                    // [TTS] 按钮 - 深绿背景 + 绿色边框
                    Button {
                        id: ttsAudioBtn
                        text: "TTS"
                        checkable: true
                        checked: parent.parent.audioSourceIndex === 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        background: Rectangle {
                            color: ttsAudioBtn.checked ? "#0d2218" :
                                   (ttsAudioBtn.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: ttsAudioBtn.checked ? "#22C55E" :
                                          (ttsAudioBtn.hovered ? "#2196F3" : "#334155")
                            border.width: ttsAudioBtn.checked ? 2 : 1

                            Rectangle {
                                visible: ttsAudioBtn.checked
                                anchors.top: parent.top
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1
                                height: 2; radius: 1; color: "#22C55E"
                            }
                        }

                        contentItem: Text {
                            text: ttsAudioBtn.text
                            font.pixelSize: 16; font.bold: ttsAudioBtn.checked
                            color: ttsAudioBtn.checked ? "#22C55E" : "#9E9E9E"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            parent.parent.parent.audioSourceIndex = 1
                            defaultAudioBtn.checked = false
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        root.requestFocusParamIndex(12)
                        mouse.accepted = false
                    }
                    z: -1
                }

                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 12) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 12) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== 第七行：状态指示区域（只读）==========
            // ✅ 2026-03-10 [Phase 7.48.33]: 新增运行LED和反馈LED指示灯
            // ✅ 2026-03-10 [Phase 7.48.36]: 行号+1（插入反馈延时行）

            // 分隔线
            // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从6修正为7（停止延时插入后未递增）
            Rectangle {
                Layout.column: 0; Layout.row: 7
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 8; Layout.bottomMargin: 8
                color: "#334155"
            }

            Text {
                // ✅ 2026-03-13 [Phase 7.48.43]: 合并状态指示和传感器数据为一个区域
                text: "状态监控"
                font.pixelSize: 19; font.bold: true; color: "#7dd3fc"
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从7修正为8
                Layout.column: 0; Layout.row: 8
                Layout.columnSpan: 4
                Layout.alignment: Qt.AlignHCenter
            }

            // 运行LED
            Text {
                text: "运行状态:"
                font.pixelSize: 21; color: "#9E9E9E"
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从8修正为9
                Layout.column: 0; Layout.row: 9
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                id: motorRunItem
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从8修正为9
                Layout.column: 1; Layout.row: 9
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 40

                // ✅ 2026-03-10 [Phase 7.48.33]: 使用属性+Connections实现实时刷新
                // ✅ 2026-03-10 [Phase 7.48.35]: 修复 parent 引用错误，改用 id 引用
                // ✅ 2026-03-10 [Phase 7.48.36]: 改用 doDataManager（前后端分离）
                // 旧：监听 diDataManager.module1DataChanged/module2DataChanged
                // 新：监听 doDataManager.doStatesChanged，读取 do_states[outputChannel]
                // ✅ 2026-03-12 [Phase 7.48.40]: 修复所有电机运行状态显示一致的bug
                // 原因：仅在doStatesChanged信号时更新，切换电机/通道变化时不会刷新
                // 修复：增加outputChannelSpin.value变化时也刷新LED状态
                property bool motorIsOn: false

                // ✅ 2026-03-12: 通道值变化时刷新LED状态
                Connections {
                    target: outputChannelSpin
                    function onValueChanged() {
                        if (typeof doDataManager !== "undefined") {
                            motorRunItem.motorIsOn = doDataManager.getDoState(outputChannelSpin.value)
                        }
                    }
                }

                Connections {
                    target: typeof doDataManager !== "undefined" ? doDataManager : null
                    function onDoStatesChanged() {
                        motorRunItem.motorIsOn = doDataManager.getDoState(outputChannelSpin.value)
                    }
                }

                // ✅ 2026-03-12: 组件加载时读取当前状态
                Component.onCompleted: {
                    if (typeof doDataManager !== "undefined") {
                        motorRunItem.motorIsOn = doDataManager.getDoState(outputChannelSpin.value)
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // LED 指示灯
                    Rectangle {
                        id: motorRunLed
                        width: 24; height: 24; radius: 12
                        anchors.verticalCenter: parent.verticalCenter

                        property bool isOn: motorRunItem.motorIsOn

                        color: isOn ? "#22C55E" : "#1a1a2e"
                        border.color: isOn ? "#86EFAC" : "#475569"
                        border.width: 2

                        // 内部高亮点
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            anchors.centerIn: parent
                            color: motorRunLed.isOn ? "#bbf7d0" : "#334155"
                            opacity: motorRunLed.isOn ? 0.8 : 0.3
                        }

                        // 发光效果
                        Rectangle {
                            visible: motorRunLed.isOn
                            width: 32; height: 32; radius: 16
                            anchors.centerIn: parent
                            color: "#22C55E"; opacity: 0.2
                            z: -1
                        }
                    }

                    Text {
                        text: motorRunLed.isOn ? "运行中" : "已停止"
                        font.pixelSize: 18
                        color: motorRunLed.isOn ? "#22C55E" : "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-03-22 [Phase 7.48.74.1]: 移除焦点指示器（运行状态为只读，不需要键盘导航）
                // 旧：focusParamIndex === 13 焦点指示器
            }

            // 反馈LED
            Text {
                text: "反馈状态:"
                font.pixelSize: 21; color: "#9E9E9E"
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从8修正为9
                Layout.column: 2; Layout.row: 9
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4
            }
            Item {
                id: feedbackLedItem
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从8修正为9
                Layout.column: 3; Layout.row: 9
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 40
                opacity: useFeedbackSwitch.checked ? 1.0 : 0.4

                // ✅ 2026-03-10 [Phase 7.48.33]: 使用属性+Connections实现实时刷新
                // ✅ 2026-03-10 [Phase 7.48.35]: 修复 parent 引用错误，改用 id 引用
                // ✅ 2026-03-10 [Phase 7.48.36]: 改用 doDataManager（前后端分离）
                // 旧：监听 diDataManager.module1DataChanged/module2DataChanged
                // 新：监听 doDataManager.diFeedbackChanged，读取 di_feedback[feedbackChannel]
                property bool feedbackIsOn: false

                Connections {
                    target: typeof doDataManager !== "undefined" ? doDataManager : null
                    function onDiFeedbackChanged() {
                        feedbackLedItem.feedbackIsOn = doDataManager.getFeedback(feedbackChannelSpin.value)
                        // ✅ 2026-03-10 [Phase 7.48.36]: 收到反馈时取消超时计时
                        if (feedbackLedItem.feedbackIsOn && root.waitingForFeedback) {
                            root.waitingForFeedback = false
                            console.log("✅ [BasicConfigTab] 电机", (root.motorIndex + 1), "反馈已收到，取消超时计时")
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // 反馈 LED 指示灯
                    Rectangle {
                        id: motorFeedbackLed
                        width: 24; height: 24; radius: 12
                        anchors.verticalCenter: parent.verticalCenter

                        property bool isOn: feedbackLedItem.feedbackIsOn

                        color: isOn ? "#00d4ff" : "#1a1a2e"
                        border.color: isOn ? "#7dd3fc" : "#475569"
                        border.width: 2

                        // 内部高亮点
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            anchors.centerIn: parent
                            color: motorFeedbackLed.isOn ? "#bae6fd" : "#334155"
                            opacity: motorFeedbackLed.isOn ? 0.8 : 0.3
                        }

                        // 发光效果
                        Rectangle {
                            visible: motorFeedbackLed.isOn
                            width: 32; height: 32; radius: 16
                            anchors.centerIn: parent
                            color: "#00d4ff"; opacity: 0.2
                            z: -1
                        }
                    }

                    Text {
                        text: motorFeedbackLed.isOn ? "已反馈" : "无反馈"
                        font.pixelSize: 18
                        color: motorFeedbackLed.isOn ? "#00d4ff" : "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-03-22 [Phase 7.48.74.1]: 移除焦点指示器（反馈状态为只读，不需要键盘导航）
                // 旧：focusParamIndex === 14 焦点指示器
            }

            // ========== 传感器实时数据（合并到状态监控区域）==========
            // ✅ 2026-03-13 [Phase 7.48.43]: 去掉独立分隔线和标题，直接跟在LED后面

            // 9个保护参数的实时值网格
            Item {
                id: sensorDataPanel
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从9修正为10
                Layout.column: 0; Layout.row: 10
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: motorValueGrid.implicitHeight + 16
                Layout.leftMargin: 8; Layout.rightMargin: 8

                // 数据模型：9个保护参数 (tabIndex 1-9)
                // ✅ 2026-03-13 [Phase 7.48.43]: 改为中文名称（TTS兼容）
                property var motorValues: [
                    { tab: 1, name: "电流",     value: 0.0, unit: "A",  exceeded: false },
                    { tab: 2, name: "前轴承温度", value: 0.0, unit: "℃", exceeded: false },
                    { tab: 3, name: "后轴承温度", value: 0.0, unit: "℃", exceeded: false },
                    { tab: 4, name: "甲相绕组",   value: 0.0, unit: "℃", exceeded: false },
                    { tab: 5, name: "乙相绕组",   value: 0.0, unit: "℃", exceeded: false },
                    { tab: 6, name: "丙相绕组",   value: 0.0, unit: "℃", exceeded: false },
                    { tab: 7, name: "电机温度",   value: 0.0, unit: "℃", exceeded: false },
                    { tab: 8, name: "水平振动",   value: 0.0, unit: "mm/s", exceeded: false },
                    { tab: 9, name: "垂直振动",   value: 0.0, unit: "mm/s", exceeded: false }
                ]

                // 接收 MqttProtectionMonitor 的 motorValueUpdated 信号
                Connections {
                    target: typeof mqttProtectionMonitor !== "undefined" ? mqttProtectionMonitor : null
                    function onMotorValueUpdated(motorIdx, tabIdx, engValue, unitStr, protName, isExceeded) {
                        if (motorIdx !== root.motorIndex) return
                        var vals = sensorDataPanel.motorValues
                        for (var i = 0; i < vals.length; i++) {
                            if (vals[i].tab === tabIdx) {
                                vals[i].value = engValue
                                vals[i].exceeded = isExceeded
                                if (unitStr !== "") vals[i].unit = unitStr
                                if (protName !== "") vals[i].name = protName
                                sensorDataPanel.motorValues = vals
                                break
                            }
                        }
                    }
                }

                Grid {
                    id: motorValueGrid
                    anchors.fill: parent
                    anchors.margins: 4
                    columns: 3
                    rowSpacing: 4
                    columnSpacing: 6

                    Repeater {
                        model: sensorDataPanel.motorValues

                        Rectangle {
                            width: (motorValueGrid.width - motorValueGrid.columnSpacing * 2) / 3
                            height: 50
                            radius: 4
                            color: "#0d1b2a"
                            border.width: 1
                            border.color: modelData.exceeded ? "#ef4444" : "#1e3a5f"

                            // 超限脉冲发光
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: "transparent"
                                border.width: 2
                                border.color: modelData.exceeded ? "#ef4444" : "transparent"
                                visible: modelData.exceeded
                                opacity: 0.6
                                SequentialAnimation on opacity {
                                    running: modelData.exceeded
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.6; to: 0.15; duration: 800 }
                                    NumberAnimation { from: 0.15; to: 0.6; duration: 800 }
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 1

                                Row {
                                    width: parent.width
                                    spacing: 4
                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.exceeded ? "#ef4444" :
                                               (modelData.value !== 0.0 ? "#22c55e" : "#475569")
                                    }
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 13; color: "#94a3b8"
                                        elide: Text.ElideRight
                                        width: parent.width - 10
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Text {
                                        text: modelData.value.toFixed(1)
                                        font.pixelSize: 22
                                        font.family: "Consolas"
                                        font.bold: true
                                        color: modelData.exceeded ? "#ef4444" :
                                               (modelData.value !== 0.0 ? "#00d4ff" : "#475569")
                                    }
                                    Text {
                                        text: modelData.unit
                                        font.pixelSize: 12; color: "#64748b"
                                        anchors.bottom: parent.children[0].bottom
                                        anchors.bottomMargin: 2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ========== 第九行：测试操作区域 ==========
            // ✅ 2026-03-10 [Phase 7.48.33]: 新增启动/停止测试按钮
            // ✅ 2026-03-10 [Phase 7.48.36]: 行号+1（插入反馈延时行）
            // ✅ 2026-03-13 [Phase 7.48.43]: 行号+3（插入传感器实时数据区域）

            // 分隔线
            Rectangle {
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从10修正为11
                Layout.column: 0; Layout.row: 11
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 8; Layout.bottomMargin: 8
                color: "#334155"
            }

            Text {
                text: "测试操作"
                font.pixelSize: 19; font.bold: true; color: "#fbbf24"
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从11修正为12
                Layout.column: 0; Layout.row: 12
                Layout.columnSpan: 4
                Layout.alignment: Qt.AlignHCenter
            }

            // 启动按钮标签
            Text {
                text: "电机控制:"
                font.pixelSize: 21; color: "#9E9E9E"
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从12修正为13
                Layout.column: 0; Layout.row: 13
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 行号从12修正为13
                Layout.column: 1; Layout.row: 13
                Layout.fillWidth: true; Layout.maximumWidth: 300
                Layout.columnSpan: 3
                implicitHeight: 56

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20

                    // 启动按钮
                    Button {
                        id: motorStartBtn
                        text: "启 动"
                        width: 120; height: 48

                        background: Rectangle {
                            color: motorStartBtn.pressed ? "#166534" :
                                   (motorStartBtn.hovered ? "#15803d" : "#0d2218")
                            radius: 8
                            border.color: motorStartBtn.pressed ? "#86EFAC" :
                                          (motorStartBtn.hovered ? "#22C55E" : "#334155")
                            border.width: 2

                            // 顶部高亮线
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 2; anchors.rightMargin: 2; anchors.topMargin: 2
                                height: 2; radius: 1; color: "#22C55E"; opacity: 0.6
                            }
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                // LED 点
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: motorRunLed.isOn ? "#22C55E" : "#475569"
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        anchors.centerIn: parent
                                        color: motorRunLed.isOn ? "#86EFAC" : "#64748B"
                                    }
                                }
                                Text {
                                    text: motorStartBtn.text
                                    font.pixelSize: 16; font.bold: true
                                    color: "#22C55E"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        onClicked: {
                            // ✅ 2026-03-12 [Phase 7.48.41]: 修改启动流程
                            // 旧：点击后立即播放语音+立即发送MQTT命令
                            // 新：点击后播放预警语音 → 等待启动延时 → 延时结束后发送MQTT命令
                            if (warningVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
                                var beltNum = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
                                var audioPath = buildAudioPath(beltNum, warningVoiceField.text)
                                var ttsText = beltNum + "号皮带" + (root.motorIndex + 1) + "号电机准备启动，请注意安全"
                                alarmPlayback.playAlarm(warningVoiceField.text, ttsText, audioPath, true, "count", 1, 5)
                            }
                            // 启动延时计时器（延时结束后才发送MQTT启动命令）
                            console.log("⏱️ [BasicConfigTab] 电机", (root.motorIndex + 1), "启动延时:", startupDelaySpin.value, "秒")
                            startupDelayTimer.restart()
                        }
                    }

                    // 停止按钮
                    Button {
                        id: motorStopBtn
                        text: "停 止"
                        width: 120; height: 48

                        background: Rectangle {
                            color: motorStopBtn.pressed ? "#7f1d1d" :
                                   (motorStopBtn.hovered ? "#991b1b" : "#1a0a0a")
                            radius: 8
                            border.color: motorStopBtn.pressed ? "#fca5a5" :
                                          (motorStopBtn.hovered ? "#ef4444" : "#334155")
                            border.width: 2

                            // 顶部高亮线
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 2; anchors.rightMargin: 2; anchors.topMargin: 2
                                height: 2; radius: 1; color: "#ef4444"; opacity: 0.6
                            }
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                // LED 点
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#ef4444"
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        anchors.centerIn: parent
                                        color: "#fca5a5"
                                    }
                                }
                                Text {
                                    text: motorStopBtn.text
                                    font.pixelSize: 16; font.bold: true
                                    color: "#ef4444"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        onClicked: {
                            // ✅ 2026-03-10 [Phase 7.48.35]: 直接发布MQTT命令到DO模块1控制电机
                            // 设备5（Luckfox-Lyra-RK3506-5）= DO模块1，MQTT主题为 module1
                            var ch = outputChannelSpin.value
                            var topic = "belt_control/do/module1/cmd"
                            var cmd = JSON.stringify({"action": "set", "channel": ch, "value": 0})
                            console.log("🔌 [BasicConfigTab] 停止电机", (root.motorIndex + 1), "通道:", ch)
                            if (typeof mqttController !== "undefined") {
                                mqttController.publish(topic, cmd, 1, false)
                            }
                        }
                    }
                }

                // 焦点指示器
                // ✅ 2026-03-22 [Phase 7.48.74.1]: 索引从15调整为13（移除只读LED导航后重编号）
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 13) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 13) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    // ✅ 2026-03-10 [Phase 7.48.34]: 从8扩展到9（新增"是否使用反馈"开关，反馈通道右移）
    // ✅ 2026-03-22 [Phase 7.48.74.1]: 从16缩减到14（移除运行LED和反馈LED的导航）
    // 旧值：return 16
    function getParamFieldCount() {
        return 14  // 0运行状态、1模块类型、2模块地址、3输出通道、4使用反馈、5反馈通道、6反馈延时、7启动延时、8停止延时、9预警语音、10失败语音、11启动键、12音频来源、13测试按钮
    }

    // ✅ 2026-03-22 [Phase 7.48.74.1]: 移除运行LED和反馈LED行，测试按钮重编号
    // 旧值：[[0,2],[2,2],[4,2],[6,2],[8,1],[9,2],[11,2],[13,2],[15,1]]
    function getParamRows() {
        return [[0,2],[2,2],[4,2],[6,2],[8,1],[9,2],[11,2],[13,1]]
        // Row0: 运行状态+模块类型  Row1: 模块地址+输出通道
        // Row2: 使用反馈+反馈通道  Row3: 反馈延时+启动延时
        // Row4: 停止延时(单列)     Row5: 预警语音+失败语音
        // Row6: 启动键+音频来源    Row7: 测试按钮(单列)
    }

    // 触发参数输入
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.14]: 使用 CustomSpinBox 的 activateVirtualKeyboard()
    // 原因：CustomSpinBox 已经内置了虚拟键盘自动滚动功能，不需要手动调用 virtualKeyboard.openForField
    function triggerParamInput(paramIndex) {
        console.log("✅ [BasicConfigTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // 运行状态（RadioButton 组）
            console.log("✅ [BasicConfigTab] 切换运行状态")
            // TODO: 切换运行状态
            break
        case 1:  // 模块类型（只读）
            console.log("✅ [BasicConfigTab] 模块类型（只读）")
            break
        case 2:  // 模块地址
            console.log("✅ [BasicConfigTab] 模块地址")
            inputField = moduleAddressSpin
            break
        case 3:  // 输出通道
            console.log("✅ [BasicConfigTab] 输出通道")
            inputField = outputChannelSpin
            break
        case 4:  // 是否使用反馈（Switch切换）
            // ✅ 2026-03-10 [Phase 7.48.34]: 新增
            console.log("✅ [BasicConfigTab] 切换是否使用反馈")
            useFeedbackSwitch.checked = !useFeedbackSwitch.checked
            break
        case 5:  // 反馈通道
            console.log("✅ [BasicConfigTab] 反馈通道")
            inputField = feedbackChannelSpin
            break
        case 6:  // 反馈延时
            // ✅ 2026-03-10 [Phase 7.48.36]: 新增
            console.log("✅ [BasicConfigTab] 反馈延时")
            inputField = feedbackDelaySpin
            break
        // ✅ 2026-03-10 [Phase 7.48.37]: 新增4个参数
        case 7:  // 启动延时
            console.log("✅ [BasicConfigTab] 启动延时")
            inputField = startupDelaySpin
            break
        // ✅ 2026-03-22 [Phase 7.48.74]: 新增停止延时
        case 8:  // 停止延时
            console.log("✅ [BasicConfigTab] 停止延时")
            inputField = stopDelaySpin
            break
        case 9:  // 预警语音
            console.log("✅ [BasicConfigTab] 预警语音")
            warningVoiceField.forceActiveFocus()
            break
        case 10:  // 失败语音
            console.log("✅ [BasicConfigTab] 失败语音")
            failureVoiceField.forceActiveFocus()
            break
        case 11:  // 启动键
            console.log("✅ [BasicConfigTab] 启动键")
            startupKeyCombo.popup.open()
            break
        // ✅ 2026-03-12: 音频来源改为ButtonGroup，点击切换选中状态
        // ✅ 2026-03-22 [Phase 7.48.74]: 索引从11调整为12
        case 12:  // 音频来源
            console.log("✅ [BasicConfigTab] 音频来源切换")
            // 旧：audioSourceCombo.popup.open()
            // 新：切换按钮选中状态
            if (audioSourceCombo.currentIndex === 0) {
                audioSourceCombo.currentIndex = 1
                ttsAudioBtn.checked = true
                defaultAudioBtn.checked = false
            } else {
                audioSourceCombo.currentIndex = 0
                defaultAudioBtn.checked = true
                ttsAudioBtn.checked = false
            }
            break
        // ✅ 2026-03-22 [Phase 7.48.74.1]: 移除运行LED(13)和反馈LED(14)的导航，测试按钮索引从15调整为13
        case 13:  // 测试按钮（启动/停止切换）
            console.log("✅ [BasicConfigTab] 测试按钮 - 切换电机状态")
            var ch8 = outputChannelSpin.value
            var topic8 = "belt_control/do/module1/cmd"
            if (motorRunLed.isOn) {
                // 停止：立即发送
                var cmd8off = JSON.stringify({"action": "set", "channel": ch8, "value": 0})
                if (typeof mqttController !== "undefined") {
                    mqttController.publish(topic8, cmd8off, 1, false)
                }
            } else {
                // ✅ 2026-03-12 [Phase 7.48.41]: 启动走延时流程（与启动按钮一致）
                // 旧：立即发送MQTT命令
                // 新：播放预警语音 → 启动延时 → 延时结束后发送
                if (warningVoiceField.text.length > 0 && typeof alarmPlayback !== "undefined") {
                    var beltNum8 = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
                    var audioPath8 = buildAudioPath(beltNum8, warningVoiceField.text)
                    var ttsText8 = beltNum8 + "号皮带" + (root.motorIndex + 1) + "号电机准备启动，请注意安全"
                    alarmPlayback.playAlarm(warningVoiceField.text, ttsText8, audioPath8, true, "count", 1, 5)
                }
                console.log("⏱️ [BasicConfigTab] 测试按钮启动延时:", startupDelaySpin.value, "秒")
                startupDelayTimer.restart()
            }
            break
        }

        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.14]: 使用 CustomSpinBox 的 activateVirtualKeyboard()
        // CustomSpinBox 会自动处理虚拟键盘显示和 ScrollView 滚动
        if (inputField) {
            console.log("✅ [BasicConfigTab] 激活虚拟键盘 - 控件:", inputField)
            // 如果控件有 activateVirtualKeyboard 函数，调用它（CustomSpinBox）
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                // 否则直接设置焦点
                inputField.forceActiveFocus()
            }
        }
    }

    // ✅ 2026-02-02 [参数持久化]: 收集配置参数
    // ✅ 2026-03-10 [Phase 7.48.31]: 修正键名与数据库列名匹配（motor_module_address）
    function collectConfig() {
        var config = {}

        // 收集所有参数字段
        // 注意：运行状态使用自定义 RadioButton，需要检查内部 Rectangle 的 visible 属性
        config["running_state"] = "投入"  // 默认值，实际应该从 RadioButton 状态读取
        // 旧：config["module_type"] = "继电器模块"  // 固定值（不存入数据库）
        // 旧：config["module_address"] = moduleAddressSpin.value || 1
        config["motor_module_address"] = moduleAddressSpin.value || 1
        config["output_channel"] = outputChannelSpin.value
        config["use_feedback"] = useFeedbackSwitch.checked ? 1 : 0  // ✅ 2026-03-10 [Phase 7.48.34]
        config["feedback_channel"] = feedbackChannelSpin.value
        config["feedback_delay"] = feedbackDelaySpin.value  // ✅ 2026-03-10 [Phase 7.48.36]
        // ✅ 2026-03-10 [Phase 7.48.37]: 新增4个参数
        config["startup_delay"] = startupDelaySpin.value
        // ✅ 2026-03-22 [Phase 7.48.74]: 新增独立停止延时
        config["stop_delay"] = stopDelaySpin.value
        config["warning_voice"] = warningVoiceField.text
        config["failure_voice"] = failureVoiceField.text
        config["startup_key"] = startupKeyCombo.currentText
        // ✅ 2026-03-12: 新增音频来源（default=默认, tts=TTS合成）
        config["audio_source"] = audioSourceCombo.currentIndex === 0 ? "default" : "tts"

        console.log("✅ [BasicConfigTab] 收集配置:", JSON.stringify(config))
        return config
    }

    // ✅ 2026-02-02 [参数持久化]: 应用配置参数
    // ✅ 2026-03-10 [Phase 7.48.31]: 修正键名与数据库列名匹配（motor_module_address）
    function applyConfig(config) {
        console.log("✅ [BasicConfigTab] 应用配置:", JSON.stringify(config))

        // ✅ 2026-03-14 [Phase 7.48.44]: 检查配置的motor_index是否匹配当前电机
        // 原因：Qt.callLater竞态条件，切换电机时上一个电机的loadMotorConfig可能延迟执行
        if (config["motor_index"] !== undefined && config["motor_index"] !== root.motorIndex) {
            console.log("⚠️ [BasicConfigTab] 配置motor_index:", config["motor_index"], "≠ 当前motorIndex:", root.motorIndex, "，忽略")
            return
        }

        // 应用所有参数字段
        // 旧：config["module_address"]
        if (config["motor_module_address"] !== undefined) {
            moduleAddressSpin.value = config["motor_module_address"]
        }
        if (config["output_channel"] !== undefined) {
            outputChannelSpin.value = config["output_channel"]
        }
        // ✅ 2026-03-10 [Phase 7.48.34]: 加载是否使用反馈
        if (config["use_feedback"] !== undefined) {
            useFeedbackSwitch.checked = (config["use_feedback"] === 1)
        }
        if (config["feedback_channel"] !== undefined) {
            feedbackChannelSpin.value = config["feedback_channel"]
        }
        // ✅ 2026-03-10 [Phase 7.48.36]: 加载反馈延时
        if (config["feedback_delay"] !== undefined) {
            feedbackDelaySpin.value = config["feedback_delay"]
        }
        // ✅ 2026-03-10 [Phase 7.48.37]: 加载新增4个参数
        if (config["startup_delay"] !== undefined) {
            startupDelaySpin.value = config["startup_delay"]
        }
        // ✅ 2026-03-22 [Phase 7.48.74]: 加载独立停止延时
        if (config["stop_delay"] !== undefined) {
            stopDelaySpin.value = config["stop_delay"]
        }
        if (config["warning_voice"] !== undefined) {
            warningVoiceField.text = config["warning_voice"]
        }
        if (config["failure_voice"] !== undefined) {
            failureVoiceField.text = config["failure_voice"]
        }
        if (config["startup_key"] !== undefined) {
            var keyIdx = startupKeyCombo.model.indexOf(config["startup_key"])
            if (keyIdx >= 0) startupKeyCombo.currentIndex = keyIdx
        }
        // ✅ 2026-03-12: 加载音频来源
        if (config["audio_source"] !== undefined) {
            audioSourceCombo.currentIndex = (config["audio_source"] === "tts") ? 1 : 0
        }
        // 注意：运行状态和模块类型暂时不处理，因为它们是自定义控件
    }
}
