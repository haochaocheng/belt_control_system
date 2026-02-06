// ModbusRegisterTab.qml
// MODBUS 寄存器操作 Tab
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 从 ModbusRegisterSection.qml 重命名
// 原因：采用 Tab 架构，每个 Tab 内部独立管理滚动
// ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 重构为 GridLayout 4列布局，添加导航支持
// 创建日期: 2026-02-04

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息
    property int focusParamIndex: 0       // 当前焦点参数索引
    property var virtualKeyboard: null    // 虚拟键盘引用

    // ========== 信号 ==========
    signal requestFocusParamIndex(int paramIndex)

    // ========== 导航索引映射 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 参数索引映射（4列布局）
    // 行0：[0] 从站地址标签  [1] 从站地址输入（80px）  [2] 功能码标签  [3] 功能码下拉（200px）
    // 行1：[4] 起始地址标签  [5] 起始地址输入（80px）  [6] 数量标签    [7] 数量输入（100px）
    // 行2：[8] 写入值标签    [9] 写入值输入（80px）    [10] 空         [11] 空
    // 行3：[12] 读取按钮（跨2列）                      [13] 写入按钮（跨2列）
    // 寄存器列表：[14] 寄存器列表（焦点指示器）
    // 参数数量：8个（索引0-7，按钮5-6，列表7）

    // ========== 焦点管理函数 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 添加 triggerParamInput() 函数
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.6]: 修改为电流保护Tab的方式
    // 参考 CurrentProtectionTab 的实现，直接在控件上调用 activateVirtualKeyboard()
    function triggerParamInput(paramIndex) {
        console.log("✅ [ModbusRegisterTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // 从站地址
            inputField = slaveAddress
            console.log("✅ [ModbusRegisterTab] 从站地址")
            break
        case 1:  // 功能码
            inputField = functionCode
            console.log("✅ [ModbusRegisterTab] 功能码")
            break
        case 2:  // 起始地址
            inputField = startAddress
            console.log("✅ [ModbusRegisterTab] 起始地址")
            break
        case 3:  // 数量
            inputField = quantity
            console.log("✅ [ModbusRegisterTab] 数量")
            break
        case 4:  // 写入值
            inputField = writeValue
            console.log("✅ [ModbusRegisterTab] 写入值")
            break
        case 5:  // 读取按钮
            inputField = readButton
            console.log("✅ [ModbusRegisterTab] 读取按钮")
            break
        case 6:  // 写入按钮
            inputField = writeButton
            console.log("✅ [ModbusRegisterTab] 写入按钮")
            break
        case 7:  // 寄存器列表
            inputField = registerListView
            console.log("✅ [ModbusRegisterTab] 寄存器列表")
            break
        default:
            console.log("⚠️ [ModbusRegisterTab] 未知参数索引:", paramIndex)
            return
        }

        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.6.1]: triggerParamInput 不应该自动打开虚拟键盘
        // 对于所有控件，都不调用 activateVirtualKeyboard 或 forceActiveFocus
        // 焦点已经通过 focusParamIndex 的变化自动设置了
        console.log("✅ [ModbusRegisterTab] 参数索引已更新，焦点指示器已显示")
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 添加 getParamFieldCount() 函数
    function getParamFieldCount() {
        return 8  // 8个参数（0-7）
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.6]: 添加 handleEnterKey() 函数
    // 处理回车键，根据当前焦点控件执行不同的操作
    // 参考 SerialPortSendTab 和 SerialPortReceiveTab 的实现
    function handleEnterKey() {
        console.log("✅ [ModbusRegisterTab] 处理回车键 - 当前焦点索引:", focusParamIndex)

        switch(focusParamIndex) {
        case 0:  // 从站地址（数字输入框）
            // 弹出虚拟键盘（数字输入）
            console.log("✅ [ModbusRegisterTab] 尝试激活虚拟键盘 - 从站地址")
            if (slaveAddress.activateVirtualKeyboard) {
                console.log("✅ [ModbusRegisterTab] 调用 slaveAddress.activateVirtualKeyboard()")
                slaveAddress.activateVirtualKeyboard()
                return true  // 表示已处理
            } else {
                console.log("✅ [ModbusRegisterTab] 调用 slaveAddress.forceActiveFocus()")
                slaveAddress.forceActiveFocus()
                return true  // 表示已处理
            }

        case 1:  // 功能码（ComboBox）
            // 循环切换选项
            var newIndex = (functionCode.currentIndex + 1) % functionCode.model.length
            console.log("✅ [ModbusRegisterTab] 功能码切换:", functionCode.currentIndex, "→", newIndex)
            functionCode.currentIndex = newIndex
            return true  // 表示已处理

        case 2:  // 起始地址（数字输入框）
            // 弹出虚拟键盘（数字输入）
            console.log("✅ [ModbusRegisterTab] 尝试激活虚拟键盘 - 起始地址")
            if (startAddress.activateVirtualKeyboard) {
                console.log("✅ [ModbusRegisterTab] 调用 startAddress.activateVirtualKeyboard()")
                startAddress.activateVirtualKeyboard()
                return true  // 表示已处理
            } else {
                console.log("✅ [ModbusRegisterTab] 调用 startAddress.forceActiveFocus()")
                startAddress.forceActiveFocus()
                return true  // 表示已处理
            }

        case 3:  // 数量（数字输入框）
            // 弹出虚拟键盘（数字输入）
            console.log("✅ [ModbusRegisterTab] 尝试激活虚拟键盘 - 数量")
            if (quantity.activateVirtualKeyboard) {
                console.log("✅ [ModbusRegisterTab] 调用 quantity.activateVirtualKeyboard()")
                quantity.activateVirtualKeyboard()
                return true  // 表示已处理
            } else {
                console.log("✅ [ModbusRegisterTab] 调用 quantity.forceActiveFocus()")
                quantity.forceActiveFocus()
                return true  // 表示已处理
            }

        case 4:  // 写入值（数字输入框）
            // 弹出虚拟键盘（数字输入）
            console.log("✅ [ModbusRegisterTab] 尝试激活虚拟键盘 - 写入值")
            if (writeValue.activateVirtualKeyboard) {
                console.log("✅ [ModbusRegisterTab] 调用 writeValue.activateVirtualKeyboard()")
                writeValue.activateVirtualKeyboard()
                return true  // 表示已处理
            } else {
                console.log("✅ [ModbusRegisterTab] 调用 writeValue.forceActiveFocus()")
                writeValue.forceActiveFocus()
                return true  // 表示已处理
            }

        case 5:  // 读取按钮
            // 执行读取操作
            console.log("✅ [ModbusRegisterTab] 执行读取操作")
            readButton.clicked()
            return true  // 表示已处理

        case 6:  // 写入按钮
            // 执行写入操作
            console.log("✅ [ModbusRegisterTab] 执行写入操作")
            writeButton.clicked()
            return true  // 表示已处理

        case 7:  // 寄存器列表
            // 寄存器列表不需要处理回车键
            console.log("⚠️ [ModbusRegisterTab] 寄存器列表不处理回车键")
            return false

        default:
            console.log("⚠️ [ModbusRegisterTab] 未知焦点索引:", focusParamIndex)
            return false
        }
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.6.2]: 添加 isFieldEnabled() 辅助函数
    // 检查字段是否启用，用于跳过禁用的字段
    function isFieldEnabled(paramIndex) {
        switch(paramIndex) {
        case 0:  // 从站地址
            return true
        case 1:  // 功能码
            return true
        case 2:  // 起始地址
            return true
        case 3:  // 数量
            return true
        case 4:  // 写入值
            return functionCode.currentIndex > 0  // 只有写入操作时启用
        case 5:  // 读取按钮
            return functionCode.currentIndex === 0  // 只有读取操作时启用
        case 6:  // 写入按钮
            return functionCode.currentIndex > 0 && writeValue.text.length > 0  // 只有写入操作且有值时启用
        case 7:  // 寄存器列表
            return true
        default:
            return false
        }
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 自定义导航处理
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.6.2]: 修改 handleDirectionKey() 跳过禁用字段
    // MODBUS 寄存器操作的布局特殊，需要自定义导航逻辑
    // 行0：[0] 从站地址  [1] 功能码
    // 行1：[2] 起始地址  [3] 数量
    // 行2：[4] 写入值
    // 行3：[5] 读取按钮  [6] 写入按钮
    // 行4：[7] 寄存器列表
    function handleDirectionKey(direction) {
        console.log("✅ [ModbusRegisterTab] 自定义导航 - 方向:", direction, "当前索引:", focusParamIndex)

        var newIndex = focusParamIndex

        switch(direction) {
        case "Down":
            // 下键导航
            if (focusParamIndex === 0) {
                // 从站地址 → 起始地址
                newIndex = 2
            } else if (focusParamIndex === 1) {
                // 功能码 → 数量
                newIndex = 3
            } else if (focusParamIndex === 2) {
                // 起始地址 → 写入值（如果启用）或读取按钮
                newIndex = isFieldEnabled(4) ? 4 : 5  // ✅ 跳过禁用的写入值
            } else if (focusParamIndex === 3) {
                // 数量 → 写入值（如果启用）或读取按钮
                newIndex = isFieldEnabled(4) ? 4 : 5  // ✅ 跳过禁用的写入值
            } else if (focusParamIndex === 4) {
                // 写入值 → 写入按钮（如果启用）或寄存器列表
                newIndex = isFieldEnabled(6) ? 6 : 7  // ✅ 跳过禁用的写入按钮
            } else if (focusParamIndex === 5 || focusParamIndex === 6) {
                // 读取按钮或写入按钮 → 寄存器列表
                newIndex = 7
            }
            // 寄存器列表：保持不变（已经在最底部）
            break

        case "Up":
            // 上键导航
            if (focusParamIndex === 7) {
                // 寄存器列表 → 读取按钮或写入按钮
                newIndex = isFieldEnabled(5) ? 5 : (isFieldEnabled(6) ? 6 : 4)  // ✅ 跳过禁用的按钮
            } else if (focusParamIndex === 5 || focusParamIndex === 6) {
                // 读取按钮或写入按钮 → 写入值（如果启用）或起始地址
                newIndex = isFieldEnabled(4) ? 4 : 2  // ✅ 跳过禁用的写入值
            } else if (focusParamIndex === 4) {
                // 写入值 → 起始地址
                newIndex = 2
            } else if (focusParamIndex === 2) {
                // 起始地址 → 从站地址
                newIndex = 0
            } else if (focusParamIndex === 3) {
                // 数量 → 功能码
                newIndex = 1
            }
            // 从站地址和功能码：保持不变（已经在最顶部）
            break

        case "Left":
            // 左键导航
            if (focusParamIndex === 1) {
                // 功能码 → 从站地址
                newIndex = 0
            } else if (focusParamIndex === 3) {
                // 数量 → 起始地址
                newIndex = 2
            } else if (focusParamIndex === 6) {
                // 写入按钮 → 读取按钮（如果启用）或写入值
                newIndex = isFieldEnabled(5) ? 5 : (isFieldEnabled(4) ? 4 : 2)  // ✅ 跳过禁用的按钮
            }
            // 其他位置：保持不变
            break

        case "Right":
            // 右键导航
            if (focusParamIndex === 0) {
                // 从站地址 → 功能码
                newIndex = 1
            } else if (focusParamIndex === 2) {
                // 起始地址 → 数量
                newIndex = 3
            } else if (focusParamIndex === 5) {
                // 读取按钮 → 写入按钮（如果启用）
                newIndex = isFieldEnabled(6) ? 6 : 5  // ✅ 跳过禁用的写入按钮
            }
            // 其他位置：保持不变
            break
        }

        if (newIndex !== focusParamIndex) {
            console.log("✅ [ModbusRegisterTab] 导航索引变化:", focusParamIndex, "→", newIndex)
            requestFocusParamIndex(newIndex)
            return true  // 导航成功
        }

        console.log("⚠️ [ModbusRegisterTab] 导航无变化，返回false")
        return false  // 导航无变化
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [ModbusRegisterTab] Component.onCompleted 开始")
        console.log("✅ [ModbusRegisterTab] Component.onCompleted 完成")
    }

    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 监听 modbusController 信号
    Connections {
        target: modbusController

        // 监听读取寄存器完成
        function onReadRegistersFinished(serverAddress, startAddress, values) {
            console.log("✅ [ModbusRegisterTab] 读取寄存器完成")
            console.log("   - 从站地址:", serverAddress)
            console.log("   - 起始地址:", startAddress)
            console.log("   - 数量:", values.length)

            // 清空现有数据
            registerModel.clear()

            // 添加新数据
            for (var i = 0; i < values.length; i++) {
                var addr = startAddress + i
                var hexValue = values[i].toString(16).toUpperCase().padStart(4, '0')
                var decValue = values[i].toString()
                registerModel.append({
                    address: addr.toString(16).toUpperCase().padStart(4, '0'),
                    hexValue: hexValue,
                    decValue: decValue,
                    description: "寄存器 " + addr
                })
            }
        }

        // 监听写入寄存器完成
        function onWriteRegisterFinished(serverAddress, address, success) {
            if (success) {
                console.log("✅ [ModbusRegisterTab] 写入单个寄存器成功")
                console.log("   - 从站地址:", serverAddress)
                console.log("   - 地址:", address)
            } else {
                console.error("❌ [ModbusRegisterTab] 写入单个寄存器失败")
            }
        }

        // 监听写入多个寄存器完成
        function onWriteRegistersFinished(serverAddress, startAddress, success) {
            if (success) {
                console.log("✅ [ModbusRegisterTab] 写入多个寄存器成功")
                console.log("   - 从站地址:", serverAddress)
                console.log("   - 起始地址:", startAddress)
            } else {
                console.error("❌ [ModbusRegisterTab] 写入多个寄存器失败")
            }
        }

        // 监听错误信号
        function onErrorOccurred(error) {
            console.error("❌ [ModbusRegisterTab] MODBUS 错误:", error)
            // TODO: 显示错误提示
        }
    }

    // ========== 滚动区域 ==========
    ScrollView {
        id: modbusScrollView
        anchors.fill: parent
        clip: true

        // ========== 主布局 ==========
        ColumnLayout {
            width: modbusScrollView.width * 0.9
            spacing: 12

            // ========== 标题 ==========
            Text {
                text: "MODBUS 寄存器操作"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#E0E0E0"
                Layout.fillWidth: true
            }

            // ========== 参数输入区（GridLayout 4列布局）==========
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 12
                rowSpacing: 12

                // ========== 行0：从站地址（索引0）、功能码（索引1）==========

                // 从站地址标签
                Text {
                    text: "从站地址:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    Layout.preferredWidth: 160
                    horizontalAlignment: Text.AlignRight
                }

                // 从站地址输入（索引0）
                Item {
                    Layout.preferredWidth: 80
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                    implicitHeight: slaveAddress.implicitHeight

                    DeviceInfo.CustomTextField {
                        id: slaveAddress
                        anchors.fill: parent
                        text: "01"
                        placeholderText: "01-FF"
                        validator: RegularExpressionValidator {
                            regularExpression: /[0-9A-Fa-f]{1,2}/
                        }
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 0) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                // 功能码标签
                Text {
                    text: "功能码:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    Layout.preferredWidth: 160
                    horizontalAlignment: Text.AlignRight
                }

                // 功能码输入（索引1）
                Item {
                    Layout.preferredWidth: 200
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                    implicitHeight: functionCode.implicitHeight

                    DeviceInfo.CustomComboBox {
                        id: functionCode
                        anchors.fill: parent
                        model: ["03-读保持寄存器", "06-写单个寄存器", "10-写多个寄存器"]
                        currentIndex: 0
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 1) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                // ========== 行1：起始地址（索引2）、数量（索引3）==========

                // 起始地址标签
                Text {
                    text: "起始地址:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    Layout.preferredWidth: 160
                    horizontalAlignment: Text.AlignRight
                }

                // 起始地址输入（索引2）
                Item {
                    Layout.preferredWidth: 80
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                    implicitHeight: startAddress.implicitHeight

                    DeviceInfo.CustomTextField {
                        id: startAddress
                        anchors.fill: parent
                        text: "0000"
                        placeholderText: "0000-FFFF"
                        validator: RegularExpressionValidator {
                            regularExpression: /[0-9A-Fa-f]{1,4}/
                        }
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 2) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                // 数量标签
                Text {
                    text: "数量:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    Layout.preferredWidth: 160
                    horizontalAlignment: Text.AlignRight
                }

                // 数量输入（索引3）
                Item {
                    Layout.preferredWidth: 100
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                    implicitHeight: quantity.implicitHeight

                    DeviceInfo.CustomSpinBox {
                        id: quantity
                        anchors.fill: parent
                        from: 1
                        to: 125
                        value: 10
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 3) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                // ========== 行2：写入值（索引4）==========

                // 写入值标签
                Text {
                    text: "写入值:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    Layout.preferredWidth: 160
                    horizontalAlignment: Text.AlignRight
                }

                // 写入值输入（索引4）
                Item {
                    Layout.preferredWidth: 80
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                    implicitHeight: writeValue.implicitHeight

                    DeviceInfo.CustomTextField {
                        id: writeValue
                        anchors.fill: parent
                        enabled: functionCode.currentIndex > 0
                        placeholderText: "0000-FFFF"
                        validator: RegularExpressionValidator {
                            regularExpression: /[0-9A-Fa-f]{1,4}/
                        }
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 4) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                // 空占位（索引10）
                Item {
                    Layout.columnSpan: 2
                }
            }

            // ========== 操作按钮 ==========
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // 读取按钮（索引5）
                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40

                    Button {
                        id: readButton
                        anchors.fill: parent
                        text: "读取"
                        enabled: functionCode.currentIndex === 0

                        background: Rectangle {
                            color: {
                                if (root.focusParamIndex === 5) {
                                    return "#2ecc71"  // 焦点时：亮绿色
                                } else if (parent.pressed) {
                                    return "#27ae60"
                                } else if (parent.hovered) {
                                    return "#2ecc71"
                                } else {
                                    return "#27ae60"
                                }
                            }
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [ModbusRegisterTab] 读取寄存器")
                            console.log("   - 从站地址:", slaveAddress.text)
                            console.log("   - 起始地址:", startAddress.text)
                            console.log("   - 数量:", quantity.value)

                            // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 调用 modbusController 读取寄存器
                            modbusController.readHoldingRegisters(
                                parseInt(slaveAddress.text, 16),
                                parseInt(startAddress.text, 16),
                                quantity.value
                            )
                        }
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 5) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                // 写入按钮（索引6）
                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40

                    Button {
                        id: writeButton
                        anchors.fill: parent
                        text: "写入"
                        enabled: functionCode.currentIndex > 0 && writeValue.text.length > 0

                        background: Rectangle {
                            color: {
                                if (root.focusParamIndex === 6) {
                                    return "#e74c3c"  // 焦点时：亮红色
                                } else if (parent.pressed) {
                                    return "#c0392b"
                                } else if (parent.hovered) {
                                    return "#e74c3c"
                                } else {
                                    return "#c0392b"
                                }
                            }
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [ModbusRegisterTab] 写入寄存器")
                            console.log("   - 从站地址:", slaveAddress.text)
                            console.log("   - 起始地址:", startAddress.text)
                            console.log("   - 写入值:", writeValue.text)

                            // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 调用 modbusController 写入寄存器
                            if (functionCode.currentIndex === 1) {
                                // 06-写单个寄存器
                                modbusController.writeSingleRegister(
                                    parseInt(slaveAddress.text, 16),
                                    parseInt(startAddress.text, 16),
                                    parseInt(writeValue.text, 16)
                                )
                            } else {
                                // 10-写多个寄存器
                                modbusController.writeMultipleRegisters(
                                    parseInt(slaveAddress.text, 16),
                                    parseInt(startAddress.text, 16),
                                    [parseInt(writeValue.text, 16)]
                                )
                            }
                        }
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 6) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            // ========== 寄存器列表标题 ==========
            Text {
                text: "寄存器列表"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "#E0E0E0"
                Layout.fillWidth: true
                Layout.topMargin: 8
            }

            // ========== 寄存器列表表头 ==========
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: "#1e2838"
                border.color: "#3d4556"
                border.width: 1
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0

                    Text {
                        text: "地址"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#3d4556"
                    }

                    Text {
                        text: "值(HEX)"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#3d4556"
                    }

                    Text {
                        text: "值(DEC)"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#3d4556"
                    }

                    Text {
                        text: "说明"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        leftPadding: 8
                    }
                }
            }

            // ========== 寄存器列表内容（索引7）==========
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200

                ListView {
                    id: registerListView
                    anchors.fill: parent
                    clip: true
                    model: ListModel {
                        id: registerModel
                        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 数据由 modbusController 提供
                        // 初始为空，读取寄存器后动态添加
                    }

                    delegate: Rectangle {
                        width: registerListView.width
                        height: 40
                        color: index % 2 === 0 ? "#1e2838" : "#2c3e50"
                        border.color: "#3d4556"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 0

                            Text {
                                text: model.address
                                font.pixelSize: 14
                                color: "#E0E0E0"
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 1
                                Layout.fillHeight: true
                                color: "#3d4556"
                            }

                            Text {
                                text: model.hexValue
                                font.pixelSize: 14
                                color: "#4CAF50"
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 1
                                Layout.fillHeight: true
                                color: "#3d4556"
                            }

                            Text {
                                text: model.decValue
                                font.pixelSize: 14
                                color: "#2196F3"
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 1
                                Layout.fillHeight: true
                                color: "#3d4556"
                            }

                            Text {
                                text: model.description
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                leftPadding: 8
                            }
                        }
                    }
                }

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.10]: 焦点指示器（索引14）
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4
                    z: 11
                }
            }
        }
    }
}
