// SerialPortSendSection.qml
// 串口发送区域
// 创建日期: 2026-02-04
// ✅ 2026-02-04: Phase 3 - 实现发送区功能

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as DeviceInfo

Rectangle {
    id: root
    color: "#2c3e50"
    radius: 8

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortSendSection] Component.onCompleted 开始")
        console.log("✅ [SerialPortSendSection] Component.onCompleted 完成")
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ========== 标题 ==========
        Text {
            text: "发送区"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            Layout.fillWidth: true
        }

        // ========== 发送数据输入和格式选择 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // 发送数据输入框
            DeviceInfo.CustomTextField {
                id: sendInput
                Layout.fillWidth: true
                placeholderText: "输入要发送的数据..."

                // 回车键发送
                Keys.onReturnPressed: {
                    sendButton.clicked()
                }
            }

            // HEX/ASCII 格式选择
            DeviceInfo.CustomComboBox {
                id: sendFormat
                Layout.preferredWidth: 120
                model: ["HEX", "ASCII"]
                currentIndex: 0
            }
        }

        // ========== 操作按钮 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                id: sendButton
                text: "发送"
                Layout.preferredWidth: 100
                enabled: sendInput.text.length > 0

                onClicked: {
                    console.log("✅ [SerialPortSendSection] 发送数据")
                    console.log("   - 格式:", sendFormat.currentText)
                    console.log("   - 数据:", sendInput.text)

                    // TODO: Phase 2 - 调用后端发送数据
                    if (sendFormat.currentText === "HEX") {
                        // serialPortController.sendHex(sendInput.text)
                    } else {
                        // serialPortController.sendAscii(sendInput.text)
                    }
                }
            }

            Button {
                text: "清空"
                Layout.preferredWidth: 100

                onClicked: {
                    sendInput.text = ""
                    sendInput.forceActiveFocus()
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }
}
