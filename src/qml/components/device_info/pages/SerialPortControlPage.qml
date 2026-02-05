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
    property int focusSubArea: 0        // 焦点子区域 (0:列表 1:Tab栏 2:参数 3:按钮)
    property int focusTabIndex: -1      // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: Tab 焦点索引
    property int focusParamIndex: 0     // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 参数焦点索引
    property int focusButtonIndex: 0    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 按钮焦点索引

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37.1]: 添加导航控制标志
    property bool isReturningToCategory: false  // 是否正在返回类别（防止事件循环）
    property bool keysEnabled: true             // 键盘事件是否启用

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.11.3]: 暴露 serialConfigPanel 供外部访问
    property alias serialConfigPanel: serialConfigPanel

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.2]: Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ========== 信号 ==========
    signal requestReturnToCategory()  // ✅ 请求返回到左侧类别

    // ========== 函数 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.6]: 添加 getCurrentTab 函数
    // 返回当前 Tab 的引用
    function getCurrentTab() {
        if (!serialConfigPanel.item) {
            return null
        }
        return serialConfigPanel.item.getCurrentTabItem()
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 修改 getParamFieldCount 函数
    // 返回当前 Tab 的参数数量（动态获取）
    function getParamFieldCount() {
        if (!serialConfigPanel.item) {
            console.warn("⚠️ [SerialPortControlPage] SerialPortConfigPanel 未加载")
            return 0
        }

        var currentTab = serialConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            console.warn("⚠️ [SerialPortControlPage] 当前 Tab 未加载")
            return 0
        }

        if (typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }

        // 默认参数数量（根据 Tab 索引）
        switch(root.focusTabIndex) {
        case 0:  // 参数配置
            return 8  // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.11]: 移除打开串口和关闭串口按钮，从10改为8
        case 1:  // 发送区
            return 5
        case 2:  // 接收区
            return 5
        case 3:  // MODBUS寄存器
            return 8
        default:
            return 0
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 修改 triggerParamInput 函数
    // 调用当前 Tab 的 triggerParamInput 方法
    function triggerParamInput(index) {
        console.log("✅ [SerialPortControlPage] triggerParamInput - 参数索引:", index)

        if (!serialConfigPanel.item) {
            console.error("❌ [SerialPortControlPage] SerialPortConfigPanel 未加载")
            return
        }

        var currentTab = serialConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            console.error("❌ [SerialPortControlPage] 当前 Tab 未加载")
            return
        }

        // 调用当前 Tab 的 triggerParamInput 方法
        if (typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(index)
        } else {
            console.warn("⚠️ [SerialPortControlPage] 当前 Tab 没有 triggerParamInput 方法")
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

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37.1]: 标志重置定时器
    Timer {
        id: resetFlagTimer
        interval: 100
        repeat: false
        onTriggered: {
            root.isReturningToCategory = false
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37.1]: 监听焦点变化，启用键盘事件
    onActiveFocusChanged: {
        if (activeFocus) {
            keysEnabled = true
        }
    }

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
            currentArea = areaMotorList  // ✅ 使用 areaMotorList（通用列表区域）
            motorListIndex = 0  // ✅ 使用 motorListIndex（通用列表索引）
            tabIndex = 0  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 初始 Tab 索引
            paramIndex = 0  // ✅ 初始参数索引
            buttonIndex = 0
            skipTabArea = false  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 支持 Tab 导航
            lastTabIndex = 3  // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.3]: 串口控制页面有4个Tab（0-3）

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 动态更新 lastParamIndex
            // 根据当前 Tab 的参数数量更新
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
                console.log("✅ [SerialPortControlPage] 初始参数数量:", paramCount)
            })

            console.log("✅ [SerialPortControlPage] NavigationManager 初始化完成")

            // 同步初始状态到root
            root.currentSerialIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        // 监听串口列表索引变化
        onMotorListIndexChanged: {
            console.log("✅ [SerialPortControlPage] 串口列表索引变化:", motorListIndex)
            root.currentSerialIndex = motorListIndex
            root.focusItemIndex = motorListIndex
        }

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 监听 Tab 索引变化
        onTabIndexChanged: {
            console.log("✅ [SerialPortControlPage] Tab 索引变化:", tabIndex)
            root.focusTabIndex = tabIndex

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37.2]: 同步更新 SerialPortConfigPanel 的 currentTabIndex
            if (serialConfigPanel.item) {
                serialConfigPanel.item.currentTabIndex = tabIndex
                console.log("✅ [SerialPortControlPage] 已同步 currentTabIndex 到 SerialPortConfigPanel:", tabIndex)
            }

            // 更新 lastParamIndex
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
                console.log("✅ [SerialPortControlPage] Tab 切换后参数数量:", paramCount)
            })
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            console.log("✅ [SerialPortControlPage] 参数索引变化:", paramIndex)
            root.focusParamIndex = paramIndex
            // ✅ 调用 triggerParamInput 设置焦点
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
            case areaMotorList:  // 列表区域
                root.focusSubArea = 0
                root.focusItemIndex = motorListIndex
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaTabBar:  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: Tab 栏区域
                root.focusSubArea = 1
                root.focusTabIndex = tabIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:  // 参数区域
                root.focusSubArea = 2
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                // ✅ 强制触发焦点设置
                root.triggerParamInput(paramIndex)
                break
            case areaButtons:  // 按钮区域
                root.focusSubArea = 3
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.7]: 监听 returnToCategory 信号，释放焦点
        // 参考 MotorControlPage.qml 的实现，当在列表区域按左键时，返回到类别区域
        onReturnToCategory: {
            console.log("✅ [SerialPortControlPage] 接收到 returnToCategory 信号，释放焦点")
            // 设置标志，防止后续键盘事件被处理
            root.isReturningToCategory = true
            // 禁用键盘事件接收
            root.keysEnabled = false
            // 主动通知 DeviceSettingsDialog 获取焦点
            root.requestReturnToCategory()
            // 延迟重置标志
            resetFlagTimer.start()
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37.1]: 恢复完整的键盘事件处理器
    // 参考 MotorControlPage.qml 的实现，添加上下左右键处理

    // 上键：向上导航
    Keys.onUpPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        console.log("✅ [SerialPortControlPage] 按上键")

        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.3]: 发送区Tab使用自定义导航
        if (navigationManager.currentArea === navigationManager.areaParams) {
            var configPanel = serialConfigPanel.item
            if (configPanel && typeof configPanel.getCurrentTabItem === "function") {
                var currentTab = configPanel.getCurrentTabItem()
                if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                    console.log("✅ [SerialPortControlPage] 调用当前Tab自定义导航")
                    var handled = currentTab.handleDirectionKey("Up")
                    if (handled) {
                        event.accepted = true
                        return
                    }
                }
            }
        }

        navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    // 下键：向下导航
    Keys.onDownPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        console.log("✅ [SerialPortControlPage] 按下键")

        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.3]: 发送区Tab使用自定义导航
        if (navigationManager.currentArea === navigationManager.areaParams) {
            var configPanel = serialConfigPanel.item
            if (configPanel && typeof configPanel.getCurrentTabItem === "function") {
                var currentTab = configPanel.getCurrentTabItem()
                if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                    console.log("✅ [SerialPortControlPage] 调用当前Tab自定义导航")
                    var handled = currentTab.handleDirectionKey("Down")
                    if (handled) {
                        event.accepted = true
                        return
                    }
                }
            }
        }

        navigationManager.handleDirectionKey("Down")
        event.accepted = true
    }

    // 左键：向左导航或返回类别
    Keys.onLeftPressed: function(event) {
        if (isReturningToCategory) {
            event.accepted = true
            return
        }
        if (navigationManager.currentArea === navigationManager.areaMotorList) {
            // 在列表区域，按左键返回到左侧类别
            console.log("✅ [SerialPortControlPage] 列表区域按左键，请求返回到左侧类别")
            root.isReturningToCategory = true
            root.requestReturnToCategory()
            resetFlagTimer.start()
            event.accepted = true
        } else {
            console.log("✅ [SerialPortControlPage] 按左键")

            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.3]: 发送区Tab使用自定义导航
            if (navigationManager.currentArea === navigationManager.areaParams) {
                var configPanel = serialConfigPanel.item
                if (configPanel && typeof configPanel.getCurrentTabItem === "function") {
                    var currentTab = configPanel.getCurrentTabItem()
                    if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                        console.log("✅ [SerialPortControlPage] 调用当前Tab自定义导航")
                        var handled = currentTab.handleDirectionKey("Left")
                        if (handled) {
                            event.accepted = true
                            return
                        }
                    }
                }
            }

            navigationManager.handleDirectionKey("Left")
            event.accepted = true
        }
    }

    // 右键：向右导航
    Keys.onRightPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        console.log("✅ [SerialPortControlPage] 按右键")

        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.3]: 发送区Tab使用自定义导航
        if (navigationManager.currentArea === navigationManager.areaParams) {
            var configPanel = serialConfigPanel.item
            if (configPanel && typeof configPanel.getCurrentTabItem === "function") {
                var currentTab = configPanel.getCurrentTabItem()
                if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                    console.log("✅ [SerialPortControlPage] 调用当前Tab自定义导航")
                    var handled = currentTab.handleDirectionKey("Right")
                    if (handled) {
                        event.accepted = true
                        return
                    }
                }
            }
        }

        navigationManager.handleDirectionKey("Right")
        event.accepted = true
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
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 改为 ColumnLayout，添加底部按钮区域
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 上部：列表和配置区域 ==========
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
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

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 传递焦点管理属性
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                    item.focusTabIndex = Qt.binding(function() { return root.focusTabIndex })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 传递虚拟键盘引用
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 连接信号，转发焦点更新
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        console.log("✅ [SerialPortControlPage] 收到焦点请求:", paramIndex)
                        root.focusParamIndex = paramIndex
                        navigationManager.paramIndex = paramIndex
                    })

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 4]: 监听 currentTabIndex 变化
                    item.onCurrentTabIndexChanged.connect(function() {
                        console.log("✅ [SerialPortControlPage] Tab 切换:", item.currentTabIndex)
                        navigationManager.tabIndex = item.currentTabIndex
                    })
                }
            }
        }

        // ========== 底部：按钮区域 ==========
        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 添加底部按钮区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90  // 两行按钮，每行35高度 + 间距
            color: "#1a1f2e"

            // 装饰边框
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 2
                color: "#00d4ff"
                opacity: 0.3
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // 第一行：打开串口、关闭串口
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: openSerialButton
                        text: "打开串口"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 0) {
                                    return "#2ecc71"  // 焦点时：亮绿色
                                } else if (parent.pressed) {
                                    return "#27ae60"
                                } else if (parent.hovered) {
                                    return "#2ecc71"
                                } else {
                                    return "#27ae60"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：5px
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 0 ? 5 : 0
                            border.color: "#2196F3"
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [SerialPortControlPage] 打开串口")
                            // TODO: 实现打开串口功能
                        }
                    }

                    Button {
                        id: closeSerialButton
                        text: "关闭串口"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 1) {
                                    return "#e74c3c"  // 焦点时：亮红色
                                } else if (parent.pressed) {
                                    return "#c0392b"
                                } else if (parent.hovered) {
                                    return "#e74c3c"
                                } else {
                                    return "#c0392b"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：5px
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 1 ? 5 : 0
                            border.color: "#2196F3"
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [SerialPortControlPage] 关闭串口")
                            // TODO: 实现关闭串口功能
                        }
                    }
                }

                // 第二行：保存、删除、重置
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: saveButton
                        text: "保存"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 2) {
                                    return "#2ecc71"  // 焦点时：亮绿色
                                } else if (parent.pressed) {
                                    return "#27ae60"
                                } else if (parent.hovered) {
                                    return "#2ecc71"
                                } else {
                                    return "#27ae60"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：5px
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 2 ? 5 : 0
                            border.color: "#2196F3"
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [SerialPortControlPage] 保存")
                            // TODO: 实现保存功能
                        }
                    }

                    Button {
                        id: deleteButton
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 3) {
                                    return "#e74c3c"  // 焦点时：亮红色
                                } else if (parent.pressed) {
                                    return "#c0392b"
                                } else if (parent.hovered) {
                                    return "#e74c3c"
                                } else {
                                    return "#d35400"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：5px
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 3 ? 5 : 0
                            border.color: "#2196F3"
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [SerialPortControlPage] 删除")
                            // TODO: 实现删除功能
                        }
                    }

                    Button {
                        id: resetButton
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 5]: 焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 4) {
                                    return "#3498db"  // 焦点时：亮蓝色
                                } else if (parent.pressed) {
                                    return "#2980b9"
                                } else if (parent.hovered) {
                                    return "#3498db"
                                } else {
                                    return "#2980b9"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：5px
                            border.width: root.focusSubArea === 3 && root.focusButtonIndex === 4 ? 5 : 0
                            border.color: "#2196F3"
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [SerialPortControlPage] 重置")
                            // TODO: 实现重置功能
                        }
                    }
                }
            }
        }
    }
}
