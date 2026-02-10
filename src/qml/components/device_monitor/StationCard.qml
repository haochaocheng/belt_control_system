import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-02-10 [Phase 7.45.3]: 集控设备状态卡片
// 显示主站/分站的状态信息
Rectangle {
    id: root

    // ========== 公开属性 ==========
    property int stationId: 1
    property string stationRole: "master"  // "master" 或 "sub"
    property string stationName: "主站"
    property string controlDevice: "1号皮带"
    property int controlDeviceId: 1
    property string ip: "192.168.10.188"
    property bool isOnline: true
    property bool isLocal: false
    property string status: "运行中"
    property string lastUpdate: "15:30:25"

    // ========== 样式属性 ==========
    implicitWidth: 280
    implicitHeight: 200
    radius: 8

    // 根据角色和状态设置边框
    border.width: {
        if (isLocal) return 3
        if (stationRole === "master") return 3
        if (!isOnline) return 1
        return 2
    }

    border.color: {
        if (isLocal) return "#00ff00"  // 本机：绿色
        if (stationRole === "master") return "#0080ff"  // 主站：蓝色
        if (!isOnline) return "#2a3f5f"  // 离线：灰色
        return "#00ff00"  // 分站在线：绿色
    }

    color: "#1a1f2e"
    opacity: isOnline ? 1.0 : 0.6

    // ========== 内容布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        // 角色和名称行
        RowLayout {
            spacing: 10

            // 状态指示圆点
            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: {
                    if (!isOnline) return "#E74C3C"  // 离线：红色
                    if (stationRole === "master") return "#0080ff"  // 主站：蓝色
                    return "#00ff00"  // 分站在线：绿色
                }

                // 闪烁动画（在线时）
                SequentialAnimation on opacity {
                    running: isOnline
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                }
            }

            Text {
                text: stationName
                font.pixelSize: 20
                font.bold: true
                font.family: "Microsoft YaHei"
                color: {
                    if (isLocal) return "#00ff00"
                    if (stationRole === "master") return "#0080ff"
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

        // 控制设备
        RowLayout {
            spacing: 8

            Text {
                text: "控制:"
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                color: "#5a6f8f"
            }

            Text {
                text: controlDevice
                font.pixelSize: 16
                font.bold: true
                font.family: "Microsoft YaHei"
                color: "#00d4ff"
            }
        }

        // IP地址
        RowLayout {
            spacing: 8

            Text {
                text: "IP:"
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                color: "#5a6f8f"
            }

            Text {
                text: isOnline ? ip : "--"
                font.pixelSize: 14
                font.family: "Consolas"
                color: isOnline ? "#00d4ff" : "#5a6f8f"
            }
        }

        // 运行状态
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
            console.log("🖱️ [StationCard] 点击集控设备:", stationName)
            // TODO: 显示集控设备详细信息
        }
    }

    // 缩放动画
    Behavior on scale {
        NumberAnimation { duration: 150 }
    }
}
