// CANParamsTab.qml
// CAN 参数配置 Tab
// 创建日期: 2026-02-07

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentCanInterface: null
    property int focusParamIndex: 0
    property var virtualKeyboard: null

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 4  // CAN接口、波特率、状态、帧类型
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [CANParamsTab] 触发参数输入 - 索引:", paramIndex)
        // 参数索引映射（2列布局）：
        // 行0：[0] CAN接口（只读） [1] 波特率（可编辑）
        // 行1：[2] 状态（只读）     [3] 帧类型（可编辑）
    }

    function handleEnterKey() {
        console.log("✅ [CANParamsTab] 处理回车键 - 参数索引:", focusParamIndex)

        switch(focusParamIndex) {
        case 1:  // 波特率
            if (bitrateCombo.popup.visible) {
                bitrateCombo.popup.close()
            } else {
                bitrateCombo.popup.open()
            }
            return true
        case 3:  // 帧类型
            if (frameTypeCombo.popup.visible) {
                frameTypeCombo.popup.close()
            } else {
                frameTypeCombo.popup.open()
            }
            return true
        default:
            return false
        }
    }

    // ========== 滚动视图 ==========
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        clip: true

        // ========== 参数网格 ==========
        GridLayout {
            width: parent.width
            columns: 2
            rowSpacing: 15
            columnSpacing: 20

            // ========== 行0：CAN接口、波特率 ==========
            // 索引 0: CAN接口（只读）
            Text {
                text: "CAN 接口:"
                font.pixelSize: 14
                color: "white"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                color: "#2c3e50"
                radius: 4
                border.width: root.focusParamIndex === 0 ? 3 : 0
                border.color: "#2196F3"

                Text {
                    id: canInterfaceText
                    anchors.centerIn: parent
                    text: canController.canInterface
                    font.pixelSize: 14
                    color: "white"
                }
            }

            // 索引 1: 波特率（可编辑）
            Text {
                text: "波特率:"
                font.pixelSize: 14
                color: "white"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            ComboBox {
                id: bitrateCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                model: ["125000", "250000", "500000", "1000000"]
                currentIndex: {
                    var bitrate = canController.bitrate
                    switch(bitrate) {
                    case 125000: return 0
                    case 250000: return 1
                    case 500000: return 2
                    case 1000000: return 3
                    default: return 2  // 默认 500000
                    }
                }

                onActivated: {
                    var newBitrate = parseInt(model[index])
                    console.log("✅ [CANParamsTab] 波特率变化:", newBitrate)
                    canController.bitrate = newBitrate
                }

                background: Rectangle {
                    color: root.focusParamIndex === 1 ? "#34495e" : "#2c3e50"
                    radius: 4
                    border.width: root.focusParamIndex === 1 ? 3 : 0
                    border.color: "#2196F3"
                }

                contentItem: Text {
                    text: bitrateCombo.displayText
                    font.pixelSize: 14
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
            }

            // ========== 行1：状态、帧类型 ==========
            // 索引 2: 状态（只读）
            Text {
                text: "状态:"
                font.pixelSize: 14
                color: "white"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                color: canController.isUp ? "#27ae60" : "#c0392b"
                radius: 4
                border.width: root.focusParamIndex === 2 ? 3 : 0
                border.color: "#2196F3"

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: canController.status
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                }
            }

            // 索引 3: 帧类型（可编辑）
            Text {
                text: "帧类型:"
                font.pixelSize: 14
                color: "white"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            ComboBox {
                id: frameTypeCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                model: ["标准帧", "扩展帧"]
                currentIndex: canController.frameType === "标准帧" ? 0 : 1

                onActivated: {
                    var newFrameType = model[index]
                    console.log("✅ [CANParamsTab] 帧类型变化:", newFrameType)
                    canController.frameType = newFrameType
                }

                background: Rectangle {
                    color: root.focusParamIndex === 3 ? "#34495e" : "#2c3e50"
                    radius: 4
                    border.width: root.focusParamIndex === 3 ? 3 : 0
                    border.color: "#2196F3"
                }

                contentItem: Text {
                    text: frameTypeCombo.displayText
                    font.pixelSize: 14
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
            }
        }
    }
}
