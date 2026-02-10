import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-02-10 [Phase 7.45.9]: 皮带连接关系数字孪生图
// 显示8条皮带的连接关系和物料流动动画
Rectangle {
    id: root

    color: "transparent"

    // ========== 皮带连接关系数据 ==========
    // 8条皮带的连接关系：1→2→3→4→5→6→7→8
    property var beltPositions: [
        { id: 1, x: 50,  y: 400, name: "1号皮带", angle: 0 },
        { id: 2, x: 200, y: 350, name: "2号皮带", angle: -15 },
        { id: 3, x: 350, y: 300, name: "3号皮带", angle: -10 },
        { id: 4, x: 500, y: 250, name: "4号皮带", angle: -5 },
        { id: 5, x: 650, y: 200, name: "5号皮带", angle: 0 },
        { id: 6, x: 800, y: 150, name: "6号皮带", angle: 5 },
        { id: 7, x: 950, y: 100, name: "7号皮带", angle: 10 },
        { id: 8, x: 1100, y: 50, name: "8号皮带", angle: 15 }
    ]

    // ========== 皮带连接线 ==========
    Canvas {
        id: connectionCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // 绘制连接线
            for (var i = 0; i < beltPositions.length - 1; i++) {
                var from = beltPositions[i]
                var to = beltPositions[i + 1]

                // 绘制皮带连接线（渐变效果）
                var gradient = ctx.createLinearGradient(from.x + 60, from.y, to.x, to.y)
                gradient.addColorStop(0, "#00d4ff")
                gradient.addColorStop(1, "#0080ff")

                ctx.strokeStyle = gradient
                ctx.lineWidth = 4
                ctx.beginPath()
                ctx.moveTo(from.x + 60, from.y)
                ctx.lineTo(to.x, to.y)
                ctx.stroke()

                // 绘制箭头
                drawArrow(ctx, from.x + 60, from.y, to.x, to.y)
            }
        }

        function drawArrow(ctx, fromX, fromY, toX, toY) {
            var headlen = 10
            var angle = Math.atan2(toY - fromY, toX - fromX)

            ctx.fillStyle = "#00d4ff"
            ctx.beginPath()
            ctx.moveTo(toX, toY)
            ctx.lineTo(toX - headlen * Math.cos(angle - Math.PI / 6),
                      toY - headlen * Math.sin(angle - Math.PI / 6))
            ctx.lineTo(toX - headlen * Math.cos(angle + Math.PI / 6),
                      toY - headlen * Math.sin(angle + Math.PI / 6))
            ctx.closePath()
            ctx.fill()
        }
    }

    // ========== 物料流动动画 ==========
    Repeater {
        model: beltPositions.length - 1

        Rectangle {
            id: materialDot
            width: 8
            height: 8
            radius: 4
            color: "#00ff00"

            property real progress: 0
            property var fromPos: beltPositions[index]
            property var toPos: beltPositions[index + 1]

            x: fromPos.x + 60 + (toPos.x - fromPos.x - 60) * progress
            y: fromPos.y + (toPos.y - fromPos.y) * progress

            // 发光效果
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                radius: (parent.width + 8) / 2
                color: "transparent"
                border.width: 2
                border.color: "#00ff00"
                opacity: 0.5
            }

            // 流动动画
            SequentialAnimation on progress {
                running: true
                loops: Animation.Infinite

                PauseAnimation { duration: index * 200 }  // 错开启动时间
                NumberAnimation {
                    from: 0
                    to: 1
                    duration: 2000
                }
                PauseAnimation { duration: 500 }
            }
        }
    }

    // ========== 皮带设备节点 ==========
    Repeater {
        model: beltPositions

        Rectangle {
            id: beltNode
            x: modelData.x
            y: modelData.y
            width: 60
            height: 40
            radius: 5

            // 根据设备状态设置颜色
            property bool isOnline: modelData.id <= 3
            property bool isLocal: modelData.id === 1

            gradient: Gradient {
                GradientStop { position: 0.0; color: isLocal ? "#1a3f1e" : "#1a2f3e" }
                GradientStop { position: 1.0; color: isLocal ? "#0a2f0e" : "#0a1f2e" }
            }

            border.width: isLocal ? 3 : 2
            border.color: isLocal ? "#00ff00" : (isOnline ? "#00d4ff" : "#5a6f8f")

            // 外层发光
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                border.width: 1
                border.color: parent.border.color
                radius: parent.radius + 2
                opacity: 0.4
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: modelData.name
                    font.pixelSize: 10
                    font.family: "Microsoft YaHei"
                    color: beltNode.isLocal ? "#00ff00" : "#00d4ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: beltNode.isOnline ? "运行中" : "离线"
                    font.pixelSize: 8
                    font.family: "Microsoft YaHei"
                    color: beltNode.isOnline ? "#2ECC71" : "#E74C3C"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // 状态指示灯
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 3
                width: 6
                height: 6
                radius: 3
                color: beltNode.isOnline ? "#00ff00" : "#E74C3C"

                SequentialAnimation on opacity {
                    running: beltNode.isOnline
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: {
                    parent.scale = 1.1
                }

                onExited: {
                    parent.scale = 1.0
                }

                onClicked: {
                    console.log("🖱️ [BeltConnectionDiagram] 点击设备:", modelData.name)
                }
            }

            Behavior on scale {
                NumberAnimation { duration: 150 }
            }
        }
    }

    // ========== 辅助设备（转载机、破碎机等）==========
    // 转载机（连接在1号皮带前）
    Rectangle {
        x: 50
        y: 500
        width: 50
        height: 50
        radius: 25
        color: "#1a2f3e"
        border.width: 2
        border.color: "#00d4ff"

        Text {
            anchors.centerIn: parent
            text: "转\n载\n机"
            font.pixelSize: 10
            font.family: "Microsoft YaHei"
            color: "#00d4ff"
            horizontalAlignment: Text.AlignHCenter
        }

        // 连接线到1号皮带
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#00d4ff"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(25, 0)
                ctx.lineTo(25, -60)
                ctx.stroke()
            }
        }
    }

    // 破碎机（连接在8号皮带后）
    Rectangle {
        x: 1200
        y: 50
        width: 50
        height: 50
        radius: 25
        color: "#1a2f3e"
        border.width: 2
        border.color: "#00d4ff"

        Text {
            anchors.centerIn: parent
            text: "破\n碎\n机"
            font.pixelSize: 10
            font.family: "Microsoft YaHei"
            color: "#00d4ff"
            horizontalAlignment: Text.AlignHCenter
        }

        // 连接线从8号皮带
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#00d4ff"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(0, 25)
                ctx.lineTo(-40, 25)
                ctx.stroke()
            }
        }
    }

    Component.onCompleted: {
        console.log("✅ [BeltConnectionDiagram] 皮带连接关系图已加载")
    }
}
