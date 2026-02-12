import QtQuick
import QtQuick.Effects

// ✅ 2026-01-20 00:20 [FIX 100.253] 工业风格装饰容器
// 用途：为 SIP 设置页面提供统一的工业/科技风格装饰
// 特性：四角装饰、渐变边框、发光效果、纯 QML 实现（无图片依赖）
// 参考：主界面 Input1 的工业风格设计
Item {
    id: root

    // ========== 可配置属性 ==========

    // 背景颜色
    property color containerColor: "#0f3460"

    // 边框颜色（主题色）
    property color borderColor: "#00d4ff"

    // 强调色（装饰元素）
    property color accentColor: "#00ff88"

    // 圆角半径
    property int cornerRadius: 10

    // 边框宽度
    property int borderWidth: 1

    // 装饰元素大小
    property int decorationSize: 30

    // 装饰线条粗细
    property int decorationLineWidth: 2

    // 是否显示四角装饰
    property bool showCornerDecorations: true

    // 是否显示顶部渐变线
    property bool showTopGradient: true

    // 是否显示底部渐变线
    property bool showBottomGradient: false

    // 是否启用发光效果
    property bool glowEnabled: false

    // 发光强度（0.0-1.0）
    property real glowIntensity: 0.3

    // 内容边距
    property int contentMargins: 20

    // 默认子元素容器（方便使用）
    default property alias contentData: contentArea.data

    // ========== 主容器背景 ==========

    Rectangle {
        id: mainBackground
        anchors.fill: parent
        color: root.containerColor
        radius: root.cornerRadius
        border.color: root.borderColor
        border.width: root.borderWidth

        // 发光效果（可选）
        layer.enabled: root.glowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: root.glowEnabled
            shadowColor: root.borderColor
            shadowBlur: 0.8
            shadowOpacity: root.glowIntensity
        }
    }

    // ========== 顶部渐变线 ==========

    Rectangle {
        visible: root.showTopGradient
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: root.decorationSize
            rightMargin: root.decorationSize
            topMargin: root.borderWidth
        }
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: root.accentColor }
            GradientStop { position: 0.5; color: root.borderColor }
            GradientStop { position: 0.8; color: root.accentColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ========== 底部渐变线 ==========

    Rectangle {
        visible: root.showBottomGradient
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.decorationSize
            rightMargin: root.decorationSize
            bottomMargin: root.borderWidth
        }
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.3; color: root.borderColor }
            GradientStop { position: 0.7; color: root.borderColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ========== 四角装饰 ==========

    // 左上角装饰
    Item {
        visible: root.showCornerDecorations
        anchors {
            left: parent.left
            top: parent.top
        }
        width: root.decorationSize
        height: root.decorationSize

        // 横线
        Rectangle {
            x: 0
            y: 0
            width: root.decorationSize
            height: root.decorationLineWidth
            color: root.borderColor
        }

        // 竖线
        Rectangle {
            x: 0
            y: 0
            width: root.decorationLineWidth
            height: root.decorationSize
            color: root.borderColor
        }

        // 小三角形（左上角）
        Canvas {
            x: root.decorationLineWidth + 2
            y: root.decorationLineWidth + 2
            width: 8
            height: 8

            onPaint: {
                // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
                if (width <= 0 || height <= 0) return
                var ctx = getContext("2d")
                if (!ctx) return

                ctx.fillStyle = root.accentColor
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(8, 0)
                ctx.lineTo(0, 8)
                ctx.closePath()
                ctx.fill()
            }

            // ✅ 2026-02-12 [Phase 7.45.27 补充]: 延迟绘制，确保Canvas引擎已初始化
            Component.onCompleted: Qt.callLater(requestPaint)
        }
    }

    // 右上角装饰
    Item {
        visible: root.showCornerDecorations
        anchors {
            right: parent.right
            top: parent.top
        }
        width: root.decorationSize
        height: root.decorationSize

        // 横线
        Rectangle {
            x: 0
            y: 0
            width: root.decorationSize
            height: root.decorationLineWidth
            color: root.borderColor
        }

        // 竖线
        Rectangle {
            x: root.decorationSize - root.decorationLineWidth
            y: 0
            width: root.decorationLineWidth
            height: root.decorationSize
            color: root.borderColor
        }

        // 小三角形（右上角）
        Canvas {
            x: root.decorationSize - 8 - root.decorationLineWidth - 2
            y: root.decorationLineWidth + 2
            width: 8
            height: 8

            onPaint: {
                // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
                if (width <= 0 || height <= 0) return
                var ctx = getContext("2d")
                if (!ctx) return

                ctx.fillStyle = root.accentColor
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(8, 0)
                ctx.lineTo(8, 8)
                ctx.closePath()
                ctx.fill()
            }

            Component.onCompleted: requestPaint()
        }
    }

    // 左下角装饰
    Item {
        visible: root.showCornerDecorations
        anchors {
            left: parent.left
            bottom: parent.bottom
        }
        width: root.decorationSize
        height: root.decorationSize

        // 横线
        Rectangle {
            x: 0
            y: root.decorationSize - root.decorationLineWidth
            width: root.decorationSize
            height: root.decorationLineWidth
            color: root.borderColor
        }

        // 竖线
        Rectangle {
            x: 0
            y: 0
            width: root.decorationLineWidth
            height: root.decorationSize
            color: root.borderColor
        }

        // 小三角形（左下角）
        Canvas {
            x: root.decorationLineWidth + 2
            y: root.decorationSize - 8 - root.decorationLineWidth - 2
            width: 8
            height: 8

            onPaint: {
                // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
                if (width <= 0 || height <= 0) return
                var ctx = getContext("2d")
                if (!ctx) return

                ctx.fillStyle = root.accentColor
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(0, 8)
                ctx.lineTo(8, 8)
                ctx.closePath()
                ctx.fill()
            }

            Component.onCompleted: requestPaint()
        }
    }

    // 右下角装饰
    Item {
        visible: root.showCornerDecorations
        anchors {
            right: parent.right
            bottom: parent.bottom
        }
        width: root.decorationSize
        height: root.decorationSize

        // 横线
        Rectangle {
            x: 0
            y: root.decorationSize - root.decorationLineWidth
            width: root.decorationSize
            height: root.decorationLineWidth
            color: root.borderColor
        }

        // 竖线
        Rectangle {
            x: root.decorationSize - root.decorationLineWidth
            y: 0
            width: root.decorationLineWidth
            height: root.decorationSize
            color: root.borderColor
        }

        // 小三角形（右下角）
        Canvas {
            x: root.decorationSize - 8 - root.decorationLineWidth - 2
            y: root.decorationSize - 8 - root.decorationLineWidth - 2
            width: 8
            height: 8

            onPaint: {
                // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
                if (width <= 0 || height <= 0) return
                var ctx = getContext("2d")
                if (!ctx) return

                ctx.fillStyle = root.accentColor
                ctx.beginPath()
                ctx.moveTo(0, 8)
                ctx.lineTo(8, 0)
                ctx.lineTo(8, 8)
                ctx.closePath()
                ctx.fill()
            }

            Component.onCompleted: requestPaint()
        }
    }

    // ========== 内容区域 ==========

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.margins: root.contentMargins
    }
}
