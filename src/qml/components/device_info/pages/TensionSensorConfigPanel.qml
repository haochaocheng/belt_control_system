import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15  // ✅ 2026-03-22 [Phase 7.48.78]: 添加Window导入，ensureVisible需要Window.activeFocusItem
import "../" as DeviceInfo

// 2026-03-17 [Phase 7.48.51] 张力传感器配置面板
// 2026-03-17 [Phase 7.48.52] 参照 AnalogInputPage 4列GridLayout布局重排参数
Rectangle {
    id: root
    color: "transparent"
    clip: true

    // ========== 公开属性 ==========
    property int deviceId: 1
    property int controlIndex: 0      // 0=张力传感器
    property int focusSubArea: 0      // 1=参数区域
    property int focusParamIndex: -1
    property int focusButtonIndex: -1
    property var virtualKeyboard: null
    property var keyboardManager: null  // ✅ 2026-03-17 [Phase 7.48.52]: 键盘管理器（CustomSpinBox/CustomTextField需要）

    // ========== 布局常量（参照AnalogInputPage） ==========
    readonly property int lblFs: 21
    readonly property string lblC: "#9E9E9E"
    readonly property int lblW: 160

    // ========== 标题栏 ==========
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "#2a3142"
        border.color: "#3d4556"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "张力传感器配置"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 内容区域 ==========
    // ✅ 2026-03-22 [Phase 7.48.78]: 改用Flickable替代ScrollView（ScrollView的contentY为NaN）
    // 旧：ScrollView { id: paramScrollView; ... }  // contentY不可动画化
    Flickable {
        id: paramScrollView
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        // ✅ 动态contentHeight，键盘弹出时增加额外空间
        contentHeight: contentArea.implicitHeight + (Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0)

    ColumnLayout {
        id: contentArea
        width: paramScrollView.width
        spacing: 12

        // ========== 传感器启用 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text { text: "传感器启用:"; font.pixelSize: root.lblFs; color: root.lblC }
            Switch {
                id: sensorEnabledSwitch
                checked: true
            }
        }

        // ========== GridLayout 4列参数区（参照AnalogInputPage） ==========
        // 参数索引: 0=名称, 1=播放次数, 2=模块类型, 3=播放时长,
        //          4=通道号, 5=上限值, 6=下限值, 7=量程,
        //          8=单位, 9=输入类型, 10=保护延时, 11=保护级别
        GridLayout {
            id: paramGrid
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            // ===== Row 0: 名称(0) | 播放次数(1) =====
            Text { text: "名称:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: nameField.implicitHeight
                // ✅ 2026-03-22 [Phase 7.48.76]: inputMethodHints改为Qt.ImhNone，允许中文输入
                DeviceInfo.CustomTextField { id: nameField; text: "张力传感器"; anchors.fill: parent; keyboardManager: root.keyboardManager; inputMethodHints: Qt.ImhNone }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 0 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "播放次数:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: playCountSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: playCountSpin; from: 1; to: 99; value: 3; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 1 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 1: 模块类型(2) | 播放时长(3) =====
            Text { text: "模块类型:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 1; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: moduleTypeCombo.implicitHeight
                DeviceInfo.CustomComboBox { id: moduleTypeCombo; model: ["模拟量模块1", "模拟量模块2", "未分配"]; currentIndex: 0; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 2 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "播放时长(秒):"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 1; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: playDurationSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: playDurationSpin; from: 1; to: 999; value: 10; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 3 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 2: 通道号(4) | 上限值(5) =====
            Text { text: "通道号:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 2; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 2; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: channelSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: channelSpin; from: -1; to: 7; value: -1; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 4 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "上限值:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 2; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 2; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: upperLimitSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: upperLimitSpin; from: 0; to: 99999; value: 100; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 5 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 3: 下限值(6) | 量程(7) =====
            Text { text: "下限值:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 3; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 3; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: lowerLimitSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: lowerLimitSpin; from: 0; to: 99999; value: 0; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 6 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "量程:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 3; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 3; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: rangeSpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: rangeSpin; from: 1; to: 99999; value: 200; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 7 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 4: 单位(8) | 输入类型(9) =====
            Text { text: "单位:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 4; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 4; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: unitCombo.implicitHeight
                DeviceInfo.CustomComboBox { id: unitCombo; model: ["kN", "N", "kg", "t", "MPa", "bar"]; currentIndex: 0; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 8 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "输入类型:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 4; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 4; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: inputTypeCombo.implicitHeight
                DeviceInfo.CustomComboBox { id: inputTypeCombo; model: ["4-20mA电流型", "0-20mA电流型", "0-5V电压型", "0-10V电压型", "1-5V电压型", "PT100热电阻"]; currentIndex: 0; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 9 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 5: 保护延时(10) | 保护级别(11) =====
            Text { text: "保护延时:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 5; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 5; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: protectionDelaySpin.implicitHeight
                DeviceInfo.CustomSpinBox { id: protectionDelaySpin; from: 0; to: 9999; value: 30; editable: true; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 10 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "保护级别:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 5; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 5; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: protectionLevelCombo.implicitHeight
                DeviceInfo.CustomComboBox { id: protectionLevelCombo; model: ["仅预警", "预警+正常停车", "预警+紧急停车"]; currentIndex: 2; anchors.fill: parent; keyboardManager: root.keyboardManager }
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 11 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        } // GridLayout end

        // ========== 分隔线 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== 语音配置区（4列GridLayout，与上方参数区对齐） ==========
        // ✅ 2026-03-18 [Phase 7.48.54]: 改为GridLayout，播放方式与保护级别列对齐
        // 旧：RowLayout 一行排列，播放方式与保护级别不对齐
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            // ===== Row 0: 音频来源 | 播放方式 =====
            Text { text: "音频来源:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: audioDefaultRadio.implicitHeight
                ButtonGroup { id: audioSourceGroup }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    // 旧：RadioButton { id: audioDefaultRadio; text: "默认"; checked: true; ... }  // 默认选中"默认"
                    // ✅ 2026-03-18 [Phase 7.48.54]: 音频来源初始值改为TTS（因为没有预录音频文件）
                    RadioButton { id: audioDefaultRadio; text: "默认"; ButtonGroup.group: audioSourceGroup; contentItem: Text { text: parent.text; font.pixelSize: 21; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 } }
                    RadioButton { id: audioTtsRadio; text: "TTS"; checked: true; ButtonGroup.group: audioSourceGroup; contentItem: Text { text: parent.text; font.pixelSize: 21; color: "#E0E0E0"; leftPadding: parent.indicator.width + 4 } }
                }
                // ✅ 2026-03-22 [Phase 7.48.76]: 添加焦点高亮（参数索引12）
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 12 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "播放方式:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            // ✅ 2026-03-18 [Phase 7.48.55]: 播放方式切换按钮（Cyberpunk工业风，与开关量输入统一）
            // 旧：RadioButton playCountRadio/playDurationRadio  // 2026-03-18 删除，改为切换按钮
            Item {
                Layout.column: 3; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: 50

                // 隐藏的 RadioButton（保持与现有保存/加载逻辑兼容）
                ButtonGroup { id: playModeGroup }
                RadioButton { id: playCountRadio; visible: false; checked: true; ButtonGroup.group: playModeGroup }
                RadioButton { id: playDurationRadio; visible: false; ButtonGroup.group: playModeGroup }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Button {
                        id: playModeCountBtn
                        text: "按次数"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        checkable: true
                        checked: playCountRadio.checked
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
                        onClicked: { playCountRadio.checked = true }
                    }

                    Button {
                        id: playModeDurationBtn
                        text: "按时长"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        checkable: true
                        checked: playDurationRadio.checked
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
                        onClicked: { playDurationRadio.checked = true }
                    }
                }
                // ✅ 2026-03-22 [Phase 7.48.76]: 添加焦点高亮（参数索引13）
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 13 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }

            // ===== Row 1: TTS文本(12) / 音频文件(13) =====
            Text { text: audioTtsRadio.checked ? "TTS文本:" : "音频文件:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 1; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                // ✅ 2026-03-18 [Phase 7.48.54]: 去掉columnSpan:3，宽度与保护延时输入框一致
                // 旧：Layout.columnSpan: 3; Layout.fillWidth: true  // 跨3列太宽
                Layout.column: 1; Layout.row: 1; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: ttsTextField.implicitHeight
                DeviceInfo.CustomTextField {
                    id: ttsTextField; text: "张力传感器报警"
                    anchors.fill: parent; visible: audioTtsRadio.checked
                    keyboardManager: root.keyboardManager
                    // ✅ 2026-03-22 [Phase 7.48.76]: inputMethodHints改为Qt.ImhNone，允许中文输入
                    inputMethodHints: Qt.ImhNone
                    // ✅ 2026-03-22 [Phase 7.48.76]: 参数索引12→14（新增音频来源12、播放方式13后后移）
                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 14 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
                }
                DeviceInfo.CustomTextField {
                    id: audioFileField; text: ""
                    // 旧：placeholderText: "自动生成"
                    // ✅ 2026-03-18 [Phase 7.48.54]: 改为"张力保护"（更准确描述功能）
                    // ✅ 2026-03-22 [Phase 7.48.76]: 参数索引13→14（新增音频来源12、播放方式13后后移）
                    anchors.fill: parent; readOnly: true; visible: audioDefaultRadio.checked; placeholderText: "张力保护"
                    keyboardManager: root.keyboardManager
                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 14 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
                }
            }
        } // 语音配置GridLayout end

        // ========== 分隔线2 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== 洒水启用(15) + 洒水编号(16) ==========
        // ✅ 2026-03-22 [Phase 7.48.78]: 改为GridLayout对齐（洒水启用对齐TTS文本列，洒水编号对齐播放方式列）
        // 旧：RowLayout { ... }  // 一行紧凑排列，不对齐
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            Text { text: "洒水启用:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 0; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 1; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: sprinklerSwitch.implicitHeight
                Switch { id: sprinklerSwitch; checked: false; anchors.verticalCenter: parent.verticalCenter }
                // ✅ 2026-03-22 [Phase 7.48.78]: 洒水启用焦点高亮（参数索引15）
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 15 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
            Text { text: "洒水编号:"; font.pixelSize: root.lblFs; color: root.lblC; Layout.column: 2; Layout.row: 0; Layout.preferredWidth: root.lblW; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.column: 3; Layout.row: 0; Layout.fillWidth: true; Layout.maximumWidth: 300
                implicitHeight: sprinklerIndexSpin.implicitHeight
                // ✅ 2026-03-22 [Phase 7.48.79]: width:120 → anchors.fill:parent，与其他SpinBox宽度一致
                DeviceInfo.CustomSpinBox {
                    id: sprinklerIndexSpin; from: 0; to: 7; value: 0; enabled: sprinklerSwitch.checked
                    anchors.fill: parent; keyboardManager: root.keyboardManager
                }
                // ✅ 2026-03-22 [Phase 7.48.78]: 洒水编号焦点高亮（参数索引16）
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 1 && root.focusParamIndex === 16 ? "#2196F3" : "transparent"; border.width: 3; radius: 4; z: 10 }
            }
        }

        // ========== 分隔线3 ==========
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3d4556" }

        // ========== 状态监控（参照BasicConfigTab传感器实时数据显示） ==========
        // ✅ 2026-03-18 [Phase 7.48.54]: 新增张力实际值状态显示
        Text {
            text: "状态监控"
            font.pixelSize: 19; font.bold: true; color: "#7dd3fc"
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            id: tensionStatusPanel
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            Layout.leftMargin: 8; Layout.rightMargin: 8

            // 张力实时数据
            property double tensionAdValue: 0
            property double tensionEngValue: 0.0
            property bool isExceeded: false

            // 监听AI数据变化
            Connections {
                target: typeof aiDataManager !== 'undefined' ? aiDataManager : null
                ignoreUnknownSignals: true
                function onChannelChanged(modIndex, channelIndex, data) {
                    // 模块匹配：模拟量模块1→AI模块索引2，模拟量模块2→AI模块索引3
                    var expectedModIndex = (moduleTypeCombo.currentText === "模拟量模块1") ? 2 : 3
                    if (modIndex !== expectedModIndex) return
                    if (channelIndex !== channelSpin.value) return
                    if (channelSpin.value < 0) return  // 未分配跳过

                    var chData = aiDataManager.getChannel(modIndex, channelIndex)
                    if (!chData) return

                    var adVal = chData.adValue || 0
                    tensionStatusPanel.tensionAdValue = adVal

                    // 工程量计算：下限 + (AD值 / 65535) × 量程
                    var lower = lowerLimitSpin.value || 0
                    var range = rangeSpin.value || 200
                    tensionStatusPanel.tensionEngValue = lower + (adVal / 65535.0) * range

                    // 超限判断
                    tensionStatusPanel.isExceeded = (tensionStatusPanel.tensionEngValue > upperLimitSpin.value || tensionStatusPanel.tensionEngValue < lowerLimitSpin.value)
                }
            }

            // 张力值卡片
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.6, 300)
                height: 50
                radius: 4
                color: "#0d1b2a"
                border.width: 1
                border.color: tensionStatusPanel.isExceeded ? "#ef4444" : "#1e3a5f"

                // 超限脉冲发光
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: tensionStatusPanel.isExceeded ? "#ef4444" : "transparent"
                    visible: tensionStatusPanel.isExceeded
                    opacity: 0.6
                    SequentialAnimation on opacity {
                        running: tensionStatusPanel.isExceeded
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.6; to: 0.15; duration: 800 }
                        NumberAnimation { from: 0.15; to: 0.6; duration: 800 }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 1

                    Row {
                        width: parent.width
                        spacing: 4
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: tensionStatusPanel.isExceeded ? "#ef4444" :
                                   (tensionStatusPanel.tensionEngValue !== 0.0 ? "#22c55e" : "#475569")
                        }
                        Text {
                            text: nameField.text || "张力传感器"
                            font.pixelSize: 13; color: "#94a3b8"
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 2
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: tensionStatusPanel.tensionEngValue.toFixed(1)
                            font.pixelSize: 22
                            font.family: "Consolas"
                            font.bold: true
                            color: tensionStatusPanel.isExceeded ? "#ef4444" :
                                   (tensionStatusPanel.tensionEngValue !== 0.0 ? "#00d4ff" : "#475569")
                        }
                        Text {
                            text: unitCombo.currentText || "kN"
                            font.pixelSize: 12; color: "#64748b"
                            anchors.bottom: parent.children[0].bottom
                            anchors.bottomMargin: 2
                        }
                    }
                }
            }
        }

        // ✅ 2026-03-22 [Phase 7.48.75]: 在ScrollView中不需要弹性空间，改为固定间距
        // 旧：Item { Layout.fillHeight: true }
        Item { Layout.preferredHeight: 20 }

        // // ========== 底部按钮行 ==========
        // RowLayout {
        //     Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 16
        //     Item { Layout.fillWidth: true }
        //     Button {
        //         id: saveBtn; text: "保存"; Layout.preferredWidth: 100; Layout.preferredHeight: 36
        //         background: Rectangle { color: saveBtn.pressed ? "#1e8449" : "#27ae60"; radius: 4 }
        //         contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        //         onClicked: saveTensionSensorConfig()
        //         Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 0 ? "#FFFFFF" : "transparent"; border.width: 2; radius: 4; z: 100 }
        //     }
        //     Button {
        //         id: resetBtn; text: "重置"; Layout.preferredWidth: 100; Layout.preferredHeight: 36
        //         background: Rectangle { color: resetBtn.pressed ? "#5d6d7e" : "#7f8c8d"; radius: 4 }
        //         contentItem: Text { text: parent.text; font.pixelSize: 14; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        //         onClicked: loadTensionSensorConfig()
        //         Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.focusSubArea === 2 && root.focusButtonIndex === 1 ? "#FFFFFF" : "transparent"; border.width: 2; radius: 4; z: 100 }
        //     }
        //     Item { Layout.fillWidth: true }
        // }
    } // ColumnLayout end
    } // Flickable end

    // ✅ 2026-03-22 [Phase 7.48.75]: 滚动动画
    NumberAnimation {
        id: scrollAnimation
        target: paramScrollView
        property: "contentY"
        duration: 200
        easing.type: Easing.OutQuad
    }

    // ✅ 2026-03-22 [Phase 7.48.75]: 虚拟键盘弹出时自动滚动，确保输入框可见
    Connections {
        target: Qt.inputMethod
        function onVisibleChanged() {
            if (Qt.inputMethod.visible) {
                // 延迟执行，等待键盘动画完成
                Qt.callLater(function() {
                    var focusItem = root.Window ? root.Window.activeFocusItem : null
                    if (focusItem) ensureVisible(focusItem)
                })
            }
        }
    }

    function ensureVisible(item) {
        if (!item) return
        Qt.callLater(function() {
            var kbRect = Qt.inputMethod.keyboardRectangle
            if (kbRect.height <= 0) return
            var itemGlobal = item.mapToItem(null, 0, 0)
            var itemGlobalBottom = itemGlobal.y + item.height
            var screenHeight = (kbRect.y >= kbRect.height) ? kbRect.y : 1080
            var kbTop = screenHeight - kbRect.height
            var safeBottom = kbTop - 60
            if (itemGlobalBottom <= safeBottom) {
                console.log("✅ [TensionSensorConfigPanel] ensureVisible: 无需滚动")
                return
            }
            var scrollNeeded = itemGlobalBottom - safeBottom
            var targetY = paramScrollView.contentY + scrollNeeded
            var maxScroll = Math.max(0, paramScrollView.contentHeight - paramScrollView.height)
            targetY = Math.min(targetY, maxScroll)
            console.log("✅ [TensionSensorConfigPanel] ensureVisible: scrollNeeded=" + scrollNeeded + " targetY=" + targetY + " maxScroll=" + maxScroll)
            scrollAnimation.to = targetY
            scrollAnimation.start()
        })
    }

    // ========== 函数 ==========
    // ✅ 2026-03-22 [Phase 7.48.78]: 参数数量16→17（新增洒水启用15）
    function getParamFieldCount() { return 17 }  // 参数索引 0-16

    function collectConfig() {
        return {
            "sensor_enabled": sensorEnabledSwitch.checked,
            "name": nameField.text,
            "unit": unitCombo.currentText,
            "module_type": moduleTypeCombo.currentText,
            "channel": channelSpin.value,
            "input_type": inputTypeCombo.currentText,
            "upper_limit": upperLimitSpin.value,
            "lower_limit": lowerLimitSpin.value,
            "range_value": rangeSpin.value,
            "protection_delay": protectionDelaySpin.value,
            "play_count": playCountSpin.value,
            "play_duration": playDurationSpin.value,
            "audio_source": audioTtsRadio.checked ? "tts" : "default",
            "play_mode": playCountRadio.checked ? "count" : "duration",
            "tts_text": ttsTextField.text,
            "audio_file": audioFileField.text,
            "protection_level": protectionLevelCombo.currentIndex,
            "sprinkler_enabled": sprinklerSwitch.checked,
            "sprinkler_index": sprinklerIndexSpin.value
        }
    }

    function applyConfig(config) {
        if (!config) return
        if (config.sensor_enabled !== undefined) sensorEnabledSwitch.checked = config.sensor_enabled
        if (config.name !== undefined) nameField.text = config.name
        if (config.unit !== undefined) { var idx = unitCombo.find(config.unit); if (idx >= 0) unitCombo.currentIndex = idx }
        if (config.module_type !== undefined) { var idx2 = moduleTypeCombo.find(config.module_type); if (idx2 >= 0) moduleTypeCombo.currentIndex = idx2 }
        if (config.channel !== undefined) channelSpin.value = config.channel
        if (config.input_type !== undefined) { var idx3 = inputTypeCombo.find(config.input_type); if (idx3 >= 0) inputTypeCombo.currentIndex = idx3 }
        if (config.upper_limit !== undefined) upperLimitSpin.value = config.upper_limit
        if (config.lower_limit !== undefined) lowerLimitSpin.value = config.lower_limit
        if (config.range_value !== undefined) rangeSpin.value = config.range_value
        if (config.protection_delay !== undefined) protectionDelaySpin.value = config.protection_delay
        if (config.play_count !== undefined) playCountSpin.value = config.play_count
        if (config.play_duration !== undefined) playDurationSpin.value = config.play_duration
        if (config.audio_source !== undefined) { audioTtsRadio.checked = (config.audio_source === "tts"); audioDefaultRadio.checked = (config.audio_source !== "tts") }
        if (config.play_mode !== undefined) { playCountRadio.checked = (config.play_mode === "count"); playDurationRadio.checked = (config.play_mode !== "count") }
        if (config.tts_text !== undefined) ttsTextField.text = config.tts_text
        if (config.audio_file !== undefined) audioFileField.text = config.audio_file
        if (config.protection_level !== undefined) protectionLevelCombo.currentIndex = config.protection_level
        if (config.sprinkler_enabled !== undefined) sprinklerSwitch.checked = config.sprinkler_enabled
        if (config.sprinkler_index !== undefined) sprinklerIndexSpin.value = config.sprinkler_index
    }

    function saveTensionSensorConfig() {
        var config = collectConfig()
        console.log("✅ [TensionSensorConfigPanel] 保存张力传感器配置:", JSON.stringify(config))
        if (typeof deviceConfigMgr !== "undefined") {
            deviceConfigMgr.saveTensionSensorConfig(root.deviceId, config)
        }
    }

    function loadTensionSensorConfig() {
        console.log("✅ [TensionSensorConfigPanel] 加载张力传感器配置, deviceId:", root.deviceId)
        if (typeof deviceConfigMgr !== "undefined") {
            var config = deviceConfigMgr.loadTensionSensorConfig(root.deviceId)
            applyConfig(config)
        }
    }

    // ✅ 2026-03-22 [Phase 7.48.76]: triggerParamInput 全面修复
    // 修复1: SpinBox 改用 activateVirtualKeyboard()（弹出虚拟键盘）
    // 修复2: ComboBox 改用循环切换值（与CustomComboBox回车行为一致）
    // 修复3: TextField 加 Qt.inputMethod.show()（弹出虚拟键盘）
    // ✅ 2026-03-22 [Phase 7.48.78]: 修复音频来源/播放方式ButtonGroup切换 + 添加洒水启用导航
    // 新索引: 0=名称, 1=播放次数, 2=模块类型, 3=播放时长, 4=通道号, 5=上限值,
    //         6=下限值, 7=量程, 8=单位, 9=输入类型, 10=保护延时, 11=保护级别,
    //         12=音频来源, 13=播放方式, 14=TTS文本/音频文件, 15=洒水启用, 16=洒水编号
    function triggerParamInput(paramIndex) {
        console.log("✅ [TensionSensorConfigPanel] triggerParamInput:", paramIndex)
        switch(paramIndex) {
        // TextField: forceActiveFocus + Qt.inputMethod.show
        case 0: nameField.forceActiveFocus(); Qt.inputMethod.show(); break
        // SpinBox: activateVirtualKeyboard
        case 1: playCountSpin.activateVirtualKeyboard(); break
        // ComboBox: 循环切换值
        case 2: moduleTypeCombo.isUserAction = true; moduleTypeCombo.currentIndex = (moduleTypeCombo.currentIndex + 1) % moduleTypeCombo.count; moduleTypeCombo.isUserAction = false; break
        case 3: playDurationSpin.activateVirtualKeyboard(); break
        case 4: channelSpin.activateVirtualKeyboard(); break
        case 5: upperLimitSpin.activateVirtualKeyboard(); break
        case 6: lowerLimitSpin.activateVirtualKeyboard(); break
        case 7: rangeSpin.activateVirtualKeyboard(); break
        case 8: unitCombo.isUserAction = true; unitCombo.currentIndex = (unitCombo.currentIndex + 1) % unitCombo.count; unitCombo.isUserAction = false; break
        case 9: inputTypeCombo.isUserAction = true; inputTypeCombo.currentIndex = (inputTypeCombo.currentIndex + 1) % inputTypeCombo.count; inputTypeCombo.isUserAction = false; break
        case 10: protectionDelaySpin.activateVirtualKeyboard(); break
        case 11: protectionLevelCombo.isUserAction = true; protectionLevelCombo.currentIndex = (protectionLevelCombo.currentIndex + 1) % protectionLevelCombo.count; protectionLevelCombo.isUserAction = false; break
        // 音频来源: 切换 默认↔TTS（旧：双!checked被ButtonGroup互斥覆盖）
        case 12:
            if (audioDefaultRadio.checked) { audioTtsRadio.checked = true }
            else { audioDefaultRadio.checked = true }
            break
        // 播放方式: 切换 按次数↔按时长（旧：双!checked被ButtonGroup互斥覆盖）
        case 13:
            if (playCountRadio.checked) { playDurationRadio.checked = true }
            else { playCountRadio.checked = true }
            break
        // TTS文本/音频文件
        case 14:
            if (audioTtsRadio.checked) {
                ttsTextField.forceActiveFocus(); Qt.inputMethod.show()
                // ✅ 2026-03-22 [Phase 7.48.78]: 主动触发ensureVisible，确保输入框不被虚拟键盘遮挡
                Qt.callLater(function() { ensureVisible(ttsTextField) })
            }
            else { audioFileField.forceActiveFocus() }
            break
        // 洒水启用（新增）
        case 15: sprinklerSwitch.checked = !sprinklerSwitch.checked; break
        // 洒水编号（旧索引15→16）
        // ✅ 2026-03-22 [Phase 7.48.79]: 洒水开关关闭时先自动启用，再弹出虚拟键盘
        case 16:
            if (!sprinklerSwitch.checked) { sprinklerSwitch.checked = true }
            sprinklerIndexSpin.activateVirtualKeyboard()
            break
        }
    }

    function triggerButton(buttonIndex) {
        console.log("✅ [TensionSensorConfigPanel] triggerButton:", buttonIndex)
        switch(buttonIndex) {
        case 0: saveTensionSensorConfig(); break
        case 1: loadTensionSensorConfig(); break
        }
    }

    Component.onCompleted: {
        console.log("✅ [TensionSensorConfigPanel] 初始化完成, deviceId:", root.deviceId)
        loadTensionSensorConfig()
    }
}
