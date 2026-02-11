import QtQuick 6.5
import QtQuick.Controls 6.5

// Image-based Input Field Component
// 2026-02-11: 使用 input1.png 和 input2.png 叠加作为背景的输入框组件
Item {
    id: root

    // 可配置属性
    property string text: ""
    property alias horizontalAlignment: textLabel.horizontalAlignment
    property alias font: textLabel.font
    property alias color: textLabel.color

    implicitWidth: 80
    implicitHeight: 28

    // 底层背景图片 - input1.png
    Image {
        id: backgroundImage1
        anchors.fill: parent
        source: "../../images/input1.png"
        fillMode: Image.Stretch
    }

    // 顶层背景图片 - input2.png（叠加在 input1 上方）
    Image {
        id: backgroundImage2
        anchors.fill: parent
        source: "../../images/input2.png"
        fillMode: Image.Stretch
    }

    // 文本显示（在最上层）
    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 14
        font.bold: true
        color: "white"
    }
}
