import QtQuick 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-02-10 [Phase 7.45.11]: 系统状态徽章组件
// 显示系统状态，带有图标和动画效果
Rectangle {
    id: root

    property string statusText: "正常"
    property string statusIcon: "●"
    property color statusColor: "#2ECC71"
    property color backgroundColor: "#0a1f2e"
    property color borderColor: "#00d4ff"

    width: 120
    height: 40
    color: root.backgroundColor
    border.width: 1
    border.color: root.borderColor
    radius: 5

    // 渐变背景
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(root.backgroundColor, 1.2) }
        GradientStop { position: 1.0; color: root.backgroundColor }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // 状态图标
        Text {
            text: root.statusIcon
            font.pixelSize: 16
            font.bold: true
            color: root.statusColor

            // 闪烁动画
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
            }

            // 光晕效果
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                radius: (parent.width + 8) / 2
                color: "transparent"
                border.width: 2
                border.color: root.statusColor
                opacity: 0.3
            }
        }

        // 状态文本
        Text {
            text: root.statusText
            font.pixelSize: 14
            font.bold: true
            font.family: "Microsoft YaHei"
            color: root.statusColor
            Layout.fillWidth: true
        }
    }

    // 外层发光效果
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        color: "transparent"
        border.width: 1
        border.color: root.borderColor
        radius: root.radius + 2
        opacity: 0.3

        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { from: 0.3; to: 0.1; duration: 1500 }
            NumberAnimation { from: 0.1; to: 0.3; duration: 1500 }
        }
    }

    // 鼠标悬停效果
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            root.scale = 1.05
        }

        onExited: {
            root.scale = 1.0
        }
    }

    Behavior on scale {
        NumberAnimation { duration: 150 }
    }
}
