// CentralControlPage.qml
// 集控管理主页面
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 新建集控管理页面——支持多协议混合集控

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"
    focus: true

    // ========== 公开属性 ==========
    property int focusSubArea: 0         // 焦点子区域 (0:列表[集控不使用] 1:Tab栏 2:参数 3:按钮)
    property int focusTabIndex: 0        // Tab 焦点索引 (0:集控角色 1:分站管理 2:MQTT集控配置)
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

    // ✅ 2026-04-14 [Phase 7.48.88.135]: 响应式 MQTT模块7 连接状态
    // isModuleConnected() 是 Q_INVOKABLE 函数调用，绑定不会自动更新
    // 改用本地属性 + Connections 监听 connectedChanged 信号
    property bool mqttModule7Connected: false

    Connections {
        target: typeof mqttController !== "undefined" ? mqttController : null
        function onConnectedChanged(moduleIndex, connected) {
            if (moduleIndex === 7) {
                root.mqttModule7Connected = connected
            }
        }
    }

    // ========== 信号 ==========
    signal requestReturnToCategory()

    // ========== Tab模型 ==========
    property var tabModel: ["集控角色", "分站管理", "MQTT集控配置"]
    property int currentTabIndex: 0

    // ========== 函数 ==========
    function getCurrentTab() {
        switch(currentTabIndex) {
        case 0: return centralRoleTabLoader.item
        case 1: return subStationManageTabLoader.item
        case 2: return mqttCentralTabLoader.item
        default: return null
        }
    }

    // ✅ 2026-04-14 [Phase 7.48.88.120]: 供 CustomComboBox.parentDialog 调用
    function handleNavigationKey(key, event) {
        switch(key) {
        case Qt.Key_Up:    navigationManager.handleDirectionKey("Up");    break
        case Qt.Key_Down:  navigationManager.handleDirectionKey("Down");  break
        case Qt.Key_Left:  navigationManager.handleDirectionKey("Left");  break
        case Qt.Key_Right: navigationManager.handleDirectionKey("Right"); break
        }
    }

    function getParamFieldCount() {
        var currentTab = getCurrentTab()
        if (currentTab && typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }
        switch(currentTabIndex) {
        case 0: return 4   // 集控角色: 4个参数
        case 1: return 7   // 分站管理: 最多7个参数（启用+协议+IP+端口+3个协议特定参数）
        case 2: return 8   // MQTT配置: 8个参数
        default: return 4
        }
    }

    function triggerParamInput(index) {
        var currentTab = getCurrentTab()
        if (currentTab && typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(index)
        }
    }

    function handleEnterKey() {
        if (focusSubArea === 1) {
            // Tab栏按Enter无特殊操作（集控没有视图切换）
            return true
        }

        if (focusSubArea === 2) {
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
            // 保存配置
            if (typeof centralControlManager !== "undefined") {
                centralControlManager.saveConfig()
                console.log("✅ [CentralControlPage] 保存集控配置")
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
            skipMotorList = true   // 集控无端口列表
            skipTabArea = false
            skipButtonArea = false
            lastTabIndex = 2      // 3个Tab (0-2)
            hasViewSwitchRow = false
            paramColumns = 2      // ✅ 2026-04-14 [Phase 7.48.88.120]: 2列参数布局

            // skipMotorList=true时，初始区域为TabBar
            currentArea = areaTabBar
            tabIndex = 0
            paramIndex = 0
            buttonIndex = 0

            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })

            root.focusSubArea = 1
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        onTabIndexChanged: {
            root.focusTabIndex = tabIndex
            root.currentTabIndex = tabIndex
            // ✅ 2026-04-14 [Phase 7.48.88.120]: Tab1(分站管理)启用分站列表区域
            if (tabIndex === 1) {
                skipMotorList = false
                lastMotorIndex = 7  // 8个分站 (0-7)
            } else {
                skipMotorList = true
            }
            // ✅ 2026-04-14 [Phase 7.48.88.123]: 切换Tab时确保focusSubArea=1(TabBar)
            root.focusSubArea = 1
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
            })
        }

        onMotorListIndexChanged: {
            // ✅ 2026-04-14 [Phase 7.48.88.120]: 列表索引变化 → 同步分站选中
            if (root.currentTabIndex === 1 && subStationManageTabLoader.item) {
                subStationManageTabLoader.item.currentSlotIndex = motorListIndex
            }
            root.focusItemIndex = motorListIndex
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
                root.focusParamIndex = -1
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                // ✅ 2026-04-14 [Phase 7.48.88.125]: 进入分站列表时直接更新tab的currentSlotIndex
                // ✅ 2026-04-14 [Phase 7.48.88.128]: 不能直接设item.focusSubArea，会破坏Qt.binding
                // root.focusSubArea = 0 已在上面设置，binding会自动同步到tab
                Qt.callLater(function() {
                    if (subStationManageTabLoader.item) {
                        subStationManageTabLoader.item.currentSlotIndex = motorListIndex
                    }
                })
                break
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
    }

    // ========== 键盘事件 ==========
    Keys.onUpPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    Keys.onDownPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        // ✅ 2026-04-14 [Phase 7.48.88.123]: Tab1(分站管理) + TabBar(focusSubArea===1) + Down → 进入分站列表
        // 用 focusSubArea===1 替代 navigationManager.currentArea 比较（更可靠）
        if (currentTabIndex === 1 && focusSubArea === 1) {
            navigationManager.switchToArea(navigationManager.areaMotorList)
            navigationManager.motorListIndex = 0
        } else {
            navigationManager.handleDirectionKey("Down")
        }
        event.accepted = true
    }

    Keys.onLeftPressed: function(event) {
        if (isReturningToCategory) { event.accepted = true; return }
        // ✅ 2026-04-14 [Phase 7.48.88.123]: Tab1 + 参数区首列(focusSubArea===2) + Left → 返回分站列表
        if (currentTabIndex === 1 && focusSubArea === 2
                && navigationManager.paramIndex % navigationManager.paramColumns === 0) {
            navigationManager.switchToArea(navigationManager.areaMotorList)
        } else {
            navigationManager.handleDirectionKey("Left")
        }
        event.accepted = true
    }

    Keys.onRightPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        // ✅ 2026-04-14 [Phase 7.48.88.123]: Tab1 + 分站列表(focusSubArea===0) + Right → 进入参数区
        if (currentTabIndex === 1 && focusSubArea === 0) {
            navigationManager.switchToArea(navigationManager.areaParams)
            navigationManager.paramIndex = 0
        } else {
            navigationManager.handleDirectionKey("Right")
        }
        event.accepted = true
    }

    Keys.onReturnPressed: {
        if (!keysEnabled || isReturningToCategory) { event.accepted = true; return }
        handleEnterKey()
        event.accepted = true
    }

    Component.onCompleted: {
        console.log("✅ [CentralControlPage] 初始化完成")
        focusSubArea = 1
        // ✅ 2026-04-14 [Phase 7.48.88.135]: 初始化时读一次 MQTT模块7 连接状态
        if (typeof mqttController !== "undefined") {
            root.mqttModule7Connected = mqttController.isModuleConnected(7)
        }
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
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: "../images/059.png"
                        fillMode: Image.Stretch
                        z: -1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "集控管理"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }
                }

                // ✅ 2026-04-14 [Phase 7.48.88.132]: 状态栏——角色/MQTT/在线站数
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: "#12192b"
                    border.color: "#2a3550"
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 16

                        // 角色指示
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: {
                                    if (typeof centralControlManager === "undefined") return "#555"
                                    switch(centralControlManager.stationRole) {
                                    case "master": return "#4FC3F7"
                                    case "sub":    return "#A5D6A7"
                                    default:       return "#78909C"
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (typeof centralControlManager === "undefined") return "角色: 独立"
                                    switch(centralControlManager.stationRole) {
                                    case "master": return "角色: 主站"
                                    case "sub":    return "角色: 分站"
                                    default:       return "角色: 独立"
                                    }
                                }
                                color: "#B0BEC5"; font.pixelSize: 12
                            }
                        }

                        // MQTT 连接状态
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: (typeof mqttController !== "undefined" &&
                                        root.mqttModule7Connected) ? "#4CAF50" : "#F44336"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (typeof mqttController === "undefined") return "MQTT: 未知"
                                    var ip = (typeof centralControlManager !== "undefined")
                                             ? centralControlManager.mqttBrokerIP : ""
                                    var connected = root.mqttModule7Connected
                                    return connected ? ("MQTT: " + (ip || "已连接"))
                                                     : ("MQTT: " + (ip ? ip + " 未连接" : "未配置"))
                                }
                                color: (typeof mqttController !== "undefined" &&
                                        root.mqttModule7Connected) ? "#A5D6A7" : "#EF9A9A"
                                font.pixelSize: 12
                            }
                        }

                        // 在线分站数（主站模式）
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: typeof centralControlManager !== "undefined" &&
                                     centralControlManager.isMasterMode
                            text: {
                                if (typeof centralControlManager === "undefined") return ""
                                var slots = centralControlManager.subStations
                                if (!slots) return "在线: 0/0"
                                var enabled = 0, online = 0
                                for (var i = 0; i < slots.length; i++) {
                                    if (slots[i].enabled) enabled++
                                    if (slots[i].isConnected) online++
                                }
                                return "在线: " + online + "/" + enabled + " 站"
                            }
                            color: "#90A4AE"; font.pixelSize: 12
                        }

                        // 分站模式提示
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: typeof centralControlManager !== "undefined" &&
                                     centralControlManager.isSubMode
                            text: "设备ID: " + (typeof centralControlManager !== "undefined"
                                               ? centralControlManager.localDeviceId : "?")
                            color: "#90A4AE"; font.pixelSize: 12
                        }
                    }
                }

                // Tab栏
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
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusTabIndex === index)
                                                  ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
                                    radius: 4
                                    z: 11
                                }

                                Image {
                                    anchors.fill: parent
                                    // ✅ 2026-04-11 [Phase 7.48.88.110.4]: 修正图片名——与S7ControlPage一致
                                    source: root.currentTabIndex === index
                                            ? "../images/DJHeadbutton2.png"
                                            : "../images/DJHeadbutton1.png"
                                    fillMode: Image.Stretch
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 14
                                    color: root.currentTabIndex === index ? "#4FC3F7" : "#8899aa"
                                    font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
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

                // Tab内容区域
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTabIndex

                    // Tab 0: 集控角色
                    Loader {
                        id: centralRoleTabLoader
                        source: "CentralRoleTab.qml"
                        active: root.currentTabIndex === 0

                        onLoaded: {
                            item.virtualKeyboard = root.virtualKeyboard
                            item.parentDialog    = root  // ✅ 2026-04-14: 供ComboBox键盘导航使用
                            item.focusParamIndex = Qt.binding(function() {
                                return root.focusSubArea === 2 ? root.focusParamIndex : -1
                            })
                            item.focusSubArea = Qt.binding(function() {
                                return root.focusSubArea
                            })
                        }
                    }

                    // Tab 1: 分站管理
                    Loader {
                        id: subStationManageTabLoader
                        source: "SubStationManageTab.qml"
                        active: root.currentTabIndex === 1

                        onLoaded: {
                            item.virtualKeyboard = root.virtualKeyboard
                            item.parentDialog    = root
                            item.focusParamIndex = Qt.binding(function() {
                                return root.focusSubArea === 2 ? root.focusParamIndex : -1
                            })
                            item.focusSubArea = Qt.binding(function() {
                                return root.focusSubArea
                            })
                            // ✅ 2026-04-14 [Phase 7.48.88.125]: 移除不可靠的focusListIndex绑定
                            // currentSlotIndex 由 onMotorListIndexChanged 和 onAreaChanged 直接更新
                            // item.focusListIndex 不再单独使用
                        }
                    }

                    // Tab 2: MQTT集控配置
                    Loader {
                        id: mqttCentralTabLoader
                        source: "MQTTCentralTab.qml"
                        active: root.currentTabIndex === 2

                        onLoaded: {
                            item.virtualKeyboard = root.virtualKeyboard
                            item.parentDialog    = root  // ✅ 2026-04-14: 供ComboBox键盘导航使用
                            item.focusParamIndex = Qt.binding(function() {
                                return root.focusSubArea === 2 ? root.focusParamIndex : -1
                            })
                            item.focusSubArea = Qt.binding(function() {
                                return root.focusSubArea
                            })
                        }
                    }
                }
            }
        }

        // 底部按钮区域
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#1a1f2e"
            border.color: "#3d4556"
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 20

                Rectangle {
                    width: 120
                    height: 40
                    color: (root.focusSubArea === 3 && root.focusButtonIndex === 0)
                           ? "#2196F3" : "#2d3448"
                    border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 0)
                                  ? "#64B5F6" : "#3d4556"
                    border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? 2 : 1
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "保存配置"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.triggerButton(0)
                    }
                }
            }
        }
    }
}
