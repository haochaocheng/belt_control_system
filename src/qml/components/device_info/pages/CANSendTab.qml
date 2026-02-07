// CANSendTab.qml
// CAN 发送区 Tab
// 创建日期: 2026-02-07

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: 0
    property var virtualKeyboard: null

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 3  // CAN ID、数据、发送按钮
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [CANSendTab] 触发参数输入 - 索引:", paramIndex)
        // 参数索引映射：
        // [0] CAN ID 输入框
        // [1] 数据输入框
        // [2] 发送按钮
    }

    function handleEnterKey() {
        console.log("✅ [CANSendTab] 处理回车键 - 参数索引:", focusParamIndex)

        if (focusParamIndex === 2) {
            // 发送按钮
            sendButton.clicked()
            return true
        }

        return false
    }

    // ========== 滚动视图 ==========
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 20

            // ========== CAN ID 输入 ==========
            // 索引 0: CAN ID
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "CAN ID (HEX):"
                    font.pixelSize: 14
                    color: "white"
                    Layout.preferredWidth: 120
                }

                TextField {
                    id: canIdInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    placeholderText: "例如: 123"
                    font.pixelSize: 14

                    background: Rectangle {
                        color: root.focusParamIndex === 0 ? "#34495e" : "#2c3e50"
                        radius: 4
                        border.width: root.focusParamIndex === 0 ? 3 : 0
                        border.color: "#2196F3"
                    }

                    color: "white"

                    // 只允许输入十六进制字符
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{0,8}/
                    }
                }
            }

            // ========== 数据输入 ==========
            // 索引 1: 数据
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "数据 (HEX):"
                    font.pixelSize: 14
                    color: "white"
                    Layout.preferredWidth: 120
                }

                TextField {
                    id: dataInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    placeholderText: "例如: DEADBEEF (最多16个字符，8字节)"
                    font.pixelSize: 14

                    background: Rectangle {
                        color: root.focusParamIndex === 1 ? "#34495e" : "#2c3e50"
                        radius: 4
                        border.width: root.focusParamIndex === 1 ? 3 : 0
                        border.color: "#2196F3"
                    }

                    color: "white"

                    // 只允许输入十六进制字符，最多16个字符（8字节）
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{0,16}/
                    }
                }
            }

            // ========== 发送按钮 ==========
            // 索引 2: 发送按钮
            Button {
                id: sendButton
                text: "发送"
                Layout.preferredWidth: 150
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter

                background: Rectangle {
                    color: {
                        if (root.focusParamIndex === 2) {
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
                    border.width: root.focusParamIndex === 2 ? 5 : 0
                    border.color: "#2196F3"
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    console.log("✅ [CANSendTab] 发送 CAN 数据")

                    // 验证输入
                    if (canIdInput.text.length === 0) {
                        console.error("❌ [CANSendTab] CAN ID 不能为空")
                        return
                    }

                    if (dataInput.text.length === 0) {
                        console.error("❌ [CANSendTab] 数据不能为空")
                        return
                    }

                    // 发送数据
                    var success = canController.sendData(canIdInput.text, dataInput.text)
                    if (success) {
                        console.log("✅ [CANSendTab] 数据发送成功")
                        // 可选：清空输入框
                        // canIdInput.text = ""
                        // dataInput.text = ""
                    } else {
                        console.error("❌ [CANSendTab] 数据发送失败")
                    }
                }
            }

            // ========== 使用说明 ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: "#34495e"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "使用说明："
                        font.pixelSize: 13
                        font.bold: true
                        color: "#00d4ff"
                    }

                    Text {
                        text: "• CAN ID: 十六进制，标准帧 11 位（0x000-0x7FF），扩展帧 29 位"
                        font.pixelSize: 11
                        color: "#ecf0f1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "• 数据: 十六进制，最多 8 字节（16 个字符）"
                        font.pixelSize: 11
                        color: "#ecf0f1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "• 示例: CAN ID=123, 数据=DEADBEEF"
                        font.pixelSize: 11
                        color: "#ecf0f1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
