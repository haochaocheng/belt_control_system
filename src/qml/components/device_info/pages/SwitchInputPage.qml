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

    // ✅ 2026-01-30 [修复]: 允许接收焦点，以便虚拟键盘关闭后焦点可以返回
    focus: true
    activeFocusOnTab: true

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.9]: 添加返回类别信号
    signal requestReturnToCategory()

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: "1号皮带"
    property int currentProtectionIndex: 0  // 当前选中的保护项索引
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性（已废弃，保留兼容性）
    property var keyboardManager: null
    // ✅ 2026-01-29 [Qt 虚拟键盘]: 父对话框引用（已废弃）
    property var parentDialog: null
    // ✅ 2026-01-29 [Qt 虚拟键盘]: 直接引用虚拟键盘
    property var virtualKeyboard: null
    // ✅ 2026-01-28 [FIX 100.300.101]: 导航焦点索引（从父对话框传递）
    property int focusItemIndex: -1  // -1 表示无焦点
    // ✅ 2026-01-28 [FIX 100.300.101]: 导航子区域（0:列表 1:参数 2:底部按钮）
    property int focusSubArea: 0  // 0:列表区域 1:参数区域 2:底部按钮区域
    property int focusParamIndex: 0  // 参数区域焦点索引
    property int focusButtonIndex: 0  // ✅ 2026-01-29 [Phase 2.30]: 底部按钮区域焦点索引（0-4）
    // ✅ 2026-02-28 [Phase 7.47.44]: 音频来源模式 0=默认 1=TTS合成
    property int audioSourceMode: 0

    // ✅ 2026-01-31 [FIX 100.300.112.8.12]: 监听焦点变化，同步更新 currentProtectionIndex
    // 当焦点在列表区域移动时，同步更新选中项索引
    onFocusItemIndexChanged: {
        if (focusSubArea === 0 && focusItemIndex >= 0 && focusItemIndex < digitalProtectionModel.count) {
            console.log("✅ [SwitchInputPage] focusItemIndex 变化:", focusItemIndex, "→ 更新 currentProtectionIndex")
            currentProtectionIndex = focusItemIndex
            loadProtectionData(focusItemIndex)
        }
    }

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.9]: 添加左键返回类别处理
    Keys.onLeftPressed: function(event) {
        if (focusSubArea === 0) {
            // 在列表区域，按左键返回到左侧类别
            console.log("✅ [SwitchInputPage] 列表区域按左键，请求返回到左侧类别")
            root.requestReturnToCategory()
            event.accepted = true
        }
    }

    // ========== 开关量保护模型 ==========
    ListModel {
        id: digitalProtectionModel
        ListElement { name: "急停"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 0 }
        ListElement { name: "跑偏"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 1 }
        ListElement { name: "撕裂"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 2 }
        ListElement { name: "烟雾"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 3 }
        ListElement { name: "温度"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 4 }
        ListElement { name: "护网"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 5 }
        ListElement { name: "堆煤"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 6 }
        ListElement { name: "主机急停"; active: false; moduleType: "开关量输入模块1"; registerAddress: 2; channelNumber: 7 }
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
                        // ✅ 2026-01-31 [FIX 100.300.112.8.12]: 分离选中状态和焦点状态
                        // 选中状态：只依赖 currentProtectionIndex（焦点离开列表时保持选中）
                        // 焦点状态：依赖 focusSubArea 和 focusItemIndex（焦点离开列表时消失）
                        readonly property bool isSelected: (root.currentProtectionIndex === index)

                        // ✅ 2026-02-28 [Phase 7.47.47]: 从 diDataManager 实时读取对应位状态（响应式绑定）
                        // 当 MQTT DI 模块对应位变化时自动刷新（通过访问 Q_PROPERTY 建立绑定依赖）
                        // Windows 无 MQTT 时 fallback 到 ListModel 的静态 active 值
                        readonly property bool _diIsActive: {
                            if (typeof diDataManager !== 'undefined' && diDataManager !== null) {
                                var moduleIdx = (model.moduleType === "开关量输入模块1") ? 0 : 1
                                var bitIdx = model.channelNumber
                                // 访问 Q_PROPERTY 建立绑定（module1DataChanged/module2DataChanged 触发时刷新）
                                var _dep = (moduleIdx === 0) ? diDataManager.module1Data : diDataManager.module2Data
                                return diDataManager.getBit(moduleIdx, bitIdx)
                            }
                            return model.active  // fallback
                        }

                        // ✅ 2026-01-28 [FIX 100.300.101]: 添加焦点指示器边框（只在列表区域显示）
                        border.color: isFocused ? "#2196F3" : "transparent"
                        border.width: isFocused ? 3 : 0

                        // ✅ 2026-01-26 [FIX 100.300.25]: 添加背景图片
                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.16]: 临时移除 states，使用简单绑定测试
                        // ✅ 2026-01-31 [FIX 100.300.112.8.12]: 背景图片只依赖选中状态，不依赖焦点状态
                        Image {
                            id: backgroundImage
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            z: -1  // 放在最底层

                            // 使用相对路径，便于QDS预览（向上三级到qml目录）
                            source: isSelected ? "../../../images/bhNameBK1.png" : "../../../images/bhNameBK.png"

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
                                color: _diIsActive ? "#F44336" : "#4CAF50"  // 红色激活，绿色正常
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: _diIsActive ? "已激活" : "正常"
                                font.pixelSize: 12
                                color: "#9E9E9E"
                            }
                        }

                        // ✅ 鼠标点击
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // ✅ 2026-02-03 [FIX 100.300.112.8.25.9]: 鼠标点击时同步焦点状态
                                console.log("🔍 [SwitchInputPage] 鼠标点击列表项:", index)
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
                    id: paramScrollView  // ✅ 添加 ID
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

                    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.25]: 修复 GridLayout 宽度 - 使用 ScrollView 的宽度
                    // 原因：GridLayout 的 parent 是 ScrollView 的 contentItem，宽度只有 270
                    // 解决：使用 paramScrollView.width * 0.7 获取正确的宽度
                    GridLayout {
                        width: paramScrollView.width * 0.7  // ✅ 占 ScrollView 宽度的 70%
                        columns: 4  // 4列：标签1、输入框1、标签2、输入框2
                        columnSpacing: 10
                        rowSpacing: 12

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.25]: 添加调试日志
                        Component.onCompleted: {
                            console.log("✅ [DEBUG] GridLayout 加载完成")
                            console.log("   宽度:", width, "高度:", height)
                            console.log("   parent.width:", parent.width)
                            console.log("   paramScrollView.width:", paramScrollView.width)
                            console.log("   计算宽度 (70%):", paramScrollView.width * 0.7)
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

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.26]: 模块类型 - 第二行左侧（索引2）
                        Text {
                            text: "模块类型:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 0
                            Layout.row: 1
                            Layout.preferredWidth: 120
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
                                // ✅ 2026-02-28 [Phase 7.47.44]: 只保留2个模块选项（与实际DI硬件一致）
                                // 旧值：["输入模块1", "输入模块2", "输入模块3", "输入模块4", "输出模块", "主模块"]
                                model: ["开关量输入模块1", "开关量输入模块2"]
                                // ✅ 根据模块自动确定寄存器地址（模块1→寄存器2，模块2→寄存器3）
                                onCurrentIndexChanged: {
                                    registerAddressSpin.value = (currentIndex === 0) ? 2 : 3
                                }
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 2) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.26]: 播放时长 - 第二行右侧（索引3）
                        Text {
                            text: "播放时长:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 2
                            Layout.row: 1
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            Layout.column: 3
                            Layout.row: 1
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: playDurationSpin.implicitHeight

                            DeviceInfo.CustomSpinBox {
                                id: playDurationSpin
                                anchors.fill: parent
                                from: 1
                                to: 999
                                value: 10
                                editable: true
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 3) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-02-28 [Phase 7.47.44]: 音频来源 - 第三行左侧（索引4）
                        // 旧代码：寄存器地址（SpinBox），用户不需要看到底层寄存器细节
                        // 新功能：音频来源选择 [默认] [TTS合成]
                        Text {
                            text: "音频来源:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 0
                            Layout.row: 2
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            Layout.column: 1
                            Layout.row: 2
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60

                            // ✅ 隐藏的寄存器地址（由moduleTypeCombo自动设置，数据库兼容用）
                            DeviceInfo.CustomSpinBox {
                                id: registerAddressSpin
                                visible: false
                                from: 0
                                to: 255
                                value: 2
                                editable: true
                                keyboardManager: root.keyboardManager
                            }

                            // 音频来源切换按钮行
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                // ✅ 2026-02-28 [Phase 7.47.44 uipro]: 美化按钮 - Cyberpunk 工业风
                                // 选中默认: 深蓝背景 + 青色边框 + 顶部青色高亮线 + LED点
                                // 选中TTS: 深绿背景 + 绿色边框 + 顶部绿色高亮线 + LED点
                                // 未选中: 深灰背景 + 板岩边框 + 灰色LED点

                                // [默认] 按钮
                                Button {
                                    id: audioSourceDefaultBtn
                                    text: "默认"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    checkable: true
                                    checked: root.audioSourceMode === 0

                                    background: Rectangle {
                                        color: audioSourceDefaultBtn.checked ? "#0d1b2e" :
                                               (audioSourceDefaultBtn.hovered ? "#1e2d42" : "#141920")
                                        radius: 6
                                        border.color: audioSourceDefaultBtn.checked ? "#00d4ff" :
                                                      (audioSourceDefaultBtn.hovered ? "#2196F3" : "#334155")
                                        border.width: audioSourceDefaultBtn.checked ? 2 : 1

                                        // 顶部青色高亮线（选中状态）
                                        Rectangle {
                                            visible: audioSourceDefaultBtn.checked
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

                                            // uipro LED状态指示点
                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: audioSourceDefaultBtn.checked ? "#00d4ff" : "#475569"

                                                // 内部高亮
                                                Rectangle {
                                                    width: 4
                                                    height: 4
                                                    radius: 2
                                                    anchors.centerIn: parent
                                                    color: audioSourceDefaultBtn.checked ? "#e0f7ff" : "#64748B"
                                                }
                                            }

                                            Text {
                                                text: audioSourceDefaultBtn.text
                                                font.pixelSize: 16
                                                font.weight: audioSourceDefaultBtn.checked ? Font.Medium : Font.Normal
                                                color: audioSourceDefaultBtn.checked ? "#00d4ff" : "#9E9E9E"
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                    onClicked: root.audioSourceMode = 0
                                }

                                // [TTS合成] 按钮
                                Button {
                                    id: audioSourceTtsBtn
                                    text: "TTS合成"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    checkable: true
                                    checked: root.audioSourceMode === 1

                                    background: Rectangle {
                                        color: audioSourceTtsBtn.checked ? "#0d2218" :
                                               (audioSourceTtsBtn.hovered ? "#1e2d42" : "#141920")
                                        radius: 6
                                        border.color: audioSourceTtsBtn.checked ? "#22C55E" :
                                                      (audioSourceTtsBtn.hovered ? "#2196F3" : "#334155")
                                        border.width: audioSourceTtsBtn.checked ? 2 : 1

                                        // 顶部绿色高亮线（选中状态）
                                        Rectangle {
                                            visible: audioSourceTtsBtn.checked
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

                                            // uipro LED状态指示点
                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: audioSourceTtsBtn.checked ? "#22C55E" : "#475569"

                                                // 内部高亮
                                                Rectangle {
                                                    width: 4
                                                    height: 4
                                                    radius: 2
                                                    anchors.centerIn: parent
                                                    color: audioSourceTtsBtn.checked ? "#86EFAC" : "#64748B"
                                                }
                                            }

                                            Text {
                                                text: audioSourceTtsBtn.text
                                                font.pixelSize: 16
                                                font.weight: audioSourceTtsBtn.checked ? Font.Medium : Font.Normal
                                                color: audioSourceTtsBtn.checked ? "#22C55E" : "#9E9E9E"
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                    onClicked: root.audioSourceMode = 1
                                }
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 4) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.27]: TTS文字 - 第三行右侧（索引5）
                        // ✅ 2026-02-28 [Phase 7.47.44]: 修复颜色和默认值
                        // ✅ 2026-02-28 [Phase 7.47.44 uipro]: 改为始终显示，默认模式下灰化（不隐藏）
                        Text {
                            text: "TTS文字:"
                            font.pixelSize: 21
                            // 默认模式: 灰化；TTS模式: 正常
                            color: root.audioSourceMode === 1 ? "#9E9E9E" : "#505565"
                            Layout.column: 2
                            Layout.row: 2
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                            // 旧: visible: root.audioSourceMode === 1  // 直接隐藏
                            // 新: 始终显示，依靠 color 灰化传达"不可用"状态
                        }

                        Item {
                            Layout.column: 3
                            Layout.row: 2
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: ttsTextField.implicitHeight
                            // 旧: visible: root.audioSourceMode === 1  // 直接隐藏
                            // 新: 始终显示，依靠 readOnly + color 灰化

                            DeviceInfo.CustomTextField {
                                id: ttsTextField
                                anchors.fill: parent
                                // ✅ 2026-02-28 [Phase 7.47.44]: 允许中文输入（不再限制为数字）
                                inputMethodHints: Qt.ImhNone
                                // ✅ 2026-02-28 [Phase 7.47.44]: 浅色占位文字，避免黑色不可见
                                placeholderText: "如：1号皮带沿线急停保护"
                                // ✅ 2026-02-28 [Phase 7.47.44 uipro]: 默认模式只读+灰色，TTS模式可编辑
                                readOnly: root.audioSourceMode === 0
                                color: root.audioSourceMode === 1 ? "#E0E0E0" : "#505565"
                                placeholderTextColor: "#6E6E6E"
                                opacity: root.audioSourceMode === 1 ? 1.0 : 0.55
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 5) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.28]: 通道编号 - 第四行左侧（索引6）
                        Text {
                            text: "通道编号:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 0
                            Layout.row: 3
                            Layout.preferredWidth: 120
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
                                anchors.fill: parent
                                from: 0
                                to: 15
                                value: 0
                                editable: true
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 6) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.28]: 音频文件 - 第四行右侧（索引7）
                        // ✅ 2026-02-28 [Phase 7.47.44]: 修复显示实际文件名（不再是占位文字）
                        Text {
                            text: "音频文件:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 2
                            Layout.row: 3
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            Layout.column: 3
                            Layout.row: 3
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: audioFileField.implicitHeight

                            DeviceInfo.CustomTextField {
                                id: audioFileField
                                anchors.fill: parent
                                // ✅ 2026-02-28 [Phase 7.47.44]: 浅色占位文字
                                placeholderText: "未配置音频文件"
                                placeholderTextColor: "#6E6E6E"
                                color: "#E0E0E0"
                                readOnly: true
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 7) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.29]: 保护延时 - 第五行左侧（索引8）
                        Text {
                            text: "保护延时:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 0
                            Layout.row: 4
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            Layout.column: 1
                            Layout.row: 4
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: delaySpin.implicitHeight

                            DeviceInfo.CustomSpinBox {
                                id: delaySpin
                                anchors.fill: parent
                                from: 0
                                to: 9999
                                value: 0
                                editable: true
                                keyboardManager: root.keyboardManager
                            }

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusSubArea === 1 && root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                                border.width: (root.focusSubArea === 1 && root.focusParamIndex === 8) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }

                        // ✅ 2026-02-28 [Phase 7.47.44 uipro]: 通道状态指示器 - 第五行右侧
                        // uipro 设计: Cyberpunk 工业 LED 风格
                        // - 灰色LED (不亮): channel = 0 / 未激活
                        // - 绿色LED (脉冲闪烁): channel = 1 / 已激活
                        Text {
                            text: "通道状态:"
                            font.pixelSize: 21
                            color: "#9E9E9E"
                            Layout.column: 2
                            Layout.row: 4
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        Item {
                            id: channelStatusItem
                            Layout.column: 3
                            Layout.row: 4
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            implicitHeight: 60

                            // ✅ 2026-02-28 [Phase 7.47.47]: 从 diDataManager 实时读取对应位状态
                            // 通过访问 Q_PROPERTY (module1Data/module2Data) 建立响应式绑定
                            // 当 DI 模块的对应位发生变化时，此属性自动更新（无需手动监听信号）
                            // Windows 无 MQTT 时 fallback 到 ListModel 的静态 active 值
                            readonly property bool isActive: {
                                if (root.currentProtectionIndex >= 0 &&
                                    root.currentProtectionIndex < digitalProtectionModel.count) {
                                    var item = digitalProtectionModel.get(root.currentProtectionIndex)
                                    if (typeof diDataManager !== 'undefined' && diDataManager !== null) {
                                        var moduleIdx = (item.moduleType === "开关量输入模块1") ? 0 : 1
                                        var bitIdx = item.channelNumber
                                        // 访问 Q_PROPERTY 建立响应式依赖
                                        var _dep = (moduleIdx === 0) ? diDataManager.module1Data : diDataManager.module2Data
                                        return diDataManager.getBit(moduleIdx, bitIdx)
                                    }
                                    // fallback: Windows（无MQTT）时使用 ListModel 中的静态值
                                    return item.active
                                }
                                return false
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                spacing: 12

                                // uipro LED 状态指示灯（工业感双环设计）
                                Item {
                                    // ✅ 2026-02-28 [Phase 7.47.47]: 2倍大小（旧值 24）
                                    width: 48
                                    height: 48
                                    anchors.verticalCenter: parent.verticalCenter

                                    // 外环脉冲光晕（激活时闪烁）
                                    Rectangle {
                                        id: ledOuterRing
                                        anchors.centerIn: parent
                                        width: 48   // ✅ 旧值 24
                                        height: 48  // ✅ 旧值 24
                                        radius: 24  // ✅ 旧值 12
                                        color: "transparent"
                                        border.width: 2
                                        border.color: channelStatusItem.isActive ? "#22C55E" : "#475569"
                                        opacity: 0.4

                                        // 激活时脉冲动画（uipro animate-pulse 等效）
                                        SequentialAnimation on opacity {
                                            running: channelStatusItem.isActive
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.05; duration: 900; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    // 内核 LED 球体
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28   // ✅ 旧值 14
                                        height: 28  // ✅ 旧值 14
                                        radius: 14  // ✅ 旧值 7
                                        color: channelStatusItem.isActive ? "#22C55E" : "#475569"

                                        // 内部反光高亮点（uipro 3D 立体感）
                                        Rectangle {
                                            width: 8    // ✅ 旧值 4
                                            height: 8   // ✅ 旧值 4
                                            radius: 4   // ✅ 旧值 2
                                            color: channelStatusItem.isActive ? "#86EFAC" : "#64748B"
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: 5  // ✅ 旧值 3
                                        }
                                    }
                                }

                                // 状态文字（双行：主状态 + 副信息）
                                Column {
                                    spacing: 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        // 主状态: "信号激活 (1)" 或 "正常监测 (0)"
                                        text: channelStatusItem.isActive ? "信号激活 (1)" : "正常监测 (0)"
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        color: channelStatusItem.isActive ? "#22C55E" : "#64748B"
                                    }

                                    Text {
                                        // 副信息: "保护已触发" 或 "通道正常"
                                        text: channelStatusItem.isActive ? "保护已触发" : "通道正常"
                                        font.pixelSize: 12
                                        color: channelStatusItem.isActive ? "#86EFAC" : "#475569"
                                    }
                                }
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

                // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.30]: 底部按钮区域（两行布局）
                // 第一行：添加输入、删除输入
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: addInputButton
                        text: "添加输入"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 2
                            border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 0) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusButtonIndex === 0) ? 3 : 0
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
                            console.log("添加输入")
                            // TODO: 实现添加输入功能
                        }
                    }

                    Button {
                        id: deleteInputButton
                        text: "删除输入"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                            radius: 2
                            border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 1) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusButtonIndex === 1) ? 3 : 0
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
                            console.log("删除输入:", nameField.text)
                            // TODO: 实现删除输入功能
                        }
                    }
                }

                // 第二行：保存、删除、重置
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: saveButton
                        text: "保存"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#27ae60")
                            radius: 2
                            border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 2) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusButtonIndex === 2) ? 3 : 0
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
                        id: deleteButton
                        text: "删除"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d35400")
                            radius: 2
                            border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 3) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusButtonIndex === 3) ? 3 : 0
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
                        id: resetButton
                        text: "重置"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#7f8c8d")
                            radius: 2
                            border.color: (root.focusSubArea === 2 && root.focusButtonIndex === 4) ? "#2196F3" : "transparent"
                            border.width: (root.focusSubArea === 2 && root.focusButtonIndex === 4) ? 3 : 0
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
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - registerAddressSpin 由moduleType自动决定（隐藏）
            // 旧: registerAddressSpin.value = protection.register_address
            channelSpin.value = protection.channel_number
            delaySpin.value = protection.protection_delay * 10  // 转换为整数（0.1秒精度）
            playCountSpin.value = protection.play_count
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - durationSpin → playDurationSpin（旧ID在注释块中，已失效）
            // 旧错误代码: durationSpin.value = protection.play_duration * 10
            playDurationSpin.value = protection.play_duration * 10
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - ttsRadio/fileRadio 在注释块中，改用 audioSourceMode
            // 旧错误代码: ttsRadio.checked = protection.use_text_to_speech === 1
            // 旧错误代码: fileRadio.checked = protection.use_text_to_speech === 0
            root.audioSourceMode = (protection.use_text_to_speech === 1) ? 1 : 0
            ttsTextField.text = protection.tts_text || getTtsDefaultText(item.name)
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - audioField → audioFileField（正确ID）
            // 旧错误代码: audioField.text = protection.audio_file || ""
            audioFileField.text = protection.audio_file || getAudioFileName(item.name)

            console.log("✅ [SwitchInputPage] 从数据库加载完整参数:", item.name)
        } else {
            // 数据库中没有，使用ListModel中的基本数据
            nameField.text = item.name
            moduleTypeCombo.currentIndex = moduleTypeCombo.model.indexOf(item.moduleType)
            // ✅ 2026-02-28 [Phase 7.47.44]: registerAddressSpin 由 moduleTypeCombo.onCurrentIndexChanged 自动设置
            channelSpin.value = item.channelNumber

            // 设置默认值
            delaySpin.value = 10  // 1.0秒
            playCountSpin.value = 3
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - durationSpin → playDurationSpin
            // 旧错误代码（导致 TypeError，后续行无法执行）: durationSpin.value = 50
            playDurationSpin.value = 50
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - ttsRadio 不存在，改用 audioSourceMode
            // 旧错误代码: ttsRadio.checked = true
            root.audioSourceMode = 0  // 默认使用默认音频
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - 使用正确的TTS文字（与批量合成清单一致）
            // 旧代码: ttsTextField.text = item.name + "保护报警"
            ttsTextField.text = getTtsDefaultText(item.name)
            // ✅ 2026-02-28 [Phase 7.47.44]: 修复 - audioField → audioFileField + 显示实际文件名
            // 旧错误代码: audioField.text = ""
            audioFileField.text = getAudioFileName(item.name)

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
        // ✅ 2026-02-28 [Phase 7.47.44]: 修复所有错误ID引用
        var protection = {
            "protection_name": nameField.text,
            "module_type": moduleTypeCombo.currentText,
            "register_address": registerAddressSpin.value,  // 由moduleType自动设置
            "channel_number": channelSpin.value,
            "protection_delay": delaySpin.realValue,
            "play_count": playCountSpin.value,
            // 旧错误代码: "play_duration": durationSpin.realValue  （durationSpin在注释块中）
            "play_duration": playDurationSpin.realValue,
            // 旧错误代码: "use_text_to_speech": ttsRadio.checked  （ttsRadio在注释块中）
            "use_text_to_speech": root.audioSourceMode === 1 ? 1 : 0,
            "tts_text": ttsTextField.text,
            // 旧错误代码: "audio_file": audioField.text  （audioField在注释块中）
            "audio_file": audioFileField.text
        }

        if (deviceConfigMgr.saveDigitalProtection(root.deviceId, protection)) {
            console.log("✅ [SwitchInputPage] 保存到数据库成功:", nameField.text)
        } else {
            console.error("❌ [SwitchInputPage] 保存到数据库失败:", nameField.text)
        }
    }

    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.29]: 获取参数字段数量
    function getParamFieldCount() {
        // 返回参数区域的输入组件数量
        // 已添加全部9个控件：
        // 保护名称(0)、播放次数(1)、模块类型(2)、播放时长(3)
        // 寄存器地址(4)、TTS文字(5)、通道编号(6)、音频文件(7)、保护延时(8)
        return 9
    }

    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.32]: 触发参数输入（弹出虚拟键盘）
    // ✅ 2026-01-29 [Qt 虚拟键盘]: 使用 Qt 自带的虚拟键盘
    function triggerParamInput(paramIndex) {
        console.log("✅ [SwitchInputPage] 触发参数输入 - 索引:", paramIndex)

        // 根据索引获取对应的输入控件
        var inputField = null
        var inputMode = "numeric"  // 默认数字模式

        switch(paramIndex) {
        case 0:
            inputField = nameField           // 保护名称（TextField）
            inputMode = "chinese"            // 中文输入
            break
        case 1:
            inputField = playCountSpin       // 播放次数（SpinBox）
            inputMode = "numeric"
            break
        case 2:
            inputField = moduleTypeCombo     // 模块类型（ComboBox）
            inputMode = "english"
            break
        case 3:
            inputField = playDurationSpin    // 播放时长（SpinBox）
            inputMode = "numeric"
            break
        case 4:
            inputField = registerAddressSpin // 寄存器地址（SpinBox）
            inputMode = "numeric"
            break
        case 5:
            inputField = ttsTextField        // TTS文字（TextField）
            inputMode = "chinese"            // 中文输入
            break
        case 6:
            inputField = channelSpin         // 通道编号（SpinBox）
            inputMode = "numeric"
            break
        case 7:
            inputField = audioFileField      // 音频文件（TextField）
            inputMode = "english"
            break
        case 8:
            inputField = delaySpin           // 保护延时（SpinBox）
            inputMode = "numeric"
            break
        default:
            console.warn("⚠️ [SwitchInputPage] 无效的参数索引:", paramIndex)
            return
        }

        // ✅ 2026-01-29 [Qt 虚拟键盘]: 使用 Qt 自带的虚拟键盘
        if (inputField) {
            console.log("✅ [SwitchInputPage] 打开 Qt 虚拟键盘 - 控件:", inputField, "模式:", inputMode)

            // ✅ 2026-01-29 [修复]: 直接使用 virtualKeyboard
            if (virtualKeyboard) {
                // ✅ 2026-01-30 [修复]: 传递父页面引用，用于恢复焦点
                virtualKeyboard.openForField(inputField, function(newValue) {
                    console.log("✅ [SwitchInputPage] 虚拟键盘输入完成:", newValue)
                }, inputMode, root)
            } else {
                console.warn("⚠️ [SwitchInputPage] 未找到 Qt 虚拟键盘实例")
                console.warn("   virtualKeyboard:", virtualKeyboard)
            }
        } else {
            console.warn("⚠️ [SwitchInputPage] 输入控件未找到 - 索引:", paramIndex)
        }
    }

    // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.32]: 触发底部按钮点击
    function triggerButton(buttonIndex) {
        console.log("✅ [SwitchInputPage] 触发底部按钮 - 索引:", buttonIndex)

        // 根据索引触发对应按钮的点击事件
        switch(buttonIndex) {
        case 0:  // 添加输入
            console.log("✅ [SwitchInputPage] 触发：添加输入")
            // TODO: 实现添加输入功能
            break
        case 1:  // 删除输入
            console.log("✅ [SwitchInputPage] 触发：删除输入 -", nameField.text)
            // TODO: 实现删除输入功能
            break
        case 2:  // 保存
            console.log("✅ [SwitchInputPage] 触发：保存")
            saveProtectionData()
            break
        case 3:  // 删除
            console.log("✅ [SwitchInputPage] 触发：删除 -", nameField.text)
            // TODO: 实现删除功能
            break
        case 4:  // 重置
            console.log("✅ [SwitchInputPage] 触发：重置")
            loadProtectionData(root.currentProtectionIndex)
            break
        default:
            console.warn("⚠️ [SwitchInputPage] 无效的按钮索引:", buttonIndex)
            break
        }
    }

    // 组件加载完成后，加载第一个保护项的数据
    Component.onCompleted: {
        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.15]: 临时禁用 Component.onCompleted，测试是否还卡住
        console.log("✅ [SwitchInputPage] Component.onCompleted 开始")
        // ✅ 2026-02-28 [Phase 7.47.44]: 恢复初始加载 - 解决保护名称默认为空的问题
        // 旧代码被注释掉导致右侧参数区域始终为空，需要用户手动点击列表项才能显示
        Qt.callLater(function() {
            console.log("✅ [SwitchInputPage] Qt.callLater 回调执行 - 加载第一个保护项")
            if (digitalProtectionModel.count > 0) {
                loadProtectionData(0)
                console.log("✅ [SwitchInputPage] 初始加载第一个保护项完成")
            }
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

    // ✅ 2026-02-28 [Phase 7.47.44]: 获取保护项的默认TTS合成文字
    // 规则：{belt}号皮带 + 真实保护名称 + 保护
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第二章
    function getTtsDefaultText(protectionName) {
        var belt = root.deviceId
        var mapping = {
            "急停":    belt + "号皮带沿线急停保护",
            "跑偏":    belt + "号皮带沿线跑偏保护",
            "撕裂":    belt + "号皮带沿线撕裂保护",
            "烟雾":    belt + "号皮带烟雾保护",
            "温度":    belt + "号皮带温度保护",
            "护网":    belt + "号皮带护网保护",
            "堆煤":    belt + "号皮带堆煤保护",
            "主机急停": belt + "号皮带主机急停保护"
        }
        return mapping[protectionName] || (belt + "号皮带" + protectionName + "保护")
    }

    // ✅ 2026-02-28 [Phase 7.47.44]: 获取保护项对应的默认音频文件名
    // 规则：短名.wav（去掉 "X号皮带" 前缀和 "保护" 后缀）
    // 与 AudioPathMapper::PROTECTION_NAME_MAP 保持一致
    function getAudioFileName(protectionName) {
        var mapping = {
            "急停":    "沿线急停.wav",
            "跑偏":    "沿线跑偏.wav",
            "撕裂":    "沿线撕裂.wav",
            "烟雾":    "烟雾.wav",
            "温度":    "温度.wav",
            "护网":    "护网.wav",
            "堆煤":    "堆煤.wav",
            "主机急停": "主机急停.wav"
        }
        return mapping[protectionName] || (protectionName + ".wav")
    }
}
