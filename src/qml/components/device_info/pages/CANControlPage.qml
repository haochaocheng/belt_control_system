// CANControlPage.qml
// CAN 控制主页面
// 创建日期: 2026-02-07
// ✅ 2026-02-07: Phase 7.39.4 - 添加键盘导航功能

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"
    focus: true

    // ========== 公开属性 ==========
    property int currentCanIndex: 0     // 当前选中的 CAN 索引 (0-1)
    property int focusItemIndex: -1     // 导航焦点索引
    property int focusSubArea: 0        // 焦点子区域 (0:列表 1:Tab栏 2:参数 3:按钮)
    property int focusTabIndex: -1      // Tab 焦点索引
    property int focusParamIndex: 0     // 参数焦点索引
    property int focusButtonIndex: 0    // 按钮焦点索引

    // ✅ 2026-02-07 [Phase 7.39.4]: 添加导航控制标志
    property bool isReturningToCategory: false  // 是否正在返回类别（防止事件循环）
    property bool keysEnabled: true             // 键盘事件是否启用

    // ✅ 2026-02-07 [Phase 7.39.4]: 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // ✅ 2026-02-07 [Phase 7.39.4]: 暴露 canConfigPanel 供外部访问
    property alias canConfigPanel: canConfigPanel

    // ✅ 2026-02-07 [Phase 7.39.4]: Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ========== 信号 ==========
    signal requestReturnToCategory()  // 请求返回到左侧类别

    // ========== 函数 ==========
    // 返回当前 Tab 的引用
    function getCurrentTab() {
        if (!canConfigPanel.item) {
            return null
        }
        return canConfigPanel.item.getCurrentTabItem()
    }

    // 返回当前 Tab 的参数数量（动态获取）
    function getParamFieldCount() {
        if (!canConfigPanel.item) {
            console.warn("⚠️ [CANControlPage] CANConfigPanel 未加载")
            return 0
        }

        var currentTab = canConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            console.warn("⚠️ [CANControlPage] 当前 Tab 未加载")
            return 0
        }

        if (typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }

        // 默认参数数量（根据 Tab 索引）
        switch(root.focusTabIndex) {
        case 0:  // 参数配置
            return 4  // CAN接口、波特率、状态、帧类型
        case 1:  // 发送区
            return 3  // CAN ID、数据、发送按钮
        case 2:  // 接收区
            return 1  // 清空按钮
        default:
            return 0
        }
    }

    // 调用当前 Tab 的 triggerParamInput 方法
    function triggerParamInput(index) {
        console.log("✅ [CANControlPage] triggerParamInput - 参数索引:", index)

        if (!canConfigPanel.item) {
            console.error("❌ [CANControlPage] CANConfigPanel 未加载")
            return
        }

        var currentTab = canConfigPanel.item.getCurrentTab()
        if (!currentTab) {
            console.error("❌ [CANControlPage] 当前 Tab 未加载")
            return
        }

        // 调用当前 Tab 的 triggerParamInput 方法
        if (typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(index)
        } else {
            console.warn("⚠️ [CANControlPage] 当前 Tab 没有 triggerParamInput 方法")
        }
    }

    // 回车键处理函数
    function handleEnterKey() {
        console.log("✅ [CANControlPage] 处理回车键 - 当前焦点区域:", focusSubArea)

        // 区域0：列表区域 - 切换 CAN
        if (focusSubArea === 0) {
            console.log("✅ [CANControlPage] 列表区域 - 切换 CAN:", focusItemIndex)
            currentCanIndex = focusItemIndex
            return true
        }

        // 区域1：Tab 栏区域 - 切换 Tab
        if (focusSubArea === 1) {
            console.log("✅ [CANControlPage] Tab 栏区域 - 切换 Tab:", focusTabIndex)
            if (canConfigPanel.item) {
                canConfigPanel.item.currentTabIndex = focusTabIndex
            }
            return true
        }

        // 区域2：参数区域 - 调用当前 Tab 的 handleEnterKey
        if (focusSubArea === 2) {
            console.log("✅ [CANControlPage] 参数区域 - 调用 Tab 的 handleEnterKey")
            if (canConfigPanel.item) {
                var currentTab = canConfigPanel.item.getCurrentTab()
                if (currentTab && typeof currentTab.handleEnterKey === "function") {
                    return currentTab.handleEnterKey()
                }
            }
            console.warn("⚠️ [CANControlPage] 当前 Tab 没有 handleEnterKey 方法")
            return false
        }

        // 区域3：按钮区域 - 执行按钮点击
        if (focusSubArea === 3) {
            console.log("✅ [CANControlPage] 按钮区域 - 执行按钮点击:", focusButtonIndex)
            return triggerButton(focusButtonIndex)
        }

        console.warn("⚠️ [CANControlPage] 未处理的焦点区域:", focusSubArea)
        return false
    }

    // 触发按钮点击
    function triggerButton(buttonIndex) {
        console.log("✅ [CANControlPage] triggerButton - 按钮索引:", buttonIndex)

        switch(buttonIndex) {
        case 0:  // 打开CAN
            console.log("✅ [CANControlPage] 执行打开CAN")
            if (canController.openCAN()) {
                console.log("✅ [CANControlPage] CAN 接口打开成功")
            } else {
                console.error("❌ [CANControlPage] CAN 接口打开失败")
            }
            return true
        case 1:  // 关闭CAN
            console.log("✅ [CANControlPage] 执行关闭CAN")
            canController.closeCAN()
            return true
        case 2:  // 保存
            console.log("✅ [CANControlPage] 执行保存配置")
            canController.saveConfig()
            return true
        case 3:  // 删除
            console.log("✅ [CANControlPage] 执行删除配置")
            if (canController.isUp) {
                canController.closeCAN()
            }
            canController.resetConfig()
            return true
        case 4:  // 重置
            console.log("✅ [CANControlPage] 执行重置配置")
            canController.resetConfig()
            return true
        default:
            console.warn("⚠️ [CANControlPage] 未知按钮索引:", buttonIndex)
            return false
        }
    }

    // ========== CAN 数据 ==========
    property var canInterfaces: [
        { name: "CAN0", path: "can0", bitrate: 500000 },
        { name: "CAN1", path: "can1", bitrate: 250000 }
    ]

    // ========== 当前 CAN 信息 ==========
    property var currentCanInterface: canInterfaces[currentCanIndex]

    // ========== 信号 ==========
    signal canInterfaceSelected(int index)

    // ✅ 2026-02-07 [Phase 7.39.4]: 标志重置定时器
    Timer {
        id: resetFlagTimer
        interval: 100
        repeat: false
        onTriggered: {
            root.isReturningToCategory = false
        }
    }

    // ✅ 2026-02-07 [Phase 7.39.4]: 监听焦点变化，启用键盘事件
    onActiveFocusChanged: {
        if (activeFocus) {
            keysEnabled = true
        }
    }

    // ========== 监听焦点变化，同步更新 currentCanIndex ==========
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < canInterfaces.length) {
            console.log("✅ [CANControlPage] focusItemIndex 变化:", focusItemIndex, "→ 更新 currentCanIndex")
            currentCanIndex = focusItemIndex
        }
    }

    // ✅ 2026-02-07 [Phase 7.39.4]: 监听 focusSubArea 变化
    onFocusSubAreaChanged: {
        console.log("🔍 [CANControlPage] focusSubArea 变化:", focusSubArea)
        console.log("🔍 [CANControlPage] 当前状态 - focusItemIndex:", focusItemIndex, "currentCanIndex:", currentCanIndex)
    }

    // ✅ 2026-02-07 [Phase 7.39.4]: 监听 currentCanIndex 变化，同步到 CANController
    onCurrentCanIndexChanged: {
        console.log("✅ [CANControlPage] currentCanIndex 变化:", currentCanIndex)
        if (currentCanIndex >= 0 && currentCanIndex < canInterfaces.length) {
            canController.currentCanIndex = currentCanIndex
            console.log("✅ [CANControlPage] 已同步到 CANController.currentCanIndex:", currentCanIndex)
        }
    }

    // ✅ 2026-02-07 [Phase 7.39.4]: NavigationManager 实例
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 初始化：从 CAN 列表区开始
        Component.onCompleted: {
            currentArea = areaMotorList  // 使用 areaMotorList（通用列表区域）
            motorListIndex = 0  // 使用 motorListIndex（通用列表索引）
            tabIndex = 0  // 初始 Tab 索引
            paramIndex = 0  // 初始参数索引
            buttonIndex = 0
            skipTabArea = false  // 支持 Tab 导航
            lastTabIndex = 2  // CAN 控制页面有3个Tab（0-2）

            // 动态更新 lastParamIndex
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
                console.log("✅ [CANControlPage] 初始参数数量:", paramCount)
            })

            console.log("✅ [CANControlPage] NavigationManager 初始化完成")

            // 同步初始状态到root
            root.currentCanIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            root.focusButtonIndex = 0
        }

        // 监听 CAN 列表索引变化
        onMotorListIndexChanged: {
            console.log("✅ [CANControlPage] CAN 列表索引变化:", motorListIndex)
            root.currentCanIndex = motorListIndex
            root.focusItemIndex = motorListIndex
        }

        // 监听 Tab 索引变化
        onTabIndexChanged: {
            console.log("✅ [CANControlPage] Tab 索引变化:", tabIndex)
            root.focusTabIndex = tabIndex

            // 同步更新 CANConfigPanel 的 currentTabIndex
            if (canConfigPanel.item) {
                canConfigPanel.item.currentTabIndex = tabIndex
                console.log("✅ [CANControlPage] 已同步 currentTabIndex 到 CANConfigPanel:", tabIndex)
            }

            // 更新 lastParamIndex
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                updateLastParamIndex(paramCount)
                console.log("✅ [CANControlPage] Tab 切换后参数数量:", paramCount)
            })
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            console.log("✅ [CANControlPage] 参数索引变化:", paramIndex)
            root.focusParamIndex = paramIndex
            // 调用 triggerParamInput 设置焦点
            root.triggerParamInput(paramIndex)
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            console.log("✅ [CANControlPage] 按钮索引变化:", buttonIndex)
            root.focusButtonIndex = buttonIndex
        }

        // 监听区域变化
        onAreaChanged: function(newArea) {
            console.log("✅ [CANControlPage] 区域变化:", newArea)
            switch(newArea) {
            case areaMotorList:  // 列表区域
                root.focusSubArea = 0
                root.focusItemIndex = motorListIndex
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaTabBar:  // Tab 栏区域
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
                // 强制触发焦点设置
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

        // 监听 returnToCategory 信号，释放焦点
        onReturnToCategory: {
            console.log("✅ [CANControlPage] 接收到 returnToCategory 信号，释放焦点")
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

    // ========== 键盘事件处理器 ==========
    // 上键：向上导航
    Keys.onUpPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        console.log("✅ [CANControlPage] 按上键")
        navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    // 下键：向下导航
    Keys.onDownPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        console.log("✅ [CANControlPage] 按下键")
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
            console.log("✅ [CANControlPage] 列表区域按左键，请求返回到左侧类别")
            root.isReturningToCategory = true
            root.requestReturnToCategory()
            resetFlagTimer.start()
            event.accepted = true
        } else {
            console.log("✅ [CANControlPage] 按左键")
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
        console.log("✅ [CANControlPage] 按右键")
        navigationManager.handleDirectionKey("Right")
        event.accepted = true
    }

    // ✅ 2026-02-07 [Phase 7.39.9]: 添加回车键处理
    // 回车键：执行当前焦点项的操作
    Keys.onReturnPressed: {
        if (!keysEnabled || isReturningToCategory) {
            event.accepted = true
            return
        }
        console.log("✅ [CANControlPage] 按回车键")
        handleEnterKey()
        event.accepted = true
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [CANControlPage] Component.onCompleted 开始")
        console.log("✅ [CANControlPage] CAN 数量:", canInterfaces.length)

        // 初始化焦点状态
        focusSubArea = 0
        focusItemIndex = 0

        console.log("✅ [CANControlPage] 初始化焦点 - focusSubArea:", focusSubArea, "focusItemIndex:", focusItemIndex)
        console.log("✅ [CANControlPage] Component.onCompleted 完成")
    }

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 上部：列表和配置区域 ==========
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ========== 左侧：CAN 列表 ==========
            Loader {
                id: canListPanel
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                source: "CANListPanel.qml"

                onLoaded: {
                    console.log("✅ [CANControlPage] CANListPanel 加载成功")

                    // 传递属性
                    item.canInterfaces = Qt.binding(function() { return root.canInterfaces })
                    item.currentCanIndex = Qt.binding(function() { return root.currentCanIndex })
                    item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })

                    // 连接信号：鼠标点击时同步焦点
                    item.canInterfaceSelected.connect(function(index) {
                        console.log("✅ [CANControlPage] CAN 选中:", index)
                        root.currentCanIndex = index
                        root.focusItemIndex = index
                        root.focusSubArea = 0
                        root.canInterfaceSelected(index)
                    })
                }
            }

            // ========== 分隔线 ==========
            Rectangle {
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                color: "#3d4556"
            }

            // ========== 右侧：CAN 配置和操作区域 ==========
            Loader {
                id: canConfigPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "CANConfigPanel.qml"

                onLoaded: {
                    console.log("✅ [CANControlPage] CANConfigPanel 加载成功")

                    // 传递属性
                    item.currentCanInterface = Qt.binding(function() { return root.currentCanInterface })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                    item.focusTabIndex = Qt.binding(function() { return root.focusTabIndex })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })

                    // 连接信号，转发焦点更新
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        console.log("✅ [CANControlPage] 收到焦点请求:", paramIndex)
                        root.focusParamIndex = paramIndex
                        navigationManager.paramIndex = paramIndex
                    })

                    // 监听 currentTabIndex 变化
                    item.onCurrentTabIndexChanged.connect(function() {
                        console.log("✅ [CANControlPage] Tab 切换:", item.currentTabIndex)
                        navigationManager.tabIndex = item.currentTabIndex
                    })
                }
            }
        }

        // ========== 底部：按钮区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90  // 两行按钮
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

                // 第一行：打开CAN、关闭CAN
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: openCANButton
                        text: "打开CAN"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
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
                            console.log("✅ [CANControlPage] 打开CAN")
                            if (canController.openCAN()) {
                                console.log("✅ [CANControlPage] CAN 接口打开成功")
                            } else {
                                console.error("❌ [CANControlPage] CAN 接口打开失败")
                            }
                        }
                    }

                    Button {
                        id: closeCANButton
                        text: "关闭CAN"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
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
                            console.log("✅ [CANControlPage] 关闭CAN")
                            canController.closeCAN()
                            console.log("✅ [CANControlPage] CAN 接口已关闭")
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
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 2) {
                                    return "#2ecc71"
                                } else if (parent.pressed) {
                                    return "#27ae60"
                                } else if (parent.hovered) {
                                    return "#2ecc71"
                                } else {
                                    return "#27ae60"
                                }
                            }
                            radius: 4
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
                            console.log("✅ [CANControlPage] 保存")
                            canController.saveConfig()
                            console.log("✅ [CANControlPage] 配置已保存")
                        }
                    }

                    Button {
                        id: deleteButton
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 3) {
                                    return "#e74c3c"
                                } else if (parent.pressed) {
                                    return "#c0392b"
                                } else if (parent.hovered) {
                                    return "#e74c3c"
                                } else {
                                    return "#d35400"
                                }
                            }
                            radius: 4
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
                            console.log("✅ [CANControlPage] 删除")
                            if (canController.isUp) {
                                canController.closeCAN()
                            }
                            canController.resetConfig()
                            console.log("✅ [CANControlPage] 当前 CAN 配置已删除（重置为默认值）")
                        }
                    }

                    Button {
                        id: resetButton
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: {
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 4) {
                                    return "#3498db"
                                } else if (parent.pressed) {
                                    return "#2980b9"
                                } else if (parent.hovered) {
                                    return "#3498db"
                                } else {
                                    return "#2980b9"
                                }
                            }
                            radius: 4
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
                            console.log("✅ [CANControlPage] 重置")
                            canController.resetConfig()
                            console.log("✅ [CANControlPage] 配置已重置为默认值")
                        }
                    }
                }
            }
        }
    }
}
