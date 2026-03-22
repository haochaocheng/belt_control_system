import QtQuick 2.15
import QtQuick.Controls 2.15
import "../" as DeviceInfo  // ✅ 2026-01-31 [FIX 100.300.112.8]: 导入 NavigationManager

// ✅ 2026-01-27 [张紧控制参数设置] 张紧控制主页面（左右分栏布局）
// ✅ 2026-01-31 [FIX 100.300.112.8]: 添加 NavigationManager 支持（3区域模式）
// ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式（无使用状态区域）
// 设计风格与电机控制、制动器控制完全一样
Rectangle {
    id: root
    // ✅ 使用 implicitWidth/Height 替代固定尺寸，确保运行时正确显示
    implicitWidth: 1000  // 默认宽度（用于QDS预览）
    implicitHeight: 600  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentControlIndex: 0  // 当前选中的控制索引 (0=张力传感器, 1=独立张紧控制)

    // ✅ 2026-01-31 [FIX 100.300.112.8]: 导航焦点属性
    // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式（0:列表 1:参数 2:按钮）
    property int focusItemIndex: -1  // -1 表示无焦点
    property int focusSubArea: 0  // 0:列表区域 1:参数区域 2:按钮区域
    property int focusParamIndex: 0  // 参数区域焦点索引
    property int focusButtonIndex: 0  // 底部按钮区域焦点索引
    // Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ✅ 2026-01-31 [FIX 100.300.112.8]: 监听 focusItemIndex 变化，同步到 currentControlIndex
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex <= 1) {
            console.log("✅ [TensionControlPage] focusItemIndex 变化:", focusItemIndex, "→ 更新 currentControlIndex 和 controlListIndex")
            currentControlIndex = focusItemIndex
            navigationManager.controlListIndex = focusItemIndex
        }
    }

    // ✅ 2026-01-31 [FIX 100.300.112.8]: NavigationManager 实例（4区域模式）
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 区域定义
        // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式（无使用状态区域）
        readonly property int areaControlList: 0      // 控制列表区域
        readonly property int areaParams: 1           // 参数区域
        readonly property int areaButtons: 2          // 底部按钮区域

        // 当前状态
        property int currentArea: areaControlList
        property int controlListIndex: 0      // 控制列表索引（0-1）
        property int paramIndex: 0            // 参数索引
        property int buttonIndex: 0           // 按钮索引（0-2）

        Component.onCompleted: {
            console.log("✅ [TensionControlPage] NavigationManager 初始化完成")

            // 初始化焦点状态
            root.focusItemIndex = 0
            root.focusSubArea = 0

            console.log("✅ [TensionControlPage] 初始状态已同步 - focusItemIndex:", root.focusItemIndex)
        }

        // 监听控制列表索引变化
        onControlListIndexChanged: {
            console.log("✅ [TensionControlPage] controlListIndex 变化:", controlListIndex)
            root.currentControlIndex = controlListIndex

            // 根据区域更新 focusSubArea
            if (currentArea === areaControlList) {
                root.focusSubArea = 0
                root.focusItemIndex = controlListIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                console.log("✅ [TensionControlPage] 更新焦点 - focusItemIndex:", root.focusItemIndex)
            }
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            if (currentArea === areaParams) {
                root.focusSubArea = 1  // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 参数区域改为1
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
            }
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            if (currentArea === areaButtons) {
                root.focusSubArea = 2  // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 按钮区域改为2
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
            }
        }

        // 区域切换函数
        // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式
        function switchToArea(newArea) {
            console.log("✅ [TensionControlPage] switchToArea:", newArea)
            currentArea = newArea

            switch(newArea) {
            case areaControlList:
                root.focusSubArea = 0
                root.focusItemIndex = controlListIndex
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 1  // ✅ 参数区域改为1
                root.focusParamIndex = paramIndex
                root.focusItemIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 2  // ✅ 按钮区域改为2
                root.focusButtonIndex = buttonIndex
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        // 导航函数：控制列表区域（2个控制项，0-1）
        function moveInListArea(direction) {
            console.log("✅ [TensionControlPage] moveInListArea - direction:", direction, "controlListIndex:", controlListIndex)
            var newIndex = controlListIndex

            switch(direction) {
            case "Up":
                if (controlListIndex > 0) {
                    newIndex = controlListIndex - 1
                }
                break
            case "Down":
                if (controlListIndex < 1) {
                    newIndex = controlListIndex + 1
                }
                break
            case "Right":
                // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 右键直接进入参数区域（无使用状态）
                switchToArea(areaParams)
                paramIndex = 0
                return
            }

            if (newIndex !== controlListIndex) {
                console.log("✅ [TensionControlPage] 更新 controlListIndex:", controlListIndex, "→", newIndex)
                controlListIndex = newIndex
            } else {
                console.log("⚠️ [TensionControlPage] controlListIndex 未变化，仍为:", controlListIndex)
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 移除使用状态区域导航（张紧控制无使用状态）
        // function moveInUsageStatusArea(direction) { ... }

        // 导航函数：参数区域
        // 2026-03-17 [Phase 7.48.51]: 动态导航数组，根据currentControlIndex切换
        // 张力传感器(0): 15个参数(0-14), 行布局: A(0,1) B(2,3,4) C(5,6,7) D(8,9,10) E(11,12) F(13,14)
        // 张紧控制(1): 6个参数(0-5), 行布局: A(0) B(1,2) C(3) D(4) E(5)
        function moveInParamArea(direction) {
            console.log("✅ [TensionControlPage] moveInParamArea - direction:", direction, "paramIndex:", paramIndex, "controlIndex:", root.currentControlIndex)
            var idx = paramIndex
            var rows = []

            // 根据当前选中的控制类型选择导航数组
            if (root.currentControlIndex === 0) {
                // 张力传感器: 17个参数（4列布局，每行2个参数）
                // ✅ 2026-03-22 [Phase 7.48.78]: 新增洒水启用(15)，洒水编号改为16
                // Row0: 名称(0)+播放次数(1), Row1: 模块类型(2)+播放时长(3),
                // Row2: 通道号(4)+上限值(5), Row3: 下限值(6)+量程(7),
                // Row4: 单位(8)+输入类型(9), Row5: 保护延时(10)+保护级别(11),
                // Row6: 音频来源(12)+播放方式(13), Row7: TTS文本/音频文件(14),
                // Row8: 洒水启用(15)+洒水编号(16)
                rows = [[0,2],[2,2],[4,2],[6,2],[8,2],[10,2],[12,2],[14,1],[15,2]]
            } else {
                // 旧：张紧控制: 6个参数  rows = [[0,1],[1,1],[2,2],[4,1],[5,1]]
                // ✅ 2026-03-22 [Phase 7.48.74]: 开关加入导航+新增停止延时，共9个参数(0-8)
                // ✅ 2026-03-22 [Phase 7.48.80]: 预警/失败语音移出导航，音频来源加入GridLayout Row4，共8个参数(0-7)
                // Row0: 张紧启用(0)+输出通道(1), Row1: 使用反馈(2)+反馈通道(3),
                // Row2: 反馈超时(4)+启动延时(5), Row3: 停止延时(6)+音频来源(7)
                rows = [[0,2],[2,2],[4,2],[6,2]]
            }

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
                else { switchToArea(areaControlList); return }
                break
            case "Right":
                if (colInRow < rows[curRow][1] - 1) { paramIndex = idx + 1 }
                break
            case "Up":
                if (curRow > 0) {
                    var prevRow = rows[curRow - 1]
                    var targetCol = Math.min(colInRow, prevRow[1] - 1)
                    paramIndex = prevRow[0] + targetCol
                } else { switchToArea(areaControlList); return }
                break
            case "Down":
                if (curRow < rows.length - 1) {
                    var nextRow = rows[curRow + 1]
                    var targetCol2 = Math.min(colInRow, nextRow[1] - 1)
                    paramIndex = nextRow[0] + targetCol2
                } else {
                    // ✅ 2026-03-22 [Phase 7.48.80.2]: 恢复Down进入按钮区，按钮已移到独立行
                    switchToArea(areaButtons); buttonIndex = colInRow; return
                }
                break
            }
        }

        // 导航函数：按钮区域（2个按钮：启动/停止）
        // 2026-03-16 [Phase 7.48.47]: 更新为启动/停止按钮（删除旧保存/重置）
        function moveInButtonArea(direction) {
            console.log("✅ [TensionControlPage] moveInButtonArea - direction:", direction, "buttonIndex:", buttonIndex)
            var newIndex = buttonIndex

            switch(direction) {
            case "Left":
                if (buttonIndex > 0) {
                    newIndex = buttonIndex - 1
                } else {
                    switchToArea(areaControlList)
                    return
                }
                break
            case "Right":
                if (buttonIndex < 1) {
                    newIndex = buttonIndex + 1
                }
                break
            case "Up":
                // ✅ 2026-03-22 [Phase 7.48.80.2]: Up从按钮区回到参数区最后行，保持列位置
                // 张力传感器: 最后行[15,2], 张紧控制: 最后行[6,2]
                switchToArea(areaParams)
                if (root.currentControlIndex === 0) {
                    paramIndex = 15 + Math.min(buttonIndex, 1)  // 15(col0) 或 16(col1)
                } else {
                    paramIndex = 6 + Math.min(buttonIndex, 1)   // 6(col0) 或 7(col1)
                }
                return
            }

            if (newIndex !== buttonIndex) {
                console.log("✅ [TensionControlPage] 更新 buttonIndex:", buttonIndex, "→", newIndex)
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

    // ✅ 2026-01-31 [FIX 100.300.112.8]: 使用 NavigationManager 处理键盘事件
    // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式（移除使用状态区域）
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
            if (navigationManager.currentArea === navigationManager.areaParams) {
                tensionControlConfigPanel.item.triggerParamInput(navigationManager.paramIndex)
            } else if (navigationManager.currentArea === navigationManager.areaButtons) {
                tensionControlConfigPanel.item.triggerButton(navigationManager.buttonIndex)
            }
            event.accepted = true
            return
        default:
            return
        }

        // 根据当前区域调用对应的导航函数
        switch(navigationManager.currentArea) {
        case navigationManager.areaControlList:
            navigationManager.moveInListArea(direction)
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

    // ✅ 2026-03-18 [Phase 7.48.53]: 添加保存转发函数，供DeviceSettingsDialog保存按钮调用
    function saveTensionControlConfig() {
        if (tensionControlConfigPanel.item && typeof tensionControlConfigPanel.item.saveTensionControlConfig === "function") {
            tensionControlConfigPanel.item.saveTensionControlConfig()
        }
    }

    // ✅ 2026-03-22 [Phase 7.48.77]: 添加triggerParamInput转发函数，供DeviceSettingsDialog回车键调用
    function triggerParamInput(paramIndex) {
        console.log("✅ [TensionControlPage] 触发参数输入 - 索引:", paramIndex)
        if (tensionControlConfigPanel.item && typeof tensionControlConfigPanel.item.triggerParamInput === "function") {
            tensionControlConfigPanel.item.triggerParamInput(paramIndex)
        } else {
            console.log("⚠️ [TensionControlPage] ConfigPanel 不支持参数输入")
        }
    }

    // ✅ 2026-03-22 [Phase 7.48.77]: 添加triggerButton转发函数，供DeviceSettingsDialog回车键调用
    function triggerButton(buttonIndex) {
        console.log("✅ [TensionControlPage] 触发按钮 - 索引:", buttonIndex)
        if (tensionControlConfigPanel.item && typeof tensionControlConfigPanel.item.triggerButton === "function") {
            tensionControlConfigPanel.item.triggerButton(buttonIndex)
        } else {
            console.log("⚠️ [TensionControlPage] ConfigPanel 不支持按钮触发")
        }
    }

    // ✅ 2026-01-31 [FIX 100.300.112.8]: 处理键盘事件（供 DeviceSettingsDialog 调用）
    // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式（移除使用状态区域）
    function handleKeyPress(direction) {
        console.log("✅ [TensionControlPage] handleKeyPress - direction:", direction)

        // 根据当前区域调用对应的导航函数
        switch(navigationManager.currentArea) {
        case navigationManager.areaControlList:
            navigationManager.moveInListArea(direction)
            break
        case navigationManager.areaParams:
            navigationManager.moveInParamArea(direction)
            break
        case navigationManager.areaButtons:
            navigationManager.moveInButtonArea(direction)
            break
        }
    }

    // ========== 左右分栏布局 ==========
    Row {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧：控制列表（使用Loader加载）==========
        Loader {
            id: tensionControlListPanel
            // ✅ 2026-01-27 [FIX 100.300.35]: 宽度减少到80%（240px → 192px）
            width: 192
            height: parent.height
            source: "TensionControlListPanel.qml"

            onLoaded: {
                // ✅ 2026-01-31 [FIX 100.300.112.8]: 绑定到 navigationManager.controlListIndex
                item.currentControlIndex = Qt.binding(function() { return navigationManager.controlListIndex })
                // ✅ 2026-01-31 [FIX 100.300.112.8]: 传递焦点索引
                item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                // ✅ 2026-01-31 [FIX 100.300.112.8]: 传递焦点子区域
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.controlSelected.connect(function(controlIndex) {
                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.16]: 鼠标点击时同步所有焦点状态
                    console.log("🔍 [TensionControlPage] 鼠标点击控制:", controlIndex)
                    root.currentControlIndex = controlIndex
                    root.focusItemIndex = controlIndex
                    root.focusSubArea = 0  // 确保在列表区域
                    navigationManager.controlListIndex = controlIndex
                    console.log("选中控制:", controlIndex === 0 ? "张力传感器" : "独立张紧控制")
                })
            }
        }

        // ========== 分隔线 ==========
        Rectangle {
            width: 2
            height: parent.height
            color: "#3d4556"
        }

        // ========== 右侧：控制配置面板（使用Loader加载）==========
        // 2026-03-17 [Phase 7.48.51]: 动态切换source，0→TensionSensorConfigPanel, 1→TensionControlConfigPanel
        Loader {
            id: tensionControlConfigPanel
            width: parent.width - tensionControlListPanel.width - 2
            height: parent.height
            source: root.currentControlIndex === 0 ? "TensionSensorConfigPanel.qml" : "TensionControlConfigPanel.qml"

            onLoaded: {
                item.deviceId = Qt.binding(function() { return root.deviceId })  // ✅ 2026-02-06 [参数持久化]: 传递设备ID
                item.controlIndex = Qt.binding(function() { return root.currentControlIndex })
                // ✅ 2026-01-31 [FIX 100.300.112.8]: 传递焦点索引和虚拟键盘
                // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 移除 usageStatusIndex（无使用状态区域）
                item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                item.focusButtonIndex = Qt.binding(function() { return root.focusButtonIndex })
                item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
            }
        }
    }
}
