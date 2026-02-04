// SerialPortConfigPanel.qml
// 串口配置面板
// 创建日期: 2026-02-04

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortConfigPanel] Component.onCompleted 开始")
        console.log("✅ [SerialPortConfigPanel] Component.onCompleted 完成")
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ========== 1. 串口参数配置区 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 250
            color: "#2c3e50"
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // 标题
                Text {
                    text: "串口参数配置"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                }

                // 参数网格
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    // 串口名称（只读）
                    Text {
                        text: "串口名称:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    Text {
                        text: root.currentSerialPort ? root.currentSerialPort.name : ""
                        font.pixelSize: 14
                        color: "#E0E0E0"
                        font.weight: Font.Bold
                    }

                    // 设备路径（只读）
                    Text {
                        text: "设备路径:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    Text {
                        text: root.currentSerialPort ? root.currentSerialPort.path : ""
                        font.pixelSize: 14
                        color: "#9E9E9E"
                    }

                    // 串口类型（可编辑）
                    Text {
                        text: "串口类型:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    TextField {
                        id: serialTypeField
                        Layout.preferredWidth: 150
                        text: root.currentSerialPort ? root.currentSerialPort.type : ""
                        placeholderText: "如: RS422, RS232, RS485"
                    }

                    // 波特率
                    Text {
                        text: "波特率:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    ComboBox {
                        id: baudRateCombo
                        Layout.preferredWidth: 150
                        model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                        currentIndex: 3  // 默认9600
                    }

                    // 数据位
                    Text {
                        text: "数据位:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    ComboBox {
                        id: dataBitsCombo
                        Layout.preferredWidth: 150
                        model: ["5", "6", "7", "8"]
                        currentIndex: 3  // 默认8
                    }

                    // 停止位
                    Text {
                        text: "停止位:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    ComboBox {
                        id: stopBitsCombo
                        Layout.preferredWidth: 150
                        model: ["1", "1.5", "2"]
                        currentIndex: 0  // 默认1
                    }

                    // 校验位
                    Text {
                        text: "校验位:"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                    }
                    ComboBox {
                        id: parityCombo
                        Layout.preferredWidth: 150
                        model: ["None", "Odd", "Even", "Mark", "Space"]
                        currentIndex: 0  // 默认None
                    }
                }

                // 操作按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        text: "打开串口"
                        Layout.preferredWidth: 120
                        onClicked: {
                            console.log("✅ [SerialPortConfigPanel] 打开串口")
                            // TODO: 实现打开串口功能
                        }
                    }

                    Button {
                        text: "关闭串口"
                        Layout.preferredWidth: 120
                        onClicked: {
                            console.log("✅ [SerialPortConfigPanel] 关闭串口")
                            // TODO: 实现关闭串口功能
                        }
                    }
                }
            }
        }

        // ========== 2. 发送区（占位符）==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#2c3e50"
            radius: 8

            Text {
                text: "发送区（Phase 3 实现）"
                font.pixelSize: 14
                color: "#9E9E9E"
                anchors.centerIn: parent
            }
        }

        // ========== 3. 接收区（占位符）==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            color: "#2c3e50"
            radius: 8

            Text {
                text: "接收区（Phase 3 实现）"
                font.pixelSize: 14
                color: "#9E9E9E"
                anchors.centerIn: parent
            }
        }

        // ========== 4. MODBUS寄存器操作（占位符）==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2c3e50"
            radius: 8

            Text {
                text: "MODBUS 寄存器操作（Phase 4 实现）"
                font.pixelSize: 14
                color: "#9E9E9E"
                anchors.centerIn: parent
            }
        }
    }
}
