import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-28 [自定义只读显示框] 使用 034.png 背景的只读文本显示框
// 用于电机控制各个 Tab 页面中的参数显示
Rectangle {
    id: root

    // ========== 公开属性 ==========
    property alias text: displayText.text
    property alias font: displayText.font
    property alias horizontalAlignment: displayText.horizontalAlignment
    property alias verticalAlignment: displayText.verticalAlignment

    // ========== 默认尺寸 ==========
    implicitWidth: 200
    implicitHeight: 60  // 与 CustomTextField/CustomSpinBox 保持一致

    // ========== 透明背景（使用图片）==========
    color: "transparent"

    // ========== 背景：使用 034.png 图片 ==========
    Image {
        anchors.fill: parent
        source: "images/034.png"
        fillMode: Image.Stretch  // 拉伸填充
        z: -1  // 放在最底层
    }

    // ========== 显示文本 ==========
    Text {
        id: displayText
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        font.pixelSize: 21  // 与其他输入组件保持一致
        color: "#E0E0E0"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight  // 文本过长时显示省略号
    }
}
