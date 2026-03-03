// MQTTControlPage.qml
// MQTT 控制主页面
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.7]: 移除底部按钮区域（MQTT页面不需要），修复导航问题
// ✅ 2026-02-08 [Phase 7.43.11]: 完善与MQTTController的绑定

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"
    focus: true

    // ========== 公开属性 ==========
    property int currentModuleIndex: 0    // 当前选中的模块索引 (0-7)
    property int focusItemIndex: -1       // 导航焦点索引
    property int focusSubArea: 0          // 焦点子区域 (0:列表 1:Tab栏 2:参数)
    property int focusTabIndex: -1        // Tab 焦点索引
    property int focusParamIndex: 0       // 参数焦点索引
    property int focusButtonIndex: 0      // 按钮焦点索引（保留但不使用）

    // 导航控制标志
    property bool isReturningToCategory: false
    property bool keysEnabled: true

    // 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // 暴露 mqttConfigPanel 供外部访问
    property alias mqttConfigPanel: mqttConfigPanel

    // Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ========== 信号 ==========
    signal requestReturnToCategory()
    signal moduleSelected(int index)
    signal connectRequested(int moduleIndex)
    signal disconnectRequested(int moduleIndex)

    // ========== MQTT 模块数据（从控制器同步）==========
    // ✅ 2026-02-08 [Phase 7.43.11]: 使用mqttController的modules属性
    property var mqttModules: mqttController ? mqttController.modules : [
        { name: "模块1", connected: false, connectionState: "未连接" },
        { name: "模块2", connected: false, connectionState: "未连接" },
        { name: "模块3", connected: false, connectionState: "未连接" },
        { name: "模块4", connected: false, connectionState: "未连接" },
        { name: "模块5", connected: false, connectionState: "未连接" },
        { name: "模块6", connected: false, connectionState: "未连接" },
        { name: "模块7", connected: false, connectionState: "未连接" },
        { name: "模块8", connected: false, connectionState: "未连接" }
    ]

    // ========== 当前模块信息 ==========
    property var currentModule: mqttModules[currentModuleIndex]

    // ========== 连接/断开函数 ==========
    // ✅ 2026-02-08 [Phase 7.43.11]: 添加连接/断开功能
    function connectToModule(moduleIndex) {
        var idx = moduleIndex >= 0 ? moduleIndex : currentModuleIndex
        console.log("✅ [MQTTControlPage] 连接模块:", idx)
        if (mqttController) {
            mqttController.connectToModule(idx)
        }
        connectRequested(idx)
    }

    function disconnectFromModule(moduleIndex) {
        var idx = moduleIndex >= 0 ? moduleIndex : currentModuleIndex
        console.log("✅ [MQTTControlPage] 断开模块:", idx)
        if (mqttController) {
            mqttController.disconnectFromModule(idx)
        }
        disconnectRequested(idx)
    }

    function saveConfig() {
        console.log("✅ [MQTTControlPage] 保存配置")
        if (mqttController) {
            mqttController.saveModuleConfig(currentModuleIndex)
        }
    }

    function loadConfig() {
        console.log("✅ [MQTTControlPage] 加载配置")
        if (mqttController) {
            mqttController.loadModuleConfig(currentModuleIndex)
        }
    }

    function resetConfig() {
        console.log("✅ [MQTTControlPage] 重置配置")
        if (mqttController) {
            mqttController.resetModuleConfig(currentModuleIndex)
        }
    }

    // ========== 监听控制器信号 ==========
    // ✅ 2026-02-08 [Phase 7.43.11]: 监听控制器的连接状态变化
    Connections {
        target: mqttController
        enabled: mqttController !== null
        // ✅ 2026-03-03 [Phase 7.47.78]: QDS 兼容 - QDS mock 无 onModulesChanged 等信号
        ignoreUnknownSignals: true

        function onModulesChanged() {
            console.log("✅ [MQTTControlPage] 模块列表已更新")
            // 强制刷新模块列表
            mqttModules = mqttController.modules
        }

        function onConnectedChanged(moduleIndex, connected) {
            console.log("✅ [MQTTControlPage] 模块", moduleIndex, "连接状态:", connected)
        }

        function onConnectionStateChanged() {
            console.log("✅ [MQTTControlPage] 连接状态变化")
        }

        function onLastErrorChanged() {
            console.log("⚠️ [MQTTControlPage] 错误:", mqttController.lastError)
        }
    }

    // ========== 函数 ==========
    function getCurrentTab() {
        if (!mqttConfigPanel.item) {
            return null
        }
        return mqttConfigPanel.item.getCurrentTabItem()
    }

    function getParamFieldCount() {
        if (!mqttConfigPanel.item) {
            return 0
        }
        var currentTab = mqttConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            return 0
        }
        if (typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }
        // 默认参数数量
        switch(root.focusTabIndex) {
        case 0:  // 连接配置（包括连接/断开按钮）
            return 11
        case 1:  // 订阅主题
            return 4
        case 2:  // 发布消息
            return 6
        case 3:  // 数据监控
            return 5
        default:
            return 0
        }
    }

    function triggerParamInput(index) {
        console.log("✅ [MQTTControlPage] triggerParamInput - 参数索引:", index)
        if (!mqttConfigPanel.item) {
            return
        }
        var currentTab = mqttConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            return
        }
        if (typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(index)
        }
    }

    function handleEnterKey() {
        console.log("✅ [MQTTControlPage] 处理回车键 - 当前焦点区域:", focusSubArea)

        if (focusSubArea === 0) {
            console.log("✅ [MQTTControlPage] 列表区域 - 切换模块:", focusItemIndex)
            currentModuleIndex = focusItemIndex
            return true
        }

        if (focusSubArea === 1) {
            console.log("✅ [MQTTControlPage] Tab 栏区域 - 切换 Tab:", focusTabIndex)
            if (mqttConfigPanel.item) {
                mqttConfigPanel.item.currentTabIndex = focusTabIndex
            }
            return true
        }

        if (focusSubArea === 2) {
            console.log("✅ [MQTTControlPage] 参数区域 - 触发参数输入:", focusParamIndex)
            triggerParamInput(focusParamIndex)
            return true
        }

        return false
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 移除旧的updateModuleStatus函数，使用控制器的modules属性

    // ========== 定时器 ==========
    Timer {
        id: resetFlagTimer
        interval: 100
        repeat: false
        onTriggered: {
            root.isReturningToCategory = false
        }
    }

    // ========== 监听器 ==========
    onActiveFocusChanged: {
        if (activeFocus) {
            keysEnabled = true
        }
    }

    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < mqttModules.length) {
            console.log("✅ [MQTTControlPage] focusItemIndex 变化:", focusItemIndex)
            currentModuleIndex = focusItemIndex
        }
    }

    onFocusSubAreaChanged: {
        console.log("🔍 [MQTTControlPage] focusSubArea 变化:", focusSubArea)
    }

    onCurrentModuleIndexChanged: {
        console.log("✅ [MQTTControlPage] currentModuleIndex 变化:", currentModuleIndex)
        // ✅ 2026-02-08 [Phase 7.43.11]: 同步到控制器
        if (mqttController) {
            mqttController.currentModuleIndex = currentModuleIndex
        }
    }

    // ========== NavigationManager ==========
    DeviceInfo.NavigationManager {
        id: navigationManager

        Component.onCompleted: {
            currentArea = areaMotorList
            motorListIndex = 0
            tabIndex = 0
            paramIndex = 0
            buttonIndex = 0
            skipTabArea = false
            skipButtonArea = true  // ✅ 跳过按钮区域（MQTT页面没有底部按钮）
            lastMotorIndex = 7  // 8个模块 (0-7)
            lastTabIndex = 4    // 5个Tab (0-4)  // ✅ 2026-02-09 [Phase 7.44.7]: 更新为5个Tab

            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })

            root.currentModuleIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        onMotorListIndexChanged: {
            root.currentModuleIndex = motorListIndex
            root.focusItemIndex = motorListIndex
        }

        onTabIndexChanged: {
            root.focusTabIndex = tabIndex
            if (mqttConfigPanel.item) {
                mqttConfigPanel.item.currentTabIndex = tabIndex
            }
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })
        }

        onParamIndexChanged: {
            root.focusParamIndex = paramIndex
        }

        onButtonIndexChanged: {
            root.focusButtonIndex = buttonIndex
        }

        onAreaChanged: function(newArea) {
            switch(newArea) {
            case areaMotorList:
                root.focusSubArea = 0
                root.focusItemIndex = motorListIndex
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaTabBar:
                root.focusSubArea = 1
                root.focusTabIndex = tabIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 2
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                // ✅ MQTT页面没有按钮区域，跳过
                break
            }
        }

        onReturnToCategory: {
            root.isReturningToCategory = true
            root.keysEnabled = false
            root.requestReturnToCategory()
            resetFlagTimer.start()
        }
    }

    // ========== 键盘事件 ==========
    Keys.onUpPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    Keys.onDownPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        navigationManager.handleDirectionKey("Down")
        event.accepted = true
    }

    Keys.onLeftPressed: function(event) {
        if (isReturningToCategory) {
            event.accepted = true
            return
        }
        if (navigationManager.currentArea === navigationManager.areaMotorList) {
            root.isReturningToCategory = true
            root.requestReturnToCategory()
            resetFlagTimer.start()
            event.accepted = true
        } else {
            navigationManager.handleDirectionKey("Left")
            event.accepted = true
        }
    }

    Keys.onRightPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        navigationManager.handleDirectionKey("Right")
        event.accepted = true
    }

    Keys.onReturnPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        handleEnterKey()
        event.accepted = true
    }

    // ========== 组件加载 ==========
    Component.onCompleted: {
        console.log("✅ [MQTTControlPage] Component.onCompleted")
        focusSubArea = 0
        focusItemIndex = 0
    }

    // ========== 主布局 ==========
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧：模块列表
        Loader {
            id: mqttListPanel
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            source: "MQTTListPanel.qml"

            onLoaded: {
                console.log("✅ [MQTTControlPage] MQTTListPanel 加载成功")
                item.mqttModules = Qt.binding(function() { return root.mqttModules })
                item.currentModuleIndex = Qt.binding(function() { return root.currentModuleIndex })
                item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })

                item.moduleSelected.connect(function(index) {
                    root.currentModuleIndex = index
                    root.focusItemIndex = index
                    root.focusSubArea = 0
                    root.moduleSelected(index)
                })
            }
        }

        // 分隔线
        Rectangle {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            color: "#3d4556"
        }

        // 右侧：MQTT 配置区域
        Loader {
            id: mqttConfigPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: "MQTTConfigPanel.qml"

            onLoaded: {
                console.log("✅ [MQTTControlPage] MQTTConfigPanel 加载成功")
                item.currentModule = Qt.binding(function() { return root.currentModule })
                item.currentModuleIndex = Qt.binding(function() { return root.currentModuleIndex })  // ✅ 2026-02-09 [Phase 7.44.8]: 传递currentModuleIndex
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.focusTabIndex = Qt.binding(function() { return root.focusTabIndex })
                item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })

                item.requestFocusParamIndex.connect(function(paramIndex) {
                    root.focusParamIndex = paramIndex
                    navigationManager.paramIndex = paramIndex
                })

                item.onCurrentTabIndexChanged.connect(function() {
                    navigationManager.tabIndex = item.currentTabIndex
                })
            }
        }
    }
}
