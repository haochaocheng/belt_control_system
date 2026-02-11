import QtQuick 6.5
import QtQuick.Controls 6.5

// Large Image-based Input Field Component for Status Display
// 2026-02-11: 使用 infostate.png 作为背景的宽输入框组件
Item {
    id: root

    // 可配置属性
    property string text: ""
    property alias horizontalAlignment: textLabel.horizontalAlignment
    property alias font: textLabel.font
    property alias color: textLabel.color

    implicitWidth: 278
    implicitHeight: 66

    // 背景图片 - infostate.png
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "../../images/infostate.png"
        fillMode: Image.Stretch
    }

    // 文本显示（在图片上方）
    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 16
        font.bold: true
        color: "white"
    }
}
