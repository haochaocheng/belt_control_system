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
    // 旧: property int focusSubArea: 0  // (0:Tab栏 1:参数 2:按钮)
    // ✅ 2026-04-10 [Phase 7.48.88.107]: 焦点子区域映射改为与TCPControlPage一致，确保S7MasterTab/S7SlaveTab焦点指示器正常
    property int focusSubArea: 0         // 焦点子区域 (0:列表[S7不使用] 1:Tab栏 2:参数 3:按钮)
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
        // 旧: if (focusSubArea !== 1 || focusParamIndex < 0) return false
        // ✅ 2026-04-10 [Phase 7.48.88.107]: focusSubArea映射修正——参数区域现在是2
        if (focusSubArea !== 2 || focusParamIndex < 0) return false
        var currentTab = getCurrentTab()
        if (!currentTab) return false
        if (typeof currentTab.handleDataViewKey !== "function") return false
        if (currentTab.viewMode !== 1) return false
        return currentTab.handleDataViewKey(direction)
    }

    function handleEnterKey() {
        // 旧: focusSubArea === 0 表示Tab栏, 1 表示参数, 2 表示按钮
        // ✅ 2026-04-10 [Phase 7.48.88.107]: focusSubArea映射修正——与TCPControlPage一致
        if (focusSubArea === 1) {
            // Tab栏按Enter → 切换视图模式
            var tabForView = getCurrentTab()
            if (tabForView && typeof tabForView.toggleViewMode === "function") {
                tabForView.toggleViewMode()
            }
            return true
        }

        if (focusSubArea === 2) {
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

        if (focusSubArea === 3) {
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

            // 旧: root.focusSubArea = 0  // 0=Tab栏
            // ✅ 2026-04-10 [Phase 7.48.88.107]: 初始focusSubArea改为1（Tab栏）
            root.focusSubArea = 1
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

        // 旧: areaTabBar→0, areaParams→1, areaButtons→2
        // ✅ 2026-04-10 [Phase 7.48.88.107]: focusSubArea映射修正——与TCPControlPage一致 (1/2/3)
        onAreaChanged: function(newArea) {
            switch(newArea) {
            case areaTabBar:
                root.focusSubArea = 1
                root.focusTabIndex = tabIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 2
                root.focusParamIndex = paramIndex
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 3
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
        // 旧: focusSubArea = 0
        // ✅ 2026-04-10 [Phase 7.48.88.107]: 初始focusSubArea改为1（Tab栏）
        focusSubArea = 1
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
                // 旧: color: "#1a1f2e", 文字 "#00d4ff"
                // ✅ 2026-04-10 [Phase 7.48.88.106]: 问题1——标题栏样式改为与TCP控制一致
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        // 旧: source: "../../images/059.png"  // 路径错误
                        // ✅ 2026-04-10 [Phase 7.48.88.107]: 修正图片路径——pages/下的QML用../images/
                        source: "../images/059.png"
                        fillMode: Image.Stretch
                        z: -1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "S7 控制"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }
                }

                // Tab栏
                // 旧: color: "#141824", RowLayout + dvList.png/dvList2.png, 文字 "#00d4ff"/"#8899aa"
                // ✅ 2026-04-10 [Phase 7.48.88.106]: 问题1——Tab样式改为与Modbus Tab一致（DJHeadbutton图片+蓝色调）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#252b3d"
                    border.color: "#3d4556"
                    border.width: 1

                    Row {
                        spacing: 0
                        height: parent.height
                        width: childrenRect.width

                        Repeater {
                            model: root.tabModel

                            Rectangle {
                                width: 143
                                height: 50
                                color: "transparent"

                                // 焦点指示器
                                // 旧: focusSubArea === 0  // ✅ 2026-04-10 [Phase 7.48.88.107]: 改为1
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusTabIndex === index)
                                                  ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
                                    radius: 4
                                    z: 11
                                }

                                // 背景图片
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.Stretch
                                    z: -1
                                    // 旧: source使用../../images/路径（错误）
                                    // ✅ 2026-04-10 [Phase 7.48.88.107]: 修正图片路径
                                    source: root.currentTabIndex === index
                                            ? "../images/DJHeadbutton2.png"
                                            : "../images/DJHeadbutton1.png"
                                }

                                // 底部激活指示条
                                Rectangle {
                                    visible: root.currentTabIndex === index
                                    width: parent.width
                                    height: 3
                                    color: "#2196F3"
                                    anchors.bottom: parent.bottom
                                }

                                Text {
                                    text: modelData
                                    anchors.centerIn: parent
                                    font.pixelSize: 14
                                    font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
                                    color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
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
                // 旧: color: "#0d1117", RowLayout, 闪烁动画, 文字颜色"#666"/"#556"
                // ✅ 2026-04-10 [Phase 7.48.88.106]: 问题1——连接状态栏样式改为与TCP控制一致
                Rectangle {
                    id: connectionStatusBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: "#1a2033"
                    border.color: "#3d4556"
                    border.width: 1

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

                    Component.onCompleted: connectionStatusBar.refreshStatus()

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 12

                        // 状态指示灯
                        Rectangle {
                            id: s7StatusDot
                            width: 10
                            height: 10
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: connectionStatusBar.hasConnected ? "#4CAF50" :
                                   connectionStatusBar.s7Running ? "#FF9800" : "#757575"
                        }

                        // 状态文字
                        Text {
                            id: s7StatusText
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 13
                            color: connectionStatusBar.hasConnected ? "#4CAF50" :
                                   connectionStatusBar.s7Running ? "#FF9800" : "#9E9E9E"
                            text: connectionStatusBar.statusText
                        }

                        // 右侧：端口信息
                        Item {
                            width: parent.width - s7StatusDot.width - s7StatusText.width - 36
                            height: parent.height

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 12
                                color: "#757575"
                                text: "Port 102"
                            }
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
        // 旧: color: "#1a1f2e", 分隔线 "#00d4ff"
        // ✅ 2026-04-10 [Phase 7.48.88.106]: 问题1——底部区域样式改为与TCP控制一致
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#252b3d"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#3d4556"
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
                            // 旧: focusSubArea === 2  // ✅ 2026-04-10 [Phase 7.48.88.107]: 改为3
                            var hasFocus = root.focusSubArea === 3 && root.focusButtonIndex === 0
                            if (toggleS7Btn.s7Running) {
                                return hasFocus ? "#e74c3c" : "#c0392b"
                            } else {
                                return hasFocus ? "#2ecc71" : "#27ae60"
                            }
                        }
                        radius: 4
                        // 旧: focusSubArea === 2  // ✅ 2026-04-10 [Phase 7.48.88.107]: 改为3
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
