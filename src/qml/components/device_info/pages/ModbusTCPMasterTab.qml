// ModbusTCPMasterTab.qml
// Modbus TCP 主站配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property real pollInterval: 1.0  // 0.1秒单位
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

    function triggerParamInput(index) {
        console.log("✅ [ModbusTCPMasterTab] triggerParamInput:", index)
    }

    function handleEnterKey() {
        console.log("✅ [ModbusTCPMasterTab] handleEnterKey - focusParamIndex:", focusParamIndex)
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
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.portNumber
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
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

            // 轮询时间
            Label {
                text: "轮询时间(0.1秒):"
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
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.pollInterval.toFixed(1)
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.pollInterval = parseFloat(text) || 1.0
                }
            }

            // 目标IP
            Label {
                text: "目标IP:"
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
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.targetIP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.targetIP = text
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
                border.color: focusParamIndex === 4 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 4 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.slaveAddress
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.slaveAddress = parseInt(text) || 1
                }
            }

            // 起始寄存器
            Label {
                text: "起始寄存器:"
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
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.startRegister
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.startRegister = parseInt(text) || 0
                }
            }

            // 寄存器数量
            Label {
                text: "寄存器数量:"
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
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.registerCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.registerCount = parseInt(text) || 10
                }
            }

            // 超时时间
            Label {
                text: "超时时间(ms):"
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
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.timeout
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.timeout = parseInt(text) || 3000
                }
            }

            // 重试次数
            Label {
                text: "重试次数:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            Rectangle {
                Layout.fillWidth: true
                height: 35
                color: "#2a3142"
                border.color: focusParamIndex === 8 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 8 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.retryCount
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.retryCount = parseInt(text) || 3
                }
            }
        }
    }
}
