import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-27 [FIX 100.300.32]: 自定义输入框组件，使用 034.png 作为背景
// ✅ 2026-01-28 [虚拟键盘支持]: 添加触摸屏和键盘导航支持
// 用于替换设备参数弹窗里所有的 TextField
TextField {
    id: root

    // ========== 公开属性 ==========
    // 继承 TextField 的所有属性，可以直接使用：
    // - text: 文本内容
    // - placeholderText: 占位符文本
    // - enabled: 是否启用
    // - readOnly: 是否只读
    // - validator: 验证器
    // - inputMethodHints: 输入法提示
    // - font: 字体
    // - color: 文字颜色
    // 等等...

    // ✅ 2026-01-28 [虚拟键盘支持]: 键盘管理器属性
    property var keyboardManager: null

    // ========== 默认样式 ==========
    // ✅ 2026-01-27 [FIX 100.300.34]: 高度增加到1.5倍（40px → 60px）
    implicitHeight: 60
    // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
    font.pixelSize: 21
    color: "#E0E0E0"
    selectByMouse: true  // 允许鼠标选择文本
    selectedTextColor: "#FFFFFF"
    selectionColor: "#2196F3"

    // ✅ 2026-01-28 [键盘导航]: 启用焦点和键盘导航
    focus: true
    activeFocusOnTab: true

    // ========== 背景：使用 034.png 图片 ==========
    background: Rectangle {
        color: "transparent"  // 透明，显示图片

        // 背景图片 034.png
        // ✅ 2026-01-28 [FIX 100.300.81]: 修复图片路径，从 "../images/034.png" 改为 "images/034.png"
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

    // ========== 内边距 ==========
    leftPadding: 12
    rightPadding: 12
    topPadding: 8
    bottomPadding: 8

    // ✅ 2026-01-28 [虚拟键盘集成]: 自动注册到键盘管理器
    Component.onCompleted: {
        if (keyboardManager) {
            keyboardManager.registerInputField(root)
            console.log("✅ [CustomTextField] 已注册到键盘管理器:", root.objectName || "unnamed")
        }
    }

    // ✅ 2026-01-28 [触摸屏支持]: 点击时弹出键盘
    MouseArea {
        anchors.fill: parent
        enabled: !root.readOnly && root.enabled
        onClicked: {
            root.forceActiveFocus()
            if (keyboardManager) {
                keyboardManager.openKeyboardForField(root, true)  // true = 触摸模式
            }
        }
        // 允许文本选择
        onPressed: mouse.accepted = false
    }

    // ✅ 2026-01-28 [键盘导航]: Enter/Space 键弹出虚拟键盘
    Keys.onReturnPressed: {
        if (keyboardManager && !root.readOnly && root.enabled) {
            keyboardManager.openKeyboardForField(root, false)  // false = 键盘导航模式
        }
    }

    Keys.onSpacePressed: {
        if (keyboardManager && !root.readOnly && root.enabled) {
            keyboardManager.openKeyboardForField(root, false)  // false = 键盘导航模式
            event.accepted = true  // 阻止空格输入
        }
    }
}
