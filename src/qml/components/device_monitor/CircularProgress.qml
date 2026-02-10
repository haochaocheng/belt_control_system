import QtQuick 2.15
import QtQuick.Shapes 1.15

// ✅ 2026-02-10 [Phase 7.45.11]: 圆形进度指示器组件
// 显示百分比进度，带有动画效果和渐变色
Item {
    id: root

    property real progress: 0  // 0.0 - 1.0
    property real targetProgress: 0
    property int size: 100
    property int lineWidth: 8
    property color startColor: "#00d4ff"
    property color endColor: "#00ff00"
    property color backgroundColor: "#2a3f5f"
    property string centerText: ""
    property int centerFontSize: 18
    property bool showPercentage: true

    width: size
    height: size

    // 平滑动画
    Behavior on progress {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutCubic
        }
    }

    onTargetProgressChanged: {
        progress = targetProgress
    }

    // 背景圆环
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeWidth: root.lineWidth
            strokeColor: root.backgroundColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.lineWidth) / 2
                radiusY: (root.size - root.lineWidth) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }
    }

    // 进度圆环
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeWidth: root.lineWidth
            strokeColor: root.startColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.lineWidth) / 2
                radiusY: (root.size - root.lineWidth) / 2
                startAngle: -90
                sweepAngle: 360 * root.progress
            }
        }

        // 渐变效果（通过透明度模拟）
        layer.enabled: true
        layer.effect: ShaderEffect {
            property real progress: root.progress
        }
    }

    // 中心文本
    Text {
        anchors.centerIn: parent
        text: root.showPercentage ?
              Math.round(root.progress * 100) + "%" :
              root.centerText
        font.pixelSize: root.centerFontSize
        font.bold: true
        font.family: "Consolas"
        color: root.startColor

        // 进度变化时的脉冲效果
        SequentialAnimation on scale {
            running: Math.abs(root.progress - root.targetProgress) > 0.01
            loops: 1
            NumberAnimation { from: 1.0; to: 1.2; duration: 150 }
            NumberAnimation { from: 1.2; to: 1.0; duration: 150 }
        }
    }

    // 外层光晕效果
    Rectangle {
        anchors.centerIn: parent
        width: root.size + 10
        height: root.size + 10
        radius: (root.size + 10) / 2
        color: "transparent"
        border.width: 2
        border.color: root.startColor
        opacity: 0.3

        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { from: 0.3; to: 0.1; duration: 1500 }
            NumberAnimation { from: 0.1; to: 0.3; duration: 1500 }
        }
    }

    Component.onCompleted: {
        progress = targetProgress
    }
}
