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
        console.log("✅ [SerialPortConfigPanel] currentSerialPort:", currentSerialPort)
        console.log("✅ [SerialPortConfigPanel] Component.onCompleted 完成")
    }

    // ========== 监听串口变化 ==========
    onCurrentSerialPortChanged: {
        console.log("✅ [SerialPortConfigPanel] currentSerialPort 变化:", currentSerialPort)
        if (currentSerialPort) {
            console.log("   - 串口名称:", currentSerialPort.name)
            console.log("   - 设备路径:", currentSerialPort.path)
            console.log("   - 串口类型:", currentSerialPort.type)
        }
    }

    // ========== 主布局（使用 ScrollView 包裹所有区域）==========
    // ✅ 2026-02-04: 添加 ScrollView 使所有区域可滚动查看
    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        clip: true
        contentWidth: availableWidth  // 防止水平滚动

        ColumnLayout {
            width: parent.width
            spacing: 16

            // ========== 1. 串口参数配置区 ==========
            Loader {
                id: paramsSection
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                source: "SerialPortParamsSection.qml"

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] SerialPortParamsSection 加载成功")
                    console.log("✅ [SerialPortConfigPanel] 传递 currentSerialPort:", root.currentSerialPort)
                    // 传递当前串口信息
                    item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
                    console.log("✅ [SerialPortConfigPanel] 绑定完成，item.currentSerialPort:", item.currentSerialPort)
                }
            }

            // ========== 2. 发送区 ==========
            Loader {
                id: sendSection
                Layout.fillWidth: true
                Layout.preferredHeight: 230  // ✅ 调整高度：250 → 230（移除内部ScrollView后）
                source: "SerialPortSendSection.qml"

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] SerialPortSendSection 加载成功")
                    // 传递当前串口信息
                    item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
                }
            }

            // ========== 3. 接收区 ==========
            Loader {
                id: receiveSection
                Layout.fillWidth: true
                Layout.preferredHeight: 260  // ✅ 调整高度：280 → 260（移除内部ScrollView后）
                source: "SerialPortReceiveSection.qml"

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] SerialPortReceiveSection 加载成功")
                    // 传递当前串口信息
                    item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
                }
            }

            // ========== 4. MODBUS寄存器操作 ==========
            Loader {
                id: modbusSection
                Layout.fillWidth: true
                Layout.preferredHeight: 600  // ✅ 使用固定高度而不是 fillHeight
                source: "ModbusRegisterSection.qml"

                onLoaded: {
                    console.log("✅ [SerialPortConfigPanel] ModbusRegisterSection 加载成功")
                    // 传递当前串口信息
                    item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
                }
            }
        }
    }
}
