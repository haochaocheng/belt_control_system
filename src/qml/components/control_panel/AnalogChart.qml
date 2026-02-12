import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Analog Chart - Simple Canvas-based visualization (no Qt Charts dependency)
// Shows speed or other analog values over time
Rectangle {
    id: root
    width: 400
    height: 250
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    property string chartTitle: "速度曲线"
    property string yAxisTitle: "速度 (m/s)"
    property real maxYValue: 5.0
    property int maxDataPoints: 60  // Keep last 60 seconds

    // Data storage
    property var dataPoints: []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        // Title
        Text {
            text: root.chartTitle
            font.pixelSize: 16
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        // Chart area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2c3e50"
            radius: 5
            border.color: "#34495e"
            border.width: 1

            Canvas {
                id: chartCanvas
                anchors.fill: parent
                anchors.margins: 40

                onPaint: {
                    // ✅ 2026-02-12 [Phase 7.45.27]: 检查Canvas尺寸
                    if (width <= 0 || height <= 0) return
                    var ctx = getContext("2d")
                    if (!ctx) return

                    ctx.clearRect(0, 0, width, height)

                    if (root.dataPoints.length < 2) return

                    // Draw grid
                    ctx.strokeStyle = "#34495e"
                    ctx.lineWidth = 1
                    for (var i = 0; i <= 5; i++) {
                        var y = (height / 5) * i
                        ctx.beginPath()
                        ctx.moveTo(0, y)
                        ctx.lineTo(width, y)
                        ctx.stroke()
                    }

                    // Draw data line
                    ctx.strokeStyle = "#00ff88"
                    ctx.lineWidth = 2
                    ctx.beginPath()

                    var pointCount = root.dataPoints.length
                    var xStep = width / (root.maxDataPoints - 1)

                    for (var j = 0; j < pointCount; j++) {
                        var x = j * xStep
                        var value = root.dataPoints[j]
                        var y = height - (value / root.maxYValue) * height

                        if (j === 0) {
                            ctx.moveTo(x, y)
                        } else {
                            ctx.lineTo(x, y)
                        }
                    }

                    ctx.stroke()

                    // Draw points
                    ctx.fillStyle = "#00ff88"
                    for (var k = 0; k < pointCount; k++) {
                        var px = k * xStep
                        var pvalue = root.dataPoints[k]
                        var py = height - (pvalue / root.maxYValue) * height

                        ctx.beginPath()
                        ctx.arc(px, py, 3, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                }
            }

            // Y Axis labels
            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 5
                spacing: (parent.height - 40) / 5

                Repeater {
                    model: 6
                    Text {
                        text: (root.maxYValue * (5 - index) / 5).toFixed(1)
                        font.pixelSize: 10
                        color: "#95a5a6"
                        horizontalAlignment: Text.AlignRight
                        width: 30
                    }
                }
            }

            // Y Axis title
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 5
                text: root.yAxisTitle
                font.pixelSize: 11
                color: "#00d4ff"
                rotation: -90
                transformOrigin: Item.Center
            }

            // X Axis label
            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 5
                text: "时间 (秒)"
                font.pixelSize: 11
                color: "#00d4ff"
            }
        }

        // Current value display
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 10

            Text {
                text: "当前值:"
                font.pixelSize: 12
                color: "#95a5a6"
            }

            Text {
                text: root.dataPoints.length > 0 ?
                      root.dataPoints[root.dataPoints.length - 1].toFixed(2) : "0.00"
                font.pixelSize: 14
                font.bold: true
                color: "#00ff88"
            }

            Item { Layout.fillWidth: true }
        }
    }

    // Update timer - simulate real-time data
    Timer {
        id: updateTimer
        interval: 1000  // Update every second
        running: true
        repeat: true

        onTriggered: {
            addDataPoint(2.5 + Math.random() * 0.5)
        }
    }

    // Public function to add data point
    function addDataPoint(value) {
        var newData = root.dataPoints.slice()
        newData.push(value)

        // Remove old points
        if (newData.length > root.maxDataPoints) {
            newData.shift()
        }

        root.dataPoints = newData
        chartCanvas.requestPaint()
    }

    // Public function to clear chart
    function clearData() {
        root.dataPoints = []
        chartCanvas.requestPaint()
    }

    // Public function to set chart parameters
    function setChartParameters(title, yTitle, maxY) {
        root.chartTitle = title
        root.yAxisTitle = yTitle
        root.maxYValue = maxY
        chartCanvas.requestPaint()
    }
}
