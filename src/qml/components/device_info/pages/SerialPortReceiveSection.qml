// SerialPortReceiveSection.qml
// 串口接收区域
// 创建日期: 2026-02-04
// ✅ 2026-02-04: Phase 3 - 实现接收区功能

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
    property bool isPaused: false         // 是否暂停接收

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortReceiveSection] Component.onCompleted 开始")
        console.log("✅ [SerialPortReceiveSection] Component.onCompleted 完成")
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ========== 标题 ==========
        Text {
            text: "接收区"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            Layout.fillWidth: true
        }

        // ========== 接收数据显示区 ==========
        // ✅ 2026-02-04: 移除内部 ScrollView，使用固定高度的 TextArea
        // ✅ 2026-02-04: 增加高度 1.5 倍：180 → 270
        TextArea {
            id: receiveArea
            Layout.fillWidth: true
            Layout.preferredHeight: 270  // 固定高度（180 * 1.5）
            readOnly: true
            wrapMode: TextArea.Wrap
            font.family: "Consolas"
            font.pixelSize: 14
            color: "#E0E0E0"
            background: Rectangle {
                color: "#1e2838"
                border.color: "#3d4556"
                border.width: 1
                radius: 4
            }

            // 模拟接收数据（Phase 2 后端实现后替换）
            text: "等待接收数据...\n"

            // TODO: Phase 2 - 连接后端接收数据
            // Connections {
            //     target: serialPortController
            //     function onDataReceived(data) {
            //         if (!root.isPaused) {
            //             receiveArea.append(data)
            //         }
            //     }
            // }
        }

        // ========== 操作按钮 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "清空"
                Layout.preferredWidth: 100

                onClicked: {
                    receiveArea.text = ""
                    console.log("✅ [SerialPortReceiveSection] 清空接收区")
                }
            }

            Button {
                id: pauseButton
                text: root.isPaused ? "继续" : "暂停"
                Layout.preferredWidth: 100

                onClicked: {
                    root.isPaused = !root.isPaused
                    console.log("✅ [SerialPortReceiveSection] 接收状态:", root.isPaused ? "暂停" : "继续")
                }
            }

            // HEX/ASCII 格式选择
            DeviceInfo.CustomComboBox {
                id: receiveFormat
                Layout.preferredWidth: 120
                model: ["HEX", "ASCII"]
                currentIndex: 0

                onCurrentIndexChanged: {
                    console.log("✅ [SerialPortReceiveSection] 显示格式切换:", currentText)
                    // TODO: Phase 2 - 切换显示格式
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }
}
