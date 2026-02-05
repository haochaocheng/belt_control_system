import QtQuick 2.15

// ✅ 2026-01-30 [FIX 100.300.109]: 全局导航状态管理器
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

    // ========== 焦点历史（用于Esc返回）==========
    property var focusHistory: []

    // ========== 信号定义 ==========
    signal areaChanged(string newArea)
    signal motorListIndexChanged(int newIndex)
    signal tabIndexChanged(int newIndex)
    signal paramIndexChanged(int newIndex)
    signal buttonIndexChanged(int newIndex)

    // ========== 区域切换函数 ==========

    // 切换到指定区域
    function switchToArea(newArea) {
        if (currentArea !== newArea) {
            // 保存当前焦点到历史
            focusHistory.push({
                area: currentArea,
                motorListIndex: motorListIndex,
                tabIndex: tabIndex,
                paramIndex: paramIndex,
                buttonIndex: buttonIndex
            })

            console.log("✅ [NavigationManager] 切换区域:", currentArea, "→", newArea)
            currentArea = newArea
            areaChanged(newArea)
        }
    }

    // Tab键：顺序切换区域（A→B→C→D→A）
    function switchToNextArea() {
        switch(currentArea) {
        case areaMotorList:
            switchToArea(areaTabBar)
            break
        case areaTabBar:
            switchToArea(areaParams)
            break
        case areaParams:
            switchToArea(areaButtons)
            break
        case areaButtons:
            switchToArea(areaMotorList)
            break
        }
    }

    // Shift+Tab：反向切换区域（D→C→B→A→D）
    function switchToPreviousArea() {
        switch(currentArea) {
        case areaMotorList:
            switchToArea(areaButtons)
            break
        case areaTabBar:
            switchToArea(areaMotorList)
            break
        case areaParams:
            switchToArea(areaTabBar)
            break
        case areaButtons:
            switchToArea(areaParams)
            break
        }
    }

    // Esc键：返回上一个焦点位置
    function goBack() {
        if (focusHistory.length > 0) {
            var lastFocus = focusHistory.pop()
            currentArea = lastFocus.area
            motorListIndex = lastFocus.motorListIndex
            tabIndex = lastFocus.tabIndex
            paramIndex = lastFocus.paramIndex
            buttonIndex = lastFocus.buttonIndex

            console.log("✅ [NavigationManager] 返回到:", currentArea)
            areaChanged(currentArea)
        } else {
            // 如果没有历史，默认返回到电机列表区
            switchToArea(areaMotorList)
        }
    }

    // ========== 区域A：电机列表导航 ==========

    function moveInMotorList(direction) {
        var newIndex = motorListIndex

        switch(direction) {
        case "Up":
            if (motorListIndex > 0) {
                newIndex = motorListIndex - 1
            } else {
                // 在顶部，跳转到底部按钮区
                switchToArea(areaButtons)
                buttonIndex = 2  // 最后一个按钮
                return
            }
            break

        case "Down":
            if (motorListIndex < 7) {
                newIndex = motorListIndex + 1
            } else {
                // 在底部，跳转到Tab导航区
                switchToArea(areaTabBar)
                return
            }
            break

        case "Right":
            // 向右跳转到Tab导航区
            switchToArea(areaTabBar)
            return
        }

        if (newIndex !== motorListIndex) {
            motorListIndex = newIndex
            motorListIndexChanged(newIndex)
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
                // 循环到最后一个Tab
                newIndex = 8
            }
            break

        case "Right":
            if (tabIndex < 8) {
                newIndex = tabIndex + 1
            } else {
                // 循环到第一个Tab
                newIndex = 0
            }
            break

        case "Up":
            // 向上跳转到电机列表区
            switchToArea(areaMotorList)
            return

        case "Down":
            // 向下跳转到参数区域
            switchToArea(areaParams)
            paramIndex = 0  // 从第一个参数开始
            return
        }

        if (newIndex !== tabIndex) {
            tabIndex = newIndex
            tabIndexChanged(newIndex)
            console.log("✅ [NavigationManager] Tab索引:", newIndex)
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
            } else {
                // 在顶部，跳转到Tab导航区
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
                // 右列底部，跳转到底部按钮区
                switchToArea(areaButtons)
                buttonIndex = 0
                return
            } else if (paramIndex === 8) {
                // 左列底部，跳转到底部按钮区
                switchToArea(areaButtons)
                buttonIndex = 0
                return
            }
            break

        case "Left":
            // 向左移动（同行）
            if (paramIndex % 2 === 1) {
                newIndex = paramIndex - 1
            } else {
                // 在左列，跳转到电机列表区
                switchToArea(areaMotorList)
                return
            }
            break

        case "Right":
            // 向右移动（同行）
            if (paramIndex % 2 === 0 && paramIndex < 8) {
                newIndex = paramIndex + 1
            } else if (paramIndex === 8) {
                // 第5行只有左侧，跳转到底部按钮区
                switchToArea(areaButtons)
                buttonIndex = 0
                return
            }
            // 在右列，保持不变
            break
        }

        if (newIndex !== paramIndex) {
            paramIndex = newIndex
            paramIndexChanged(newIndex)
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
            } else {
                // 循环到最后一个按钮
                newIndex = 2
            }
            break

        case "Right":
            if (buttonIndex < 2) {
                newIndex = buttonIndex + 1
            } else {
                // 循环到第一个按钮
                newIndex = 0
            }
            break

        case "Up":
            // 向上跳转到参数区域
            switchToArea(areaParams)
            paramIndex = 8  // 最后一个参数
            return

        case "Down":
            // 向下跳转到电机列表区
            switchToArea(areaMotorList)
            motorListIndex = 0
            return
        }

        if (newIndex !== buttonIndex) {
            buttonIndex = newIndex
            buttonIndexChanged(newIndex)
            console.log("✅ [NavigationManager] 按钮索引:", newIndex)
        }
    }

    // ========== 统一导航入口 ==========

    // 处理方向键
    function handleDirectionKey(direction) {
        console.log("✅ [NavigationManager] 方向键:", direction, "当前区域:", currentArea)

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

    // 处理Enter键
    function handleEnterKey() {
        console.log("✅ [NavigationManager] Enter键，当前区域:", currentArea)

        switch(currentArea) {
        case areaMotorList:
            console.log("✅ [NavigationManager] 切换到电机:", motorListIndex)
            // 触发电机切换信号（由外部处理）
            break
        case areaTabBar:
            console.log("✅ [NavigationManager] 切换到Tab:", tabIndex)
            // 触发Tab切换信号（由外部处理）
            break
        case areaParams:
            console.log("✅ [NavigationManager] 激活参数:", paramIndex)
            // 触发参数激活信号（由外部处理）
            break
        case areaButtons:
            console.log("✅ [NavigationManager] 执行按钮:", buttonIndex)
            // 触发按钮执行信号（由外部处理）
            break
        }
    }

    // ========== 辅助函数 ==========

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
        focusHistory = []

        console.log("✅ [NavigationManager] 导航状态已重置")
    }
}
