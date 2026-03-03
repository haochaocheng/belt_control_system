// MQTTSubscribeTab.qml
// MQTT 订阅主题 Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.2]: 重构布局，参照 ModbusTCPMasterTab.qml
// ✅ 2026-02-08 [Phase 7.43.6]: 修复QML语法错误
// ✅ 2026-02-08 [Phase 7.43.11]: 完善与MQTTController的绑定

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
            doSubscribe()
        } else if (paramIndex === 3) {
            doUnsubscribe()
        }
    }

    function handleEnterKey() {
        if (focusParamIndex === 1) {
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.model.length
            return true
        }
        if (focusParamIndex === 2) {
            doSubscribe()
            return true
        }
        if (focusParamIndex === 3) {
            doUnsubscribe()
            return true
        }
        return false
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 订阅函数
    function doSubscribe() {
        if (subscribeTopic.length === 0) {
            console.log("⚠️ [MQTTSubscribeTab] 主题不能为空")
            return
        }
        console.log("✅ [MQTTSubscribeTab] 订阅主题:", subscribeTopic, "QoS:", subscribeQos)
        if (mqttController) {
            var success = mqttController.subscribe(subscribeTopic, subscribeQos)
            if (success) {
                // 添加到本地列表显示
                subscribedModel.append({ topic: subscribeTopic, qos: subscribeQos })
                subscribeTopic = ""  // 清空输入
            } else {
                console.log("⚠️ [MQTTSubscribeTab] 订阅失败:", mqttController.lastError)
            }
        } else {
            // 模拟模式：直接添加到列表
            subscribedModel.append({ topic: subscribeTopic, qos: subscribeQos })
            subscribeTopic = ""
        }
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 取消订阅函数
    function doUnsubscribe() {
        if (subscribedListView.currentIndex < 0) {
            console.log("⚠️ [MQTTSubscribeTab] 请先选择要取消的主题")
            return
        }
        var topic = subscribedModel.get(subscribedListView.currentIndex).topic
        console.log("✅ [MQTTSubscribeTab] 取消订阅:", topic)
        if (mqttController) {
            mqttController.unsubscribe(topic)
        }
        subscribedModel.remove(subscribedListView.currentIndex)
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 监听控制器的订阅变化
    Connections {
        target: mqttController
        enabled: mqttController !== null
        // ✅ 2026-03-03 [Phase 7.47.78]: QDS 兼容 - QDS mock 无 onSubscriptionsChanged 信号
        ignoreUnknownSignals: true

        function onSubscriptionsChanged() {
            console.log("✅ [MQTTSubscribeTab] 订阅列表已更新")
            // 可以在这里同步控制器的订阅列表到本地模型
        }
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
                            doSubscribe()
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
                            doUnsubscribe()
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

                // ✅ 2026-02-08 [Phase 7.43.11]: 添加id以便取消订阅时使用
                ListView {
                    id: subscribedListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    currentIndex: -1  // 默认无选中

                    model: ListModel {
                        id: subscribedModel
                        ListElement { topic: "belt_control/module1/status"; qos: 1 }
                    }

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 50
                        // ✅ 2026-02-08 [Phase 7.43.11]: 选中高亮
                        color: subscribedListView.currentIndex === index ? "#3d4556" : (index % 2 === 0 ? "#2a3142" : "#252b3d")

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

                        // ✅ 2026-02-08 [Phase 7.43.11]: 点击选中
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                subscribedListView.currentIndex = index
                            }
                        }
                    }
                }
            }
        }
    }
}
