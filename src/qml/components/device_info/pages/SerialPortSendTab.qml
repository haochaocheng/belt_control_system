// SerialPortSendTab.qml
// 串口发送 Tab
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 从 SerialPortSendSection.qml 重命名
// 原因：采用 Tab 架构，每个 Tab 内部独立管理滚动
// 创建日期: 2026-02-04

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

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.2]: 添加焦点函数
    function focusSendData() {
        sendInput.forceActiveFocus()
        console.log("✅ [SerialPortSendSection] 发送数据获得焦点")
    }

    function focusSendFormat() {
        sendFormat.forceActiveFocus()
        console.log("✅ [SerialPortSendSection] 发送格式获得焦点")
    }

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

        // ========== 标题和格式选择 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "发送区"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#E0E0E0"
            }

            Item {
                Layout.fillWidth: true
            }

            // HEX/ASCII 格式选择
            Text {
                text: "格式:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Item {
                Layout.preferredWidth: 100
                implicitHeight: sendFormat.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: sendFormat
                    anchors.fill: parent
                    model: ["HEX", "ASCII"]
                    currentIndex: 0
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.2]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: sendFormat.activeFocus ? "#2196F3" : "transparent"
                    border.width: sendFormat.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }
        }

        // ========== 发送数据输入框 ==========
        // ✅ 2026-02-04: 移除内部 ScrollView，使用固定高度的 TextArea
        // ✅ 2026-02-04: 增加高度 1.5 倍：150 → 225
        TextArea {
            id: sendInput
            Layout.fillWidth: true
            Layout.preferredHeight: 225  // 固定高度（150 * 1.5）
            wrapMode: TextArea.Wrap
            font.family: "Consolas"
            font.pixelSize: 14
            color: "#E0E0E0"
            placeholderText: "输入要发送的数据..."
            placeholderTextColor: "#5E6E7E"
            background: Rectangle {
                color: "#1e2838"
                border.color: sendInput.activeFocus ? "#2196F3" : "#3d4556"
                border.width: sendInput.activeFocus ? 2 : 1
                radius: 4
            }

            // Ctrl+Enter 发送
            Keys.onPressed: function(event) {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                    (event.modifiers & Qt.ControlModifier)) {
                    sendButton.clicked()
                    event.accepted = true
                }
            }
        }

        // ========== 操作按钮 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                id: sendButton
                text: "发送 (Ctrl+Enter)"
                Layout.preferredWidth: 150
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
