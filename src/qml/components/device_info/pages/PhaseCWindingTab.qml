import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-25 [C相绕组温度保护] C相绕组温度保护配置
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

            // 是否投入输入（RadioButton 组）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: enabledRow.implicitHeight  // ✅ 引用 Row 的 implicitHeight

                Row {
                    id: enabledRow
                    anchors.fill: parent
                    spacing: 30

                    // 投入选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: true  // 默认选中
                            }
                        }

                        Text {
                            text: "投入"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 禁用选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: false  // 默认不选中
                            }
                        }

                        Text {
                            text: "禁用"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 报警类型标签
            Text {
                text: "报警类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 报警类型输入（RadioButton 组）
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: alarmTypeRow.implicitHeight  // ✅ 引用 Row 的 implicitHeight

                Row {
                    id: alarmTypeRow
                    anchors.fill: parent
                    spacing: 30

                    // 按次数选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: true  // 默认选中
                            }
                        }

                        Text {
                            text: "按次数"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 按时间选项
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            border.color: "#2196F3"
                            border.width: 2
                            color: "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: "#2196F3"
                                anchors.centerIn: parent
                                visible: false  // 默认不选中
                            }
                        }

                        Text {
                            text: "按时间"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 1) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第二行：动作保护类型（左侧，索引2）、故障保护类型（右侧，索引3）==========

            // 动作保护类型标签
            Text {
                text: "动作保护类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 动作保护类型输入（只读）
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: actionProtectionField.implicitHeight  // ✅ 引用 CustomReadOnlyField 的 implicitHeight

                DeviceInfo.CustomReadOnlyField {
                    id: actionProtectionField
                    anchors.fill: parent
                    text: "立即停机"
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 故障保护类型标签
            Text {
                text: "故障保护类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 故障保护类型输入（只读）
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: faultProtectionField.implicitHeight  // ✅ 引用 CustomReadOnlyField 的 implicitHeight

                DeviceInfo.CustomReadOnlyField {
                    id: faultProtectionField
                    anchors.fill: parent
                    text: "紧急停机"
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第三行：温度量程（左侧，索引4）、温度上限（右侧，索引5）==========

            // 温度量程标签
            Text {
                text: "温度量程:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 温度量程输入（只读）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: tempRangeField.implicitHeight  // ✅ 引用 CustomReadOnlyField 的 implicitHeight

                DeviceInfo.CustomReadOnlyField {
                    id: tempRangeField
                    anchors.fill: parent
                    text: "-20~100℃"
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 温度上限标签
            Text {
                text: "温度上限:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 温度上限输入（只读，带单位）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: tempUpperRow.implicitHeight  // ✅ 引用 Row 的 implicitHeight

                Row {
                    id: tempUpperRow
                    width: parent.width
                    height: 60  // ✅ 设置 Row 的固定高度
                    spacing: 5

                    DeviceInfo.CustomReadOnlyField {
                        width: parent.width - 30
                        height: 60
                        text: "80"
                    }

                    Text {
                        text: "℃"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第四行：温度下限（左侧，索引6）、输入点选择（右侧，索引7）==========

            // 温度下限标签
            Text {
                text: "温度下限:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 温度下限输入（只读，带单位）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: tempLowerRow.implicitHeight  // ✅ 引用 Row 的 implicitHeight

                Row {
                    id: tempLowerRow
                    width: parent.width
                    height: 60  // ✅ 设置 Row 的固定高度
                    spacing: 5

                    DeviceInfo.CustomReadOnlyField {
                        width: parent.width - 30
                        height: 60
                        text: "-10"
                    }

                    Text {
                        text: "℃"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 输入点选择标签
            Text {
                text: "输入点选择:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 输入点选择输入（只读）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: inputPointField.implicitHeight  // ✅ 引用 CustomReadOnlyField 的 implicitHeight

                DeviceInfo.CustomReadOnlyField {
                    id: inputPointField
                    anchors.fill: parent
                    text: "AI-0"
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第五行：过滤干扰延时（左侧，索引8）==========

            // 过滤干扰延时标签
            Text {
                text: "过滤干扰延时:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 过滤干扰延时输入（只读）
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: filterDelayField.implicitHeight  // ✅ 引用 CustomReadOnlyField 的 implicitHeight

                DeviceInfo.CustomReadOnlyField {
                    id: filterDelayField
                    anchors.fill: parent
                    text: "0.5 秒"
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4
                    z: 10
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    function getParamFieldCount() {
        return 9  // 9个参数字段
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [PhaseCWindingTab] 触发参数输入 - 索引:", paramIndex)

        // 所有字段都是只读的，只显示日志
        switch(paramIndex) {
        case 0:  // 是否投入（RadioButton 组）
            console.log("✅ [PhaseCWindingTab] 切换是否投入")
            // TODO: 切换是否投入
            break
        case 1:  // 报警类型（RadioButton 组）
            console.log("✅ [PhaseCWindingTab] 切换报警类型")
            // TODO: 切换报警类型
            break
        case 2:  // 动作保护类型（只读）
            console.log("✅ [PhaseCWindingTab] 动作保护类型（只读）")
            break
        case 3:  // 故障保护类型（只读）
            console.log("✅ [PhaseCWindingTab] 故障保护类型（只读）")
            break
        case 4:  // 温度量程（只读）
            console.log("✅ [PhaseCWindingTab] 温度量程（只读）")
            break
        case 5:  // 温度上限（只读）
            console.log("✅ [PhaseCWindingTab] 温度上限（只读）")
            break
        case 6:  // 温度下限（只读）
            console.log("✅ [PhaseCWindingTab] 温度下限（只读）")
            break
        case 7:  // 输入点选择（只读）
            console.log("✅ [PhaseCWindingTab] 输入点选择（只读）")
            break
        case 8:  // 过滤干扰延时（只读）
            console.log("✅ [PhaseCWindingTab] 过滤干扰延时（只读）")
            break
        }
    }
}
