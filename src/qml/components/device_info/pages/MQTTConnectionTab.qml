// MQTTConnectionTab.qml
// MQTT 连接配置 Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.2]: 重构布局，参照 ModbusTCPMasterTab.qml

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentModule: null
    property int focusParamIndex: -1
    property var virtualKeyboard: null

    // ========== 信号 ==========
    signal requestFocusParamIndex(int paramIndex)

    // ========== 参数数据 ==========
    property string brokerHost: "192.168.10.1"
    property int brokerPort: 1883
    property string clientId: "belt_control_module_1"
    property string username: ""
    property string password: ""
    property int keepAlive: 60
    property bool cleanSession: true
    property int defaultQos: 1
    property bool isConnected: false

    // ========== 获取参数数量 ==========
    function getParamFieldCount() {
        return 9  // 9个参数
    }

    // ========== 触发参数输入 ==========
    function triggerParamInput(paramIndex) {
        console.log("✅ [MQTTConnectionTab] triggerParamInput:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // Broker 地址（CustomTextField）
            inputField = brokerHostField
            break
        case 1:  // 端口（CustomSpinBox）
            inputField = brokerPortField
            break
        case 2:  // 客户端 ID（CustomTextField）
            inputField = clientIdField
            break
        case 3:  // 用户名（CustomTextField）
            inputField = usernameField
            break
        case 4:  // 密码（CustomTextField）
            inputField = passwordField
            break
        case 5:  // Keep Alive（CustomSpinBox）
            inputField = keepAliveField
            break
        case 6:  // Clean Session（CustomComboBox）
            console.log("✅ [MQTTConnectionTab] 切换 Clean Session")
            cleanSessionField.currentIndex = (cleanSessionField.currentIndex + 1) % cleanSessionField.model.length
            return
        case 7:  // 默认 QoS（CustomComboBox）
            console.log("✅ [MQTTConnectionTab] 切换默认 QoS")
            defaultQosField.currentIndex = (defaultQosField.currentIndex + 1) % defaultQosField.model.length
            return
        case 8:  // 状态（只读）
            return
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [MQTTConnectionTab] 激活虚拟键盘 - 控件:", inputField)
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                inputField.forceActiveFocus()
            }
        }
    }

    // ========== 回车键处理 ==========
    function handleEnterKey() {
        console.log("✅ [MQTTConnectionTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // ComboBox 切换选项
        if (focusParamIndex === 6) {  // Clean Session
            cleanSessionField.currentIndex = (cleanSessionField.currentIndex + 1) % cleanSessionField.model.length
            return true
        } else if (focusParamIndex === 7) {  // 默认 QoS
            defaultQosField.currentIndex = (defaultQosField.currentIndex + 1) % defaultQosField.model.length
            return true
        } else if (focusParamIndex === 8) {  // 状态（只读）
            return true
        }

        // 其他输入框返回 false，让 DeviceSettingsDialog 调用 triggerParamInput
        return false
    }

    // ========== 滚动视图 ==========
    ScrollView {
        id: paramScrollView
        anchors.fill: parent
        clip: true

        GridLayout {
            width: paramScrollView.width * 0.9
            columns: 4
            columnSpacing: 10
            rowSpacing: 12

            // ========== 第一行：Broker 地址（左侧，索引0）、端口（右侧，索引1）==========

            // Broker 地址标签
            Text {
                text: "Broker 地址:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Broker 地址输入
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: brokerHostField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: brokerHostField
                    anchors.fill: parent
                    text: root.brokerHost
                    onTextChanged: root.brokerHost = text
                    placeholderText: "192.168.10.1"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击 Broker 地址，发射信号: requestFocusParamIndex(0)")
                        root.requestFocusParamIndex(0)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 端口标签
            Text {
                text: "端口:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 端口输入
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: brokerPortField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: brokerPortField
                    anchors.fill: parent
                    from: 1
                    to: 65535
                    value: root.brokerPort
                    onValueChanged: root.brokerPort = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击端口，发射信号: requestFocusParamIndex(1)")
                        root.requestFocusParamIndex(1)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 1) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第二行：客户端 ID（左侧，索引2）、用户名（右侧，索引3）==========

            // 客户端 ID 标签
            Text {
                text: "客户端 ID:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 客户端 ID 输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: clientIdField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: clientIdField
                    anchors.fill: parent
                    text: root.clientId
                    onTextChanged: root.clientId = text
                    placeholderText: "belt_control_module_1"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击客户端 ID，发射信号: requestFocusParamIndex(2)")
                        root.requestFocusParamIndex(2)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 用户名标签
            Text {
                text: "用户名:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 用户名输入
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: usernameField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: usernameField
                    anchors.fill: parent
                    text: root.username
                    onTextChanged: root.username = text
                    placeholderText: "可选"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击用户名，发射信号: requestFocusParamIndex(3)")
                        root.requestFocusParamIndex(3)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第三行：密码（左侧，索引4）、Keep Alive（右侧，索引5）==========

            // 密码标签
            Text {
                text: "密码:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 密码输入
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: passwordField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: passwordField
                    anchors.fill: parent
                    text: root.password
                    onTextChanged: root.password = text
                    placeholderText: "可选"
                    echoMode: TextInput.Password
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击密码，发射信号: requestFocusParamIndex(4)")
                        root.requestFocusParamIndex(4)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // Keep Alive 标签
            Text {
                text: "心跳间隔:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Keep Alive 输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: keepAliveRow.implicitHeight

                Row {
                    id: keepAliveRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: keepAliveField
                        width: parent.width - 30
                        height: 60
                        from: 0
                        to: 65535
                        value: root.keepAlive
                        onValueChanged: root.keepAlive = value
                    }

                    Text {
                        text: "秒"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击心跳间隔，发射信号: requestFocusParamIndex(5)")
                        root.requestFocusParamIndex(5)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第四行：Clean Session（左侧，索引6）、默认 QoS（右侧，索引7）==========

            // Clean Session 标签
            Text {
                text: "清除会话:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Clean Session 输入（下拉框）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: cleanSessionField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: cleanSessionField
                    anchors.fill: parent
                    model: ["是", "否"]
                    currentIndex: root.cleanSession ? 0 : 1
                    onCurrentIndexChanged: root.cleanSession = (currentIndex === 0)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击清除会话，发射信号: requestFocusParamIndex(6)")
                        root.requestFocusParamIndex(6)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 默认 QoS 标签
            Text {
                text: "默认 QoS:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 默认 QoS 输入（下拉框）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: defaultQosField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: defaultQosField
                    anchors.fill: parent
                    model: ["0 - 最多一次", "1 - 至少一次", "2 - 恰好一次"]
                    currentIndex: root.defaultQos
                    onCurrentIndexChanged: root.defaultQos = currentIndex
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击默认 QoS，发射信号: requestFocusParamIndex(7)")
                        root.requestFocusParamIndex(7)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第五行：连接状态（左侧，索引8）==========

            // 连接状态标签
            Text {
                text: "连接状态:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 连接状态显示
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.columnSpan: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 600
                implicitHeight: 60

                Rectangle {
                    anchors.fill: parent
                    color: "#2a3142"
                    radius: 4

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // 状态指示灯
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isConnected ? "#4CAF50" : "#9E9E9E"
                        }

                        Text {
                            text: root.isConnected ? "已连接" : "未连接"
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [MQTTConnectionTab] 鼠标点击连接状态，发射信号: requestFocusParamIndex(8)")
                        root.requestFocusParamIndex(8)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }
        }  // GridLayout 结束
    }  // ScrollView 结束
}
