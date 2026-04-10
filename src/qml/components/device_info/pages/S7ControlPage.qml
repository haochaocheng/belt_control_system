// S7ControlPage.qml
// S7 控制独立页面（从TCP控制中分离）
// 创建日期: 2026-04-10
// ✅ 2026-04-10 [Phase 7.48.88.105]: S7只能使用端口102，独立为单独的控制栏目

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"
    focus: true

    // ========== 公开属性 ==========
    property int focusSubArea: 0         // 焦点子区域 (0:Tab栏 1:参数 2:按钮)
    property int focusTabIndex: 0        // Tab 焦点索引 (0:S7主站 1:S7从站)
    property int focusParamIndex: 0      // 参数焦点索引
    property int focusButtonIndex: 0     // 按钮焦点索引
    property int focusItemIndex: -1      // 兼容DeviceSettingsDialog的焦点索引

    // 导航控制标志
    property bool isReturningToCategory: false
    property bool keysEnabled: true

    // 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // S7固定使用portIndex=0
    readonly property int portIndex: 0

    // ========== 信号 ==========
    signal requestReturnToCategory()

    // ========== Tab模型 ==========
    property var tabModel: ["S7主站", "S7从站"]
    property int currentTabIndex: 0

    // ========== 函数 ==========
    function getCurrentTab() {
        switch(currentTabIndex) {
        case 0: return s7MasterTabLoader.item
        case 1: return s7SlaveTabLoader.item
        default: return null
        }
    }

    function getParamFieldCount() {
        var currentTab = getCurrentTab()
        if (currentTab && typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }
        // 默认
        return currentTabIndex === 0 ? 11 : 9
    }

    function triggerParamInput(index) {
        var currentTab = getCurrentTab()
        if (currentTab && typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(index)
        }
    }

    function tryDataViewNavigation(direction) {
        if (focusSubArea !== 1 || focusParamIndex < 0) return false
        var currentTab = getCurrentTab()
        if (!currentTab) return false
        if (typeof currentTab.handleDataViewKey !== "function") return false
        if (currentTab.viewMode !== 1) return false
        return currentTab.handleDataViewKey(direction)
    }

    function handleEnterKey() {
        if (focusSubArea === 0) {
            // Tab栏按Enter → 切换视图模式
            var tabForView = getCurrentTab()
            if (tabForView && typeof tabForView.toggleViewMode === "function") {
                tabForView.toggleViewMode()
            }
            return true
        }

        if (focusSubArea === 1) {
            // 视图切换行按Enter
            if (focusParamIndex === -1) {
                var tabForSwitch = getCurrentTab()
                if (tabForSwitch && typeof tabForSwitch.toggleViewMode === "function") {
                    tabForSwitch.toggleViewMode()
                }
                return true
            }
            // 参数区域按回车 → 虚拟键盘
            triggerParamInput(focusParamIndex)
            return true
        }

        if (focusSubArea === 2) {
            return triggerButton(focusButtonIndex)
        }

        return false
    }

    function triggerButton(buttonIndex) {
        if (buttonIndex === 0) {
            // 切换S7连接
            if (typeof tcpDataAdapter !== "undefined") {
                if (tcpDataAdapter.isS7Running()) {
                    tcpDataAdapter.stopS7Server()
                    console.log("✅ [S7ControlPage] 停止S7服务器")
                } else {
                    var result = tcpDataAdapter.startS7Server()
                    console.log("✅ [S7ControlPage] 启动S7服务器, 结果:", result)
                }
            }
            return true
        }
        return false
    }

    // ========== 定时器 ==========
    Timer {
        id: resetFlagTimer
        interval: 100
        repeat: false
        onTriggered: root.isReturningToCategory = false
    }

    // ========== 监听器 ==========
    onActiveFocusChanged: {
        if (activeFocus) keysEnabled = true
    }

    // ========== NavigationManager ==========
    DeviceInfo.NavigationManager {
        id: navigationManager

        Component.onCompleted: {
            skipMotorList = true   // S7无端口列表
            skipTabArea = false
            skipButtonArea = false
            lastTabIndex = 1      // 2个Tab (0-1)
            hasViewSwitchRow = true

            // skipMotorList=true时，初始区域为TabBar
            currentArea = areaTabBar
            tabIndex = 0
            paramIndex = 0
            buttonIndex = 0

            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })

            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        onTabIndexChanged: {
            root.focusTabIndex = tabIndex
            root.currentTabIndex = tabIndex
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
            case areaTabBar:
                root.focusSubArea = 0
                root.focusTabIndex = tabIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 1
                root.focusParamIndex = paramIndex
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 2
                root.focusButtonIndex = buttonIndex
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

        onToggleViewRequested: {
            var currentTab = root.getCurrentTab()
            if (currentTab && typeof currentTab.toggleViewMode === "function") {
                currentTab.toggleViewMode()
            }
        }
    }

    // ========== 键盘事件 ==========
    Keys.onUpPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        if (!tryDataViewNavigation("Up"))
            navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    Keys.onDownPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        if (!tryDataViewNavigation("Down"))
            navigationManager.handleDirectionKey("Down")
        event.accepted = true
    }

    Keys.onLeftPressed: function(event) {
        if (isReturningToCategory) { event.accepted = true; return }
        // S7无端口列表，Left在Tab栏第一个Tab时由NavigationManager处理（returnToCategory）
        if (!tryDataViewNavigation("Left"))
            navigationManager.handleDirectionKey("Left")
        event.accepted = true
    }

    Keys.onRightPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        if (!tryDataViewNavigation("Right"))
            navigationManager.handleDirectionKey("Right")
        event.accepted = true
    }

    Keys.onReturnPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        handleEnterKey()
        event.accepted = true
    }

    Component.onCompleted: {
        console.log("✅ [S7ControlPage] 初始化完成")
        focusSubArea = 0
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 内容区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#1a1f2e"

                    Text {
                        anchors.centerIn: parent
                        text: "S7 控制"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#00d4ff"
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: "#00d4ff"
                        opacity: 0.3
                    }
                }

                // Tab栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#141824"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 4

                        Repeater {
                            model: root.tabModel

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"

                                // 焦点指示器
                                border.color: (root.focusSubArea === 0 && root.focusTabIndex === index) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 0 && root.focusTabIndex === index) ? 3 : 0
                                radius: 4

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.Stretch
                                    source: root.currentTabIndex === index ? "../../images/dvList2.png" : "../../images/dvList.png"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 14
                                    font.bold: root.currentTabIndex === index
                                    color: root.currentTabIndex === index ? "#00d4ff" : "#8899aa"
                                }

                                // 底部激活条
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 3
                                    color: "#00d4ff"
                                    visible: root.currentTabIndex === index
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.currentTabIndex = index
                                        root.focusTabIndex = index
                                        navigationManager.tabIndex = index
                                    }
                                }
                            }
                        }
                    }
                }

                // 连接状态栏
                Rectangle {
                    id: connectionStatusBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: "#0d1117"

                    property bool s7Running: false
                    property bool hasConnected: false
                    property string statusText: "S7:已停止"

                    function refreshStatus() {
                        if (typeof tcpDataAdapter !== "undefined") {
                            s7Running = tcpDataAdapter.isS7Running()
                            statusText = tcpDataAdapter.getS7StatusText()
                            hasConnected = statusText.indexOf("已连接") >= 0
                        }
                    }

                    Timer {
                        interval: 2000
                        running: true
                        repeat: true
                        onTriggered: connectionStatusBar.refreshStatus()
                    }

                    Component.onCompleted: refreshStatus()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 10

                        // 状态指示灯
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: connectionStatusBar.hasConnected ? "#4CAF50" :
                                   connectionStatusBar.s7Running ? "#FF9800" : "#757575"

                            SequentialAnimation on opacity {
                                running: connectionStatusBar.s7Running && !connectionStatusBar.hasConnected
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                            }
                        }

                        // 状态文字
                        Text {
                            text: connectionStatusBar.statusText
                            font.pixelSize: 13
                            color: connectionStatusBar.hasConnected ? "#4CAF50" :
                                   connectionStatusBar.s7Running ? "#FF9800" : "#666"
                        }

                        Item { Layout.fillWidth: true }

                        // 端口信息
                        Text {
                            text: "Port 102"
                            font.pixelSize: 12
                            color: "#556"
                        }
                    }
                }

                // Tab内容区域
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTabIndex

                    // Tab 0: S7主站
                    Loader {
                        id: s7MasterTabLoader
                        source: "S7MasterTab.qml"

                        onLoaded: {
                            console.log("✅ [S7ControlPage] S7MasterTab 加载成功")
                            item.currentPort = null
                            item.portIndex = root.portIndex
                            item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                            item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                            item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        }
                    }

                    // Tab 1: S7从站
                    Loader {
                        id: s7SlaveTabLoader
                        source: "S7SlaveTab.qml"

                        onLoaded: {
                            console.log("✅ [S7ControlPage] S7SlaveTab 加载成功")
                            item.currentPort = null
                            item.portIndex = root.portIndex
                            item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                            item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                            item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                        }
                    }
                }
            }
        }

        // 底部：按钮区域
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

                Button {
                    id: toggleS7Btn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    property bool s7Running: {
                        if (typeof tcpDataAdapter !== "undefined") {
                            return tcpDataAdapter.isS7Running()
                        }
                        return false
                    }

                    text: s7Running ? "停止S7" : "启动S7"

                    background: Rectangle {
                        color: {
                            var hasFocus = root.focusSubArea === 2 && root.focusButtonIndex === 0
                            if (toggleS7Btn.s7Running) {
                                return hasFocus ? "#e74c3c" : "#c0392b"
                            } else {
                                return hasFocus ? "#2ecc71" : "#27ae60"
                            }
                        }
                        radius: 4
                        border.width: root.focusSubArea === 2 && root.focusButtonIndex === 0 ? 5 : 0
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

                    onClicked: triggerButton(0)

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            toggleS7Btn.s7Running = Qt.binding(function() {
                                if (typeof tcpDataAdapter !== "undefined") {
                                    return tcpDataAdapter.isS7Running()
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
