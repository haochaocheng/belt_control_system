import QtQuick 2.15

// ✅ 2026-02-10 [Phase 7.45.11]: 动态数字计数器组件
// 用于显示动态变化的数字，带有平滑的计数动画
Item {
    id: root

    property real targetValue: 0
    property real currentValue: 0
    property int decimals: 0
    property string suffix: ""
    property string prefix: ""
    property color textColor: "#00d4ff"
    property int fontSize: 24
    property string fontFamily: "Consolas"
    property bool fontBold: true

    width: counterText.width
    height: counterText.height

    // 平滑动画
    Behavior on currentValue {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutCubic
        }
    }

    // 监听目标值变化
    onTargetValueChanged: {
        currentValue = targetValue
    }

    Text {
        id: counterText
        text: root.prefix + currentValue.toFixed(root.decimals) + root.suffix
        font.pixelSize: root.fontSize
        font.bold: root.fontBold
        font.family: root.fontFamily
        color: root.textColor

        // 数字变化时的闪烁效果
        SequentialAnimation on opacity {
            running: Math.abs(currentValue - targetValue) > 0.01
            loops: 1
            NumberAnimation { from: 1.0; to: 0.5; duration: 100 }
            NumberAnimation { from: 0.5; to: 1.0; duration: 100 }
        }
    }

    Component.onCompleted: {
        currentValue = targetValue
    }
}
