import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-28 [FIX 100.300.78]: 自定义 ComboBox 组件，使用 034.png 作为背景
// ✅ 2026-01-28 [虚拟键盘支持]: 添加触摸屏和键盘导航支持（可编辑时）
// 与 CustomSpinBox 保持一致的样式
ComboBox {
    id: root

    // ✅ 2026-01-28 [虚拟键盘支持]: 键盘管理器属性
    property var keyboardManager: null

    // ========== 默认样式 ==========
    // ✅ 高度与 CustomSpinBox 一致（60px）
    implicitHeight: 60

    // ✅ 2026-01-28 [键盘导航]: 启用焦点和键盘导航
    focus: true
    activeFocusOnTab: true

    // ========== 背景：使用 034.png 图片 ==========
    background: Rectangle {
        color: "transparent"  // 透明，显示图片

        // 背景图片 034.png
        Image {
            anchors.fill: parent
            source: "images/034.png"
            fillMode: Image.Stretch  // 拉伸填充
            z: -1  // 放在最底层
        }

        // 焦点边框（可选，增强视觉效果）
        // ✅ 2026-01-28 [焦点指示]: 焦点时显示蓝色边框，更明显
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.activeFocus ? "#2196F3" : "transparent"
            border.width: root.activeFocus ? 3 : 0  // 加粗边框
            radius: 4
        }
    }

    // ========== 文本显示区域 ==========
    contentItem: Text {
        text: root.displayText
        // ✅ 字体大小与 CustomSpinBox 一致（21px）
        font.pixelSize: 21
        color: "#E0E0E0"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        leftPadding: 15
        rightPadding: root.indicator.width + 15
        elide: Text.ElideRight

        // ✅ 2026-01-28 [触摸屏支持]: 点击文本区域时弹出键盘（仅可编辑时）
        MouseArea {
            anchors.fill: parent
            enabled: root.editable && root.enabled
            onClicked: {
                root.forceActiveFocus()
                if (keyboardManager) {
                    keyboardManager.openKeyboardForField(root, true)  // true = 触摸模式
                }
            }
            // 允许默认的下拉行为
            onPressed: {
                if (!root.editable) {
                    mouse.accepted = false
                }
            }
        }
    }

    // ========== 下拉箭头指示器 ==========
    indicator: Rectangle {
        x: root.width - width - 2
        y: (root.height - height) / 2
        width: 24
        height: 24
        color: root.pressed ? "#2196F3" : (root.hovered ? "#1E88E5" : "#1a1f2e")
        border.color: "#3d4556"
        border.width: 1
        radius: 2

        Text {
            text: "▼"
            font.pixelSize: 10
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    // ========== 下拉列表弹出框 ==========
    popup: Popup {
        y: root.height
        width: root.width
        implicitHeight: contentItem.implicitHeight
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: "#2d3548"
            border.color: "#3d4556"
            border.width: 1
            radius: 2
        }
    }

    // ========== 下拉列表项样式 ==========
    delegate: ItemDelegate {
        width: root.width
        height: 40

        contentItem: Text {
            text: modelData
            font.pixelSize: 18
            color: highlighted ? "#FFFFFF" : "#E0E0E0"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 15
        }

        background: Rectangle {
            color: highlighted ? "#2196F3" : (hovered ? "#3d4556" : "transparent")
        }

        highlighted: root.highlightedIndex === index
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.24]: 键盘导航修复（最终方案 v4）
    // 问题：Phase 7.22 导致死循环（onCurrentIndexChanged 修改 currentIndex 又触发 onCurrentIndexChanged）
    // 解决方案：添加 isRestoring 标志防止递归

    property int savedIndex: currentIndex  // 保存上一次有效的索引
    property bool isUserAction: false  // 标记是否是用户主动操作（回车键）
    property bool isRestoring: false  // 标记是否正在恢复索引（防止递归）

    // 监听 currentIndex 变化
    onCurrentIndexChanged: {
        if (isRestoring) {
            // 正在恢复索引，不要再次触发
            return
        }

        if (!isUserAction && root.activeFocus) {
            // 如果不是用户主动操作（回车键），且有焦点，说明是键盘导航引起的
            // 立即恢复原值
            console.log("⚠️ [CustomComboBox] 检测到键盘导航修改索引:", currentIndex, "→ 恢复为:", savedIndex)
            isRestoring = true  // 设置恢复标志
            root.currentIndex = savedIndex
            isRestoring = false  // 重置恢复标志
        } else {
            // 用户主动操作，更新保存的索引
            savedIndex = currentIndex
        }
    }

    // ✅ 2026-01-28 [虚拟键盘集成]: 自动注册到键盘管理器（仅可编辑时）
    Component.onCompleted: {
        if (keyboardManager && root.editable) {
            keyboardManager.registerInputField(root)
            console.log("✅ [CustomComboBox] 已注册到键盘管理器:", root.objectName || "unnamed")
        }
        // 初始化保存的索引
        savedIndex = currentIndex
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.15]: 回车键循环切换参数值
    // 用户反馈：直接按回车键切换参数，不需要下拉列表
    // 参考：开关量输入页面的行为
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.16]: 使用 Qt 6 推荐的函数语法
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.22]: 设置 isUserAction 标志
    Keys.onReturnPressed: function(event) {
        console.log("🔍 [CustomComboBox] 回车键按下 - editable:", root.editable, "enabled:", root.enabled)
        if (root.editable) {
            // 可编辑：打开虚拟键盘
            if (keyboardManager && root.enabled) {
                keyboardManager.openKeyboardForField(root, false)
                event.accepted = true
            }
        } else {
            // 不可编辑：循环切换参数值（0 → 1 → 2 → ... → count-1 → 0）
            if (root.enabled && root.count > 0) {
                isUserAction = true  // 标记为用户主动操作
                root.currentIndex = (root.currentIndex + 1) % root.count
                console.log("✅ [CustomComboBox] 回车键切换参数:", root.currentIndex, "/", root.count)
                isUserAction = false  // 重置标志
                event.accepted = true
            }
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.27]: 添加方向键处理，让事件传播到父组件
    // 问题：ComboBox 拦截了方向键，但是我们恢复了索引，导致事件被消耗但焦点没有移动
    // 解决方案：显式设置 event.accepted = false，让事件传播到父组件处理导航
    Keys.onUpPressed: function(event) {
        console.log("🔍 [CustomComboBox] 上键按下 - activeFocus:", root.activeFocus, "currentIndex:", root.currentIndex)
        event.accepted = false  // 不处理，让父组件处理导航
        console.log("✅ [CustomComboBox] 上键事件传播到父组件")
    }

    Keys.onDownPressed: function(event) {
        console.log("🔍 [CustomComboBox] 下键按下 - activeFocus:", root.activeFocus, "currentIndex:", root.currentIndex)
        event.accepted = false  // 不处理，让父组件处理导航
        console.log("✅ [CustomComboBox] 下键事件传播到父组件")
    }

    Keys.onLeftPressed: function(event) {
        console.log("🔍 [CustomComboBox] 左键按下 - activeFocus:", root.activeFocus, "currentIndex:", root.currentIndex)
        event.accepted = false  // 不处理，让父组件处理导航
        console.log("✅ [CustomComboBox] 左键事件传播到父组件")
    }

    Keys.onRightPressed: function(event) {
        console.log("🔍 [CustomComboBox] 右键按下 - activeFocus:", root.activeFocus, "currentIndex:", root.currentIndex)
        event.accepted = false  // 不处理，让父组件处理导航
        console.log("✅ [CustomComboBox] 右键事件传播到父组件")
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.15]: Space 键与回车键相同行为
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.16]: 使用 Qt 6 推荐的函数语法
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.22]: 设置 isUserAction 标志
    Keys.onSpacePressed: function(event) {
        if (root.editable) {
            // 可编辑：打开虚拟键盘
            if (keyboardManager && root.enabled) {
                keyboardManager.openKeyboardForField(root, false)
                event.accepted = true
            }
        } else {
            // 不可编辑：循环切换参数值
            if (root.enabled && root.count > 0) {
                isUserAction = true  // 标记为用户主动操作
                root.currentIndex = (root.currentIndex + 1) % root.count
                console.log("✅ [CustomComboBox] Space键切换参数:", root.currentIndex, "/", root.count)
                isUserAction = false  // 重置标志
                event.accepted = true
            }
        }
    }
}
