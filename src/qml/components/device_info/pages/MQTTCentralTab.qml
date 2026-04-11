// MQTTCentralTab.qml
// MQTT集控配置Tab - Broker参数配置
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——MQTT Broker配置

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: -1
    property int focusSubArea: 0
    property var virtualKeyboard: null

    // ========== 参数数据 ==========
    property string brokerIP: typeof centralControlManager !== "undefined"
                              ? centralControlManager.mqttBrokerIP : "192.168.1.1"
    property int brokerPort: typeof centralControlManager !== "undefined"
                             ? centralControlManager.mqttBrokerPort : 1883
    property string clientId: typeof centralControlManager !== "undefined"
                              ? centralControlManager.mqttClientId : "belt_central_1"
    property int qosLevel: typeof centralControlManager !== "undefined"
                           ? centralControlManager.mqttQos : 1
    property int keepAlive: typeof centralControlManager !== "undefined"
                            ? centralControlManager.mqttKeepAlive : 60
    property string topicPrefix: typeof centralControlManager !== "undefined"
                                 ? centralControlManager.mqttTopicPrefix : "belt/central/"
    property string username: typeof centralControlManager !== "undefined"
                              ? centralControlManager.mqttUsername : ""
    property string password: typeof centralControlManager !== "undefined"
                              ? centralControlManager.mqttPassword : ""

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 8
    }

    function triggerParamInput(index) {
        console.log("✅ [MQTTCentralTab] triggerParamInput:", index)

        switch(index) {
        case 0:  // Broker IP (TextField)
            if (root.virtualKeyboard && brokerIPField) {
                root.virtualKeyboard.targetInput = brokerIPField
                root.virtualKeyboard.show()
            }
            break
        case 1:  // Broker端口 (SpinBox)
            if (root.virtualKeyboard && brokerPortField) {
                root.virtualKeyboard.targetInput = brokerPortField
                root.virtualKeyboard.show()
            }
            break
        case 2:  // Client ID (TextField)
            if (root.virtualKeyboard && clientIdField) {
                root.virtualKeyboard.targetInput = clientIdField
                root.virtualKeyboard.show()
            }
            break
        case 3:  // QoS (ComboBox切换)
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.model.length
            if (typeof centralControlManager !== "undefined") {
                centralControlManager.mqttQos = qosField.currentIndex
            }
            break
        case 4:  // Keep-alive (SpinBox)
            if (root.virtualKeyboard && keepAliveField) {
                root.virtualKeyboard.targetInput = keepAliveField
                root.virtualKeyboard.show()
            }
            break
        case 5:  // Topic前缀 (TextField)
            if (root.virtualKeyboard && topicPrefixField) {
                root.virtualKeyboard.targetInput = topicPrefixField
                root.virtualKeyboard.show()
            }
            break
        case 6:  // 用户名 (TextField)
            if (root.virtualKeyboard && usernameField) {
                root.virtualKeyboard.targetInput = usernameField
                root.virtualKeyboard.show()
            }
            break
        case 7:  // 密码 (TextField)
            if (root.virtualKeyboard && passwordField) {
                root.virtualKeyboard.targetInput = passwordField
                root.virtualKeyboard.show()
            }
            break
        }
    }

    // ========== 布局 ==========
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        GridLayout {
            width: parent.width - 20
            columns: 4
            columnSpacing: 10
            rowSpacing: 8

            // ===== 参数0: Broker IP =====
            Text {
                text: "Broker IP"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomTextField {
                id: brokerIPField
                Layout.preferredWidth: 160
                Layout.preferredHeight: 36
                text: root.brokerIP
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 0
                onTextChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttBrokerIP = text
                    }
                }
            }

            // ===== 参数1: Broker端口 =====
            Text {
                text: "Broker端口"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomSpinBox {
                id: brokerPortField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                from: 1
                to: 65535
                value: root.brokerPort
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 1
                onValueChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttBrokerPort = value
                    }
                }
            }

            // ===== 参数2: Client ID =====
            Text {
                text: "Client ID"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomTextField {
                id: clientIdField
                Layout.preferredWidth: 160
                Layout.preferredHeight: 36
                text: root.clientId
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 2
                onTextChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttClientId = text
                    }
                }
            }

            // ===== 参数3: QoS =====
            Text {
                text: "QoS"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomComboBox {
                id: qosField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                model: ["QoS 0", "QoS 1", "QoS 2"]
                currentIndex: root.qosLevel
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 3
            }

            // ===== 参数4: Keep-alive =====
            Text {
                text: "Keep-alive(秒)"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomSpinBox {
                id: keepAliveField
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                from: 10
                to: 600
                value: root.keepAlive
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 4
                onValueChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttKeepAlive = value
                    }
                }
            }

            // ===== 参数5: Topic前缀 =====
            Text {
                text: "Topic前缀"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomTextField {
                id: topicPrefixField
                Layout.preferredWidth: 160
                Layout.preferredHeight: 36
                text: root.topicPrefix
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 5
                onTextChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttTopicPrefix = text
                    }
                }
            }

            // ===== 参数6: 用户名 =====
            Text {
                text: "用户名"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomTextField {
                id: usernameField
                Layout.preferredWidth: 160
                Layout.preferredHeight: 36
                text: root.username
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 6
                onTextChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttUsername = text
                    }
                }
            }

            // ===== 参数7: 密码 =====
            Text {
                text: "密码"
                color: "#B0BEC5"
                font.pixelSize: 13
                Layout.preferredWidth: 120
            }
            DeviceInfo.CustomTextField {
                id: passwordField
                Layout.preferredWidth: 160
                Layout.preferredHeight: 36
                text: root.password
                echoMode: TextInput.Password
                highlighted: root.focusSubArea === 2 && root.focusParamIndex === 7
                onTextChanged: {
                    if (typeof centralControlManager !== "undefined") {
                        centralControlManager.mqttPassword = text
                    }
                }
            }

            // ===== MQTT说明 =====
            Rectangle {
                Layout.columnSpan: 4
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.topMargin: 20
                color: "#1a2030"
                radius: 4
                border.color: "#3d4556"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "MQTT集控说明"
                        color: "#4FC3F7"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "同类型设备之间通过MQTT Broker交换状态和控制数据"
                        color: "#90A4AE"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "确保所有集控设备使用相同的Broker地址和Topic前缀"
                        color: "#90A4AE"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
