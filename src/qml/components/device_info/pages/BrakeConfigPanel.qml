import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-27 [制动器控制-右侧面板] 制动器配置面板（简化版，无Tab切换）
// 设计风格与电机控制完全一样，但不需要Tab栏
// ✅ 2026-01-28 [统一样式] 替换 TextField 为 CustomTextField
// ✅ 2026-01-28 [两列布局] 改为两列布局，参考 AnalogInputPage - FIX 100.300.83
Rectangle {
    id: root
    implicitWidth: 1400  // ✅ 2026-01-28 修改宽度以支持两列布局
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

            // ✅ 2026-01-28 支持水平滚动
            contentWidth: Math.max(width, 1200)
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: 20
                implicitWidth: 1200  // ✅ 2026-01-28 固定内容宽度
                implicitHeight: childrenRect.height  // ✅ 2026-01-28 自适应高度

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

                // ========== 两列参数区域 ==========
                // ✅ 2026-01-28 改为两列布局，删除原有分组标题
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    spacing: 20

                    // ========== 左列（5个参数）==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width / 2 - 10
                        spacing: 15

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

                            DeviceInfo.CustomTextField {
                                id: holdTimeField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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

                            DeviceInfo.CustomTextField {
                                id: releaseTimeField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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

                            DeviceInfo.CustomTextField {
                                id: maxTimeField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
                            }

                            Text {
                                text: "秒"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                            }
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

                            DeviceInfo.CustomTextField {
                                id: brakeDelayField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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

                            DeviceInfo.CustomTextField {
                                id: emergencyBrakeField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
                            }

                            Text {
                                text: "秒"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                            }
                        }
                    }

                    // ========== 右列（4个参数）==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width / 2 - 10
                        spacing: 15

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

                            DeviceInfo.CustomTextField {
                                id: brakeOutputField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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

                            DeviceInfo.CustomTextField {
                                id: reducerOutputField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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

                            DeviceInfo.CustomTextField {
                                id: releaseInPlaceField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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

                            DeviceInfo.CustomTextField {
                                id: brakeInPlaceField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.87]: 固定最大宽度 300px
                                placeholderText: "0"
                                text: "0"
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
