// CANReceiveTab.qml
// CAN 接收区 Tab
// 创建日期: 2026-02-07

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: 0

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 1  // 清空按钮
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [CANReceiveTab] 触发参数输入 - 索引:", paramIndex)
        // 参数索引映射：
        // [0] 清空按钮
    }

    function handleEnterKey() {
        console.log("✅ [CANReceiveTab] 处理回车键 - 参数索引:", focusParamIndex)

        if (focusParamIndex === 0) {
            // 清空按钮
            clearButton.clicked()
            return true
        }

        return false
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        // ========== 标题栏 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "接收数据"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                Layout.fillWidth: true
            }

            // 清空按钮
            Button {
                id: clearButton
                text: "清空"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 30

                background: Rectangle {
                    color: {
                        if (root.focusParamIndex === 0) {
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
                    border.width: root.focusParamIndex === 0 ? 5 : 0
                    border.color: "#2196F3"
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    console.log("✅ [CANReceiveTab] 清空接收缓冲区")
                    canController.clearReceiveBuffer()
                }
            }
        }

        // ========== 接收数据显示区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2c3e50"
            radius: 4
            border.width: 1
            border.color: "#34495e"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                TextArea {
                    id: receiveTextArea
                    text: canController.receiveBuffer
                    font.pixelSize: 12
                    font.family: "Courier New"
                    color: "#ecf0f1"
                    readOnly: true
                    wrapMode: TextArea.Wrap

                    background: Rectangle {
                        color: "transparent"
                    }

                    // 自动滚动到底部
                    onTextChanged: {
                        cursorPosition = text.length
                    }
                }
            }
        }

        // ========== 统计信息 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#34495e"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 20

                Text {
                    text: "接收帧数: " + (canController.receiveBuffer.split('\n').length - 1)
                    font.pixelSize: 12
                    color: "#ecf0f1"
                }

                Text {
                    text: "CAN 状态: " + canController.status
                    font.pixelSize: 12
                    color: canController.isUp ? "#2ecc71" : "#e74c3c"
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "格式: [时间戳] CAN_ID | 数据"
                    font.pixelSize: 11
                    color: "#95a5a6"
                }
            }
        }
    }

    // ========== 监听 CAN 数据接收信号 ==========
    Connections {
        target: canController

        function onDataReceived(canId, data, timestamp) {
            console.log("✅ [CANReceiveTab] 接收到 CAN 数据 - ID:", canId, "数据:", data, "时间:", timestamp)
        }
    }
}
