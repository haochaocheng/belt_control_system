import QtQuick 2.15
import QtQuick.Controls 2.15
import ".." as DeviceInfo

// ✅ 2026-01-25 [电机控制-基本配置] 基本配置Tab内容
// ✅ 2026-01-25 [FIX 100.313]: 调整为标签和输入框同一行布局
// ✅ 2026-01-28 [FIX 100.300.60]: 替换所有 SpinBox 为 DeviceInfo.CustomSpinBox
Rectangle {
    id: root
    width: 800  // 默认宽度（用于QDS预览）
    height: 500  // 默认高度（用于QDS预览）
    color: "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0  // 当前电机索引 (0-7)

    // ========== 滚动区域 ==========
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

            // ========== 运行状态 ==========
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20

                Text {
                    text: "运行状态:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 30

                    // 投入选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: true  // 默认选中
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    console.log((root.motorIndex + 1) + "号电机: 投入")
                                }
                            }
                        }

                        Text {
                            text: "投入"
                            font.pixelSize: 14
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 禁用选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: false  // 默认不选中
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    console.log((root.motorIndex + 1) + "号电机: 禁用")
                                }
                            }
                        }

                        Text {
                            text: "禁用"
                            font.pixelSize: 14
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ========== 模块类型 ==========
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20

                Text {
                    text: "模块类型:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
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
            }

            // ========== 模块地址 ==========
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20

                Text {
                    text: "模块地址:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-28 [FIX 100.300.60]: 替换为 DeviceInfo.CustomSpinBox
                DeviceInfo.CustomSpinBox {
                    width: 120
                    height: 36
                    from: 1
                    to: 8
                    value: 1
                    editable: true
                }
            }

            // ========== 输出通道 ==========
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20

                Text {
                    text: "输出通道:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-28 [FIX 100.300.60]: 替换为 DeviceInfo.CustomSpinBox
                DeviceInfo.CustomSpinBox {
                    width: 120
                    height: 36
                    from: 0
                    to: 7
                    value: root.motorIndex
                    editable: true
                }
            }

            // ========== 反馈通道 ==========
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20

                Text {
                    text: "反馈通道:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    width: 120
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-28 [FIX 100.300.60]: 替换为 DeviceInfo.CustomSpinBox
                DeviceInfo.CustomSpinBox {
                    width: 120
                    height: 36
                    from: 0
                    to: 7
                    value: root.motorIndex
                    editable: true
                }
            }
        }
    }
}
