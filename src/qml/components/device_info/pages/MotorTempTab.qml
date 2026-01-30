import QtQuick 2.15
import QtQuick.Controls 2.15
import ".." as DeviceInfo

// ✅ 2026-01-25 [电机温度保护] 电机温度保护配置
// ✅ 2026-01-28 [FIX 100.300.83] 替换所有只读显示框为 CustomReadOnlyField
// ✅ 2026-01-28 [虚拟键盘集成]: 接收键盘管理器（暂无可编辑组件）
// ✅ 2026-01-30 [FIX 100.300.106]: 添加导航系统
Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0
    // ✅ 2026-01-28 [虚拟键盘]: 键盘管理器属性（预留，当前页面只有只读字段）
    property var keyboardManager: null

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusParamIndex: 0  // 参数区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

    // ✅ 2026-01-30 [FIX 100.300.106.3]: 布局模式（单列布局）
    readonly property string layoutMode: "single-column"  // "single-column" 或 "two-column"

    // ========== 滚动视图 ==========
    ScrollView {
        anchors.fill: parent
        clip: true

        Column {
            width: parent.width
            spacing: 15
            leftPadding: 30
        rightPadding: 30
        topPadding: 30
        // FIX 100.300.59: Use separate padding to avoid polish() loop

            // 是否投入（索引 0）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "是否投入:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 200
                    height: 40

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 0) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 30
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                border.color: "#2196F3"; border.width: 2
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: true }
                            }
                            Text { text: "投入"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                border.color: "#2196F3"; border.width: 2
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: false }
                            }
                            Text { text: "禁用"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // 报警类型（索引 1）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "报警类型:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 200
                    height: 40

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 1) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 30
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                border.color: "#2196F3"; border.width: 2
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: true }
                            }
                            Text { text: "按次数"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                border.color: "#2196F3"; border.width: 2
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: 10; height: 10; radius: 5; color: "#2196F3"; anchors.centerIn: parent; visible: false }
                            }
                            Text { text: "按时间"; font.pixelSize: 14; color: "#E0E0E0"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // 动作保护类型（索引 2）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "动作保护类型:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 200
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 2) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "立即停机"
                    }
                }
            }

            // 故障保护类型（索引 3）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "故障保护类型:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 200
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 3) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "紧急停机"
                    }
                }
            }

            // 温度量程（索引 4）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "温度量程:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 200
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 4) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "-20~100℃"
                    }
                }
            }

            // 温度上限（索引 5）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "温度上限:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 120
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 5) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "80"
                    }
                }

                Text {
                    text: "℃"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 温度下限（索引 6）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "温度下限:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 120
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 6) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "-10"
                    }
                }

                Text {
                    text: "℃"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 过滤干扰延时（索引 7）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "过滤干扰延时:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 120
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 7) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "0.5 秒"
                    }
                }
            }

            // 输入点选择（索引 8）
            Row {
                width: parent.width - 60  // FIX 100.300.59: Subtract left+right padding
                spacing: 20
                Text {
                    text: "输入点选择:"
                    width: 120
                    font.pixelSize: 14
                    color: "#9E9E9E"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器容器
                Item {
                    width: 200
                    height: 60

                    // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 8) ? 3 : 0
                        radius: 4
                        z: 10
                    }

                    DeviceInfo.CustomReadOnlyField {
                        anchors.fill: parent
                        text: "AI-0"
                    }
                }
            }
        }
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航函数
    // 获取参数字段数量
    function getParamFieldCount() {
        return 9  // 9个参数字段
    }

    // 触发参数输入
    function triggerParamInput(paramIndex) {
        console.log("✅ [MotorTempTab] 触发参数输入 - 索引:", paramIndex)

        // 所有字段都是只读的，只显示日志
        switch(paramIndex) {
        case 0:  // 是否投入（RadioButton 组）
            console.log("✅ [MotorTempTab] 切换是否投入")
            // TODO: 切换是否投入
            break
        case 1:  // 报警类型（RadioButton 组）
            console.log("✅ [MotorTempTab] 切换报警类型")
            // TODO: 切换报警类型
            break
        case 2:  // 动作保护类型（只读）
            console.log("✅ [MotorTempTab] 动作保护类型（只读）")
            break
        case 3:  // 故障保护类型（只读）
            console.log("✅ [MotorTempTab] 故障保护类型（只读）")
            break
        case 4:  // 温度量程（只读）
            console.log("✅ [MotorTempTab] 温度量程（只读）")
            break
        case 5:  // 温度上限（只读）
            console.log("✅ [MotorTempTab] 温度上限（只读）")
            break
        case 6:  // 温度下限（只读）
            console.log("✅ [MotorTempTab] 温度下限（只读）")
            break
        case 7:  // 过滤干扰延时（只读）
            console.log("✅ [MotorTempTab] 过滤干扰延时（只读）")
            break
        case 8:  // 输入点选择（只读）
            console.log("✅ [MotorTempTab] 输入点选择（只读）")
            break
        }
    }
}
