import QtQuick 2.15

// ✅ 2026-01-25 [通用装饰组件] 页面装饰边框
// 用途：为所有页面提供统一的装饰效果
Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property string title: "页面标题"
    property color borderColor: "#2196F3"
    property int borderWidth: 2
    property int cornerRadius: 10
    property string backgroundImage: ""  // 背景图片路径

    // ========== 背景装饰 ==========
    // 背景图片
    Image {
        anchors.fill: parent
        source: root.backgroundImage
        fillMode: Image.Stretch
        visible: root.backgroundImage !== ""
        z: -2
    }

    // 渐变背景（如果没有图片）
    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImage === ""
        z: -2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1f2e" }
            GradientStop { position: 1.0; color: "#252b3d" }
        }
    }

    // ========== 边框装饰 ==========
    // 主边框
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth
        radius: root.cornerRadius
        z: -1
    }

    // 左上角装饰
    Rectangle {
        x: 0
        y: 0
        width: 40
        height: 40
        color: "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth
        radius: root.cornerRadius
    }

    // 右上角装饰
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 40
        height: 40
        color: "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth
        radius: root.cornerRadius
    }

    // 左下角装饰
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 40
        height: 40
        color: "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth
        radius: root.cornerRadius
    }

    // 右下角装饰
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 40
        height: 40
        color: "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth
        radius: root.cornerRadius
    }

    // ========== 标题栏装饰 ==========
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#252b3d"
        border.color: root.borderColor
        border.width: 1
        radius: root.cornerRadius

        // 标题文字
        Text {
            anchors.centerIn: parent
            text: root.title
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
        }

        // 左侧装饰线
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 30
            color: root.borderColor
            radius: 2
        }

        // 右侧装饰线
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 30
            color: root.borderColor
            radius: 2
        }
    }

    // ========== 发光效果 ==========
    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        color: "transparent"
        border.color: root.borderColor
        border.width: 1
        radius: root.cornerRadius + 5
        opacity: 0.3
        z: -1

        // 脉冲动画
        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { from: 0.2; to: 0.5; duration: 2000; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.5; to: 0.2; duration: 2000; easing.type: Easing.InOutQuad }
        }
    }
}
