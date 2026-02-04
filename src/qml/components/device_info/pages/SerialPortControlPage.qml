// SerialPortControlPage.qml
// 串口控制主页面
// 创建日期: 2026-02-04

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int currentSerialIndex: 0  // 当前选中的串口索引 (0-5)
    property int focusItemIndex: -1     // 导航焦点索引
    property int focusSubArea: 0        // 焦点子区域 (0:列表 1:参数 2:按钮)

    // ========== 串口数据 ==========
    property var serialPorts: [
        { name: "COM1", path: "/dev/ttyS0", type: "RS422" },
        { name: "COM2", path: "/dev/ttyS7", type: "RS422" },
        { name: "COM3", path: "/dev/ttyCH9344USB0", type: "RS232" },
        { name: "COM4", path: "/dev/ttyCH9344USB1", type: "RS232" },
        { name: "COM5", path: "/dev/ttyCH9344USB2", type: "RS485" },
        { name: "COM6", path: "/dev/ttyCH9344USB3", type: "RS485" }
    ]

    // ========== 当前串口信息 ==========
    property var currentSerialPort: serialPorts[currentSerialIndex]

    // ========== 信号 ==========
    signal serialPortSelected(int index)

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortControlPage] Component.onCompleted 开始")
        console.log("✅ [SerialPortControlPage] 串口数量:", serialPorts.length)
        console.log("✅ [SerialPortControlPage] Component.onCompleted 完成")
    }

    // ========== 主布局 ==========
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧：串口列表 ==========
        Loader {
            id: serialListPanel
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            source: "SerialPortListPanel.qml"

            onLoaded: {
                console.log("✅ [SerialPortControlPage] SerialPortListPanel 加载成功")

                // 传递属性
                item.serialPorts = Qt.binding(function() { return root.serialPorts })
                item.currentSerialIndex = Qt.binding(function() { return root.currentSerialIndex })
                item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })

                // 连接信号
                item.serialPortSelected.connect(function(index) {
                    console.log("✅ [SerialPortControlPage] 串口选中:", index)
                    root.currentSerialIndex = index
                    root.serialPortSelected(index)
                })
            }
        }

        // ========== 分隔线 ==========
        Rectangle {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            color: "#3d4556"
        }

        // ========== 右侧：串口配置和操作区域 ==========
        Loader {
            id: serialConfigPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: "SerialPortConfigPanel.qml"

            onLoaded: {
                console.log("✅ [SerialPortControlPage] SerialPortConfigPanel 加载成功")

                // 传递属性
                item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
            }
        }
    }
}
