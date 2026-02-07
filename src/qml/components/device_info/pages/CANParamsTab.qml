// CANParamsTab.qml
// CAN 参数配置 Tab
// 创建日期: 2026-02-07

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        // ========== 参数网格 ==========
        GridLayout {
            width: parent.width * 0.9
            columns: 2
            rowSpacing: 12
            columnSpacing: 16

            // ========== 行0：CAN接口、波特率 ==========
            // 索引 0: CAN接口（只读）
            Item {
                Layout.column: 0
                Layout.row: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 40

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
                        Layout.preferredHeight: 40

                        TextField {
                            id: canInterfaceText
                            anchors.fill: parent
                            text: canController.canInterface
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            verticalAlignment: Text.AlignVCenter
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

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        Layout.preferredHeight: 40

                        ComboBox {
                            id: bitrateCombo
                            anchors.fill: parent
                            model: ["125000", "250000", "500000", "1000000"]
                            currentIndex: {
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
                                var newBitrate = parseInt(model[index])
                                console.log("✅ [CANParamsTab] 波特率变化:", newBitrate)
                                canController.bitrate = newBitrate
                            }

                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }

                            contentItem: Text {
                                text: bitrateCombo.displayText
                                font.pixelSize: 21
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                color: "transparent"
                                border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                                border.width: (root.focusParamIndex === 1) ? 3 : 0
                                radius: 4
                                z: 10
                            }
                        }
                    }
                }
            }

            // ========== 行1：状态、帧类型 ==========
            // 索引 2: 状态（只读）
            Item {
                Layout.column: 0
                Layout.row: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 40

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
                        Layout.preferredHeight: 40

                        TextField {
                            id: statusText
                            anchors.fill: parent
                            text: canController.status
                            font.pixelSize: 21
                            color: canController.isUp ? "#4CAF50" : "#9E9E9E"
                            font.weight: Font.Bold
                            verticalAlignment: Text.AlignVCenter
                            readOnly: true

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

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        Layout.preferredHeight: 40

                        ComboBox {
                            id: frameTypeCombo
                            anchors.fill: parent
                            model: ["标准帧", "扩展帧"]
                            currentIndex: canController.frameType === "标准帧" ? 0 : 1

                            onActivated: {
                                var newFrameType = model[index]
                                console.log("✅ [CANParamsTab] 帧类型变化:", newFrameType)
                                canController.frameType = newFrameType
                            }

                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }

                            contentItem: Text {
                                text: frameTypeCombo.displayText
                                font.pixelSize: 21
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
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
    }
}
