import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-01-27 [制动器控制-右侧面板] 制动器配置面板（简化版，无Tab切换）
// 设计风格与电机控制完全一样，但不需要Tab栏
Rectangle {
    id: root
    width: 800  // 默认宽度（用于QDS预览）
    height: 600  // 默认高度（用于QDS预览）
    // ✅ 改为透明背景，与开关量/模拟量/电机控制页面统一
    color: "transparent"

    // ========== 公开属性 ==========
    property int brakeIndex: 0  // 当前制动器索引 (0-7)

    // ========== 键盘导航支持 ==========
    focus: true

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        // ✅ 改为透明，使用背景图片
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        // ✅ 添加背景图片，填充整个 header
        Image {
            id: headerBackground
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch  // 拉伸填充整个 header
            z: -1  // 放在最底层
        }

        Text {
            anchors.centerIn: parent
            text: (root.brakeIndex + 1) + "号制动器配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域（无Tab栏，直接显示参数）==========
    Rectangle {
        id: contentArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        // ========== 滚动区域：参数字段 ==========
        ScrollView {
            anchors.fill: parent
            anchors.margins: 15
            clip: true

            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 20

                // ========== 使用状态 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "使用状态"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }

                    RowLayout {
                        spacing: 20

                        RadioButton {
                            id: statusEnabled
                            text: "投入"
                            checked: true
                            font.pixelSize: 14
                            contentItem: Text {
                                text: statusEnabled.text
                                font: statusEnabled.font
                                color: "#E0E0E0"
                                leftPadding: statusEnabled.indicator.width + statusEnabled.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        RadioButton {
                            id: statusDisabled
                            text: "禁用"
                            font.pixelSize: 14
                            contentItem: Text {
                                text: statusDisabled.text
                                font: statusDisabled.font
                                color: "#E0E0E0"
                                leftPadding: statusDisabled.indicator.width + statusDisabled.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // ========== 分割线 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#3d4556"
                }

                // ========== 点刹功能 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "点刹功能"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }

                    // 抱闸保持时间
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "抱闸保持时间:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: holdTimeField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: holdTimeField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }

                        Text {
                            text: "秒"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                        }
                    }

                    // 松闸保持时间
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "松闸保持时间:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: releaseTimeField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: releaseTimeField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }

                        Text {
                            text: "秒"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                        }
                    }

                    // 最长允许时间
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "最长允许时间:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: maxTimeField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: maxTimeField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }

                        Text {
                            text: "秒"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                        }
                    }
                }

                // ========== 分割线 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#3d4556"
                }

                // ========== 抱闸延时 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "抱闸延时"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }

                    // 抱闸延时时间
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "抱闸延时时间:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: brakeDelayField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: brakeDelayField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }

                        Text {
                            text: "秒"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                        }
                    }

                    // 急停抱闸时间
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "急停抱闸时间:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: emergencyBrakeField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: emergencyBrakeField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }

                        Text {
                            text: "秒"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                        }
                    }
                }

                // ========== 分割线 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#3d4556"
                }

                // ========== 输出点 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "输出点"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }

                    // 抱闸输出点
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "抱闸输出点:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: brakeOutputField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: brakeOutputField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }

                    // 减速机输出点
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "减速机输出点:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: reducerOutputField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: reducerOutputField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }

                    // 松闸到位
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "松闸到位:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: releaseInPlaceField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: releaseInPlaceField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }

                    // 抱闸到位
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "抱闸到位:"
                            font.pixelSize: 14
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: brakeInPlaceField
                            Layout.preferredWidth: 150
                            placeholderText: "0"
                            text: "0"
                            color: "#E0E0E0"
                            background: Rectangle {
                                color: "#1a1f2e"
                                border.color: brakeInPlaceField.activeFocus ? "#2196F3" : "#3d4556"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }
                }

                // ========== 底部按钮区域 ==========
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    spacing: 15

                    Button {
                        text: "保存"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        font.pixelSize: 14

                        background: Rectangle {
                            color: parent.pressed ? "#1976D2" : (parent.hovered ? "#2196F3" : "#1E88E5")
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("保存制动器配置:", root.brakeIndex + 1)
                            // TODO: 保存配置到数据库
                        }
                    }

                    Button {
                        text: "重置"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        font.pixelSize: 14

                        background: Rectangle {
                            color: parent.pressed ? "#616161" : (parent.hovered ? "#757575" : "#9E9E9E")
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("重置制动器配置:", root.brakeIndex + 1)
                            // TODO: 重置为默认值
                        }
                    }
                }
            }
        }
    }
}
