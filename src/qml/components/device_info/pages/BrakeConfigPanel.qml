import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-27 [制动器控制-右侧面板] 制动器配置面板（简化版，无Tab切换）
// 设计风格与电机控制完全一样，但不需要Tab栏
// ✅ 2026-01-28 [统一样式] 替换 TextField 为 CustomTextField
// ✅ 2026-01-28 [两列布局] 改为两列布局，参考 AnalogInputPage - FIX 100.300.83
// ✅ 2026-01-28 [虚拟键盘集成]: 接收并传递键盘管理器
// ✅ 2026-01-31 [FIX 100.300.111]: 改为 GridLayout 布局，集成导航功能
Rectangle {
    id: root
    implicitWidth: 1400  // ✅ 2026-01-28 修改宽度以支持两列布局
    height: 600  // 默认高度（用于QDS预览）
    // ✅ 改为透明背景，与开关量/模拟量/电机控制页面统一
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1  // ✅ 2026-02-06 [参数持久化]: 设备ID（从父组件传递）
    property int brakeIndex: 0  // 当前制动器索引 (0-7)
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性（已废弃，保留兼容性）
    property var keyboardManager: null
    // ✅ 2026-01-31 [FIX 100.300.111]: Qt 虚拟键盘引用
    property var virtualKeyboard: null
    // ✅ 2026-01-31 [FIX 100.300.111]: 导航焦点索引
    // ✅ 2026-01-31 [FIX 100.300.112.7]: 更新区域定义，添加使用状态索引
    property int focusSubArea: 0  // 0:制动器列表 1:使用状态 2:参数区域 3:底部按钮区域
    property int focusUsageStatusIndex: 0  // 使用状态焦点索引（0:投入 1:禁用）
    property int focusParamIndex: 0  // 参数区域焦点索引（0-9）
    property int focusButtonIndex: 0  // 底部按钮区域焦点索引（0-1）

    // ========== 键盘导航支持 ==========
    focus: true
    activeFocusOnTab: true

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        // ✅ 改为透明，使用背景图片
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        // ✅ 添加背景图片，填充整个 header
        Image {
            id: headerBackground
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch  // 拉伸填充整个 header
            z: -1  // 放在最底层
        }

        Text {
            anchors.centerIn: parent
            text: (root.brakeIndex + 1) + "号制动器配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域（无Tab栏，直接显示参数）==========
    Rectangle {
        id: contentArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        // ========== 滚动区域：参数字段 ==========
        ScrollView {
            anchors.fill: parent
            anchors.margins: 15
            clip: true

            // ✅ 2026-01-28 支持水平滚动
            contentWidth: Math.max(width, 1200)
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 20
                implicitWidth: 1200  // ✅ 2026-01-28 固定内容宽度
                implicitHeight: childrenRect.height  // ✅ 2026-01-28 自适应高度

                // ========== 使用状态 ==========
                // ✅ 2026-01-31 [FIX 100.300.112.7]: 添加焦点指示器
                // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 整个区域作为一个焦点单元
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "使用状态"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }

                    // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 整个 RowLayout 作为一个焦点单元
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: radioRow.implicitHeight + 20

                        RowLayout {
                            id: radioRow
                            anchors.centerIn: parent
                            spacing: 20

                            RadioButton {
                                id: statusEnabled
                                text: "投入"
                                checked: true
                                font.pixelSize: 14
                                contentItem: Text {
                                    text: statusEnabled.text
                                    font: statusEnabled.font
                                    color: "#E0E0E0"
                                    leftPadding: statusEnabled.indicator.width + statusEnabled.spacing
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            RadioButton {
                                id: statusDisabled
                                text: "禁用"
                                font.pixelSize: 14
                                contentItem: Text {
                                    text: statusDisabled.text
                                    font: statusDisabled.font
                                    color: "#E0E0E0"
                                    leftPadding: statusDisabled.indicator.width + statusDisabled.spacing
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 焦点指示器包围整个区域
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 1) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 1) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }
                }

                // ========== 分割线 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#3d4556"
                }

                // ========== GridLayout 参数区域 ==========
                // ✅ 2026-01-31 [FIX 100.300.111]: 改为 GridLayout 4列布局，与 AnalogInputPage 保持一致
                // ❌ 2026-01-31 [注释]: 移除旧的 RowLayout 两列布局（Line 140-381）
                // 原因：统一界面布局风格，提高代码可维护性，优化参数字段的视觉对齐
                GridLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    columns: 4  // 4列：标签1、输入框1、标签2、输入框2
                    columnSpacing: 10
                    rowSpacing: 12

                    // ========== 第一行：抱闸保持时间（左）、松闸保持时间（右）==========
                    // 参数索引: 0 - 抱闸保持时间（左列，行0）
                    Text {
                        text: "抱闸保持时间:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 0
                        Layout.row: 0
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 1
                        Layout.row: 0
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: holdTimeField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: holdTimeField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 0) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // 参数索引: 1 - 松闸保持时间（右列，行0）
                    Text {
                        text: "松闸保持时间:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 2
                        Layout.row: 0
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 3
                        Layout.row: 0
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: releaseTimeField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: releaseTimeField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 1) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // ========== 第二行：抱闸动作延时（左）、抱闸释放延时（右）==========
                    // 参数索引: 2 - 抱闸动作延时（左列，行1）
                    Text {
                        text: "抱闸动作延时:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 0
                        Layout.row: 1
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 1
                        Layout.row: 1
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: brakeDelayField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: brakeDelayField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 2) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // 参数索引: 3 - 抱闸释放延时（右列，行1）
                    Text {
                        text: "抱闸释放延时:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 2
                        Layout.row: 1
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 3
                        Layout.row: 1
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: releaseDelayField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: releaseDelayField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 3) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // ========== 第三行：抱闸检测延时（左）、抱闸故障延时（右）==========
                    // 参数索引: 4 - 抱闸检测延时（左列，行2）
                    Text {
                        text: "抱闸检测延时:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 0
                        Layout.row: 2
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 1
                        Layout.row: 2
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: detectDelayField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: detectDelayField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 4) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // 参数索引: 5 - 抱闸故障延时（右列，行2）
                    Text {
                        text: "抱闸故障延时:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 2
                        Layout.row: 2
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 3
                        Layout.row: 2
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: faultDelayField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: faultDelayField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 5) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // ========== 第四行：抱闸动作电流（左）、抱闸释放电流（右）==========
                    // 参数索引: 6 - 抱闸动作电流（左列，行3）
                    Text {
                        text: "抱闸动作电流:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 0
                        Layout.row: 3
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 1
                        Layout.row: 3
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: brakeCurrentField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: brakeCurrentField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 6) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // 参数索引: 7 - 抱闸释放电流（右列，行3）
                    Text {
                        text: "抱闸释放电流:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 2
                        Layout.row: 3
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 3
                        Layout.row: 3
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: releaseCurrentField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: releaseCurrentField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 7) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // ========== 第五行：抱闸动作电压（左）、抱闸释放电压（右）==========
                    // 参数索引: 8 - 抱闸动作电压（左列，行4）
                    Text {
                        text: "抱闸动作电压:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 0
                        Layout.row: 4
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 1
                        Layout.row: 4
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: brakeVoltageField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: brakeVoltageField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 8) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                    // 参数索引: 9 - 抱闸释放电压（右列，行4）
                    Text {
                        text: "抱闸释放电压:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.column: 2
                        Layout.row: 4
                        Layout.preferredWidth: 160
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.column: 3
                        Layout.row: 4
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        implicitHeight: releaseVoltageField.implicitHeight

                        DeviceInfo.CustomTextField {
                            id: releaseVoltageField
                            anchors.fill: parent
                            keyboardManager: root.keyboardManager
                            placeholderText: "0"
                            text: "0"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 2 && root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusParamIndex === 9) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                    }

                }  // GridLayout 结束

                // ========== 底部按钮区域 ==========
                // ✅ 2026-01-31 [FIX 100.300.111]: 添加焦点指示器，与 MotorControlPage 保持一致
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    spacing: 15

                    // 保存按钮（索引 0）
                    Item {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40

                        // 焦点指示器
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? 5 : 0
                            radius: 4
                            z: 10
                        }

                        Button {
                            anchors.fill: parent
                            text: "保存"
                            font.pixelSize: 14

                            background: Rectangle {
                                // 焦点时背景色更亮
                                color: {
                                    if (root.focusSubArea === 3 && root.focusButtonIndex === 0) {
                                        return "#2ecc71"  // 焦点时：亮绿色
                                    } else if (parent.pressed) {
                                        return "#1976D2"
                                    } else if (parent.hovered) {
                                        return "#2196F3"
                                    } else {
                                        return "#1E88E5"
                                    }
                                }
                                radius: 4
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#FFFFFF"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                console.log("保存制动器配置:", root.brakeIndex + 1)
                                // ✅ 2026-02-06 [参数持久化]: 保存配置到数据库
                                saveBrakeConfig()
                            }
                        }
                    }

                    // 重置按钮（索引 1）
                    Item {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40

                        // 焦点指示器
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? 5 : 0
                            radius: 4
                            z: 10
                        }

                        Button {
                            anchors.fill: parent
                            text: "重置"
                            font.pixelSize: 14

                            background: Rectangle {
                                // 焦点时背景色更亮
                                color: {
                                    if (root.focusSubArea === 3 && root.focusButtonIndex === 1) {
                                        return "#95a5a6"  // 焦点时：亮灰色
                                    } else if (parent.pressed) {
                                        return "#616161"
                                    } else if (parent.hovered) {
                                        return "#757575"
                                    } else {
                                        return "#9E9E9E"
                                    }
                                }
                                radius: 4
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#FFFFFF"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                console.log("重置制动器配置:", root.brakeIndex + 1)
                                // TODO: 重置为默认值
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 导航函数 ==========
    // ✅ 2026-01-31 [FIX 100.300.111]: 添加导航系统函数

    // 返回参数区域的字段数量
    function getParamFieldCount() {
        return 10  // 10个参数字段（GridLayout 4列布局，5行）
    }

    // 触发参数输入（打开虚拟键盘）
    function triggerParamInput(paramIndex) {
        console.log("✅ [BrakeConfigPanel] 触发参数输入 - 索引:", paramIndex)

        var inputField = null
        var inputMode = "numeric"  // 默认数字模式

        switch(paramIndex) {
        case 0:  // 抱闸保持时间
            inputField = holdTimeField
            inputMode = "numeric"
            break
        case 1:  // 松闸保持时间
            inputField = releaseTimeField
            inputMode = "numeric"
            break
        case 2:  // 抱闸动作延时
            inputField = brakeDelayField
            inputMode = "numeric"
            break
        case 3:  // 抱闸释放延时
            inputField = releaseDelayField
            inputMode = "numeric"
            break
        case 4:  // 抱闸检测延时
            inputField = detectDelayField
            inputMode = "numeric"
            break
        case 5:  // 抱闸故障延时
            inputField = faultDelayField
            inputMode = "numeric"
            break
        case 6:  // 抱闸动作电流
            inputField = brakeCurrentField
            inputMode = "numeric"
            break
        case 7:  // 抱闸释放电流
            inputField = releaseCurrentField
            inputMode = "numeric"
            break
        case 8:  // 抱闸动作电压
            inputField = brakeVoltageField
            inputMode = "numeric"
            break
        case 9:  // 抱闸释放电压
            inputField = releaseVoltageField
            inputMode = "numeric"
            break
        default:
            console.warn("⚠️ [BrakeConfigPanel] 未知的参数索引:", paramIndex)
            return
        }

        // 打开虚拟键盘
        if (virtualKeyboard && inputField) {
            console.log("✅ [BrakeConfigPanel] 打开 Qt 虚拟键盘 - 控件:", inputField, "模式:", inputMode)
            virtualKeyboard.openForField(inputField, function(newValue) {
                console.log("✅ [BrakeConfigPanel] 虚拟键盘输入完成:", newValue)
            }, inputMode, root)
        } else {
            console.warn("⚠️ [BrakeConfigPanel] 虚拟键盘或输入控件不可用")
        }
    }

    // ✅ 2026-01-31 [FIX 100.300.112.7]: 触发使用状态切换
    // ✅ 2026-01-31 [FIX 100.300.112.7]: 触发使用状态切换（基于索引）
    // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 已废弃，改用 toggleUsageStatus()
    // function triggerUsageStatus(usageStatusIndex) {
    //     console.log("✅ [BrakeConfigPanel] 触发使用状态切换 - 索引:", usageStatusIndex)
    //
    //     switch(usageStatusIndex) {
    //     case 0:  // 投入
    //         statusEnabled.checked = true
    //         console.log("✅ [BrakeConfigPanel] 设置为：投入")
    //         break
    //     case 1:  // 禁用
    //         statusDisabled.checked = true
    //         console.log("✅ [BrakeConfigPanel] 设置为：禁用")
    //         break
    //     default:
    //         console.warn("⚠️ [BrakeConfigPanel] 未知的使用状态索引:", usageStatusIndex)
    //         break
    //     }
    // }

    // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 切换使用状态（投入 ↔ 禁用）
    function toggleUsageStatus() {
        console.log("✅ [BrakeConfigPanel] 切换使用状态")

        if (statusEnabled.checked) {
            // 当前是投入，切换到禁用
            statusDisabled.checked = true
            console.log("✅ [BrakeConfigPanel] 切换为：禁用")
        } else {
            // 当前是禁用，切换到投入
            statusEnabled.checked = true
            console.log("✅ [BrakeConfigPanel] 切换为：投入")
        }
    }

    // 触发底部按钮
    function triggerButton(buttonIndex) {
        console.log("✅ [BrakeConfigPanel] 触发底部按钮 - 索引:", buttonIndex)

        switch(buttonIndex) {
        case 0:  // 保存
            console.log("✅ [BrakeConfigPanel] 触发：保存")
            saveBrakeConfig()
            break
        case 1:  // 重置
            console.log("✅ [BrakeConfigPanel] 触发：重置")
            loadBrakeConfig()  // 重置 = 重新加载配置
            break
        default:
            console.warn("⚠️ [BrakeConfigPanel] 未知的按钮索引:", buttonIndex)
            break
        }
    }

    // ========== 参数持久化函数 ==========
    // ✅ 2026-02-06 [参数持久化]: 收集制动器配置参数
    function collectConfig() {
        var config = {}

        // 使用状态
        config["enabled"] = statusEnabled.checked

        // 10个参数字段
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

        console.log("✅ [BrakeConfigPanel] 收集配置:", JSON.stringify(config))
        return config
    }

    // ✅ 2026-02-06 [参数持久化]: 保存制动器配置
    function saveBrakeConfig() {
        console.log("✅ [BrakeConfigPanel] 保存制动器配置 - 设备:", root.deviceId, "制动器:", root.brakeIndex + 1)

        // 收集配置
        var config = collectConfig()

        // 保存到数据库
        var success = deviceConfigMgr.saveBrakeConfig(
            root.deviceId,
            root.brakeIndex,
            config
        )

        if (success) {
            console.log("✅ [BrakeConfigPanel] 保存成功")
        } else {
            console.log("❌ [BrakeConfigPanel] 保存失败")
        }

        return success
    }

    // ✅ 2026-02-06 [参数持久化]: 加载制动器配置
    function loadBrakeConfig() {
        console.log("✅ [BrakeConfigPanel] 加载制动器配置 - 设备:", root.deviceId, "制动器:", root.brakeIndex + 1)

        // 从数据库加载配置
        var config = deviceConfigMgr.loadBrakeConfig(
            root.deviceId,
            root.brakeIndex
        )

        if (!config || Object.keys(config).length === 0) {
            console.log("⚠️ [BrakeConfigPanel] 未找到配置，使用默认值")
            return false
        }

        // 应用配置到界面
        console.log("✅ [BrakeConfigPanel] 应用配置:", JSON.stringify(config))

        // 使用状态
        if (config.hasOwnProperty("enabled")) {
            statusEnabled.checked = config["enabled"]
            statusDisabled.checked = !config["enabled"]
        }

        // 10个参数字段
        if (config.hasOwnProperty("hold_time")) {
            holdTimeField.text = config["hold_time"].toString()
        }
        if (config.hasOwnProperty("release_time")) {
            releaseTimeField.text = config["release_time"].toString()
        }
        if (config.hasOwnProperty("brake_delay")) {
            brakeDelayField.text = config["brake_delay"].toString()
        }
        if (config.hasOwnProperty("release_delay")) {
            releaseDelayField.text = config["release_delay"].toString()
        }
        if (config.hasOwnProperty("detect_delay")) {
            detectDelayField.text = config["detect_delay"].toString()
        }
        if (config.hasOwnProperty("fault_delay")) {
            faultDelayField.text = config["fault_delay"].toString()
        }
        if (config.hasOwnProperty("brake_current")) {
            brakeCurrentField.text = config["brake_current"].toString()
        }
        if (config.hasOwnProperty("release_current")) {
            releaseCurrentField.text = config["release_current"].toString()
        }
        if (config.hasOwnProperty("brake_voltage")) {
            brakeVoltageField.text = config["brake_voltage"].toString()
        }
        if (config.hasOwnProperty("release_voltage")) {
            releaseVoltageField.text = config["release_voltage"].toString()
        }

        console.log("✅ [BrakeConfigPanel] 配置加载完成")
        return true
    }

    // ========== 组件初始化 ==========
    Component.onCompleted: {
        console.log("✅ [BrakeConfigPanel] Component.onCompleted - 制动器:", root.brakeIndex + 1)
        // ✅ 2026-02-06 [参数持久化]: 加载配置
        loadBrakeConfig()
    }

    // ========== 监听制动器索引变化 ==========
    onBrakeIndexChanged: {
        console.log("✅ [BrakeConfigPanel] 制动器索引变化:", root.brakeIndex + 1)
        // ✅ 2026-02-06 [参数持久化]: 重新加载配置
        loadBrakeConfig()
    }
}
