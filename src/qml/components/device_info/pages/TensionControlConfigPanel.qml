import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-27 [张紧控制-右侧面板] 控制配置面板
// 张力传感器：包含模拟量弹窗的所有参数（完整版）
// 独立张紧控制：待实现
Rectangle {
    id: root
    // ✅ 2026-01-28 [FIX 100.300.89]: 改为两列布局，宽度从 800 增加到 1400
    implicitWidth: 1400  // 支持两列布局
    implicitHeight: 600  // 默认高度（用于QDS预览）
    // ✅ 改为透明背景，与开关量/模拟量/电机控制/制动器控制页面统一
    color: "transparent"

    // ========== 公开属性 ==========
    property int controlIndex: 0  // 当前控制索引 (0=张力传感器, 1=独立张紧控制)

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
            text: root.controlIndex === 0 ? "张力传感器配置" : "独立张紧控制配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域（根据 controlIndex 切换）==========
    Rectangle {
        id: contentArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        // ========== StackLayout 切换内容 ==========
        StackLayout {
            anchors.fill: parent
            currentIndex: root.controlIndex

            // ========== 0: 张力传感器配置（完整参数）==========
            Item {
                // ========== 滚动区域：参数字段 ==========
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 15
                    clip: true

                    // ✅ 2026-01-28 [FIX 100.300.89]: 移除水平滚动条禁用，支持两列布局
                    // ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    // ✅ 2026-01-28 [FIX 100.300.89]: 明确设置 contentWidth，确保两列布局正常显示
                    contentWidth: Math.max(width, 1200)

                    ColumnLayout {
                        width: parent.width
                        // ✅ 2026-01-28 [FIX 100.300.89]: 设置最小宽度和动态高度
                        implicitWidth: 1200  // 两列布局需要的最小宽度
                        implicitHeight: childrenRect.height
                        spacing: 15

                        // ✅ 2026-01-28 [FIX 100.300.89]: 两列布局 - 参数区域
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20

                            // ========== 左列 ==========
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width / 2 - 10
                                spacing: 15

                                // ========== 保护名称 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "保护名称:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomTextField {
                                        id: nameField
                                        text: "张力"
                                        enabled: false  // 固定为"张力"
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }

                                // ========== 保护类型 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "保护类型:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomComboBox {
                                        id: typeCombo
                                        enabled: false  // 固定为"模拟量"
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                        model: ["模拟量", "开关量"]
                                        currentIndex: 0
                                    }
                                }

                                // ========== 模块类型 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "模块类型:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomComboBox {
                                        id: moduleTypeCombo
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                        model: ["模拟量模块1", "模拟量模块2", "模拟量模块3", "模拟量模块4"]
                                        currentIndex: 0
                                    }
                                }

                                // ========== 寄存器地址 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "寄存器地址:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: registerAddressSpin
                                        from: 0
                                        to: 255
                                        value: 6  // 张力默认寄存器地址
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }

                                // ========== 上限值 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "上限值:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: upperLimitSpin
                                        from: 0
                                        to: 10000
                                        value: 100
                                        stepSize: 10
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }

                                // ========== 下限值 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "下限值:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: lowerLimitSpin
                                        from: 0
                                        to: 10000
                                        value: 0
                                        stepSize: 10
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }

                                // ========== 量程 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "量程:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: rangeSpin
                                        from: 1
                                        to: 10000
                                        value: 100
                                        stepSize: 10
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }
                            }

                            // ========== 右列 ==========
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width / 2 - 10
                                spacing: 15

                                // ========== 单位 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "单位:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomComboBox {
                                        id: unitCombo
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                        model: ["m/s", "T", "℃", "kW", "A", "V", "MPa", "%"]
                                        editable: true
                                        currentIndex: 1  // 默认选择 "T"（张力单位）
                                    }
                                }

                                // ========== 保护延时 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "保护延时(秒):"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: delaySpin
                                        from: 0
                                        to: 600
                                        value: 10  // 默认1.0秒 * 10
                                        stepSize: 1
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度

                                        property int decimals: 1
                                        property real realValue: value / 10

                                        textFromValue: function(value, locale) {
                                            return Number(value / 10).toLocaleString(locale, 'f', 1)
                                        }

                                        valueFromText: function(text, locale) {
                                            return Number.fromLocaleString(locale, text) * 10
                                        }
                                    }
                                }

                                // ========== 播放次数 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "播放次数:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: playCountSpin
                                        from: 1
                                        to: 99
                                        value: 3
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }

                                // ========== 播放时长 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "播放时长(秒):"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: durationSpin
                                        from: 1
                                        to: 600
                                        value: 50  // 默认5.0秒 * 10
                                        stepSize: 5
                                        editable: true
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度

                                        property int decimals: 1
                                        property real realValue: value / 10

                                        textFromValue: function(value, locale) {
                                            return Number(value / 10).toLocaleString(locale, 'f', 1)
                                        }

                                        valueFromText: function(text, locale) {
                                            return Number.fromLocaleString(locale, text) * 10
                                        }
                                    }
                                }

                                // ========== 语音报警类型 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "语音报警:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    RadioButton {
                                        id: ttsRadio
                                        text: "文字转语音"
                                        checked: true
                                        font.pixelSize: 14

                                        indicator: Rectangle {
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            x: ttsRadio.leftPadding
                                            y: parent.height / 2 - height / 2
                                            radius: 10
                                            border.color: ttsRadio.checked ? "#2196F3" : "#3d4556"
                                            border.width: 2
                                            color: "transparent"

                                            Rectangle {
                                                width: 10
                                                height: 10
                                                x: 5
                                                y: 5
                                                radius: 5
                                                color: "#2196F3"
                                                visible: ttsRadio.checked
                                            }
                                        }

                                        contentItem: Text {
                                            text: ttsRadio.text
                                            font: ttsRadio.font
                                            color: "#E0E0E0"
                                            leftPadding: ttsRadio.indicator.width + 8
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    RadioButton {
                                        id: fileRadio
                                        text: "音频文件"
                                        checked: false
                                        font.pixelSize: 14

                                        indicator: Rectangle {
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            x: fileRadio.leftPadding
                                            y: parent.height / 2 - height / 2
                                            radius: 10
                                            border.color: fileRadio.checked ? "#2196F3" : "#3d4556"
                                            border.width: 2
                                            color: "transparent"

                                            Rectangle {
                                                width: 10
                                                height: 10
                                                x: 5
                                                y: 5
                                                radius: 5
                                                color: "#2196F3"
                                                visible: fileRadio.checked
                                            }
                                        }

                                        contentItem: Text {
                                            text: fileRadio.text
                                            font: fileRadio.font
                                            color: "#E0E0E0"
                                            leftPadding: fileRadio.indicator.width + 8
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // ========== 报警文字 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: ttsRadio.checked

                                    Text {
                                        text: "报警文字:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomTextField {
                                        id: ttsTextField
                                        text: "张力保护报警"
                                        placeholderText: "输入报警文字内容..."
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 300  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度
                                    }
                                }

                                // ========== 音频文件 ==========
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: fileRadio.checked

                                    Text {
                                        text: "音频文件:"
                                        font.pixelSize: 21
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 120
                                    }

                                    DeviceInfo.CustomTextField {
                                        id: audioField
                                        text: ""
                                        placeholderText: "选择音频文件..."
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 200  // ✅ 2026-01-28 [FIX 100.300.89]: 限制最大宽度（留空间给浏览按钮）
                                        readOnly: true
                                    }

                                    Button {
                                        text: "浏览"
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 35

                                        background: Rectangle {
                                            color: parent.pressed ? "#1976D2" : (parent.hovered ? "#2196F3" : "#1E88E5")
                                            radius: 4
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font.pixelSize: 12
                                            color: "#FFFFFF"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: {
                                            console.log("浏览音频文件")
                                            // TODO: 打开文件选择对话框
                                        }
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
                                    console.log("保存张力传感器配置")
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
                                    console.log("重置张力传感器配置")
                                    // TODO: 重置为默认值
                                }
                            }
                        }
                    }
                }
            }

            // ========== 1: 独立张紧控制配置（待实现）==========
            Rectangle {
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "独立张紧控制\n（待实现）"
                    font.pixelSize: 18
                    color: "#CCCCCC"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
