import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-27 [FIX 100.300.33]: 自定义 SpinBox 组件，使用 034.png 作为背景
// ✅ 2026-01-28 [虚拟键盘支持]: 添加触摸屏和键盘导航支持
// 用于替换设备参数弹窗里所有的 SpinBox
SpinBox {
    id: root

    // ========== 公开属性 ==========
    // 继承 SpinBox 的所有属性，可以直接使用：
    // - from: 最小值
    // - to: 最大值
    // - value: 当前值
    // - stepSize: 步长
    // - editable: 是否可编辑
    // - validator: 验证器
    // - textFromValue: 值转文本函数
    // - valueFromText: 文本转值函数
    // 等等...

    // ✅ 2026-01-28 [虚拟键盘支持]: 键盘管理器属性
    property var keyboardManager: null

    // ========== 默认样式 ==========
    // ✅ 2026-01-27 [FIX 100.300.34]: 高度增加到1.5倍（40px → 60px）
    implicitHeight: 60
    editable: true  // 默认可编辑

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

    // ========== 文本输入区域 ==========
    contentItem: TextInput {
        id: textInput
        text: root.textFromValue(root.value, root.locale)
        // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
        font.pixelSize: 21
        color: "#E0E0E0"
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !root.editable
        validator: root.validator
        // ✅ 2026-02-02 [FIX 100.300.112.8.25.7.6]: 改为 Qt.ImhDigitsOnly，Qt会自动显示纯数字键盘
        inputMethodHints: Qt.ImhDigitsOnly
        selectByMouse: true  // 允许鼠标选择文本
        selectedTextColor: "#FFFFFF"
        selectionColor: "#2196F3"

        // ✅ 2026-02-02 [FIX 100.300.112.8.25.7.6]: 移除 MouseArea，让 TextInput 直接接收事件
        // MouseArea 会拦截事件，导致 Qt.inputMethod 无法正常工作
    }

    // ========== 上下按钮样式 ==========
    up.indicator: Rectangle {
        x: root.width - width - 2
        y: 2
        width: 24
        height: parent.height / 2 - 2
        color: root.up.pressed ? "#2196F3" : (root.up.hovered ? "#1E88E5" : "#1a1f2e")
        border.color: "#3d4556"
        border.width: 1
        radius: 2

        Text {
            text: "▲"
            font.pixelSize: 10
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    down.indicator: Rectangle {
        x: root.width - width - 2
        y: parent.height / 2
        width: 24
        height: parent.height / 2 - 2
        color: root.down.pressed ? "#2196F3" : (root.down.hovered ? "#1E88E5" : "#1a1f2e")
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

    // ✅ 2026-02-02 [FIX 100.300.112.8.25.7.7]: 添加激活虚拟键盘的函数
    // 键盘导航需要手动调用 Qt.inputMethod.show()
    function activateVirtualKeyboard() {
        textInput.forceActiveFocus()
        Qt.inputMethod.show()  // ✅ 手动显示虚拟键盘（键盘导航必需）
        console.log("✅ [CustomSpinBox] activateVirtualKeyboard() 调用")
        console.log("   - TextInput 获得焦点")
        console.log("   - 手动调用 Qt.inputMethod.show()")
    }

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.11]: 监听虚拟键盘关闭，恢复焦点到父容器
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.11.1]: 修复焦点恢复到GridLayout而不是Tab
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.12]: 添加自动滚动功能，避免虚拟键盘遮挡
    Connections {
        target: Qt.inputMethod

        // 保存原始滚动位置
        property real savedScrollY: 0

        function onVisibleChanged() {
            if (Qt.inputMethod.visible && textInput.activeFocus) {
                // ========== 虚拟键盘显示：自动滚动到输入框 ==========
                console.log("⌨️ [CustomSpinBox] 虚拟键盘显示，自动滚动到输入框")

                // 查找ScrollView
                var scrollView = findScrollView(root.parent)
                if (!scrollView) {
                    return
                }

                console.log("   📊 ScrollView信息:")
                console.log("      - height:", scrollView.height)
                console.log("      - contentHeight:", scrollView.contentHeight)

                // 保存当前滚动位置
                savedScrollY = scrollView.ScrollBar.vertical.position
                console.log("   💾 保存滚动位置:", savedScrollY)

                // 计算输入框在ScrollView内容中的Y坐标（相对于ScrollView的contentItem）
                var inputYInContent = getYInScrollView(root, scrollView)
                console.log("   📍 输入框在ScrollView内容中的Y:", inputYInContent)
                console.log("   📏 输入框高度:", root.height)

                // 计算当前滚动偏移
                var currentScrollY = scrollView.ScrollBar.vertical.position * scrollView.contentHeight
                console.log("   📜 当前滚动偏移:", currentScrollY)

                // 计算输入框在ScrollView可见区域中的Y坐标
                var inputYInViewport = inputYInContent - currentScrollY
                console.log("   👁️  输入框在可见区域中的Y:", inputYInViewport)

                // 计算输入框在屏幕坐标系中的Y坐标
                // 需要加上ScrollView在屏幕中的Y坐标
                var scrollViewScreenY = getScreenY(scrollView)
                var inputScreenY = scrollViewScreenY + inputYInViewport
                var inputScreenBottom = inputScreenY + root.height
                console.log("   🌍 屏幕坐标:")
                console.log("      - ScrollView屏幕Y:", scrollViewScreenY)
                console.log("      - 输入框屏幕Y:", inputScreenY)
                console.log("      - 输入框屏幕底部:", inputScreenBottom)

                // 获取虚拟键盘的实际高度和位置
                // 虚拟键盘在屏幕底部，y = root.height - keyboard.height
                // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.12.3]: 使用实际的虚拟键盘高度
                var screenHeight = scrollView.Window.window ? scrollView.Window.window.height : 1080

                // 尝试获取实际的虚拟键盘高度
                var keyboardHeight = 0
                if (scrollView.Window.window && scrollView.Window.window.virtualKeyboardHeight) {
                    keyboardHeight = scrollView.Window.window.virtualKeyboardHeight
                    console.log("   ⌨️  使用实际虚拟键盘高度:", keyboardHeight)
                } else {
                    // 回退到估算（屏幕高度的40%）
                    keyboardHeight = screenHeight * 0.4
                    console.log("   ⌨️  使用估算虚拟键盘高度:", keyboardHeight, "(40% of", screenHeight, ")")
                }

                var keyboardTop = screenHeight - keyboardHeight
                console.log("   ⌨️  虚拟键盘信息:")
                console.log("      - 屏幕高度:", screenHeight)
                console.log("      - 键盘高度:", keyboardHeight)
                console.log("      - 键盘顶部Y:", keyboardTop)

                // 判断输入框是否被虚拟键盘遮挡
                var gap = 20  // 期望的间距
                var targetBottom = keyboardTop - gap
                console.log("   🎯 目标位置:")
                console.log("      - 目标底部Y（键盘顶部-间距）:", targetBottom)

                if (inputScreenBottom > targetBottom) {
                    // 输入框被遮挡，需要滚动
                    var overlap = inputScreenBottom - targetBottom
                    console.log("   ⚠️  输入框被遮挡，重叠:", overlap, "px")

                    // 计算需要滚动的距离（在ScrollView内容坐标系中）
                    var targetScrollY = currentScrollY + overlap
                    console.log("   📐 滚动计算:")
                    console.log("      - 当前滚动Y:", currentScrollY)
                    console.log("      - 需要额外滚动:", overlap)
                    console.log("      - 目标滚动Y:", targetScrollY)

                    // 限制滚动范围
                    var maxScrollY = Math.max(0, scrollView.contentHeight - scrollView.height)
                    targetScrollY = Math.max(0, Math.min(targetScrollY, maxScrollY))
                    console.log("      - 最大滚动Y:", maxScrollY)
                    console.log("      - 最终滚动Y:", targetScrollY)

                    // 转换为position（0.0-1.0）
                    var targetPosition = targetScrollY / scrollView.contentHeight
                    console.log("   🎚️  目标position:", targetPosition)

                    // 平滑滚动到目标位置
                    scrollView.ScrollBar.vertical.position = targetPosition
                    console.log("   ✅ 滚动完成")
                } else {
                    console.log("   ✅ 输入框未被遮挡，无需滚动")
                }
            } else if (!Qt.inputMethod.visible && textInput.activeFocus) {
                // ========== 虚拟键盘关闭：恢复焦点和滚动位置 ==========
                console.log("⌨️ [CustomSpinBox] 虚拟键盘关闭，恢复焦点和滚动位置")

                // 恢复滚动位置
                var scrollView = findScrollView(root.parent)
                if (scrollView && savedScrollY !== undefined) {
                    console.log("   - 恢复滚动位置:", savedScrollY)
                    scrollView.ScrollBar.vertical.position = savedScrollY
                }

                // 恢复焦点到参数区域（Tab），而不是GridLayout
                // 组件层级：CustomSpinBox → Item → GridLayout → ScrollView → Tab
                // 需要向上找到Tab（通常是4-5层）
                var container = root.parent
                var depth = 0
                while (container && depth < 10) {
                    console.log("   - 层级", depth, ":", container)
                    // 查找包含 focusParamIndex 属性的容器（通常是Tab）
                    if (container.hasOwnProperty("focusParamIndex")) {
                        console.log("   - 找到参数区域容器，恢复焦点")
                        container.forceActiveFocus()
                        return
                    }
                    container = container.parent
                    depth++
                }
                console.log("⚠️ [CustomSpinBox] 未找到参数区域容器，使用默认恢复")
                // 如果没找到，使用默认的parent.parent
                if (root.parent && root.parent.parent) {
                    root.parent.parent.forceActiveFocus()
                }
            }
        }

        // 辅助函数：查找ScrollView
        function findScrollView(item) {
            var current = item
            var depth = 0
            while (current && depth < 10) {
                var typeName = current.toString()
                console.log("   - 检查层级", depth, ":", typeName)

                // 检查是否是ScrollView（通过类型名称）
                if (typeName.indexOf("ScrollView") !== -1) {
                    console.log("   ✅ 找到ScrollView，层级:", depth)
                    return current
                }
                // 或者检查是否是Flickable（ScrollView的内部实现）
                if (typeName.indexOf("Flickable") !== -1 && current.parent && current.parent.toString().indexOf("ScrollView") !== -1) {
                    console.log("   ✅ 找到Flickable（ScrollView内部），层级:", depth, "使用父ScrollView")
                    return current.parent
                }
                current = current.parent
                depth++
            }
            console.log("⚠️ [CustomSpinBox] 未找到ScrollView")
            return null
        }

        // 辅助函数：计算元素在ScrollView中的Y坐标
        function getYInScrollView(item, scrollView) {
            var y = 0
            var current = item
            var depth = 0
            console.log("   - 开始计算Y坐标，从:", item)
            while (current && current !== scrollView && depth < 20) {
                console.log("     层级", depth, "Y:", current.y, "累计:", y, "对象:", current)
                y += current.y
                current = current.parent
                depth++
            }
            console.log("   - Y坐标计算完成，总计:", y)
            return y
        }

        // 辅助函数：计算元素在屏幕坐标系中的Y坐标
        function getScreenY(item) {
            var y = 0
            var current = item
            var depth = 0
            console.log("   - 开始计算屏幕Y坐标，从:", item)
            while (current && depth < 20) {
                console.log("     层级", depth, "Y:", current.y, "累计:", y, "对象:", current)
                y += current.y
                current = current.parent
                depth++
                // 如果到达Window，停止
                if (current && current.toString().indexOf("Window") !== -1) {
                    console.log("     到达Window，停止")
                    break
                }
            }
            console.log("   - 屏幕Y坐标计算完成，总计:", y)
            return y
        }
    }

    // ✅ 2026-01-28 [虚拟键盘集成]: 自动注册到键盘管理器
    Component.onCompleted: {
        if (keyboardManager) {
            keyboardManager.registerInputField(root)
            console.log("✅ [CustomSpinBox] 已注册到键盘管理器:", root.objectName || "unnamed")
        }
    }

    // ✅ 2026-02-02 [FIX 100.300.112.8.25.7.2]: Qt会自动显示虚拟键盘，移除手动调用
    // ❌ 2026-02-02 [移除]: Keys.onReturnPressed 和 Keys.onSpacePressed 不再需要
    // Qt会在TextField获得焦点时自动显示虚拟键盘
}
