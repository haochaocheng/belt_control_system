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
