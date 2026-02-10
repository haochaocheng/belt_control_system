import QtQuick 2.15

// ✅ 2026-02-10 [Phase 7.45.11]: 角落装饰元素组件
// 科技感的角落装饰线条
Item {
    id: root

    property string corner: "topLeft"  // topLeft, topRight, bottomLeft, bottomRight
    property int lineLength: 20
    property int lineWidth: 2
    property color lineColor: "#00d4ff"
    property real opacity: 0.6

    width: lineLength
    height: lineLength

    // 水平线
    Rectangle {
        width: root.lineLength
        height: root.lineWidth
        color: root.lineColor
        opacity: root.opacity

        anchors {
            left: root.corner === "topLeft" || root.corner === "bottomLeft" ? parent.left : undefined
            right: root.corner === "topRight" || root.corner === "bottomRight" ? parent.right : undefined
            top: root.corner === "topLeft" || root.corner === "topRight" ? parent.top : undefined
            bottom: root.corner === "bottomLeft" || root.corner === "bottomRight" ? parent.bottom : undefined
        }

        // 闪烁动画
        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { from: root.opacity; to: root.opacity * 0.3; duration: 1500 }
            NumberAnimation { from: root.opacity * 0.3; to: root.opacity; duration: 1500 }
        }
    }

    // 垂直线
    Rectangle {
        width: root.lineWidth
        height: root.lineLength
        color: root.lineColor
        opacity: root.opacity

        anchors {
            left: root.corner === "topLeft" || root.corner === "bottomLeft" ? parent.left : undefined
            right: root.corner === "topRight" || root.corner === "bottomRight" ? parent.right : undefined
            top: root.corner === "topLeft" || root.corner === "topRight" ? parent.top : undefined
            bottom: root.corner === "bottomLeft" || root.corner === "bottomRight" ? parent.bottom : undefined
        }

        // 闪烁动画（稍微延迟）
        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            PauseAnimation { duration: 200 }
            NumberAnimation { from: root.opacity; to: root.opacity * 0.3; duration: 1500 }
            NumberAnimation { from: root.opacity * 0.3; to: root.opacity; duration: 1500 }
        }
    }

    // 角落小点
    Rectangle {
        width: 4
        height: 4
        radius: 2
        color: root.lineColor
        opacity: root.opacity

        anchors {
            left: root.corner === "topLeft" || root.corner === "bottomLeft" ? parent.left : undefined
            right: root.corner === "topRight" || root.corner === "bottomRight" ? parent.right : undefined
            top: root.corner === "topLeft" || root.corner === "topRight" ? parent.top : undefined
            bottom: root.corner === "bottomLeft" || root.corner === "bottomRight" ? parent.bottom : undefined
        }

        // 脉冲动画
        SequentialAnimation on scale {
            running: true
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.5; duration: 800 }
            NumberAnimation { from: 1.5; to: 1.0; duration: 800 }
        }
    }
}
