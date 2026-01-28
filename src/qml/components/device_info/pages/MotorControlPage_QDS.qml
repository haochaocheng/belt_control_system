import QtQuick 2.15

// ✅ 2026-01-25 [电机控制-QDS预览版] 电机控制主页面（简化版，用于QDS预览）
// ⚠️ 注意：这是专门为 QDS 预览创建的简化版本，不包含交互逻辑
Rectangle {
    id: root
    width: 1000
    height: 600
    color: "#1a1f2e"  // 深蓝灰背景

    // ========== 左侧：电机列表 ==========
    Rectangle {
        id: leftPanel
        x: 0
        y: 0
        width: 200
        height: 600
        color: "#252b3d"

        // 标题
        Rectangle {
            x: 0
            y: 0
            width: 200
            height: 50
            color: "#252b3d"
            border.color: "#3d4556"
            border.width: 1

            Text {
                x: 60
                y: 17
                text: "电机列表"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "#E0E0E0"
            }
        }

        // 1号电机（选中状态）
        Rectangle {
            x: 0
            y: 50
            width: 200
            height: 60
            color: "#252b3d"
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

        // 3-8号电机（简化显示）
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

    // ========== 分隔线 ==========
    Rectangle {
        x: 200
        y: 0
        width: 2
        height: 600
        color: "#3d4556"
    }

    // ========== 右侧：配置面板 ==========
    Rectangle {
        id: rightPanel
        x: 202
        y: 0
        width: 798
        height: 600
        color: "#1a1f2e"

        // 标题
        Rectangle {
            x: 0
            y: 0
            width: 798
            height: 50
            color: "#252b3d"
            border.color: "#3d4556"
            border.width: 1

            Text {
                x: 30
                y: 17
                text: "1号电机配置"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "#E0E0E0"
            }
        }

        // Tab栏
        Rectangle {
            x: 0
            y: 50
            width: 798
            height: 50
            color: "#252b3d"
            border.color: "#3d4556"
            border.width: 1

            // 基本配置 Tab（选中状态）
            Rectangle {
                x: 0
                y: 0
                width: 120
                height: 50
                color: "transparent"

                Text {
                    x: 30
                    y: 17
                    text: "基本配置"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#2196F3"
                }

                Rectangle {
                    x: 0
                    y: 47
                    width: 120
                    height: 3
                    color: "#2196F3"
                }
            }

            // 电流保护 Tab
            Rectangle {
                x: 120
                y: 0
                width: 120
                height: 50
                color: "transparent"

                Text {
                    x: 30
                    y: 17
                    text: "电流保护"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                }
            }

            // 其他 Tab（简化显示）
            Text {
                x: 260
                y: 17
                text: "前轴承温度"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Text {
                x: 380
                y: 17
                text: "后轴承温度"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Text {
                x: 500
                y: 17
                text: "A相绕组"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Text {
                x: 600
                y: 17
                text: "..."
                font.pixelSize: 14
                color: "#9E9E9E"
            }
        }

        // 内容区域（基本配置示例）
        Rectangle {
            x: 0
            y: 100
            width: 798
            height: 500
            color: "transparent"

            // 运行状态
            Text {
                x: 30
                y: 30
                text: "运行状态:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            // 投入选项
            Rectangle {
                x: 170
                y: 26
                width: 20
                height: 20
                radius: 10
                border.color: "#2196F3"
                border.width: 2
                color: "transparent"

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: "#2196F3"
                    anchors.centerIn: parent
                }
            }

            Text {
                x: 198
                y: 30
                text: "投入"
                font.pixelSize: 14
                color: "#E0E0E0"
            }

            // 禁用选项
            Rectangle {
                x: 260
                y: 26
                width: 20
                height: 20
                radius: 10
                border.color: "#2196F3"
                border.width: 2
                color: "transparent"
            }

            Text {
                x: 288
                y: 30
                text: "禁用"
                font.pixelSize: 14
                color: "#E0E0E0"
            }

            // 模块类型
            Text {
                x: 30
                y: 80
                text: "模块类型:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Rectangle {
                x: 170
                y: 74
                width: 200
                height: 36
                color: "#2d3548"
                border.color: "#3d4556"
                border.width: 1
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: "继电器模块"
                    font.pixelSize: 14
                    color: "#E0E0E0"
                }
            }

            // 模块地址
            Text {
                x: 30
                y: 130
                text: "模块地址:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Rectangle {
                x: 170
                y: 124
                width: 120
                height: 36
                color: "#2d3548"
                border.color: "#3d4556"
                border.width: 1
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: "1"
                    font.pixelSize: 14
                    color: "#E0E0E0"
                }

                // + 按钮
                Rectangle {
                    x: 90
                    y: 0
                    width: 30
                    height: 18
                    color: "#3d4556"
                    border.color: "#2196F3"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }

                // - 按钮
                Rectangle {
                    x: 90
                    y: 18
                    width: 30
                    height: 18
                    color: "#3d4556"
                    border.color: "#2196F3"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "-"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }

            // 输出通道
            Text {
                x: 30
                y: 180
                text: "输出通道:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Rectangle {
                x: 170
                y: 174
                width: 120
                height: 36
                color: "#2d3548"
                border.color: "#3d4556"
                border.width: 1
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: "0"
                    font.pixelSize: 14
                    color: "#E0E0E0"
                }

                Rectangle {
                    x: 90
                    y: 0
                    width: 30
                    height: 18
                    color: "#3d4556"
                    border.color: "#2196F3"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }

                Rectangle {
                    x: 90
                    y: 18
                    width: 30
                    height: 18
                    color: "#3d4556"
                    border.color: "#2196F3"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "-"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }

            // 反馈通道
            Text {
                x: 30
                y: 230
                text: "反馈通道:"
                font.pixelSize: 14
                color: "#9E9E9E"
            }

            Rectangle {
                x: 170
                y: 224
                width: 120
                height: 36
                color: "#2d3548"
                border.color: "#3d4556"
                border.width: 1
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: "0"
                    font.pixelSize: 14
                    color: "#E0E0E0"
                }

                Rectangle {
                    x: 90
                    y: 0
                    width: 30
                    height: 18
                    color: "#3d4556"
                    border.color: "#2196F3"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }

                Rectangle {
                    x: 90
                    y: 18
                    width: 30
                    height: 18
                    color: "#3d4556"
                    border.color: "#2196F3"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "-"
                        font.pixelSize: 14
                        color: "#E0E0E0"
                    }
                }
            }
        }
    }
}
