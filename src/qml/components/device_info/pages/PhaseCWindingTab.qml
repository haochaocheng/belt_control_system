import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as DeviceInfo

// ✅ 2026-01-25 [C相绕组保护] C相绕组保护配置
// ✅ 2026-01-28 [FIX 100.300.83] 替换所有只读显示框为 CustomReadOnlyField
// ✅ 2026-01-30 [FIX 100.300.106]: 添加导航系统
// ✅ 2026-01-30 [FIX 100.300.106.5]: 改为两列布局,参考 BasicConfigTab
Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int motorIndex: 0

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusParamIndex: 0  // 参数区域焦点索引
    property var virtualKeyboard: null  // Qt 虚拟键盘引用

    // ✅ 2026-01-30 [FIX 100.300.106.3]: 布局模式（两列布局）
    readonly property string layoutMode: "two-column"  // "single-column" 或 "two-column"

    // ========== 滚动视图 ==========
    ScrollView {
        anchors.fill: parent
        clip: true

        // ✅ 2026-01-30 [FIX 100.300.106.5]: 改为两列布局
        ColumnLayout {
            width: parent.width
            spacing: 12
            implicitWidth: 1200  // 两列布局需要的最小宽度
            implicitHeight: childrenRect.height

            // ✅ 2026-01-30 [FIX 100.300.106.5]: 两列布局
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 20  // 两列之间的间距

                // ========== 左列 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    // 是否投入（索引 0）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "是否投入:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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
                                        font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
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
                                        font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                                        color: "#E0E0E0"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // 动作保护类型（索引 2）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "动作保护类型:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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

                    // 温度量程（索引 4）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "温度量程:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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

                    // 温度下限（索引 6）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "温度下限:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 6) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            Row {
                                anchors.fill: parent
                                spacing: 5

                                DeviceInfo.CustomReadOnlyField {
                                    width: parent.width - 30
                                    height: parent.height
                                    text: "-10"
                                }

                                Text {
                                    text: "℃"
                                    font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                                    color: "#9E9E9E"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 输入点选择（索引 8）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "输入点选择:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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
                }  // 左列结束

                // ========== 右列 ==========
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    // 报警类型（索引 1）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "报警类型:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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
                                        font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
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
                                        font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                                        color: "#E0E0E0"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // 故障保护类型（索引 3）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "故障保护类型:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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

                    // 温度上限（索引 5）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "温度上限:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 5) ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            Row {
                                anchors.fill: parent
                                spacing: 5

                                DeviceInfo.CustomReadOnlyField {
                                    width: parent.width - 30
                                    height: parent.height
                                    text: "80"
                                }

                                Text {
                                    text: "℃"
                                    font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                                    color: "#9E9E9E"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 过滤干扰延时（索引 7）
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）
                        spacing: 10

                        Text {
                            text: "过滤干扰延时:"
                            font.pixelSize: 21  // ✅ 2026-01-30 [FIX 100.300.106.6]: 统一文字大小为 21（参考开关量参数区）
                            color: "#9E9E9E"
                            Layout.preferredWidth: 120
                            horizontalAlignment: Text.AlignRight
                        }

                        // 焦点指示器容器
                        Item {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            Layout.preferredHeight: 60  // ✅ 2026-01-30 [FIX 100.300.106.7]: 统一输入框高度为 60（参考 CustomReadOnlyField）

                            // 焦点指示器
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
                }  // 右列结束
            }  // RowLayout 结束
        }  // ColumnLayout 结束
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
        case 7:  // 过滤干扰延时（只读）
            console.log("✅ [PhaseCWindingTab] 过滤干扰延时（只读）")
            break
        case 8:  // 输入点选择（只读）
            console.log("✅ [PhaseCWindingTab] 输入点选择（只读）")
            break
        }
    }
}
