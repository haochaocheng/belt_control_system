import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components/device_monitor"
import "../Input1/Input1Content"

// ✅ 2026-02-10 [Phase 7.45.9]: 设备监控页面 - 数字孪生布局
// 参考工业监控系统界面，添加 3D 数字孪生效果
// 布局：左侧信息面板 + 中央数字孪生区域 + 右侧控制面板 + 底部数据面板
Item {
    id: root

    width: 1920
    height: 1080
    anchors.fill: parent

    // ========== 背景 ==========
    Back {
        anchors.fill: parent
        z: 0
        enabled: false
    }

    // ========== 头部 ==========
    Item {
        id: headerContainer
        anchors.top: parent.top
        anchors.left: parent.left
        width: 1920
        height: 80
        clip: true
        z: 10

        transform: Scale {
            property real scaleFactor: root.width / 1920
            xScale: scaleFactor
            yScale: scaleFactor
            origin.x: 0
            origin.y: 0
        }

        Head {
            width: 1920
            height: 80
            currentPageIndex: 1
        }
    }

    // ========== 主内容区域（三栏布局）==========
    RowLayout {
        anchors.top: headerContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomPanel.top
        anchors.margins: 10
        spacing: 10

        // ========== 左侧信息面板 ==========
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: "#0a0f1e"
            border.width: 2
            border.color: "#00d4ff"
            radius: 8
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 设备总览
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f3e" }
                        GradientStop { position: 1.0; color: "#0a1f2e" }
                    }
                    border.width: 1
                    border.color: "#00d4ff"
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        Text {
                            text: "设备总览"
                            font.pixelSize: 16
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#00d4ff"
                            opacity: 0.3
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 10

                            Text {
                                text: "总设备:"
                                font.pixelSize: 12
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                            }
                            Text {
                                text: "12"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "Consolas"
                                color: "#00d4ff"
                            }

                            Text {
                                text: "在线:"
                                font.pixelSize: 12
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                            }
                            Text {
                                text: "8"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "Consolas"
                                color: "#2ECC71"
                            }

                            Text {
                                text: "运行中:"
                                font.pixelSize: 12
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                            }
                            Text {
                                text: "5"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "Consolas"
                                color: "#00ff00"
                            }
                        }
                    }
                }

                // 本机信息
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a3f1e" }
                        GradientStop { position: 1.0; color: "#0a2f0e" }
                    }
                    border.width: 2
                    border.color: "#00ff00"
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        RowLayout {
                            spacing: 5

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "#00ff00"

                                SequentialAnimation on opacity {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                                }
                            }

                            Text {
                                text: "本机设备"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "Microsoft YaHei"
                                color: "#00ff00"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#00ff00"
                            opacity: 0.3
                        }

                        Text {
                            text: "1号皮带"
                            font.pixelSize: 16
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00ff00"
                        }

                        Text {
                            text: "状态: 运行中"
                            font.pixelSize: 12
                            font.family: "Microsoft YaHei"
                            color: "#2ECC71"
                        }
                    }
                }

                // 关键指标
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f3e" }
                        GradientStop { position: 1.0; color: "#0a1f2e" }
                    }
                    border.width: 1
                    border.color: "#00d4ff"
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "关键指标"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#00d4ff"
                            opacity: 0.3
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 8

                            Text {
                                text: "总产量:"
                                font.pixelSize: 11
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                            }
                            Text {
                                text: "5863 t"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "Consolas"
                                color: "#00d4ff"
                            }

                            Text {
                                text: "运行时长:"
                                font.pixelSize: 11
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                            }
                            Text {
                                text: "127h 56m"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "Consolas"
                                color: "#00d4ff"
                            }

                            Text {
                                text: "效率:"
                                font.pixelSize: 11
                                font.family: "Microsoft YaHei"
                                color: "#5a6f8f"
                            }
                            Text {
                                text: "100%"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "Consolas"
                                color: "#2ECC71"
                            }
                        }

                        // 圆形进度指示器
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 80
                            height: 80
                            radius: 40
                            color: "transparent"
                            border.width: 6
                            border.color: "#00d4ff"

                            Text {
                                anchors.centerIn: parent
                                text: "100%"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "Consolas"
                                color: "#00d4ff"
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ========== 中央数字孪生区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0f1e"
            border.width: 2
            border.color: "#00d4ff"
            radius: 8
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // 标题
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "【皮带输送系统 - 数字孪生】"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.7; duration: 1500 }
                            NumberAnimation { from: 0.7; to: 1.0; duration: 1500 }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "更新: " + Qt.formatTime(new Date(), "hh:mm:ss")
                        font.pixelSize: 12
                        font.family: "Consolas"
                        color: "#5a6f8f"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 2
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // 皮带连接关系图
                BeltConnectionDiagram {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }

        // ========== 右侧控制面板 ==========
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: "#0a0f1e"
            border.width: 2
            border.color: "#00d4ff"
            radius: 8
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 快速操作
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f3e" }
                        GradientStop { position: 1.0; color: "#0a1f2e" }
                    }
                    border.width: 1
                    border.color: "#00d4ff"
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "快速操作"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#00d4ff"
                            opacity: 0.3
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8

                            Button {
                                text: "全部启动"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                background: Rectangle {
                                    color: parent.pressed ? "#2a3f5f" : (parent.hovered ? "#1a2f4f" : "#0a0f1e")
                                    border.width: 1
                                    border.color: "#00d4ff"
                                    radius: 3
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 11
                                    font.family: "Microsoft YaHei"
                                    color: "#00d4ff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Button {
                                text: "全部停止"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                background: Rectangle {
                                    color: parent.pressed ? "#3f2a2a" : (parent.hovered ? "#2f1a1a" : "#0a0f1e")
                                    border.width: 1
                                    border.color: "#E74C3C"
                                    radius: 3
                                }
                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 11
                                    font.family: "Microsoft YaHei"
                                    color: "#E74C3C"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                // 设备列表
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f3e" }
                        GradientStop { position: 1.0; color: "#0a1f2e" }
                    }
                    border.width: 1
                    border.color: "#00d4ff"
                    radius: 5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "设备列表"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#00d4ff"
                            opacity: 0.3
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                model: 12
                                spacing: 5

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 40
                                    color: index === 0 ? "#1a3f1e" : "#0a1f2e"
                                    border.width: 1
                                    border.color: index === 0 ? "#00ff00" : "#2a3f5f"
                                    radius: 3

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: index < 8 ? "#2ECC71" : "#E74C3C"
                                        }

                                        Text {
                                            text: index < 8 ? ((index + 1) + "号皮带") :
                                                  (index === 8 ? "转载机" :
                                                   index === 9 ? "破碎机" :
                                                   index === 10 ? "前刮板" : "后刮板")
                                            font.pixelSize: 11
                                            font.family: "Microsoft YaHei"
                                            color: index === 0 ? "#00ff00" : "#00d4ff"
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: index < 5 ? "运行" : "停止"
                                            font.pixelSize: 10
                                            font.family: "Microsoft YaHei"
                                            color: index < 5 ? "#2ECC71" : "#E74C3C"
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: {
                                            parent.scale = 1.05
                                        }

                                        onExited: {
                                            parent.scale = 1.0
                                        }
                                    }

                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 底部数据面板 ==========
    Rectangle {
        id: bottomPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        height: 200
        color: "#0a0f1e"
        border.width: 2
        border.color: "#00d4ff"
        radius: 8
        opacity: 0.95

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            // 实时数据表格
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#1a2f3e" }
                    GradientStop { position: 1.0; color: "#0a1f2e" }
                }
                border.width: 1
                border.color: "#00d4ff"
                radius: 5

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "实时运行数据"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#00d4ff"
                        opacity: 0.3
                    }

                    // 表格头
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "设备"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                            Layout.preferredWidth: 80
                        }
                        Text {
                            text: "速度"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "电流"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "温度"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                            Layout.preferredWidth: 60
                        }
                        Text {
                            text: "状态"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                            Layout.preferredWidth: 60
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            model: 5
                            spacing: 3

                            delegate: RowLayout {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: (index + 1) + "号皮带"
                                    font.pixelSize: 10
                                    font.family: "Microsoft YaHei"
                                    color: "#00d4ff"
                                    Layout.preferredWidth: 80
                                }
                                Text {
                                    text: (1.2 + index * 0.1).toFixed(1) + " m/s"
                                    font.pixelSize: 10
                                    font.family: "Consolas"
                                    color: "#2ECC71"
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: (45 + index * 5) + " A"
                                    font.pixelSize: 10
                                    font.family: "Consolas"
                                    color: "#F39C12"
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: (35 + index * 2) + " °C"
                                    font.pixelSize: 10
                                    font.family: "Consolas"
                                    color: "#00d4ff"
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: "运行中"
                                    font.pixelSize: 10
                                    font.family: "Microsoft YaHei"
                                    color: "#2ECC71"
                                    Layout.preferredWidth: 60
                                }
                            }
                        }
                    }
                }
            }

            // 故障统计
            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#1a2f3e" }
                    GradientStop { position: 1.0; color: "#0a1f2e" }
                }
                border.width: 1
                border.color: "#00d4ff"
                radius: 5

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "故障统计"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#00d4ff"
                        opacity: 0.3
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 10

                        Text {
                            text: "今日故障:"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                        }
                        Text {
                            text: "0"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "Consolas"
                            color: "#2ECC71"
                        }

                        Text {
                            text: "本周故障:"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                        }
                        Text {
                            text: "2"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "Consolas"
                            color: "#F39C12"
                        }

                        Text {
                            text: "本月故障:"
                            font.pixelSize: 11
                            font.family: "Microsoft YaHei"
                            color: "#5a6f8f"
                        }
                        Text {
                            text: "5"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "Consolas"
                            color: "#E74C3C"
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "平均故障间隔: 127h"
                        font.pixelSize: 10
                        font.family: "Microsoft YaHei"
                        color: "#5a6f8f"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // 报警信息
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#1a2f3e" }
                    GradientStop { position: 1.0; color: "#0a1f2e" }
                }
                border.width: 1
                border.color: "#00d4ff"
                radius: 5

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "最近报警"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#00d4ff"
                        opacity: 0.3
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            model: 3
                            spacing: 5

                            delegate: Rectangle {
                                width: parent.width
                                height: 40
                                color: "#0a1f2e"
                                border.width: 1
                                border.color: "#2a3f5f"
                                radius: 3

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2

                                    Text {
                                        text: index === 0 ? "3号皮带速度异常" :
                                              index === 1 ? "5号皮带温度过高" : "转载机电流波动"
                                        font.pixelSize: 10
                                        font.family: "Microsoft YaHei"
                                        color: "#F39C12"
                                    }

                                    Text {
                                        text: "2026-02-10 " + (15 - index) + ":30:00"
                                        font.pixelSize: 9
                                        font.family: "Consolas"
                                        color: "#5a6f8f"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("✅ [DeviceMonitorPage] 数字孪生设备监控页面已加载")
    }
}
