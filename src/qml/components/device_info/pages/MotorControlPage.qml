import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15  // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11.1]: 添加 Layouts 导入
import "../" as DeviceInfo  // ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: 导入 NavigationManager

// ✅ 2026-01-25 [电机控制参数设置] 电机控制主页面（左右分栏布局）
// ✅ 2026-01-25 [FIX 100.311]: 重构为模块化设计，支持键盘操作
// ✅ 2026-01-25 [FIX 100.312]: 添加背景图片预留位置
// ✅ 2026-01-25 [FIX 100.314]: 修复QDS预览问题，使用Loader加载组件
// ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: 集成 NavigationManager，实现平面导航
Rectangle {
    id: root
    // ✅ 2026-01-26 [FIX 100.300.25.12]: 使用 implicitWidth/Height 替代固定尺寸，确保运行时正确显示
    implicitWidth: 1000  // 默认宽度（用于QDS预览）
    implicitHeight: 600  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentMotorIndex: 0  // 当前选中的电机索引 (0-7)

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.6]: 暴露 navigationManager 供外部访问
    property alias navigationManager: navigationManager

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引
    // ✅ 2026-01-30 [FIX 100.300.106.2]: 修正 focusSubArea 定义
    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 添加 focusButtonIndex
    // ✅ 2026-02-02 [FIX 100.300.112.8.24.5]: 添加 focusParamIndex 变化监听
    property int focusItemIndex: -1  // -1 表示无焦点
    property int focusSubArea: 0  // 0:电机列表区域 1:Tab区域 2:参数区域 3:按钮区域
    property int focusTabIndex: 0  // Tab区域焦点索引
    property int focusParamIndex: 0  // 参数区域焦点索引
    // ✅ 2026-03-10 [Phase 7.48.29]: 按钮从5个减为3个
    // 旧：property int focusButtonIndex: 0  // 按钮区域焦点索引 (0-4)
    property int focusButtonIndex: 0  // 按钮区域焦点索引 (0-2): 0=保存, 1=删除, 2=重置

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.5]: 监听 focusParamIndex 变化
    // ✅ 2026-02-02 [FIX 100.300.112.8.24.6]: 双向同步 - focusParamIndex 变化时也要更新 NavigationManager
    onFocusParamIndexChanged: {
        console.log("🔶 [MotorControlPage] focusParamIndex 变化:", focusParamIndex)
        console.log("  - focusSubArea:", focusSubArea)
        console.log("  - navigationManager.paramIndex:", navigationManager.paramIndex)
        console.log("  - navigationManager.currentArea:", navigationManager.currentArea)

        // ✅ 双向同步：当 focusParamIndex 变化时，同步更新 NavigationManager 的 paramIndex
        if (focusSubArea === 2 && navigationManager.currentArea === "C" && navigationManager.paramIndex !== focusParamIndex) {
            console.log("🔶 [MotorControlPage] 同步 NavigationManager.paramIndex:", navigationManager.paramIndex, "→", focusParamIndex)
            navigationManager.paramIndex = focusParamIndex
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: Qt 虚拟键盘引用
    property var virtualKeyboard: null

    // ✅ 2026-01-31 [FIX 100.300.112.8.16]: 监听 focusItemIndex 变化，同步到 currentMotorIndex
    // 当 DeviceSettingsDialog 恢复焦点位置时，同步更新选中状态
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < 8) {
            console.log("✅ [MotorControlPage] focusItemIndex 变化:", focusItemIndex, "→ 同步 currentMotorIndex")
            currentMotorIndex = focusItemIndex
            navigationManager.motorListIndex = focusItemIndex
        }
    }

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.5]: 请求 DeviceSettingsDialog 获取焦点
    signal requestDialogFocus()

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: NavigationManager 实例
    DeviceInfo.NavigationManager {
        id: navigationManager

        // 初始化：从电机列表区开始
        Component.onCompleted: {
            currentArea = areaMotorList
            motorListIndex = 0
            tabIndex = 0
            paramIndex = 0
            buttonIndex = 0
            console.log("✅ [MotorControlPage] NavigationManager 初始化完成")

            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.1]: 立即同步初始状态到root
            root.currentMotorIndex = 0
            root.focusItemIndex = 0
            root.focusSubArea = 0
            root.focusTabIndex = 0
            root.focusParamIndex = 0
            console.log("✅ [MotorControlPage] 初始状态已同步 - focusItemIndex:", root.focusItemIndex)

            // ✅ 2026-02-02 [FIX 100.300.112.8.25.5]: 初始化时更新 lastParamIndex
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                if (paramCount > 0) {
                    navigationManager.updateLastParamIndex(paramCount)
                }
                // ✅ 2026-03-22 [Phase 7.48.74]: 更新参数行映射（用于非均匀网格导航）
                navigationManager.paramRows = root.getParamRows()
            })
        }

        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.5]: 修复信号处理器参数问题
        // QML 自动生成的属性变化信号不传递参数，直接使用属性值

        // 监听电机列表索引变化
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.19]: 添加详细调试日志
        onMotorListIndexChanged: {
            console.log("🔍 [DEBUG] NavigationManager.motorListIndex 变化:", motorListIndex)
            console.log("  - 更新前 currentMotorIndex:", root.currentMotorIndex)
            console.log("  - 更新前 focusItemIndex:", root.focusItemIndex)
            root.currentMotorIndex = motorListIndex
            root.focusItemIndex = motorListIndex
            console.log("  - 更新后 currentMotorIndex:", root.currentMotorIndex)
            console.log("  - 更新后 focusItemIndex:", root.focusItemIndex)
            // ✅ 2026-02-02 [参数持久化]: 切换电机时加载配置
            Qt.callLater(root.loadMotorConfig)
        }

        // 监听Tab索引变化，切换参数区显示
        onTabIndexChanged: {
            console.log("✅ [MotorControlPage] Tab索引变化:", tabIndex, "参数区自动切换显示")
            root.focusTabIndex = tabIndex
            // 切换Tab时，参数区自动显示对应的参数
            if (motorConfigPanel.item) {
                motorConfigPanel.item.currentTabIndex = tabIndex
            }

            // ✅ 2026-02-02 [FIX 100.300.112.8.25.5]: 更新 NavigationManager 的 lastParamIndex
            Qt.callLater(function() {
                var paramCount = root.getParamFieldCount()
                if (paramCount > 0) {
                    navigationManager.updateLastParamIndex(paramCount)
                }
                // ✅ 2026-03-22 [Phase 7.48.74]: 更新参数行映射（用于非均匀网格导航）
                navigationManager.paramRows = root.getParamRows()
            })

            // ✅ 2026-02-02 [参数持久化]: 切换Tab时加载配置
            Qt.callLater(root.loadMotorConfig)
        }

        // 监听参数索引变化
        onParamIndexChanged: {
            console.log("✅ [MotorControlPage] 参数索引变化:", paramIndex)
            root.focusParamIndex = paramIndex
        }

        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24]: 监听 returnToCategory 信号，释放焦点
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.2]: 设置标志，防止恶性循环
        onReturnToCategory: {
            console.log("✅ [MotorControlPage] 接收到 returnToCategory 信号，释放焦点")
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.2]: 设置标志，防止后续键盘事件被处理
            root.isReturningToCategory = true
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.6]: 禁用键盘事件接收
            root.keysEnabled = false
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.5]: 主动通知 DeviceSettingsDialog 获取焦点
            root.requestDialogFocus()
            // 释放焦点，让 DeviceSettingsDialog 接管键盘事件
            root.focus = false
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.4]: 启动定时器，延迟重置标志
            resetFlagTimer.start()
        }

        // 监听按钮索引变化
        onButtonIndexChanged: {
            console.log("✅ [MotorControlPage] 按钮索引变化:", buttonIndex)
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 同步按钮焦点索引
            root.focusButtonIndex = buttonIndex
        }

        // 监听区域变化
        onAreaChanged: function(newArea) {
            console.log("✅ [MotorControlPage] 区域变化:", newArea)
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 清除其他区域的焦点指示器
            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 添加按钮区域焦点处理
            // 根据区域更新 focusSubArea，并清除其他区域的焦点索引
            switch(newArea) {
            case areaMotorList:
                root.focusSubArea = 0
                root.focusItemIndex = motorListIndex
                // 清除其他区域的焦点
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaTabBar:
                root.focusSubArea = 1
                root.focusTabIndex = tabIndex
                // 清除其他区域的焦点
                root.focusItemIndex = -1
                root.focusParamIndex = -1
                root.focusButtonIndex = -1
                break
            case areaParams:
                root.focusSubArea = 2
                root.focusParamIndex = paramIndex
                // 清除其他区域的焦点
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusButtonIndex = -1
                break
            case areaButtons:
                root.focusSubArea = 3
                root.focusButtonIndex = buttonIndex
                // 清除其他区域的焦点
                root.focusItemIndex = -1
                root.focusTabIndex = -1
                root.focusParamIndex = -1
                break
            }
        }

        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 监听返回到类别信号
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24]: 移除旧的处理器，已在 Line 136 重新实现
        // onReturnToCategory: {
        //     console.log("✅ [MotorControlPage] 返回到左侧类别")
        //     // 发出信号通知 DeviceSettingsDialog 返回到左侧类别
        //     root.requestReturnToCategory()
        // }
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

    // ✅ 2026-01-30 [FIX 100.300.106]: 允许接收焦点，以便虚拟键盘关闭后焦点可以返回
    focus: true
    activeFocusOnTab: true

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.2]: 防止 returnToCategory 恶性循环
    property bool isReturningToCategory: false

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.6]: 控制是否接收键盘事件
    property bool keysEnabled: true

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.4]: 使用定时器延迟重置标志
    Timer {
        id: resetFlagTimer
        interval: 100  // 100ms 后重置标志
        repeat: false
        onTriggered: {
            console.log("⏰ [DEBUG] 定时器触发，重置 isReturningToCategory 标志")
            root.isReturningToCategory = false
        }
    }

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.20]: 添加焦点变化监听
    onActiveFocusChanged: {
        console.log("🔍 [DEBUG] MotorControlPage 焦点变化:", activeFocus)
        if (!activeFocus) {
            console.log("⚠️ [DEBUG] MotorControlPage 失去焦点！")
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.4]: 不再立即重置标志，由定时器延迟重置
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.2]: 焦点丢失后，重置标志
            // isReturningToCategory = false  // ❌ 移除立即重置，改用定时器
        } else {
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.7]: 焦点恢复时，重新启用键盘事件
            console.log("✅ [DEBUG] MotorControlPage 获得焦点，重新启用键盘事件")
            keysEnabled = true
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2]: 使用 NavigationManager 处理键盘事件
    // ✅ 平面导航逻辑：只用方向键，不用Enter/Esc/Tab
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.19]: 添加详细调试日志
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.2]: 防止 returnToCategory 恶性循环
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.24.6]: 检查是否启用键盘事件
    Keys.onUpPressed: {
        if (!keysEnabled) {
            console.log("⚠️ [DEBUG] 键盘事件已禁用，忽略 Up 键")
            event.accepted = true
            return
        }
        if (isReturningToCategory) {
            console.log("⚠️ [DEBUG] 正在返回大类，忽略 Up 键")
            event.accepted = true
            return
        }
        console.log("🔍 [DEBUG] MotorControlPage 接收到 Up 键")
        console.log("  - currentArea:", navigationManager.currentArea)
        console.log("  - motorListIndex:", navigationManager.motorListIndex)
        console.log("  - currentMotorIndex:", root.currentMotorIndex)
        console.log("  - focusItemIndex:", root.focusItemIndex)
        navigationManager.handleDirectionKey("Up")
        event.accepted = true
    }

    Keys.onDownPressed: {
        if (!keysEnabled) {
            console.log("⚠️ [DEBUG] 键盘事件已禁用，忽略 Down 键")
            event.accepted = true
            return
        }
        if (isReturningToCategory) {
            console.log("⚠️ [DEBUG] 正在返回大类，忽略 Down 键")
            event.accepted = true
            return
        }
        console.log("🔍 [DEBUG] MotorControlPage 接收到 Down 键")
        console.log("  - currentArea:", navigationManager.currentArea)
        console.log("  - motorListIndex:", navigationManager.motorListIndex)
        console.log("  - currentMotorIndex:", root.currentMotorIndex)
        console.log("  - focusItemIndex:", root.focusItemIndex)
        navigationManager.handleDirectionKey("Down")
        event.accepted = true
    }

    Keys.onLeftPressed: function(event) {
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.2]: 只在电机列表区域时返回大类
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.3]: 修复警告，使用函数形式声明 event 参数
        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.4]: 添加标志检查，防止重复处理

        // 检查是否正在返回大类，避免重复处理
        if (isReturningToCategory) {
            console.log("⚠️ [MotorControlPage] Keys.onLeftPressed 正在返回大类，忽略 Left 键")
            event.accepted = true
            return
        }

        if (navigationManager.currentArea === navigationManager.areaMotorList) {
            console.log("✅ [MotorControlPage] 电机列表区域按左键，请求返回到左侧类别")
            // 设置标志，防止 handleKeyPress 重复处理
            root.isReturningToCategory = true
            root.requestReturnToCategory()
            // 启动定时器，延迟重置标志
            resetFlagTimer.start()
            event.accepted = true
        } else {
            // 其他区域由 NavigationManager 处理
            console.log("✅ [MotorControlPage] 其他区域按左键，由 NavigationManager 处理")
            navigationManager.handleDirectionKey("Left")
            event.accepted = true
        }
    }

    Keys.onRightPressed: {
        if (!keysEnabled) {
            console.log("⚠️ [DEBUG] 键盘事件已禁用，忽略 Right 键")
            event.accepted = true
            return
        }
        if (isReturningToCategory) {
            console.log("⚠️ [DEBUG] 正在返回大类，忽略 Right 键")
            event.accepted = true
            return
        }
        navigationManager.handleDirectionKey("Right")
        event.accepted = true
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 旧的键盘导航支持（已废弃，注释掉）
    // Keys.onPressed: {
    //     // 将键盘事件转发给子组件
    //     if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
    //         motorListPanel.item.focus = true
    //     } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
    //         motorConfigPanel.item.focus = true
    //     }
    // }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 改为 ColumnLayout，添加底部按钮区域
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 上部：左右分栏布局 ==========
        Row {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ========== 左侧：电机列表（使用Loader加载）==========
            Loader {
                id: motorListPanel
                // ✅ 2026-01-26 [FIX 100.300.25.16]: 统一列表宽度为 240，与开关量/模拟量一致
                width: 240  // 从 200 改为 240
                height: parent.height
                source: "MyMotorListPanel.qml"

                onLoaded: {
                    item.currentMotorIndex = Qt.binding(function() { return root.currentMotorIndex })
                    // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引
                    item.focusItemIndex = Qt.binding(function() { return root.focusItemIndex })
                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.17]: 鼠标点击时同步更新 focusItemIndex 和 NavigationManager
                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.19]: 添加详细调试日志和 currentArea 检查
                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.20]: 添加强制恢复焦点
                    item.motorSelected.connect(function(motorIndex) {
                        console.log("🔍 [DEBUG] 鼠标点击电机:", motorIndex)
                        console.log("  - 点击前 currentArea:", navigationManager.currentArea)
                        console.log("  - 点击前 motorListIndex:", navigationManager.motorListIndex)
                        console.log("  - 点击前 MotorControlPage.activeFocus:", root.activeFocus)

                        root.currentMotorIndex = motorIndex
                        root.focusItemIndex = motorIndex  // 同步更新焦点索引（蓝色边框）
                        navigationManager.motorListIndex = motorIndex  // 同步更新 NavigationManager

                        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.19]: 确保 currentArea 是 areaMotorList
                        if (navigationManager.currentArea !== navigationManager.areaMotorList) {
                            console.log("🔍 [DEBUG] 切换 currentArea 到 areaMotorList")
                            navigationManager.currentArea = navigationManager.areaMotorList
                        }

                        // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.20]: 强制恢复焦点到 MotorControlPage
                        if (!root.activeFocus) {
                            console.log("🔍 [DEBUG] 强制恢复焦点到 MotorControlPage")
                            root.forceActiveFocus()
                        }

                        console.log("  - 点击后 currentArea:", navigationManager.currentArea)
                        console.log("  - 点击后 motorListIndex:", navigationManager.motorListIndex)
                        console.log("  - 点击后 MotorControlPage.activeFocus:", root.activeFocus)
                        console.log("✅ [MotorControlPage] 选中电机:", motorIndex + 1, "- 已同步 focusItemIndex 和 NavigationManager")
                    })
                }
            }

            // ========== 分隔线 ==========
            Rectangle {
                width: 2
                height: parent.height
                color: "#3d4556"
            }

            // ========== 右侧：电机配置面板（使用Loader加载）==========
            Loader {
                id: motorConfigPanel
                width: parent.width - motorListPanel.width - 2
                height: parent.height
                source: "MotorConfigPanel.qml"

                onLoaded: {
                    item.motorIndex = Qt.binding(function() { return root.currentMotorIndex })
                    // ✅ 2026-01-30 [FIX 100.300.106]: 传递焦点索引和虚拟键盘
                    // ✅ 2026-01-30 [FIX 100.300.106.2]: 直接传递 focusSubArea
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })
                    item.focusTabIndex = Qt.binding(function() { return root.focusTabIndex })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })

                    // ✅ 2026-02-02 [FIX 100.300.112.8.24.8]: 连接信号，更新 NavigationManager
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        console.log("✅ [MotorControlPage] 接收信号: requestFocusParamIndex(" + paramIndex + ")")
                        console.log("  - 更新 NavigationManager.paramIndex:", navigationManager.paramIndex, "→", paramIndex)

                        // 更新 NavigationManager 的 paramIndex
                        // NavigationManager 会自动触发 focusParamIndex 的更新
                        navigationManager.paramIndex = paramIndex
                    })

                    // ✅ 2026-03-22 [Phase 7.48.81]: 首次加载时主动加载电机配置
                    // 原因：currentMotorIndex 初始值为0，不触发 onCurrentMotorIndexChanged，
                    // 导致首次显示1号电机时使用默认值而非数据库保存的配置
                    Qt.callLater(root.loadMotorConfig)
                }
            }
        }

        // ========== 底部：按钮区域 ==========
        // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11]: 添加底部按钮区域
        Rectangle {
            Layout.fillWidth: true
            // ✅ 2026-03-10 [Phase 7.48.29]: 从两行按钮改为单行（删除"添加电机保护"和"删除电机保护"）
            // 旧：Layout.preferredHeight: 90  // 两行按钮，每行35高度 + 间距
            Layout.preferredHeight: 55  // 单行按钮：35高度 + 上下间距
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

                // ✅ 2026-03-10 [Phase 7.48.29]: 删除第一行按钮（添加电机保护 + 删除电机保护）
                // 旧：第一行 [0] 添加电机保护 [1] 删除电机保护
                //     第二行 [2] 保存 [3] 删除 [4] 重置
                // 新：单行 [0] 保存 [1] 删除 [2] 重置

                // 保存、删除、重置
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: saveButton
                        text: "保存"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11.2]: 增强焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                // ✅ 2026-03-10 [Phase 7.48.29]: 旧 focusButtonIndex === 2，改为 0
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
                            // 增加边框宽度：2px → 5px
                            // ✅ 2026-03-10 [Phase 7.48.29]: 旧 focusButtonIndex === 2，改为 0
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
                            console.log("✅ [MotorControlPage] 保存")
                            // ✅ 2026-02-02 [参数持久化]: 调用保存函数
                            root.saveMotorConfig()
                        }
                    }

                    Button {
                        id: deleteButton
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11.2]: 增强焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                // ✅ 2026-03-10 [Phase 7.48.29]: 旧 focusButtonIndex === 3，改为 1
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 1) {
                                    return "#e74c3c"  // 焦点时：亮橙色
                                } else if (parent.pressed) {
                                    return "#c0392b"
                                } else if (parent.hovered) {
                                    return "#e74c3c"
                                } else {
                                    return "#d35400"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：2px → 5px
                            // ✅ 2026-03-10 [Phase 7.48.29]: 旧 focusButtonIndex === 3，改为 1
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
                            console.log("✅ [MotorControlPage] 删除")
                            // ✅ 2026-03-10 [Phase 7.48.31]: 实现删除功能（恢复默认值）
                            root.resetMotorConfigToDefaults()
                        }
                    }

                    Button {
                        id: resetButton
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.11.2]: 增强焦点指示器
                            // 焦点时背景色更亮
                            color: {
                                // ✅ 2026-03-10 [Phase 7.48.29]: 旧 focusButtonIndex === 4，改为 2
                                if (root.focusSubArea === 3 && root.focusButtonIndex === 2) {
                                    return "#95a5a6"  // 焦点时：亮灰色
                                } else if (parent.pressed) {
                                    return "#7f8c8d"
                                } else if (parent.hovered) {
                                    return "#95a5a6"
                                } else {
                                    return "#7f8c8d"
                                }
                            }
                            radius: 4
                            // 增加边框宽度：2px → 5px
                            // ✅ 2026-03-10 [Phase 7.48.29]: 旧 focusButtonIndex === 4，改为 2
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
                            console.log("✅ [MotorControlPage] 重置")
                            // ✅ 2026-03-10 [Phase 7.48.31]: 实现重置功能（重新加载数据库值）
                            root.loadMotorConfig()
                        }
                    }
                }
            }
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    function getParamFieldCount() {
        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (currentTab && typeof currentTab.getParamFieldCount === "function") {
            return currentTab.getParamFieldCount()
        }
        return 0
    }

    // ✅ 2026-03-22 [Phase 7.48.74]: 获取当前Tab的参数行映射（用于非均匀网格导航）
    function getParamRows() {
        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (currentTab && typeof currentTab.getParamRows === "function") {
            return currentTab.getParamRows()
        }
        return []  // 空数组=使用默认paramColumns均匀网格
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [MotorControlPage] 触发参数输入 - 索引:", paramIndex)

        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (currentTab && typeof currentTab.triggerParamInput === "function") {
            currentTab.triggerParamInput(paramIndex)
        } else {
            console.log("⚠️ [MotorControlPage] 当前 Tab 不支持参数输入")
        }
    }

    // 切换 Tab
    function triggerTabSwitch(tabIndex) {
        console.log("✅ [MotorControlPage] 切换 Tab - 索引:", tabIndex)
        if (motorConfigPanel.item) {
            motorConfigPanel.item.currentTabIndex = tabIndex
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.8]: 公开信号，供 DeviceSettingsDialog 监听
    signal requestReturnToCategory()  // 请求返回到左侧类别

    // ✅ 2026-01-30 [FIX 100.300.109 Phase 2.4]: 公开键盘事件处理函数
    // 供DeviceSettingsDialog调用，转发键盘事件给NavigationManager
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25]: 简化为直接处理
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.3]: 检查 currentArea，只在电机列表区域时返回大类
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.25.4]: 添加标志检查，防止重复处理
    function handleKeyPress(direction) {
        // 检查是否正在返回大类，避免重复处理
        if (isReturningToCategory) {
            console.log("⚠️ [MotorControlPage] handleKeyPress 正在返回大类，忽略键盘事件:", direction)
            return
        }

        // 左键：检查当前区域
        if (direction === "Left") {
            if (navigationManager.currentArea === navigationManager.areaMotorList) {
                console.log("✅ [MotorControlPage] handleKeyPress 电机列表区域按左键，请求返回到左侧类别")
                // 设置标志，防止 Keys.onLeftPressed 重复处理
                root.isReturningToCategory = true
                root.requestReturnToCategory()
                // 启动定时器，延迟重置标志
                resetFlagTimer.start()
                return
            } else {
                // 其他区域由 NavigationManager 处理
                console.log("✅ [MotorControlPage] handleKeyPress 其他区域按左键，由 NavigationManager 处理")
                navigationManager.handleDirectionKey("Left")
                return
            }
        }

        // 其他方向键正常处理
        console.log("✅ [MotorControlPage] 接收键盘事件:", direction)
        navigationManager.handleDirectionKey(direction)
    }

    // ✅ 2026-02-02 [参数持久化]: 保存电机配置
    function saveMotorConfig() {
        console.log("✅ [MotorControlPage] 保存电机配置 - 设备:", root.deviceId, "电机:", root.currentMotorIndex, "Tab:", root.focusTabIndex)

        // 获取当前 Tab 的参数
        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (!currentTab) {
            console.log("⚠️ [MotorControlPage] 无法获取当前 Tab")
            return false
        }

        // 收集参数（根据不同 Tab 类型收集不同参数）
        var config = {}

        // 根据 Tab 索引确定 Tab 名称
        // ✅ 2026-03-10 [Phase 7.48.29]: 从10个扩展到14个Tab
        // 旧：10个Tab（基本配置 + 9个保护）
        // ✅ 2026-03-13 [Phase 7.48.43]: A/B/C→甲/乙/丙，X/Y→水平/垂直（TTS中文兼容）
        var tabNames = [
            "基本配置", "电流保护", "前轴承温度", "后轴承温度", "甲相绕组",
            "乙相绕组", "丙相绕组", "电机温度", "水平振动", "垂直振动",
            "堵转保护", "起动超时", "功率保护", "三相不平衡"
        ]
        config["tab_name"] = tabNames[root.focusTabIndex] || "未知Tab"

        // 调用 Tab 的 collectConfig() 方法收集参数
        if (typeof currentTab.collectConfig === "function") {
            var tabConfig = currentTab.collectConfig()
            // 合并 Tab 配置到主配置
            for (var key in tabConfig) {
                config[key] = tabConfig[key]
            }
        } else {
            console.log("⚠️ [MotorControlPage] 当前 Tab 不支持 collectConfig()")
            return false
        }

        // 保存到数据库
        var success = deviceConfigMgr.saveMotorConfig(
            root.deviceId,
            root.currentMotorIndex,
            root.focusTabIndex,
            config
        )

        if (success) {
            console.log("✅ [MotorControlPage] 保存成功")

            // ✅ 2026-03-22 [Phase 7.48.82]: 保存成功后同步反馈配置到 CommonControl
            // 原因：ParameterSettings.syncDeviceFeedbackConfigs() 只在启动时调用一次，
            //       修改 use_feedback 后 CommonControl 内存中仍是旧值，导致反馈检测不生效
            if (root.focusTabIndex === 0 && typeof commonControl !== "undefined") {
                var motorName = (root.currentMotorIndex + 1) + "号电机"
                var useFeedback = config["use_feedback"] !== undefined ? (Number(config["use_feedback"]) === 1) : true
                var feedbackChannel = config["feedback_channel"] !== undefined ? config["feedback_channel"] : root.currentMotorIndex
                var feedbackDelay = config["feedback_delay"] || 3
                commonControl.setDeviceFeedbackConfig(motorName, useFeedback, feedbackChannel, feedbackDelay)
                console.log("✅ [MotorControlPage] 已同步反馈配置到CommonControl -", motorName,
                           "useFeedback:", useFeedback, "channel:", feedbackChannel, "delay:", feedbackDelay)
            }
        } else {
            console.log("❌ [MotorControlPage] 保存失败")
        }

        return success
    }

    // ✅ 2026-02-02 [参数持久化]: 加载电机配置
    function loadMotorConfig() {
        console.log("✅ [MotorControlPage] 加载电机配置 - 设备:", root.deviceId, "电机:", root.currentMotorIndex, "Tab:", root.focusTabIndex)

        // 从数据库加载配置
        var config = deviceConfigMgr.loadMotorConfig(
            root.deviceId,
            root.currentMotorIndex,
            root.focusTabIndex
        )

        if (!config || Object.keys(config).length === 0) {
            console.log("⚠️ [MotorControlPage] 未找到配置，使用默认值")
            // ✅ 2026-03-10 [Phase 7.48.36]: 未找到配置时，用motorIndex生成默认配置并应用
            // 原因：applyConfig会打破QML绑定，切换电机后需要重新设置默认值
            var currentTab0 = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
            if (currentTab0 && typeof currentTab0.applyConfig === "function") {
                var defaultConfig = {
                    "motor_module_address": 1,
                    // ✅ 2026-03-24 [Phase 7.48.88.7]: 电机1-5通道1-5，电机6-8通道-1
                    // 旧代码："output_channel": root.currentMotorIndex + 1
                    "output_channel": root.currentMotorIndex < 5 ? root.currentMotorIndex + 1 : -1,
                    "use_feedback": 1,
                    "feedback_channel": root.currentMotorIndex,
                    "feedback_delay": 3
                }
                currentTab0.applyConfig(defaultConfig)
                console.log("✅ [MotorControlPage] 已应用默认配置 - 电机:", root.currentMotorIndex)
            }
            return false
        }

        // 获取当前 Tab
        var currentTab = motorConfigPanel.item ? motorConfigPanel.item.getCurrentTab() : null
        if (!currentTab) {
            console.log("⚠️ [MotorControlPage] 无法获取当前 Tab")
            return false
        }

        // 调用 Tab 的 applyConfig() 方法应用配置
        if (typeof currentTab.applyConfig === "function") {
            currentTab.applyConfig(config)
            console.log("✅ [MotorControlPage] 配置已应用")
        } else {
            console.log("⚠️ [MotorControlPage] 当前 Tab 不支持 applyConfig()")
            return false
        }

        return true
    }

    // ✅ 2026-03-10 [Phase 7.48.31]: 恢复默认值（删除按钮功能）
    // 删除当前 Tab 的数据库记录，然后重新加载（会使用默认值）
    function resetMotorConfigToDefaults() {
        console.log("✅ [MotorControlPage] 恢复默认值 - 设备:", root.deviceId, "电机:", root.currentMotorIndex, "Tab:", root.focusTabIndex)

        // 删除数据库中的当前配置
        var success = deviceConfigMgr.deleteMotorConfig(
            root.deviceId,
            root.currentMotorIndex,
            root.focusTabIndex
        )

        if (success) {
            console.log("✅ [MotorControlPage] 已删除配置，重新加载默认值")
            // 重新加载（数据库无记录时会使用默认值）
            root.loadMotorConfig()
        } else {
            console.log("⚠️ [MotorControlPage] 删除配置失败")
        }
    }
}
