// ModbusTCPMasterTab.qml
// Modbus TCP 主站配置Tab
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
    property real pollInterval: 10  // 0.1秒单位
    property string targetIP: "192.168.1.1"
    property int slaveAddress: 1
    property int startRegister: 0
    property int registerCount: 10
    property int timeout: 3000
    property int retryCount: 3

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 9
    }

    // ✅ 2026-02-08 [Phase 7.42.13]: 重构虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [ModbusTCPMasterTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号（CustomSpinBox）
            inputField = portNumberField
            break
        case 1:  // 状态（CustomComboBox）
            console.log("✅ [ModbusTCPMasterTab] 切换状态")
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return
        case 2:  // 轮询时间（CustomSpinBox）
            inputField = pollIntervalField
            break
        case 3:  // 目标IP（CustomTextField）
            inputField = targetIPField
            break
        case 4:  // 从站地址（CustomSpinBox）
            inputField = slaveAddressField
            break
        case 5:  // 起始寄存器（CustomSpinBox）
            inputField = startRegisterField
            break
        case 6:  // 寄存器数量（CustomSpinBox）
            inputField = registerCountField
            break
        case 7:  // 超时时间（CustomSpinBox）
            inputField = timeoutField
            break
        case 8:  // 重试次数（CustomSpinBox）
            inputField = retryCountField
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [ModbusTCPMasterTab] 激活虚拟键盘 - 控件:", inputField)
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                inputField.forceActiveFocus()
            }
        }
    }

    // ✅ 2026-02-08 [Phase 7.42]: 完善回车键处理
    // ✅ 2026-02-08 [Phase 7.42.15]: 修复返回值逻辑
    // - ComboBox：切换选项，返回 true（已处理）
    // - SpinBox/TextField：返回 false，让 DeviceSettingsDialog 调用 triggerParamInput 弹出虚拟键盘
    function handleEnterKey() {
        console.log("✅ [ModbusTCPMasterTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，切换选项
        if (focusParamIndex === 1) {  // 状态（ComboBox）
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return true  // 已处理，不需要弹出虚拟键盘
        }

        // 其他输入框（SpinBox/TextField）返回 false，让 DeviceSettingsDialog 调用 triggerParamInput
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
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击端口号，发射信号: requestFocusParamIndex(0)")
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
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击状态，发射信号: requestFocusParamIndex(1)")
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

            // ========== 第二行：轮询时间（左侧，索引2）、目标IP（右侧，索引3）==========

            // 轮询时间标签
            Text {
                text: "轮询时间:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 轮询时间输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: pollIntervalRow.implicitHeight

                Row {
                    id: pollIntervalRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: pollIntervalField
                        width: parent.width - 60
                        height: 60
                        from: 1
                        to: 1000
                        value: root.pollInterval
                        onValueChanged: root.pollInterval = value
                    }

                    Text {
                        text: "0.1秒"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击轮询时间，发射信号: requestFocusParamIndex(2)")
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

            // 目标IP标签
            Text {
                text: "目标IP:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 目标IP输入
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: targetIPField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: targetIPField
                    anchors.fill: parent
                    text: root.targetIP
                    onTextChanged: root.targetIP = text
                    placeholderText: "192.168.1.1"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击目标IP，发射信号: requestFocusParamIndex(3)")
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

            // ========== 第三行：从站地址（左侧，索引4）、起始寄存器（右侧，索引5）==========

            // 从站地址标签
            Text {
                text: "从站地址:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 从站地址输入
            Item {
                Layout.column: 1
                Layout.row: 2
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
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击从站地址，发射信号: requestFocusParamIndex(4)")
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

            // 起始寄存器标签
            Text {
                text: "起始寄存器:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 起始寄存器输入
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: startRegisterField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: startRegisterField
                    anchors.fill: parent
                    from: 0
                    to: 65535
                    value: root.startRegister
                    onValueChanged: root.startRegister = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击起始寄存器，发射信号: requestFocusParamIndex(5)")
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

            // ========== 第四行：寄存器数量（左侧，索引6）、超时时间（右侧，索引7）==========

            // 寄存器数量标签
            Text {
                text: "寄存器数量:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 寄存器数量输入
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: registerCountField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: registerCountField
                    anchors.fill: parent
                    from: 1
                    to: 125
                    value: root.registerCount
                    onValueChanged: root.registerCount = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击寄存器数量，发射信号: requestFocusParamIndex(6)")
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

            // 超时时间标签
            Text {
                text: "超时时间:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 超时时间输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: timeoutRow.implicitHeight

                Row {
                    id: timeoutRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: timeoutField
                        width: parent.width - 40
                        height: 60
                        from: 100
                        to: 30000
                        value: root.timeout
                        onValueChanged: root.timeout = value
                    }

                    Text {
                        text: "ms"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击超时时间，发射信号: requestFocusParamIndex(7)")
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

            // ========== 第五行：重试次数（左侧，索引8）==========

            // 重试次数标签
            Text {
                text: "重试次数:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 重试次数输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: retryCountRow.implicitHeight

                Row {
                    id: retryCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: retryCountField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 10
                        value: root.retryCount
                        onValueChanged: root.retryCount = value
                    }

                    Text {
                        text: "次"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPMasterTab] 鼠标点击重试次数，发射信号: requestFocusParamIndex(8)")
                        root.requestFocusParamIndex(8)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束
}
