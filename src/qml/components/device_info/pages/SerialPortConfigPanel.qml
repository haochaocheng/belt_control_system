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
    property int focusSubArea: 0  // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.3]: 接收焦点状态（0=列表 1=参数）

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.3]: 焦点指示器
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: (focusSubArea === 1) ? "#2196F3" : "transparent"
        border.width: (focusSubArea === 1) ? 2 : 0
        radius: 4
        z: -1  // 放在最底层
    }

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
                Layout.preferredHeight: 380  // ✅ 修正高度：305 → 380（标题40 + TextArea225 + 按钮50 + 边距65）
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
                Layout.preferredHeight: 425  // ✅ 修正高度：350 → 425（标题40 + TextArea270 + 按钮50 + 边距65）
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
