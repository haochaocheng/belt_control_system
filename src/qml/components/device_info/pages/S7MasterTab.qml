// S7MasterTab.qml
// S7 主站（客户端）配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现
// 使用 Snap7 库实现西门子 S7 协议

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

    // ✅ 2026-02-08 [Phase 7.42]: 添加虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [S7MasterTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号
            inputField = portNumberInput
            break
        case 1:  // 状态（ComboBox）
            inputField = statusCombo
            break
        case 2:  // 目标IP
            inputField = targetIPInput
            break
        case 3:  // Rack
            inputField = rackInput
            break
        case 4:  // Slot
            inputField = slotInput
            break
        case 5:  // 连接类型（ComboBox）
            inputField = connectionTypeCombo
            break
        case 6:  // Local TSAP
            inputField = localTSAPInput
            break
        case 7:  // Remote TSAP
            inputField = remoteTSAPInput
            break
        case 8:  // PDU大小
            inputField = pduSizeInput
            break
        case 9:  // 轮询时间
            inputField = pollIntervalInput
            break
        case 10:  // 超时时间
            inputField = timeoutInput
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
        console.log("✅ [S7MasterTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，打开下拉列表
        if (focusParamIndex === 1) {
            if (statusCombo) {
                statusCombo.popup.open()
                return true
            }
        } else if (focusParamIndex === 5) {
            if (connectionTypeCombo) {
                connectionTypeCombo.popup.open()
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
                    id: targetIPInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.targetIP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
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
                    id: rackInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.rack
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
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
                    id: slotInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.slot
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
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
                id: connectionTypeCombo
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
                    id: localTSAPInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.localTSAP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhNoPredictiveText
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
                    id: remoteTSAPInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.remoteTSAP
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhNoPredictiveText
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
                    id: pduSizeInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.pduSize
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
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
                    id: pollIntervalInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.pollInterval.toFixed(1)
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
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
                    id: timeoutInput
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.timeout
                    color: "#E0E0E0"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: root.timeout = parseInt(text) || 5000
                }
            }
        }
    }
}
