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

    // ========== 函数 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.10]: 添加 getParamFieldCount 函数
    // 串口控制页面不支持参数区域内的逐个导航，返回 0
    function getParamFieldCount() {
        return 0  // 不支持参数区域内的逐个导航
    }

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

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.6]: 监听 focusSubArea 变化
    onFocusSubAreaChanged: {
        console.log("🔍 [SerialPortControlPage] focusSubArea 变化:", focusSubArea)
        console.log("🔍 [SerialPortControlPage] 当前状态 - focusItemIndex:", focusItemIndex, "currentSerialIndex:", currentSerialIndex)
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 5.4]: 移除 Keys.onUpPressed/onDownPressed/onRightPressed
    // 原因：这些处理器会在鼠标点击后拦截导航键事件，导致 DeviceSettingsDialog 的导航逻辑被绕过
    // 解决方案：完全依赖 DeviceSettingsDialog 的默认处理 + Connections 同步
    // 参考：SwitchInputPage 和 AnalogInputPage 的实现

    // ✅ 左键：从列表区返回类别（保留此功能）
    Keys.onLeftPressed: function(event) {
        if (focusSubArea === 0) {
            // 在列表区域，按左键返回到左侧类别
            console.log("✅ [SerialPortControlPage] 列表区域按左键，请求返回到左侧类别")
            root.requestReturnToCategory()
            event.accepted = true
        }
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortControlPage] Component.onCompleted 开始")
        console.log("✅ [SerialPortControlPage] 串口数量:", serialPorts.length)

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.9]: 检查 Loader 状态
        console.log("🔍 [SerialPortControlPage] serialListPanel.status:", serialListPanel.status)
        console.log("🔍 [SerialPortControlPage] serialListPanel.item:", serialListPanel.item)
        console.log("🔍 [SerialPortControlPage] serialConfigPanel.status:", serialConfigPanel.status)
        console.log("🔍 [SerialPortControlPage] serialConfigPanel.item:", serialConfigPanel.item)

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 5.4]: 移除 forceActiveFocus()
        // 原因：不应该让 SerialPortControlPage 获得焦点，焦点应该由 DeviceSettingsDialog 管理
        // 初始化焦点状态
        focusSubArea = 0
        focusItemIndex = 0

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
                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 5.4]: 移除 forceActiveFocus()
                    // 原因：不应该让 SerialPortControlPage 获得焦点，焦点应该由 DeviceSettingsDialog 管理
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

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.9]: 监听 Loader 状态
            onStatusChanged: {
                console.log("🔍 [SerialPortControlPage] serialConfigPanel Loader 状态变化:", status)
                if (status === Loader.Error) {
                    console.error("❌ [SerialPortControlPage] serialConfigPanel Loader 加载失败")
                } else if (status === Loader.Ready) {
                    console.log("✅ [SerialPortControlPage] serialConfigPanel Loader 加载完成")
                } else if (status === Loader.Loading) {
                    console.log("🔄 [SerialPortControlPage] serialConfigPanel Loader 加载中...")
                } else if (status === Loader.Null) {
                    console.log("⚠️ [SerialPortControlPage] serialConfigPanel Loader 状态为 Null")
                }
            }

            onLoaded: {
                console.log("✅ [SerialPortControlPage] SerialPortConfigPanel 加载成功")

                // 传递属性
                item.currentSerialPort = Qt.binding(function() { return root.currentSerialPort })
                // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.4]: 传递 focusSubArea
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
            }
        }
    }
}
