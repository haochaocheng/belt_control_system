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

    // ✅ 2026-01-30 [修复]: 保存真正的父容器引用（Screen01），用于焦点恢复
    // 必须在最外层 Item 上定义，才能在 createObject 时设置
    property var parentContainer: null

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
            objectName: "deviceSettingsDialog"  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 添加 objectName 供 CustomComboBox 查找
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

    // ✅ 2026-01-31 [FIX 100.300.112.8.15]: 为每个类别保存独立的内容索引
    // 避免切换类别时焦点位置丢失
    // ✅ 2026-02-04 [FIX 100.300.113]: 添加串口控制类别
    property var categoryContentIndexMap: ({
        0: 0,  // 基本配置
        1: 0,  // 开关量输入
        2: 0,  // 模拟量输入
        3: 0,  // 电机控制
        4: 0,  // 制动器控制
        5: 0,  // 张紧控制
        6: 0,  // 串口控制
        7: 0   // 逻辑控制
    })

    // ✅ 2026-01-31 [FIX 100.300.112.8.15]: 监听类别切换，保存和恢复内容索引
    onCurrentCategoryChanged: {
        // 保存旧类别的内容索引（如果有的话）
        // 注意：这里不需要保存，因为反向同步已经在更新 categoryContentIndexMap

        // 恢复新类别的内容索引
        var savedIndex = categoryContentIndexMap[currentCategory]
        if (savedIndex !== undefined) {
            console.log("✅ [DeviceSettingsDialog] 切换到类别", currentCategory, "恢复内容索引:", savedIndex)
            currentContentItemIndex = savedIndex
        } else {
            console.log("⚠️ [DeviceSettingsDialog] 类别", currentCategory, "没有保存的索引，使用默认值 0")
            currentContentItemIndex = 0
        }

        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.7]: 移除重新启用逻辑，改为在焦点恢复时启用
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.6]: 重新启用电机控制页面的键盘事件
        // if (currentCategory === 3 && motorControlPageLoader.item) {
        //     console.log("✅ [DeviceSettingsDialog] 重新启用 MotorControlPage 键盘事件")
        //     motorControlPageLoader.item.keysEnabled = true
        // }
    }

    // ✅ 2026-01-31 [FIX 100.300.112.8.15]: 监听内容索引变化，保存到对应类别
    onCurrentContentItemIndexChanged: {
        console.log("✅ [DeviceSettingsDialog] 内容索引变化:", currentContentItemIndex, "类别:", currentCategory)
        // 更新当前类别的内容索引
        var newMap = categoryContentIndexMap
        newMap[currentCategory] = currentContentItemIndex
        categoryContentIndexMap = newMap
    }

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

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.7]: 暂时禁用焦点追踪 Timer
        // 测试 Timer 是否导致焦点丢失
        // focusTracker.start()
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.4]: 焦点追踪 Timer
    Timer {
        id: focusTracker
        interval: 100  // 每100ms检查一次
        running: false
        repeat: true
        property var lastFocusObject: null

        onTriggered: {
            var currentFocus = root.Window.activeFocusItem
            if (currentFocus !== lastFocusObject) {
                console.log("🔍 [焦点追踪] Window.activeFocusItem 变化:", currentFocus)
                if (currentFocus) {
                    console.log("   - objectName:", currentFocus.objectName)
                    console.log("   - toString:", currentFocus.toString())
                }
                lastFocusObject = currentFocus
            }
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 导航处理函数，供 CustomComboBox 直接调用
    function handleNavigationKey(key, event) {
        console.log("✅ [DeviceSettingsDialog] handleNavigationKey 被调用 - key:", key)

        // 根据按键类型调用对应的处理器
        if (key === Qt.Key_Up) {
            console.log("✅ [导航] 上键 - 当前区域:", currentFocusArea, "当前类别:", currentCategory)
            handleUpKey(event)
        } else if (key === Qt.Key_Down) {
            console.log("✅ [导航] 下键 - 当前区域:", currentFocusArea, "当前类别:", currentCategory)
            handleDownKey(event)
        } else if (key === Qt.Key_Left) {
            console.log("✅ [导航] 左键 - 当前区域:", currentFocusArea, "当前类别:", currentCategory)
            handleLeftKey(event)
        } else if (key === Qt.Key_Right) {
            console.log("✅ [导航] 右键 - 当前区域:", currentFocusArea, "当前类别:", currentCategory)
            handleRightKey(event)
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 提取上键处理逻辑
    function handleUpKey(event) {
        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 临时实现 - 直接调用串口控制的 NavigationManager
        // TODO: 后续需要将完整的 Keys.onUpPressed 逻辑移到这里
        console.log("✅ [handleUpKey] 被调用 - currentCategory:", currentCategory, "currentFocusArea:", currentFocusArea)

        // 串口控制页面特殊处理
        if (currentCategory === 6 && currentFocusArea === 2) {
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined" && currentPage.focusSubArea === 1) {
                var serialPage = serialPortControlPageLoader.item
                if (serialPage && serialPage.navigationManager) {
                    console.log("✅ [handleUpKey] 调用 NavigationManager.handleDirectionKey(Up)")
                    serialPage.navigationManager.handleDirectionKey("Up")
                    event.accepted = true
                    return
                }
            }
        }

        // 其他情况：暂时不处理
        console.log("⚠️ [handleUpKey] 未处理的情况")
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 提取下键处理逻辑
    function handleDownKey(event) {
        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 临时实现 - 直接调用串口控制的 NavigationManager
        // TODO: 后续需要将完整的 Keys.onDownPressed 逻辑移到这里
        console.log("✅ [handleDownKey] 被调用 - currentCategory:", currentCategory, "currentFocusArea:", currentFocusArea)

        // 串口控制页面特殊处理
        if (currentCategory === 6 && currentFocusArea === 2) {
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined" && currentPage.focusSubArea === 1) {
                var serialPage = serialPortControlPageLoader.item
                if (serialPage && serialPage.navigationManager) {
                    console.log("✅ [handleDownKey] 调用 NavigationManager.handleDirectionKey(Down)")
                    serialPage.navigationManager.handleDirectionKey("Down")
                    event.accepted = true
                    return
                }
            }
        }

        // 其他情况：暂时不处理
        console.log("⚠️ [handleDownKey] 未处理的情况")
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 提取左键处理逻辑
    function handleLeftKey(event) {
        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 临时实现 - 直接调用串口控制的 NavigationManager
        // TODO: 后续需要将完整的 Keys.onLeftPressed 逻辑移到这里
        console.log("✅ [handleLeftKey] 被调用 - currentCategory:", currentCategory, "currentFocusArea:", currentFocusArea)

        // 串口控制页面特殊处理
        if (currentCategory === 6 && currentFocusArea === 2) {
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined" && currentPage.focusSubArea === 1) {
                var serialPage = serialPortControlPageLoader.item
                if (serialPage && serialPage.navigationManager) {
                    console.log("✅ [handleLeftKey] 调用 NavigationManager.handleDirectionKey(Left)")
                    serialPage.navigationManager.handleDirectionKey("Left")
                    event.accepted = true
                    return
                }
            }
        }

        // 其他情况：暂时不处理
        console.log("⚠️ [handleLeftKey] 未处理的情况")
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 提取右键处理逻辑
    function handleRightKey(event) {
        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 临时实现 - 直接调用串口控制的 NavigationManager
        // TODO: 后续需要将完整的 Keys.onRightPressed 逻辑移到这里
        console.log("✅ [handleRightKey] 被调用 - currentCategory:", currentCategory, "currentFocusArea:", currentFocusArea)

        // 串口控制页面特殊处理
        if (currentCategory === 6 && currentFocusArea === 2) {
            var currentPage = getCurrentPage(currentCategory)
            if (currentPage && typeof currentPage.focusSubArea !== "undefined" && currentPage.focusSubArea === 1) {
                var serialPage = serialPortControlPageLoader.item
                if (serialPage && serialPage.navigationManager) {
                    console.log("✅ [handleRightKey] 调用 NavigationManager.handleDirectionKey(Right)")
                    serialPage.navigationManager.handleDirectionKey("Right")
                    event.accepted = true
                    return
                }
            }
        }

        // 其他情况：暂时不处理
        console.log("⚠️ [handleRightKey] 未处理的情况")
    }

    // ✅ 2026-01-24 [FIX]: 键盘导航支持
    // ✅ 2026-01-28 [FIX 100.300.100]: FocusScope 内的 Rectangle 需要 focus
    focus: true

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.4]: 监听焦点变化
    onActiveFocusChanged: {
        console.log("🔍 [DeviceSettingsDialog root] activeFocus 变化:", activeFocus)
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 电视遥控器式导航系统 - 上下键区域内导航
    // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加参数区域导航支持
    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.31]: 实现两列交叉导航和底部按钮导航
    Keys.onUpPressed: function(event) {
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.4]: 电机控制页面使用NavigationManager
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.10]: 修复 QML 警告 - 声明 event 参数
        // ✅ 2026-01-31 [FIX 100.300.112.7.2]: 制动器控制页面使用NavigationManager
        // ✅ 2026-01-31 [FIX 100.300.112.8]: 张紧控制页面使用NavigationManager
        if (currentCategory === 3 && currentFocusArea === 2) {
            var motorPage = motorControlPageLoader.item
            if (motorPage && typeof motorPage.handleKeyPress === "function") {
                motorPage.handleKeyPress("Up")
                event.accepted = true
                return
            }
        }

        if (currentCategory === 4 && currentFocusArea === 2) {
            var brakePage = brakeControlPageLoader.item
            if (brakePage && typeof brakePage.handleKeyPress === "function") {
                brakePage.handleKeyPress("Up")
                event.accepted = true
                return
            }
        }

        if (currentCategory === 5 && currentFocusArea === 2) {
            var tensionPage = tensionControlPageLoader.item
            if (tensionPage && typeof tensionPage.handleKeyPress === "function") {
                tensionPage.handleKeyPress("Up")
                event.accepted = true
                return
            }
        }

        // 上键：在当前区域内向上导航
        console.log("✅ [导航] 上键 - 当前区域:", currentFocusArea, "当前类别:", currentCategory)

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 5.2]: 添加串口控制详细日志
        if (currentCategory === 6) {
            console.log("🔍 [串口控制调试] 上键 - currentFocusArea:", currentFocusArea)
            console.log("🔍 [串口控制调试] currentContentItemIndex:", currentContentItemIndex)
            var serialPage = serialPortControlPageLoader.item
            if (serialPage) {
                console.log("🔍 [串口控制调试] focusSubArea:", serialPage.focusSubArea)
                console.log("🔍 [串口控制调试] focusItemIndex:", serialPage.focusItemIndex)
                console.log("🔍 [串口控制调试] currentSerialIndex:", serialPage.currentSerialIndex)
            } else {
                console.log("⚠️ [串口控制调试] serialPage 为 null")
            }
        }

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
                    console.log("✅ [导航] 列表区域上移 - 当前索引:", currentContentItemIndex)
                    if (currentContentItemIndex > 0) {
                        currentContentItemIndex--
                        console.log("✅ [导航] 列表区域上移后 - 新索引:", currentContentItemIndex)
                    } else {
                        console.log("⚠️ [导航] 已到达列表第一项")
                    }
                } else if (currentPage.focusSubArea === 1) {
                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.7]: 串口控制使用 NavigationManager
                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.28]: 添加详细调试信息
                    console.log("🔍 [串口控制导航] 上键 - currentCategory:", currentCategory, "focusSubArea:", currentPage.focusSubArea)
                    if (currentCategory === 6) {
                        // 串口控制页面：使用 NavigationManager
                        var serialPage = serialPortControlPageLoader.item
                        console.log("🔍 [串口控制导航] serialPage:", serialPage ? "存在" : "null")
                        if (serialPage) {
                            console.log("🔍 [串口控制导航] navigationManager:", serialPage.navigationManager ? "存在" : "null")
                        }
                        if (serialPage && serialPage.navigationManager) {
                            console.log("🔍 [串口控制导航] 上键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Up")  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.10]: 使用 handleDirectionKey
                            event.accepted = true
                            return
                        } else {
                            console.log("⚠️ [串口控制导航] 上键 - NavigationManager 不可用")
                        }
                    }

                    // ✅ 2026-01-30 [FIX 100.300.106.3]: 检查布局模式
                    var currentTab = currentPage.getCurrentTab ? currentPage.getCurrentTab() : null
                    var layoutMode = (currentTab && currentTab.layoutMode) ? currentTab.layoutMode : "two-column"

                    if (layoutMode === "single-column") {
                        // ✅ 一列布局：直接向上移动
                        var currentIndex = currentPage.focusParamIndex
                        if (currentIndex > 0) {
                            currentPage.focusParamIndex = currentIndex - 1
                            console.log("✅ [导航] 参数区域（一列）上移:", currentIndex, "→", currentIndex - 1)
                        } else {
                            console.log("⚠️ [导航] 已到达第一个参数")
                        }
                    } else {
                        // ✅ 两列布局：同列向上移动
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
                    }
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.13]: 串口控制参数区域使用NavigationManager
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.15]: 主动调用NavigationManager，而不是只跳过
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.6]: 直接调用SerialPortControlPage.getCurrentTab()
                    // 原因：串口控制页面的focusSubArea定义不同（0=列表 1=Tab 2=参数 3=按钮）
                    // 其他页面的focusSubArea定义（0=列表 1=参数 2=按钮）
                    // 解决：在focusSubArea=2时，检查是否为串口控制页面，调用NavigationManager处理上键
                    if (currentCategory === 6) {
                        var serialPage = serialPortControlPageLoader.item
                        if (serialPage && serialPage.navigationManager) {
                            // 检查当前Tab是否有自定义导航
                            if (typeof serialPage.getCurrentTab === "function") {
                                var currentTab = serialPage.getCurrentTab()
                                if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                                    console.log("✅ [串口控制导航] 上键 - 调用自定义导航")
                                    var handled = currentTab.handleDirectionKey("Up")
                                    if (handled) {
                                        event.accepted = true
                                        return
                                    }
                                }
                            }

                            // 如果没有自定义导航或自定义导航返回false，使用NavigationManager
                            console.log("🔍 [串口控制导航] 上键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Up")
                            event.accepted = true
                            return
                        }
                    } else {
                        // 其他页面：focusSubArea=2是底部按钮区域
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
                } else if (currentPage.focusSubArea === 3) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.12]: 串口控制按钮区域使用NavigationManager
                    // 原因：串口控制页面的focusSubArea定义不同（0=列表 1=Tab 2=参数 3=按钮）
                    // 其他页面的focusSubArea定义（0=列表 1=参数 2=按钮）
                    // 解决：在focusSubArea=3时，检查是否为串口控制页面，调用NavigationManager
                    console.log("🔍 [串口控制导航] 上键 - currentCategory:", currentCategory, "focusSubArea:", currentPage.focusSubArea)
                    if (currentCategory === 6) {
                        // 串口控制页面：使用 NavigationManager
                        var serialPage = serialPortControlPageLoader.item
                        console.log("🔍 [串口控制导航] serialPage:", serialPage ? "存在" : "null")
                        if (serialPage) {
                            console.log("🔍 [串口控制导航] navigationManager:", serialPage.navigationManager ? "存在" : "null")
                        }
                        if (serialPage && serialPage.navigationManager) {
                            console.log("🔍 [串口控制导航] 上键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Up")
                            event.accepted = true
                            return
                        } else {
                            console.log("⚠️ [串口控制导航] 上键 - NavigationManager 不可用")
                        }
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
    Keys.onDownPressed: function(event) {
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.4]: 电机控制页面使用NavigationManager
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.10]: 修复 QML 警告 - 声明 event 参数
        // ✅ 2026-01-31 [FIX 100.300.112.7.2]: 制动器控制页面使用NavigationManager
        if (currentCategory === 3 && currentFocusArea === 2) {
            var motorPage = motorControlPageLoader.item
            if (motorPage && typeof motorPage.handleKeyPress === "function") {
                motorPage.handleKeyPress("Down")
                event.accepted = true
                return
            }
        }

        if (currentCategory === 4 && currentFocusArea === 2) {
            var brakePage = brakeControlPageLoader.item
            if (brakePage && typeof brakePage.handleKeyPress === "function") {
                brakePage.handleKeyPress("Down")
                event.accepted = true
                return
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.8]: 张紧控制页面使用NavigationManager
        if (currentCategory === 5 && currentFocusArea === 2) {
            var tensionPage = tensionControlPageLoader.item
            if (tensionPage && typeof tensionPage.handleKeyPress === "function") {
                tensionPage.handleKeyPress("Down")
                event.accepted = true
                return
            }
        }

        // 下键：在当前区域内向下导航
        console.log("✅ [导航] 下键 - 当前区域:", currentFocusArea, "当前类别:", currentCategory)

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 5.2]: 添加串口控制详细日志
        if (currentCategory === 6) {
            console.log("🔍 [串口控制调试] 下键 - currentFocusArea:", currentFocusArea)
            console.log("🔍 [串口控制调试] currentContentItemIndex:", currentContentItemIndex)
            var serialPage = serialPortControlPageLoader.item
            if (serialPage) {
                console.log("🔍 [串口控制调试] focusSubArea:", serialPage.focusSubArea)
                console.log("🔍 [串口控制调试] focusItemIndex:", serialPage.focusItemIndex)
                console.log("🔍 [串口控制调试] currentSerialIndex:", serialPage.currentSerialIndex)
            } else {
                console.log("⚠️ [串口控制调试] serialPage 为 null")
            }
        }

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
                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.7]: 串口控制使用 NavigationManager
                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.28]: 添加详细调试信息
                    console.log("🔍 [串口控制导航] 下键 - currentCategory:", currentCategory, "focusSubArea:", currentPage.focusSubArea)
                    if (currentCategory === 6) {
                        // 串口控制页面：使用 NavigationManager
                        var serialPage = serialPortControlPageLoader.item
                        console.log("🔍 [串口控制导航] serialPage:", serialPage ? "存在" : "null")
                        if (serialPage) {
                            console.log("🔍 [串口控制导航] navigationManager:", serialPage.navigationManager ? "存在" : "null")
                        }
                        if (serialPage && serialPage.navigationManager) {
                            console.log("🔍 [串口控制导航] 下键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Down")  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.10]: 使用 handleDirectionKey
                            event.accepted = true
                            return
                        } else {
                            console.log("⚠️ [串口控制导航] 下键 - NavigationManager 不可用")
                        }
                    }

                    // ✅ 2026-01-30 [FIX 100.300.106.3]: 检查布局模式
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.10]: 串口控制参数区域使用NavigationManager
                    // 原因：串口控制页面的focusSubArea定义不同（0=列表 1=Tab 2=参数 3=按钮）
                    // 其他页面的focusSubArea定义（0=列表 1=参数 2=按钮）
                    // 解决：在focusSubArea=2时，检查是否为串口控制页面，调用NavigationManager
                    console.log("🔍 [串口控制导航] 下键 - currentCategory:", currentCategory, "focusSubArea:", currentPage.focusSubArea)
                    if (currentCategory === 6) {
                        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.6]: 直接调用SerialPortControlPage.getCurrentTab()
                        var serialPage = serialPortControlPageLoader.item
                        if (serialPage && serialPage.navigationManager) {
                            // 检查当前Tab是否有自定义导航
                            if (typeof serialPage.getCurrentTab === "function") {
                                var currentTab = serialPage.getCurrentTab()
                                if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                                    console.log("✅ [串口控制导航] 下键 - 调用自定义导航")
                                    var handled = currentTab.handleDirectionKey("Down")
                                    if (handled) {
                                        event.accepted = true
                                        return
                                    }
                                }
                            }

                            // 如果没有自定义导航或自定义导航返回false，使用NavigationManager
                            console.log("🔍 [串口控制导航] 下键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Down")
                            event.accepted = true
                            return
                        }
                    }

                    // ✅ 其他页面的底部按钮区域：下键导航
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
                } else if (currentPage.focusSubArea === 3) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.12]: 串口控制按钮区域使用NavigationManager
                    // 原因：串口控制页面的focusSubArea定义不同（0=列表 1=Tab 2=参数 3=按钮）
                    // 其他页面的focusSubArea定义（0=列表 1=参数 2=按钮）
                    // 解决：在focusSubArea=3时，检查是否为串口控制页面，调用NavigationManager
                    console.log("🔍 [串口控制导航] 下键 - currentCategory:", currentCategory, "focusSubArea:", currentPage.focusSubArea)
                    if (currentCategory === 6) {
                        // 串口控制页面：使用 NavigationManager
                        var serialPage = serialPortControlPageLoader.item
                        console.log("🔍 [串口控制导航] serialPage:", serialPage ? "存在" : "null")
                        if (serialPage) {
                            console.log("🔍 [串口控制导航] navigationManager:", serialPage.navigationManager ? "存在" : "null")
                        }
                        if (serialPage && serialPage.navigationManager) {
                            console.log("🔍 [串口控制导航] 下键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Down")
                            event.accepted = true
                            return
                        } else {
                            console.log("⚠️ [串口控制导航] 下键 - NavigationManager 不可用")
                        }
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
    Keys.onLeftPressed: function(event) {
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.4]: 电机控制页面使用NavigationManager
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.10]: 修复 QML 警告 - 声明 event 参数
        if (currentCategory === 3 && currentFocusArea === 2) {
            var motorPage = motorControlPageLoader.item
            if (motorPage && typeof motorPage.handleKeyPress === "function") {
                motorPage.handleKeyPress("Left")
                event.accepted = true
                return
            }
        }

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
                // ✅ 2026-01-31 [FIX 100.300.112.7.2]: 检查是否是 BrakeControlPage（4区域模式）
                var isBrakeControlPage = (currentCategory === 4)  // 制动器控制类别

                if (isBrakeControlPage) {
                    // ✅ BrakeControlPage 4区域模式：左键由内部 NavigationManager 处理
                    // ✅ 2026-01-31 [FIX 100.300.112.7.4]: 调用 handleKeyPress 处理左键
                    // ✅ 2026-01-31 [FIX 100.300.112.7.5]: 只在非列表区域时转发，列表区域左键返回类别
                    var brakePage = brakeControlPageLoader.item

                    // 检查当前子区域：0=列表 1=使用状态 2=参数 3=按钮
                    if (brakePage && brakePage.focusSubArea !== 0) {
                        // 在使用状态、参数或按钮区域：转发给内部 NavigationManager
                        if (typeof brakePage.handleKeyPress === "function") {
                            brakePage.handleKeyPress("Left")
                            event.accepted = true
                            console.log("✅ [导航] BrakeControlPage 左键由内部 NavigationManager 处理")
                            return
                        }
                    } else {
                        // 在列表区域：左键返回到左侧类别区域
                        console.log("✅ [导航] BrakeControlPage 列表区域左键返回类别")
                        currentFocusArea = 1  // 切换到左侧类别
                        // ✅ 2026-02-03 [FIX 100.300.112.8.25.13]: 强制转移焦点到 DeviceSettingsDialog
                        console.log("✅ [DeviceSettingsDialog] 强制转移焦点到 DeviceSettingsDialog")
                        root.forceActiveFocus()
                        return
                    }
                }

                // ✅ 2026-01-31 [FIX 100.300.112.8]: 检查是否是 TensionControlPage（4区域模式）
                var isTensionControlPage = (currentCategory === 5)  // 张紧控制类别

                if (isTensionControlPage) {
                    // ✅ TensionControlPage 4区域模式：左键由内部 NavigationManager 处理
                    var tensionPage = tensionControlPageLoader.item

                    // 检查当前子区域：0=列表 1=使用状态 2=参数 3=按钮
                    if (tensionPage && tensionPage.focusSubArea !== 0) {
                        // 在使用状态、参数或按钮区域：转发给内部 NavigationManager
                        if (typeof tensionPage.handleKeyPress === "function") {
                            tensionPage.handleKeyPress("Left")
                            event.accepted = true
                            console.log("✅ [导航] TensionControlPage 左键由内部 NavigationManager 处理")
                            return
                        }
                    } else {
                        // 在列表区域：左键返回到左侧类别区域
                        console.log("✅ [导航] TensionControlPage 列表区域左键返回类别")
                        currentFocusArea = 1  // 切换到左侧类别
                        // ✅ 2026-02-03 [FIX 100.300.112.8.25.14]: 强制转移焦点到 DeviceSettingsDialog
                        console.log("✅ [DeviceSettingsDialog] 强制转移焦点到 DeviceSettingsDialog")
                        root.forceActiveFocus()
                        return
                    }
                }

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.4]: 移除旧的串口控制页面特殊处理
                // 原因：串口控制页面已改为4区域模式（列表、Tab、参数、按钮），使用NavigationManager管理导航
                // 旧代码会在Tab区域（focusSubArea=1）按左键时直接跳到列表区域，导致无法逐个向左切换Tab
                // 现在让SerialPortControlPage自己处理左键事件（通过Keys.onLeftPressed）

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.5]: 串口控制页面跳过参数区域左键处理
                // 串口控制页面的区域定义：0=列表 1=Tab 2=参数 3=按钮
                // 电机控制页面的区域定义：0=列表 1=参数 2=按钮
                // 下面的代码是为电机控制页面设计的，检查 focusSubArea === 1 认为是参数区域
                // 但对串口控制页面来说，focusSubArea === 1 是Tab区域，不应该执行参数区域的逻辑
                var isSerialPortControlPage = (currentCategory === 6)  // 串口控制类别

                if (currentPage.focusSubArea === 1 && !isSerialPortControlPage) {
                    // ✅ 2026-01-30 [FIX 100.300.106.3]: 检查布局模式
                    var currentTab = currentPage.getCurrentTab ? currentPage.getCurrentTab() : null
                    var layoutMode = (currentTab && currentTab.layoutMode) ? currentTab.layoutMode : "two-column"

                    if (layoutMode === "single-column") {
                        // ✅ 一列布局：左键返回列表区域
                        currentPage.focusSubArea = 0
                        console.log("✅ [导航] 从参数区域（一列）返回列表区域")
                        return  // 不切换到左侧类别
                    } else {
                        // ✅ 两列布局：两列交叉导航
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
                    }
                } else if (currentPage.focusSubArea === 2) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.16]: 串口控制参数区域使用NavigationManager
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.6]: 直接调用SerialPortControlPage.getCurrentTab()
                    // 原因：串口控制页面的focusSubArea定义不同（0=列表 1=Tab 2=参数 3=按钮）
                    // 其他页面的focusSubArea定义（0=列表 1=参数 2=按钮）
                    // 解决：在focusSubArea=2时，检查是否为串口控制页面，调用NavigationManager
                    console.log("🔍 [串口控制导航] 左键 - currentCategory:", currentCategory, "focusSubArea:", currentPage.focusSubArea)
                    if (currentCategory === 6) {
                        var serialPage = serialPortControlPageLoader.item
                        if (serialPage && serialPage.navigationManager) {
                            // 检查当前Tab是否有自定义导航
                            if (typeof serialPage.getCurrentTab === "function") {
                                var currentTab = serialPage.getCurrentTab()
                                if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                                    console.log("✅ [串口控制导航] 左键 - 调用自定义导航")
                                    var handled = currentTab.handleDirectionKey("Left")
                                    if (handled) {
                                        event.accepted = true
                                        return
                                    }
                                }
                            }

                            // 如果没有自定义导航或自定义导航返回false，使用NavigationManager
                            console.log("🔍 [串口控制导航] 左键 - 调用 NavigationManager.handleDirectionKey")
                            serialPage.navigationManager.handleDirectionKey("Left")
                            event.accepted = true
                            return
                        }
                    }

                    // ✅ 其他页面的底部按钮区域：左键导航
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

            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.6]: 串口控制页面使用NavigationManager处理左键
            if (currentCategory === 6 && currentFocusArea === 2) {
                var serialPage = serialPortControlPageLoader.item
                if (serialPage && serialPage.navigationManager) {
                    console.log("✅ [导航] 串口控制页面左键 - 调用NavigationManager")
                    serialPage.navigationManager.handleDirectionKey("Left")
                    event.accepted = true
                    return
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
    Keys.onRightPressed: function(event) {
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.4]: 电机控制页面使用NavigationManager
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.10]: 修复 QML 警告 - 声明 event 参数
        // ✅ 2026-01-31 [FIX 100.300.112.7.2]: 制动器控制页面使用NavigationManager
        if (currentCategory === 3 && currentFocusArea === 2) {
            var motorPage = motorControlPageLoader.item
            if (motorPage && typeof motorPage.handleKeyPress === "function") {
                motorPage.handleKeyPress("Right")
                event.accepted = true
                return
            }
        }

        if (currentCategory === 4 && currentFocusArea === 2) {
            var brakePage = brakeControlPageLoader.item
            if (brakePage && typeof brakePage.handleKeyPress === "function") {
                brakePage.handleKeyPress("Right")
                event.accepted = true
                return
            }
        }

        // ✅ 2026-01-31 [FIX 100.300.112.8]: 张紧控制页面使用NavigationManager
        if (currentCategory === 5 && currentFocusArea === 2) {
            var tensionPage = tensionControlPageLoader.item
            if (tensionPage && typeof tensionPage.handleKeyPress === "function") {
                tensionPage.handleKeyPress("Right")
                event.accepted = true
                return
            }
        }

        // 右键：切换到右侧区域
        console.log("✅ [导航] 右键 - 当前区域:", currentFocusArea)

        switch(currentFocusArea) {
        case 0:  // 顶部按钮 → 左侧类别
            currentFocusArea = 1
            break
        case 1:  // 左侧类别 → 右侧内容
            currentFocusArea = 2
            // ✅ 2026-01-31 [FIX 100.300.112.8.13]: 不重置内容区域索引，保持之前的选中状态
            // 电机控制、制动器控制、张紧控制等页面需要保持之前选中的项
            // currentContentItemIndex = 0  // ❌ 不应该重置，会导致焦点和选中状态不同步
            break
        case 2:  // 右侧内容 → 检查当前页面是否支持子区域导航
            console.log("🔍 [串口控制导航] case 2 开始 - currentCategory:", currentCategory)
            var currentPage = getCurrentPage(currentCategory)
            console.log("🔍 [串口控制导航] getCurrentPage 返回:", currentPage ? "有效对象" : "null")

            if (currentPage) {
                console.log("🔍 [串口控制导航] currentPage.focusSubArea 类型:", typeof currentPage.focusSubArea)
                console.log("🔍 [串口控制导航] currentPage.focusSubArea 值:", currentPage.focusSubArea)
            }

            if (currentPage && typeof currentPage.focusSubArea !== "undefined") {
                console.log("🔍 [串口控制导航] 进入子区域导航处理")

                // ✅ 2026-01-31 [FIX 100.300.112.7.2]: 检查是否是 BrakeControlPage（4区域模式）
                var isBrakeControlPage = (currentCategory === 4)  // 制动器控制类别

                if (isBrakeControlPage) {
                    // ✅ BrakeControlPage 4区域模式：0=列表 1=使用状态 2=参数 3=按钮
                    // 右键由 BrakeControlPage 内部的 NavigationManager 处理，不在这里处理
                    console.log("✅ [导航] BrakeControlPage 右键由内部 NavigationManager 处理")
                    return
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.12]: 串口控制页面使用 NavigationManager
                var isSerialPortControlPage = (currentCategory === 6)  // 串口控制类别
                console.log("🔍 [串口控制导航] isSerialPortControlPage:", isSerialPortControlPage)

                if (isSerialPortControlPage) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.6]: 添加自定义导航调用
                    var serialPage = serialPortControlPageLoader.item
                    if (serialPage && serialPage.navigationManager) {
                        // 检查当前Tab是否有自定义导航
                        if (typeof serialPage.getCurrentTab === "function") {
                            var currentTab = serialPage.getCurrentTab()
                            if (currentTab && typeof currentTab.handleDirectionKey === "function") {
                                console.log("✅ [串口控制导航] 右键 - 调用自定义导航")
                                var handled = currentTab.handleDirectionKey("Right")
                                if (handled) {
                                    event.accepted = true
                                    return
                                }
                            }
                        }

                        // 如果没有自定义导航或自定义导航返回false，使用NavigationManager
                        console.log("🔍 [串口控制导航] 右键 - 调用 NavigationManager.handleDirectionKey")
                        serialPage.navigationManager.handleDirectionKey("Right")
                        event.accepted = true
                        return
                    }
                }

                // 如果当前在列表区域，切换到参数区域
                if (currentPage.focusSubArea === 0) {
                    currentPage.focusSubArea = 1
                    currentPage.focusParamIndex = 0  // 重置参数焦点索引
                    console.log("✅ [导航] 从列表区域切换到参数区域")
                    return  // 不切换到底部按钮
                } else if (currentPage.focusSubArea === 1) {
                    // ✅ 2026-01-30 [FIX 100.300.106.3]: 检查布局模式
                    var currentTab = currentPage.getCurrentTab ? currentPage.getCurrentTab() : null
                    var layoutMode = (currentTab && currentTab.layoutMode) ? currentTab.layoutMode : "two-column"

                    if (layoutMode === "single-column") {
                        // ✅ 一列布局：右键保持焦点（不支持切换列）
                        console.log("⚠️ [导航] 参数区域（一列）已在最右侧")
                        return
                    } else {
                        // ✅ 两列布局：两列交叉导航
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
                    }
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
            } else {
                console.log("🔍 [串口控制导航] currentPage 为 null 或没有 focusSubArea 属性")
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
                // ✅ 2026-02-02 [FIX 100.300.112.8.23.1]: 修正 focusSubArea 值检查
                // MotorControlPage 的 focusSubArea 定义：0=列表, 1=Tab, 2=参数, 3=按钮
                if (currentPage.focusSubArea === 2) {
                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.11]: 先尝试调用当前Tab的handleEnterKey()
                    // 如果Tab处理了回车键（返回true），则不执行triggerParamInput
                    // 用于支持ComboBox的回车键循环切换选项
                    var handled = false

                    // 串口控制页面特殊处理
                    if (currentCategory === 6) {
                        var serialPage = serialPortControlPageLoader.item
                        if (serialPage) {
                            var configPanel = serialPage.children[0].children[1]
                            if (configPanel) {
                                var currentTab = configPanel.getCurrentTab()
                                if (currentTab && typeof currentTab.handleEnterKey === "function") {
                                    handled = currentTab.handleEnterKey()
                                    if (handled) {
                                        console.log("✅ [导航] 回车键已被Tab处理（串口控制）")
                                        event.accepted = true
                                        return
                                    }
                                }
                            }
                        }
                    }

                    // 如果Tab没有处理，执行默认行为（弹出虚拟键盘）
                    // ✅ 参数区域：弹出虚拟键盘
                    if (typeof currentPage.triggerParamInput === "function") {
                        currentPage.triggerParamInput(currentPage.focusParamIndex)
                        console.log("✅ [导航] 触发参数输入 - 索引:", currentPage.focusParamIndex)
                    } else {
                        console.warn("⚠️ [导航] 当前页面未实现 triggerParamInput 方法")
                    }
                } else if (currentPage.focusSubArea === 3) {
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
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.10]: 检查虚拟键盘是否激活
        // 如果虚拟键盘激活，不关闭对话框（让 InputPanel 的 Shortcut 处理）
        if (Qt.inputMethod.visible) {
            console.log("⌨️ [DeviceSettingsDialog] 虚拟键盘激活中，忽略 ESC 键")
            return
        }

        // Escape 键：关闭弹窗
        console.log("🔍 [DeviceSettingsDialog] ========== ESC 键关闭对话框 ==========")
        console.log("🔍 [DeviceSettingsDialog] 关闭前 - modalContainer.visible:", modalContainer.visible)
        console.log("🔍 [DeviceSettingsDialog] 关闭前 - modalContainer.parentContainer:", modalContainer.parentContainer)

        // ✅ 2026-01-30 [修复]: 隐藏整个 modalContainer（包括遮罩层），而不是只隐藏 root
        modalContainer.visible = false

        console.log("🔍 [DeviceSettingsDialog] 关闭后 - modalContainer.visible:", modalContainer.visible)

        // ✅ 2026-01-30 [修复]: 使用保存的 parentContainer 引用恢复焦点
        if (modalContainer.parentContainer) {
            console.log("🔍 [DeviceSettingsDialog] 准备恢复焦点到 parentContainer...")
            console.log("🔍 [DeviceSettingsDialog] parentContainer.focus:", modalContainer.parentContainer.focus)
            console.log("🔍 [DeviceSettingsDialog] parentContainer.activeFocus:", modalContainer.parentContainer.activeFocus)

            modalContainer.parentContainer.forceActiveFocus()

            console.log("🔍 [DeviceSettingsDialog] forceActiveFocus() 调用完成")
            console.log("🔍 [DeviceSettingsDialog] parentContainer.focus:", modalContainer.parentContainer.focus)
            console.log("🔍 [DeviceSettingsDialog] parentContainer.activeFocus:", modalContainer.parentContainer.activeFocus)
        } else {
            console.error("🔍 [DeviceSettingsDialog] ❌ parentContainer 为 null，无法恢复焦点！")
        }
        console.log("🔍 [DeviceSettingsDialog] =====================================")
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
                        console.log("🔍 [DeviceSettingsDialog] ========== 关闭按钮被点击 ==========")
                        console.log("🔍 [DeviceSettingsDialog] 关闭前 - modalContainer.visible:", modalContainer.visible)
                        console.log("🔍 [DeviceSettingsDialog] 关闭前 - modalContainer.parentContainer:", modalContainer.parentContainer)

                        // ✅ 2026-01-30 [修复]: 隐藏整个 modalContainer（包括遮罩层），而不是只隐藏 root
                        modalContainer.visible = false

                        console.log("🔍 [DeviceSettingsDialog] 关闭后 - modalContainer.visible:", modalContainer.visible)

                        // ✅ 2026-01-30 [修复]: 使用保存的 parentContainer 引用恢复焦点
                        if (modalContainer.parentContainer) {
                            console.log("🔍 [DeviceSettingsDialog] 准备恢复焦点到 parentContainer...")
                            console.log("🔍 [DeviceSettingsDialog] parentContainer.focus:", modalContainer.parentContainer.focus)
                            console.log("🔍 [DeviceSettingsDialog] parentContainer.activeFocus:", modalContainer.parentContainer.activeFocus)

                            modalContainer.parentContainer.forceActiveFocus()

                            console.log("🔍 [DeviceSettingsDialog] forceActiveFocus() 调用完成")
                            console.log("🔍 [DeviceSettingsDialog] parentContainer.focus:", modalContainer.parentContainer.focus)
                            console.log("🔍 [DeviceSettingsDialog] parentContainer.activeFocus:", modalContainer.parentContainer.activeFocus)
                        }
                        console.log("🔍 [DeviceSettingsDialog] =====================================")
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
                    model: ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "串口控制", "逻辑控制"]

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
                            // ✅ 2026-01-30 [FIX 100.300.105.1]: keyboardManager 已废弃，注释掉
                            // item.keyboardManager = keyboardManager
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
                            // ✅ 2026-01-29 [Qt 虚拟键盘]: 直接传递 qtVirtualKeyboard
                            item.virtualKeyboard = qtVirtualKeyboard
                            console.log("✅ [DEBUG] 设置 virtualKeyboard:", qtVirtualKeyboard)

                            // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.21]: 设置初始焦点状态
                            // 当焦点在内容区域（区域2）且当前类别是开关量输入时
                            if (root.currentFocusArea === 2 && root.currentCategory === 1) {
                                item.focusSubArea = 0  // 默认焦点在列表区域
                                item.focusItemIndex = root.currentContentItemIndex
                            }

                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.9]: 监听返回类别信号
                            item.requestReturnToCategory.connect(function() {
                                console.log("✅ [DeviceSettingsDialog] 接收到开关量输入返回类别请求")
                                root.currentFocusArea = 1  // 切换到左侧类别区域
                                // ✅ 强制转移焦点到 DeviceSettingsDialog
                                console.log("✅ [DeviceSettingsDialog] 强制转移焦点到 DeviceSettingsDialog")
                                root.forceActiveFocus()
                            })
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

                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.11]: SwitchInputPage 反向焦点同步（从 Page 到 Dialog）
                    // 当用户在开关量列表中导航或鼠标点击时，同步更新 Dialog 的 currentContentItemIndex
                    Connections {
                        target: switchInputPageLoader.item
                        enabled: switchInputPageLoader.item !== null

                        function onFocusItemIndexChanged() {
                            if (root.currentCategory === 1 &&
                                root.currentFocusArea === 2 &&
                                switchInputPageLoader.item.focusSubArea === 0 &&
                                switchInputPageLoader.item.focusItemIndex >= 0) {
                                // 只在焦点在列表区域时同步
                                console.log("✅ [DeviceSettingsDialog] 同步开关量列表焦点:", switchInputPageLoader.item.focusItemIndex)
                                root.currentContentItemIndex = switchInputPageLoader.item.focusItemIndex
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
                            // ✅ 2026-01-30 [FIX 100.300.105.1]: keyboardManager 已废弃，注释掉
                            // item.keyboardManager = keyboardManager
                            // ✅ 2026-01-30 [FIX 100.300.105]: 传递虚拟键盘引用
                            item.virtualKeyboard = qtVirtualKeyboard

                            // ✅ 2026-01-30 [FIX 100.300.105]: 设置初始焦点状态
                            if (root.currentFocusArea === 2 && root.currentCategory === 2) {
                                item.focusSubArea = 0  // 默认焦点在列表区域
                                item.focusItemIndex = root.currentContentItemIndex
                            }

                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.10]: 监听返回类别信号
                            item.requestReturnToCategory.connect(function() {
                                console.log("✅ [DeviceSettingsDialog] 接收到模拟量输入返回类别请求")
                                root.currentFocusArea = 1  // 切换到左侧类别区域
                                // ✅ 强制转移焦点到 DeviceSettingsDialog
                                console.log("✅ [DeviceSettingsDialog] 强制转移焦点到 DeviceSettingsDialog")
                                root.forceActiveFocus()
                            })
                        }
                    }

                    onStatusChanged: {
                        if (analogInputPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] AnalogInputPage 加载失败")
                        }
                    }
                }

                // ✅ 2026-01-30 [FIX 100.300.105]: AnalogInputPage 焦点同步
                Connections {
                    target: root
                    enabled: analogInputPageLoader.item !== null

                    function onCurrentFocusAreaChanged() {
                        if (analogInputPageLoader.item && root.currentCategory === 2) {
                            if (root.currentFocusArea === 2) {
                                // 焦点进入内容区域，默认在列表区域
                                analogInputPageLoader.item.focusSubArea = 0
                                analogInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 焦点离开内容区域，清除焦点
                                analogInputPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentCategoryChanged() {
                        if (analogInputPageLoader.item) {
                            if (root.currentFocusArea === 2 && root.currentCategory === 2) {
                                // 切换到模拟量输入类别，设置焦点
                                analogInputPageLoader.item.focusSubArea = 0
                                analogInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 切换到其他类别，清除焦点
                                analogInputPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentContentItemIndexChanged() {
                        if (analogInputPageLoader.item &&
                            root.currentFocusArea === 2 &&
                            root.currentCategory === 2) {
                            // 在模拟量列表中导航
                            analogInputPageLoader.item.focusItemIndex = root.currentContentItemIndex
                        }
                    }
                }

                // ✅ 2026-02-03 [FIX 100.300.112.8.25.12]: AnalogInputPage 反向焦点同步（从 Page 到 Dialog）
                // 当用户在模拟量列表中导航或鼠标点击时，同步更新 Dialog 的 currentContentItemIndex
                Connections {
                    target: analogInputPageLoader.item
                    enabled: analogInputPageLoader.item !== null

                    function onFocusItemIndexChanged() {
                        if (root.currentCategory === 2 &&
                            root.currentFocusArea === 2 &&
                            analogInputPageLoader.item.focusSubArea === 0 &&
                            analogInputPageLoader.item.focusItemIndex >= 0) {
                            // 只在焦点在列表区域时同步
                            console.log("✅ [DeviceSettingsDialog] 同步模拟量列表焦点:", analogInputPageLoader.item.focusItemIndex)
                            root.currentContentItemIndex = analogInputPageLoader.item.focusItemIndex
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
                            // ✅ 2026-01-30 [FIX 100.300.105.1]: keyboardManager 已废弃，注释掉
                            // item.keyboardManager = keyboardManager
                            // ✅ 2026-01-30 [FIX 100.300.106]: 传递虚拟键盘引用
                            item.virtualKeyboard = qtVirtualKeyboard

                            // ✅ 2026-01-30 [FIX 100.300.106]: 设置初始焦点状态
                            if (root.currentFocusArea === 2 && root.currentCategory === 3) {
                                item.focusSubArea = 0  // 默认焦点在电机列表区域
                                item.focusItemIndex = root.currentContentItemIndex
                            }

                            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 监听返回到类别信号
                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.3]: 重置 NavigationManager 状态
                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.6]: 添加详细日志诊断
                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.7]: 移除重置逻辑，由 onCurrentFocusAreaChanged 处理
                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.8]: 添加焦点转移，确保焦点离开 MotorControlPage
                            item.requestReturnToCategory.connect(function() {
                                console.log("✅ [DeviceSettingsDialog] 接收到返回类别请求")
                                // ❌ 不在这里重置 NavigationManager.currentArea
                                // 因为用户可能在大类列表按右键，此时会直接进入内容区域
                                // 应该在 onCurrentFocusAreaChanged 中重置，确保进入内容区域时才重置
                                root.currentFocusArea = 1  // 切换到左侧类别区域
                                // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.8]: 强制转移焦点到 DeviceSettingsDialog
                                console.log("✅ [DeviceSettingsDialog] 强制转移焦点到 DeviceSettingsDialog")
                                root.forceActiveFocus()
                            })

                            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.5]: 监听请求焦点信号
                            item.requestDialogFocus.connect(function() {
                                console.log("✅ [DeviceSettingsDialog] 接收到 requestDialogFocus 信号，获取焦点")
                                root.forceActiveFocus()
                            })
                        }
                    }

                    onStatusChanged: {
                        if (motorControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] MotorControlPage 加载失败")
                        }
                    }
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: MotorControlPage 焦点同步（从 Dialog 到 Page）
                Connections {
                    target: root
                    enabled: motorControlPageLoader.item !== null

                    function onCurrentFocusAreaChanged() {
                        if (motorControlPageLoader.item && root.currentCategory === 3) {
                            if (root.currentFocusArea === 2) {
                                // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.5]: 焦点进入内容区域，重置 NavigationManager 到电机列表区域
                                console.log("✅ [DeviceSettingsDialog] 焦点进入电机控制内容区域，重置 NavigationManager.currentArea 到电机列表")
                                if (motorControlPageLoader.item.navigationManager) {
                                    motorControlPageLoader.item.navigationManager.currentArea = motorControlPageLoader.item.navigationManager.areaMotorList
                                }
                                // 焦点进入内容区域，默认在电机列表区域
                                motorControlPageLoader.item.focusSubArea = 0
                                motorControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 焦点离开内容区域，清除焦点
                                motorControlPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentCategoryChanged() {
                        if (motorControlPageLoader.item) {
                            if (root.currentFocusArea === 2 && root.currentCategory === 3) {
                                // 切换到电机控制类别，设置焦点
                                motorControlPageLoader.item.focusSubArea = 0
                                motorControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 切换到其他类别，清除焦点
                                motorControlPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentContentItemIndexChanged() {
                        if (motorControlPageLoader.item &&
                            root.currentFocusArea === 2 &&
                            root.currentCategory === 3) {
                            // 在电机列表中导航
                            motorControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                        }
                    }
                }

                // ✅ 2026-01-31 [FIX 100.300.112.8.14]: MotorControlPage 反向焦点同步（从 Page 到 Dialog）
                // 当用户在电机列表中导航时，同步更新 Dialog 的 currentContentItemIndex
                // 这样当焦点离开再返回时，能恢复到正确的位置
                Connections {
                    target: motorControlPageLoader.item
                    enabled: motorControlPageLoader.item !== null

                    function onFocusItemIndexChanged() {
                        if (root.currentCategory === 3 &&
                            root.currentFocusArea === 2 &&
                            motorControlPageLoader.item.focusSubArea === 0 &&
                            motorControlPageLoader.item.focusItemIndex >= 0) {
                            // 只在焦点在电机列表区域时同步
                            console.log("✅ [DeviceSettingsDialog] 同步电机列表焦点:", motorControlPageLoader.item.focusItemIndex)
                            root.currentContentItemIndex = motorControlPageLoader.item.focusItemIndex
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
                            // ✅ 2026-01-31 [FIX 100.300.112.4]: 传递虚拟键盘引用
                            item.virtualKeyboard = qtVirtualKeyboard

                            // ✅ 2026-01-31 [FIX 100.300.112.4]: 设置初始焦点状态
                            if (root.currentFocusArea === 2 && root.currentCategory === 4) {
                                item.focusSubArea = 0  // 默认焦点在制动器列表区域
                                item.focusItemIndex = root.currentContentItemIndex
                            }
                        }
                    }

                    onStatusChanged: {
                        if (brakeControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] BrakeControlPage 加载失败")
                        }
                    }
                }

                // ✅ 2026-01-31 [FIX 100.300.112.4]: BrakeControlPage 焦点同步（从 Dialog 到 Page）
                Connections {
                    target: root
                    enabled: brakeControlPageLoader.item !== null

                    function onCurrentFocusAreaChanged() {
                        if (brakeControlPageLoader.item && root.currentCategory === 4) {
                            if (root.currentFocusArea === 2) {
                                // 焦点进入内容区域，默认在制动器列表区域
                                brakeControlPageLoader.item.focusSubArea = 0
                                brakeControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 焦点离开内容区域，清除焦点
                                brakeControlPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentCategoryChanged() {
                        if (brakeControlPageLoader.item) {
                            if (root.currentFocusArea === 2 && root.currentCategory === 4) {
                                // 切换到制动器控制类别，设置焦点
                                brakeControlPageLoader.item.focusSubArea = 0
                                brakeControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 切换到其他类别，清除焦点
                                brakeControlPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentContentItemIndexChanged() {
                        if (brakeControlPageLoader.item &&
                            root.currentFocusArea === 2 &&
                            root.currentCategory === 4) {
                            // 在制动器列表中导航
                            brakeControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                        }
                    }
                }

                // ✅ 2026-01-31 [FIX 100.300.112.8.14]: BrakeControlPage 反向焦点同步（从 Page 到 Dialog）
                // 当用户在制动器列表中导航时，同步更新 Dialog 的 currentContentItemIndex
                Connections {
                    target: brakeControlPageLoader.item
                    enabled: brakeControlPageLoader.item !== null

                    function onFocusItemIndexChanged() {
                        if (root.currentCategory === 4 &&
                            root.currentFocusArea === 2 &&
                            brakeControlPageLoader.item.focusSubArea === 0 &&
                            brakeControlPageLoader.item.focusItemIndex >= 0) {
                            // 只在焦点在制动器列表区域时同步
                            console.log("✅ [DeviceSettingsDialog] 同步制动器列表焦点:", brakeControlPageLoader.item.focusItemIndex)
                            root.currentContentItemIndex = brakeControlPageLoader.item.focusItemIndex
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
                            // ✅ 2026-01-30 [FIX 100.300.105.1]: keyboardManager 已废弃，注释掉
                            // item.keyboardManager = keyboardManager

                            // ✅ 2026-01-31 [FIX 100.300.112.8]: 初始化焦点状态
                            if (root.currentFocusArea === 2 && root.currentCategory === 5) {
                                item.focusSubArea = 0  // 默认焦点在控制列表区域
                                item.focusItemIndex = root.currentContentItemIndex
                            }
                        }
                    }

                    onStatusChanged: {
                        if (tensionControlPageLoader.status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] TensionControlPage 加载失败")
                        }
                    }
                }

                // ✅ 2026-01-31 [FIX 100.300.112.8]: TensionControlPage 焦点同步（从 Dialog 到 Page）
                Connections {
                    target: root
                    enabled: tensionControlPageLoader.item !== null

                    function onCurrentFocusAreaChanged() {
                        if (tensionControlPageLoader.item && root.currentCategory === 5) {
                            if (root.currentFocusArea === 2) {
                                // 焦点进入内容区域，默认在控制列表区域
                                tensionControlPageLoader.item.focusSubArea = 0
                                tensionControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 焦点离开内容区域，清除焦点
                                tensionControlPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentCategoryChanged() {
                        if (tensionControlPageLoader.item) {
                            if (root.currentCategory === 5 && root.currentFocusArea === 2) {
                                // 切换到张紧控制类别，设置焦点
                                tensionControlPageLoader.item.focusSubArea = 0
                                tensionControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                // 切换到其他类别，清除焦点
                                tensionControlPageLoader.item.focusItemIndex = -1
                            }
                        }
                    }

                    function onCurrentContentItemIndexChanged() {
                        if (tensionControlPageLoader.item &&
                            root.currentFocusArea === 2 &&
                            root.currentCategory === 5) {
                            // 在控制列表中导航
                            tensionControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                        }
                    }
                }

                // ✅ 2026-01-31 [FIX 100.300.112.8.14]: TensionControlPage 反向焦点同步（从 Page 到 Dialog）
                // 当用户在张紧控制列表中导航时，同步更新 Dialog 的 currentContentItemIndex
                Connections {
                    target: tensionControlPageLoader.item
                    enabled: tensionControlPageLoader.item !== null

                    function onFocusItemIndexChanged() {
                        if (root.currentCategory === 5 &&
                            root.currentFocusArea === 2 &&
                            tensionControlPageLoader.item.focusSubArea === 0 &&
                            tensionControlPageLoader.item.focusItemIndex >= 0) {
                            // 只在焦点在控制列表区域时同步
                            console.log("✅ [DeviceSettingsDialog] 同步张紧控制列表焦点:", tensionControlPageLoader.item.focusItemIndex)
                            root.currentContentItemIndex = tensionControlPageLoader.item.focusItemIndex
                        }
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113]: 6: 串口控制
                Loader {
                    id: serialPortControlPageLoader
                    source: "pages/SerialPortControlPage.qml"

                    onLoaded: {
                        console.log("✅ [DeviceSettingsDialog] SerialPortControlPage 加载成功")
                    }

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.error("❌ [DeviceSettingsDialog] SerialPortControlPage 加载失败")
                        }
                    }

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 5]: 添加焦点连接
                    Connections {
                        target: root
                        enabled: serialPortControlPageLoader.item !== null

                        function onCurrentFocusAreaChanged() {
                            console.log("🔍 [串口控制同步] onCurrentFocusAreaChanged - currentFocusArea:", root.currentFocusArea, "currentCategory:", root.currentCategory)
                            if (serialPortControlPageLoader.item && root.currentCategory === 6) {
                                if (root.currentFocusArea === 2) {
                                    // 焦点进入内容区域，默认在列表区域
                                    console.log("✅ [串口控制同步] 焦点进入内容区域 - 设置 focusSubArea=0, focusItemIndex=", root.currentContentItemIndex)
                                    serialPortControlPageLoader.item.focusSubArea = 0
                                    serialPortControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                                } else {
                                    // 焦点离开内容区域，清除焦点
                                    console.log("✅ [串口控制同步] 焦点离开内容区域 - 清除 focusItemIndex")
                                    serialPortControlPageLoader.item.focusItemIndex = -1
                                }
                            }
                        }

                        function onCurrentCategoryChanged() {
                            console.log("🔍 [串口控制同步] onCurrentCategoryChanged - currentCategory:", root.currentCategory, "currentFocusArea:", root.currentFocusArea)
                            if (serialPortControlPageLoader.item) {
                                if (root.currentFocusArea === 2 && root.currentCategory === 6) {
                                    // 切换到串口控制类别，设置焦点
                                    console.log("✅ [串口控制同步] 切换到串口控制 - 设置 focusSubArea=0, focusItemIndex=", root.currentContentItemIndex)
                                    serialPortControlPageLoader.item.focusSubArea = 0
                                    serialPortControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                                } else {
                                    // 切换到其他类别，清除焦点
                                    console.log("✅ [串口控制同步] 切换到其他类别 - 清除 focusItemIndex")
                                    serialPortControlPageLoader.item.focusItemIndex = -1
                                }
                            }
                        }

                        function onCurrentContentItemIndexChanged() {
                            console.log("🔍 [串口控制同步] onCurrentContentItemIndexChanged - currentContentItemIndex:", root.currentContentItemIndex)
                            if (serialPortControlPageLoader.item &&
                                root.currentFocusArea === 2 &&
                                root.currentCategory === 6 &&
                                serialPortControlPageLoader.item.focusSubArea === 0) {
                                // 只在焦点在列表区域时同步
                                console.log("✅ [串口控制同步] 同步 focusItemIndex:", root.currentContentItemIndex)
                                serialPortControlPageLoader.item.focusItemIndex = root.currentContentItemIndex
                            } else {
                                console.log("⚠️ [串口控制同步] 不满足同步条件 - focusArea:", root.currentFocusArea, "category:", root.currentCategory, "focusSubArea:", serialPortControlPageLoader.item ? serialPortControlPageLoader.item.focusSubArea : "null")
                            }
                        }
                    }

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 5]: 监听串口控制页面焦点变化
                    Connections {
                        target: serialPortControlPageLoader.item
                        enabled: serialPortControlPageLoader.item !== null

                        function onFocusItemIndexChanged() {
                            if (serialPortControlPageLoader.item &&
                                root.currentCategory === 6 &&
                                root.currentFocusArea === 2 &&
                                serialPortControlPageLoader.item.focusSubArea === 0 &&
                                serialPortControlPageLoader.item.focusItemIndex >= 0) {
                                // 只在焦点在列表区域时同步
                                console.log("✅ [DeviceSettingsDialog] 同步串口控制列表焦点:", serialPortControlPageLoader.item.focusItemIndex)
                                root.currentContentItemIndex = serialPortControlPageLoader.item.focusItemIndex
                            }
                        }

                        function onRequestReturnToCategory() {
                            // 串口控制页面请求返回到左侧类别
                            console.log("✅ [DeviceSettingsDialog] 串口控制请求返回类别")
                            root.currentFocusArea = 1  // 切换到左侧类别区域
                        }
                    }
                }

                // 7: 逻辑控制
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
        var names = ["基本配置", "开关量输入", "模拟量输入", "电机控制", "制动器控制", "张紧控制", "串口控制", "逻辑控制"]
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
        case 6: // 串口控制
            return []  // ✅ 2026-02-04 [FIX 100.300.113]: 串口控制暂无底部按钮
        case 7: // 逻辑控制
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
            return 5  // ✅ 2026-01-30 [FIX 100.300.105]: 5个模拟量保护项
        case 3:  // 电机控制
            return 8  // ✅ 2026-01-30 [FIX 100.300.106]: 8个电机
        case 4:  // 制动器控制
            return 9  // 9个输入组件
        case 5:  // 张紧控制
            return 14  // 14个输入组件
        case 6:  // 串口控制
            return 6  // ✅ 2026-02-04 [FIX 100.300.113 Phase 5.3]: 6个串口（COM1-COM6）
        case 7:  // 逻辑控制
            return 0  // 待实现
        default:
            return 0
        }
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 触发顶部按钮
    function triggerTopButton(buttonIndex) {
        switch(buttonIndex) {
        case 0:  // 关闭
            console.log("🔍 [DeviceSettingsDialog] ========== 导航触发关闭 ==========")
            console.log("🔍 [DeviceSettingsDialog] 关闭前 - modalContainer.visible:", modalContainer.visible)
            console.log("🔍 [DeviceSettingsDialog] 关闭前 - modalContainer.parentContainer:", modalContainer.parentContainer)

            // ✅ 2026-01-30 [修复]: 隐藏整个 modalContainer（包括遮罩层），而不是只隐藏 root
            modalContainer.visible = false

            console.log("🔍 [DeviceSettingsDialog] 关闭后 - modalContainer.visible:", modalContainer.visible)

            // ✅ 2026-01-30 [修复]: 使用保存的 parentContainer 引用恢复焦点
            if (modalContainer.parentContainer) {
                console.log("🔍 [DeviceSettingsDialog] 准备恢复焦点到 parentContainer...")
                console.log("🔍 [DeviceSettingsDialog] parentContainer.focus:", modalContainer.parentContainer.focus)
                console.log("🔍 [DeviceSettingsDialog] parentContainer.activeFocus:", modalContainer.parentContainer.activeFocus)

                modalContainer.parentContainer.forceActiveFocus()

                console.log("🔍 [DeviceSettingsDialog] forceActiveFocus() 调用完成")
                console.log("🔍 [DeviceSettingsDialog] parentContainer.focus:", modalContainer.parentContainer.focus)
                console.log("🔍 [DeviceSettingsDialog] parentContainer.activeFocus:", modalContainer.parentContainer.activeFocus)
            }
            console.log("🔍 [DeviceSettingsDialog] =====================================")
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
            return serialPortControlPageLoader.item  // ✅ 2026-02-04 [FIX 100.300.113 Phase 6.5]: 返回串口控制页面
        case 7:
            return null  // 逻辑控制待实现
        default:
            return null
        }
    }
        }  // Rectangle (root)
    }  // FocusScope (dialogFocusScope)
}  // Item (modalContainer)
