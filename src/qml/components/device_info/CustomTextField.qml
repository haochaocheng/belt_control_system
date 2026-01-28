import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-27 [FIX 100.300.32]: 自定义输入框组件，使用 034.png 作为背景
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

    // ========== 默认样式 ==========
    // ✅ 2026-01-27 [FIX 100.300.34]: 高度增加到1.5倍（40px → 60px）
    implicitHeight: 60
    // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
    font.pixelSize: 21
    color: "#E0E0E0"
    selectByMouse: true  // 允许鼠标选择文本
    selectedTextColor: "#FFFFFF"
    selectionColor: "#2196F3"

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
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.activeFocus ? "#2196F3" : "transparent"
            border.width: root.activeFocus ? 2 : 0
            radius: 4
        }
    }

    // ========== 内边距 ==========
    leftPadding: 12
    rightPadding: 12
    topPadding: 8
    bottomPadding: 8
}
