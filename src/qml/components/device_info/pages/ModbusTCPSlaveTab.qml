// ModbusTCPSlaveTab.qml
// Modbus TCP 从站配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现
// ✅ 2026-02-08 [Phase 7.42.13]: 重构布局，参照 CurrentProtectionTab.qml

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentPort: null
    property int focusParamIndex: -1
    property var virtualKeyboard: null

    // ✅ 2026-02-08 [Phase 7.42.13]: 信号 - 请求更新焦点索引
    signal requestFocusParamIndex(int paramIndex)

    // ========== 参数数据 ==========
    property int portNumber: currentPort ? currentPort.port : 502
    property bool isEnabled: false
    property int slaveAddress: 1
    property int maxConnections: 5
    property int holdingRegisterCount: 100
    property int inputRegisterCount: 100
    property int coilCount: 100
    property int discreteInputCount: 100

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 8
    }

    // ✅ 2026-02-08 [Phase 7.42.13]: 重构虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [ModbusTCPSlaveTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号（CustomSpinBox）
            inputField = portNumberField
            break
        case 1:  // 状态（CustomComboBox）
            console.log("✅ [ModbusTCPSlaveTab] 切换状态")
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return
        case 2:  // 从站地址（CustomSpinBox）
            inputField = slaveAddressField
            break
        case 3:  // 最大连接数（CustomSpinBox）
            inputField = maxConnectionsField
            break
        case 4:  // 保持寄存器数量（CustomSpinBox）
            inputField = holdingRegisterCountField
            break
        case 5:  // 输入寄存器数量（CustomSpinBox）
            inputField = inputRegisterCountField
            break
        case 6:  // 线圈数量（CustomSpinBox）
            inputField = coilCountField
            break
        case 7:  // 离散输入数量（CustomSpinBox）
            inputField = discreteInputCountField
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [ModbusTCPSlaveTab] 激活虚拟键盘 - 控件:", inputField)
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                inputField.forceActiveFocus()
            }
        }
    }

    // ✅ 2026-02-08 [Phase 7.42]: 完善回车键处理
    // ✅ 2026-02-08 [Phase 7.42.15]: 修复返回值逻辑
    function handleEnterKey() {
        console.log("✅ [ModbusTCPSlaveTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，切换选项
        if (focusParamIndex === 1) {  // 状态（ComboBox）
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return true  // 已处理，不需要弹出虚拟键盘
        }

        // 其他输入框返回 false，让 DeviceSettingsDialog 调用 triggerParamInput
        return false
    }

    // ========== 滚动视图 ==========
    ScrollView {
        id: paramScrollView
        anchors.fill: parent
        clip: true

        // ✅ 2026-02-08 [Phase 7.42.13]: 改为 4 列 GridLayout，参考 CurrentProtectionTab
        GridLayout {
            width: paramScrollView.width * 0.9
            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
            columnSpacing: 10
            rowSpacing: 12

            // ========== 第一行：端口号（左侧，索引0）、状态（右侧，索引1）==========

            // 端口号标签
            Text {
                text: "端口号:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 端口号输入
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: portNumberField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: portNumberField
                    anchors.fill: parent
                    from: 1
                    to: 65535
                    value: root.portNumber
                    onValueChanged: root.portNumber = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击端口号，发射信号: requestFocusParamIndex(0)")
                        root.requestFocusParamIndex(0)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 状态标签
            Text {
                text: "状态:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 状态输入（下拉框）
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: statusField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: statusField
                    anchors.fill: parent
                    model: ["关闭", "打开"]
                    currentIndex: root.isEnabled ? 1 : 0
                    onCurrentIndexChanged: root.isEnabled = (currentIndex === 1)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击状态，发射信号: requestFocusParamIndex(1)")
                        root.requestFocusParamIndex(1)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 1) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第二行：从站地址（左侧，索引2）、最大连接数（右侧，索引3）==========

            // 从站地址标签
            Text {
                text: "从站地址:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 从站地址输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: slaveAddressField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: slaveAddressField
                    anchors.fill: parent
                    from: 1
                    to: 247
                    value: root.slaveAddress
                    onValueChanged: root.slaveAddress = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击从站地址，发射信号: requestFocusParamIndex(2)")
                        root.requestFocusParamIndex(2)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 最大连接数标签
            Text {
                text: "最大连接数:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 最大连接数输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: maxConnectionsRow.implicitHeight

                Row {
                    id: maxConnectionsRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: maxConnectionsField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 100
                        value: root.maxConnections
                        onValueChanged: root.maxConnections = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击最大连接数，发射信号: requestFocusParamIndex(3)")
                        root.requestFocusParamIndex(3)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第三行：保持寄存器数量（左侧，索引4）、输入寄存器数量（右侧，索引5）==========

            // 保持寄存器数量标签
            Text {
                text: "保持寄存器:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 保持寄存器数量输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: holdingRegisterCountRow.implicitHeight

                Row {
                    id: holdingRegisterCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: holdingRegisterCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.holdingRegisterCount
                        onValueChanged: root.holdingRegisterCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击保持寄存器数量，发射信号: requestFocusParamIndex(4)")
                        root.requestFocusParamIndex(4)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 输入寄存器数量标签
            Text {
                text: "输入寄存器:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 输入寄存器数量输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: inputRegisterCountRow.implicitHeight

                Row {
                    id: inputRegisterCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: inputRegisterCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.inputRegisterCount
                        onValueChanged: root.inputRegisterCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击输入寄存器数量，发射信号: requestFocusParamIndex(5)")
                        root.requestFocusParamIndex(5)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第四行：线圈数量（左侧，索引6）、离散输入数量（右侧，索引7）==========

            // 线圈数量标签
            Text {
                text: "线圈数量:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 线圈数量输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: coilCountRow.implicitHeight

                Row {
                    id: coilCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: coilCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.coilCount
                        onValueChanged: root.coilCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击线圈数量，发射信号: requestFocusParamIndex(6)")
                        root.requestFocusParamIndex(6)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 离散输入数量标签
            Text {
                text: "离散输入:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 离散输入数量输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: discreteInputCountRow.implicitHeight

                Row {
                    id: discreteInputCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: discreteInputCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.discreteInputCount
                        onValueChanged: root.discreteInputCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击离散输入数量，发射信号: requestFocusParamIndex(7)")
                        root.requestFocusParamIndex(7)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束
}
