import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo  // ✅ 2026-01-25 [工业科技感设计]: 导入主题
import "../virtual_keyboard" as VirtualKeyboard  // ✅ 2026-01-28 [虚拟键盘]: 导入虚拟键盘组件

// ✅ 2026-01-24 [设备信息界面重构] 设备参数设置弹窗
// ✅ 2026-01-25 [工业科技感设计]: 应用 IndustrialTheme
// ✅ 2026-01-28 [FIX 100.300.66]: 自适应屏幕尺寸（1920×1080 和 1280×800），居中显示
// ✅ 2026-01-28 [FIX 100.300.67]: 修改尺寸为屏幕的 80%
// ✅ 2026-01-28 [虚拟键盘集成]: 集成虚拟键盘管理器
// ✅ 2026-01-28 [FIX 100.300.99]: 强化焦点管理，使用延迟获取焦点和 z-index（失败）
// ✅ 2026-01-28 [FIX 100.300.100]: 使用 MouseArea 模态遮罩 + FocusScope 强制获取焦点
// QDS 预览版本：使用 Rectangle 替代 Dialog
Item {
    id: modalContainer
    anchors.fill: parent
    z: 1000  // 确保在最顶层

    // ✅ 2026-01-28 [FIX 100.300.100]: 全屏模态遮罩，阻止所有事件传播到主界面
    MouseArea {
        id: modalOverlay
        anchors.fill: parent
        z: 999  // 在对话框下方

        // 阻止所有鼠标事件传播
        onClicked: {
            console.log("✅ [DeviceSettingsDialog] 点击遮罩，强制对话框获取焦点")
            dialogFocusScope.forceActiveFocus()
            mouse.accepted = true
        }
        onPressed: mouse.accepted = true
        onReleased: mouse.accepted = true
        onWheel: wheel.accepted = true
        propagateComposedEvents: false
        hoverEnabled: true

        // 半透明黑色背景
        Rectangle {
            anchors.fill: parent
            color: "#80000000"
        }
    }

    // ✅ 2026-01-28 [FIX 100.300.100]: 使用 FocusScope 创建独立焦点作用域
    FocusScope {
        id: dialogFocusScope
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8
        focus: true  // FocusScope 获取焦点
        z: 1000  // 在遮罩上方

        Rectangle {
            id: root
            anchors.fill: parent
            color: "#ec1e1e1e"
    // ✅ 2026-01-25: 使用主题背景色

    // ========== 公开属性 ==========
    property string deviceName: "1号皮带（预览）"  // 设备名称
    property int deviceId: 1                      // 设备ID
    property int currentCategory: 0               // 当前选中的参数类别
    property int currentBottomButtonIndex: 0      // ✅ 2026-01-24 [FIX]: 当前选中的底部按钮索引

    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统
    property int currentFocusArea: 1              // 当前焦点区域 (0:顶部 1:左侧类别 2:右侧内容 3:底部)
    property int currentTopButtonIndex: 0         // 顶部按钮索引 (0:关闭 1:保存 2:重置)
    property int currentContentItemIndex: 0       // 右侧内容区域当前焦点项索引

    // ✅ 2026-01-29 [Qt 虚拟键盘]: 使用 Qt 自带的虚拟键盘
    VirtualKeyboard.QtVirtualKeyboardIntegration {
        id: qtVirtualKeyboard
        parent: Overlay.overlay  // 显示在最顶层
        z: 2000  // 确保在对话框上方
    }

    // ✅ 2026-01-29 [Qt 虚拟键盘]: 初始化
    // ✅ 2026-01-28 [FIX 100.300.100]: 强制获取焦点
    Component.onCompleted: {
        console.log("✅ [DeviceSettingsDialog] Qt 虚拟键盘已初始化")

        // 强制 FocusScope 和对话框获取焦点
        dialogFocusScope.forceActiveFocus()
        root.forceActiveFocus()
        console.log("✅ [DeviceSettingsDialog] 对话框已获取焦点")
    }

    // ✅ 2026-01-24 [FIX]: 键盘导航支持
    // ✅ 2026-01-28 [FIX 100.300.100]: FocusScope 内的 Rectangle 需要 focus
    focus: true

    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统 - 上下键区域内导航
    // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加参数区域导航支持
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.31]: 实现两列交叉导航和底部按钮导航
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
        case 2:  // 右侧内容 - 检查子区域
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined") {
                if (currentPage.focusSubArea === 0) {
                    // 列表区域：使用 currentContentItemIndex
                    if (currentContentItemIndex > 0) {
                        currentContentItemIndex--
                    }
                } else if (currentPage.focusSubArea === 1) {
                    // ✅ 参数区域：两列交叉导航 - 同列向上移动
                    var currentIndex = currentPage.focusParamIndex
                    var isRightColumn = (currentIndex % 2 === 1)  // 奇数索引 = 右列

                    if (isRightColumn) {
                        // 右列：1→3→5→7，向上移动2步
                        if (currentIndex >= 2) {
                            currentPage.focusParamIndex = currentIndex - 2
                            console.log("✅ [导航] 参数区域右列上移:", currentIndex, "→", currentIndex - 2)
                        } else {
                            console.log("⚠️ [导航] 已到达右列第一个参数")
                        }
                    } else {
                        // 左列：0→2→4→6→8，向上移动2步
                        if (currentIndex >= 2) {
                            currentPage.focusParamIndex = currentIndex - 2
                            console.log("✅ [导航] 参数区域左列上移:", currentIndex, "→", currentIndex - 2)
                        } else {
                            console.log("⚠️ [导航] 已到达左列第一个参数")
                        }
                    }
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 底部按钮区域：上键导航
                    var buttonIndex = currentPage.focusButtonIndex

                    // 按钮布局：第一行(0,1) 第二行(2,3,4)
                    if (buttonIndex >= 2) {
                        // 第二行 → 第一行
                        if (buttonIndex === 2) {
                            currentPage.focusButtonIndex = 0  // 保存 → 添加输入
                        } else if (buttonIndex === 3) {
                            currentPage.focusButtonIndex = 1  // 删除 → 删除输入
                        } else if (buttonIndex === 4) {
                            currentPage.focusButtonIndex = 1  // 重置 → 删除输入
                        }
                        console.log("✅ [导航] 底部按钮上移:", buttonIndex, "→", currentPage.focusButtonIndex)
                    } else {
                        // 第一行 → 返回参数区域
                        currentPage.focusSubArea = 1
                        // 焦点移到参数区域最后一行
                        var paramCount = currentPage.getParamFieldCount()
                        if (buttonIndex === 0) {
                            // 从添加输入返回 → 左列最后一个
                            currentPage.focusParamIndex = (paramCount % 2 === 0) ? paramCount - 2 : paramCount - 1
                        } else {
                            // 从删除输入返回 → 右列最后一个
                            currentPage.focusParamIndex = (paramCount % 2 === 0) ? paramCount - 1 : paramCount - 2
                        }
                        console.log("✅ [导航] 从底部按钮返回参数区域，索引:", currentPage.focusParamIndex)
                    }
                }
            } else {
                // 不支持子区域的页面，使用 currentContentItemIndex
                if (currentContentItemIndex > 0) {
                    currentContentItemIndex--
                }
            }
            break
        case 3:  // 底部按钮
            if (currentBottomButtonIndex > 0) {
                currentBottomButtonIndex--
            }
            break
        }
    }

    // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加参数区域导航支持
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.31]: 实现两列交叉导航和底部按钮导航
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
        case 2:  // 右侧内容 - 检查子区域
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined") {
                if (currentPage.focusSubArea === 0) {
                    // 列表区域：使用 currentContentItemIndex
                    var maxIndex = getContentItemCount(currentCategory)
                    if (currentContentItemIndex < maxIndex - 1) {
                        currentContentItemIndex++
                    }
                } else if (currentPage.focusSubArea === 1) {
                    // ✅ 参数区域：两列交叉导航 - 同列向下移动
                    var currentIndex = currentPage.focusParamIndex
                    var paramCount = currentPage.getParamFieldCount()
                    var isRightColumn = (currentIndex % 2 === 1)  // 奇数索引 = 右列

                    if (isRightColumn) {
                        // 右列：1→3→5→7，向下移动2步
                        var nextIndex = currentIndex + 2
                        if (nextIndex < paramCount) {
                            currentPage.focusParamIndex = nextIndex
                            console.log("✅ [导航] 参数区域右列下移:", currentIndex, "→", nextIndex)
                        } else {
                            // 已到达右列最后一个 → 进入底部按钮区域
                            currentPage.focusSubArea = 2
                            currentPage.focusButtonIndex = 1  // 删除输入（右侧按钮）
                            console.log("✅ [导航] 从参数区域右列进入底部按钮区域")
                        }
                    } else {
                        // 左列：0→2→4→6→8，向下移动2步
                        var nextIndex = currentIndex + 2
                        if (nextIndex < paramCount) {
                            currentPage.focusParamIndex = nextIndex
                            console.log("✅ [导航] 参数区域左列下移:", currentIndex, "→", nextIndex)
                        } else {
                            // 已到达左列最后一个 → 进入底部按钮区域
                            currentPage.focusSubArea = 2
                            currentPage.focusButtonIndex = 0  // 添加输入（左侧按钮）
                            console.log("✅ [导航] 从参数区域左列进入底部按钮区域")
                        }
                    }
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 底部按钮区域：下键导航
                    var buttonIndex = currentPage.focusButtonIndex

                    // 按钮布局：第一行(0,1) 第二行(2,3,4)
                    if (buttonIndex < 2) {
                        // 第一行 → 第二行
                        if (buttonIndex === 0) {
                            currentPage.focusButtonIndex = 2  // 添加输入 → 保存
                        } else if (buttonIndex === 1) {
                            currentPage.focusButtonIndex = 3  // 删除输入 → 删除
                        }
                        console.log("✅ [导航] 底部按钮下移:", buttonIndex, "→", currentPage.focusButtonIndex)
                    } else {
                        console.log("⚠️ [导航] 已到达底部按钮最后一行")
                    }
                }
            } else {
                // 不支持子区域的页面，使用 currentContentItemIndex
                var maxIndex = getContentItemCount(currentCategory)
                if (currentContentItemIndex < maxIndex - 1) {
                    currentContentItemIndex++
                }
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

    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统 - 左右键切换区域
    // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加子区域切换支持
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.31]: 添加底部按钮区域左右导航
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
        case 2:  // 右侧内容 → 检查是否在参数区域或底部按钮区域
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined") {
                if (currentPage.focusSubArea === 1) {
                    // ✅ 参数区域：两列交叉导航
                    var currentIndex = currentPage.focusParamIndex

                    // 两列交叉导航：左列（0,2,4,6,8） vs 右列（1,3,5,7）
                    if (currentIndex % 2 === 1) {
                        // 当前在右列，切换到左列
                        var prevIndex = currentIndex - 1
                        currentPage.focusParamIndex = prevIndex
                        console.log("✅ [导航] 参数区域：右列 → 左列，索引:", currentIndex, "→", prevIndex)
                        return  // 不切换到列表区域
                    } else {
                        // 当前在左列，返回列表区域
                        currentPage.focusSubArea = 0
                        console.log("✅ [导航] 从参数区域返回列表区域")
                        return  // 不切换到左侧类别
                    }
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 底部按钮区域：左键导航
                    var buttonIndex = currentPage.focusButtonIndex

                    // 按钮布局：第一行(0,1) 第二行(2,3,4)
                    if (buttonIndex === 1) {
                        // 删除输入 → 添加输入
                        currentPage.focusButtonIndex = 0
                        console.log("✅ [导航] 底部按钮左移:", buttonIndex, "→", 0)
                        return
                    } else if (buttonIndex === 3) {
                        // 删除 → 保存
                        currentPage.focusButtonIndex = 2
                        console.log("✅ [导航] 底部按钮左移:", buttonIndex, "→", 2)
                        return
                    } else if (buttonIndex === 4) {
                        // 重置 → 删除
                        currentPage.focusButtonIndex = 3
                        console.log("✅ [导航] 底部按钮左移:", buttonIndex, "→", 3)
                        return
                    } else {
                        // 已在最左侧，保持焦点
                        console.log("⚠️ [导航] 已在底部按钮最左侧")
                        return
                    }
                }
            }
            // 否则切换到左侧类别
            currentFocusArea = 1
            break
        case 3:  // 底部按钮 → 右侧内容
            currentFocusArea = 2
            break
        }

        console.log("✅ [导航] 左键后区域:", currentFocusArea)
    }

    // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加子区域切换支持
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.31]: 添加底部按钮区域左右导航
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
        case 2:  // 右侧内容 → 检查当前页面是否支持子区域导航
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined") {
                // 如果当前在列表区域，切换到参数区域
                if (currentPage.focusSubArea === 0) {
                    currentPage.focusSubArea = 1
                    currentPage.focusParamIndex = 0  // 重置参数焦点索引
                    console.log("✅ [导航] 从列表区域切换到参数区域")
                    return  // 不切换到底部按钮
                } else if (currentPage.focusSubArea === 1) {
                    // ✅ 参数区域：两列交叉导航
                    var currentIndex = currentPage.focusParamIndex
                    var paramCount = currentPage.getParamFieldCount()

                    // 两列交叉导航：左列（0,2,4,6,8） vs 右列（1,3,5,7）
                    if (currentIndex % 2 === 0) {
                        // 当前在左列，切换到右列
                        var nextIndex = currentIndex + 1
                        if (nextIndex < paramCount) {
                            currentPage.focusParamIndex = nextIndex
                            console.log("✅ [导航] 参数区域：左列 → 右列，索引:", currentIndex, "→", nextIndex)
                            return  // 不切换到底部按钮
                        }
                    }
                    // 如果当前在右列，或者右列没有更多控件，则保持焦点
                    console.log("⚠️ [导航] 参数区域已在最右侧")
                    return
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 底部按钮区域：右键导航
                    var buttonIndex = currentPage.focusButtonIndex

                    // 按钮布局：第一行(0,1) 第二行(2,3,4)
                    if (buttonIndex === 0) {
                        // 添加输入 → 删除输入
                        currentPage.focusButtonIndex = 1
                        console.log("✅ [导航] 底部按钮右移:", buttonIndex, "→", 1)
                        return
                    } else if (buttonIndex === 2) {
                        // 保存 → 删除
                        currentPage.focusButtonIndex = 3
                        console.log("✅ [导航] 底部按钮右移:", buttonIndex, "→", 3)
                        return
                    } else if (buttonIndex === 3) {
                        // 删除 → 重置
                        currentPage.focusButtonIndex = 4
                        console.log("✅ [导航] 底部按钮右移:", buttonIndex, "→", 4)
                        return
                    } else {
                        // 已在最右侧，保持焦点
                        console.log("⚠️ [导航] 已在底部按钮最右侧")
                        return
                    }
                }
            }
            // 否则切换到底部按钮
            currentFocusArea = 3
            break
        case 3:  // 底部按钮 → 左侧类别（循环）
            currentFocusArea = 1
            break
        }

        console.log("✅ [导航] 右键后区域:", currentFocusArea)
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统 - 回车键功能
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.32]: 支持子区域的回车键处理
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
        case 2:  // 右侧内容：检查子区域
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined") {
                if (currentPage.focusSubArea === 1) {
                    // ✅ 参数区域：弹出虚拟键盘
                    if (typeof currentPage.triggerParamInput === "function") {
                        currentPage.triggerParamInput(currentPage.focusParamIndex)
                        console.log("✅ [导航] 触发参数输入 - 索引:", currentPage.focusParamIndex)
                    } else {
                        console.warn("⚠️ [导航] 当前页面未实现 triggerParamInput 方法")
                    }
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 底部按钮区域：触发按钮点击
                    if (typeof currentPage.triggerButton === "function") {
                        currentPage.triggerButton(currentPage.focusButtonIndex)
                        console.log("✅ [导航] 触发底部按钮 - 索引:", currentPage.focusButtonIndex)
                    } else {
                        console.warn("⚠️ [导航] 当前页面未实现 triggerButton 方法")
                    }
                } else {
                    // 列表区域：使用旧的 triggerInputItem 方法
                    triggerContentItem(currentCategory, currentContentItemIndex)
                }
            } else {
                // 不支持子区域的页面，使用旧的方法
                triggerContentItem(currentCategory, currentContentItemIndex)
            }
            break
        case 3:  // 底部按钮：触发按钮点击
            var bottomButtons = getBottomButtons(currentCategory)
            if (currentBottomButtonIndex < bottomButtons.length) {
                console.log("✅ [导航] 触发底部按钮:", bottomButtons[currentBottomButtonIndex])
            }
            break
        }
    }

    Keys.onEscapePressed: {
        // Escape 键：关闭弹窗
        root.visible = false
    }

    // ========== 背景图片 ==========
    Image {
        anchors.fill: parent
        source: "images/deviceInfo40.png"
        fillMode: Image.Stretch
        smooth: true
    }

    // ========== 内容区域 ==========
    Item {
        id: item1
        anchors.fill: parent

        // ========== 上部按钮栏 ==========
        // ✅ 2026-01-24 [FIX]: 使用 Rectangle 容器，351.png 作为背景
        Rectangle {
            id: topButtonsContainer
            anchors.top: parent.top
            anchors.left: parent.left  // ✅ 2026-01-24 [FIX]: 左右对齐
            anchors.right: parent.right  // ✅ 2026-01-24 [FIX]: 左右对齐
            anchors.topMargin: 15
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            height: 45
            color: "transparent"

            // ✅ 2026-01-26 [FIX 100.300.25.17]: 添加 MouseArea 阻止点击事件穿透到背景
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 阻止点击事件穿透，不做任何操作
                    mouse.accepted = true
                }
            }

            // ✅ 背景图片 351.png（填充整个宽度）
            Image {
                id: topButtonsBackground
                anchors.fill: parent
                source: "images/351.png"
                fillMode: Image.Stretch
                smooth: true
                z: -1  // ✅ 确保在按钮下方
            }

            // ✅ 设备名称显示（左侧）
            // ✅ 2026-01-25 [工业科技感设计]: 使用直接颜色值
            Text {
                id: deviceNameText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                text: root.deviceName
                font.pixelSize: 18  // ✅ 标题字体
                font.weight: Font.Bold
                color: "#E0E0E0"  // ✅ 浅灰文字
                opacity: 1.0
            }

            // ✅ 按钮行（右侧）
            Row {
                id: topButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 20
                spacing: 20

                // ✅ 2026-01-25 [工业科技感设计]: 关闭按钮
                // ✅ 2026-01-28 [FIX 100.300.101]: 添加焦点指示器
                Button {
                    id: closeButton
                    text: "关闭"
                    width: 80
                    height: 35
                    flat: true
                    background: Rectangle {
                        color: "transparent"
                        border.color: (root.currentFocusArea === 0 && currentTopButtonIndex === 0) ? "#2196F3" : "#3d4556"
                        border.width: (root.currentFocusArea === 0 && currentTopButtonIndex === 0) ? 3 : 2
                        radius: 2
                        opacity: 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#E0E0E0"  // ✅ 浅灰文字
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    onClicked: {
                        // ✅ 2026-01-24: 关闭弹窗
                        root.visible = false
                    }
                }

                // ✅ 2026-01-25 [工业科技感设计]: 保存按钮
                // ✅ 2026-01-28 [FIX 100.300.101]: 添加焦点指示器
                Button {
                    id: saveButton
                    text: "保存"
                    width: 80
                    height: 35
                    flat: true
                    background: Rectangle {
                        color: "#2196F3"  // ✅ 科技蓝背景
                        border.color: (root.currentFocusArea === 0 && currentTopButtonIndex === 1) ? "#FFFFFF" : "#42A5F5"
                        border.width: (root.currentFocusArea === 0 && currentTopButtonIndex === 1) ? 3 : 1
                        radius: 2
                        opacity: 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"  // ✅ 白色文字
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    onClicked: {
                        // ✅ 2026-01-24: 保存参数（待实现）
                        console.log("保存参数")
                    }
                }

                // ✅ 2026-01-25 [工业科技感设计]: 重置按钮
                // ✅ 2026-01-28 [FIX 100.300.101]: 添加焦点指示器
                Button {
                    id: resetButton
                    text: "重置"
                    width: 80
                    height: 35
                    flat: true
                    background: Rectangle {
                        color: "#FF9800"  // ✅ 橙色背景
                        border.color: (root.currentFocusArea === 0 && currentTopButtonIndex === 2) ? "#FFFFFF" : "#FF9800"
                        border.width: (root.currentFocusArea === 0 && currentTopButtonIndex === 2) ? 3 : 1
                        radius: 2
                        opacity: 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"  // ✅ 白色文字
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: 1.0
                    }
                    onClicked: {
                        // ✅ 2026-01-24: 重置参数（待实现）
                        console.log("重置参数")
                    }
                }
            }
        }

        // ========== 左侧按钮列 ==========
        // ✅ 2026-01-24 [FIX 100.301]: 使用 Rectangle 容器，042.png 作为背景
        Rectangle {
            id: leftButtonsContainer
            anchors.left: parent.left

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 0
            anchors.topMargin: 65
            anchors.bottomMargin: 8
            width: 142
            color: "transparent"

            // ✅ 2026-01-26 [FIX 100.300.25.17]: 添加 MouseArea 阻止点击事件穿透到背景
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 阻止点击事件穿透，不做任何操作
                    mouse.accepted = true
                }
            }

            // ✅ 背景图片 042.png（使用 Image 作为背景）
            Image {
                id: leftButtonsBackground
                anchors.fill: parent
                anchors.rightMargin: 8
                source: "images/042.png"
                fillMode: Image.Stretch  // ✅ 2026-01-24 [FIX]: 拉伸填充整个区域
                smooth: true
                z: -1  // ✅ 确保在按钮下方
            }

            // ✅ 按钮列（在背景图片上方）
            Column {
                id: leftButtons
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 8
                anchors.rightMargin: 0
                anchors.topMargin: 13
                spacing: 10

                Repeater {
                    model: ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "逻辑控制"]

                    Button {
                        width: parent.width - 20
                        height: 40
                        text: modelData
                        // ✅ 2026-01-25 [工业科技感设计]: 禁用默认样式
                        flat: true

                        background: Rectangle {
                            // ✅ 2026-01-26 [FIX 100.300.25.6]: 改为透明，使用背景图片
                            // ✅ 2026-01-28 [FIX 100.300.101]: 只在焦点区域为1时显示焦点指示器
                            // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.5]: 使用 root.currentFocusArea 避免 ReferenceError
                            color: "transparent"
                            border.color: (root.currentFocusArea === 1 && root.currentCategory === index) ? "#2196F3" : "#3d4556"
                            border.width: (root.currentFocusArea === 1 && root.currentCategory === index) ? 3 : 1
                            radius: 2
                            opacity: 1.0

                            // ✅ 2026-01-26 [FIX 100.300.25.6]: 添加背景图片
                            Image {
                                id: buttonBackgroundImage
                                anchors.fill: parent
                                fillMode: Image.Stretch
                                z: -1  // 放在最底层

                                // 使用相对路径，便于QDS预览
                                source: "../../images/dvList.png"

                                states: [
                                    State {
                                        name: "selected"
                                        when: root.currentCategory === index
                                        PropertyChanges {
                                            target: buttonBackgroundImage
                                            source: "../../images/dvList2.png"
                                        }
                                    },
                                    State {
                                        name: "normal"
                                        when: root.currentCategory !== index
                                        PropertyChanges {
                                            target: buttonBackgroundImage
                                            source: "../../images/dvList.png"
                                        }
                                    }
                                ]
                            }

                            // ✅ 2026-01-25 [工业科技感设计]: 激活状态左侧强调条
                            // ✅ 2026-01-28 [FIX 100.300.101]: 只在焦点区域为1时显示
                            Rectangle {
                                visible: (root.currentFocusArea === 1 && root.currentCategory === index)
                                width: 4
                                height: parent.height
                                color: "#2196F3"
                                anchors.left: parent.left
                            }
                        }

                        contentItem: Text {
                            text: parent.text
                            // ✅ 2026-01-25 [FIX]: 使用直接颜色值以确保 QDS 预览正常
                            color: root.currentCategory === index ? "#E0E0E0" : "#9E9E9E"
                            font.pixelSize: 14
                            font.weight: root.currentCategory === index ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            // ✅ 2026-01-25 [FIX]: 确保文字可见
                            opacity: 1.0
                        }

                        // ✅ 2026-01-24 [FIX]: 点击时更新类别和重置底部按钮索引
                        onClicked: {
                            root.currentCategory = index
                            root.currentBottomButtonIndex = 0
                        }
                    }
                }
            }
        }

        // ========== 中间参数显示区域 ==========
        Rectangle {
            id: contentArea
            anchors.left: leftButtonsContainer.right  // ✅ 2026-01-24 [FIX]: 更新锚点引用
            anchors.right: parent.right
            anchors.top: topButtonsContainer.bottom
            anchors.bottom: parent.bottom  // ✅ 2026-01-26 [FIX 100.300.25.8]: 延伸到底部，覆盖底部按钮区域
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            anchors.topMargin: 2
            anchors.bottomMargin: 8
            color: "transparent"  // 透明，显示背景图片

            // ✅ 2026-01-26 [FIX 100.300.25.17]: 添加 MouseArea 阻止点击事件穿透到背景
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // 阻止点击事件穿透，不做任何操作
                    mouse.accepted = true
                }
            }

            // ✅ 2026-01-26 [FIX 100.300.25.7]: 添加背景图片154.png
            Image {
                id: contentAreaBackground
                anchors.fill: parent
                anchors.leftMargin: -14
                anchors.rightMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                source: "../../images/036.png"
                fillMode: Image.Stretch
                z: -1  // 放在最底层，作为所有页面的统一背景
            }

            // ✅ 2026-01-24 [FIX]: 使用 StackLayout 切换页面
            StackLayout {
                id: contentStack
                // ✅ 2026-01-26 [FIX 100.300.25.19]: 移除硬编码高度和无效 anchor
                // 原因：bottomButtonsContainer 不是 StackLayout 的兄弟元素，anchor 无效
                // 解决：使用 anchors.fill + bottomMargin 为底部按钮留出空间
                anchors.fill: parent
                // ✅ 2026-01-26 [FIX 100.300.25.13]: 添加 margins，让内容在背景图片边框内部显示
                anchors.leftMargin: 2
                anchors.rightMargin: 19
                anchors.topMargin: 19
                // ✅ 2026-01-26 [FIX 100.300.25.19]: 为底部按钮留出空间
                // bottomButtonsContainer 高度 60 + bottomMargin 20 - contentArea bottomMargin 8 = 72
                anchors.bottomMargin: 72
                currentIndex: root.currentCategory  // 自动切换页面

                // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加调试输出
                Component.onCompleted: {
                    console.log("✅ [DEBUG] StackLayout 宽度:", width)
                    console.log("✅ [DEBUG] StackLayout 高度:", height)
                    console.log("✅ [DEBUG] StackLayout 子元素数量:", count)
                }

                // 0: 基本配置
                // ✅ 2026-01-24 [FIX 100.302]: 使用 BasicConfigPage 组件
                Loader {
                    id: basicConfigPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 0  // 仅在选中时加载
                    source: "pages/BasicConfigPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] BasicConfigPage 加载成功")
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                            // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                            item.keyboardManager = keyboardManager
                        }
                    }

                    onStatusChanged: {
                        if (basicConfigPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] BasicConfigPage 加载失败")
                        }
                    }
                }

                // 1: 开关量输入
                // ✅ 2026-01-25 [FIX 100.306]: 使用 SwitchInputPage 组件
                Loader {
                    id: switchInputPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 1  // 仅在选中时加载
                    source: "pages/SwitchInputPage.qml"

                    // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加调试输出
                    Component.onCompleted: {
                        console.log("✅ [DEBUG] SwitchInputPage Loader 宽度:", width)
                        console.log("✅ [DEBUG] SwitchInputPage Loader 高度:", height)
                    }

                    onLoaded: {
                        console.log("✅ [DEBUG] onLoaded 开始")
                        if (item) {
                            // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.21]: 恢复属性设置
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                            // ✅ 2026-01-29 [Qt 虚拟键盘]: keyboardManager 已废弃，注释掉
                            // item.keyboardManager = keyboardManager
                            // ✅ 2026-01-29 [Qt 虚拟键盘]: 设置父对话框引用
                            item.parentDialog = root
                            console.log("✅ [DEBUG] 设置 parentDialog:", root)
                            console.log("✅ [DEBUG] root.qtVirtualKeyboard:", root.qtVirtualKeyboard)

                            // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.21]: 设置初始焦点状态
                            // 当焦点在内容区域（区域2）且当前类别是开关量输入时
                            if (root.currentFocusArea === 2 && root.currentCategory === 1) {
                                item.focusSubArea = 0  // 默认焦点在列表区域
                                item.focusItemIndex = root.currentContentItemIndex
                            }
                        }
                        Qt.callLater(function() {
                            console.log("✅ [DEBUG] Qt.callLater 回调执行 - 事件循环正常")
                        })
                        console.log("✅ [DEBUG] onLoaded 完成")
                    }

                    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.9]: 使用 Connections 代替动态绑定
                    // 避免绑定循环导致事件循环阻塞
                    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.21]: 重新启用 Connections，修复焦点同步
                    Connections {
                        target: root
                        enabled: switchInputPageLoader.item !== null

                        function onCurrentFocusAreaChanged() {
                            if (switchInputPageLoader.item && root.currentCategory === 1) {
                                if (root.currentFocusArea === 2) {
                                    // 焦点进入内容区域，默认在列表区域
                                    switchInputPageLoader.item.focusSubArea = 0
                                    switchInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
                                } else {
                                    // 焦点离开内容区域，清除焦点
                                    switchInputPageLoader.item.focusItemIndex = -1
                                }
                            }
                        }

                        function onCurrentCategoryChanged() {
                            if (switchInputPageLoader.item) {
                                if (root.currentFocusArea === 2 && root.currentCategory === 1) {
                                    // 切换到开关量输入类别，设置焦点
                                    switchInputPageLoader.item.focusSubArea = 0
                                    switchInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
                                } else {
                                    // 切换到其他类别，清除焦点
                                    switchInputPageLoader.item.focusItemIndex = -1
                                }
                            }
                        }

                        function onCurrentContentItemIndexChanged() {
                            if (switchInputPageLoader.item &&
                                root.currentFocusArea === 2 &&
                                root.currentCategory === 1) {
                                // 在开关量列表中导航
                                switchInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            }
                        }
                    }

                    onStatusChanged: {
                        if (switchInputPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] SwitchInputPage 加载失败")
                        }
                    }
                }

                // 2: 模拟量输入
                // ✅ 2026-01-25 [FIX 100.308]: 使用 AnalogInputPage 组件
                Loader {
                    id: analogInputPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 2  // 仅在选中时加载
                    source: "pages/AnalogInputPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] AnalogInputPage 加载成功")
                            // ✅ 2026-01-28 [FIX 100.300.73.2]: 移除 Qt.binding()，使用 anchors.fill 方案
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                            // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                            item.keyboardManager = keyboardManager
                        }
                    }

                    onStatusChanged: {
                        if (analogInputPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] AnalogInputPage 加载失败")
                        }
                    }
                }

                // 3: 电机控制
                // ✅ 2026-01-25 [FIX 100.310]: 使用 MotorControlPage 组件
                Loader {
                    id: motorControlPageLoader
                    // ✅ 2026-01-26 [FIX 100.300.25.11]: 为 Loader 设置明确尺寸，便于 QDS 预览
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 3  // 仅在选中时加载
                    source: "pages/MotorControlPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] MotorControlPage 加载成功")
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                            // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                            item.keyboardManager = keyboardManager
                        }
                    }

                    onStatusChanged: {
                        if (motorControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] MotorControlPage 加载失败")
                        }
                    }
                }

                // 4: 制动器控制
                // ✅ 2026-01-28 [FIX 100.300.84]: 使用 BrakeControlPage 组件
                Loader {
                    id: brakeControlPageLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 4  // 仅在选中时加载
                    source: "pages/BrakeControlPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] BrakeControlPage 加载成功")
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                            // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                            item.keyboardManager = keyboardManager
                        }
                    }

                    onStatusChanged: {
                        if (brakeControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] BrakeControlPage 加载失败")
                        }
                    }
                }

                // 5: 张紧控制
                // ✅ 2026-01-28 [FIX 100.300.88]: 使用 TensionControlPage 组件
                Loader {
                    id: tensionControlPageLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentCategory === 5  // 仅在选中时加载
                    source: "pages/TensionControlPage.qml"

                    onLoaded: {
                        if (item) {
                            console.log("✅ [DeviceSettingsDialog] TensionControlPage 加载成功")
                            item.deviceId = root.deviceId
                            item.deviceName = root.deviceName
                            // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                            item.keyboardManager = keyboardManager
                        }
                    }

                    onStatusChanged: {
                        if (tensionControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] TensionControlPage 加载失败")
                        }
                    }
                }

                // 6: 逻辑控制
                Rectangle {
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "逻辑控制\n（待实现）"
                        font.pixelSize: 18
                        color: "#CCCCCC"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // ========== 底部按钮区域 ==========
        // ✅ 2026-01-24 [FIX]: 根据左侧选择的类别动态显示不同的按钮
        Rectangle {
            id: bottomButtonsContainer
            anchors.left: leftButtonsContainer.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottomMargin: 20
            height: 60
            color: "transparent"

            // ✅ 按钮行（根据 currentCategory 动态显示）
            Row {
                id: bottomButtons
                anchors.centerIn: parent
                spacing: 20

                // ✅ 2026-01-24: 使用 Repeater 根据类别动态生成按钮
                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.7]: 使用 root.getBottomButtons 避免 ReferenceError
                Repeater {
                    model: root.getBottomButtons(root.currentCategory)

                    Button {
                        text: modelData
                        width: 100
                        height: 40
                        background: Rectangle {
                            // ✅ 2026-01-24 [FIX]: 选中状态高亮
                            // ✅ 2026-01-28 [FIX 100.300.101]: 只在焦点区域为3时显示焦点指示器
                            color: (root.currentFocusArea === 3 && root.currentBottomButtonIndex === index) ? "#00AA00" : "#555555"
                            border.color: (root.currentFocusArea === 3 && root.currentBottomButtonIndex === index) ? "#2196F3" : "#888888"
                            border.width: (root.currentFocusArea === 3 && root.currentBottomButtonIndex === index) ? 3 : 1
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.bold: root.currentBottomButtonIndex === index  // ✅ 选中时加粗
                        }
                        onClicked: {
                            root.currentBottomButtonIndex = index  // ✅ 点击时更新选中索引
                            console.log("底部按钮点击:", modelData)
                        }
                    }
                }
            }
        }
    }

    // ========== 辅助函数 ==========
    function getCategoryName(index) {
        var names = ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "逻辑控制"]
        return names[index] || "未知类别"
    }

    // ✅ 2026-01-24 [FIX]: 根据类别返回底部按钮列表
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.30]: 删除开关量输入和模拟量输入的底部按钮
    // 原因：这些按钮已经在各自的页面内部实现，避免重复
    function getBottomButtons(categoryIndex) {
        switch(categoryIndex) {
        case 0: // 基本配置
            return ["保存配置", "恢复默认", "导入配置", "导出配置"]
        case 1: // 开关量输入
            return []  // ✅ 按钮已在 SwitchInputPage 内部实现
        case 2: // 模拟量输入
            return []  // ✅ 按钮已在 AnalogInputPage 内部实现
        case 3: // 电机控制
            return ["启动测试", "停止测试", "参数校验"]
        case 4: // 制动器控制
            return ["制动测试", "释放测试", "参数校验"]
        case 5: // 张紧控制
            return ["张紧测试", "释放测试", "参数校验"]
        case 6: // 逻辑控制
            return ["添加逻辑", "删除逻辑", "测试逻辑"]
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
