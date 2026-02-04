// SerialPortControlPage.qml
// 串口控制主页面
// 创建日期: 2026-02-04
// ✅ 2026-02-04: Phase 5 - 添加键盘导航功能

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"
    focus: true  // ✅ 添加焦点支持

    // ========== 公开属性 ==========
    property int currentSerialIndex: 0  // 当前选中的串口索引 (0-5)
    property int focusItemIndex: -1     // 导航焦点索引
    property int focusSubArea: 0        // 焦点子区域 (0:列表 1:参数)

    // ========== 信号 ==========
    signal requestReturnToCategory()  // ✅ 请求返回到左侧类别

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

    // ========== 监听焦点变化，同步更新 currentSerialIndex ==========
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < serialPorts.length) {
            console.log("✅ [SerialPortControlPage] focusItemIndex 变化:", focusItemIndex, "→ 更新 currentSerialIndex")
            currentSerialIndex = focusItemIndex
        }
    }

    // ========== 键盘导航 ==========
    // ✅ 上键：列表区向上移动
    Keys.onUpPressed: {
        if (focusSubArea === 0) {
            if (focusItemIndex > 0) {
                focusItemIndex--
                console.log("✅ [SerialPortControlPage] 上键 → focusItemIndex:", focusItemIndex)
            }
        }
        event.accepted = true
    }

    // ✅ 下键：列表区向下移动
    Keys.onDownPressed: {
        if (focusSubArea === 0) {
            if (focusItemIndex < serialPorts.length - 1) {
                focusItemIndex++
                console.log("✅ [SerialPortControlPage] 下键 → focusItemIndex:", focusItemIndex)
            }
        }
        event.accepted = true
    }

    // ✅ 左键：从参数区返回列表区，或从列表区返回类别
    Keys.onLeftPressed: function(event) {
        if (focusSubArea === 1) {
            // 从参数区返回列表区
            focusSubArea = 0
            focusItemIndex = currentSerialIndex
            console.log("✅ [SerialPortControlPage] 左键 → 返回列表区, focusItemIndex:", focusItemIndex)
        } else if (focusSubArea === 0) {
            // 在列表区域，按左键返回到左侧类别
            console.log("✅ [SerialPortControlPage] 列表区域按左键，请求返回到左侧类别")
            root.requestReturnToCategory()
        }
        event.accepted = true
    }

    // ✅ 右键：从列表区进入参数区
    Keys.onRightPressed: {
        if (focusSubArea === 0) {
            // 从列表区进入参数区
            focusSubArea = 1
            focusItemIndex = -1
            console.log("✅ [SerialPortControlPage] 右键 → 进入参数区")
        }
        event.accepted = true
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortControlPage] Component.onCompleted 开始")
        console.log("✅ [SerialPortControlPage] 串口数量:", serialPorts.length)

        // ✅ 初始化焦点
        focusSubArea = 0
        focusItemIndex = 0
        root.forceActiveFocus()

        console.log("✅ [SerialPortControlPage] 初始化焦点 - focusSubArea:", focusSubArea, "focusItemIndex:", focusItemIndex)
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

                // ✅ 连接信号：鼠标点击时同步焦点
                item.serialPortSelected.connect(function(index) {
                    console.log("✅ [SerialPortControlPage] 串口选中:", index)
                    root.currentSerialIndex = index
                    root.focusItemIndex = index  // ✅ 同步焦点索引
                    root.focusSubArea = 0  // ✅ 确保在列表区域
                    root.serialPortSelected(index)
                    root.forceActiveFocus()  // ✅ 恢复焦点以支持键盘操作
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
