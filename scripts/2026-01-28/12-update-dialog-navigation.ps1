# UTF-8 with BOM
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# FIX 100.300.101 - 更新 DeviceSettingsDialog.qml 导航系统
# 日期: 2026-01-28

$filePath = "e:\2025\3_gongkongji\belt_control_system\src\qml\components\device_info\DeviceSettingsDialog.qml"

Write-Host "✅ 开始修改 DeviceSettingsDialog.qml..." -ForegroundColor Green

# 读取文件内容
$content = Get-Content $filePath -Raw -Encoding UTF8

# 1. 添加新的属性（在 Line 65 之后）
$oldProperties = @"
    property int currentBottomButtonIndex: 0      // ✅ 2026-01-24 [FIX]: 当前选中的底部按钮索引

    // ✅ 2026-01-28 [虚拟键盘管理器]: 创建键盘管理器实例
"@

$newProperties = @"
    property int currentBottomButtonIndex: 0      // ✅ 2026-01-24 [FIX]: 当前选中的底部按钮索引

    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统
    property int currentFocusArea: 1              // 当前焦点区域 (0:顶部 1:左侧类别 2:右侧内容 3:底部)
    property int currentTopButtonIndex: 0         // 顶部按钮索引 (0:关闭 1:保存 2:重置)
    property int currentContentItemIndex: 0       // 右侧内容区域当前焦点项索引

    // ✅ 2026-01-28 [虚拟键盘管理器]: 创建键盘管理器实例
"@

$content = $content.Replace($oldProperties, $newProperties)

# 2. 替换键盘事件处理（Line 93-136）
$oldKeyHandlers = @"
    Keys.onUpPressed: {
        // 上键：选择上一个类别
        if (root.currentCategory > 0) {
            root.currentCategory--
            root.currentBottomButtonIndex = 0  // 重置底部按钮索引
        }
    }

    Keys.onDownPressed: {
        // 下键：选择下一个类别
        if (root.currentCategory < 6) {  // ✅ 2026-01-24 [FIX]: 7个类别 (0-6)
            root.currentCategory++
            root.currentBottomButtonIndex = 0  // 重置底部按钮索引
        }
    }

    Keys.onLeftPressed: {
        // 左键：选择上一个底部按钮
        var bottomButtons = getBottomButtons(root.currentCategory)
        if (bottomButtons.length > 0 && root.currentBottomButtonIndex > 0) {
            root.currentBottomButtonIndex--
        }
    }

    Keys.onRightPressed: {
        // 右键：选择下一个底部按钮
        var bottomButtons = getBottomButtons(root.currentCategory)
        if (bottomButtons.length > 0 && root.currentBottomButtonIndex < bottomButtons.length - 1) {
            root.currentBottomButtonIndex++
        }
    }

    Keys.onReturnPressed: {
        // 回车键：触发当前选中的底部按钮
        var bottomButtons = getBottomButtons(root.currentCategory)
        if (bottomButtons.length > 0 && root.currentBottomButtonIndex < bottomButtons.length) {
            console.log("触发底部按钮:", bottomButtons[root.currentBottomButtonIndex])
        }
    }
"@

$newKeyHandlers = @"
    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统
    Keys.onLeftPressed: {
        // 左键：切换到左侧区域
        console.log("✅ [导航] 左键 - 当前区域:", currentFocusArea)

        switch(currentFocusArea) {
        case 0:  // 顶部按钮 → 底部按钮（循环）
            currentFocusArea = 3
            break
        case 1:  // 左侧类别 → 顶部按钮
            currentFocusArea = 0
            break
        case 2:  // 右侧内容 → 左侧类别
            currentFocusArea = 1
            break
        case 3:  // 底部按钮 → 右侧内容
            currentFocusArea = 2
            break
        }

        console.log("✅ [导航] 左键后区域:", currentFocusArea)
    }

    Keys.onRightPressed: {
        // 右键：切换到右侧区域
        console.log("✅ [导航] 右键 - 当前区域:", currentFocusArea)

        switch(currentFocusArea) {
        case 0:  // 顶部按钮 → 左侧类别
            currentFocusArea = 1
            break
        case 1:  // 左侧类别 → 右侧内容
            currentFocusArea = 2
            currentContentItemIndex = 0  // 重置内容区域索引
            break
        case 2:  // 右侧内容 → 底部按钮
            currentFocusArea = 3
            break
        case 3:  // 底部按钮 → 左侧类别（循环）
            currentFocusArea = 1
            break
        }

        console.log("✅ [导航] 右键后区域:", currentFocusArea)
    }

    Keys.onUpPressed: {
        // 上键：在当前区域内向上导航
        console.log("✅ [导航] 上键 - 当前区域:", currentFocusArea)

        switch(currentFocusArea) {
        case 0:  // 顶部按钮
            if (currentTopButtonIndex > 0) {
                currentTopButtonIndex--
            }
            break
        case 1:  // 左侧类别
            if (currentCategory > 0) {
                currentCategory--
            }
            break
        case 2:  // 右侧内容
            if (currentContentItemIndex > 0) {
                currentContentItemIndex--
            }
            break
        case 3:  // 底部按钮
            if (currentBottomButtonIndex > 0) {
                currentBottomButtonIndex--
            }
            break
        }
    }

    Keys.onDownPressed: {
        // 下键：在当前区域内向下导航
        console.log("✅ [导航] 下键 - 当前区域:", currentFocusArea)

        switch(currentFocusArea) {
        case 0:  // 顶部按钮（3个按钮：关闭、保存、重置）
            if (currentTopButtonIndex < 2) {
                currentTopButtonIndex++
            }
            break
        case 1:  // 左侧类别（7个类别）
            if (currentCategory < 6) {
                currentCategory++
            }
            break
        case 2:  // 右侧内容
            var maxIndex = getContentItemCount(currentCategory)
            if (currentContentItemIndex < maxIndex - 1) {
                currentContentItemIndex++
            }
            break
        case 3:  // 底部按钮
            var bottomButtons = getBottomButtons(currentCategory)
            if (currentBottomButtonIndex < bottomButtons.length - 1) {
                currentBottomButtonIndex++
            }
            break
        }
    }

    Keys.onReturnPressed: {
        // 回车键：根据当前区域执行不同操作
        console.log("✅ [导航] 回车键 - 当前区域:", currentFocusArea)

        switch(currentFocusArea) {
        case 0:  // 顶部按钮：触发按钮点击
            triggerTopButton(currentTopButtonIndex)
            break
        case 1:  // 左侧类别：切换类别（已自动切换，无需额外操作）
            console.log("✅ [导航] 当前类别:", getCategoryName(currentCategory))
            break
        case 2:  // 右侧内容：弹出虚拟键盘（如果是输入框）
            triggerContentItem(currentCategory, currentContentItemIndex)
            break
        case 3:  // 底部按钮：触发按钮点击
            var bottomButtons = getBottomButtons(currentCategory)
            if (currentBottomButtonIndex < bottomButtons.length) {
                console.log("✅ [导航] 触发底部按钮:", bottomButtons[currentBottomButtonIndex])
            }
            break
        }
    }
