// MQTTPublishTab.qml
// MQTT 发布消息 Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.3]: 重构布局，参照 ModbusTCPMasterTab.qml
// ✅ 2026-02-08 [Phase 7.43.6]: 修复QML语法错误

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    property var currentModule: null
    property int focusParamIndex: -1
    property var virtualKeyboard: null

    signal requestFocusParamIndex(int paramIndex)

    // 发布参数
    property string publishTopic: ""
    property int publishQos: 1
    property bool publishRetain: false
    property string publishMessage: ""

    function getParamFieldCount() { return 6 }

    function triggerParamInput(paramIndex) {
        console.log("✅ [MQTTPublishTab] triggerParamInput:", paramIndex)
        if (paramIndex === 0) {
            if (topicField.activateVirtualKeyboard) topicField.activateVirtualKeyboard()
            else topicField.forceActiveFocus()
        } else if (paramIndex === 1) {
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.model.length
        } else if (paramIndex === 2) {
            retainField.currentIndex = (retainField.currentIndex + 1) % retainField.model.length
        } else if (paramIndex === 3) {
            if (messageField.activateVirtualKeyboard) messageField.activateVirtualKeyboard()
            else messageField.forceActiveFocus()
        } else if (paramIndex === 4) {
            publishButton.clicked()
        } else if (paramIndex === 5) {
            clearButton.clicked()
        }
    }

    function handleEnterKey() {
        if (focusParamIndex === 1) {
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.model.length
            return true
        }
        if (focusParamIndex === 2) {
            retainField.currentIndex = (retainField.currentIndex + 1) % retainField.model.length
            return true
        }
        if (focusParamIndex === 4) {
            publishButton.clicked()
            return true
        }
        if (focusParamIndex === 5) {
            clearButton.clicked()
            return true
        }
        return false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ========== 发布配置区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            color: "#252b3d"
            radius: 4

            GridLayout {
                anchors.fill: parent
                anchors.margins: 15
                columns: 4
                columnSpacing: 15
                rowSpacing: 12

                // 行 0: 主题
                Text {
                    text: "主题:"
                    font.pixelSize: 21
                    color: "#9E9E9E"
                    Layout.preferredWidth: 80
                }

                Item {
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    Layout.preferredHeight: 60

                    DeviceInfo.CustomTextField {
                        id: topicField
                        anchors.fill: parent
                        text: root.publishTopic
                        onTextChanged: root.publishTopic = text
                        placeholderText: "belt_control/module1/command"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(0)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 0 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 0 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 行 1: QoS / Retain / 按钮
                Text {
                    text: "QoS:"
                    font.pixelSize: 21
                    color: "#9E9E9E"
                    Layout.preferredWidth: 80
                }

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    DeviceInfo.CustomComboBox {
                        id: qosField
                        anchors.fill: parent
                        model: ["0", "1", "2"]
                        currentIndex: root.publishQos
                        onCurrentIndexChanged: root.publishQos = currentIndex
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(1)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 1 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 1 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                Text {
                    text: "保留:"
                    font.pixelSize: 21
                    color: "#9E9E9E"
                    Layout.preferredWidth: 80
                }

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    DeviceInfo.CustomComboBox {
                        id: retainField
                        anchors.fill: parent
                        model: ["否", "是"]
                        currentIndex: root.publishRetain ? 1 : 0
                        onCurrentIndexChanged: root.publishRetain = (currentIndex === 1)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(2)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 2 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 2 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 行 2: 按钮
                Item {
                    Layout.preferredWidth: 80
                }

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    Button {
                        id: publishButton
                        anchors.fill: parent
                        text: "发布"

                        background: Rectangle {
                            color: root.focusParamIndex === 4 ? "#4CAF50" : "#388E3C"
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 18
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [MQTTPublishTab] 发布消息")
                            historyModel.insert(0, {
                                topic: topicField.text,
                                message: messageField.text,
                                qos: qosField.currentIndex,
                                retain: retainField.currentIndex === 1,
                                timestamp: new Date().toLocaleTimeString()
                            })
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(4)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 4 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 4 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                Item {
                    Layout.preferredWidth: 80
                }

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    Button {
                        id: clearButton
                        anchors.fill: parent
                        text: "清空"

                        background: Rectangle {
                            color: root.focusParamIndex === 5 ? "#FF9800" : "#F57C00"
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 18
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            console.log("✅ [MQTTPublishTab] 清空消息")
                            messageField.text = ""
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(5)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 5 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 5 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }
            }
        }

        // ========== 消息内容区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: "#252b3d"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "消息内容"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    DeviceInfo.CustomTextField {
                        id: messageField
                        anchors.fill: parent
                        text: root.publishMessage
                        onTextChanged: root.publishMessage = text
                        placeholderText: "输入要发布的消息内容（支持 JSON 格式）"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(3)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 3 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 3 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }
            }
        }

        // ========== 发布历史区域 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#252b3d"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "发布历史"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#E0E0E0"
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "清空历史"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 35

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#d32f2f")
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: historyModel.clear()
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2

                    model: ListModel {
                        id: historyModel
                    }

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 60
                        color: index % 2 === 0 ? "#2a3142" : "#252b3d"
                        radius: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: model.topic
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: "#4CAF50"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "QoS:" + model.qos + (model.retain ? " [R]" : "")
                                    font.pixelSize: 12
                                    color: "#808080"
                                }

                                Text {
                                    text: model.timestamp
                                    font.pixelSize: 12
                                    color: "#606060"
                                }
                            }

                            Text {
                                text: model.message
                                font.pixelSize: 13
                                color: "#B0B0B0"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
