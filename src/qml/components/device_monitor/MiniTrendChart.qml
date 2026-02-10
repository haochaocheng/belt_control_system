import QtQuick 2.15

// ✅ 2026-02-10 [Phase 7.45.11]: 迷你趋势图组件
// 显示实时数据趋势，带有动画效果
Item {
    id: root

    property var dataPoints: []  // 数据点数组
    property int maxDataPoints: 20
    property real minValue: 0
    property real maxValue: 100
    property color lineColor: "#00d4ff"
    property color fillColor: "#1a2f3e"
    property int lineWidth: 2

    width: 200
    height: 60

    // 背景
    Rectangle {
        anchors.fill: parent
        color: "#0a0f1e"
        border.width: 1
        border.color: "#2a3f5f"
        radius: 3
    }

    // 网格线
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        anchors.margins: 5

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = "#2a3f5f"
            ctx.lineWidth = 0.5

            // 水平网格线（3条）
            for (var i = 0; i < 4; i++) {
                var y = (height / 3) * i
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }

    // 趋势线
    Canvas {
        id: trendCanvas
        anchors.fill: parent
        anchors.margins: 5

        onPaint: {
            if (root.dataPoints.length < 2) return

            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var pointSpacing = width / (root.maxDataPoints - 1)
            var valueRange = root.maxValue - root.minValue

            // 绘制填充区域
            ctx.fillStyle = root.fillColor
            ctx.beginPath()
            ctx.moveTo(0, height)

            for (var i = 0; i < root.dataPoints.length; i++) {
                var x = i * pointSpacing
                var normalizedValue = (root.dataPoints[i] - root.minValue) / valueRange
                var y = height - (normalizedValue * height)

                if (i === 0) {
                    ctx.lineTo(x, y)
                } else {
                    ctx.lineTo(x, y)
                }
            }

            ctx.lineTo((root.dataPoints.length - 1) * pointSpacing, height)
            ctx.closePath()
            ctx.fill()

            // 绘制线条
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = root.lineWidth
            ctx.beginPath()

            for (var j = 0; j < root.dataPoints.length; j++) {
                var x2 = j * pointSpacing
                var normalizedValue2 = (root.dataPoints[j] - root.minValue) / valueRange
                var y2 = height - (normalizedValue2 * height)

                if (j === 0) {
                    ctx.moveTo(x2, y2)
                } else {
                    ctx.lineTo(x2, y2)
                }
            }

            ctx.stroke()

            // 绘制数据点
            ctx.fillStyle = root.lineColor
            for (var k = 0; k < root.dataPoints.length; k++) {
                var x3 = k * pointSpacing
                var normalizedValue3 = (root.dataPoints[k] - root.minValue) / valueRange
                var y3 = height - (normalizedValue3 * height)

                ctx.beginPath()
                ctx.arc(x3, y3, 2, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }

    // 添加数据点
    function addDataPoint(value) {
        var newData = root.dataPoints.slice()
        newData.push(value)

        // 限制数据点数量
        if (newData.length > root.maxDataPoints) {
            newData.shift()
        }

        root.dataPoints = newData
        trendCanvas.requestPaint()
    }

    // 清除数据
    function clearData() {
        root.dataPoints = []
        trendCanvas.requestPaint()
    }

    // 监听数据变化
    onDataPointsChanged: {
        trendCanvas.requestPaint()
    }

    Component.onCompleted: {
        gridCanvas.requestPaint()
    }
}
