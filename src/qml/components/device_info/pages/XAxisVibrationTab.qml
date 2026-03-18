import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-25 [X轴振动保护] X轴振动保护配置
// ✅ 2026-01-28 [FIX 100.300.83] 替换所有只读显示框为 CustomReadOnlyField
// ✅ 2026-01-30 [FIX 100.300.106]: 添加导航系统
// ✅ 2026-01-30 [FIX 100.300.108]: 改为 GridLayout，参考 CurrentProtectionTab
Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusParamIndex: 0  // 参数区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

    // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 信号 - 请求更新焦点索引
    // 用于鼠标点击时通知父组件，避免直接赋值打破 Qt.binding
    signal requestFocusParamIndex(int paramIndex)

    // ✅ 2026-03-18 [Phase 7.48.55]: 播放方式 0=按次数 1=按时长（统一Cyberpunk切换按钮样式）
    property int playModeSelection: 0

    // ✅ 2026-01-30 [FIX 100.300.108]: 布局模式（GridLayout）
    readonly property string layoutMode: "grid"  // "grid" 布局

    // ========== 滚动视图 ==========
    ScrollView {
        id: paramScrollView  // ✅ 2026-01-30 [FIX 100.300.108]: 添加 ID，用于 GridLayout 宽度计算
        anchors.fill: parent
        clip: true

        // ✅ 2026-01-30 [FIX 100.300.108]: 改为 GridLayout，参考 CurrentProtectionTab
        GridLayout {
            width: paramScrollView.width * 0.9  // ✅ 占 ScrollView 宽度的 90%
            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
            columnSpacing: 10
            rowSpacing: 12

            // ========== 第一行：是否投入（左侧，索引0）、报警类型（右侧，索引1）==========

            // 是否投入标签
            Text {
                text: "是否投入:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomComboBox，支持回车键切换
            // 是否投入输入（下拉框）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: enabledField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: enabledField
                    anchors.fill: parent
                    model: ["投入", "禁用"]
                    currentIndex: 0  // 默认选中"投入"
                    keyboardManager: root.keyboardManager
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击是否投入，发射信号: requestFocusParamIndex(0)")
                        root.requestFocusParamIndex(0)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 增加 z 值到 1000
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 播放方式标签
            // 旧：text: "报警类型:"  // 2026-03-18 改为"播放方式:"
            Text {
                text: "播放方式:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-03-18 [Phase 7.48.55]: 播放方式切换按钮（Cyberpunk工业风，与开关量输入统一）
            // 旧：CustomComboBox ["按次数", "按时间"]  // 2026-03-18 删除，改为切换按钮
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: 50

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Button {
                        id: playModeCountBtn
                        text: "按次数"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        checkable: true
                        checked: root.playModeSelection === 0
                        background: Rectangle {
                            color: playModeCountBtn.checked ? "#0d1b2e" : (playModeCountBtn.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: playModeCountBtn.checked ? "#00d4ff" : (playModeCountBtn.hovered ? "#2196F3" : "#334155")
                            border.width: playModeCountBtn.checked ? 2 : 1
                            Rectangle { visible: playModeCountBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#00d4ff" }
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: playModeCountBtn.checked ? "#00d4ff" : "#475569"; Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: playModeCountBtn.checked ? "#e0f7ff" : "#64748B" } }
                                Text { text: playModeCountBtn.text; font.pixelSize: 16; font.weight: playModeCountBtn.checked ? Font.Medium : Font.Normal; color: playModeCountBtn.checked ? "#00d4ff" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                        onClicked: root.playModeSelection = 0
                    }

                    Button {
                        id: playModeDurationBtn
                        text: "按时长"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        checkable: true
                        checked: root.playModeSelection === 1
                        background: Rectangle {
                            color: playModeDurationBtn.checked ? "#1b1500" : (playModeDurationBtn.hovered ? "#1e2d42" : "#141920")
                            radius: 6
                            border.color: playModeDurationBtn.checked ? "#F59E0B" : (playModeDurationBtn.hovered ? "#2196F3" : "#334155")
                            border.width: playModeDurationBtn.checked ? 2 : 1
                            Rectangle { visible: playModeDurationBtn.checked; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1; height: 2; radius: 1; color: "#F59E0B" }
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: playModeDurationBtn.checked ? "#F59E0B" : "#475569"; Rectangle { width: 4; height: 4; radius: 2; anchors.centerIn: parent; color: playModeDurationBtn.checked ? "#FDE68A" : "#64748B" } }
                                Text { text: playModeDurationBtn.text; font.pixelSize: 16; font.weight: playModeDurationBtn.checked ? Font.Medium : Font.Normal; color: playModeDurationBtn.checked ? "#F59E0B" : "#9E9E9E"; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                        onClicked: root.playModeSelection = 1
                    }
                }

                Rectangle { anchors.fill: parent; color: "transparent"; border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"; border.width: (root.focusParamIndex === 1) ? 3 : 0; radius: 4; z: 1000; enabled: false }
            }

            // ========== 第二行：次数设置（左侧，索引2，条件显示）、时间设置（右侧，索引3，条件显示）==========

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 次数设置（始终显示，按次数时启用，否则变灰禁用）
            // 次数设置标签
            Text {
                text: "次数设置:"
                font.pixelSize: 21
                color: root.playModeSelection === 0 ? "#9E9E9E" : "#3E3E3E"  // 按次数时正常色，否则变深灰
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 次数设置输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: countSettingField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: countSettingField
                    anchors.fill: parent
                    from: 1
                    to: 100
                    value: 3
                    enabled: root.playModeSelection === 0  // 按次数时启用，否则禁用
                    keyboardManager: root.keyboardManager
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    enabled: root.playModeSelection === 0  // 按次数时启用，否则禁用
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击次数设置，发射信号: requestFocusParamIndex(2)")
                        root.requestFocusParamIndex(2)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 时间设置（始终显示，按时间时启用，否则变灰禁用）
            // 时间设置标签
            Text {
                text: "时间设置:"
                font.pixelSize: 21
                color: root.playModeSelection === 1 ? "#9E9E9E" : "#3E3E3E"  // 按时间时正常色，否则变深灰
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 时间设置输入（带单位 0.1秒）
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: timeSettingRow.implicitHeight

                Row {
                    id: timeSettingRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: timeSettingField
                        width: parent.width - 60
                        height: 60
                        from: 1
                        to: 1000
                        value: 10
                        enabled: root.playModeSelection === 1  // 按时间时启用，否则禁用
                        keyboardManager: root.keyboardManager
                    }

                    Text {
                        text: "0.1秒"
                        font.pixelSize: 21
                        color: root.playModeSelection === 1 ? "#9E9E9E" : "#3E3E3E"  // 按时间时正常色，否则变深灰
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    enabled: root.playModeSelection === 1  // 按时间时启用，否则禁用
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击时间设置，发射信号: requestFocusParamIndex(3)")
                        root.requestFocusParamIndex(3)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第三行：动作保护类型（左侧，索引4）、故障保护类型（右侧，索引5）==========

            // 动作保护类型标签
            Text {
                text: "动作保护类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomComboBox，支持下拉选择
            // 动作保护类型输入（下拉框）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: actionProtectionField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: actionProtectionField
                    anchors.fill: parent
                    model: ["预警停机", "预警不停机", "立即停机"]
                    currentIndex: 2  // 默认选中"立即停机"
                    keyboardManager: root.keyboardManager
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击动作保护类型，发射信号: requestFocusParamIndex(4)")
                        root.requestFocusParamIndex(4)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 故障保护类型标签
            Text {
                text: "故障保护类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomComboBox，支持下拉选择
            // 故障保护类型输入（下拉框）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: faultProtectionField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: faultProtectionField
                    anchors.fill: parent
                    model: ["预警停机", "预警不停机", "立即停机"]
                    currentIndex: 2  // 默认选中"立即停机"
                    keyboardManager: root.keyboardManager
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击故障保护类型，发射信号: requestFocusParamIndex(5)")
                        root.requestFocusParamIndex(5)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第四行：温度量程（左侧，索引6）、温度上限（右侧，索引7）==========

            // 温度量程标签
            Text {
                text: "温度量程:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomSpinBox，可输入数据，单位在外部
            // 温度量程输入（可输入，带单位）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: tempRangeRow.implicitHeight

                Row {
                    id: tempRangeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: tempRangeField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 200
                        value: 100
                        keyboardManager: root.keyboardManager
                    }

                    Text {
                        text: "℃"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击温度量程，发射信号: requestFocusParamIndex(6)")
                        root.requestFocusParamIndex(6)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 温度上限标签
            Text {
                text: "温度上限:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomSpinBox，可输入数据
            // 温度上限输入（可输入，带单位）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: tempUpperRow.implicitHeight

                Row {
                    id: tempUpperRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: tempUpperField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 200
                        value: 80
                        keyboardManager: root.keyboardManager
                    }

                    Text {
                        text: "℃"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击温度上限，发射信号: requestFocusParamIndex(7)")
                        root.requestFocusParamIndex(7)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第五行：温度下限（左侧，索引8）、输入点选择（右侧，索引9）==========

            // 温度下限标签
            Text {
                text: "温度下限:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomSpinBox，可输入数据
            // 温度下限输入（可输入，带单位）
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: tempLowerRow.implicitHeight

                Row {
                    id: tempLowerRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: tempLowerField
                        width: parent.width - 30
                        height: 60
                        from: -50
                        to: 200
                        value: -10
                        keyboardManager: root.keyboardManager
                    }

                    Text {
                        text: "℃"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击温度下限，发射信号: requestFocusParamIndex(8)")
                        root.requestFocusParamIndex(8)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 输入点选择标签
            Text {
                text: "输入点选择:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomComboBox，选项 AI0.0-AI1.7
            // 输入点选择输入（下拉框）
            Item {
                Layout.column: 3
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: inputPointField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: inputPointField
                    anchors.fill: parent
                    model: ["AI0.0", "AI0.1", "AI0.2", "AI0.3", "AI0.4", "AI0.5", "AI0.6", "AI0.7",
                            "AI1.0", "AI1.1", "AI1.2", "AI1.3", "AI1.4", "AI1.5", "AI1.6", "AI1.7"]
                    currentIndex: 0  // 默认选中 AI0.0
                    keyboardManager: root.keyboardManager
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击输入点选择，发射信号: requestFocusParamIndex(9)")
                        root.requestFocusParamIndex(9)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 9) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第六行：过滤干扰延时（左侧，索引10）==========

            // 过滤干扰延时标签
            Text {
                text: "过滤干扰延时:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 改为 CustomSpinBox，修改单位为 "0.1秒"
            // 过滤干扰延时输入（可输入，带单位）
            Item {
                Layout.column: 1
                Layout.row: 5
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: filterDelayRow.implicitHeight

                Row {
                    id: filterDelayRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: filterDelayField
                        width: parent.width - 60
                        height: 60
                        from: 0
                        to: 100
                        value: 5
                        keyboardManager: root.keyboardManager
                    }

                    Text {
                        text: "0.1秒"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-02 [FIX 100.300.112.8.24.9]: 鼠标点击发射信号
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [XAxisVibrationTab] 鼠标点击过滤干扰延时，发射信号: requestFocusParamIndex(10)")
                        root.requestFocusParamIndex(10)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 10) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 10) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    function getParamFieldCount() {
        return 11  // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.16]: 从 9 个增加到 11 个参数字段（增加了次数设置和时间设置）
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [XAxisVibrationTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // 是否投入（CustomComboBox）
            console.log("✅ [XAxisVibrationTab] 切换是否投入")
            // ComboBox 不需要虚拟键盘，直接切换选项
            enabledField.currentIndex = (enabledField.currentIndex + 1) % enabledField.model.length
            break
        case 1:  // 播放方式（Cyberpunk切换按钮）
            console.log("✅ [XAxisVibrationTab] 切换播放方式")
            // ✅ 2026-03-18 [Phase 7.48.55]: 改为切换 playModeSelection
            // 旧：alarmTypeField.currentIndex = (alarmTypeField.currentIndex + 1) % alarmTypeField.model.length
            root.playModeSelection = (root.playModeSelection + 1) % 2
            break
        case 2:  // 次数设置（CustomSpinBox，条件启用）
            console.log("✅ [XAxisVibrationTab] 次数设置")
            if (root.playModeSelection === 0) {
                inputField = countSettingField
            }
            break
        case 3:  // 时间设置（CustomSpinBox，条件启用）
            console.log("✅ [XAxisVibrationTab] 时间设置")
            if (root.playModeSelection === 1) {
                inputField = timeSettingField
            }
            break
        case 4:  // 动作保护类型（CustomComboBox）
            console.log("✅ [XAxisVibrationTab] 动作保护类型")
            // ComboBox 不需要虚拟键盘，直接切换选项
            actionProtectionField.currentIndex = (actionProtectionField.currentIndex + 1) % actionProtectionField.model.length
            break
        case 5:  // 故障保护类型（CustomComboBox）
            console.log("✅ [XAxisVibrationTab] 故障保护类型")
            // ComboBox 不需要虚拟键盘，直接切换选项
            faultProtectionField.currentIndex = (faultProtectionField.currentIndex + 1) % faultProtectionField.model.length
            break
        case 6:  // 温度量程（CustomSpinBox）
            console.log("✅ [XAxisVibrationTab] 温度量程")
            inputField = tempRangeField
            break
        case 7:  // 温度上限（CustomSpinBox）
            console.log("✅ [XAxisVibrationTab] 温度上限")
            inputField = tempUpperField
            break
        case 8:  // 温度下限（CustomSpinBox）
            console.log("✅ [XAxisVibrationTab] 温度下限")
            inputField = tempLowerField
            break
        case 9:  // 输入点选择（CustomComboBox）
            console.log("✅ [XAxisVibrationTab] 输入点选择")
            // ComboBox 不需要虚拟键盘，直接切换选项
            inputPointField.currentIndex = (inputPointField.currentIndex + 1) % inputPointField.model.length
            break
        case 10:  // 过滤干扰延时（CustomSpinBox）
            console.log("✅ [XAxisVibrationTab] 过滤干扰延时")
            inputField = filterDelayField
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [XAxisVibrationTab] 激活虚拟键盘 - 控件:", inputField)
            // 如果控件有 activateVirtualKeyboard 函数，调用它（CustomSpinBox）
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                // 否则直接设置焦点（CustomTextField）
                inputField.forceActiveFocus()
            }
        }
    }
}
