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
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12
            implicitWidth: 1200  // 两列布局需要的最小宽度
            implicitHeight: childrenRect.height

            // ✅ 2026-01-30 [FIX 100.300.106.4]: 两列布局
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 20  // 两列之间的间距

                // ========== 左列 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    // 运行状态（索引 0）
                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "运行状态:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 0) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            Row {
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
                                        font.pixelSize: 14
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
                                        font.pixelSize: 14
                                        color: "#E0E0E0"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // 模块地址（索引 2）
                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "模块地址:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 2) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            DeviceInfo.CustomSpinBox {
                                id: moduleAddressSpin
                                anchors.fill: parent
                                from: 1
                                to: 8
                                value: 1
                                editable: true
                            }
                        }
                    }

                    // 反馈通道（索引 4）
                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "反馈通道:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 4) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            DeviceInfo.CustomSpinBox {
                                id: feedbackChannelSpin
                                anchors.fill: parent
                                from: 0
                                to: 7
                                value: root.motorIndex
                                editable: true
                            }
                        }
                    }
                }  // 左列结束

                // ========== 右列 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    // 模块类型（索引 1）
                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "模块类型:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 1) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#2d3548"
                                border.color: "#3d4556"
                                border.width: 1
                                radius: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "继电器模块"
                                    font.pixelSize: 14
                                    color: "#E0E0E0"
                                }
                            }
                        }
                    }

                    // 输出通道（索引 3）
                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "输出通道:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 3) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            DeviceInfo.CustomSpinBox {
                                id: outputChannelSpin
                                anchors.fill: parent
                                from: 0
                                to: 7
                                value: root.motorIndex
                                editable: true
                            }
                        }
                    }
                }  // 右列结束
            }  // RowLayout 结束
        }  // ColumnLayout 结束
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
}
