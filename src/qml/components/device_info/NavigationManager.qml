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
    property int tabIndex: 0                       // 区域B：Tab索引（动态范围，取决于页面）
    property int paramIndex: 0                     // 区域C：参数索引（动态范围，取决于当前Tab）
    property int buttonIndex: 0                    // 区域D：按钮索引（0-2，共3个按钮：保存/删除/重置）

    // ✅ 2026-02-07 [Phase 7.39.11]: 添加 lastMotorIndex 属性
    // 不同页面有不同的列表项数量：
    // - 电机控制页面：8个电机（0-7），lastMotorIndex=7
    // - 串口控制页面：6个串口（0-5），lastMotorIndex=5
    // - CAN控制页面：2个CAN接口（0-1），lastMotorIndex=1
    property int lastMotorIndex: 7  // 默认为7（电机控制页面）

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.3]: 添加 lastTabIndex 属性
    // 不同页面有不同的Tab数量：
    // - 电机控制页面：10个Tab（0-9），lastTabIndex=9
    // - 串口控制页面：4个Tab（0-3），lastTabIndex=3
    property int lastTabIndex: 9  // 默认为9（电机控制页面）

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.12]: 是否跳过Tab区域（串口控制页面没有Tab）
    property bool skipTabArea: false               // 默认false（电机控制有Tab），串口控制设置为true

    // ✅ 2026-02-08 [Phase 7.43.8]: 是否跳过按钮区域（MQTT页面没有底部按钮）
    property bool skipButtonArea: false            // 默认false（电机控制有按钮），MQTT设置为true

    // ✅ 2026-03-22 [Phase 7.48.74]: 参数区域列数（默认2列，某些单列面板设为1）
    property int paramColumns: 2

    // ✅ 2026-03-22 [Phase 7.48.74]: 参数区域行映射（可选，用于非均匀网格布局）
    // 格式：[[startIndex, count], ...] — 每行起始索引和该行字段数
    // 为空数组时使用paramColumns均匀网格导航
    property var paramRows: []

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.5]: 监听 paramIndex 变化
    onParamIndexChanged: {
        console.log("🔷 [NavigationManager] paramIndex 变化:", paramIndex)
        console.log("  - currentArea:", currentArea)
        console.log("  - lastParamIndex:", lastParamIndex)
    }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11.3]: 当前Tab的最后一个参数索引
    // ✅ 2026-02-02 [FIX 100.300.112.8.25.5]: 改为动态更新，不再硬编码
    // 不同Tab有不同的参数数量：
    // - 基本配置（Tab 0）：5个参数（0-4），最后索引=4
    // - 电流保护（Tab 1）：11个参数（0-10），最后索引=10
    // - 其他Tab（Tab 2-9）：9个参数（0-8），最后索引=8
    property int lastParamIndex: 4  // 默认为4（初始Tab 0是基本配置）

    // ✅ 2026-02-02 [FIX 100.300.112.8.25.5]: 添加函数来更新lastParamIndex
    function updateLastParamIndex(count) {
        if (count > 0) {
            lastParamIndex = count - 1  // 参数数量-1 = 最后一个参数的索引
            console.log("✅ [NavigationManager] 更新 lastParamIndex:", lastParamIndex, "（参数数量:", count, "）")
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.2]: 移除重复的信号定义
    // QML会自动为每个property生成对应的Changed信号，不需要手动定义
    // 例如：motorListIndex 会自动生成 onMotorListIndexChanged 信号
    // 手动定义会导致 "Duplicate signal name" 错误

    // ========== 自定义信号 ==========
    signal areaChanged(string newArea)  // 区域切换信号（自定义，因为需要传递参数）
    signal returnToCategory()  // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 返回到左侧类别信号

    // ========== 区域切换函数 ==========

    // 切换到指定区域
    function switchToArea(newArea) {
        // ✅ 2026-02-07 [Phase 7.39.11 Debug]: 添加详细调试信息
        console.log("🔍 [NavigationManager.switchToArea] 开始切换")
        console.log("  - 当前区域:", currentArea)
        console.log("  - 目标区域:", newArea)
        console.log("  - areaMotorList:", areaMotorList)
        console.log("  - areaTabBar:", areaTabBar)
        console.log("  - areaParams:", areaParams)
        console.log("  - areaButtons:", areaButtons)

        if (currentArea !== newArea) {
            console.log("✅ [NavigationManager] 切换区域:", currentArea, "→", newArea)
            currentArea = newArea
            areaChanged(newArea)
        } else {
            console.log("⚠️ [NavigationManager] 区域未变化，保持:", currentArea)
        }
    }

    // ========== 区域A：电机列表导航 ==========

    function moveInMotorList(direction) {
        // ✅ 2026-02-07 [Phase 7.39.11 Debug]: 添加详细调试信息
        console.log("🔍 [NavigationManager.moveInMotorList] 开始处理")
        console.log("  - direction:", direction)
        console.log("  - motorListIndex:", motorListIndex)
        console.log("  - lastMotorIndex:", lastMotorIndex)
        console.log("  - skipTabArea:", skipTabArea)
        console.log("  - currentArea:", currentArea)

        var newIndex = motorListIndex

        switch(direction) {
        case "Up":
            if (motorListIndex > 0) {
                newIndex = motorListIndex - 1
            }
            // 在顶部，保持不变
            break

        case "Down":
            // ✅ 2026-02-07 [Phase 7.39.11]: 使用 lastMotorIndex 而不是硬编码的7
            if (motorListIndex < lastMotorIndex) {
                newIndex = motorListIndex + 1
            }
            // 在底部，保持不变
            break

        case "Right":
            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.12]: 根据 skipTabArea 决定跳转目标
            console.log("🔍 [NavigationManager.moveInMotorList] 处理右键")
            console.log("  - skipTabArea:", skipTabArea)

            if (skipTabArea) {
                // 串口控制页面：直接跳转到参数区域
                console.log("✅ [NavigationManager] 从列表跳转到参数区域（跳过Tab）")
                switchToArea(areaParams)
                paramIndex = 0  // 从第一个参数开始
            } else {
                // 电机控制页面：跳转到Tab导航区
                console.log("✅ [NavigationManager] 从列表跳转到Tab导航区")
                console.log("  - 目标区域: areaTabBar")
                console.log("  - 当前 tabIndex:", tabIndex)
                switchToArea(areaTabBar)
            }
            return

        case "Left":
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 向左返回到大类（电机控制）
            // 通过自定义信号通知外部返回到左侧类别
            console.log("✅ [NavigationManager] 返回到类别")
            returnToCategory()
            return
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
            if (tabIndex < lastTabIndex) {  // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.3]: 使用 lastTabIndex 动态限制
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
            // ✅ 2026-02-02 [FIX 100.300.112.8.25.5]: 移除硬编码的lastParamIndex更新
            // lastParamIndex 现在由 MotorControlPage 在 Tab 切换后动态更新
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
        // ✅ 2026-03-22 [Phase 7.48.74]: 支持 paramRows 行映射（非均匀网格布局）
        if (paramRows && paramRows.length > 0) {
            moveInParamAreaByRows(direction)
            return
        }

        var newIndex = paramIndex
        // ✅ 2026-03-22 [Phase 7.48.74]: 使用 paramColumns 代替硬编码2
        var cols = paramColumns

        switch(direction) {
        case "Up":
            if (paramIndex >= cols) {
                newIndex = paramIndex - cols
            } else if (paramIndex < cols) {
                switchToArea(areaTabBar)
                return
            }
            break

        case "Down":
            var nextIndex = paramIndex + cols
            if (nextIndex > lastParamIndex) {
                if (skipButtonArea) {
                    console.log("✅ [NavigationManager] 已在参数区底部，跳过按钮区域")
                    return
                } else {
                    switchToArea(areaButtons)
                    buttonIndex = 0
                    return
                }
            } else {
                newIndex = nextIndex
            }
            break

        case "Left":
            if (cols > 1 && paramIndex % cols > 0) {
                newIndex = paramIndex - 1
            } else {
                if (skipTabArea) {
                    console.log("✅ [NavigationManager] 从参数区返回到模块列表（跳过Tab）")
                    switchToArea(areaMotorList)
                    return
                } else {
                    console.log("✅ [NavigationManager] 从参数区返回到Tab栏")
                    switchToArea(areaTabBar)
                    return
                }
            }
            break

        case "Right":
            if (cols > 1 && paramIndex % cols < cols - 1 && paramIndex < lastParamIndex) {
                newIndex = paramIndex + 1
            }
            break
        }

        if (newIndex !== paramIndex) {
            paramIndex = newIndex
            console.log("✅ [NavigationManager] 参数索引:", newIndex)
        }
    }

    // ✅ 2026-03-22 [Phase 7.48.74]: 基于行映射的参数区域导航（支持非均匀网格）
    // paramRows格式: [[startIdx, colCount], ...] 如 [[0,2],[2,2],[4,1],[5,2]]
    function moveInParamAreaByRows(direction) {
        var idx = paramIndex
        var rows = paramRows
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
            else {
                if (skipTabArea) { switchToArea(areaMotorList) }
                else { switchToArea(areaTabBar) }
                return
            }
            break
        case "Right":
            if (colInRow < rows[curRow][1] - 1) { paramIndex = idx + 1 }
            break
        case "Up":
            if (curRow > 0) {
                var prevRow = rows[curRow - 1]
                var targetCol = Math.min(colInRow, prevRow[1] - 1)
                paramIndex = prevRow[0] + targetCol
            } else { switchToArea(areaTabBar); return }
            break
        case "Down":
            if (curRow < rows.length - 1) {
                var nextRow = rows[curRow + 1]
                var targetCol2 = Math.min(colInRow, nextRow[1] - 1)
                paramIndex = nextRow[0] + targetCol2
            } else {
                if (skipButtonArea) return
                switchToArea(areaButtons)
                buttonIndex = 0
                return
            }
            break
        }
        console.log("✅ [NavigationManager] 参数索引(rows):", paramIndex)
    }

    // ========== 区域D：底部按钮导航 ==========
    // ✅ 2026-03-10 [Phase 7.48.29]: 从5个按钮改为3个按钮（单行）
    // 旧：按钮布局：
    //   第一行：[0] 添加输入  [1] 删除输入
    //   第二行：[2] 保存      [3] 删除      [4] 重置
    // 新：按钮布局（单行）：
    //   [0] 保存  [1] 删除  [2] 重置

    function moveInButtonArea(direction) {
        var newIndex = buttonIndex

        switch(direction) {
        case "Left":
            // 左键：向左移动
            if (buttonIndex > 0) {
                newIndex = buttonIndex - 1
            }
            break

        case "Right":
            // 右键：向右移动
            if (buttonIndex < 2) {
                newIndex = buttonIndex + 1
            }
            break

        case "Up":
            // 向上：返回参数区最后一个参数
            switchToArea(areaParams)
            paramIndex = lastParamIndex
            return

        case "Down":
            // 向下：单行按钮，保持不变
            break
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
