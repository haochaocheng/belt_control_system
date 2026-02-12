import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-02-10 [Phase 7.45.10]: 增强版皮带连接关系数字孪生图
// 添加更多科技感元素：网格背景、更粗连接线、详细信息、导航控制器、扫描线动画
Rectangle {
    id: root

    color: "transparent"

    // ========== 网格背景（科技感）==========
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.15

        onPaint: {
            // ✅ 2026-02-11 [Phase 7.45.26]: 检查Canvas尺寸，避免"Painter not active"警告
            if (width <= 0 || height <= 0) return

            var ctx = getContext("2d")
            if (!ctx) return  // ✅ 确保context有效

            ctx.clearRect(0, 0, width, height)

            ctx.strokeStyle = "#00d4ff"
            ctx.lineWidth = 0.5

            // 绘制垂直网格线
            for (var x = 0; x < width; x += 50) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }

            // 绘制水平网格线
            for (var y = 0; y < height; y += 50) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }

    // ========== 扫描线动画（科技感）==========
    Rectangle {
        id: scanLine
        width: parent.width
        height: 2
        y: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: "#00d4ff" }
            GradientStop { position: 1.0; color: "transparent" }
        }

        opacity: 0.6

        SequentialAnimation on y {
            running: true
            loops: Animation.Infinite
            NumberAnimation {
                from: 0
                to: root.height
                duration: 3000
            }
            PauseAnimation { duration: 1000 }
        }
    }

    // ========== 皮带连接关系数据 ==========
    property var beltPositions: [
        { id: 1, x: 100,  y: 450, name: "1号皮带", speed: 1.2, current: 45, temp: 35, status: "运行中" },
        { id: 2, x: 250,  y: 400, name: "2号皮带", speed: 1.3, current: 48, temp: 36, status: "运行中" },
        { id: 3, x: 400,  y: 350, name: "3号皮带", speed: 1.1, current: 42, temp: 34, status: "运行中" },
        { id: 4, x: 550,  y: 300, name: "4号皮带", speed: 0.0, current: 0,  temp: 28, status: "停止" },
        { id: 5, x: 700,  y: 250, name: "5号皮带", speed: 0.0, current: 0,  temp: 27, status: "停止" },
        { id: 6, x: 850,  y: 200, name: "6号皮带", speed: 0.0, current: 0,  temp: 26, status: "离线" },
        { id: 7, x: 1000, y: 150, name: "7号皮带", speed: 0.0, current: 0,  temp: 25, status: "离线" },
        { id: 8, x: 1150, y: 100, name: "8号皮带", speed: 0.0, current: 0,  temp: 24, status: "离线" }
    ]

    // ========== 更粗的渐变连接线 ==========
    Canvas {
        id: connectionCanvas
        anchors.fill: parent

        onPaint: {
            // ✅ 2026-02-11 [Phase 7.45.26]: 检查Canvas尺寸，避免"Painter not active"警告
            if (width <= 0 || height <= 0) return

            var ctx = getContext("2d")
            if (!ctx) return  // ✅ 确保context有效

            ctx.clearRect(0, 0, width, height)

            // 绘制连接线
            for (var i = 0; i < beltPositions.length - 1; i++) {
                var from = beltPositions[i]
                var to = beltPositions[i + 1]

                // 更粗的渐变连接线
                var gradient = ctx.createLinearGradient(from.x + 80, from.y + 20, to.x, to.y + 20)

                // 根据设备状态设置颜色
                if (from.status === "运行中" && to.status === "运行中") {
                    gradient.addColorStop(0, "#00ff00")
                    gradient.addColorStop(1, "#00d4ff")
                } else if (from.status === "运行中") {
                    gradient.addColorStop(0, "#00ff00")
                    gradient.addColorStop(1, "#5a6f8f")
                } else {
                    gradient.addColorStop(0, "#5a6f8f")
                    gradient.addColorStop(1, "#2a3f5f")
                }

                ctx.strokeStyle = gradient
                ctx.lineWidth = 6  // 更粗的线条
                ctx.beginPath()
                ctx.moveTo(from.x + 80, from.y + 20)
                ctx.lineTo(to.x, to.y + 20)
                ctx.stroke()

                // 绘制箭头
                if (from.status === "运行中") {
                    drawArrow(ctx, from.x + 80, from.y + 20, to.x, to.y + 20, "#00d4ff")
                }
            }
        }

        function drawArrow(ctx, fromX, fromY, toX, toY, color) {
            var headlen = 15
            var angle = Math.atan2(toY - fromY, toX - fromX)

            ctx.fillStyle = color
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

    // ========== 物料流动动画（更多光点）==========
    Repeater {
        model: beltPositions.length - 1

        // ✅ 2026-02-11 [Phase 7.45.25]: 使用Item包装，保存外层index
        Item {
            property int segmentIndex: index  // 保存外层Repeater的index

            Repeater {
                model: 3  // 每段皮带3个光点

                Rectangle {
                    id: materialDot
                    width: 10
                    height: 10
                    radius: 5
                    color: "#00ff00"

                    property real progress: 0
                    property var fromPos: beltPositions[parent.segmentIndex]  // ✅ 2026-02-11 [Phase 7.45.25]: 使用外层index
                    property var toPos: beltPositions[parent.segmentIndex + 1]  // ✅ 2026-02-11 [Phase 7.45.25]: 使用外层index

                visible: fromPos.status === "运行中"

                x: fromPos.x + 80 + (toPos.x - fromPos.x - 80) * progress
                y: fromPos.y + 20 + (toPos.y - fromPos.y) * progress

                // 发光效果（双层）
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 10
                    height: parent.height + 10
                    radius: (parent.width + 10) / 2
                    color: "transparent"
                    border.width: 2
                    border.color: "#00ff00"
                    opacity: 0.5
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 20
                    height: parent.height + 20
                    radius: (parent.width + 20) / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#00ff00"
                    opacity: 0.3
                }

                // 流动动画（错开启动时间）
                SequentialAnimation on progress {
                    running: fromPos.status === "运行中"
                    loops: Animation.Infinite

                    PauseAnimation { duration: parent.index * 200 + index * 600 }
                    NumberAnimation {
                        from: 0
                        to: 1
                        duration: 2000
                    }
                    PauseAnimation { duration: 500 }
                }
            }
        }  // ✅ 2026-02-11 [Phase 7.45.25]: 内层Repeater结束
        }  // ✅ 2026-02-11 [Phase 7.45.25]: Item包装结束
    }

    // ========== 皮带设备节点（显示详细信息）==========
    Repeater {
        model: beltPositions

        Rectangle {
            id: beltNode
            x: modelData.x
            y: modelData.y
            width: 80
            height: 60
            radius: 5

            property bool isOnline: modelData.status !== "离线"
            property bool isRunning: modelData.status === "运行中"
            property bool isLocal: modelData.id === 1

            // 渐变背景
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: isLocal ? "#1a3f1e" : (isRunning ? "#1a2f3e" : "#1a1f2e")
                }
                GradientStop {
                    position: 1.0
                    color: isLocal ? "#0a2f0e" : (isRunning ? "#0a1f2e" : "#0a0f1e")
                }
            }

            border.width: isLocal ? 3 : 2
            border.color: isLocal ? "#00ff00" : (isRunning ? "#00d4ff" : "#5a6f8f")

            // 外层发光
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                border.width: 1
                border.color: parent.border.color
                radius: parent.radius + 2
                opacity: 0.4
                visible: isOnline
            }

            // 内层光晕
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.width: 1
                border.color: parent.border.color
                radius: parent.radius - 1
                opacity: 0.6
                visible: isOnline
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                // 设备名称
                Text {
                    text: modelData.name
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "Microsoft YaHei"
                    color: beltNode.isLocal ? "#00ff00" : (beltNode.isRunning ? "#00d4ff" : "#5a6f8f")
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 状态
                Text {
                    text: modelData.status
                    font.pixelSize: 9
                    font.family: "Microsoft YaHei"
                    color: beltNode.isRunning ? "#2ECC71" : (beltNode.isOnline ? "#F39C12" : "#E74C3C")
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 速度（运行中才显示）
                Text {
                    text: beltNode.isRunning ? (modelData.speed.toFixed(1) + " m/s") : "--"
                    font.pixelSize: 8
                    font.family: "Consolas"
                    color: "#00d4ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: beltNode.isOnline
                }
            }

            // 状态指示灯（右上角）
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 3
                width: 8
                height: 8
                radius: 4
                color: beltNode.isRunning ? "#00ff00" : (beltNode.isOnline ? "#F39C12" : "#E74C3C")

                SequentialAnimation on opacity {
                    running: beltNode.isOnline
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                }

                // 光晕效果
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: parent.height + 6
                    radius: (parent.width + 6) / 2
                    color: "transparent"
                    border.width: 1
                    border.color: parent.color
                    opacity: 0.5
                }
            }

            // 鼠标交互
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: {
                    parent.scale = 1.1
                    detailPopup.visible = true
                }

                onExited: {
                    parent.scale = 1.0
                    detailPopup.visible = false
                }

                onClicked: {
                    console.log("🖱️ [BeltConnectionDiagram] 点击设备:", modelData.name)
                }
            }

            Behavior on scale {
                NumberAnimation { duration: 150 }
            }

            // 详细信息弹窗（悬停时显示）
            Rectangle {
                id: detailPopup
                visible: false
                x: parent.width + 10
                y: -20
                width: 120
                height: 80
                radius: 5
                color: "#0a1f2e"
                border.width: 2
                border.color: "#00d4ff"
                opacity: 0.95
                z: 100

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: modelData.name
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#00d4ff"
                        opacity: 0.3
                    }

                    Text {
                        text: "速度: " + (beltNode.isRunning ? (modelData.speed.toFixed(1) + " m/s") : "0.0 m/s")
                        font.pixelSize: 8
                        font.family: "Consolas"
                        color: "#00d4ff"
                    }

                    Text {
                        text: "电流: " + modelData.current + " A"
                        font.pixelSize: 8
                        font.family: "Consolas"
                        color: "#F39C12"
                    }

                    Text {
                        text: "温度: " + modelData.temp + " °C"
                        font.pixelSize: 8
                        font.family: "Consolas"
                        color: "#2ECC71"
                    }

                    Text {
                        text: "状态: " + modelData.status
                        font.pixelSize: 8
                        font.family: "Microsoft YaHei"
                        color: beltNode.isRunning ? "#2ECC71" : "#E74C3C"
                    }
                }
            }
        }
    }

    // ========== 辅助设备 ==========
    // 转载机（连接在1号皮带前）
    Rectangle {
        x: 50
        y: 500
        width: 60
        height: 60
        radius: 30
        color: "#1a2f3e"
        border.width: 2
        border.color: "#00d4ff"

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a2f3e" }
            GradientStop { position: 1.0; color: "#0a1f2e" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: "转载机"
                font.pixelSize: 10
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "运行中"
                font.pixelSize: 8
                font.family: "Microsoft YaHei"
                color: "#2ECC71"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 连接线到1号皮带
        Canvas {
            anchors.fill: parent
            onPaint: {
                // ✅ 2026-02-11 [Phase 7.45.26]: 检查Canvas尺寸
                if (width <= 0 || height <= 0) return
                var ctx = getContext("2d")
                if (!ctx) return

                ctx.strokeStyle = "#00d4ff"
                ctx.lineWidth = 4
                ctx.beginPath()
                ctx.moveTo(30, 0)
                ctx.lineTo(50, -30)
                ctx.stroke()
            }
        }
    }

    // 破碎机（连接在8号皮带后）
    Rectangle {
        x: 1250
        y: 100
        width: 60
        height: 60
        radius: 30
        color: "#1a2f3e"
        border.width: 2
        border.color: "#5a6f8f"

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a2f3e" }
            GradientStop { position: 1.0; color: "#0a1f2e" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: "破碎机"
                font.pixelSize: 10
                font.family: "Microsoft YaHei"
                color: "#5a6f8f"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "停止"
                font.pixelSize: 8
                font.family: "Microsoft YaHei"
                color: "#E74C3C"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 连接线从8号皮带
        Canvas {
            anchors.fill: parent
            onPaint: {
                // ✅ 2026-02-11 [Phase 7.45.26]: 检查Canvas尺寸
                if (width <= 0 || height <= 0) return
                var ctx = getContext("2d")
                if (!ctx) return

                ctx.strokeStyle = "#5a6f8f"
                ctx.lineWidth = 4
                ctx.beginPath()
                ctx.moveTo(0, 30)
                ctx.lineTo(-40, 20)
                ctx.stroke()
            }
        }
    }

    // ========== 圆形导航控制器（右上角）==========
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 80
        height: 80
        radius: 40
        color: "#0a1f2e"
        border.width: 2
        border.color: "#00d4ff"
        opacity: 0.9

        // 外层光晕
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 10
            radius: (parent.width + 10) / 2
            color: "transparent"
            border.width: 1
            border.color: "#00d4ff"
            opacity: 0.5
        }

        Column {
            anchors.centerIn: parent
            spacing: 5

            // 上箭头
            Text {
                text: "▲"
                font.pixelSize: 12
                color: "#00d4ff"
                anchors.horizontalCenter: parent.horizontalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("🔼 向上导航")
                }
            }

            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                // 左箭头
                Text {
                    text: "◀"
                    font.pixelSize: 12
                    color: "#00d4ff"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: console.log("◀ 向左导航")
                    }
                }

                // 中心点
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#00d4ff"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: console.log("⊙ 重置视图")
                    }
                }

                // 右箭头
                Text {
                    text: "▶"
                    font.pixelSize: 12
                    color: "#00d4ff"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: console.log("▶ 向右导航")
                    }
                }
            }

            // 下箭头
            Text {
                text: "▼"
                font.pixelSize: 12
                color: "#00d4ff"
                anchors.horizontalCenter: parent.horizontalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("🔽 向下导航")
                }
            }
        }
    }

    // ========== 左下角圆形控制器 ==========
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 20
        width: 60
        height: 60
        radius: 30
        color: "#0a1f2e"
        border.width: 2
        border.color: "#00d4ff"
        opacity: 0.9

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: "+"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                anchors.horizontalCenter: parent.horizontalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("🔍 放大")
                }
            }

            Rectangle {
                width: 30
                height: 1
                color: "#00d4ff"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "-"
                font.pixelSize: 16
                font.bold: true
                color: "#00d4ff"
                anchors.horizontalCenter: parent.horizontalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("🔍 缩小")
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("✅ [BeltConnectionDiagram] 增强版皮带连接关系图已加载")
    }
}
