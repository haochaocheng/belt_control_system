import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.VirtualKeyboard

// Network Settings Section - Modbus TCP configuration
Rectangle {
    id: root
    color: "#1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // 连接状态属性
    property bool isConnected: false

    // 对外暴露连接/断开方法
    function connectToServer() {
        if (typeof networkTask !== 'undefined' && networkTask) {
            networkTask.start()
        }
    }

    function disconnectFromServer() {
        if (typeof networkTask !== 'undefined' && networkTask) {
            networkTask.stop()
        }
    }

    // 监听网络任务连接状态
    Connections {
        target: typeof networkTask !== 'undefined' ? networkTask : null
        function onConnectionStatusChanged(connected) {
            root.isConnected = connected
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Section title and status
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "模块网络参数"
                font.pixelSize: 20
                font.bold: true
                color: "#00d4ff"
                Layout.fillWidth: true
            }

            // Connection status indicator
            Rectangle {
                width: 100
                height: 30
                radius: 15
                color: root.isConnected ? "#27ae60" : "#c0392b"
                border.color: root.isConnected ? "#2ecc71" : "#e74c3c"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: root.isConnected ? "已连接" : "未连接"
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.5
        }

        // Modbus Server IP
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: "Modbus服务器IP:"
                font.pixelSize: 16
                color: "#ecf0f1"
                Layout.preferredWidth: 180
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: "#2c3e50"
                radius: 8
                border.color: serverIpField.activeFocus ? "#00ff88" : "#00d4ff"
                border.width: 2

                TextInput {
                    id: serverIpField
                    anchors.fill: parent
                    anchors.margins: 10
                    text: systemConfig.modbusServerIp
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    verticalAlignment: Text.AlignVCenter

                    onTextChanged: {
                        if (text !== systemConfig.modbusServerIp) {
                            systemConfig.modbusServerIp = text
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            Qt.inputMethod.show()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: serverIpField.forceActiveFocus()
                }
            }
        }

        // Gateway
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: "网关:"
                font.pixelSize: 16
                color: "#ecf0f1"
                Layout.preferredWidth: 180
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: "#2c3e50"
                radius: 8
                border.color: gatewayField.activeFocus ? "#00ff88" : "#00d4ff"
                border.width: 2

                TextInput {
                    id: gatewayField
                    anchors.fill: parent
                    anchors.margins: 10
                    text: systemConfig.modbusGateway
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    verticalAlignment: Text.AlignVCenter

                    onTextChanged: {
                        if (text !== systemConfig.modbusGateway) {
                            systemConfig.modbusGateway = text
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            Qt.inputMethod.show()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: gatewayField.forceActiveFocus()
                }
            }
        }

        // Subnet Mask
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: "子网掩码:"
                font.pixelSize: 16
                color: "#ecf0f1"
                Layout.preferredWidth: 180
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: "#2c3e50"
                radius: 8
                border.color: subnetMaskField.activeFocus ? "#00ff88" : "#00d4ff"
                border.width: 2

                TextInput {
                    id: subnetMaskField
                    anchors.fill: parent
                    anchors.margins: 10
                    text: systemConfig.modbusSubnetMask
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    verticalAlignment: Text.AlignVCenter

                    onTextChanged: {
                        if (text !== systemConfig.modbusSubnetMask) {
                            systemConfig.modbusSubnetMask = text
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            Qt.inputMethod.show()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: subnetMaskField.forceActiveFocus()
                }
            }
        }

        // Poll Interval
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: "轮询间隔(ms):"
                font.pixelSize: 16
                color: "#ecf0f1"
                Layout.preferredWidth: 180
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: "#2c3e50"
                radius: 8
                border.color: pollIntervalField.activeFocus ? "#00ff88" : "#00d4ff"
                border.width: 2

                TextInput {
                    id: pollIntervalField
                    anchors.fill: parent
                    anchors.margins: 10
                    text: systemConfig.modbusPollInterval
                    font.pixelSize: 16
                    color: "#ecf0f1"
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly

                    onTextChanged: {
                        var value = parseInt(text)
                        if (!isNaN(value) && value >= 10 && value !== systemConfig.modbusPollInterval) {
                            systemConfig.modbusPollInterval = value
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            Qt.inputMethod.show()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: pollIntervalField.forceActiveFocus()
                }
            }
        }

        // Connect/Disconnect buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            Layout.topMargin: 10

            Item { Layout.fillWidth: true }

            Button {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 45
                enabled: !root.isConnected

                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#1e8449" : (parent.hovered ? "#27ae60" : "#2ecc71")) : "#7f8c8d"
                    radius: 8
                    border.color: "#00d4ff"
                    border.width: 2
                }

                contentItem: Text {
                    text: "连接"
                    font.pixelSize: 18
                    font.bold: true
                    color: parent.enabled ? "#0a1628" : "#bdc3c7"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.connectToServer()
            }

            Button {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 45
                enabled: root.isConnected

                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#a93226" : (parent.hovered ? "#c0392b" : "#e74c3c")) : "#7f8c8d"
                    radius: 8
                    border.color: "#00d4ff"
                    border.width: 2
                }

                contentItem: Text {
                    text: "断开"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.disconnectFromServer()
            }

            Item { Layout.fillWidth: true }
        }
    }
}
