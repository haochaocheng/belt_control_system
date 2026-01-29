import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-25 [开关量输入页面] 左右分栏布局：左侧列表 + 右侧参数编辑
// ✅ 2026-01-28 [FIX 100.300.79]: 替换所有原生输入组件为自定义组件
// ✅ 2026-01-28 [虚拟键盘集成]: 接收并传递键盘管理器
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
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性
    property var keyboardManager: null
    // ✅ 2026-01-28 [FIX 100.300.101]: 导航焦点索引（从父对话框传递）
    property int focusItemIndex: -1  // -1 表示无焦点
    // ✅ 2026-01-28 [FIX 100.300.101]: 导航子区域（0:列表 1:参数）
    property int focusSubArea: 0  // 0:列表区域 1:参数区域
    property int focusParamIndex: 0  // 参数区域焦点索引

    // ========== 开关量保护模型 ==========
    ListModel {
        id: digitalProtectionModel
        ListElement { name: "急停"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 0 }
        ListElement { name: "跑偏"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 1 }
        ListElement { name: "撕裂"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 2 }
        ListElement { name: "烟雾"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 3 }
        ListElement { name: "温度"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 4 }
        ListElement { name: "护网"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 5 }
        ListElement { name: "堆煤"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 6 }
        ListElement { name: "主机急停"; active: false; moduleType: "输入模块1"; registerAddress: 2; channelNumber: 7 }
    }

    // ✅ 2026-01-28 [FIX 100.300.101]: 参数字段模型（动态管理，便于添加/删除参数）
    ListModel {
        id: paramFieldsModel
        // 字段定义：label=标签文本, type=组件类型(text/combo/spin), componentId=组件ID
        ListElement { label: "保护名称:"; type: "text"; componentId: "nameField" }
        ListElement { label: "模块类型:"; type: "combo"; componentId: "moduleTypeCombo" }
        ListElement { label: "寄存器地址:"; type: "spin"; componentId: "registerAddressSpin" }
        ListElement { label: "通道编号:"; type: "spin"; componentId: "channelSpin" }
        ListElement { label: "保护延时(秒):"; type: "spin"; componentId: "delaySpin" }
        ListElement { label: "保护动作:"; type: "combo"; componentId: "actionCombo" }
        ListElement { label: "报警级别:"; type: "combo"; componentId: "alarmLevelCombo" }
        ListElement { label: "是否启用:"; type: "switch"; componentId: "enabledSwitch" }
        ListElement { label: "备注:"; type: "text"; componentId: "remarkField" }
    }

    // ========== 主布局：左右分栏 ==========
    RowLayout {
        anchors.fill: parent
        // ✅ 2026-01-26 [FIX 100.300.25.25]: 移除 spacing，让标题贴近列表
        spacing: 0

        // ========== 左侧：开关量列表 ==========
        // ✅ 2026-01-26 [FIX 100.300.22]: 统一为电机控制的主题风格
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 240
            // ✅ 2026-01-26 [FIX 100.300.25.28]: 改为透明，使用 33.png 作为整体背景
            color: "transparent"
            // ✅ 2026-01-26 [FIX 100.300.25.18]: 添加 clip 防止背景色超出弹窗底部
            clip: true

            // ✅ 2026-01-26 [FIX 100.300.25.28]: 添加整体背景图片 33.png
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
                    // ✅ 2026-01-26 [FIX 100.300.25.28]: 改为透明，显示背景图片
                    color: "transparent"
                    border.color: "transparent"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: "开关量列表"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                    }
                }

                // 开关量列表
                ListView {
                    id: protectionListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: digitalProtectionModel
                    spacing: 0
                    currentIndex: root.currentProtectionIndex

                    delegate: Rectangle {
                        width: protectionListView.width
                        // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整高度，使二级标题比一级标题小
                        height: 45  // 从 60 改为 45（一级标题是 40）
                        color: "transparent"

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.8]: 使用中间属性减少绑定计算
                        // 只计算一次，其他绑定引用这个属性，避免重复计算
                        readonly property bool isFocused: (root.focusSubArea === 0 && root.focusItemIndex === index)

                        // ✅ 2026-01-28 [FIX 100.300.101]: 添加焦点指示器边框（只在列表区域显示）
                        border.color: isFocused ? "#2196F3" : "transparent"
                        border.width: isFocused ? 3 : 0

                        // ✅ 2026-01-26 [FIX 100.300.25]: 添加背景图片
                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.16]: 临时移除 states，使用简单绑定测试
                        Image {
                            id: backgroundImage
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1  // 放在最底层

                            // 使用相对路径，便于QDS预览（向上三级到qml目录）
                            source: isFocused ? "../../../images/bhNameBK1.png" : "../../../images/bhNameBK.png"

                            // // ✅ 2026-01-26 [FIX 100.300.25.2]: 改用states方式，使用相对路径便于QDS预览
                            // states: [
                            //     State {
                            //         name: "focused"
                            //         when: isFocused
                            //         PropertyChanges {
                            //             target: backgroundImage
                            //             source: "../../../images/bhNameBK1.png"
                            //         }
                            //     },
                            //     State {
                            //         name: "normal"
                            //         when: !isFocused
                            //         PropertyChanges {
                            //             target: backgroundImage
                            //             source: "../../../images/bhNameBK.png"
                            //         }
                            //     }
                            // ]
                        }

                        // ✅ 左侧激活指示条
                        // ✅ 2026-01-28 [FIX 100.300.101]: 响应焦点变化（只在列表区域显示）
                        Rectangle {
                            visible: isFocused
                            width: 4
                            height: parent.height
                            color: "#2196F3"
                            anchors.left: parent.left
                        }

                        // ✅ 2026-01-26 [FIX 100.300.25.4]: 开关量名称居中显示
                        // ✅ 2026-01-28 [FIX 100.300.101]: 响应焦点变化（只在列表区域显示）
                        Text {
                            text: model.name
                            // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整字体，使二级标题比一级标题小
                            font.pixelSize: 14  // 从 16 改为 14（与一级标题相同）
                            font.weight: isFocused ? Font.Bold : Font.Normal
                            color: isFocused ? "#E0E0E0" : "#9E9E9E"
                            anchors.centerIn: parent
                        }

                        // ✅ 2026-01-26 [FIX 100.300.25.4]: 状态指示放在最右侧
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

            // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加调试输出
            Component.onCompleted: {
                console.log("✅ [DEBUG] SwitchInputPage 右侧区域宽度:", width)
                console.log("✅ [DEBUG] SwitchInputPage 右侧区域高度:", height)
            }

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

                    // ✅ 2026-01-26 [FIX 100.300.25.9]: 添加调试输出
                    Component.onCompleted: {
                        console.log("✅ [DEBUG] SwitchInputPage ScrollView 宽度:", width)
                        console.log("✅ [DEBUG] SwitchInputPage ScrollView 高度:", height)
                    }

                    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.24.3]: 修复 GridLayout 宽度问题 - 使用 width: parent.width - 20
                    GridLayout {
                        width: parent.width - 20  // ✅ 使用固定宽度，而不是 Layout.fillWidth
                        columns: 4  // 4列：标签1、输入框1、标签2、输入框2
                        columnSpacing: 10
                        rowSpacing: 12

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.24.3]: 添加调试日志
                        Component.onCompleted: {
                            console.log("✅ [DEBUG] GridLayout 加载完成")
                            console.log("   宽度:", width, "高度:", height)
                            console.log("   parent.width:", parent.width)
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.24.2]: 保护名称 - 第一行左侧（索引0）
                        Text {
                            text: "保护名称:"
                            font.pixelSize: 21  // ✅ 参考模拟量输入字体大小
                            color: "#9E9E9E"
                            Layout.column: 0
                            Layout.row: 0
                            Layout.preferredWidth: 120  // ✅ 参考模拟量输入标签宽度
                            horizontalAlignment: Text.AlignRight  // ✅ 右对齐
                        }

                        Item {
                            Layout.column: 1
                            Layout.row: 0
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300  // ✅ 参考模拟量输入输入框最大宽度
                            implicitHeight: nameField.implicitHeight

                            DeviceInfo.CustomTextField {
                                id: nameField
                                anchors.fill: parent
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.24.2]: 播放次数 - 第一行右侧（索引1）
                        Text {
                            text: "播放次数:"
                            font.pixelSize: 21  // ✅ 参考模拟量输入字体大小
                            color: "#9E9E9E"
                            Layout.column: 2
                            Layout.row: 0
                            Layout.preferredWidth: 120  // ✅ 参考模拟量输入标签宽度
                            horizontalAlignment: Text.AlignRight  // ✅ 右对齐
                        }

                        Item {
                            Layout.column: 3
                            Layout.row: 0
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300  // ✅ 参考模拟量输入输入框最大宽度
                            implicitHeight: playCountSpin.implicitHeight

                            DeviceInfo.CustomSpinBox {
                                id: playCountSpin
                                anchors.fill: parent
                                from: 1
                                to: 99
                                value: 3
                                editable: true
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }
                    }  // GridLayout 结束

                    // // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.17]: 临时移除 RowLayout，测试是否还卡住
                    // // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.17.1]: 使用块注释注释掉整个 RowLayout 内容
                    /*
                    // 保留原始的完整 RowLayout 代码，以便后续恢复
                    RowLayout {
                        width: parent.width - 20
                        spacing: 20

                        // ✅ 左列：保护名称(0)、模块类型(2)、寄存器地址(4)、通道编号(6)、保护延时(8)
                        ColumnLayout {
                            id: leftColumn
                            Layout.fillWidth: true
                            Layout.preferredWidth: parent.width / 2 - 10
                            spacing: 12

                            // 保护名称
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保护名称:"
                                font.pixelSize: 14
                                color: "#9E9E9E"  // 与电机控制一致：标签灰色
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomTextField
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: nameField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: nameField
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                }

                                // 焦点指示器
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 0) ? 3 : 0
                                    radius: 4
                                    z: 10  // 放在输入框前面
                                }
                            }
                        }

                        // 模块类型
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "模块类型:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomComboBox
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: moduleTypeCombo.implicitHeight

                                DeviceInfo.CustomComboBox {
                                    id: moduleTypeCombo
                                    anchors.fill: parent
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器

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

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 1 改为 2（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }

                        // 寄存器地址
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: moduleTypeCombo.currentText !== "主模块"

                            Text {
                                text: "寄存器地址:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomSpinBox
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: registerAddressSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: registerAddressSpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 255
                                    editable: true
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 2 改为 4（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }

                        // 通道编号
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "通道编号:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomSpinBox
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: channelSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: channelSpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 7
                                    editable: true
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 3 改为 6（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 6) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#3d4556"
                            opacity: 0.2
                        }

                        // 保护延时
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保护延时(秒):"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomSpinBox
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: delaySpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: delaySpin
                                    anchors.fill: parent
                                    from: 0
                                    to: 600
                                    value: 10
                                    stepSize: 1
                                    editable: true
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器

                                    property int decimals: 1
                                    property real realValue: value / 10

                                    textFromValue: function(value, locale) {
                                        return Number(value / 10).toLocaleString(locale, 'f', 1)
                                    }

                                    valueFromText: function(text, locale) {
                                        return Number.fromLocaleString(locale, text) * 10
                                    }
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 4 改为 8（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 8) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }
                    }  // 左列结束

                    // ✅ 右列：播放次数(1)、播放时长(3)、TTS文字(5)、音频文件(7)
                    ColumnLayout {
                        id: rightColumn
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width / 2 - 10
                        spacing: 12

                        // 播放次数
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "播放次数:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomSpinBox
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: playCountSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: playCountSpin
                                    anchors.fill: parent
                                    from: 1
                                    to: 99
                                    value: 3
                                    editable: true
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 5 改为 1（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 1) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }

                        // 播放时长
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "播放时长(秒):"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomSpinBox
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: durationSpin.implicitHeight

                                DeviceInfo.CustomSpinBox {
                                    id: durationSpin
                                    anchors.fill: parent
                                    from: 1
                                    to: 600
                                    value: 50
                                    stepSize: 5
                                    editable: true
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器

                                    property int decimals: 1
                                    property real realValue: value / 10

                                    textFromValue: function(value, locale) {
                                        return Number(value / 10).toLocaleString(locale, 'f', 1)
                                    }

                                    valueFromText: function(text, locale) {
                                        return Number.fromLocaleString(locale, text) * 10
                                    }
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 6 改为 3（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? 3 : 0
                                    radius: 4
                                    z: 10
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
                                font.pixelSize: 14
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
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: ttsRadio.checked

                            Text {
                                text: "报警文字:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomTextField
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: ttsTextField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: ttsTextField
                                    anchors.fill: parent
                                    placeholderText: "输入报警文字内容..."
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 7 改为 5（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 5) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
                            }
                        }

                        // 音频文件选择
                        // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 添加焦点指示器
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: fileRadio.checked

                            Text {
                                text: "音频文件:"
                                font.pixelSize: 14
                                color: "#9E9E9E"
                                Layout.preferredWidth: 100
                            }

                            // ✅ 2026-01-28 [FIX 100.300.79]: 替换为 CustomTextField
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: audioField.implicitHeight

                                DeviceInfo.CustomTextField {
                                    id: audioField
                                    anchors.fill: parent
                                    placeholderText: "选择音频文件..."
                                    keyboardManager: root.keyboardManager  // ✅ 2026-01-28 [虚拟键盘]: 传递键盘管理器
                                    readOnly: true
                                }

                                // 焦点指示器
                                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2]: 索引从 8 改为 7（交叉导航）
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: (root.focusSubArea === 1 && root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                                    border.width: (root.focusSubArea === 1 && root.focusParamIndex === 7) ? 3 : 0
                                    radius: 4
                                    z: 10
                                }
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
                }  // RowLayout 结束
                */
            }  // ScrollView 结束

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
        if (index < 0 || index >= digitalProtectionModel.count) {
            return
        }

        var item = digitalProtectionModel.get(index)

        // ✅ 2026-01-25 [数据库集成] 从数据库加载完整的保护参数
        var protection = deviceConfigMgr.loadDigitalProtection(root.deviceId, item.name)

        if (protection && protection.protection_name) {
            // 从数据库加载完整参数
            nameField.text = protection.protection_name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(protection.module_type)
            registerAddressSpin.value = protection.register_address
            channelSpin.value = protection.channel_number
            delaySpin.value = protection.protection_delay * 10  // 转换为整数（0.1秒精度）
            playCountSpin.value = protection.play_count
            durationSpin.value = protection.play_duration * 10  // 转换为整数（0.1秒精度）
            ttsRadio.checked = protection.use_text_to_speech === 1
            fileRadio.checked = protection.use_text_to_speech === 0
            ttsTextField.text = protection.tts_text || (item.name + "保护报警")
            audioField.text = protection.audio_file || ""

            console.log("✅ [SwitchInputPage] 从数据库加载完整参数:", item.name)
        } else {
            // 数据库中没有，使用ListModel中的基本数据
            nameField.text = item.name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(item.moduleType)
            registerAddressSpin.value = item.registerAddress
            channelSpin.value = item.channelNumber

            // 设置默认值
            delaySpin.value = 10  // 1.0秒
            playCountSpin.value = 3
            durationSpin.value = 50  // 5.0秒
            ttsRadio.checked = true
            ttsTextField.text = item.name + "保护报警"
            audioField.text = ""

            console.log("⚠️ [SwitchInputPage] 数据库中没有详细参数，使用默认值:", item.name)
        }
    }

    // 保存保护数据
    function saveProtectionData() {
        if (root.currentProtectionIndex < 0 || root.currentProtectionIndex >= digitalProtectionModel.count) {
            return
        }

        // 更新ListModel
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "name", nameField.text)
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "moduleType", moduleTypeCombo.currentText)
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "registerAddress", registerAddressSpin.value)
        digitalProtectionModel.setProperty(root.currentProtectionIndex, "channelNumber", channelSpin.value)

        console.log("✅ 保存保护数据到内存:", nameField.text)

        // ✅ 2026-01-25 [数据库集成] 保存到数据库
        var protection = {
            "protection_name": nameField.text,
            "module_type": moduleTypeCombo.currentText,
            "register_address": registerAddressSpin.value,
            "channel_number": channelSpin.value,
            "protection_delay": delaySpin.realValue,
            "play_count": playCountSpin.value,
            "play_duration": durationSpin.realValue,
            "use_text_to_speech": ttsRadio.checked,
            "tts_text": ttsTextField.text,
            "audio_file": audioField.text
        }

        if (deviceConfigMgr.saveDigitalProtection(root.deviceId, protection)) {
            console.log("✅ [SwitchInputPage] 保存到数据库成功:", nameField.text)
        } else {
            console.error("❌ [SwitchInputPage] 保存到数据库失败:", nameField.text)
        }
    }

    // ✅ 2026-01-29 [FIX 100.300.101 Phase 3]: 获取参数字段数量
    function getParamFieldCount() {
        // 返回参数区域的输入组件数量
        // 保护名称、模块类型、寄存器地址、通道编号、保护延时、保护动作、报警级别、是否启用、备注
        return 9
    }

    // 组件加载完成后，加载第一个保护项的数据
    Component.onCompleted: {
        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.15]: 临时禁用 Component.onCompleted，测试是否还卡住
        console.log("✅ [SwitchInputPage] Component.onCompleted 开始")
        Qt.callLater(function() {
            console.log("✅ [SwitchInputPage] Qt.callLater 回调执行 - 事件循环正常")
        })
        console.log("✅ [SwitchInputPage] Component.onCompleted 完成")

        // // ✅ 2026-01-25 [数据库集成] 从数据库加载开关量保护配置
        // console.log("✅ [SwitchInputPage] 开始加载设备", deviceId, "的开关量保护配置")
        //
        // var protections = deviceConfigMgr.loadAllDigitalProtections(deviceId)
        // console.log("✅ [SwitchInputPage] 从数据库加载了", protections.length, "个保护项")
        //
        // if (protections.length > 0) {
        //     // 清空现有模型
        //     digitalProtectionModel.clear()
        //
        //     // 加载数据库中的配置
        //     for (var i = 0; i < protections.length; i++) {
        //         var p = protections[i]
        //         digitalProtectionModel.append({
        //             name: p.protection_name,
        //             active: p.active === 1,
        //             moduleType: p.module_type,
        //             registerAddress: p.register_address,
        //             channelNumber: p.channel_number
        //         })
        //     }
        //
        //     console.log("✅ [SwitchInputPage] 数据库配置加载完成")
        // } else {
        //     console.log("⚠️ [SwitchInputPage] 数据库中没有配置，使用默认配置")
        // }
        //
        // // 加载第一个保护项的详细参数
        // // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.3]: 使用 Qt.callLater 延迟加载，避免访问未初始化的组件
        // if (digitalProtectionModel.count > 0) {
        //     Qt.callLater(function() {
        //         loadProtectionData(0)
        //         console.log("✅ [SwitchInputPage] 延迟加载第一个保护项完成")
        //     })
        // }
    }
}
