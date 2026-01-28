import QtQuick 2.15
import QtQuick.Controls 2.15

// ✅ 2026-01-25 [X轴振动保护] X轴振动保护配置
Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0

    // ========== 滚动视图 ==========
    ScrollView {
        anchors.fill: parent
        clip: true

        Column {
            width: parent.width
            spacing: 15
            leftPadding: 30
        rightPadding: 30
        topPadding: 30
        // FIX 100.300.59: Use separate padding to avoid polish() loop

            // 是否投入
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "是否投入:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 30
                    Row {
                        spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            border.color: "#2196F3"; border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: true }
                        }
                        Text { text: "投入"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            border.color: "#2196F3"; border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: false }
                        }
                        Text { text: "禁用"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            // 报警类型
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "报警类型:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 30
                    Row {
                        spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            border.color: "#2196F3"; border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: true }
                        }
                        Text { text: "按次数"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            border.color: "#2196F3"; border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: false }
                        }
                        Text { text: "按时间"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            // 动作保护类型
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "动作保护类型:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 200; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "立即停机"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }

            // 故障保护类型
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "故障保护类型:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 200; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "紧急停机"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }

            // 温度量程
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "温度量程:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 200; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "-20~100℃"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }

            // 温度上限
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "温度上限:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 120; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "80"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
                Text {
                    text: "℃"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 温度下限
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "温度下限:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 120; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "-10"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
                Text {
                    text: "℃"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 过滤干扰延时
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "过滤干扰延时:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 120; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "0.5 秒"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }

            // 输入点选择
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "输入点选择:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 200; height: 36
                    color: "#2d3548"
                    border.color: "#3d4556"; border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "AI-0"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }
        }
    }
}
