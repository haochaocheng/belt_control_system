import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
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
                    to: 7
                    value: root.motorIndex
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

            // ========== 第三行：反馈通道（左侧，索引4）==========

            // 反馈通道标签
            Text {
                text: "反馈通道:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160  // ✅ 2026-01-30 [FIX 100.300.107.3]: 从 120 增加到 160
                horizontalAlignment: Text.AlignRight
            }

            // 反馈通道输入
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: feedbackChannelSpin.implicitHeight  // ✅ 引用 SpinBox 的 implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: feedbackChannelSpin
                    anchors.fill: parent
                    from: 0
                    to: 7
                    value: root.motorIndex
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
                        console.log("✅ [BasicConfigTab] 鼠标点击反馈通道，发射信号: requestFocusParamIndex(4)")

                        // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 发射信号，而不是直接赋值
                        // 避免打破 Qt.binding
                        root.requestFocusParamIndex(4)

                        mouse.accepted = false  // 让事件继续传递给 SpinBox
                    }
                }

                // 焦点指示器
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.2]: 大幅增加 z 值，确保在所有元素之上
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.5]: 移除测试背景色，添加渲染状态日志
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.5.2]: 移除无效的 onBorderColorChanged，改用 Connections
                Rectangle {
                    id: feedbackChannelFocusIndicator
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false

                    Component.onCompleted: {
                        console.log("🔵 [反馈通道焦点指示器] 组件加载完成")
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
                            if (root.focusParamIndex === 4) {
                                console.log("🔵 [反馈通道焦点指示器] 获得焦点")
                                console.log("  - border.color:", feedbackChannelFocusIndicator.border.color)
                                console.log("  - border.width:", feedbackChannelFocusIndicator.border.width)
                                console.log("  - visible:", feedbackChannelFocusIndicator.visible)
                                console.log("  - opacity:", feedbackChannelFocusIndicator.opacity)
                                console.log("  - z:", feedbackChannelFocusIndicator.z)
                                console.log("  - width:", feedbackChannelFocusIndicator.width, "height:", feedbackChannelFocusIndicator.height)
                                console.log("  - x:", feedbackChannelFocusIndicator.x, "y:", feedbackChannelFocusIndicator.y)
                            }
                        }
                    }
                }
            }

            // ========== 第四行：状态指示区域（只读）==========
            // ✅ 2026-03-10 [Phase 7.48.33]: 新增运行LED和反馈LED指示灯

            // 分隔线
            Rectangle {
                Layout.column: 0; Layout.row: 3
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 8; Layout.bottomMargin: 8
                color: "#334155"
            }

            Text {
                text: "状态指示"
                font.pixelSize: 19; font.bold: true; color: "#7dd3fc"
                Layout.column: 0; Layout.row: 4
                Layout.columnSpan: 4
                Layout.alignment: Qt.AlignHCenter
            }

            // 运行LED
            Text {
                text: "运行状态:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 5
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 40

                // ✅ 2026-03-10 [Phase 7.48.33]: 使用属性+Connections实现实时刷新
                property bool motorIsOn: false

                Connections {
                    target: typeof diDataManager !== "undefined" ? diDataManager : null
                    function onModule1DataChanged() {
                        if (moduleAddressSpin.value === 1) {
                            parent.motorIsOn = diDataManager.getBit(0, outputChannelSpin.value)
                        }
                    }
                    function onModule2DataChanged() {
                        if (moduleAddressSpin.value === 2) {
                            parent.motorIsOn = diDataManager.getBit(1, outputChannelSpin.value)
                        }
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

                        property bool isOn: parent.parent.motorIsOn

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

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // 反馈LED
            Text {
                text: "反馈状态:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 2; Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 3; Layout.row: 5
                Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 40

                // ✅ 2026-03-10 [Phase 7.48.33]: 使用属性+Connections实现实时刷新
                property bool feedbackIsOn: false

                Connections {
                    target: typeof diDataManager !== "undefined" ? diDataManager : null
                    function onModule1DataChanged() {
                        if (moduleAddressSpin.value === 1) {
                            parent.feedbackIsOn = diDataManager.getBit(0, feedbackChannelSpin.value)
                        }
                    }
                    function onModule2DataChanged() {
                        if (moduleAddressSpin.value === 2) {
                            parent.feedbackIsOn = diDataManager.getBit(1, feedbackChannelSpin.value)
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

                        property bool isOn: parent.parent.feedbackIsOn

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

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }

            // ========== 第五行：测试操作区域 ==========
            // ✅ 2026-03-10 [Phase 7.48.33]: 新增启动/停止测试按钮

            // 分隔线
            Rectangle {
                Layout.column: 0; Layout.row: 6
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 8; Layout.bottomMargin: 8
                color: "#334155"
            }

            Text {
                text: "测试操作"
                font.pixelSize: 19; font.bold: true; color: "#fbbf24"
                Layout.column: 0; Layout.row: 7
                Layout.columnSpan: 4
                Layout.alignment: Qt.AlignHCenter
            }

            // 启动按钮标签
            Text {
                text: "电机控制:"
                font.pixelSize: 21; color: "#9E9E9E"
                Layout.column: 0; Layout.row: 8
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }
            Item {
                Layout.column: 1; Layout.row: 8
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
                            console.log("🔌 [BasicConfigTab] 启动电机", (root.motorIndex + 1))
                            if (typeof mqttProtectionMonitor !== "undefined") {
                                mqttProtectionMonitor.publishMotorCommand(root.deviceId, root.motorIndex, true)
                            }
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
                            console.log("🔌 [BasicConfigTab] 停止电机", (root.motorIndex + 1))
                            if (typeof mqttProtectionMonitor !== "undefined") {
                                mqttProtectionMonitor.publishMotorCommand(root.deviceId, root.motorIndex, false)
                            }
                        }
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent; color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4; z: 1000; enabled: false
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    // ✅ 2026-03-10 [Phase 7.48.33]: 从5扩展到8（新增运行LED、反馈LED、测试按钮）
    // 旧值：return 5
    function getParamFieldCount() {
        return 8  // 0运行状态、1模块类型、2模块地址、3输出通道、4反馈通道、5运行LED、6反馈LED、7测试按钮
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
        case 4:  // 反馈通道
            console.log("✅ [BasicConfigTab] 反馈通道")
            inputField = feedbackChannelSpin
            break
        // ✅ 2026-03-10 [Phase 7.48.33]: 新增状态指示和测试操作
        case 5:  // 运行LED（只读）
            console.log("✅ [BasicConfigTab] 运行LED（只读）")
            break
        case 6:  // 反馈LED（只读）
            console.log("✅ [BasicConfigTab] 反馈LED（只读）")
            break
        case 7:  // 测试按钮（启动/停止切换）
            console.log("✅ [BasicConfigTab] 测试按钮 - 切换电机状态")
            if (motorRunLed.isOn) {
                // 当前运行中 → 停止
                if (typeof mqttProtectionMonitor !== "undefined") {
                    mqttProtectionMonitor.publishMotorCommand(root.deviceId, root.motorIndex, false)
                }
            } else {
                // 当前已停止 → 启动
                if (typeof mqttProtectionMonitor !== "undefined") {
                    mqttProtectionMonitor.publishMotorCommand(root.deviceId, root.motorIndex, true)
                }
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
        config["feedback_channel"] = feedbackChannelSpin.value

        console.log("✅ [BasicConfigTab] 收集配置:", JSON.stringify(config))
        return config
    }

    // ✅ 2026-02-02 [参数持久化]: 应用配置参数
    // ✅ 2026-03-10 [Phase 7.48.31]: 修正键名与数据库列名匹配（motor_module_address）
    function applyConfig(config) {
        console.log("✅ [BasicConfigTab] 应用配置:", JSON.stringify(config))

        // 应用所有参数字段
        // 旧：config["module_address"]
        if (config["motor_module_address"] !== undefined) {
            moduleAddressSpin.value = config["motor_module_address"]
        }
        if (config["output_channel"] !== undefined) {
            outputChannelSpin.value = config["output_channel"]
        }
        if (config["feedback_channel"] !== undefined) {
            feedbackChannelSpin.value = config["feedback_channel"]
        }
        // 注意：运行状态和模块类型暂时不处理，因为它们是自定义控件
    }
}
