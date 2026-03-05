import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo  // ✅ 2026-01-27 [FIX 100.300.32]: 导入自定义组件

// ✅ 2026-01-25 [模拟量输入页面] 左右分栏布局：左侧列表 + 右侧参数编辑
// ✅ 2026-01-28 [虚拟键盘集成]: 接收并传递键盘管理器
// ✅ 2026-01-30 [FIX 100.300.105]: 添加完整的导航系统（参考 SwitchInputPage）
Rectangle {
    id: root
    // ✅ 2026-01-28 [FIX 100.300.75]: 增加 implicitWidth 到 1400，充分利用右侧空间
    // 两列布局需要更大的宽度：左侧列表192px + 右侧参数区域两列（每列约600px）
    implicitWidth: 1400
    implicitHeight: 600
    color: "transparent"

    // ✅ 2026-01-30 [FIX 100.300.105]: 允许接收焦点，以便虚拟键盘关闭后焦点可以返回
    focus: true
    activeFocusOnTab: true

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.10]: 添加返回类别信号
    signal requestReturnToCategory()

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentProtectionIndex: 0  // 当前选中的保护项索引
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性（已废弃，保留兼容性）
    property var keyboardManager: null
    // ✅ 2026-01-30 [FIX 100.300.105]: Qt 虚拟键盘引用
    property var virtualKeyboard: null
    // ✅ 2026-01-30 [FIX 100.300.105]: 导航焦点索引（从父对话框传递）
    property int focusItemIndex: -1  // -1 表示无焦点
    // ✅ 2026-01-30 [FIX 100.300.105]: 导航子区域（0:列表 1:参数 3:底部按钮）
    // ❌ 2026-03-03 [Phase 7.47.76]: 旧注释：2:底部按钮区域 → 改为3，与MotorControlPage一致，修复键盘Enter误触发虚拟键盘
    property int focusSubArea: 0  // 0:列表区域 1:参数区域 3:底部按钮区域
    property int focusParamIndex: 0  // 参数区域焦点索引
    property int focusButtonIndex: 0  // 底部按钮区域焦点索引

    // ✅ 2026-03-05 [Phase 7.48.6]: 新增属性支持18参数布局
    property string audioSourceMode: "tts"  // 音频来源模式：default=默认音频, tts=TTS合成
    property string playModeSelection: "count"  // 播放方式：count=按次数, duration=按时长
    property int protectionLevel: 1  // 保护级别：0=预警+紧急停车, 1=预警+正常停车, 2=仅预警, 3=不处理
    property string inputType: "4-20mA"  // 输入类型：4-20mA, 0-20mA, 0-5V, 0-10V, 1-5V

    // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护专用属性
    property real speedStartDelay: 0.0      // 电机启动延时（秒）
    property string speedDetectMode: "limit" // 检测模式：limit=上下限, percent=额定百分比
    property real ratedSpeed: 0.0           // 额定速度（m/s）
    property real slipDelay: 10.0           // 低速打滑延时（秒）

    // 判断当前选中的是否为速度保护
    readonly property bool isSpeedProtection: {
        if (currentProtectionIndex >= 0 && currentProtectionIndex < analogProtectionModel.count) {
            return analogProtectionModel.get(currentProtectionIndex).name === "速度"
        }
        return false
    }

    // ✅ 2026-01-31 [FIX 100.300.112.8.12]: 监听焦点变化，同步更新 currentProtectionIndex
    // 当焦点在列表区域移动时，同步更新选中项索引
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < analogProtectionModel.count) {
            console.log("✅ [AnalogInputPage] focusItemIndex 变化:", focusItemIndex, "→ 更新 currentProtectionIndex")
            currentProtectionIndex = focusItemIndex
            loadProtectionData(focusItemIndex)
        }
    }

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.10]: 添加左键返回类别处理
    Keys.onLeftPressed: function(event) {
        if (focusSubArea === 0) {
            // 在列表区域，按左键返回到左侧类别
            console.log("✅ [AnalogInputPage] 列表区域按左键，请求返回到左侧类别")
            root.requestReturnToCategory()
            event.accepted = true
        }
    }

    // ========== 模拟量保护模型 ==========
    ListModel {
        id: analogProtectionModel
        // ✅ 2026-03-05 [Phase 7.48.8]: 扩展模拟量保护从5项到18项（速度/张力/电压为单一保护项）
        // 设备运行保护（7项）
        ListElement { name: "速度"; active: false; currentValue: 0.0; unit: "m/s"; moduleType: "模拟量模块1"; registerAddress: 5 }
        ListElement { name: "张力"; active: false; currentValue: 0.0; unit: "T"; moduleType: "模拟量模块1"; registerAddress: 6 }
        ListElement { name: "煤流"; active: false; currentValue: 0.0; unit: "t/h"; moduleType: "模拟量模块1"; registerAddress: 7 }
        ListElement { name: "煤仓高度"; active: false; currentValue: 0.0; unit: "m"; moduleType: "模拟量模块1"; registerAddress: 8 }
        ListElement { name: "温度一"; active: false; currentValue: 0.0; unit: "℃"; moduleType: "模拟量模块1"; registerAddress: 9 }
        ListElement { name: "温度二"; active: false; currentValue: 0.0; unit: "℃"; moduleType: "模拟量模块1"; registerAddress: 10 }
        ListElement { name: "电压"; active: false; currentValue: 0.0; unit: "V"; moduleType: "模拟量模块1"; registerAddress: 11 }
        // 环境安全监测（8项）
        ListElement { name: "温度"; active: false; currentValue: 0.0; unit: "℃"; moduleType: "模拟量模块1"; registerAddress: 12 }
        ListElement { name: "湿度"; active: false; currentValue: 0.0; unit: "%RH"; moduleType: "模拟量模块1"; registerAddress: 13 }
        ListElement { name: "烟雾"; active: false; currentValue: 0.0; unit: "mg/m³"; moduleType: "模拟量模块1"; registerAddress: 14 }
        ListElement { name: "气压"; active: false; currentValue: 0.0; unit: "kPa"; moduleType: "模拟量模块1"; registerAddress: 15 }
        ListElement { name: "氧气"; active: false; currentValue: 0.0; unit: "%O₂"; moduleType: "模拟量模块1"; registerAddress: 16 }
        ListElement { name: "甲烷"; active: false; currentValue: 0.0; unit: "%CH₄"; moduleType: "模拟量模块1"; registerAddress: 17 }
        ListElement { name: "一氧化碳"; active: false; currentValue: 0.0; unit: "ppm"; moduleType: "模拟量模块1"; registerAddress: 18 }
        ListElement { name: "硫化氢"; active: false; currentValue: 0.0; unit: "ppm"; moduleType: "模拟量模块1"; registerAddress: 19 }
        // 安全规程补充（3项）
        ListElement { name: "二氧化碳"; active: false; currentValue: 0.0; unit: "%CO₂"; moduleType: "模拟量模块1"; registerAddress: 20 }
        ListElement { name: "风速"; active: false; currentValue: 0.0; unit: "m/s"; moduleType: "模拟量模块1"; registerAddress: 21 }
        ListElement { name: "粉尘浓度"; active: false; currentValue: 0.0; unit: "mg/m³"; moduleType: "模拟量模块1"; registerAddress: 22 }
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
                        // ✅ 2026-01-30 [FIX 100.300.105]: 添加焦点指示器边框
                        border.color: isFocused ? "#2196F3" : "transparent"
                        border.width: isFocused ? 3 : 0

                        // ✅ 2026-01-30 [FIX 100.300.105]: 焦点状态判断
                        readonly property bool isFocused: (root.focusSubArea === 0 && root.focusItemIndex === index)
                        // ✅ 2026-01-31 [FIX 100.300.112.8.12]: 分离选中状态和焦点状态
                        // 选中状态：只依赖 currentProtectionIndex（焦点离开列表时保持选中）
                        // 焦点状态：依赖 focusSubArea 和 focusItemIndex（焦点离开列表时消失）
                        readonly property bool isSelected: (root.currentProtectionIndex === index)

                        // ✅ 2026-01-26 [FIX 100.300.25.5]: 添加背景图片
                        Image {
                            id: backgroundImage
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1  // 放在最底层

                            // ✅ 2026-01-30 [FIX 100.300.105]: 根据焦点状态切换背景图片
                            // ✅ 2026-01-31 [FIX 100.300.112.8.12]: 背景图片只依赖选中状态，不依赖焦点状态
                            source: isSelected ? "../../../images/bhNameBK1.png" : "../../../images/bhNameBK.png"

                            // ✅ 2026-01-30 [注释]: 保留原有的 states，但现在由 isFocused 控制
                            // states: [
                            //     State {
                            //         name: "selected"
                            //         when: root.currentProtectionIndex === index
                            //         PropertyChanges {
                            //             target: backgroundImage
                            //             source: "../../../images/bhNameBK1.png"
                            //         }
                            //     },
                            //     State {
                            //         name: "normal"
                            //         when: root.currentProtectionIndex !== index
                            //         PropertyChanges {
                            //             target: backgroundImage
                            //             source: "../../../images/bhNameBK.png"
                            //         }
                            //     }
                            // ]
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
                        // ✅ 2026-01-30 [FIX 100.300.105]: 根据焦点状态调整文字样式
                        Text {
                            text: model.name
                            // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整字体，使二级标题比一级标题小
                            font.pixelSize: 14  // 从 16 改为 14（与一级标题相同）
                            font.weight: isFocused ? Font.Bold : Font.Normal
                            color: isFocused ? "#E0E0E0" : "#9E9E9E"
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
                                // ✅ 2026-02-03 [FIX 100.300.112.8.25.10]: 鼠标点击时同步焦点状态
                                console.log("🔍 [AnalogInputPage] 鼠标点击列表项:", index)
                                root.currentProtectionIndex = index
                                root.focusItemIndex = index
                                root.focusSubArea = 0  // 确保在列表区域
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

                // ✅ 2026-01-28 [FIX 100.300.72.3]: 添加调试日志
                Component.onCompleted: {
                    console.log("✅ [AnalogInputPage] 外层 ColumnLayout 宽度:", width)
                }

                // 滚动区域：参数字段
                ScrollView {
                    id: paramScrollView  // ✅ 2026-01-31 [FIX 100.300.110.1]: 添加 id，供 GridLayout 引用
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // ✅ 2026-01-28 [FIX 100.300.77]: 移除水平滚动条禁用，让内容可以扩展
                    // ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    // ✅ 2026-01-28 [FIX 100.300.77]: 明确设置 contentWidth，确保内容可以充分展开
                    contentWidth: Math.max(width, 1200)  // 至少 1200px，或者使用 ScrollView 的实际宽度

                    // ✅ 2026-01-28 [FIX 100.300.72.3]: 添加调试日志
                    Component.onCompleted: {
                        console.log("✅ [AnalogInputPage] ScrollView 宽度:", width)
                        console.log("✅ [AnalogInputPage] ScrollView contentWidth:", contentWidth)
                    }

                    ColumnLayout {
                        width: parent.width  // ✅ 2026-01-27 [FIX 100.300.42]: 改为完整宽度，让内部2列布局正确填充
                        spacing: 12

                        // ✅ 2026-01-28 [FIX 100.300.76]: 添加 implicitWidth，告诉 ScrollView 内容需要的宽度
                        implicitWidth: 1200  // 两列布局需要的最小宽度
                        // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加隐式高度，让 ScrollView 知道内容大小
                        implicitHeight: childrenRect.height

                        // ✅ 2026-01-28 [FIX 100.300.72.3]: 添加调试日志
                        Component.onCompleted: {
                            console.log("✅ [AnalogInputPage] ScrollView 内部 ColumnLayout 宽度:", width)
                            console.log("✅ [AnalogInputPage] ScrollView 内部 ColumnLayout parent.width:", parent.width)
                        }

                        // ✅ 2026-01-31 [FIX 100.300.110]: 改为 GridLayout 布局，与 SwitchInputPage 保持一致
                        // ❌ 2026-01-31 [注释]: 移除旧的 RowLayout 两列布局（Line 290-1077）
                        // 原因：统一界面布局风格，提高代码可维护性，优化参数字段的视觉对齐
                        GridLayout {
                            width: paramScrollView.width * 0.9
                            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
                            columnSpacing: 10
                            rowSpacing: 12

                            // ========== 第一行：保护名称（左）、保护延时（右）==========
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引1改为播放次数
                            // 参数索引: 1 - 播放次数（右列，行0）
                            Text {
                                text: "播放次数:"
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
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第二行：模块类型（左）、播放次数（右）==========
                            // 参数索引: 2 - 模块类型（左列，行1）
                            Text {
                                text: "模块类型:"
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
                                implicitHeight: moduleTypeCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: moduleTypeCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]

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

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引3改为播放时长
                            // 参数索引: 3 - 播放时长（右列，行1）
                            Text {
                                text: "播放时长(秒):"
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
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第三行：音频来源（左）、TTS文字（右）==========
                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引4改为音频来源按钮组
                            // 参数索引: 4 - 音频来源（左列，行2）
                            Text {
                                text: "音频来源:"
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
                                implicitHeight: 48

                                // 音频来源切换按钮行
                                RowLayout {
                                    id: audioSourceButtonGroup
                                    anchors.fill: parent
                                    spacing: 8

                                    // ✅ 2026-03-05 [Phase 7.48.6]: Cyberpunk 工业风（与开关量一致）
                                    // 选中默认: 深蓝背景 + 青色边框 + 顶部青色高亮线 + LED点
                                    // 选中TTS: 深绿背景 + 绿色边框 + 顶部绿色高亮线 + LED点
                                    // 未选中: 深灰背景 + 板岩边框 + 灰色LED点

                                    // [默认] 按钮
                                    Button {
                                        id: defaultAudioButton
                                        text: "默认"
                                        checkable: true
                                        checked: root.audioSourceMode === "default"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50

                                        background: Rectangle {
                                            color: defaultAudioButton.checked ? "#0a1929" :
                                                   (defaultAudioButton.hovered ? "#1e2d42" : "#141920")
                                            radius: 6
                                            border.color: defaultAudioButton.checked ? "#00d4ff" :
                                                          (defaultAudioButton.hovered ? "#2196F3" : "#334155")
                                            border.width: defaultAudioButton.checked ? 2 : 1

                                            // 顶部青色高亮线（选中状态）
                                            Rectangle {
                                                visible: defaultAudioButton.checked
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: 1
                                                anchors.rightMargin: 1
                                                anchors.topMargin: 1
                                                height: 2
                                                radius: 1
                                                color: "#00d4ff"
                                            }
                                        }

                                        contentItem: Item {
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 8

                                                // LED状态指示点
                                                Rectangle {
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: defaultAudioButton.checked ? "#00d4ff" : "#475569"

                                                    // 内部高亮
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        anchors.centerIn: parent
                                                        color: defaultAudioButton.checked ? "#7dd3fc" : "#64748B"
                                                    }
                                                }

                                                Text {
                                                    text: defaultAudioButton.text
                                                    font.pixelSize: 13
                                                    font.bold: defaultAudioButton.checked
                                                    color: defaultAudioButton.checked ? "#E0E0E0" : "#9E9E9E"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }

                                        onClicked: {
                                            root.audioSourceMode = "default"
                                            ttsAudioButton.checked = false
                                        }
                                    }

                                    // [TTS] 按钮
                                    Button {
                                        id: ttsAudioButton
                                        text: "TTS"
                                        checkable: true
                                        checked: root.audioSourceMode === "tts"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50

                                        background: Rectangle {
                                            color: ttsAudioButton.checked ? "#0d2218" :
                                                   (ttsAudioButton.hovered ? "#1e2d42" : "#141920")
                                            radius: 6
                                            border.color: ttsAudioButton.checked ? "#22C55E" :
                                                          (ttsAudioButton.hovered ? "#2196F3" : "#334155")
                                            border.width: ttsAudioButton.checked ? 2 : 1

                                            // 顶部绿色高亮线（选中状态）
                                            Rectangle {
                                                visible: ttsAudioButton.checked
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: 1
                                                anchors.rightMargin: 1
                                                anchors.topMargin: 1
                                                height: 2
                                                radius: 1
                                                color: "#22C55E"
                                            }
                                        }

                                        contentItem: Item {
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 8

                                                // LED状态指示点
                                                Rectangle {
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: ttsAudioButton.checked ? "#22C55E" : "#475569"

                                                    // 内部高亮
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        anchors.centerIn: parent
                                                        color: ttsAudioButton.checked ? "#86EFAC" : "#64748B"
                                                    }
                                                }

                                                Text {
                                                    text: ttsAudioButton.text
                                                    font.pixelSize: 13
                                                    font.bold: ttsAudioButton.checked
                                                    color: ttsAudioButton.checked ? "#E0E0E0" : "#9E9E9E"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }

                                        onClicked: {
                                            root.audioSourceMode = "tts"
                                            defaultAudioButton.checked = false
                                        }
                                    }
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引5改为TTS文字
                            // 参数索引: 5 - TTS文字（右列，行2）
                            Text {
                                text: "TTS文字:"
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
                                implicitHeight: ttsTextField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: ttsTextField
                                    placeholderText: "输入报警文字内容..."
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

                            // ========== 第四行：通道编号（左）、语音报警（右）==========
                            // 参数索引: 6 - 通道编号（左列，行3）
                            Text {
                                text: "通道编号:"
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
                                implicitHeight: channelSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: channelSpin
                                    from: 0
                                    to: 7
                                    editable: true
                                    anchors.fill: parent
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引7改为音频文件
                            // 参数索引: 7 - 音频文件（右列，行3）
                            Text {
                                text: "音频文件:"
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
                                implicitHeight: audioField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: audioField
                                    placeholderText: "音频文件路径（只读）"
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    readOnly: true
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

                            // ========== 第五行：上限值（左）、TTS文字（右）==========
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
                                    from: 0
                                    to: 10000
                                    value: 100
                                    stepSize: 10
                                    editable: true
                                    anchors.fill: parent
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引9改为保护延时
                            // 参数索引: 9 - 保护延时（右列，行4）
                            Text {
                                text: "保护延时(秒):"
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
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 9) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ========== 第五行：下限值（左）、量程（右）==========
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
                                    from: 0
                                    to: 10000
                                    value: 0
                                    stepSize: 10
                                    editable: true
                                    anchors.fill: parent
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 新增参数索引11 - 数据超时
                            // 参数索引: 11 - 数据超时（右列，行5）
                            Text {
                                text: "数据超时(秒):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 5
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 5
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: dataTimeoutSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: dataTimeoutSpin
                                    from: 1
                                    to: 600
                                    value: 30
                                    stepSize: 1
                                    editable: true
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

                            // ========== 第六行：单位（左）、量程（右）==========
                            // 参数索引: 12 - 单位（左列，行6）
                            Text {
                                text: "单位:"
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
                                implicitHeight: unitCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: unitCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["m/s", "T", "℃", "kW", "A", "V", "MPa", "%"]
                                    editable: true
                                    currentIndex: 0
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 参数索引13改为连接超时
                            // 参数索引: 13 - 连接超时（右列，行6）
                            Text {
                                text: "连接超时(秒):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 6
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 6
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: connectionTimeoutSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: connectionTimeoutSpin
                                    from: 1
                                    to: 600
                                    value: 60
                                    stepSize: 1
                                    editable: true
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
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

                            // ✅ 2026-03-05 [Phase 7.48.6]: 新增 Row 7 - 量程和播放方式
                            // ========== 第七行：量程（左）、播放方式（右）==========
                            // 参数索引: 14 - 量程（左列，行7）
                            Text {
                                text: "量程:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 7
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 7
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: rangeSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: rangeSpin
                                    from: 1
                                    to: 10000
                                    value: 100
                                    stepSize: 10
                                    editable: true
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 14) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 14) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 15 - 播放方式（右列，行7）
                            Text {
                                text: "播放方式:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 7
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 7
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: 48

                                // 播放方式切换按钮行
                                RowLayout {
                                    id: playModeButtonGroup
                                    anchors.fill: parent
                                    spacing: 8

                                    // ✅ 2026-03-05 [Phase 7.48.6]: Cyberpunk 工业风（与开关量一致）
                                    // 选中按次数: 深蓝背景 + 青色边框 + 顶部青色高亮线 + LED点
                                    // 选中按时长: 深橙背景 + 橙色边框 + 顶部橙色高亮线 + LED点
                                    // 未选中: 深灰背景 + 板岩边框 + 灰色LED点

                                    // [按次数] 按钮
                                    Button {
                                        id: playByCountButton
                                        text: "按次数"
                                        checkable: true
                                        checked: root.playModeSelection === "count"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50

                                        background: Rectangle {
                                            color: playByCountButton.checked ? "#0a1929" :
                                                   (playByCountButton.hovered ? "#1e2d42" : "#141920")
                                            radius: 6
                                            border.color: playByCountButton.checked ? "#00d4ff" :
                                                          (playByCountButton.hovered ? "#2196F3" : "#334155")
                                            border.width: playByCountButton.checked ? 2 : 1

                                            // 顶部青色高亮线（选中状态）
                                            Rectangle {
                                                visible: playByCountButton.checked
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: 1
                                                anchors.rightMargin: 1
                                                anchors.topMargin: 1
                                                height: 2
                                                radius: 1
                                                color: "#00d4ff"
                                            }
                                        }

                                        contentItem: Item {
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 8

                                                // LED状态指示点
                                                Rectangle {
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: playByCountButton.checked ? "#00d4ff" : "#475569"

                                                    // 内部高亮
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        anchors.centerIn: parent
                                                        color: playByCountButton.checked ? "#7DD3FC" : "#64748B"
                                                    }
                                                }

                                                Text {
                                                    text: playByCountButton.text
                                                    font.pixelSize: 13
                                                    font.bold: playByCountButton.checked
                                                    color: playByCountButton.checked ? "#E0E0E0" : "#9E9E9E"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }

                                        onClicked: {
                                            root.playModeSelection = "count"
                                            playByDurationButton.checked = false
                                        }
                                    }

                                    // [按时长] 按钮
                                    Button {
                                        id: playByDurationButton
                                        text: "按时长"
                                        checkable: true
                                        checked: root.playModeSelection === "duration"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50

                                        background: Rectangle {
                                            color: playByDurationButton.checked ? "#1b1500" :
                                                   (playByDurationButton.hovered ? "#1e2d42" : "#141920")
                                            radius: 6
                                            border.color: playByDurationButton.checked ? "#F59E0B" :
                                                          (playByDurationButton.hovered ? "#2196F3" : "#334155")
                                            border.width: playByDurationButton.checked ? 2 : 1

                                            // 顶部橙色高亮线（选中状态）
                                            Rectangle {
                                                visible: playByDurationButton.checked
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: 1
                                                anchors.rightMargin: 1
                                                anchors.topMargin: 1
                                                height: 2
                                                radius: 1
                                                color: "#F59E0B"
                                            }
                                        }

                                        contentItem: Item {
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 8

                                                // LED状态指示点
                                                Rectangle {
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: playByDurationButton.checked ? "#F59E0B" : "#475569"

                                                    // 内部高亮
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        anchors.centerIn: parent
                                                        color: playByDurationButton.checked ? "#FDE68A" : "#64748B"
                                                    }
                                                }

                                                Text {
                                                    text: playByDurationButton.text
                                                    font.pixelSize: 13
                                                    font.bold: playByDurationButton.checked
                                                    color: playByDurationButton.checked ? "#E0E0E0" : "#9E9E9E"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }

                                        onClicked: {
                                            root.playModeSelection = "duration"
                                            playByCountButton.checked = false
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 15) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 15) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ✅ 2026-03-05 [Phase 7.48.6]: 新增 Row 8 - 输入类型和保护级别
                            // ========== 第八行：输入类型（左）、保护级别（右）==========
                            // 参数索引: 16 - 输入类型（左列，行8）
                            Text {
                                text: "输入类型:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 8
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 8
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: inputTypeCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: inputTypeCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["4-20mA电流型", "0-20mA电流型", "0-5V电压型", "0-10V电压型", "1-5V电压型"]
                                    currentIndex: 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 16) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 16) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 17 - 保护级别（右列，行8）
                            Text {
                                text: "保护级别:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 8
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 8
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: protectionLevelCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: protectionLevelCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["预警+紧急停车", "预警+正常停车", "仅预警", "不处理"]
                                    currentIndex: 1
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 17) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 17) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ✅ 2026-03-05 [Phase 7.48.10]: 新增 Row 9 - 检测模式和启动延时（仅速度保护可见）

                            // 参数索引: 18 - 检测模式（左列，行9）
                            Text {
                                text: "检测模式:"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 9
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                                visible: root.isSpeedProtection
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 9
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: speedDetectModeCombo.implicitHeight
                                visible: root.isSpeedProtection

                                DeviceInfo.CustomComboBox {
                                    id: speedDetectModeCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager
                                    model: ["上下限比较", "额定速度百分比"]
                                    currentIndex: root.speedDetectMode === "percent" ? 1 : 0
                                    onCurrentIndexChanged: {
                                        root.speedDetectMode = (currentIndex === 1) ? "percent" : "limit"
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 18) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 18) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 19 - 启动延时（右列，行9）
                            Text {
                                text: "启动延时(秒):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 9
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                                visible: root.isSpeedProtection
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 9
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: speedStartDelaySpin.implicitHeight
                                visible: root.isSpeedProtection

                                SpinBox {
                                    id: speedStartDelaySpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 300
                                    value: root.speedStartDelay
                                    editable: true
                                    font.pixelSize: 18
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 19) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 19) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // ✅ 2026-03-05 [Phase 7.48.10]: 新增 Row 10 - 额定速度和打滑延时（仅速度保护+百分比模式可见）

                            // 参数索引: 20 - 额定速度（左列，行10）
                            Text {
                                text: "额定速度(m/s):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 0
                                Layout.row: 10
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                                visible: root.isSpeedProtection && root.speedDetectMode === "percent"
                            }

                            Item {
                                Layout.column: 1
                                Layout.row: 10
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: ratedSpeedSpin.implicitHeight
                                visible: root.isSpeedProtection && root.speedDetectMode === "percent"

                                SpinBox {
                                    id: ratedSpeedSpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 1000
                                    value: root.ratedSpeed * 10
                                    editable: true
                                    font.pixelSize: 18

                                    property int decimals: 1
                                    property real realValue: value / 10
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 20) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 20) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                            // 参数索引: 21 - 打滑延时（右列，行10）
                            Text {
                                text: "打滑延时(秒):"
                                font.pixelSize: 21
                                color: "#9E9E9E"
                                Layout.column: 2
                                Layout.row: 10
                                Layout.preferredWidth: 160
                                horizontalAlignment: Text.AlignRight
                                visible: root.isSpeedProtection && root.speedDetectMode === "percent"
                            }

                            Item {
                                Layout.column: 3
                                Layout.row: 10
                                Layout.fillWidth: true
                                Layout.maximumWidth: 300
                                implicitHeight: slipDelaySpin.implicitHeight
                                visible: root.isSpeedProtection && root.speedDetectMode === "percent"

                                SpinBox {
                                    id: slipDelaySpin
                                    anchors.fill: parent
                                    from: 1
                                    to: 120
                                    value: root.slipDelay
                                    editable: true
                                    font.pixelSize: 18
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 21) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 21) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }

                        }  // GridLayout 结束
                    }
                }

                // ✅ 2026-03-05 [Phase 7.48.6]: 新增只读区域 - AD值、工程量、状态LED
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "transparent"
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        // 左侧：AD值和工程量显示
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // AD值
                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "AD值:"
                                    font.pixelSize: 14
                                    color: "#9E9E9E"
                                    Layout.preferredWidth: 60
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    color: "#1a1a1a"
                                    border.color: "#555555"
                                    border.width: 1
                                    radius: 3

                                    Text {
                                        id: adValueText
                                        anchors.centerIn: parent
                                        text: "0"
                                        font.pixelSize: 13
                                        color: "#00d4ff"
                                    }
                                }
                            }

                            // 工程量
                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "工程量:"
                                    font.pixelSize: 14
                                    color: "#9E9E9E"
                                    Layout.preferredWidth: 60
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    color: "#1a1a1a"
                                    border.color: "#555555"
                                    border.width: 1
                                    radius: 3

                                    Text {
                                        id: engineeringValueText
                                        anchors.centerIn: parent
                                        text: "0.00 m/s"
                                        font.pixelSize: 13
                                        color: "#4CAF50"
                                    }
                                }
                            }
                        }

                        // 右侧：状态LED
                        ColumnLayout {
                            Layout.preferredWidth: 150
                            spacing: 8

                            // MQTT服务状态
                            RowLayout {
                                spacing: 8

                                // ✅ 2026-03-05 [Phase 7.48.6]: 双层 LED（与开关量一致）
                                Item {
                                    width: 34
                                    height: 34

                                    Rectangle {
                                        id: mqttStatusLed
                                        anchors.centerIn: parent
                                        width: 34
                                        height: 34
                                        radius: 17
                                        color: "#4CAF50"  // 绿色=在线
                                        border.color: "#2E7D32"
                                        border.width: 2

                                        // 内部高亮
                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            anchors.centerIn: parent
                                            color: "#81C784"
                                        }
                                    }
                                }

                                Text {
                                    text: "MQTT在线"
                                    font.pixelSize: 12
                                    color: "#9E9E9E"
                                }
                            }

                            // 模块状态
                            RowLayout {
                                spacing: 8

                                // ✅ 2026-03-05 [Phase 7.48.6]: 双层 LED（与开关量一致）
                                Item {
                                    width: 34
                                    height: 34

                                    Rectangle {
                                        id: moduleStatusLed
                                        anchors.centerIn: parent
                                        width: 34
                                        height: 34
                                        radius: 17
                                        color: "#4CAF50"  // 绿色=在线
                                        border.color: "#2E7D32"
                                        border.width: 2

                                        // 内部高亮
                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            anchors.centerIn: parent
                                            color: "#81C784"
                                        }
                                    }
                                }

                                Text {
                                    text: "模块在线"
                                    font.pixelSize: 12
                                    color: "#9E9E9E"
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#00d4ff"
                    opacity: 0.3
                }

                // 底部按钮
                // ✅ 2026-01-30 [FIX 100.300.105]: 添加焦点指示器
                // ✅ 2026-03-05 [Phase 7.48.6]: 简化为2按钮布局（与开关量一致）
                //    新布局：单行（添加保护项 | 删除保护项）
                //    保存/重置已由顶部按钮统一代理
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // 添加保护项按钮（索引 0）
                    Button {
                        id: addProtectionButton
                        text: "添加保护项"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 2
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? 3 : 0
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
                            console.log("添加保护项（模拟量）")
                            // TODO: 实现添加保护项功能
                        }
                    }

                    // 删除保护项按钮（索引 1）
                    Button {
                        id: deleteProtectionButton
                        text: "删除保护项"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#8e44ad" : (parent.hovered ? "#9b59b6" : "#8e44ad")
                            radius: 2
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? 3 : 0
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
                            console.log("删除保护项:", nameField.text)
                            // TODO: 实现删除保护项功能
                        }
                    }
                }

                    // ❌ 2026-03-03 [Phase 7.47.77]: 以下原保存/删除/重置按钮已注释
                    // 保存/重置由顶部统一代理；删除已改名为"删除保护项"（index=2）
                    /*
                    // 保存按钮（索引 0）
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 0) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                        Button {
                            anchors.fill: parent
                            text: "保存"
                            background: Rectangle { color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60"); radius: 2 }
                            contentItem: Text { text: parent.text; font.pixelSize: 13; font.bold: true; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: { saveProtectionData() }
                        }
                    }

                    // 删除按钮（索引 1）
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 1) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                        Button {
                            anchors.fill: parent
                            text: "删除"
                            background: Rectangle { color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400"); radius: 2 }
                            contentItem: Text { text: parent.text; font.pixelSize: 13; font.bold: true; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: { console.log("删除保护:", nameField.text) }
                        }
                    }

                    // 重置按钮（索引 2）
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (root.focusSubArea === 3 && root.focusButtonIndex === 2) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 3 && root.focusButtonIndex === 2) ? 3 : 0
                            radius: 4
                            z: 10
                        }
                        Button {
                            anchors.fill: parent
                            text: "重置"
                            background: Rectangle { color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d"); radius: 2 }
                            contentItem: Text { text: parent.text; font.pixelSize: 13; font.bold: true; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: { loadProtectionData(root.currentProtectionIndex) }
                        }
                    }
                    */
            }
        }
    }

    // ========== 辅助函数 ==========

    // 加载保护数据到右侧编辑区域
    // ✅ 2026-03-05 [Phase 7.48.6]: 更新以支持新增字段
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
            channelSpin.value = protection.channel_number || protection.register_address

            // ✅ 2026-01-27 [FIX 100.300.31]: 加载上限值、下限值、量程、单位
            upperLimitSpin.value = protection.upper_limit || 100
            lowerLimitSpin.value = protection.lower_limit || 0
            rangeSpin.value = protection.range || 100
            unitCombo.currentIndex = unitCombo.model.indexOf(protection.unit || item.unit)

            // 基本参数
            delaySpin.value = protection.protection_delay * 10  // 转换为整数（0.1秒精度）
            playCountSpin.value = protection.play_count
            durationSpin.value = protection.play_duration * 10  // 转换为整数（0.1秒精度）
            ttsTextField.text = protection.tts_text || (item.name + "保护报警")
            audioField.text = protection.audio_file || ""

            // ✅ 2026-03-05 [Phase 7.48.6]: 加载新增字段
            root.audioSourceMode = protection.audio_source_mode || "tts"
            defaultAudioButton.checked = (root.audioSourceMode === "default")
            ttsAudioButton.checked = (root.audioSourceMode === "tts")

            root.playModeSelection = protection.play_mode || "count"
            playByCountButton.checked = (root.playModeSelection === "count")
            playByDurationButton.checked = (root.playModeSelection === "duration")

            root.protectionLevel = protection.protection_level || 1
            protectionLevelCombo.currentIndex = root.protectionLevel

            root.inputType = protection.input_type || "4-20mA"
            var inputTypeIndex = inputTypeCombo.model.indexOf(root.inputType + "电流型")
            if (inputTypeIndex < 0) inputTypeIndex = inputTypeCombo.model.indexOf(root.inputType + "电压型")
            if (inputTypeIndex < 0) inputTypeIndex = 0
            inputTypeCombo.currentIndex = inputTypeIndex

            dataTimeoutSpin.value = protection.data_timeout || 30
            connectionTimeoutSpin.value = protection.connection_timeout || 60

            // ✅ 2026-03-05 [Phase 7.48.10]: 加载速度保护专用字段
            if (item.name === "速度") {
                root.speedStartDelay = protection.speed_start_delay || 0.0
                speedStartDelaySpin.value = root.speedStartDelay
                root.speedDetectMode = protection.speed_detect_mode || "limit"
                speedDetectModeCombo.currentIndex = (root.speedDetectMode === "percent") ? 1 : 0
                root.ratedSpeed = protection.rated_speed || 0.0
                ratedSpeedSpin.value = root.ratedSpeed * 10
                root.slipDelay = protection.slip_delay || 10.0
                slipDelaySpin.value = root.slipDelay
            }

            console.log("✅ [AnalogInputPage] 从数据库加载完整参数:", item.name)
        } else {
            // 数据库中没有，使用ListModel中的基本数据
            nameField.text = item.name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(item.moduleType)
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
            ttsTextField.text = item.name + "保护报警"
            audioField.text = ""

            // ✅ 2026-03-05 [Phase 7.48.6]: 新增字段默认值
            root.audioSourceMode = "tts"
            defaultAudioButton.checked = false
            ttsAudioButton.checked = true

            root.playModeSelection = "count"
            playByCountButton.checked = true
            playByDurationButton.checked = false

            root.protectionLevel = 1
            protectionLevelCombo.currentIndex = 1

            root.inputType = "4-20mA"
            inputTypeCombo.currentIndex = 0

            dataTimeoutSpin.value = 30
            connectionTimeoutSpin.value = 60

            // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护专用字段默认值
            if (item.name === "速度") {
                root.speedStartDelay = 30.0
                speedStartDelaySpin.value = 30
                root.speedDetectMode = "limit"
                speedDetectModeCombo.currentIndex = 0
                root.ratedSpeed = 2.5
                ratedSpeedSpin.value = 25
                root.slipDelay = 10.0
                slipDelaySpin.value = 10
            }

            console.log("⚠️ [AnalogInputPage] 数据库中没有详细参数，使用默认值:", item.name)
        }
    }

    // 保存保护数据
    // ✅ 2026-03-05 [Phase 7.48.6]: 更新以支持新增字段
    function saveProtectionData() {
        if (root.currentProtectionIndex < 0 || root.currentProtectionIndex >= analogProtectionModel.count) {
            return
        }

        // 更新ListModel
        analogProtectionModel.setProperty(root.currentProtectionIndex, "name", nameField.text)
        analogProtectionModel.setProperty(root.currentProtectionIndex, "moduleType", moduleTypeCombo.currentText)
        analogProtectionModel.setProperty(root.currentProtectionIndex, "registerAddress", channelSpin.value)
        // ✅ 2026-01-27 [FIX 100.300.31]: 更新单位到 ListModel
        analogProtectionModel.setProperty(root.currentProtectionIndex, "unit", unitCombo.editable ? unitCombo.editText : unitCombo.displayText)

        console.log("✅ 保存保护数据到内存:", nameField.text)

        // ✅ 2026-01-25 [数据库集成] 保存到数据库
        var protection = {
            "protection_name": nameField.text,
            "module_type": moduleTypeCombo.currentText,
            "register_address": channelSpin.value,
            "channel_number": channelSpin.value,
            // ✅ 2026-01-27 [FIX 100.300.31]: 保存上限值、下限值、量程、单位
            "upper_limit": upperLimitSpin.value,
            "lower_limit": lowerLimitSpin.value,
            "range": rangeSpin.value,
            "unit": unitCombo.editable ? unitCombo.editText : unitCombo.displayText,
            "protection_delay": delaySpin.realValue,
            "play_count": playCountSpin.value,
            "play_duration": durationSpin.realValue,
            "tts_text": ttsTextField.text,
            "audio_file": audioField.text,
            // ✅ 2026-03-05 [Phase 7.48.6]: 保存新增字段
            "audio_source_mode": root.audioSourceMode,
            "play_mode": root.playModeSelection,
            "protection_level": root.protectionLevel,
            "input_type": root.inputType,
            "data_timeout": dataTimeoutSpin.value,
            "connection_timeout": connectionTimeoutSpin.value
        }

        // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护专用字段
        if (root.isSpeedProtection) {
            protection["speed_start_delay"] = speedStartDelaySpin.value
            protection["speed_detect_mode"] = root.speedDetectMode
            protection["rated_speed"] = ratedSpeedSpin.realValue
            protection["slip_delay"] = slipDelaySpin.value
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

    // ========== 导航函数 ==========
    // ✅ 2026-01-30 [FIX 100.300.105]: 添加导航系统函数

    // 返回参数区域的字段数量
    function getParamFieldCount() {
        // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护时返回22（18+4个速度专用参数），其他保护返回18
        return root.isSpeedProtection ? 22 : 18
        // ❌ 2026-03-05 [Phase 7.48.6]: 旧值 18（9行布局）已废弃
    }

    // 触发参数输入（打开虚拟键盘）
    // ✅ 2026-03-05 [Phase 7.48.6]: 更新为18参数布局
    function triggerParamInput(paramIndex) {
        console.log("✅ [AnalogInputPage] 触发参数输入 - 索引:", paramIndex)

        var inputField = null
        var inputMode = "numeric"  // 默认数字模式

        switch(paramIndex) {
        case 0:  // 保护名称
            inputField = nameField
            inputMode = "chinese"
            break
        case 1:  // 播放次数
            inputField = playCountSpin
            inputMode = "numeric"
            break
        case 2:  // 模块类型
            inputField = moduleTypeCombo
            inputMode = "english"
            break
        case 3:  // 播放时长
            inputField = durationSpin
            inputMode = "numeric"
            break
        case 4:  // 音频来源（按钮组，切换选中状态）
            if (root.audioSourceMode === "default") {
                root.audioSourceMode = "tts"
                ttsAudioButton.checked = true
                defaultAudioButton.checked = false
            } else {
                root.audioSourceMode = "default"
                defaultAudioButton.checked = true
                ttsAudioButton.checked = false
            }
            console.log("✅ [AnalogInputPage] 切换音频来源:", root.audioSourceMode)
            return  // 按钮组不需要打开虚拟键盘
        case 5:  // TTS文字
            inputField = ttsTextField
            inputMode = "chinese"
            break
        case 6:  // 通道编号
            inputField = channelSpin
            inputMode = "numeric"
            break
        case 7:  // 音频文件
            inputField = audioField
            inputMode = "english"
            break
        case 8:  // 上限值
            inputField = upperLimitSpin
            inputMode = "numeric"
            break
        case 9:  // 保护延时
            inputField = delaySpin
            inputMode = "numeric"
            break
        case 10:  // 下限值
            inputField = lowerLimitSpin
            inputMode = "numeric"
            break
        case 11:  // 数据超时
            inputField = dataTimeoutSpin
            inputMode = "numeric"
            break
        case 12:  // 单位
            inputField = unitCombo
            inputMode = "english"
            break
        case 13:  // 连接超时
            inputField = connectionTimeoutSpin
            inputMode = "numeric"
            break
        case 14:  // 量程
            inputField = rangeSpin
            inputMode = "numeric"
            break
        case 15:  // 播放方式（按钮组，切换选中状态）
            if (root.playModeSelection === "count") {
                root.playModeSelection = "duration"
                playByDurationButton.checked = true
                playByCountButton.checked = false
            } else {
                root.playModeSelection = "count"
                playByCountButton.checked = true
                playByDurationButton.checked = false
            }
            console.log("✅ [AnalogInputPage] 切换播放方式:", root.playModeSelection)
            return  // 按钮组不需要打开虚拟键盘
        case 16:  // 输入类型
            inputField = inputTypeCombo
            inputMode = "english"
            break
        case 17:  // 保护级别
            inputField = protectionLevelCombo
            inputMode = "english"
            break
        // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护专用参数（case 18-21）
        case 18:  // 检测模式（ComboBox切换）
            inputField = speedDetectModeCombo
            inputMode = "english"
            break
        case 19:  // 启动延时
            inputField = speedStartDelaySpin
            inputMode = "numeric"
            break
        case 20:  // 额定速度
            inputField = ratedSpeedSpin
            inputMode = "numeric"
            break
        case 21:  // 打滑延时
            inputField = slipDelaySpin
            inputMode = "numeric"
            break
        default:
            console.warn("⚠️ [AnalogInputPage] 未知的参数索引:", paramIndex)
            return
        }

        // 打开虚拟键盘
        if (virtualKeyboard && inputField) {
            console.log("✅ [AnalogInputPage] 打开 Qt 虚拟键盘 - 控件:", inputField, "模式:", inputMode)
            virtualKeyboard.openForField(inputField, function(newValue) {
                console.log("✅ [AnalogInputPage] 虚拟键盘输入完成:", newValue)
            }, inputMode, root)
        } else {
            console.warn("⚠️ [AnalogInputPage] 虚拟键盘或输入控件不可用")
        }
    }

    // 触发底部按钮
    // ✅ 2026-03-05 [Phase 7.48.6]: 更新为2按钮布局
    function triggerButton(buttonIndex) {
        console.log("✅ [AnalogInputPage] 触发底部按钮 - 索引:", buttonIndex)

        switch(buttonIndex) {
        case 0:  // 添加保护项
            console.log("✅ [AnalogInputPage] 触发：添加保护项")
            // TODO: 实现添加保护项功能
            break
        case 1:  // 删除保护项
            console.log("✅ [AnalogInputPage] 触发：删除保护项")
            console.log("删除保护:", nameField.text)
            // TODO: 实现删除功能
            break
        default:
            console.warn("⚠️ [AnalogInputPage] 未知的按钮索引:", buttonIndex)
            break
        }
    }
}
