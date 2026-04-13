// MQTTCentralTab.qml
// MQTT集控配置Tab - Broker参数配置
// 创建日期: 2026-04-11
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——MQTT Broker配置
// ✅ 2026-04-14 [Phase 7.48.88.120]: 添加完整键盘导航焦点指示器

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
    property var parentDialog: null     // ✅ 供 CustomComboBox.parentDialog 使用

    // ========== 参数数据 ==========
    property string brokerIP:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttBrokerIP    : "192.168.1.1"
    property int    brokerPort:  typeof centralControlManager !== "undefined" ? centralControlManager.mqttBrokerPort  : 1883
    property string clientId:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttClientId    : "belt_central_1"
    property int    qosLevel:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttQos         : 1
    property int    keepAlive:   typeof centralControlManager !== "undefined" ? centralControlManager.mqttKeepAlive   : 60
    property string topicPrefix: typeof centralControlManager !== "undefined" ? centralControlManager.mqttTopicPrefix : "belt/central/"
    property string username:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttUsername    : ""
    property string password:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttPassword    : ""

    // ========== 辅助：焦点边框 ==========
    function focusBorderColor(paramIdx) {
        return (focusSubArea === 2 && focusParamIndex === paramIdx) ? "#2196F3" : "transparent"
    }
    function focusBorderWidth(paramIdx) {
        return (focusSubArea === 2 && focusParamIndex === paramIdx) ? 2 : 0
    }

    // ========== 函数 ==========
    function getParamFieldCount() { return 8 }

    function triggerParamInput(index) {
        switch(index) {
        case 0: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = brokerIPField;    root.virtualKeyboard.show() } break
        case 1: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = brokerPortField;  root.virtualKeyboard.show() } break
        case 2: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = clientIdField;    root.virtualKeyboard.show() } break
        case 3:
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.count
            if (typeof centralControlManager !== "undefined") centralControlManager.mqttQos = qosField.currentIndex
            break
        case 4: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = keepAliveField;   root.virtualKeyboard.show() } break
        case 5: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = topicPrefixField; root.virtualKeyboard.show() } break
        case 6: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = usernameField;    root.virtualKeyboard.show() } break
        case 7: if (root.virtualKeyboard) { root.virtualKeyboard.targetInput = passwordField;    root.virtualKeyboard.show() } break
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
            rowSpacing: 10

            // ----- 参数0: Broker IP -----
            Text { text: "Broker IP"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 160; Layout.preferredHeight: 36
                DeviceInfo.CustomTextField {
                    id: brokerIPField; anchors.fill: parent
                    text: root.brokerIP
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttBrokerIP = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(0); border.width: root.focusBorderWidth(0)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数1: Broker端口 -----
            Text { text: "Broker端口"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 36
                DeviceInfo.CustomSpinBox {
                    id: brokerPortField; anchors.fill: parent
                    from: 1; to: 65535; value: root.brokerPort
                    onValueChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttBrokerPort = value }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(1); border.width: root.focusBorderWidth(1)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数2: Client ID -----
            Text { text: "Client ID"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 160; Layout.preferredHeight: 36
                DeviceInfo.CustomTextField {
                    id: clientIdField; anchors.fill: parent
                    text: root.clientId
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttClientId = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(2); border.width: root.focusBorderWidth(2)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数3: QoS -----
            Text { text: "QoS"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 36
                DeviceInfo.CustomComboBox {
                    id: qosField; anchors.fill: parent
                    model: ["QoS 0", "QoS 1", "QoS 2"]
                    currentIndex: root.qosLevel
                    parentDialog: root.parentDialog
                    onActivated: {
                        if (typeof centralControlManager !== "undefined") centralControlManager.mqttQos = currentIndex
                    }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(3); border.width: root.focusBorderWidth(3)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数4: Keep-alive -----
            Text { text: "Keep-alive(秒)"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 36
                DeviceInfo.CustomSpinBox {
                    id: keepAliveField; anchors.fill: parent
                    from: 10; to: 600; value: root.keepAlive
                    onValueChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttKeepAlive = value }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(4); border.width: root.focusBorderWidth(4)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数5: Topic前缀 -----
            Text { text: "Topic前缀"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 160; Layout.preferredHeight: 36
                DeviceInfo.CustomTextField {
                    id: topicPrefixField; anchors.fill: parent
                    text: root.topicPrefix
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttTopicPrefix = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(5); border.width: root.focusBorderWidth(5)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数6: 用户名 -----
            Text { text: "用户名"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 160; Layout.preferredHeight: 36
                DeviceInfo.CustomTextField {
                    id: usernameField; anchors.fill: parent
                    text: root.username
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttUsername = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(6); border.width: root.focusBorderWidth(6)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数7: 密码 -----
            Text { text: "密码"; color: "#B0BEC5"; font.pixelSize: 13; Layout.preferredWidth: 120 }
            Item {
                Layout.preferredWidth: 160; Layout.preferredHeight: 36
                DeviceInfo.CustomTextField {
                    id: passwordField; anchors.fill: parent
                    text: root.password
                    echoMode: TextInput.Password
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttPassword = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(7); border.width: root.focusBorderWidth(7)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 说明 -----
            Rectangle {
                Layout.columnSpan: 4; Layout.fillWidth: true
                Layout.preferredHeight: 80; Layout.topMargin: 20
                color: "#1a2030"; radius: 4; border.color: "#3d4556"; border.width: 1

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 4
                    Text { text: "MQTT集控说明"; color: "#4FC3F7"; font.pixelSize: 14; font.weight: Font.Bold }
                    Text { text: "同类型设备之间通过MQTT Broker交换状态和控制数据"; color: "#90A4AE"; font.pixelSize: 12 }
                    Text { text: "确保所有集控设备使用相同的Broker地址和Topic前缀";  color: "#90A4AE"; font.pixelSize: 12 }
                }
            }
        }
    }
}
