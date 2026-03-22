import QtQuick
import QtQuick.Controls
import Input1
// ✅ 2026-01-31 [FIX 100.300.112.8.10]: 删除 Input1Content 导入（模块不存在）
// import Input1Content  // ❌ 此模块未在 CMakeLists.txt 中定义

// ✅ 2026-01-27 [FIX 100.300.54]: Screen01 包装器 - 添加键盘导航功能
// ✅ 2026-01-27 [FIX 100.300.56]: 添加 Input1Content 导入以加载 Screen01Form
// ✅ 2026-01-27 [FIX 100.300.58]: 增强焦点管理和调试信息
// ✅ 2026-01-28 [FIX 100.300.60]: 添加 dataItems 空值检查，修复 QDS 中 undefined 错误
// ✅ 2026-01-28 [FIX 100.300.62]: 改用直接访问组件方式，修复 QDS 中 dataItems 未定义问题
// ✅ 2026-01-28 [FIX 100.300.67]: 添加鼠标单击选中和双击打开弹窗功能
// ✅ 2026-01-28 [FIX 100.300.68]: 修复闭包陷阱，使用立即执行函数（IIFE）捕获索引
Item {
    id: root
    width: 1920
    height: 1080

    property int currentPageIndex: 0
    property int selectedIndex: 0

    // ✅ 2026-03-22 [Phase 7.48.82.2]: 区分QDS独立预览与设备SwipeView运行
    // QDS独立运行时保持true（需要焦点），通过Input1Page.onLoaded设为false（设备模式）
    property bool autoFocusOnLoad: true

    readonly property int rows: 3
    readonly property int cols: 4
    readonly property int totalItems: 12

    focus: true
    activeFocusOnTab: true

    // ✅ 2026-01-30 [调试]: 详细追踪焦点变化
    onActiveFocusChanged: {
        console.log("🔍 [Screen01] ========== 焦点状态变化 ==========")
        console.log("🔍 [Screen01] activeFocus:", activeFocus ? "✅ 获得焦点" : "❌ 失去焦点")
        console.log("🔍 [Screen01] focus 属性:", focus)
        console.log("🔍 [Screen01] parent:", parent)
        console.log("🔍 [Screen01] parent.objectName:", parent ? parent.objectName : "无")
        console.log("🔍 [Screen01] =====================================")
    }

    onFocusChanged: {
        console.log("🔍 [Screen01] focus 属性变化:", focus)
    }

    // ✅ 2026-01-28 [FIX 100.300.65]: 添加双击事件打开设备设置对话框
    // ✅ 2026-01-28 [FIX 100.300.67]: 修改为仅处理空白区域点击，不阻止子组件鼠标事件
    MouseArea {
        anchors.fill: parent
        z: -1  // 放在最底层，只处理空白区域
        onClicked: {
            console.log("[Screen01] 🖱️ 点击空白区域，强制获取焦点")
            root.forceActiveFocus()
        }
    }

    Screen01Form {
        id: screen01Form
        anchors.fill: parent
        currentPageIndex: root.currentPageIndex

        Component.onCompleted: {
            console.log("[Screen01Form] ✅ 组件加载完成")
        }
    }

    // ❌ 2026-02-10 [Phase 7.45.7]: 移除设备监控按钮和对话框
    // 原因：设备监控已改为独立页面，在 main_qds.qml 的 SwipeView 中
    // 用户可通过导航栏切换到设备监控页面
    /*
    // ✅ 2026-02-10 [Phase 7.45.5]: 设备监控按钮
    Button {
        id: deviceMonitorButton
        ...
    }

    // ✅ 2026-02-10 [Phase 7.45.5]: 设备监控对话框
    Loader {
        id: deviceMonitorDialogLoader
        ...
    }
    */

    // ========== 页面内设备卡片点击处理 ==========

    // ✅ 2026-01-28 [FIX 100.300.62]: 直接访问 Screen01Form 的子组件
    function getDataItems() {
        return [
            screen01Form.data_row1_col1,
            screen01Form.data_row1_col2,
            screen01Form.data_row1_col3,
            screen01Form.data_row1_col4,
            screen01Form.data_row2_col1,
            screen01Form.data_row2_col2,
            screen01Form.data_row2_col3,
            screen01Form.data_row2_col4,
            screen01Form.data_row3_col1,
            screen01Form.data_row3_col2,
            screen01Form.data_row3_col3,
            screen01Form.data_row3_col4
        ]
    }

    // ✅ 2026-01-28 [FIX 100.300.67]: 为每个数据组件添加鼠标交互
    // 功能：单击选中，双击打开设备设置对话框
    // ✅ 2026-01-28 [FIX 100.300.68]: 修复闭包陷阱，使用立即执行函数捕获索引
    function setupMouseInteraction() {
        var dataItems = getDataItems()
        console.log("[Screen01] 🖱️ 开始设置鼠标交互...")

        for (var i = 0; i < dataItems.length; i++) {
            var item = dataItems[i]
            if (!item) {
                console.warn("[Screen01] ⚠️ 组件", i, "为 null，跳过鼠标交互设置")
                continue
            }

            // 使用立即执行函数（IIFE）捕获当前索引，避免闭包陷阱
            (function(currentIndex, currentItem) {
                // 为每个组件创建 MouseArea
                var mouseAreaComponent = Qt.createQmlObject(
                    'import QtQuick 2.15; MouseArea { anchors.fill: parent; hoverEnabled: true }',
                    currentItem,
                    "dynamicMouseArea_" + currentIndex
                )

                if (mouseAreaComponent) {
                    // 单击选中
                    mouseAreaComponent.clicked.connect(function() {
                        console.log("[Screen01] 🖱️ 单击组件", currentIndex)
                        root.selectedIndex = currentIndex
                        root.updateSelection()
                        root.forceActiveFocus()
                    })

                    // 双击打开设备设置
                    mouseAreaComponent.doubleClicked.connect(function() {
                        console.log("[Screen01] 🖱️🖱️ 双击组件", currentIndex, "- 打开设备设置对话框")
                        root.selectedIndex = currentIndex
                        root.updateSelection()
                        root.openDeviceSettings()
                    })

                    // 鼠标悬停效果（可选）
                    mouseAreaComponent.onEntered.connect(function() {
                        console.log("[Screen01] 🖱️ 鼠标悬停在组件", currentIndex)
                    })

                    console.log("[Screen01] ✅ 组件", currentIndex, "鼠标交互已设置")
                } else {
                    console.error("[Screen01] ❌ 无法为组件", currentIndex, "创建 MouseArea")
                }
            })(i, item)  // 立即执行，传入当前索引和组件
        }

        console.log("[Screen01] 🖱️ 鼠标交互设置完成")
    }

    function updateSelection() {
        // ✅ 2026-01-28 [FIX 100.300.62]: 使用 getDataItems() 直接访问
        var dataItems = getDataItems()

        // 检查是否有有效组件
        var validCount = 0
        for (var i = 0; i < dataItems.length; i++) {
            if (dataItems[i]) validCount++
        }

        if (validCount === 0) {
            console.warn("[Screen01] ⚠️ 没有有效的 dataItems，跳过更新")
            return
        }

        console.log("[Screen01] 🔄 updateSelection 开始，selectedIndex:", selectedIndex, "有效组件:", validCount)
        var successCount = 0
        for (var i = 0; i < dataItems.length; i++) {
            var item = dataItems[i]
            if (item) {
                item.selected = (i === selectedIndex)
                if (item.selected) {
                    console.log("[Screen01] ✅ 组件", i, "已选中")
                }
                successCount++
            } else {
                console.warn("[Screen01] ⚠️ 组件", i, "为 null")
            }
        }
        console.log("[Screen01] 🔄 updateSelection 完成，成功更新", successCount, "个组件")
    }

    // ✅ 2026-01-28 [FIX 100.300.65]: 添加打开设备设置对话框函数
    // ✅ 2026-01-28 [FIX 100.300.66]: 修复 open() 不是函数错误，使用 visible 属性
    // ✅ 2026-01-30 [修复]: 使用 root 作为父容器，以便对话框关闭后焦点返回到 Screen01
    // ✅ 2026-01-30 [调试]: 添加详细的焦点追踪日志
    // ✅ 2026-01-30 [修复]: 传递 parentContainer 引用，解决 FocusScope 层级问题
    function openDeviceSettings() {
        console.log("🔍 [Screen01] ========== 打开对话框 ==========")
        console.log("🔍 [Screen01] 当前选中索引:", selectedIndex)
        console.log("🔍 [Screen01] 打开前 - activeFocus:", activeFocus)
        console.log("🔍 [Screen01] 打开前 - focus:", focus)

        // ✅ 2026-03-22 [Phase 7.48.82.5]: 前8个为1-8号皮带，后4个未定义不可打开
        if (selectedIndex >= 8) {
            console.log("⚠️ [Screen01] 设备", selectedIndex + 1, "未定义，跳过打开设置")
            return
        }

        // 创建并显示 DeviceSettingsDialog
        var component = Qt.createComponent("../../components/device_info/DeviceSettingsDialog.qml")
        if (component.status === Component.Ready) {
            // ✅ 2026-03-22 [Phase 7.48.82.4]: 根据选中索引传递不同的deviceId和deviceName
            // 原因：12个设备卡片都使用默认deviceId=1，导致修改一个设备的参数影响所有设备
            var deviceIndex = selectedIndex + 1  // 设备编号从1开始
            var dialog = component.createObject(root, {
                // ✅ 2026-01-30 [修复]: 传递 parentContainer 引用，用于焦点恢复
                parentContainer: root,
                deviceId: deviceIndex,
                deviceName: deviceIndex + "号皮带"
            })
            if (dialog) {
                console.log("🔍 [Screen01] 对话框创建成功")
                console.log("🔍 [Screen01] dialog.parent === root:", dialog.parent === root)
                console.log("🔍 [Screen01] dialog.parent:", dialog.parent)
                console.log("🔍 [Screen01] dialog.parentContainer === root:", dialog.parentContainer === root)

                // ✅ 2026-01-28 [FIX 100.300.66]: DeviceSettingsDialog 是 Rectangle，使用 visible 而不是 open()
                dialog.visible = true
                dialog.z = 1000  // 确保在最上层

                console.log("🔍 [Screen01] 对话框已显示")
                console.log("🔍 [Screen01] 打开后 - activeFocus:", activeFocus)
                console.log("🔍 [Screen01] 打开后 - focus:", focus)
                console.log("🔍 [Screen01] =====================================")
            } else {
                console.error("[Screen01] ❌ 无法创建 DeviceSettingsDialog 对象")
            }
        } else if (component.status === Component.Error) {
            console.error("[Screen01] ❌ DeviceSettingsDialog 加载失败:", component.errorString())
        }
    }

    Component.onCompleted: {
        console.log("[Screen01] ✅ 组件加载完成")

        // ✅ 2026-01-28 [FIX 100.300.62]: 延迟初始化，等待 Screen01Form 的子组件加载
        Qt.callLater(function() {
            var dataItems = getDataItems()
            var validCount = 0
            for (var i = 0; i < dataItems.length; i++) {
                if (dataItems[i]) validCount++
            }

            console.log("[Screen01] 📊 dataItems 有效数量:", validCount, "/ 12")

            if (validCount > 0) {
                console.log("[Screen01] 🔄 初始化选中状态...")
                updateSelection()

                // ✅ 2026-01-28 [FIX 100.300.67]: 设置鼠标交互
                console.log("[Screen01] 🖱️ 设置鼠标交互...")
                setupMouseInteraction()
            } else {
                console.warn("[Screen01] ⚠️ dataItems 仍未定义，跳过初始化")
            }
        })

        // ✅ 2026-03-22 [Phase 7.48.82.2]: 延迟检查焦点模式
        // QDS独立预览: autoFocusOnLoad保持true → 获取焦点（导航键可用）
        // 设备SwipeView: Input1Page.onLoaded 已将 autoFocusOnLoad 设为 false → 不抢焦点
        // 旧代码：root.forceActiveFocus()  // 无条件抢夺导致设备启动时右键被拦截
        Qt.callLater(function() {
            if (root.autoFocusOnLoad) {
                console.log("[Screen01] 🎯 QDS独立模式，获取焦点")
                root.forceActiveFocus()
            } else {
                console.log("[Screen01] 🎯 SwipeView模式，跳过焦点获取（由App.qml管理）")
            }
        })
    }

    onSelectedIndexChanged: {
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols
        console.log("[Screen01] 📍 selectedIndex 变化:", selectedIndex, "→ 行", row, "列", col)
    }

    Keys.onPressed: function(event) {
        console.log("[Screen01] ⌨️ 按键事件 - Key:", event.key, "焦点:", activeFocus ? "✅" : "❌")

        if (!activeFocus) {
            console.warn("[Screen01] ⚠️ 无焦点，按键被忽略！请点击屏幕获取焦点")
            return
        }

        var oldIndex = selectedIndex
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols

        var keyName = ""
        if (event.key === Qt.Key_Up) {
            keyName = "↑ 上"
            if (row > 0) {
                selectedIndex = (row - 1) * cols + col
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在第一行，无法向上")
            }
        } else if (event.key === Qt.Key_Down) {
            keyName = "↓ 下"
            if (row < rows - 1) {
                selectedIndex = (row + 1) * cols + col
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在最后一行，无法向下")
            }
        } else if (event.key === Qt.Key_Left) {
            keyName = "← 左"
            if (col > 0) {
                selectedIndex = row * cols + (col - 1)
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在第一列，无法向左")
            }
        } else if (event.key === Qt.Key_Right) {
            keyName = "→ 右"
            if (col < cols - 1) {
                selectedIndex = row * cols + (col + 1)
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在最后一列，无法向右")
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // ✅ 2026-01-28 [FIX 100.300.65]: 添加回车键打开设备设置对话框
            console.log("[Screen01] ⏎ 回车键 - 打开设备设置对话框，索引:", selectedIndex)
            openDeviceSettings()
            event.accepted = true
        } else {
            console.log("[Screen01] ℹ️ 未处理的按键:", event.key)
        }

        if (oldIndex !== selectedIndex) {
            console.log("[Screen01] 🎯 导航成功:", keyName, "- 索引", oldIndex, "→", selectedIndex)
            updateSelection()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.activeFocus ? "yellow" : "red"
        border.width: 3
        z: 1000
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        width: 300
        height: 120
        color: "#80000000"
        z: 999

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Text {
                text: "焦点: " + (root.activeFocus ? "✅ 有" : "❌ 无")
                color: root.activeFocus ? "#00FF00" : "#FF0000"
                font.pixelSize: 18
                font.bold: true
            }

            Text {
                text: "选中: " + selectedIndex
                color: "white"
                font.pixelSize: 16
            }

            Text {
                text: "行" + Math.floor(selectedIndex / cols) + " 列" + (selectedIndex % cols)
                color: "white"
                font.pixelSize: 16
            }

            Text {
                text: "点击屏幕获取焦点"
                color: "#FFFF00"
                font.pixelSize: 12
            }
        }
    }
}
