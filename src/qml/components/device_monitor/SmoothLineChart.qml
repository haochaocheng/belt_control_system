import QtQuick 2.15

// ✅ 2026-02-10 [Phase 7.45.14]: 平滑折线图组件
// 基于 Canvas 绘制，支持平滑曲线、渐变填充、动画效果
Item {
    id: root

    // 数据属性
    property var dataPoints: []  // 数据点数组
    property real minValue: 0    // 最小值
    property real maxValue: 100  // 最大值

    // 样式属性
    property color lineColor: Theme.accent
    property color fillColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
    property int lineWidth: 2
    property bool showFill: true
    property bool showPoints: false
    property bool showGrid: true
    property int gridLines: 5

    // 动画属性
    property real animationProgress: 1.0
    property bool animateOnDataChange: true

    width: 400
    height: 200

    // 背景网格
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: root.showGrid

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            if (!root.showGrid) return

            ctx.strokeStyle = Theme.borderSecondary
            ctx.lineWidth = 1
            ctx.globalAlpha = 0.3

            // 绘制水平网格线
            for (var i = 0; i <= root.gridLines; i++) {
                var y = (height / root.gridLines) * i
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }

            // 绘制垂直网格线
            var verticalLines = Math.min(root.dataPoints.length - 1, 10)
            for (var j = 0; j <= verticalLines; j++) {
                var x = (width / verticalLines) * j
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
        }
    }

    // 主图表 Canvas
    Canvas {
        id: chartCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            if (root.dataPoints.length < 2) return

            var points = root.dataPoints
            var range = root.maxValue - root.minValue
            if (range === 0) range = 1

            // 计算点的坐标
            var coords = []
            for (var i = 0; i < points.length; i++) {
                var x = (width / (points.length - 1)) * i
                var normalizedValue = (points[i] - root.minValue) / range
                var y = height - (normalizedValue * height)
                coords.push({x: x, y: y})
            }

            // 应用动画进度
            var visiblePoints = Math.ceil(coords.length * root.animationProgress)
            if (visiblePoints < 2) visiblePoints = 2

            // 绘制填充区域
            if (root.showFill) {
                ctx.fillStyle = root.fillColor
                ctx.beginPath()
                ctx.moveTo(coords[0].x, height)
                ctx.lineTo(coords[0].x, coords[0].y)

                // 使用二次贝塞尔曲线绘制平滑曲线
                for (var j = 0; j < visiblePoints - 1; j++) {
                    var current = coords[j]
                    var next = coords[j + 1]
                    var cpX = (current.x + next.x) / 2
                    var cpY = (current.y + next.y) / 2
                    ctx.quadraticCurveTo(current.x, current.y, cpX, cpY)
                }

                // 最后一个点
                var lastPoint = coords[visiblePoints - 1]
                ctx.lineTo(lastPoint.x, lastPoint.y)
                ctx.lineTo(lastPoint.x, height)
                ctx.closePath()
                ctx.fill()
            }

            // 绘制线条
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = root.lineWidth
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.beginPath()
            ctx.moveTo(coords[0].x, coords[0].y)

            // 使用二次贝塞尔曲线绘制平滑曲线
            for (var k = 0; k < visiblePoints - 1; k++) {
                var curr = coords[k]
                var nxt = coords[k + 1]
                var controlX = (curr.x + nxt.x) / 2
                var controlY = (curr.y + nxt.y) / 2
                ctx.quadraticCurveTo(curr.x, curr.y, controlX, controlY)
            }

            // 最后一个点
            var last = coords[visiblePoints - 1]
            ctx.lineTo(last.x, last.y)
            ctx.stroke()

            // 绘制数据点
            if (root.showPoints) {
                ctx.fillStyle = root.lineColor
                for (var m = 0; m < visiblePoints; m++) {
                    var point = coords[m]
                    ctx.beginPath()
                    ctx.arc(point.x, point.y, 3, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    // 数据变化时的动画
    Behavior on animationProgress {
        enabled: root.animateOnDataChange
        NumberAnimation {
            duration: Theme.animationDuration * 2
            easing.type: Theme.animationEasing
        }
    }

    // 数据变化时重绘
    onDataPointsChanged: {
        if (animateOnDataChange) {
            animationProgress = 0
            animationProgress = 1.0
        } else {
            chartCanvas.requestPaint()
            gridCanvas.requestPaint()
        }
    }

    onShowGridChanged: {
        gridCanvas.requestPaint()
    }

    onLineColorChanged: {
        chartCanvas.requestPaint()
    }

    onFillColorChanged: {
        chartCanvas.requestPaint()
    }

    onAnimationProgressChanged: {
        chartCanvas.requestPaint()
    }

    Component.onCompleted: {
        chartCanvas.requestPaint()
        gridCanvas.requestPaint()
    }
}
