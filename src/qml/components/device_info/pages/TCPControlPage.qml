// TCPControlPage.qml
// TCP 控制主页面
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"
    focus: true

    // ========== 公开属性 ==========
    property int currentPortIndex: 0     // 当前选中的端口索引 (0-7)
    property int focusItemIndex: -1      // 导航焦点索引
    property int focusSubArea: 0         // 焦点子区域 (0:列表 1:Tab栏 2:参数 3:按钮)
    property int focusTabIndex: -1       // Tab 焦点索引
    property int focusParamIndex: 0      // 参数焦点索引
    property int focusButtonIndex: 0     // 按钮焦点索引

    // 导航控制标志
    property bool isReturningToCategory: false
    property bool keysEnabled: true

    // 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // 暴露 tcpConfigPanel 供外部访问
    property alias tcpConfigPanel: tcpConfigPanel

    // Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ========== 信号 ==========
    signal requestReturnToCategory()
    signal portSelected(int index)

    // ========== TCP 端口数据 ==========
    property var tcpPorts: [
        { name: "端口1", port: 502, status: false },
        { name: "端口2", port: 503, status: false },
        { name: "端口3", port: 504, status: false },
        { name: "端口4", port: 505, status: false },
        { name: "端口5", port: 506, status: false },
        { name: "端口6", port: 507, status: false },
        { name: "端口7", port: 508, status: false },
        { name: "端口8", port: 509, status: false }
    ]

    // ========== 当前端口信息 ==========
    property var currentPort: tcpPorts[currentPortIndex]

    // ========== 函数 ==========
    function getCurrentTab() {
        if (!tcpConfigPanel.item) {
            return null
        }
        return tcpConfigPanel.item.getCurrentTabItem()
    }

    function getParamFieldCount() {
        if (!tcpConfigPanel.item) {
            return 0
        }
        var currentTab = tcpConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            return 0
        }
        if (typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }
        // 默认参数数量
        switch(root.focusTabIndex) {
        case 0:  // Modbus主站
            return 9
        case 1:  // Modbus从站
            return 8
        // 旧: case 2 S7主站(11), case 3 S7从站(9)  // 2026-04-10 [Phase 7.48.88.105]: S7已分离
        default:
            return 0
        }
    }

    function triggerParamInput(index) {
        console.log("✅ [TCPControlPage] triggerParamInput - 参数索引:", index)
        if (!tcpConfigPanel.item) {
            return
        }
        var currentTab = tcpConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            return
        }
        if (typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(index)
        }
    }

    // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图模式下，方向键委托给Tab处理（类别切换+滚动）
    // ✅ 2026-04-08 [Phase 7.48.88.95]: 添加调试日志，修复viewMode检查
    function tryDataViewNavigation(direction) {
        console.log("🔍 [tryDataViewNavigation]", direction, "focusSubArea:", focusSubArea, "focusParamIndex:", focusParamIndex)
        if (focusSubArea !== 2 || focusParamIndex < 0) {
            console.log("🔍 [tryDataViewNavigation] SKIP: focusSubArea !== 2 || focusParamIndex < 0")
            return false
        }
        if (!tcpConfigPanel.item) {
            console.log("🔍 [tryDataViewNavigation] SKIP: no tcpConfigPanel.item")
            return false
        }
        var currentTab = tcpConfigPanel.item.getCurrentTabItem()
        if (!currentTab) {
            console.log("🔍 [tryDataViewNavigation] SKIP: no currentTab")
            return false
        }
        if (typeof currentTab.handleDataViewKey !== "function") {
            console.log("🔍 [tryDataViewNavigation] SKIP: handleDataViewKey not a function")
            return false
        }
        console.log("🔍 [tryDataViewNavigation] currentTab.viewMode:", currentTab.viewMode)
        if (currentTab.viewMode !== 1) {
            console.log("🔍 [tryDataViewNavigation] SKIP: viewMode !== 1")
            return false
        }
        var result = currentTab.handleDataViewKey(direction)
        console.log("🔍 [tryDataViewNavigation] handleDataViewKey result:", result)
        return result
    }

    function handleEnterKey() {
        console.log("✅ [TCPControlPage] 处理回车键 - 当前焦点区域:", focusSubArea)

        if (focusSubArea === 0) {
            console.log("✅ [TCPControlPage] 列表区域 - 切换端口:", focusItemIndex)
            currentPortIndex = focusItemIndex
            return true
        }

        if (focusSubArea === 1) {
            // 旧：console.log("✅ [TCPControlPage] Tab 栏区域 - 切换 Tab:", focusTabIndex)  // 2026-04-08 [Phase 7.48.88.91] Tab已通过左右键切换，Enter改为切换视图
            // 旧：if (tcpConfigPanel.item) {  // 2026-04-08 [Phase 7.48.88.91]
            // 旧：    tcpConfigPanel.item.currentTabIndex = focusTabIndex  // 2026-04-08 [Phase 7.48.88.91]
            // 旧：}  // 2026-04-08 [Phase 7.48.88.91]
            // ✅ 2026-04-08 [Phase 7.48.88.91]: Tab栏按Enter键 → 切换参数配置/映射表视图
            console.log("✅ [TCPControlPage] Tab 栏区域 - 切换视图模式")
            if (tcpConfigPanel.item) {
                var currentTab = tcpConfigPanel.item.getCurrentTabItem()
                if (currentTab && typeof currentTab.toggleViewMode === "function") {
                    currentTab.toggleViewMode()
                }
            }
            return true
        }

        if (focusSubArea === 2) {
            // ✅ 2026-04-08 [Phase 7.48.88.92]: 视图切换行按Enter键切换视图
            if (focusParamIndex === -1) {
                console.log("✅ [TCPControlPage] 视图切换行 - 切换视图模式")
                if (tcpConfigPanel.item) {
                    var currentTabView = tcpConfigPanel.item.getCurrentTabItem()
                    if (currentTabView && typeof currentTabView.toggleViewMode === "function") {
                        currentTabView.toggleViewMode()
                    }
                }
                return true
            }
            // ✅ 2026-02-08 [Phase 7.42.15]: 参数区域按回车键时触发虚拟键盘
            console.log("✅ [TCPControlPage] 参数区域 - 触发参数输入:", focusParamIndex)
            triggerParamInput(focusParamIndex)
            return true
        }

        if (focusSubArea === 3) {
            console.log("✅ [TCPControlPage] 按钮区域 - 执行按钮点击:", focusButtonIndex)
            return triggerButton(focusButtonIndex)
        }

        return false
    }

    function triggerButton(buttonIndex) {
        console.log("✅ [TCPControlPage] triggerButton - 按钮索引:", buttonIndex)
        switch(buttonIndex) {
        case 0:  // 打开连接
            // 旧：console.log("✅ [TCPControlPage] 执行打开连接")  // 2026-04-07 [Phase 7.48.88.86] 实现实际连接逻辑
            // 旧：// TODO: 实现打开连接逻辑  // 2026-04-07 [Phase 7.48.88.86] 已实现
            console.log("✅ [TCPControlPage] 执行打开连接 - 端口:", currentPortIndex)
            if (typeof tcpDataAdapter !== "undefined") {
                var result = tcpDataAdapter.startPortServices(currentPortIndex)
                console.log("✅ [TCPControlPage] 启动结果:", result)
            }
            return true
        case 1:  // 关闭连接
            // 旧：console.log("✅ [TCPControlPage] 执行关闭连接")  // 2026-04-07 [Phase 7.48.88.86] 实现实际断开逻辑
            // 旧：// TODO: 实现关闭连接逻辑  // 2026-04-07 [Phase 7.48.88.86] 已实现
            console.log("✅ [TCPControlPage] 执行关闭连接 - 端口:", currentPortIndex)
            if (typeof tcpDataAdapter !== "undefined") {
                tcpDataAdapter.stopPortServices(currentPortIndex)
            }
            return true
        // 旧：case 2(保存)/3(删除)/4(重置)  // 2026-03-18 [Phase 7.48.55] 删除按钮，不需要
        default:
            return false
        }
    }

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
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < tcpPorts.length) {
            console.log("✅ [TCPControlPage] focusItemIndex 变化:", focusItemIndex)
            currentPortIndex = focusItemIndex
        }
    }

    onFocusSubAreaChanged: {
        console.log("🔍 [TCPControlPage] focusSubArea 变化:", focusSubArea)
    }

    onCurrentPortIndexChanged: {
        console.log("✅ [TCPControlPage] currentPortIndex 变化:", currentPortIndex)
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
            lastMotorIndex = 7  // 8个端口 (0-7)
            // 旧: lastTabIndex = 3    // 4个Tab (0-3)
            // ✅ 2026-04-10 [Phase 7.48.88.105]: S7已分离到独立的S7ControlPage
            lastTabIndex = 1    // 2个Tab (0-1): Modbus主站, Modbus从站
            hasViewSwitchRow = true  // ✅ 2026-04-08 [Phase 7.48.88.92]: TCP页面有视图切换行

            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })

            root.currentPortIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        onMotorListIndexChanged: {
            root.currentPortIndex = motorListIndex
            root.focusItemIndex = motorListIndex
        }

        onTabIndexChanged: {
            root.focusTabIndex = tabIndex
            if (tcpConfigPanel.item) {
                tcpConfigPanel.item.currentTabIndex = tabIndex
            }
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })
        }

        onParamIndexChanged: {
            root.focusParamIndex = paramIndex
            // ✅ 2026-02-08 [Phase 7.42.15]: 移除自动触发虚拟键盘
            // 虚拟键盘应该在按回车键时才弹出，而不是焦点变化时
            // root.triggerParamInput(paramIndex)  // ❌ 移除
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
                // ✅ 2026-02-08 [Phase 7.42.15]: 移除自动触发虚拟键盘
                // 虚拟键盘应该在按回车键时才弹出，而不是进入参数区域时
                // root.triggerParamInput(paramIndex)  // ❌ 移除
                break
            case areaButtons:
                root.focusSubArea = 3
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        onReturnToCategory: {
            root.isReturningToCategory = true
            root.keysEnabled = false
            root.requestReturnToCategory()
            resetFlagTimer.start()
        }

        // ✅ 2026-04-08 [Phase 7.48.88.90]: Tab区域按上键 → 切换当前Tab的参数配置/映射表视图
        onToggleViewRequested: {
            if (tcpConfigPanel.item) {
                var currentTab = tcpConfigPanel.item.getCurrentTabItem()
                if (currentTab && typeof currentTab.toggleViewMode === "function") {
                    currentTab.toggleViewMode()
                }
            }
        }
    }

    // ========== 键盘事件 ==========
    Keys.onUpPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图模式下优先让Tab处理
        if (!tryDataViewNavigation("Up"))
            navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    Keys.onDownPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图模式下优先让Tab处理
        if (!tryDataViewNavigation("Down"))
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
            // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图模式下优先让Tab处理
            if (!tryDataViewNavigation("Left"))
                navigationManager.handleDirectionKey("Left")
            event.accepted = true
        }
    }

    Keys.onRightPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图模式下优先让Tab处理
        if (!tryDataViewNavigation("Right"))
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
        console.log("✅ [TCPControlPage] Component.onCompleted")
        focusSubArea = 0
        focusItemIndex = 0
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 上部：列表和配置区域
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // 左侧：端口列表
            Loader {
                id: tcpListPanel
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                source: "TCPListPanel.qml"

                onLoaded: {
                    console.log("✅ [TCPControlPage] TCPListPanel 加载成功")
                    item.tcpPorts = Qt.binding(function() { return root.tcpPorts })
                    item.currentPortIndex = Qt.binding(function() { return root.currentPortIndex })
                    item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })

                    item.portSelected.connect(function(index) {
                        root.currentPortIndex = index
                        root.focusItemIndex = index
                        root.focusSubArea = 0
                        root.portSelected(index)
                    })
                }
            }

            // 分隔线
            Rectangle {
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                color: "#3d4556"
            }

            // 右侧：TCP 配置区域
            Loader {
                id: tcpConfigPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "TCPConfigPanel.qml"

                onLoaded: {
                    console.log("✅ [TCPControlPage] TCPConfigPanel 加载成功")
                    item.currentPort = Qt.binding(function() { return root.currentPort })
                    item.currentPortIndex = Qt.binding(function() { return root.currentPortIndex })  // ✅ 2026-04-07 [Phase 7.48.88.84]
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

        // 底部：按钮区域
        // ✅ 2026-04-09: 问题5修复——合并为单个切换按钮，减少占用空间
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#1a1f2e"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 2
                color: "#00d4ff"
                opacity: 0.3
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // 单个切换按钮：根据端口运行状态显示不同文字和颜色
                Button {
                    id: toggleConnectionBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    property bool portRunning: {
                        if (typeof tcpDataAdapter !== "undefined") {
                            return tcpDataAdapter.isPortRunning(root.currentPortIndex)
                        }
                        return false
                    }

                    text: portRunning ? "关闭连接" : "打开连接"

                    background: Rectangle {
                        color: {
                            var hasFocus = root.focusSubArea === 3 && root.focusButtonIndex === 0
                            if (toggleConnectionBtn.portRunning) {
                                return hasFocus ? "#e74c3c" : "#c0392b"  // 运行中 → 红色（关闭）
                            } else {
                                return hasFocus ? "#2ecc71" : "#27ae60"  // 未运行 → 绿色（打开）
                            }
                        }
                        radius: 4
                        border.width: root.focusSubArea === 3 && root.focusButtonIndex === 0 ? 5 : 0
                        border.color: "#2196F3"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 16
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (toggleConnectionBtn.portRunning) {
                            triggerButton(1)  // 关闭
                        } else {
                            triggerButton(0)  // 打开
                        }
                    }

                    // 定时刷新端口状态
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            toggleConnectionBtn.portRunning = Qt.binding(function() {
                                if (typeof tcpDataAdapter !== "undefined") {
                                    return tcpDataAdapter.isPortRunning(root.currentPortIndex)
                                }
                                return false
                            })
                        }
                    }
                }
            }
        }
    }
}
