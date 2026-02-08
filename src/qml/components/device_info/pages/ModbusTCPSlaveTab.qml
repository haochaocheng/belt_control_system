// ModbusTCPSlaveTab.qml
// Modbus TCP 从站配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentPort: null
    property int focusParamIndex: -1
    property var virtualKeyboard: null

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

    // ✅ 2026-02-08 [Phase 7.42]: 添加虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [ModbusTCPSlaveTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号
            inputField = portNumberInput
            break
        case 1:  // 状态（ComboBox）
            inputField = statusCombo
            break
        case 2:  // 从站地址
            inputField = slaveAddressInput
            break
        case 3:  // 最大连接数
            inputField = maxConnectionsInput
            break
        case 4:  // 保持寄存器数量
            inputField = holdingRegisterCountInput
            break
        case 5:  // 输入寄存器数量
            inputField = inputRegisterCountInput
            break
        case 6:  // 线圈数量
            inputField = coilCountInput
            break
        case 7:  // 离散输入数量
            inputField = discreteInputCountInput
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            inputField.forceActiveFocus()
            if (root.virtualKeyboard) {
                root.virtualKeyboard.visible = true
            }
        }
    }

    // ✅ 2026-02-08 [Phase 7.42]: 完善回车键处理
    function handleEnterKey() {
        console.log("✅ [ModbusTCPSlaveTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，打开下拉列表
        if (focusParamIndex === 1) {
            if (statusCombo) {
                statusCombo.popup.open()
                return true
            }
        }

        return true
    }

    // ========== 主布局 ==========
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        GridLayout {
            width: parent.width - 20
            columns: 2
            columnSpacing: 20
            rowSpacing: 15

            // 端口号
            Label {
                text: "端口号:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 0 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 0 ? 2 : 1
                radius: 4

                TextInput {
                    id: portNumberInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.portNumber
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.portNumber = parseInt(text) || 502
                }
            }

            // 状态
            Label {
                text: "状态:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            ComboBox {
                id: statusCombo
                Layout.fillWidth: true
                model: ["关闭", "打开"]
                currentIndex: root.isEnabled ? 1 : 0
                onCurrentIndexChanged: root.isEnabled = (currentIndex === 1)

                background: Rectangle {
                    color: "#2a3142"
                    border.color: focusParamIndex === 1 ? "#2196F3" : "#3d4556"
                    border.width: focusParamIndex === 1 ? 2 : 1
                    radius: 4
                }
            }

            // 从站地址
            Label {
                text: "从站地址:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 2 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 2 ? 2 : 1
                radius: 4

                TextInput {
                    id: slaveAddressInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.slaveAddress
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.slaveAddress = parseInt(text) || 1
                }
            }

            // 最大连接数
            Label {
                text: "最大连接数:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 3 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 3 ? 2 : 1
                radius: 4

                TextInput {
                    id: maxConnectionsInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.maxConnections
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.maxConnections = parseInt(text) || 5
                }
            }

            // 保持寄存器数量
            Label {
                text: "保持寄存器数量:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 4 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 4 ? 2 : 1
                radius: 4

                TextInput {
                    id: holdingRegisterCountInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.holdingRegisterCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.holdingRegisterCount = parseInt(text) || 100
                }
            }

            // 输入寄存器数量
            Label {
                text: "输入寄存器数量:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 5 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 5 ? 2 : 1
                radius: 4

                TextInput {
                    id: inputRegisterCountInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.inputRegisterCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.inputRegisterCount = parseInt(text) || 100
                }
            }

            // 线圈数量
            Label {
                text: "线圈数量:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 6 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 6 ? 2 : 1
                radius: 4

                TextInput {
                    id: coilCountInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.coilCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.coilCount = parseInt(text) || 100
                }
            }

            // 离散输入数量
            Label {
                text: "离散输入数量:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 7 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 7 ? 2 : 1
                radius: 4

                TextInput {
                    id: discreteInputCountInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.discreteInputCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.discreteInputCount = parseInt(text) || 100
                }
            }
        }
    }
}
