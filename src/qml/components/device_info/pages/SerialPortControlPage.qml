// SerialPortControlPage.qml
// 串口控制主页面
// 创建日期: 2026-02-04
// ✅ 2026-02-04: Phase 5 - 添加键盘导航功能

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 导入 NavigationManager

Rectangle {
    id: root
    color: "transparent"
    focus: true  // ✅ 添加焦点支持

    // ========== 公开属性 ==========
    property int currentSerialIndex: 0  // 当前选中的串口索引 (0-5)
    property int focusItemIndex: -1     // 导航焦点索引
    property int focusSubArea: 0        // 焦点子区域 (0:列表 1:参数 2:按钮)
    property int focusParamIndex: 0     // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 参数焦点索引
    property int focusButtonIndex: 0    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 按钮焦点索引

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ========== 信号 ==========
    signal requestReturnToCategory()  // ✅ 请求返回到左侧类别

    // ========== 函数 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 修改 getParamFieldCount 函数
    // 返回参数区域的可导航元素数量（参考 SwitchInputPage）
    // 布局：2列4行 + 2按钮，索引连续 0-9
    function getParamFieldCount() {
        return 10  // 10个可导航元素（索引0-9）
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 重新规划导航索引（参考 SwitchInputPage）
    // 布局：2列4行 + 2按钮，索引连续 0-9
    // Row 0: [0]串口名称(只读)  [1]波特率(可编辑)
    // Row 1: [2]设备路径(只读)  [3]数据位(可编辑)
    // Row 2: [4]串口类型(只读)  [5]停止位(可编辑)
    // Row 3: [6]校验位(可编辑)  [7]状态(只读)
    // Row 4: [8]打开串口(按钮)  [9]关闭串口(按钮)
    function triggerParamInput(index) {
        console.log("✅ [SerialPortControlPage] triggerParamInput - 参数索引:", index)

        if (!serialConfigPanel.item) {
            console.error("❌ [SerialPortControlPage] SerialPortConfigPanel 未加载")
            return
        }

        if (!serialConfigPanel.item.paramsSection.item) {
            console.error("❌ [SerialPortControlPage] SerialPortParamsSection 未加载")
            return
        }

        var paramsSection = serialConfigPanel.item.paramsSection.item

        // 根据索引触发对应的输入控件
        switch(index) {
        case 0:  // 串口名称（只读，但可以有焦点）
            paramsSection.focusSerialName()
            break
        case 1:  // 波特率 (ComboBox)
            paramsSection.focusBaudRate()
            break
        case 2:  // 设备路径（只读，但可以有焦点）
            paramsSection.focusDevicePath()
            break
        case 3:  // 数据位 (ComboBox)
            paramsSection.focusDataBits()
            break
        case 4:  // 串口类型（只读，但可以有焦点）
            paramsSection.focusSerialType()
            break
        case 5:  // 停止位 (ComboBox)
            paramsSection.focusStopBits()
            break
        case 6:  // 校验位 (ComboBox)
            paramsSection.focusParity()
            break
        case 7:  // 状态（只读，但可以有焦点）
            paramsSection.focusStatus()
            break
        case 8:  // 打开串口按钮
            paramsSection.focusOpenButton()
            break
        case 9:  // 关闭串口按钮
            paramsSection.focusCloseButton()
            break
        default:
            console.warn("⚠️ [SerialPortControlPage] 未知的参数索引:", index)
            break
        }
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

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: NavigationManager 实例
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 初始化：从串口列表区开始
        Component.onCompleted: {
            currentArea = areaMotorList  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.10]: 使用 areaMotorList（通用列表区域）
            motorListIndex = 0  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.9]: 使用 motorListIndex（通用列表索引）
            paramIndex = 0  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 初始参数索引改为0（串口名称）
            buttonIndex = 0
            skipTabArea = true  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.12]: 串口控制页面没有Tab区域

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 设置 lastParamIndex
            // 串口参数区域有10个参数（索引0-9）：
            // 0=串口名称, 1=波特率, 2=设备路径, 3=数据位, 4=串口类型, 5=停止位,
            // 6=校验位, 7=状态, 8=打开串口按钮, 9=关闭串口按钮
            // 最大索引是9
            updateLastParamIndex(10)  // 参数数量=10，最大索引=9

            console.log("✅ [SerialPortControlPage] NavigationManager 初始化完成")

            // 同步初始状态到root
            root.currentSerialIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        // 监听串口列表索引变化
        onMotorListIndexChanged: {  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.9]: 使用 motorListIndex（通用列表索引）
            console.log("✅ [SerialPortControlPage] 串口列表索引变化:", motorListIndex)
            root.currentSerialIndex = motorListIndex
            root.focusItemIndex = motorListIndex
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            console.log("✅ [SerialPortControlPage] 参数索引变化:", paramIndex)
            root.focusParamIndex = paramIndex
            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.11]: 调用 triggerParamInput 设置焦点
            root.triggerParamInput(paramIndex)
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            console.log("✅ [SerialPortControlPage] 按钮索引变化:", buttonIndex)
            root.focusButtonIndex = buttonIndex
        }

        // 监听区域变化
        onAreaChanged: function(newArea) {
            console.log("✅ [SerialPortControlPage] 区域变化:", newArea)
            switch(newArea) {
            case areaMotorList:  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.10]: 使用 areaMotorList（通用列表区域）
                root.focusSubArea = 0
                root.focusItemIndex = motorListIndex  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.9]: 使用 motorListIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 1
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.13]: 强制触发焦点设置
                root.triggerParamInput(paramIndex)
                break
            case areaButtons:
                root.focusSubArea = 2
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                break
            }
        }
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
