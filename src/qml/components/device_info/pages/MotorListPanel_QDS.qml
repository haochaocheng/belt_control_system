import QtQuick 2.15

// ✅ 2026-01-25 [电机控制-左侧列表] 电机列表面板（QDS简化预览版）
Rectangle {
    id: root
    width: 200
    height: 600
    color: "#252b3d"

    // 标题
    Rectangle {
        id: header
        x: 0
        y: 0
        width: 200
        height: 50
        color: "#1a1f2e"

        Text {
            x: 60
            y: 17
            text: "电机列表"
            font.pixelSize: 16
            color: "#E0E0E0"
        }
    }

    // 1号电机（选中状态）
    Rectangle {
        x: 0
        y: 50
        width: 200
        height: 60
        color: "#1a1f2e"
        border.color: "#2196F3"
        border.width: 2

        Rectangle {
            x: 0
            y: 0
            width: 4
            height: 60
            color: "#2196F3"
        }

        Text {
            x: 20
            y: 15
            text: "1号电机"
            font.pixelSize: 16
            font.bold: true
            color: "#E0E0E0"
        }

        Rectangle {
            x: 20
            y: 38
            width: 8
            height: 8
            radius: 4
            color: "#4CAF50"
        }

        Text {
            x: 35
            y: 33
            text: "运行中"
            font.pixelSize: 12
            color: "#9E9E9E"
        }
    }

    // 2号电机
    Rectangle {
        x: 0
        y: 110
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 15
            text: "2号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }

        Rectangle {
            x: 20
            y: 38
            width: 8
            height: 8
            radius: 4
            color: "#4CAF50"
        }

        Text {
            x: 35
            y: 33
            text: "运行中"
            font.pixelSize: 12
            color: "#9E9E9E"
        }
    }

    // 3号电机
    Rectangle {
        x: 0
        y: 170
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 20
            text: "3号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }
    }

    // 4号电机
    Rectangle {
        x: 0
        y: 230
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 20
            text: "4号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }
    }

    // 5号电机
    Rectangle {
        x: 0
        y: 290
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 20
            text: "5号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }
    }

    // 6号电机
    Rectangle {
        x: 0
        y: 350
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 20
            text: "6号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }
    }

    // 7号电机
    Rectangle {
        x: 0
        y: 410
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 20
            text: "7号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }
    }

    // 8号电机
    Rectangle {
        x: 0
        y: 470
        width: 200
        height: 60
        color: "transparent"
        border.color: "#3d4556"
        border.width: 1

        Text {
            x: 20
            y: 20
            text: "8号电机"
            font.pixelSize: 16
            color: "#9E9E9E"
        }
    }
}
