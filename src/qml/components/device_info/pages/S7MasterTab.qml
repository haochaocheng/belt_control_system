// S7MasterTab.qml
// S7 主站（客户端）配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现
// 使用 Snap7 库实现西门子 S7 协议

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
    property int portNumber: 102  // S7 标准端口
    property bool isEnabled: false
    property string targetIP: "192.168.0.1"
    property int rack: 0
    property int slot: 2
    property string connectionType: "PG"  // PG/OP/Basic
    property string localTSAP: "0x0100"
    property string remoteTSAP: "0x0302"
    property int pduSize: 480
    property real pollInterval: 1.0  // 0.1秒单位
    property int timeout: 5000

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 11
    }

    function triggerParamInput(index) {
        console.log("✅ [S7MasterTab] triggerParamInput:", index)
    }

    function handleEnterKey() {
        console.log("✅ [S7MasterTab] handleEnterKey - focusParamIndex:", focusParamIndex)
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
                    onTextChanged: root.portNumber = parseInt(text) || 102
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
                border.color: focusParamIndex === 2 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 2 ? 2 : 1
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

            // Rack
            Label {
                text: "Rack:"
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
                    text: root.rack
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.rack = parseInt(text) || 0
                }
            }

            // Slot
            Label {
                text: "Slot:"
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
                    text: root.slot
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.slot = parseInt(text) || 2
                }
            }

            // 连接类型
            Label {
                text: "连接类型:"
                color: "#E0E0E0"
                font.pixelSize: 14
            }
            ComboBox {
                Layout.fillWidth: true
                model: ["PG", "OP", "Basic"]
                currentIndex: {
                    switch(root.connectionType) {
                    case "PG": return 0
                    case "OP": return 1
                    case "Basic": return 2
                    default: return 0
                    }
                }
                onCurrentIndexChanged: {
                    switch(currentIndex) {
                    case 0: root.connectionType = "PG"; break
                    case 1: root.connectionType = "OP"; break
                    case 2: root.connectionType = "Basic"; break
                    }
                }

                background: Rectangle {
                    color: "#2a3142"
                    border.color: focusParamIndex === 5 ? "#2196F3" : "#3d4556"
                    border.width: focusParamIndex === 5 ? 2 : 1
                    radius: 4
                }
            }

            // Local TSAP
            Label {
                text: "Local TSAP:"
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
                    text: root.localTSAP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.localTSAP = text
                }
            }

            // Remote TSAP
            Label {
                text: "Remote TSAP:"
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
                    text: root.remoteTSAP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.remoteTSAP = text
                }
            }

            // PDU大小
            Label {
                text: "PDU大小:"
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
                    text: root.pduSize
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.pduSize = parseInt(text) || 480
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
                border.color: focusParamIndex === 9 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 9 ? 2 : 1
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
                border.color: focusParamIndex === 10 ? "#2196F3" : "#3d4556"
                border.width: focusParamIndex === 10 ? 2 : 1
                radius: 4

                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.timeout
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.timeout = parseInt(text) || 5000
                }
            }
        }
    }
}
