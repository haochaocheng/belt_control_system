import QtQuick 2.15

// ✅ 2026-01-30 [FIX 100.300.109]: 全局导航状态管理器
// ✅ 2026-01-30 [FIX 100.300.109 v2]: 平面导航逻辑 - 只用方向键，不用Enter
// 管理4个导航区域的焦点状态和导航逻辑
QtObject {
    id: navigationManager

    // ========== 导航区域定义 ==========
    readonly property string areaMotorList: "A"    // 电机列表区
    readonly property string areaTabBar: "B"       // Tab导航区
    readonly property string areaParams: "C"       // 参数区域
    readonly property string areaButtons: "D"      // 底部按钮区

    // ========== 当前焦点状态 ==========
    property string currentArea: areaMotorList     // 当前焦点区域
    property int motorListIndex: 0                 // 区域A：电机列表索引（0-7）
    property int tabIndex: 0                       // 区域B：Tab索引（0-8）
    property int paramIndex: 0                     // 区域C：参数索引（0-8）
    property int buttonIndex: 0                    // 区域D：按钮索引（0-2）

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除重复的信号定义
    // QML会自动为每个property生成对应的Changed信号，不需要手动定义
    // 例如：motorListIndex 会自动生成 onMotorListIndexChanged 信号
    // 手动定义会导致 "Duplicate signal name" 错误

    // ========== 自定义信号 ==========
    signal areaChanged(string newArea)  // 区域切换信号（自定义，因为需要传递参数）

    // ========== 区域切换函数 ==========

    // 切换到指定区域
    function switchToArea(newArea) {
        if (currentArea !== newArea) {
            console.log("✅ [NavigationManager] 切换区域:", currentArea, "→", newArea)
            currentArea = newArea
            areaChanged(newArea)
        }
    }

    // ========== 区域A：电机列表导航 ==========

    function moveInMotorList(direction) {
        var newIndex = motorListIndex

        switch(direction) {
        case "Up":
            if (motorListIndex > 0) {
                newIndex = motorListIndex - 1
            }
            // 在顶部，保持不变
            break

        case "Down":
            if (motorListIndex < 7) {
                newIndex = motorListIndex + 1
            }
            // 在底部，保持不变
            break

        case "Right":
            // 向右跳转到Tab导航区
            switchToArea(areaTabBar)
            return

        case "Left":
            // 在左侧边界，保持不变
            break
        }

        if (newIndex !== motorListIndex) {
            motorListIndex = newIndex
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            // motorListIndex 改变时会自动触发 onMotorListIndexChanged 信号
            console.log("✅ [NavigationManager] 电机列表索引:", newIndex)
        }
    }

    // ========== 区域B：Tab导航 ==========

    function moveInTabBar(direction) {
        var newIndex = tabIndex

        switch(direction) {
        case "Left":
            if (tabIndex > 0) {
                newIndex = tabIndex - 1
            } else {
                // 在第一个Tab，向左跳转到电机列表区
                switchToArea(areaMotorList)
                return
            }
            break

        case "Right":
            if (tabIndex < 8) {
                newIndex = tabIndex + 1
            }
            // 在最后一个Tab，保持不变
            break

        case "Up":
            // 在Tab区域，向上保持不变
            break

        case "Down":
            // 向下进入当前Tab对应的参数区第一个参数
            switchToArea(areaParams)
            paramIndex = 0  // 从第一个参数开始
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            return
        }

        if (newIndex !== tabIndex) {
            tabIndex = newIndex
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            console.log("✅ [NavigationManager] Tab索引:", newIndex, "（参数区自动切换显示）")
        }
    }

    // ========== 区域C：参数区域导航（GridLayout 5行×2列）==========

    // 参数索引映射：
    // 行0：[0] 是否投入          [1] 报警类型
    // 行1：[2] 动作保护类型      [3] 故障保护类型
    // 行2：[4] 温度量程          [5] 温度上限
    // 行3：[6] 温度下限          [7] 输入点选择
    // 行4：[8] 过滤干扰延时      [ ] 空

    function moveInParamArea(direction) {
        var newIndex = paramIndex

        switch(direction) {
        case "Up":
            // 向上移动（同列）
            if (paramIndex >= 2) {
                newIndex = paramIndex - 2
            } else if (paramIndex === 0 || paramIndex === 1) {
                // 在第一个参数，向上返回到对应的Tab
                switchToArea(areaTabBar)
                return
            }
            break

        case "Down":
            // 向下移动（同列）
            if (paramIndex <= 5) {
                newIndex = paramIndex + 2
            } else if (paramIndex === 6) {
                newIndex = 8  // 跳转到第5行
            } else if (paramIndex === 7) {
                // 右列最后一个参数，向下进入底部按钮区
                switchToArea(areaButtons)
                buttonIndex = 0
                // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
                return
            } else if (paramIndex === 8) {
                // 左列最后一个参数，向下进入底部按钮区
                switchToArea(areaButtons)
                buttonIndex = 0
                // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
                return
            }
            break

        case "Left":
            // 向左移动（同行）
            if (paramIndex % 2 === 1) {
                newIndex = paramIndex - 1
            }
            // 在左列，保持不变
            break

        case "Right":
            // 向右移动（同行）
            if (paramIndex % 2 === 0 && paramIndex < 8) {
                newIndex = paramIndex + 1
            }
            // 在右列或第5行，保持不变
            break
        }

        if (newIndex !== paramIndex) {
            paramIndex = newIndex
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            console.log("✅ [NavigationManager] 参数索引:", newIndex)
        }
    }

    // ========== 区域D：底部按钮导航 ==========

    function moveInButtonArea(direction) {
        var newIndex = buttonIndex

        switch(direction) {
        case "Left":
            if (buttonIndex > 0) {
                newIndex = buttonIndex - 1
            }
            // 在第一个按钮，保持不变
            break

        case "Right":
            if (buttonIndex < 2) {
                newIndex = buttonIndex + 1
            }
            // 在最后一个按钮，保持不变
            break

        case "Up":
            // 向上返回参数区最后一个参数
            switchToArea(areaParams)
            paramIndex = 8  // 最后一个参数
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            return

        case "Down":
            // 向下循环回参数区最后一个参数
            switchToArea(areaParams)
            paramIndex = 8  // 最后一个参数
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            return
        }

        if (newIndex !== buttonIndex) {
            buttonIndex = newIndex
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除手动信号调用
            console.log("✅ [NavigationManager] 按钮索引:", newIndex)
        }
    }

    // ========== 统一导航入口 ==========

    // 处理方向键
    function handleDirectionKey(direction) {
        console.log("✅ [NavigationManager] 方向键:", direction, "当前区域:", currentArea, "当前索引:", getCurrentIndex())

        switch(currentArea) {
        case areaMotorList:
            moveInMotorList(direction)
            break
        case areaTabBar:
            moveInTabBar(direction)
            break
        case areaParams:
            moveInParamArea(direction)
            break
        case areaButtons:
            moveInButtonArea(direction)
            break
        }
    }

    // ========== 辅助函数 ==========

    // 获取当前区域的索引
    function getCurrentIndex() {
        switch(currentArea) {
        case areaMotorList:
            return motorListIndex
        case areaTabBar:
            return tabIndex
        case areaParams:
            return paramIndex
        case areaButtons:
            return buttonIndex
        default:
            return -1
        }
    }

    // 获取当前焦点的描述信息
    function getCurrentFocusInfo() {
        var info = "区域: " + currentArea

        switch(currentArea) {
        case areaMotorList:
            info += ", 电机: " + (motorListIndex + 1)
            break
        case areaTabBar:
            info += ", Tab: " + tabIndex
            break
        case areaParams:
            info += ", 参数: " + paramIndex
            break
        case areaButtons:
            info += ", 按钮: " + buttonIndex
            break
        }

        return info
    }

    // 重置导航状态
    function reset() {
        currentArea = areaMotorList
        motorListIndex = 0
        tabIndex = 0
        paramIndex = 0
        buttonIndex = 0

        console.log("✅ [NavigationManager] 导航状态已重置")
    }

    // ========== Tab切换时的参数区联动 ==========

    // 当Tab索引改变时，参数区应该自动切换显示对应的参数
    // 这个逻辑由外部（DeviceSettingsDialog）监听tabIndexChanged信号来实现
    // NavigationManager只负责管理焦点状态，不负责UI更新
}
