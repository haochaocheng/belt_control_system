// SerialPortParamsSection.qml
// 串口参数配置区域
// 创建日期: 2026-02-04
// ✅ 2026-02-04: 使用与 SwitchInputPage 一致的样式（21px字体，#9E9E9E颜色，120px标签宽度）

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 添加焦点函数
    function focusBaudRate() {
        baudRateCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 波特率获得焦点")
    }

    function focusDataBits() {
        dataBitsCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 数据位获得焦点")
    }

    function focusStopBits() {
        stopBitsCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 停止位获得焦点")
    }

    function focusParity() {
        parityCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 校验位获得焦点")
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortParamsSection] Component.onCompleted 开始")
        if (currentSerialPort) {
            console.log("✅ [SerialPortParamsSection] 当前串口:", currentSerialPort.name)
        }
        console.log("✅ [SerialPortParamsSection] Component.onCompleted 完成")
    }

    // ========== 监听串口变化 ==========
    onCurrentSerialPortChanged: {
        if (currentSerialPort) {
            console.log("✅ [SerialPortParamsSection] 串口切换:", currentSerialPort.name)
            // 更新显示
            serialNameText.text = currentSerialPort.name
            devicePathText.text = currentSerialPort.path
            serialTypeField.text = currentSerialPort.type
        }
    }

    // ========== 主布局 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.19]: 移除 ScrollView，直接使用 GridLayout
    // 原因：用户反馈波特率界面有滑动窗口，不需要
    GridLayout {
        anchors.fill: parent
        anchors.margins: 16
        columns: 4
        columnSpacing: 16
        rowSpacing: 12

            // ========== 第1行：串口名称 | 波特率 ==========

            // 串口名称标签
            Text {
                text: "串口名称:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 串口名称值（只读）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: serialNameText.implicitHeight

                Text {
                    id: serialNameText
                    anchors.fill: parent
                    text: currentSerialPort ? currentSerialPort.name : ""
                    font.pixelSize: 21
                    color: "#E0E0E0"
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 波特率标签
            Text {
                text: "波特率:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 波特率下拉框
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: baudRateCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: baudRateCombo
                    anchors.fill: parent
                    model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                    currentIndex: 3  // 默认9600
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: baudRateCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: baudRateCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第2行：设备路径 | 数据位 ==========

            // 设备路径标签
            Text {
                text: "设备路径:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 设备路径值（只读）
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: devicePathText.implicitHeight

                Text {
                    id: devicePathText
                    anchors.fill: parent
                    text: currentSerialPort ? currentSerialPort.path : ""
                    font.pixelSize: 21
                    color: "#9E9E9E"
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 数据位标签
            Text {
                text: "数据位:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 数据位下拉框
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: dataBitsCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: dataBitsCombo
                    anchors.fill: parent
                    model: ["5", "6", "7", "8"]
                    currentIndex: 3  // 默认8
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: dataBitsCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: dataBitsCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第3行：串口类型 | 停止位 ==========

            // 串口类型标签
            Text {
                text: "串口类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 串口类型输入框（可编辑）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: serialTypeField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: serialTypeField
                    anchors.fill: parent
                    text: currentSerialPort ? currentSerialPort.type : ""
                    placeholderText: "如: RS422, RS232, RS485"
                }
            }

            // 停止位标签
            Text {
                text: "停止位:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 停止位下拉框
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: stopBitsCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: stopBitsCombo
                    anchors.fill: parent
                    model: ["1", "1.5", "2"]
                    currentIndex: 0  // 默认1
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: stopBitsCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: stopBitsCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第4行：校验位 | 状态 ==========

            // 校验位标签
            Text {
                text: "校验位:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 校验位下拉框
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: parityCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: parityCombo
                    anchors.fill: parent
                    model: ["None", "Odd", "Even", "Mark", "Space"]
                    currentIndex: 0  // 默认None
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: parityCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: parityCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 状态标签
            Text {
                text: "状态:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 状态指示器
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: 30

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#9E9E9E"  // 默认关闭状态
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "已关闭"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ========== 第5行：操作按钮 ==========

            // 空白占位（左侧两列）
            Item {
                Layout.column: 0
                Layout.row: 4
                Layout.columnSpan: 2
            }

            // 打开串口按钮
            Item {
                Layout.column: 2
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: openButton.implicitHeight

                Button {
                    id: openButton
                    anchors.fill: parent
                    text: "打开串口"
                    font.pixelSize: 21
                    enabled: true  // Phase 2 实现后连接到后端
                    onClicked: {
                        console.log("✅ [SerialPortParamsSection] 打开串口:", currentSerialPort.name)
                        // TODO: Phase 2 - 调用后端打开串口
                    }
                }
            }

            // 关闭串口按钮
            Item {
                Layout.column: 3
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: closeButton.implicitHeight

                Button {
                    id: closeButton
                    anchors.fill: parent
                    text: "关闭串口"
                    font.pixelSize: 21
                    enabled: false  // Phase 2 实现后连接到后端
                    onClicked: {
                        console.log("✅ [SerialPortParamsSection] 关闭串口:", currentSerialPort.name)
                        // TODO: Phase 2 - 调用后端关闭串口
                    }
                }
            }
        }
}

