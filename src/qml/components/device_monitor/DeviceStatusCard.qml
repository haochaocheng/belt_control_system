import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-02-10 [Phase 7.45.3]: 设备状态卡片
// 显示皮带/辅助设备的状态信息
Rectangle {
    id: root

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property string deviceType: "Belt"  // Belt/Loader/Crusher/FrontScraper/RearScraper
    property string controlStation: "主站"
    property bool isLocal: false
    property bool isOnline: true
    property string status: "运行中"
    property real speed: 1.2
    property string lastUpdate: "15:30:25"

    // ========== 样式属性 ==========
    implicitWidth: 280
    implicitHeight: 180
    radius: 8

    // 根据本机/从机状态设置边框
    border.width: isLocal ? 3 : 2
    border.color: {
        if (isLocal) return "#00ff00"  // 本机：绿色
        if (!isOnline) return "#2a3f5f"  // 离线：灰色
        return "#00d4ff"  // 从机在线：青色
    }

    // ✅ 科技感：渐变背景
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#1a2f3e" }
        GradientStop { position: 1.0; color: "#0a1f2e" }
    }

    opacity: isOnline ? 1.0 : 0.6

    // ✅ 科技感：外层发光效果
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        color: "transparent"
        border.width: 2
        border.color: root.border.color
        radius: root.radius + 3
        opacity: 0.4
        visible: isOnline
    }

    // ✅ 科技感：内层光晕
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: "transparent"
        border.width: 1
        border.color: root.border.color
        radius: root.radius - 2
        opacity: 0.6
        visible: isOnline
    }

    // ========== 内容布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        // 设备名称行
        RowLayout {
            spacing: 10

            // 状态指示圆点
            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: {
                    if (!isOnline) return "#E74C3C"  // 离线：红色
                    if (isLocal) return "#00ff00"  // 本机：绿色
                    return "#00d4ff"  // 从机在线：青色
                }

                // 闪烁动画（在线时）
                SequentialAnimation on opacity {
                    running: isOnline
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                }

                // ✅ 科技感：光晕效果（3层）
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: (parent.width + 8) / 2
                    color: "transparent"
                    border.width: 2
                    border.color: parent.color
                    opacity: 0.5
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 16
                    height: parent.height + 16
                    radius: (parent.width + 16) / 2
                    color: "transparent"
                    border.width: 1
                    border.color: parent.color
                    opacity: 0.3
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 24
                    height: parent.height + 24
                    radius: (parent.width + 24) / 2
                    color: "transparent"
                    border.width: 1
                    border.color: parent.color
                    opacity: 0.1
                }
            }

            Text {
                text: deviceName
                font.pixelSize: 20
                font.bold: true
                font.family: "Microsoft YaHei"
                color: {
                    if (isLocal) return "#00ff00"
                    if (!isOnline) return "#5a6f8f"
                    return "#00d4ff"
                }
            }
        }

        // 本机标签（如果是本机）
        Text {
            text: "(本机)"
            font.pixelSize: 14
            font.family: "Microsoft YaHei"
            color: "#00ff00"
            visible: isLocal
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#2a3f5f"
        }

        // 在线状态
        RowLayout {
            spacing: 8

            Text {
                text: "状态:"
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                color: "#5a6f8f"
            }

            Text {
                text: isOnline ? status : "离线"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
                color: {
                    if (!isOnline) return "#E74C3C"
                    if (status === "运行中") return "#2ECC71"
                    if (status === "停止") return "#95A5A6"
                    return "#F39C12"
                }
            }
        }

        // 速度（仅皮带和辅助设备显示）
        RowLayout {
            spacing: 8
            visible: isOnline && (deviceType === "Belt" || deviceType === "Loader" ||
                                  deviceType === "Crusher" || deviceType === "FrontScraper" ||
                                  deviceType === "RearScraper")

            Text {
                text: "速度:"
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                color: "#5a6f8f"
            }

            Text {
                text: speed.toFixed(1) + " m/s"
                font.pixelSize: 16
                font.family: "Consolas"
                color: "#00d4ff"
            }
        }

        // 控制集控
        RowLayout {
            spacing: 8

            Text {
                text: "集控:"
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                color: "#5a6f8f"
            }

            Text {
                text: controlStation
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }
        }

        // 最后更新时间
        Text {
            text: "更新: " + (isOnline ? lastUpdate : "--")
            font.pixelSize: 12
            font.family: "Consolas"
            color: "#5a6f8f"
        }

        Item { Layout.fillHeight: true }
    }

    // ========== 鼠标交互 ==========
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            root.scale = 1.02
        }

        onExited: {
            root.scale = 1.0
        }

        onClicked: {
            console.log("🖱️ [DeviceStatusCard] 点击设备:", deviceName)
            // TODO: 显示设备详细信息或打开参数设置
        }
    }

    // 缩放动画
    Behavior on scale {
        NumberAnimation { duration: 150 }
    }
}
