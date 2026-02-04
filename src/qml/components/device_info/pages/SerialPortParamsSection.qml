// SerialPortParamsSection.qml
// 串口参数配置区域
// 创建日期: 2026-02-04

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#2c3e50"
    radius: 8

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息

    // ========== 主布局 ==========
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

        // 参数区域（使用 ScrollView）
        ScrollView {
            id: paramScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // ✅ 参考开关量输入的 GridLayout 布局
            GridLayout {
                width: paramScrollView.width * 0.9  // 占 ScrollView 宽度的 90%
                columns: 4  // 4列：标签1、值1、标签2、值2
                columnSpacing: 16
                rowSpacing: 12

                // ========== 第一行：串口名称 + 设备路径 ==========
                // 串口名称标签
                Text {
                    text: "串口名称:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 0
                    Layout.row: 0
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 串口名称值（只读）
                Text {
                    text: root.currentSerialPort ? root.currentSerialPort.name : ""
                    font.pixelSize: 14
                    color: "#E0E0E0"
                    font.weight: Font.Bold
                    Layout.column: 1
                    Layout.row: 0
                    Layout.fillWidth: true
                }

                // 设备路径标签
                Text {
                    text: "设备路径:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 2
                    Layout.row: 0
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 设备路径值（只读）
                Text {
                    text: root.currentSerialPort ? root.currentSerialPort.path : ""
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    Layout.column: 3
                    Layout.row: 0
                    Layout.fillWidth: true
                }

                // ========== 第二行：串口类型 + 波特率 ==========
                // 串口类型标签
                Text {
                    text: "串口类型:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 0
                    Layout.row: 1
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 串口类型输入框
                TextField {
                    id: serialTypeField
                    text: root.currentSerialPort ? root.currentSerialPort.type : ""
                    placeholderText: "如: RS422, RS232, RS485"
                    font.pixelSize: 14
                    Layout.column: 1
                    Layout.row: 1
                    Layout.fillWidth: true
                    Layout.maximumWidth: 200
                }

                // 波特率标签
                Text {
                    text: "波特率:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 2
                    Layout.row: 1
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 波特率下拉框
                ComboBox {
                    id: baudRateCombo
                    model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                    currentIndex: 3  // 默认9600
                    Layout.column: 3
                    Layout.row: 1
                    Layout.fillWidth: true
                    Layout.maximumWidth: 150
                }

                // ========== 第三行：数据位 + 停止位 ==========
                // 数据位标签
                Text {
                    text: "数据位:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 0
                    Layout.row: 2
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 数据位下拉框
                ComboBox {
                    id: dataBitsCombo
                    model: ["5", "6", "7", "8"]
                    currentIndex: 3  // 默认8
                    Layout.column: 1
                    Layout.row: 2
                    Layout.fillWidth: true
                    Layout.maximumWidth: 150
                }

                // 停止位标签
                Text {
                    text: "停止位:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 2
                    Layout.row: 2
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 停止位下拉框
                ComboBox {
                    id: stopBitsCombo
                    model: ["1", "1.5", "2"]
                    currentIndex: 0  // 默认1
                    Layout.column: 3
                    Layout.row: 2
                    Layout.fillWidth: true
                    Layout.maximumWidth: 150
                }

                // ========== 第四行：校验位 + 状态 ==========
                // 校验位标签
                Text {
                    text: "校验位:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 0
                    Layout.row: 3
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 校验位下拉框
                ComboBox {
                    id: parityCombo
                    model: ["None", "Odd", "Even", "Mark", "Space"]
                    currentIndex: 0  // 默认None
                    Layout.column: 1
                    Layout.row: 3
                    Layout.fillWidth: true
                    Layout.maximumWidth: 150
                }

                // 状态标签
                Text {
                    text: "状态:"
                    font.pixelSize: 14
                    color: "#B0B0B0"
                    Layout.column: 2
                    Layout.row: 3
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignRight
                }

                // 状态指示
                Row {
                    spacing: 8
                    Layout.column: 3
                    Layout.row: 3

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#9E9E9E"  // TODO: 根据串口状态动态改变颜色
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "已关闭"  // TODO: 根据串口状态动态改变文本
                        font.pixelSize: 14
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 操作按钮
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "打开串口"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                onClicked: {
                    console.log("✅ [SerialPortParamsSection] 打开串口")
                    // TODO: 实现打开串口功能
                }
            }

            Button {
                text: "关闭串口"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                onClicked: {
                    console.log("✅ [SerialPortParamsSection] 关闭串口")
                    // TODO: 实现关闭串口功能
                }
            }

            Item {
                Layout.fillWidth: true  // 占据剩余空间
            }
        }
    }
}
