import QtQuick 2.15
import QtQuick.Controls 2.15
import "../" as DeviceInfo  // ✅ 2026-01-31 [FIX 100.300.112]: 导入 NavigationManager

// ✅ 2026-01-27 [制动器控制参数设置] 制动器控制主页面（左右分栏布局）
// 设计风格与电机控制完全一样
// ✅ 2026-01-31 [FIX 100.300.112]: 集成 NavigationManager，实现平面导航
Rectangle {
    id: root
    // ✅ 使用 implicitWidth/Height 替代固定尺寸，确保运行时正确显示
    implicitWidth: 1000  // 默认宽度（用于QDS预览）
    implicitHeight: 600  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentBrakeIndex: 0  // 当前选中的制动器索引 (0-7)

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 制动器状态数组（传递给 BrakeListPanel）
    // 每个元素: { enabled: bool, releaseOutputChannel: int }
    property var brakeStatusList: []

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 制动器运行状态数组（全局关联）
    // true=运行中（亮绿闪烁）, false=已停止
    property var brakeRunningStates: [false,false,false,false,false,false,false,false]

    // ✅ 2026-01-31 [FIX 100.300.112]: 导航焦点索引（从父对话框传递）
    property int focusItemIndex: -1  // -1 表示无焦点
    // 导航子区域（0:制动器列表 1:参数区域 2:底部按钮区域）
    property int focusSubArea: 0
    property int focusParamIndex: 0  // 参数区域焦点索引
    property int focusButtonIndex: 0  // 底部按钮区域焦点索引
    // Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ✅ 2026-01-31 [FIX 100.300.112.5]: 监听 focusItemIndex 变化，同步到 currentBrakeIndex
    // ✅ 2026-01-31 [FIX 100.300.112.5.1]: 同时更新 navigationManager.brakeListIndex
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex <= 7) {
            console.log("✅ [BrakeControlPage] focusItemIndex 变化:", focusItemIndex, "→ 更新 currentBrakeIndex 和 brakeListIndex")
            currentBrakeIndex = focusItemIndex
            navigationManager.brakeListIndex = focusItemIndex
        }
    }

    // ✅ 2026-01-31 [FIX 100.300.112]: NavigationManager 实例
    // ✅ 2026-01-31 [FIX 100.300.112.7]: 增加使用状态区域
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 区域定义
        readonly property int areaBrakeList: 0      // 制动器列表区域
        readonly property int areaUsageStatus: 1    // 使用状态区域（投入/禁用）
        readonly property int areaParams: 2         // 参数区域
        readonly property int areaButtons: 3        // 底部按钮区域

        // 当前状态
        property int currentArea: areaBrakeList
        property int brakeListIndex: 0      // 制动器列表索引（0-7）
        property int usageStatusIndex: 0    // 使用状态索引（0:投入 1:禁用）
        property int paramIndex: 0          // 参数索引（0-9）
        property int buttonIndex: 0         // 按钮索引（0-1）

        Component.onCompleted: {
            console.log("✅ [BrakeControlPage] NavigationManager 初始化完成")

            // 初始化焦点状态
            root.focusItemIndex = 0
            root.focusSubArea = 0

            console.log("✅ [BrakeControlPage] 初始状态已同步 - focusItemIndex:", root.focusItemIndex)
        }

        // 监听制动器列表索引变化
        onBrakeListIndexChanged: {
            console.log("✅ [BrakeControlPage] brakeListIndex 变化:", brakeListIndex)
            root.currentBrakeIndex = brakeListIndex

            // 根据区域更新 focusSubArea
            if (currentArea === areaBrakeList) {
                root.focusSubArea = 0
                root.focusItemIndex = brakeListIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                console.log("✅ [BrakeControlPage] 更新焦点 - focusItemIndex:", root.focusItemIndex)
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.7]: 监听使用状态索引变化
        onUsageStatusIndexChanged: {
            if (currentArea === areaUsageStatus) {
                root.focusSubArea = 1  // 使用状态区域
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                console.log("✅ [BrakeControlPage] 更新焦点 - 使用状态索引:", usageStatusIndex)
            }
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            if (currentArea === areaParams) {
                root.focusSubArea = 2  // ✅ 2026-01-31 [FIX 100.300.112.7]: 参数区域改为2
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
            }
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            if (currentArea === areaButtons) {
                root.focusSubArea = 3  // ✅ 2026-01-31 [FIX 100.300.112.7]: 按钮区域改为3
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
            }
        }

        // 区域切换函数
        // ✅ 2026-01-31 [FIX 100.300.112.7]: 增加使用状态区域
        function switchToArea(newArea) {
            currentArea = newArea

            switch(newArea) {
            case areaBrakeList:
                root.focusSubArea = 0
                root.focusItemIndex = brakeListIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaUsageStatus:
                root.focusSubArea = 1
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 2
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 3
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        // 导航函数
        // 2026-03-14 [Phase 7.48.45]: 简化导航，去掉usageStatus区域，投入/禁用改为Switch在参数区
        function moveInListArea(direction) {
            var newIndex = brakeListIndex
            switch(direction) {
            case "Up":
                if (brakeListIndex > 0) newIndex = brakeListIndex - 1
                break
            case "Down":
                if (brakeListIndex < 7) newIndex = brakeListIndex + 1
                break
            case "Right":
                // 右键直接进入参数区域
                switchToArea(areaParams)
                paramIndex = 0
                return
            }
            if (newIndex !== brakeListIndex) brakeListIndex = newIndex
        }

        // 2026-03-14 [Phase 7.48.45]: 保留兼容性，实际不再使用
        function moveInUsageStatusArea(direction) {
            switchToArea(areaParams); paramIndex = 0
        }

        // 2026-03-14 [Phase 7.48.45]: 参数区域导航（19个参数，混合行宽）
        // 行布局: A(0,1,2) B(3,4,5) C(6,7,8) D(9,10,11,12) E(13,14,15,16) F(17,18)
        function moveInParamArea(direction) {
            var idx = paramIndex
            // 旧：var rows = [[0,3],[3,3],[6,3],[9,4],[13,4],[17,2]]
            // ✅ 2026-03-22 [Phase 7.48.74]: 更新行映射（新增启动延时+停止延时行）
            // 旧：行5:[17-20] 电压+启动延时（4列）行6:[21-22] 停止延时
            // ✅ 2026-03-22 [Phase 7.48.74.2]: 电压行/启动延时/停止延时各独立一行
            // 行0:[0-2] 使用/松闸通道/抱闸通道  行1:[3-5] 松闸反馈  行2:[6-8] 抱闸反馈
            // 行3:[9-12] 保持/延时  行4:[13-16] 检测/电流  行5:[17-18] 电压  行6:[19-20] 启动延时  行7:[21-22] 停止延时
            var rows = [[0,3],[3,3],[6,3],[9,4],[13,4],[17,2],[19,2],[21,2]]
            var curRow = -1, colInRow = 0
            for (var r = 0; r < rows.length; r++) {
                if (idx >= rows[r][0] && idx < rows[r][0] + rows[r][1]) {
                    curRow = r; colInRow = idx - rows[r][0]; break
                }
            }
            if (curRow < 0) return

            switch(direction) {
            case "Left":
                if (colInRow > 0) { paramIndex = idx - 1 }
                else { switchToArea(areaBrakeList); return }
                break
            case "Right":
                if (colInRow < rows[curRow][1] - 1) { paramIndex = idx + 1 }
                break
            case "Up":
                if (curRow > 0) {
                    var prevRow = rows[curRow - 1]
                    var targetCol = Math.min(colInRow, prevRow[1] - 1)
                    paramIndex = prevRow[0] + targetCol
                } else { switchToArea(areaBrakeList); return }
                break
            case "Down":
                if (curRow < rows.length - 1) {
                    var nextRow = rows[curRow + 1]
                    var targetCol2 = Math.min(colInRow, nextRow[1] - 1)
                    paramIndex = nextRow[0] + targetCol2
                } else { switchToArea(areaButtons); buttonIndex = 0; return }
                break
            }
        }

        // 2026-03-14 [Phase 7.48.45]: 按钮区域导航（3个按钮：松闸/抱闸/停止）
        function moveInButtonArea(direction) {
            var newIndex = buttonIndex

            switch(direction) {
            case "Left":
                if (buttonIndex > 0) {
                    newIndex = buttonIndex - 1
                } else {
                    switchToArea(areaBrakeList)
                    return
                }
                break
            case "Right":
                if (buttonIndex < 2) {
                    newIndex = buttonIndex + 1
                }
                break
            case "Up":
                switchToArea(areaParams)
                paramIndex = 18
                return
            }

            if (newIndex !== buttonIndex) {
                buttonIndex = newIndex
            }
        }
    }

    // ========== 背景装饰图片（预留位置，可在QDS中替换）==========
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: ""  // 预留：在QDS中设置装饰图片路径
        fillMode: Image.Stretch
        z: -1  // 确保在所有内容下方
        visible: source != ""  // 只有设置了图片才显示
    }

    // ========== 键盘导航支持 ==========
    focus: true

    // ✅ 2026-01-31 [FIX 100.300.112]: 使用 NavigationManager 处理键盘事件
    // ✅ 2026-01-31 [FIX 100.300.112.7]: 增加使用状态区域处理
    Keys.onPressed: (event) => {
        var direction = ""

        switch(event.key) {
        case Qt.Key_Up:
            direction = "Up"
            break
        case Qt.Key_Down:
            direction = "Down"
            break
        case Qt.Key_Left:
            direction = "Left"
            break
        case Qt.Key_Right:
            direction = "Right"
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // 回车键：触发当前焦点项
            if (navigationManager.currentArea === navigationManager.areaUsageStatus) {
                // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 切换投入/禁用选项
                brakeConfigPanel.item.toggleUsageStatus()
            } else if (navigationManager.currentArea === navigationManager.areaParams) {
                brakeConfigPanel.item.triggerParamInput(navigationManager.paramIndex)
            } else if (navigationManager.currentArea === navigationManager.areaButtons) {
                brakeConfigPanel.item.triggerButton(navigationManager.buttonIndex)
            }
            event.accepted = true
            return
        default:
            return
        }

        // 根据当前区域调用对应的导航函数
        switch(navigationManager.currentArea) {
        case navigationManager.areaBrakeList:
            navigationManager.moveInListArea(direction)
            break
        case navigationManager.areaUsageStatus:
            // ✅ 2026-01-31 [FIX 100.300.112.7]: 使用状态区域导航
            navigationManager.moveInUsageStatusArea(direction)
            break
        case navigationManager.areaParams:
            navigationManager.moveInParamArea(direction)
            break
        case navigationManager.areaButtons:
            navigationManager.moveInButtonArea(direction)
            break
        }

        event.accepted = true
    }

    // ❌ 2026-01-31 [FIX 100.300.112]: 旧的键盘导航支持（已废弃，注释掉）
    // Keys.onPressed: {
    //     // 将键盘事件转发给子组件
    //     if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
    //         brakeListPanel.item.focus = true
    //     } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
    //         brakeConfigPanel.item.focus = true
    //     }
    // }

    // ========== 左右分栏布局 ==========
    Row {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧：制动器列表（使用Loader加载）==========
        Loader {
            id: brakeListPanel
            // ✅ 2026-01-27 [FIX 100.300.35]: 宽度减少到80%（240px → 192px）
            width: 192
            height: parent.height
            source: "BrakeListPanel.qml"

            onLoaded: {
                // ✅ 2026-01-31 [FIX 100.300.112.3]: 绑定到 navigationManager.brakeListIndex 而不是 root.currentBrakeIndex
                // 这样 NavigationManager 的导航逻辑才能正确更新列表焦点
                item.currentBrakeIndex = Qt.binding(function() { return navigationManager.brakeListIndex })
                // ✅ 2026-01-31 [FIX 100.300.112]: 传递焦点索引
                item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                // ✅ 2026-01-31 [FIX 100.300.112.6]: 传递焦点子区域
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                // ✅ 2026-03-30 [Phase 7.48.88.74]: 传递制动器状态和运行状态数据
                item.brakeStatusList = Qt.binding(function() { return root.brakeStatusList })
                item.brakeRunningStates = Qt.binding(function() { return root.brakeRunningStates })
                item.brakeSelected.connect(function(brakeIndex) {
                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.15]: 鼠标点击时同步所有焦点状态
                    console.log("🔍 [BrakeControlPage] 鼠标点击制动器:", brakeIndex)
                    root.currentBrakeIndex = brakeIndex
                    root.focusItemIndex = brakeIndex
                    root.focusSubArea = 0  // 确保在列表区域
                    navigationManager.brakeListIndex = brakeIndex
                    console.log("选中制动器:", brakeIndex + 1)
                })
            }
        }

        // ========== 分隔线 ==========
        Rectangle {
            width: 2
            height: parent.height
            color: "#3d4556"
        }

        // ========== 右侧：制动器配置面板（使用Loader加载）==========
        Loader {
            id: brakeConfigPanel
            width: parent.width - brakeListPanel.width - 2
            height: parent.height
            source: "BrakeConfigPanel.qml"

            onLoaded: {
                item.deviceId = Qt.binding(function() { return root.deviceId })  // ✅ 2026-02-06 [参数持久化]: 传递设备ID
                item.brakeIndex = Qt.binding(function() { return root.currentBrakeIndex })
                // ✅ 2026-01-31 [FIX 100.300.112]: 传递焦点索引和虚拟键盘
                // ✅ 2026-01-31 [FIX 100.300.112.7]: 传递使用状态焦点索引
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.focusUsageStatusIndex = Qt.binding(function() { return navigationManager.usageStatusIndex })
                item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                item.focusButtonIndex = Qt.binding(function() { return root.focusButtonIndex })
                item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
            }
        }
    }

    // ========== 转发函数（供 DeviceSettingsDialog 调用）==========
    // ✅ 2026-01-31 [FIX 100.300.112.2]: 添加转发函数，将调用转发给 BrakeConfigPanel
    // ✅ 2026-01-31 [FIX 100.300.112.7.2]: 添加 handleKeyPress 函数，处理 DeviceSettingsDialog 的键盘事件

    // ✅ 2026-03-18 [Phase 7.48.53]: 添加保存转发函数，供DeviceSettingsDialog保存按钮调用
    function saveBrakeConfig() {
        if (brakeConfigPanel.item && typeof brakeConfigPanel.item.saveBrakeConfig === "function") {
            brakeConfigPanel.item.saveBrakeConfig()
        }
    }

    // 处理键盘事件（供 DeviceSettingsDialog 调用）
    function handleKeyPress(direction) {
        console.log("✅ [BrakeControlPage] handleKeyPress - direction:", direction)

        // 根据当前区域调用对应的导航函数
        switch(navigationManager.currentArea) {
        case navigationManager.areaBrakeList:
            navigationManager.moveInListArea(direction)
            break
        case navigationManager.areaUsageStatus:
            navigationManager.moveInUsageStatusArea(direction)
            break
        case navigationManager.areaParams:
            navigationManager.moveInParamArea(direction)
            break
        case navigationManager.areaButtons:
            navigationManager.moveInButtonArea(direction)
            break
        }
    }

    // 返回参数区域的字段数量
    function getParamFieldCount() {
        if (brakeConfigPanel.item && typeof brakeConfigPanel.item.getParamFieldCount === "function") {
            return brakeConfigPanel.item.getParamFieldCount()
        }
        return 0
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [BrakeControlPage] 触发参数输入 - 索引:", paramIndex)

        if (brakeConfigPanel.item && typeof brakeConfigPanel.item.triggerParamInput === "function") {
            brakeConfigPanel.item.triggerParamInput(paramIndex)
        } else {
            console.log("⚠️ [BrakeControlPage] BrakeConfigPanel 不支持参数输入")
        }
    }

    // 触发按钮点击
    function triggerButton(buttonIndex) {
        console.log("✅ [BrakeControlPage] 触发按钮 - 索引:", buttonIndex)

        if (brakeConfigPanel.item && typeof brakeConfigPanel.item.triggerButton === "function") {
            brakeConfigPanel.item.triggerButton(buttonIndex)
        } else {
            console.log("⚠️ [BrakeControlPage] BrakeConfigPanel 不支持按钮触发")
        }
    }

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 加载所有8个制动器的状态（启用/禁用/未配置）
    // 用于 BrakeListPanel 显示每个制动器的实际状态
    function loadAllBrakeStatuses() {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var statusList = []
        for (var i = 0; i < 8; i++) {
            var config = deviceConfigMgr.loadBrakeConfig(root.deviceId, i)
            if (config && Object.keys(config).length > 0) {
                var enabled = config.hasOwnProperty("enabled") ? (config["enabled"] === true || config["enabled"] === 1) : true
                var relCh = config.hasOwnProperty("release_output_channel") ? config["release_output_channel"] : -1
                statusList.push({ enabled: enabled, releaseOutputChannel: relCh })
            } else {
                // 未保存配置：制动器1-5默认有通道(6-10)，6-8无通道
                statusList.push({ enabled: true, releaseOutputChannel: i < 5 ? i + 6 : -1 })
            }
        }
        root.brakeStatusList = statusList
        console.log("✅ [BrakeControlPage] 已加载8个制动器状态")
    }

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 监听全局设备状态变化，更新制动器运行状态
    // ✅ 2026-03-30 [Phase 7.48.88.76]: 已迁移到 DeviceSettingsDialog 层级持久化
    // 问题：切换类别时Loader销毁组件导致runningStates重置，现由Dialog层级统一监听并通过Qt.binding()传递
    // Connections {
    //     target: typeof commonControl !== "undefined" ? commonControl : null
    //     function onDeviceStatusChanged(beltNumber, deviceName, isRunning) {
    //         var match = deviceName.match(/(\d+)号制动器/)
    //         if (!match) return
    //         var brakeIdx = parseInt(match[1]) - 1
    //         if (brakeIdx < 0 || brakeIdx >= 8) return
    //         var newStates = root.brakeRunningStates.slice()
    //         newStates[brakeIdx] = isRunning
    //         root.brakeRunningStates = newStates
    //         console.log("✅ [BrakeControlPage] 制动器" + (brakeIdx + 1) + (isRunning ? " 运行中" : " 已停止"))
    //     }
    // }

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 初始化时加载制动器状态
    Component.onCompleted: {
        loadAllBrakeStatuses()
    }
}
