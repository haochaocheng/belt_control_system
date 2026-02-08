// MQTTSubscribeTab.qml
// MQTT 订阅主题 Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.2]: 重构布局，参照 ModbusTCPMasterTab.qml
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

    property string subscribeTopic: ""
    property int subscribeQos: 1

    function getParamFieldCount() { return 4 }

    function triggerParamInput(paramIndex) {
        console.log("✅ [MQTTSubscribeTab] triggerParamInput:", paramIndex)
        if (paramIndex === 0) {
            if (topicField.activateVirtualKeyboard) topicField.activateVirtualKeyboard()
            else topicField.forceActiveFocus()
        } else if (paramIndex === 1) {
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.model.length
        } else if (paramIndex === 2) {
            subscribeButton.clicked()
        } else if (paramIndex === 3) {
            unsubscribeButton.clicked()
        }
    }

    function handleEnterKey() {
        if (focusParamIndex === 1) {
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.model.length
            return true
        }
        if (focusParamIndex === 2) {
            subscribeButton.clicked()
            return true
        }
        if (focusParamIndex === 3) {
            unsubscribeButton.clicked()
            return true
        }
        return false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#252b3d"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "主题:"
                    font.pixelSize: 21
                    color: "#9E9E9E"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60

                    DeviceInfo.CustomTextField {
                        id: topicField
                        anchors.fill: parent
                        text: root.subscribeTopic
                        onTextChanged: root.subscribeTopic = text
                        placeholderText: "belt_control/module1/status"
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

                Text {
                    text: "QoS:"
                    font.pixelSize: 21
                    color: "#9E9E9E"
                }

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    DeviceInfo.CustomComboBox {
                        id: qosField
                        anchors.fill: parent
                        model: ["0", "1", "2"]
                        currentIndex: root.subscribeQos
                        onCurrentIndexChanged: root.subscribeQos = currentIndex
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

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    Button {
                        id: subscribeButton
                        anchors.fill: parent
                        text: "订阅"

                        background: Rectangle {
                            color: root.focusParamIndex === 2 ? "#4CAF50" : "#388E3C"
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
                            subscribedModel.append({ topic: topicField.text, qos: qosField.currentIndex })
                        }
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

                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 60

                    Button {
                        id: unsubscribeButton
                        anchors.fill: parent
                        text: "取消"

                        background: Rectangle {
                            color: root.focusParamIndex === 3 ? "#f44336" : "#d32f2f"
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
                            console.log("取消订阅")
                        }
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

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#252b3d"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "已订阅主题"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#E0E0E0"
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    model: ListModel {
                        id: subscribedModel
                        ListElement { topic: "belt_control/module1/status"; qos: 1 }
                    }

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 50
                        color: index % 2 === 0 ? "#2a3142" : "#252b3d"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text {
                                text: model.topic
                                font.pixelSize: 16
                                color: "#E0E0E0"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "QoS: " + model.qos
                                font.pixelSize: 14
                                color: "#808080"
                            }
                        }
                    }
                }
            }
        }
    }
}
