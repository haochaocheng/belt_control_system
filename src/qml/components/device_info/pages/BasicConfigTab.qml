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
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性（已废弃）
    // property var keyboardManager: null

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusParamIndex: 0  // 参数区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

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
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 10
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
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 10
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
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    function getParamFieldCount() {
        return 5  // 5个参数字段：运行状态、模块类型、模块地址、输出通道、反馈通道
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [BasicConfigTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null
        var inputMode = "numeric"  // 默认数字模式

        switch(paramIndex) {
        case 0:  // 运行状态（RadioButton 组）
            console.log("✅ [BasicConfigTab] 切换运行状态")
            // TODO: 切换运行状态
            break
        case 1:  // 模块类型（只读）
            console.log("✅ [BasicConfigTab] 模块类型（只读）")
            break
        case 2:  // 模块地址
            inputField = moduleAddressSpin
            inputMode = "numeric"
            break
        case 3:  // 输出通道
            inputField = outputChannelSpin
            inputMode = "numeric"
            break
        case 4:  // 反馈通道
            inputField = feedbackChannelSpin
            inputMode = "numeric"
            break
        }

        // 打开虚拟键盘
        if (virtualKeyboard && inputField) {
            console.log("✅ [BasicConfigTab] 打开 Qt 虚拟键盘 - 控件:", inputField, "模式:", inputMode)
            virtualKeyboard.openForField(inputField, function(newValue) {
                console.log("✅ [BasicConfigTab] 虚拟键盘输入完成:", newValue)
            }, inputMode, root)
        } else {
            console.log("⚠️ [BasicConfigTab] 虚拟键盘或输入控件不可用")
        }
    }

    // ✅ 2026-02-02 [参数持久化]: 收集配置参数
    function collectConfig() {
        var config = {}

        // 收集所有参数字段
        // 注意：运行状态使用自定义 RadioButton，需要检查内部 Rectangle 的 visible 属性
        config["running_state"] = "投入"  // 默认值，实际应该从 RadioButton 状态读取
        config["module_type"] = "继电器模块"  // 固定值
        config["module_address"] = moduleAddressSpin.value || 1
        config["output_channel"] = outputChannelSpin.value || 0
        config["feedback_channel"] = feedbackChannelSpin.value || 0

        console.log("✅ [BasicConfigTab] 收集配置:", JSON.stringify(config))
        return config
    }

    // ✅ 2026-02-02 [参数持久化]: 应用配置参数
    function applyConfig(config) {
        console.log("✅ [BasicConfigTab] 应用配置:", JSON.stringify(config))

        // 应用所有参数字段
        if (config["module_address"] !== undefined) {
            moduleAddressSpin.value = config["module_address"]
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
