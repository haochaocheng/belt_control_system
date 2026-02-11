import QtQuick 6.5
import QtQuick.Controls 6.5

// Image-based Input Field Component
// 2026-02-11: 使用 input1.png 和 input2.png 作为背景的输入框组件
Item {
    id: root

    // 可配置属性
    property string text: ""
    property bool useSecondaryImage: false  // false: input1.png, true: input2.png
    property alias horizontalAlignment: textLabel.horizontalAlignment
    property alias font: textLabel.font
    property alias color: textLabel.color

    implicitWidth: 80
    implicitHeight: 28

    // 背景图片
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: root.useSecondaryImage ? "../../images/input2.png" : "../../images/input1.png"
        fillMode: Image.Stretch
    }

    // 文本显示
    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 14
        font.bold: true
        color: "white"
    }
}
