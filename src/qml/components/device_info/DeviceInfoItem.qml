import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-24 [设备信息界面重构] 设备信息卡片组件
// 用于显示单个设备的状态信息，支持选中、点击、双击交互
Item {
    id: root

    // ========== 公开属性 ==========
    property string deviceName: ""              // 设备名称
    property string deviceId: ""                // 设备ID
    property string imagePath: ""               // 图片路径
    property bool isSelected: false             // 是否选中
    property bool isRunning: false              // 是否运行中
    property real speed: 0.0                    // 当前速度
    property string status: "停止"              // 状态文本

    // ========== 信号 ==========
    signal clicked()
    signal doubleClicked()

    // ========== 主容器 ==========
    Rectangle {
        id: container
        anchors.fill: parent
        color: "#1E1E1E"                        // 深色背景
        border.color: isSelected ? "#00FF00" : "#555555"  // 选中时绿色边框
        border.width: isSelected ? 3 : 1
        radius: 8

        // 状态过渡动画
        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }
        Behavior on border.width {
            NumberAnimation { duration: 200 }
        }

        // ========== 设备图片/占位符 ==========
        Rectangle {
            id: imageContainer
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            height: parent.height * 0.5
            color: "#2A2A2A"
            radius: 4

            Image {
                id: deviceImage
                anchors.fill: parent
                anchors.margins: 5
                source: imagePath !== "" ? imagePath : "qrc:/qt/qml/BeltControlQml/Input1/Input1Content/images/devices/placeholder.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true  // 异步加载，提升性能

                // 图片加载失败时显示占位符
                onStatusChanged: {
                    if (status === Image.Error) {
                        console.warn("[DeviceInfoItem] 图片加载失败:", imagePath)
                    }
                }
            }

            // 占位符文本（当没有图片时）
            Text {
                anchors.centerIn: parent
                text: deviceName
                font.pixelSize: 16
                color: "#888888"
                visible: deviceImage.status === Image.Error || imagePath === ""
            }
        }

        // ========== 设备信息区域 ==========
        Column {
            id: infoColumn
            anchors.top: imageContainer.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 5

            // 设备名称
            Text {
                width: parent.width
                text: deviceName
                font.pixelSize: 14
                font.bold: true
                color: "#FFFFFF"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // 运行状态
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: {
                        if (status === "故障") return "#FF0000"      // 红色
                        if (status === "警告") return "#FFFF00"      // 黄色
                        if (isRunning) return "#00FF00"              // 绿色
                        return "#808080"                             // 灰色
                    }

                    // 运行中时闪烁动画
                    SequentialAnimation on opacity {
                        running: isRunning
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                Text {
                    text: status
                    font.pixelSize: 12
                    color: "#CCCCCC"
                }
            }

            // 速度信息
            Text {
                width: parent.width
                text: isRunning ? "速度: " + speed.toFixed(1) + " m/s" : ""
                font.pixelSize: 11
                color: "#999999"
                horizontalAlignment: Text.AlignHCenter
                visible: isRunning
            }
        }

        // ========== 鼠标交互区域 ==========
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            onClicked: {
                root.clicked()
            }

            onDoubleClicked: {
                root.doubleClicked()
            }

            onEntered: {
                container.color = "#252525"  // 鼠标悬停时稍微变亮
            }

            onExited: {
                container.color = "#1E1E1E"  // 恢复原色
            }
        }
    }
}
