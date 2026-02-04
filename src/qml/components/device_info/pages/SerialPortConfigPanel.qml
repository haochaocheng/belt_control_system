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
        Loader {
            id: paramsSection
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            source: "SerialPortParamsSection.qml"

            onLoaded: {
                console.log("✅ [SerialPortConfigPanel] SerialPortParamsSection 加载成功")
                // 传递当前串口信息
                item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
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
