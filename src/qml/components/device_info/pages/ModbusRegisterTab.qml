// ModbusRegisterTab.qml
// MODBUS 寄存器操作 Tab
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 从 ModbusRegisterSection.qml 重命名
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

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 添加焦点函数
    function focusSlaveAddress() {
        slaveAddress.forceActiveFocus()
        console.log("✅ [ModbusRegisterSection] 从站地址获得焦点")
    }

    function focusFunctionCode() {
        functionCode.forceActiveFocus()
        console.log("✅ [ModbusRegisterSection] 功能码获得焦点")
    }

    function focusStartAddress() {
        startAddress.forceActiveFocus()
        console.log("✅ [ModbusRegisterSection] 起始地址获得焦点")
    }

    function focusQuantity() {
        quantity.forceActiveFocus()
        console.log("✅ [ModbusRegisterSection] 数量获得焦点")
    }

    function focusWriteValue() {
        writeValue.forceActiveFocus()
        console.log("✅ [ModbusRegisterSection] 写入值获得焦点")
    }

    function focusRegisterList() {
        registerListView.forceActiveFocus()
        console.log("✅ [ModbusRegisterSection] 寄存器列表获得焦点")
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [ModbusRegisterSection] Component.onCompleted 开始")
        console.log("✅ [ModbusRegisterSection] Component.onCompleted 完成")
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ========== 标题 ==========
        Text {
            text: "MODBUS 寄存器操作"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            Layout.fillWidth: true
        }

        // ========== 参数输入区 ==========
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 12
            rowSpacing: 12

            // 从站地址
            Text {
                text: "从站地址:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Item {
                Layout.preferredWidth: 80
                implicitHeight: slaveAddress.implicitHeight

                DeviceInfo.CustomTextField {
                    id: slaveAddress
                    anchors.fill: parent
                    text: "01"
                    placeholderText: "01-FF"
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{1,2}/
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: slaveAddress.activeFocus ? "#2196F3" : "transparent"
                    border.width: slaveAddress.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 功能码
            Text {
                text: "功能码:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Item {
                Layout.preferredWidth: 200
                implicitHeight: functionCode.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: functionCode
                    anchors.fill: parent
                    model: ["03-读保持寄存器", "06-写单个寄存器", "10-写多个寄存器"]
                    currentIndex: 0
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: functionCode.activeFocus ? "#2196F3" : "transparent"
                    border.width: functionCode.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 起始地址
            Text {
                text: "起始地址:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Item {
                Layout.preferredWidth: 80
                implicitHeight: startAddress.implicitHeight

                DeviceInfo.CustomTextField {
                    id: startAddress
                    anchors.fill: parent
                    text: "0000"
                    placeholderText: "0000-FFFF"
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{1,4}/
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: startAddress.activeFocus ? "#2196F3" : "transparent"
                    border.width: startAddress.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 数量
            Text {
                text: "数量:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Item {
                Layout.preferredWidth: 100
                implicitHeight: quantity.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: quantity
                    anchors.fill: parent
                    from: 1
                    to: 125
                    value: 10
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: quantity.activeFocus ? "#2196F3" : "transparent"
                    border.width: quantity.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 写入值
            Text {
                text: "写入值:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Item {
                Layout.preferredWidth: 80
                implicitHeight: writeValue.implicitHeight

                DeviceInfo.CustomTextField {
                    id: writeValue
                    anchors.fill: parent
                    enabled: functionCode.currentIndex > 0
                    placeholderText: "0000-FFFF"
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{1,4}/
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: writeValue.activeFocus ? "#2196F3" : "transparent"
                    border.width: writeValue.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            Item {
                Layout.columnSpan: 2
            }
        }

        // ========== 操作按钮 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "读取"
                Layout.preferredWidth: 100
                enabled: functionCode.currentIndex === 0

                onClicked: {
                    console.log("✅ [ModbusRegisterSection] 读取寄存器")
                    console.log("   - 从站地址:", slaveAddress.text)
                    console.log("   - 起始地址:", startAddress.text)
                    console.log("   - 数量:", quantity.value)

                    // TODO: Phase 2 - 调用后端读取寄存器
                    // modbusController.readHoldingRegisters(
                    //     parseInt(slaveAddress.text, 16),
                    //     parseInt(startAddress.text, 16),
                    //     quantity.value
                    // )
                }
            }

            Button {
                text: "写入"
                Layout.preferredWidth: 100
                enabled: functionCode.currentIndex > 0 && writeValue.text.length > 0

                onClicked: {
                    console.log("✅ [ModbusRegisterSection] 写入寄存器")
                    console.log("   - 从站地址:", slaveAddress.text)
                    console.log("   - 起始地址:", startAddress.text)
                    console.log("   - 写入值:", writeValue.text)

                    // TODO: Phase 2 - 调用后端写入寄存器
                    if (functionCode.currentIndex === 1) {
                        // modbusController.writeSingleRegister(
                        //     parseInt(slaveAddress.text, 16),
                        //     parseInt(startAddress.text, 16),
                        //     parseInt(writeValue.text, 16)
                        // )
                    } else {
                        // modbusController.writeMultipleRegisters(
                        //     parseInt(slaveAddress.text, 16),
                        //     parseInt(startAddress.text, 16),
                        //     [parseInt(writeValue.text, 16)]
                        // )
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // ========== 寄存器列表标题 ==========
        Text {
            text: "寄存器列表"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
            Layout.fillWidth: true
            Layout.topMargin: 8
        }

        // ========== 寄存器列表表头 ==========
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#1e2838"
            border.color: "#3d4556"
            border.width: 1
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0

                Text {
                    text: "地址"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: "#3d4556"
                }

                Text {
                    text: "值(HEX)"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: "#3d4556"
                }

                Text {
                    text: "值(DEC)"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                    Layout.preferredWidth: 100
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: "#3d4556"
                }

                Text {
                    text: "说明"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    leftPadding: 8
                }
            }
        }

        // ========== 寄存器列表内容 ==========
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollView {
                anchors.fill: parent
                clip: true

                ListView {
                    id: registerListView
                    model: ListModel {
                        id: registerModel
                        // 模拟数据（Phase 2 后端实现后替换）
                        ListElement { address: "0000"; hexValue: "0001"; decValue: "1"; description: "状态寄存器" }
                        ListElement { address: "0001"; hexValue: "0064"; decValue: "100"; description: "速度设定" }
                        ListElement { address: "0002"; hexValue: "00C8"; decValue: "200"; description: "温度设定" }
                    }

                    delegate: Rectangle {
                        width: registerListView.width
                        height: 40
                        color: index % 2 === 0 ? "#1e2838" : "#2c3e50"
                        border.color: "#3d4556"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 0

                            Text {
                                text: model.address
                                font.pixelSize: 14
                                color: "#E0E0E0"
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 1
                                Layout.fillHeight: true
                                color: "#3d4556"
                            }

                            Text {
                                text: model.hexValue
                                font.pixelSize: 14
                                color: "#4CAF50"
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 1
                                Layout.fillHeight: true
                                color: "#3d4556"
                            }

                            Text {
                                text: model.decValue
                                font.pixelSize: 14
                                color: "#2196F3"
                                Layout.preferredWidth: 100
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 1
                                Layout.fillHeight: true
                                color: "#3d4556"
                            }

                            Text {
                                text: model.description
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                leftPadding: 8
                            }
                        }
                    }
                }
            }

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.4]: 焦点指示器
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: registerListView.activeFocus ? "#2196F3" : "transparent"
                border.width: registerListView.activeFocus ? 3 : 0
                radius: 4
                z: 10
            }
        }
    }
}
