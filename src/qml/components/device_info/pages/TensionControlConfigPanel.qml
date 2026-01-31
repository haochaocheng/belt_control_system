import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-27 [张紧控制-右侧面板] 控制配置面板
// 张力传感器：包含模拟量弹窗的所有参数（完整版）
// 独立张紧控制：待实现
// ✅ 2026-01-28 [虚拟键盘集成]: 接收并传递键盘管理器
Rectangle {
    id: root
    // ✅ 2026-01-28 [FIX 100.300.89]: 改为两列布局，宽度从 800 增加到 1400
    implicitWidth: 1400  // 支持两列布局
    implicitHeight: 600  // 默认高度（用于QDS预览）
    // ✅ 改为透明背景，与开关量/模拟量/电机控制/制动器控制页面统一
    color: "transparent"

    // ========== 公开属性 ==========
    property int controlIndex: 0  // 当前控制索引 (0=张力传感器, 1=独立张紧控制)
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性
    property var keyboardManager: null
    // ✅ 2026-01-31 [FIX 100.300.112.8.2]: 导航焦点属性
    // ✅ 2026-01-31 [FIX 100.300.112.8.3]: 改为3区域模式（0:列表 1:参数 2:按钮）
    property int focusSubArea: 0  // 0:列表区域 1:参数区域 2:按钮区域
    property int focusUsageStatusIndex: 0  // 使用状态焦点索引（保留但不使用）
    property int focusParamIndex: 0  // 参数区域焦点索引
    property int focusButtonIndex: 0  // 底部按钮区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

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
                    id: paramScrollView  // ✅ 2026-01-31 [FIX 100.300.112.8.5]: 添加 id，供 GridLayout 引用
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

                        // ✅ 2026-01-31 [FIX 100.300.112.8.5]: 改为 GridLayout 布局，与 SwitchInputPage/AnalogInputPage 保持一致
                        // ❌ 2026-01-31 [注释]: 移除旧的 RowLayout 两列布局
                        // 原因：统一界面布局风格，提高代码可维护性，优化参数字段的视觉对齐，使参数索引符合两列交叉的导航逻辑
                        GridLayout {
                            width: paramScrollView.width * 0.9
                            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
                            columnSpacing: 10
                            rowSpacing: 12

                            // ========== 第一行：保护名称（左）、单位（右）==========
                            // 参数索引: 0 - 保护名称（左列，行0）
                            Text {
                                text: "保护名称:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 0
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 0
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: nameField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: nameField
                                    anchors.fill: parent
                                    text: "张力"
                                    enabled: false
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 1 - 单位（右列，行0）
                            Text {
                                text: "单位:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 0
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 0
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: unitCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: unitCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["m/s", "T", "℃", "kW", "A", "V", "MPa", "%"]
                                    editable: true
                                    currentIndex: 1
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第二行：保护类型（左）、保护延时（右）==========
                            // 参数索引: 2 - 保护类型（左列，行1）
                            Text {
                                text: "保护类型:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 1
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 1
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: typeCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: typeCombo
                                    anchors.fill: parent
                                    enabled: false
                                    keyboardManager: root.keyboardManager
                                    model: ["模拟量", "开关量"]
                                    currentIndex: 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 3 - 保护延时（右列，行1）
                            Text {
                                text: "保护延时(秒):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 1
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 1
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: delaySpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: delaySpin
                                    from: 0
                                    to: 600
                                    value: 10
                                    stepSize: 1
                                    editable: true
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager

                                    property int decimals: 1
                                    property real realValue: value / 10

                                    textFromValue: function(value, locale) {
                                        return Number(value / 10).toLocaleString(locale, 'f', 1)
                                    }

                                    valueFromText: function(text, locale) {
                                        return Number.fromLocaleString(locale, text) * 10
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第三行：模块类型（左）、播放次数（右）==========
                            // 参数索引: 4 - 模块类型（左列，行2）
                            Text {
                                text: "模块类型:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 2
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 2
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: moduleTypeCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: moduleTypeCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["模拟量模块1", "模拟量模块2", "模拟量模块3", "模拟量模块4"]
                                    currentIndex: 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 5 - 播放次数（右列，行2）
                            Text {
                                text: "播放次数:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 2
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 2
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: playCountSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: playCountSpin
                                    from: 1
                                    to: 99
                                    value: 3
                                    editable: true
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 5) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第四行：寄存器地址（左）、播放时长（右）==========
                            // 参数索引: 6 - 寄存器地址（左列，行3）
                            Text {
                                text: "寄存器地址:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 3
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 3
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: registerAddressSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: registerAddressSpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 255
                                    value: 6
                                    editable: true
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 6) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 7 - 播放时长（右列，行3）
                            Text {
                                text: "播放时长(秒):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 3
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 3
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: durationSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: durationSpin
                                    from: 1
                                    to: 600
                                    value: 50
                                    stepSize: 5
                                    editable: true
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager

                                    property int decimals: 1
                                    property real realValue: value / 10

                                    textFromValue: function(value, locale) {
                                        return Number(value / 10).toLocaleString(locale, 'f', 1)
                                    }

                                    valueFromText: function(text, locale) {
                                        return Number.fromLocaleString(locale, text) * 10
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 7) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第五行：上限值（左）、语音报警（右）==========
                            // 参数索引: 8 - 上限值（左列，行4）
                            Text {
                                text: "上限值:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 4
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 4
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: upperLimitSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: upperLimitSpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 10000
                                    value: 100
                                    stepSize: 10
                                    editable: true
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 8) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 9 - 语音报警（右列，行4）
                            Text {
                                text: "语音报警:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 4
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 4
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: radioRow.implicitHeight

                                Row {
                                    id: radioRow
                                    spacing: 30

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

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 9) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第六行：下限值（左）、报警文字（右）==========
                            // 参数索引: 10 - 下限值（左列，行5）
                            Text {
                                text: "下限值:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 5
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 5
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: lowerLimitSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: lowerLimitSpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 10000
                                    value: 0
                                    stepSize: 10
                                    editable: true
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 10) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 10) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 11 - 报警文字（右列，行5）
                            Text {
                                text: "报警文字:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 5
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                                visible: ttsRadio.checked
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 5
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: ttsTextField.implicitHeight
                                visible: ttsRadio.checked

                                DeviceInfo.CustomTextField {
                                    id: ttsTextField
                                    text: "张力保护报警"
                                    placeholderText: "输入报警文字内容..."
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 11) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 11) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第七行：量程（左）、音频文件（右）==========
                            // 参数索引: 12 - 量程（左列，行6）
                            Text {
                                text: "量程:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 6
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 6
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: rangeSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: rangeSpin
                                    anchors.fill: parent
                                    from: 1
                                    to: 10000
                                    value: 100
                                    stepSize: 10
                                    editable: true
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 12) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 12) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 13 - 音频文件（右列，行6）
                            Text {
                                text: "音频文件:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 6
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                                visible: fileRadio.checked
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 6
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: audioFieldRow.implicitHeight
                                visible: fileRadio.checked

                                Row {
                                    id: audioFieldRow
                                    spacing: 10
                                    anchors.fill: parent

                                    DeviceInfo.CustomTextField {
                                        id: audioField
                                        text: ""
                                        placeholderText: "选择音频文件..."
                                        width: parent.width - 70
                                        keyboardManager: root.keyboardManager
                                        readOnly: true
                                    }

                                    Button {
                                        text: "浏览"
                                        width: 60
                                        height: 35

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
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 13) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 13) ? 3 : 0
                                    radius: 4
                                    z: 10
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

