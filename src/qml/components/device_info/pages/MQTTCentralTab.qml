// MQTTCentralTab.qml
// MQTT集控配置Tab
// ✅ 2026-04-11 [Phase 7.48.88.110]: 集控管理——MQTT Broker配置
// ✅ 2026-04-14 [Phase 7.48.88.120]: 键盘导航焦点指示器
// ✅ 2026-04-14 [Phase 7.48.88.121]: 字体/尺寸统一 + 虚拟键盘调用修复

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    property int focusParamIndex: -1
    property int focusSubArea: 0
    property var virtualKeyboard: null
    property var parentDialog: null

    property string brokerIP:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttBrokerIP    : "192.168.1.1"
    property int    brokerPort:  typeof centralControlManager !== "undefined" ? centralControlManager.mqttBrokerPort  : 1883
    property string clientId:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttClientId    : "belt_central_1"
    property int    qosLevel:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttQos         : 1
    property int    keepAlive:   typeof centralControlManager !== "undefined" ? centralControlManager.mqttKeepAlive   : 60
    property string topicPrefix: typeof centralControlManager !== "undefined" ? centralControlManager.mqttTopicPrefix : "belt/central/"
    property string username:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttUsername    : ""
    property string password:    typeof centralControlManager !== "undefined" ? centralControlManager.mqttPassword    : ""

    function focusBorderColor(i) { return (focusSubArea === 2 && focusParamIndex === i) ? "#2196F3" : "transparent" }
    function focusBorderWidth(i) { return (focusSubArea === 2 && focusParamIndex === i) ? 2 : 0 }

    function getParamFieldCount() { return 8 }

    // ✅ 2026-04-14 [Phase 7.48.88.121]: 使用 activateVirtualKeyboard() 触发Qt自带虚拟键盘
    function triggerParamInput(index) {
        function activate(field) {
            if (field && field.activateVirtualKeyboard) field.activateVirtualKeyboard()
            else if (field) field.forceActiveFocus()
        }
        switch(index) {
        case 0: activate(brokerIPField);    break
        case 1: activate(brokerPortField);  break
        case 2: activate(clientIdField);    break
        case 3:
            qosField.currentIndex = (qosField.currentIndex + 1) % qosField.count
            if (typeof centralControlManager !== "undefined") centralControlManager.mqttQos = qosField.currentIndex
            break
        case 4: activate(keepAliveField);   break
        case 5: activate(topicPrefixField); break
        case 6: activate(usernameField);    break
        case 7: activate(passwordField);    break
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true

        GridLayout {
            width: parent.width - 20
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            // ----- 参数0: Broker IP -----
            Text { text: "Broker IP:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
                DeviceInfo.CustomTextField {
                    id: brokerIPField; anchors.fill: parent; text: root.brokerIP
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttBrokerIP = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(0); border.width: root.focusBorderWidth(0)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数1: Broker端口 -----
            Text { text: "Broker端口:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
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
            Text { text: "Client ID:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
                DeviceInfo.CustomTextField {
                    id: clientIdField; anchors.fill: parent; text: root.clientId
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttClientId = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(2); border.width: root.focusBorderWidth(2)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数3: QoS -----
            Text { text: "QoS:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
                DeviceInfo.CustomComboBox {
                    id: qosField; anchors.fill: parent
                    model: ["QoS 0", "QoS 1", "QoS 2"]
                    currentIndex: root.qosLevel
                    parentDialog: root.parentDialog
                    onActivated: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttQos = currentIndex }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(3); border.width: root.focusBorderWidth(3)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数4: Keep-alive -----
            Text { text: "Keep-alive(秒):"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
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
            Text { text: "Topic前缀:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
                DeviceInfo.CustomTextField {
                    id: topicPrefixField; anchors.fill: parent; text: root.topicPrefix
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttTopicPrefix = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(5); border.width: root.focusBorderWidth(5)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数6: 用户名 -----
            Text { text: "用户名:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
                DeviceInfo.CustomTextField {
                    id: usernameField; anchors.fill: parent; text: root.username
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttUsername = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(6); border.width: root.focusBorderWidth(6)
                    radius: 4; z: 1; enabled: false }
            }

            // ----- 参数7: 密码 -----
            Text { text: "密码:"; font.pixelSize: 21; color: "#9E9E9E"
                   Layout.preferredWidth: 160; horizontalAlignment: Text.AlignRight }
            Item {
                Layout.preferredWidth: 200; Layout.preferredHeight: 48
                DeviceInfo.CustomTextField {
                    id: passwordField; anchors.fill: parent; text: root.password
                    echoMode: TextInput.Password
                    onTextChanged: { if (typeof centralControlManager !== "undefined") centralControlManager.mqttPassword = text }
                }
                Rectangle { anchors.fill: parent; color: "transparent"
                    border.color: root.focusBorderColor(7); border.width: root.focusBorderWidth(7)
                    radius: 4; z: 1; enabled: false }
            }

            // ✅ 2026-04-14 [Phase 7.48.88.132]: MQTT集控连接状态区
            Rectangle {
                Layout.columnSpan: 4; Layout.fillWidth: true
                Layout.preferredHeight: 56; Layout.topMargin: 10
                color: "#0d1520"; radius: 4
                border.color: {
                    if (typeof mqttController === "undefined") return "#3d4556"
                    return mqttController.isModuleConnected(7) ? "#388E3C" : "#C62828"
                }
                border.width: 2

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 12

                    // 状态灯
                    // ✅ 2026-04-14 [Phase 7.48.88.133]: isModuleConnecting 非 Q_INVOKABLE，改用 getModuleConnectionState
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        color: {
                            if (typeof mqttController === "undefined") return "#555"
                            if (mqttController.isModuleConnected(7)) return "#4CAF50"
                            var state = mqttController.getModuleConnectionState(7)
                            if (state === "Connecting" || state === "正在连接") return "#FFA726"
                            return "#F44336"
                        }
                    }

                    // 状态文字
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (typeof mqttController === "undefined") return "MQTT模块7: 未知状态"
                            var ip = (typeof centralControlManager !== "undefined")
                                     ? centralControlManager.mqttBrokerIP : ""
                            var port = (typeof centralControlManager !== "undefined")
                                       ? centralControlManager.mqttBrokerPort : 1883
                            if (mqttController.isModuleConnected(7))
                                return "MQTT模块7 已连接  " + ip + ":" + port
                            var state = mqttController.getModuleConnectionState(7)
                            if (!ip || ip === "") return "MQTT模块7 未连接 — 请先填写Broker IP地址"
                            if (state === "Connecting" || state === "正在连接")
                                return "MQTT模块7 连接中…  " + ip + ":" + port
                            return "MQTT模块7 未连接  " + ip + ":" + port
                                   + (state ? "  [" + state + "]" : "")
                        }
                        color: {
                            if (typeof mqttController === "undefined") return "#78909C"
                            if (mqttController.isModuleConnected(7)) return "#A5D6A7"
                            var state = mqttController.getModuleConnectionState(7)
                            if (state === "Connecting" || state === "正在连接") return "#FFB74D"
                            return "#EF9A9A"
                        }
                        font.pixelSize: 13
                    }

                    // 配置校验提示
                    Text {
                        visible: typeof centralControlManager !== "undefined"
                                 && centralControlManager.mqttBrokerIP === ""
                        text: "⚠ 未填写Broker地址"
                        color: "#FFB74D"; font.pixelSize: 12
                    }
                }
            }

            // ----- 说明 -----
            Rectangle {
                Layout.columnSpan: 4; Layout.fillWidth: true
                Layout.preferredHeight: 70; Layout.topMargin: 8
                color: "#1a2030"; radius: 4; border.color: "#3d4556"; border.width: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Text { text: "MQTT集控说明"; color: "#4FC3F7"; font.pixelSize: 14; font.weight: Font.Bold }
                    Text { text: "集控专用MQTT模块7（模块0-6已被数据采集占用）"; color: "#90A4AE"; font.pixelSize: 12 }
                    Text { text: "确保所有集控设备使用相同的Broker地址和Topic前缀"; color: "#90A4AE"; font.pixelSize: 12 }
                }
                }
            }
        }
    }
}
