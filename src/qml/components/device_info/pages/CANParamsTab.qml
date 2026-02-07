// CANParamsTab.qml
// CAN 参数配置 Tab
// 创建日期: 2026-02-07
// ✅ 2026-02-07 [Phase 7.39.12]: 修复输入框背景图片

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentCanInterface: null
    property int focusParamIndex: 0
    property var virtualKeyboard: null

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 4  // CAN接口、波特率、状态、帧类型
    }

    function triggerParamInput(paramIndex) {
        console.log("✅ [CANParamsTab] 触发参数输入 - 索引:", paramIndex)
        // 参数索引映射（2列布局）：
        // 行0：[0] CAN接口（只读） [1] 波特率（可编辑）
        // 行1：[2] 状态（只读）     [3] 帧类型（可编辑）
    }

    function handleEnterKey() {
        console.log("✅ [CANParamsTab] 处理回车键 - 参数索引:", focusParamIndex)

        switch(focusParamIndex) {
        case 1:  // 波特率
            if (bitrateCombo.popup.visible) {
                bitrateCombo.popup.close()
            } else {
                bitrateCombo.popup.open()
            }
            return true
        case 3:  // 帧类型
            if (frameTypeCombo.popup.visible) {
                frameTypeCombo.popup.close()
            } else {
                frameTypeCombo.popup.open()
            }
            return true
        default:
            return false
        }
    }

    // ========== 滚动视图 ==========
    ScrollView {
        id: paramScrollView
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        // ========== 参数网格 ==========
        GridLayout {
            id: gridLayout
            width: paramScrollView.width * 0.9  // ✅ 2026-02-07 [Phase 7.39.8]: 修复宽度绑定，参考串口配置
            columns: 2
            rowSpacing: 12
            columnSpacing: 16

            Component.onCompleted: {
                console.log("✅ [CANParamsTab] GridLayout 加载完成")
                console.log("   - columns:", columns)
                console.log("   - width:", width)
                console.log("   - paramScrollView.width:", paramScrollView.width)
                console.log("   - columnSpacing:", columnSpacing)
                console.log("   - rowSpacing:", rowSpacing)
            }

            // ========== 行0：CAN接口、波特率 ==========
            // 索引 0: CAN接口（只读）
            Item {
                Layout.column: 0
                Layout.row: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 60  // ✅ 2026-02-07 [Phase 7.39.12]: 与 CustomComboBox 高度一致

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "CAN 接口:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        Layout.preferredHeight: 60  // ✅ 2026-02-07 [Phase 7.39.12]: 与 CustomComboBox 高度一致

                        // ✅ 2026-02-07 [Phase 7.39.12]: 添加背景图片
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: "../images/034.png"
                                fillMode: Image.Stretch
                                z: -1
                            }
                        }

                        TextField {
                            id: canInterfaceText
                            anchors.fill: parent
                            text: currentCanInterface ? currentCanInterface.devicePath : ""
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 15
                            readOnly: true

                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                color: "transparent"
                                border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 0) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }
                    }
                }
            }

            // 索引 1: 波特率（可编辑）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                implicitHeight: bitrateCombo.implicitHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "波特率:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    // ✅ 2026-02-07 [Phase 7.39.12]: 使用 CustomComboBox
                    DeviceInfo.CustomComboBox {
                        id: bitrateCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        model: ["125000", "250000", "500000", "1000000"]
                        currentIndex: {
                            if (typeof canController === 'undefined') return 2
                            var bitrate = canController.bitrate
                            switch(bitrate) {
                            case 125000: return 0
                            case 250000: return 1
                            case 500000: return 2
                            case 1000000: return 3
                            default: return 2
                            }
                        }

                        onActivated: {
                            if (typeof canController !== 'undefined') {
                                var newBitrate = parseInt(model[index])
                                console.log("✅ [CANParamsTab] 波特率变化:", newBitrate)
                                canController.bitrate = newBitrate
                            }
                        }
                    }

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: bitrateCombo
                        color: "transparent"
                        border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 1) ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行1：状态、帧类型 ==========
            // 索引 2: 状态（只读）
            Item {
                Layout.column: 0
                Layout.row: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 60  // ✅ 2026-02-07 [Phase 7.39.12]: 与 CustomComboBox 高度一致

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "状态:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        Layout.preferredHeight: 60  // ✅ 2026-02-07 [Phase 7.39.12]: 与 CustomComboBox 高度一致

                        // ✅ 2026-02-07 [Phase 7.39.12]: 添加背景图片
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: "../images/034.png"
                                fillMode: Image.Stretch
                                z: -1
                            }
                        }

                        TextField {
                            id: statusText
                            anchors.fill: parent
                            text: typeof canController !== 'undefined' ? canController.status : ""
                            font.pixelSize: 21
                            color: (typeof canController !== 'undefined' && canController.isUp) ? "#4CAF50" : "#9E9E9E"
                            font.weight: Font.Bold
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 15
                            readOnly: true

                            // ✅ 2026-02-07 [Phase 7.39.16]: 添加调试日志
                            Component.onCompleted: {
                                console.log("🔍 [CANParamsTab] statusText 初始化")
                                console.log("   - canController 是否存在:", typeof canController !== 'undefined')
                                if (typeof canController !== 'undefined') {
                                    console.log("   - canController.status:", canController.status)
                                    console.log("   - canController.isUp:", canController.isUp)
                                }
                            }

                            Connections {
                                target: typeof canController !== 'undefined' ? canController : null
                                function onStatusChanged() {
                                    console.log("🔍 [CANParamsTab] canController.status 变化:", canController.status)
                                }
                            }

                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                color: "transparent"
                                border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 2) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }
                    }
                }
            }

            // 索引 3: 帧类型（可编辑）
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                implicitHeight: frameTypeCombo.implicitHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "帧类型:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    // ✅ 2026-02-07 [Phase 7.39.12]: 使用 CustomComboBox
                    DeviceInfo.CustomComboBox {
                        id: frameTypeCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        model: ["标准帧", "扩展帧"]
                        currentIndex: (typeof canController !== 'undefined' && canController.frameType === "标准帧") ? 0 : 1

                        onActivated: {
                            if (typeof canController !== 'undefined') {
                                var newFrameType = model[index]
                                console.log("✅ [CANParamsTab] 帧类型变化:", newFrameType)
                                canController.frameType = newFrameType
                            }
                        }
                    }

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: frameTypeCombo
                        color: "transparent"
                        border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 3) ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }
        }
    }
}
