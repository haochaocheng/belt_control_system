import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo  // ✅ 2026-01-27 [FIX 100.300.32]: 导入自定义组件

// ✅ 2026-01-25 [模拟量输入页面] 左右分栏布局：左侧列表 + 右侧参数编辑
Rectangle {
    id: root
    // ✅ 2026-01-26 [FIX 100.300.25.12]: 明确设置尺寸，确保运行时正确显示
    implicitWidth: 800
    implicitHeight: 600
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentProtectionIndex: 0  // 当前选中的保护项索引

    // ========== 模拟量保护模型 ==========
    ListModel {
        id: analogProtectionModel
        // ✅ 2026-01-26 [FIX 100.300.23]: 移除所有电机相关的模拟量保护
        // 电流、电机温度、振动、绕组等都应该在电机控制里设置
        // 只保留皮带系统级别的模拟量保护
        ListElement { name: "速度"; active: false; currentValue: 0.0; unit: "m/s"; moduleType: "模拟量模块1"; registerAddress: 5 }
        ListElement { name: "张力"; active: false; currentValue: 0.0; unit: "T"; moduleType: "模拟量模块1"; registerAddress: 6 }
        ListElement { name: "红外温度一"; active: false; currentValue: 0.0; unit: "℃"; moduleType: "模拟量模块1"; registerAddress: 7 }
        ListElement { name: "红外温度二"; active: false; currentValue: 0.0; unit: "℃"; moduleType: "模拟量模块1"; registerAddress: 8 }
        ListElement { name: "电压"; active: false; currentValue: 0.0; unit: "V"; moduleType: "模拟量模块1"; registerAddress: 11 }
    }

    // ========== 主布局：左右分栏 ==========
    RowLayout {
        anchors.fill: parent
        // ✅ 2026-01-26 [FIX 100.300.25.25]: 移除 spacing，让标题贴近列表
        spacing: 0

        // ========== 左侧：模拟量列表 ==========
        // ✅ 2026-01-26 [FIX 100.300.23]: 统一为电机控制的主题风格
        Rectangle {
            Layout.fillHeight: true
            // ✅ 2026-01-27 [FIX 100.300.35]: 宽度减少到80%（240px → 192px）
            Layout.preferredWidth: 192
            // ✅ 2026-01-26 [FIX 100.300.25.26]: 改为透明，使用 33.png 作为整体背景
            color: "transparent"
            // ✅ 2026-01-26 [FIX 100.300.25.18]: 添加 clip 防止背景色超出弹窗底部
            clip: true

            // ✅ 2026-01-26 [FIX 100.300.25.26]: 添加整体背景图片 33.png
            Image {
                anchors.fill: parent
                source: "../images/33.png"
                fillMode: Image.Stretch
                z: -1  // 放在最底层
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // 标题栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    // ✅ 2026-01-26 [FIX 100.300.25.26]: 改为透明，显示背景图片
                    color: "transparent"
                    border.color: "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: "模拟量列表"
                        font.pixelSize: 16
                        anchors.verticalCenterOffset: -6
                        anchors.horizontalCenterOffset: 0
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }
                }

                // 模拟量列表
                ListView {
                    id: protectionListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: analogProtectionModel
                    spacing: 0
                    currentIndex: root.currentProtectionIndex

                    delegate: Rectangle {
                        width: protectionListView.width
                        // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整高度，使二级标题比一级标题小
                        height: 45  // 从 60 改为 45（一级标题是 40）
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0

                        // ✅ 2026-01-26 [FIX 100.300.25.5]: 添加背景图片
                        Image {
                            id: backgroundImage
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1  // 放在最底层

                            // 使用相对路径，便于QDS预览
                            source: "../../../images/bhNameBK.png"

                            states: [
                                State {
                                    name: "selected"
                                    when: root.currentProtectionIndex === index
                                    PropertyChanges {
                                        target: backgroundImage
                                        source: "../../../images/bhNameBK1.png"
                                    }
                                },
                                State {
                                    name: "normal"
                                    when: root.currentProtectionIndex !== index
                                    PropertyChanges {
                                        target: backgroundImage
                                        source: "../../../images/bhNameBK.png"
                                    }
                                }
                            ]
                        }

                        // ✅ 左侧激活指示条
                        Rectangle {
                            visible: root.currentProtectionIndex === index
                            width: 4
                            height: parent.height
                            color: "#2196F3"
                            anchors.left: parent.left
                        }

                        // ✅ 2026-01-26 [FIX 100.300.25.5]: 模拟量名称居中显示
                        Text {
                            text: model.name
                            // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整字体，使二级标题比一级标题小
                            font.pixelSize: 14  // 从 16 改为 14（与一级标题相同）
                            font.weight: root.currentProtectionIndex === index ? Font.Bold : Font.Normal
                            color: root.currentProtectionIndex === index ? "#E0E0E0" : "#9E9E9E"
                            anchors.centerIn: parent
                        }

                        // ✅ 2026-01-26 [FIX 100.300.25.5]: 状态指示放在最右侧
                        Row {
                            spacing: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 2
                                color: model.active ? "#F44336" : "#4CAF50"  // 红色激活，绿色正常
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: model.active ? "已激活" : "正常"
                                font.pixelSize: 12
                                color: "#9E9E9E"
                            }
                        }

                        // ✅ 鼠标点击
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.currentProtectionIndex = index
                                loadProtectionData(index)
                            }
                        }
                    }
                }
            }
        }

        // ========== 右侧：参数编辑区域 ==========
        // ✅ 2026-01-26 [FIX 100.300.24]: 统一为电机控制的主题风格
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "transparent"  // 与电机控制一致：透明背景
            // ❌ 2026-01-27 [FIX 100.300.39]: 移除调试日志

            // ✅ 2026-01-26 [FIX 100.300.25.24]: 标题区域直接 anchor，与电机控制保持一致
            Rectangle {
                id: titleBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 50
                color: "transparent"

                // 背景图片
                Image {
                    anchors.fill: parent
                    source: "../images/059.png"
                    fillMode: Image.Stretch
                    z: -1
                }

                // 标题文字
                Text {
                    anchors.centerIn: parent
                    text: "保护参数设置"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                }
            }

            // ✅ 内容区域
            ColumnLayout {
                anchors.top: titleBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 15
                spacing: 12

                // 滚动区域：参数字段
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    // ❌ 2026-01-27 [FIX 100.300.39]: 移除调试日志

                    ColumnLayout {
                        width: parent.width - 20
                        spacing: 12

                        // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加隐式高度，让 ScrollView 知道内容大小
                        implicitHeight: childrenRect.height
                        // ❌ 2026-01-27 [FIX 100.300.39]: 移除调试日志

                        // ✅ 2026-01-27 [FIX 100.300.38]: 参数区域分为左右2列
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0  // ✅ 2026-01-27 [FIX 100.300.41]: 改为0，用装饰条控制间距

                            // ========== 左列：保护名称到单位 ==========
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 200
                                Layout.alignment: Qt.AlignTop
                                spacing: 12

                                // 保护名称
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "保护名称:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.32]: 使用自定义 TextField（034.png 背景）
                                    DeviceInfo.CustomTextField {
                                        id: nameField
                                        Layout.fillWidth: true
                                    }
                                }

                                // 模块类型
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "模块类型:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    ComboBox {
                                        id: moduleTypeCombo
                                        Layout.fillWidth: true

                                        model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]

                                        background: Rectangle {
                                            color: "#2d3548"
                                            radius: 2
                                            border.color: moduleTypeCombo.pressed ? "#3498db" : "#7f8c8d"
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: moduleTypeCombo.displayText
                                            color: "#E0E0E0"
                                            font.pixelSize: 12
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10
                                        }

                                        onCurrentTextChanged: {
                                            // 根据模块类型自动设置寄存器地址
                                            if (currentText === "输入模块1") {
                                                registerAddressSpin.value = 2
                                            } else if (currentText === "输入模块2") {
                                                registerAddressSpin.value = 3
                                            } else if (currentText === "输入模块3") {
                                                registerAddressSpin.value = 4
                                            } else if (currentText === "输入模块4") {
                                                registerAddressSpin.value = 5
                                            } else if (currentText === "输出模块") {
                                                registerAddressSpin.value = 50
                                            }
                                        }
                                    }
                                }

                                // 寄存器地址
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: moduleTypeCombo.currentText !== "主模块"

                                    Text {
                                        text: "寄存器地址:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.33]: 使用自定义 SpinBox（034.png 背景）
                                    DeviceInfo.CustomSpinBox {
                                        id: registerAddressSpin
                                        from: 0
                                        to: 255
                                        editable: true
                                        Layout.fillWidth: true
                                    }
                                }

                                // 通道编号
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "通道编号:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.33]: 使用自定义 SpinBox（034.png 背景）
                                    DeviceInfo.CustomSpinBox {
                                        id: channelSpin
                                        from: 0
                                        to: 7
                                        editable: true
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#3d4556"
                                    opacity: 0.2
                                }

                                // ✅ 2026-01-27 [FIX 100.300.31]: 添加上限值、下限值、量程、单位参数（与张力传感器一致）
                                // 上限值
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "上限值:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.33]: 使用自定义 SpinBox（034.png 背景）
                                    DeviceInfo.CustomSpinBox {
                                        id: upperLimitSpin
                                        from: 0
                                        to: 10000
                                        value: 100
                                        stepSize: 10
                                        editable: true
                                        Layout.fillWidth: true
                                    }
                                }

                                // 下限值
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "下限值:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.33]: 使用自定义 SpinBox（034.png 背景）
                                    DeviceInfo.CustomSpinBox {
                                        id: lowerLimitSpin
                                        from: 0
                                        to: 10000
                                        value: 0
                                        stepSize: 10
                                        editable: true
                                        Layout.fillWidth: true
                                    }
                                }

                                // 量程
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "量程:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.33]: 使用自定义 SpinBox（034.png 背景）
                                    DeviceInfo.CustomSpinBox {
                                        id: rangeSpin
                                        from: 1
                                        to: 10000
                                        value: 100
                                        stepSize: 10
                                        editable: true
                                        Layout.fillWidth: true
                                    }
                                }

                                // 单位
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "单位:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    ComboBox {
                                        id: unitCombo
                                        Layout.fillWidth: true
                                        model: ["m/s", "T", "℃", "kW", "A", "V", "MPa", "%"]
                                        editable: true
                                        currentIndex: 0  // 默认选择 "m/s"

                                        background: Rectangle {
                                            color: "#2d3548"
                                            radius: 2
                                            border.color: unitCombo.activeFocus ? "#3498db" : "#7f8c8d"
                                            border.width: 1
                                        }

                                        contentItem: TextInput {
                                            text: unitCombo.editable ? unitCombo.editText : unitCombo.displayText
                                            font.pixelSize: 12
                                            color: "#E0E0E0"
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10
                                            readOnly: !unitCombo.editable
                                            selectByMouse: true
                                        }
                                    }
                                }
                            }  // 左列结束

                            // ========== 装饰分隔条 ==========
                            Rectangle {
                                Layout.fillHeight: true
                                Layout.preferredWidth: 2
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: "#3A3A3A"  // 深灰色分隔线
                                radius: 1
                            }

                            // ========== 右列：保护延时到音频文件 ==========
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 200
                                Layout.alignment: Qt.AlignTop
                                spacing: 12

                                // 保护延时
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "保护延时(秒):"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: delaySpin
                                        from: 0
                                        to: 600
                                        value: 10
                                        stepSize: 1
                                        editable: true
                                        Layout.fillWidth: true

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

                                // 播放次数
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "播放次数:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: playCountSpin
                                        from: 1
                                        to: 99
                                        value: 3
                                        editable: true
                                        Layout.fillWidth: true
                                    }
                                }

                                // 播放时长
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "播放时长(秒):"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    DeviceInfo.CustomSpinBox {
                                        id: durationSpin
                                        from: 1
                                        to: 600
                                        value: 50
                                        stepSize: 5
                                        editable: true
                                        Layout.fillWidth: true

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

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#3d4556"
                                    opacity: 0.2
                                }

                                // 语音报警类型
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "语音报警:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    RadioButton {
                                        id: ttsRadio
                                        text: "文字转语音"
                                        checked: true
                                        font.pixelSize: 12

                                        indicator: Rectangle {
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            x: ttsRadio.leftPadding
                                            y: parent.height / 2 - height / 2
                                            radius: 9
                                            border.color: ttsRadio.checked ? "#00d4ff" : "#7f8c8d"
                                            border.width: 2
                                            color: "transparent"

                                            Rectangle {
                                                width: 10
                                                height: 10
                                                x: 4
                                                y: 4
                                                radius: 5
                                                color: "#3d4556"
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
                                        font.pixelSize: 12

                                        indicator: Rectangle {
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            x: fileRadio.leftPadding
                                            y: parent.height / 2 - height / 2
                                            radius: 9
                                            border.color: fileRadio.checked ? "#00d4ff" : "#7f8c8d"
                                            border.width: 2
                                            color: "transparent"

                                            Rectangle {
                                                width: 10
                                                height: 10
                                                x: 4
                                                y: 4
                                                radius: 5
                                                color: "#3d4556"
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

                                // TTS文字输入
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: ttsRadio.checked

                                    Text {
                                        text: "报警文字:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.32]: 使用自定义 TextField（034.png 背景）
                                    DeviceInfo.CustomTextField {
                                        id: ttsTextField
                                        placeholderText: "输入报警文字内容..."
                                        Layout.fillWidth: true
                                    }
                                }

                                // 音频文件选择
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    visible: fileRadio.checked

                                    Text {
                                        text: "音频文件:"
                                        font.pixelSize: 21  // ✅ 2026-01-27 [FIX 100.300.36]: 字体大小增加到1.5倍（14px → 21px）
                                        color: "#9E9E9E"
                                        Layout.preferredWidth: 100
                                    }

                                    // ✅ 2026-01-27 [FIX 100.300.32]: 使用自定义 TextField（034.png 背景）
                                    DeviceInfo.CustomTextField {
                                        id: audioField
                                        placeholderText: "选择音频文件..."
                                        Layout.fillWidth: true
                                        readOnly: true
                                    }

                                    Button {
                                        text: "浏览"
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 30

                                        background: Rectangle {
                                            color: parent.pressed ? "#2980b9" : (parent.hovered ? "#3498db" : "#34495e")
                                            radius: 2
                                            border.color: "#2196F3"
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font.pixelSize: 11
                                            color: "#E0E0E0"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: {
                                            console.log("打开文件选择对话框")
                                            // TODO: 实现文件选择
                                        }
                                    }
                                }
                            }  // 右列结束
                        }  // 2列布局结束
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // 底部按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "保存"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            saveProtectionData()
                        }
                    }

                    Button {
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                            radius: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("删除保护:", nameField.text)
                            // TODO: 实现删除功能
                        }
                    }

                    Button {
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d")
                            radius: 2
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            loadProtectionData(root.currentProtectionIndex)
                        }
                    }
                }
            }
        }
    }

    // ========== 辅助函数 ==========

    // 加载保护数据到右侧编辑区域
    function loadProtectionData(index) {
        if (index < 0 || index >= analogProtectionModel.count) {
            return
        }

        var item = analogProtectionModel.get(index)

        // ✅ 2026-01-25 [数据库集成] 从数据库加载完整的保护参数
        var protection = deviceConfigMgr.loadAnalogProtection(root.deviceId, item.name)

        if (protection && protection.protection_name) {
            // 从数据库加载完整参数
            nameField.text = protection.protection_name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(protection.module_type)
            registerAddressSpin.value = protection.register_address
            channelSpin.value = protection.register_address
            // ✅ 2026-01-27 [FIX 100.300.31]: 加载上限值、下限值、量程、单位
            upperLimitSpin.value = protection.upper_limit || 100
            lowerLimitSpin.value = protection.lower_limit || 0
            rangeSpin.value = protection.range || 100
            unitCombo.currentIndex = unitCombo.model.indexOf(protection.unit || item.unit)
            delaySpin.value = protection.protection_delay * 10  // 转换为整数（0.1秒精度）
            playCountSpin.value = protection.play_count
            durationSpin.value = protection.play_duration * 10  // 转换为整数（0.1秒精度）
            ttsRadio.checked = protection.use_text_to_speech === 1
            fileRadio.checked = protection.use_text_to_speech === 0
            ttsTextField.text = protection.tts_text || (item.name + "保护报警")
            audioField.text = protection.audio_file || ""

            console.log("✅ [AnalogInputPage] 从数据库加载完整参数:", item.name)
        } else {
            // 数据库中没有，使用ListModel中的基本数据
            nameField.text = item.name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(item.moduleType)
            registerAddressSpin.value = item.registerAddress
            channelSpin.value = item.registerAddress

            // ✅ 2026-01-27 [FIX 100.300.31]: 设置默认值
            upperLimitSpin.value = 100
            lowerLimitSpin.value = 0
            rangeSpin.value = 100
            unitCombo.currentIndex = unitCombo.model.indexOf(item.unit)

            // 设置默认值
            delaySpin.value = 10  // 1.0秒
            playCountSpin.value = 3
            durationSpin.value = 50  // 5.0秒
            ttsRadio.checked = true
            ttsTextField.text = item.name + "保护报警"
            audioField.text = ""

            console.log("⚠️ [AnalogInputPage] 数据库中没有详细参数，使用默认值:", item.name)
        }
    }

    // 保存保护数据
    function saveProtectionData() {
        if (root.currentProtectionIndex < 0 || root.currentProtectionIndex >= analogProtectionModel.count) {
            return
        }

        // 更新ListModel
        analogProtectionModel.setProperty(root.currentProtectionIndex, "name", nameField.text)
        analogProtectionModel.setProperty(root.currentProtectionIndex, "moduleType", moduleTypeCombo.currentText)
        analogProtectionModel.setProperty(root.currentProtectionIndex, "registerAddress", registerAddressSpin.value)
        analogProtectionModel.setProperty(root.currentProtectionIndex, "registerAddress", channelSpin.value)
        // ✅ 2026-01-27 [FIX 100.300.31]: 更新单位到 ListModel
        analogProtectionModel.setProperty(root.currentProtectionIndex, "unit", unitCombo.editable ? unitCombo.editText : unitCombo.displayText)

        console.log("✅ 保存保护数据到内存:", nameField.text)

        // ✅ 2026-01-25 [数据库集成] 保存到数据库
        var protection = {
            "protection_name": nameField.text,
            "module_type": moduleTypeCombo.currentText,
            "register_address": registerAddressSpin.value,
            "channel_number": channelSpin.value,
            // ✅ 2026-01-27 [FIX 100.300.31]: 保存上限值、下限值、量程、单位
            "upper_limit": upperLimitSpin.value,
            "lower_limit": lowerLimitSpin.value,
            "range": rangeSpin.value,
            "unit": unitCombo.editable ? unitCombo.editText : unitCombo.displayText,
            "protection_delay": delaySpin.realValue,
            "play_count": playCountSpin.value,
            "play_duration": durationSpin.realValue,
            "use_text_to_speech": ttsRadio.checked,
            "tts_text": ttsTextField.text,
            "audio_file": audioField.text
        }

        if (deviceConfigMgr.saveAnalogProtection(root.deviceId, protection)) {
            console.log("✅ [AnalogInputPage] 保存到数据库成功:", nameField.text)
        } else {
            console.error("❌ [AnalogInputPage] 保存到数据库失败:", nameField.text)
        }
    }

    // 组件加载完成后，加载第一个保护项的数据
    Component.onCompleted: {
        // ✅ 2026-01-25 [数据库集成] 从数据库加载模拟量保护配置
        console.log("✅ [AnalogInputPage] 开始加载设备", deviceId, "的模拟量保护配置")

        var protections = deviceConfigMgr.loadAllAnalogProtections(deviceId)
        console.log("✅ [AnalogInputPage] 从数据库加载了", protections.length, "个保护项")

        if (protections.length > 0) {
            // 清空现有模型
            analogProtectionModel.clear()

            // 加载数据库中的配置
            for (var i = 0; i < protections.length; i++) {
                var p = protections[i]
                analogProtectionModel.append({
                    name: p.protection_name,
                    active: p.active === 1,
                    currentValue: p.current_value || 0.0,
                    unit: p.unit || "m/s",
                    moduleType: p.module_type,
                    registerAddress: p.register_address
                })
            }

            console.log("✅ [AnalogInputPage] 数据库配置加载完成")
        } else {
            console.log("⚠️ [AnalogInputPage] 数据库中没有配置，使用默认配置")
        }

        // 加载第一个保护项的详细参数
        if (analogProtectionModel.count > 0) {
            loadProtectionData(0)
        }
    }
}
