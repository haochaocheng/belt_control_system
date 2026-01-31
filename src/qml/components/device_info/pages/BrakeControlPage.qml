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

        // 导航函数（参考 MotorControlPage 的实现）
        // ✅ 2026-01-31 [FIX 100.300.112.7]: 右键进入使用状态区域
        function moveInListArea(direction) {
            console.log("✅ [BrakeControlPage] moveInListArea - direction:", direction, "brakeListIndex:", brakeListIndex)
            // 制动器列表导航（8个制动器，0-7）
            var newIndex = brakeListIndex

            switch(direction) {
            case "Up":
                if (brakeListIndex > 0) {
                    newIndex = brakeListIndex - 1
                }
                break
            case "Down":
                if (brakeListIndex < 7) {
                    newIndex = brakeListIndex + 1
                }
                break
            case "Right":
                // ✅ 2026-01-31 [FIX 100.300.112.7]: 右键进入使用状态区域
                switchToArea(areaUsageStatus)
                usageStatusIndex = 0
                return
            }

            if (newIndex !== brakeListIndex) {
                console.log("✅ [BrakeControlPage] 更新 brakeListIndex:", brakeListIndex, "→", newIndex)
                brakeListIndex = newIndex
            } else {
                console.log("⚠️ [BrakeControlPage] brakeListIndex 未变化，仍为:", brakeListIndex)
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.7]: 使用状态区域导航
        // ✅ 2026-01-31 [FIX 100.300.112.7.1]: 修复右键切换逻辑，支持双向切换
        // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 右键进入参数区域，回车键切换选项
        function moveInUsageStatusArea(direction) {
            // 使用状态区域导航（整个区域作为一个焦点单元）
            // 左键：返回制动器列表
            // 右键：进入参数区域
            // 下键：进入参数区域
            // 回车键：切换投入/禁用选项（在 Keys.onPressed 中处理）

            switch(direction) {
            case "Left":
                // 左键：返回制动器列表
                switchToArea(areaBrakeList)
                return
            case "Right":
                // ✅ 2026-01-31 [FIX 100.300.112.7.3]: 右键进入参数区域（不再切换选项）
                switchToArea(areaParams)
                paramIndex = 0
                return
            case "Down":
                // 下键：进入参数区域
                switchToArea(areaParams)
                paramIndex = 0
                return
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.7]: 参数区域导航（左键和上键返回使用状态区域）
        function moveInParamArea(direction) {
            // 参数区域导航（10个参数，0-9，GridLayout 4列布局）
            var newIndex = paramIndex

            switch(direction) {
            case "Left":
                if (paramIndex % 2 === 1) {
                    // 右列 → 左列
                    newIndex = paramIndex - 1
                } else {
                    // ✅ 2026-01-31 [FIX 100.300.112.7]: 左列最左，返回使用状态区域
                    switchToArea(areaUsageStatus)
                    return
                }
                break
            case "Right":
                if (paramIndex % 2 === 0) {
                    // 左列 → 右列
                    newIndex = paramIndex + 1
                }
                break
            case "Up":
                if (paramIndex >= 2) {
                    newIndex = paramIndex - 2
                } else {
                    // ✅ 2026-01-31 [FIX 100.300.112.7]: 第一行，返回使用状态区域
                    switchToArea(areaUsageStatus)
                    return
                }
                break
            case "Down":
                if (paramIndex <= 7) {
                    newIndex = paramIndex + 2
                } else {
                    // 最后一行，进入按钮区域
                    switchToArea(areaButtons)
                    buttonIndex = 0
                    return
                }
                break
            }

            if (newIndex !== paramIndex && newIndex >= 0 && newIndex <= 9) {
                paramIndex = newIndex
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.7]: 按钮区域导航（左键返回使用状态区域）
        function moveInButtonArea(direction) {
            // 底部按钮导航（2个按钮，0-1）
            var newIndex = buttonIndex

            switch(direction) {
            case "Left":
                if (buttonIndex > 0) {
                    newIndex = buttonIndex - 1
                } else {
                    // ✅ 2026-01-31 [FIX 100.300.112.7]: 最左，返回使用状态区域
                    switchToArea(areaUsageStatus)
                    return
                }
                break
            case "Right":
                if (buttonIndex < 1) {
                    newIndex = buttonIndex + 1
                }
                break
            case "Up":
                // 返回参数区域最后一个参数
                switchToArea(areaParams)
                paramIndex = 9
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
                item.brakeSelected.connect(function(brakeIndex) {
                    root.currentBrakeIndex = brakeIndex
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
}