"@

$content = $content.Replace($oldKeyHandlers, $newKeyHandlers)

# 3. 添加辅助函数（在 getBottomButtons 函数之后）
$oldFunctionEnd = @"
        default:
            return []
        }
    }
        }  // Rectangle (root)
    }  // FocusScope (dialogFocusScope)
}  // Item (modalContainer)
"@

$newFunctionEnd = @"
        default:
            return []
        }
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 获取右侧内容区域的可聚焦项数量
    function getContentItemCount(categoryIndex) {
        switch(categoryIndex) {
        case 0:  // 基本配置
            return 5  // 示例：5个输入项
        case 1:  // 开关量输入
            return 9  // 9个输入组件
        case 2:  // 模拟量输入
            return 13  // 13个输入组件
        case 3:  // 电机控制
            return 3  // 基本配置 Tab 有 3 个 SpinBox
        case 4:  // 制动器控制
            return 9  // 9个输入组件
        case 5:  // 张紧控制
            return 14  // 14个输入组件
        case 6:  // 逻辑控制
            return 0  // 待实现
        default:
            return 0
        }
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 触发顶部按钮
    function triggerTopButton(buttonIndex) {
        switch(buttonIndex) {
        case 0:  // 关闭
            console.log("✅ [导航] 触发：关闭")
            root.visible = false
            break
        case 1:  // 保存
            console.log("✅ [导航] 触发：保存")
            // 保存逻辑（待实现）
            break
        case 2:  // 重置
            console.log("✅ [导航] 触发：重置")
            // 重置逻辑（待实现）
            break
        }
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 触发右侧内容区域的项
    function triggerContentItem(categoryIndex, itemIndex) {
        console.log("✅ [导航] 触发内容项 - 类别:", categoryIndex, "索引:", itemIndex)

        // 通知当前页面触发指定索引的输入组件
        // 每个页面需要实现 triggerInputItem(index) 方法
        var currentPage = getCurrentPage(categoryIndex)
        if (currentPage && typeof currentPage.triggerInputItem === "function") {
            currentPage.triggerInputItem(itemIndex)
        } else {
            console.warn("⚠️ [导航] 当前页面未实现 triggerInputItem 方法")
        }
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 获取当前页面实例
    function getCurrentPage(categoryIndex) {
        switch(categoryIndex) {
        case 0:
            return basicConfigPageLoader.item
        case 1:
            return switchInputPageLoader.item
        case 2:
            return analogInputPageLoader.item
        case 3:
            return motorControlPageLoader.item
        case 4:
            return brakeControlPageLoader.item
        case 5:
            return tensionControlPageLoader.item
        case 6:
            return null  // 逻辑控制待实现
        default:
            return null
        }
    }
        }  // Rectangle (root)
    }  // FocusScope (dialogFocusScope)
}  // Item (modalContainer)
"@

$content = $content.Replace($oldFunctionEnd, $newFunctionEnd)

# 写入文件
$content | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline

Write-Host "✅ DeviceSettingsDialog.qml 修改完成！" -ForegroundColor Green
Write-Host ""
Write-Host "修改内容：" -ForegroundColor Cyan
Write-Host "  1. 添加了 3 个新属性（currentFocusArea, currentTopButtonIndex, currentContentItemIndex）" -ForegroundColor Yellow
Write-Host "  2. 重写了键盘事件处理（左右键切换区域，上下键区域内导航）" -ForegroundColor Yellow
Write-Host "  3. 添加了 4 个辅助函数（getContentItemCount, triggerTopButton, triggerContentItem, getCurrentPage）" -ForegroundColor Yellow
