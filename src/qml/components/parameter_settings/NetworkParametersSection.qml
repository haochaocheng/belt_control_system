import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Network Parameters Section Component
Rectangle {
    id: root
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    property var virtualKeyboardPopup: null

    // ✅ 2026-02-06 [参数持久化]: 配置对象（由父组件传递）
    property var networkConfig: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "网络参数设置"
            font.pixelSize: 20
            font.bold: true
            color: "#00d4ff"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#00d4ff"
            opacity: 0.5
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            ParameterRow {
                Layout.fillWidth: true
                label: "IP地址"
                value: networkConfig ? networkConfig.ipAddress : "192.168.1.100"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
                onFieldValueChanged: function(newValue) {
                    if (networkConfig) {
                        networkConfig.ipAddress = newValue
                    }
                }
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "子网掩码"
                value: networkConfig ? networkConfig.subnetMask : "255.255.255.0"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
                onFieldValueChanged: function(newValue) {
                    if (networkConfig) {
                        networkConfig.subnetMask = newValue
                    }
                }
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "网关"
                value: networkConfig ? networkConfig.gateway : "192.168.1.1"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
                onFieldValueChanged: function(newValue) {
                    if (networkConfig) {
                        networkConfig.gateway = newValue
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    component ParameterRow: RowLayout {
        property string label: ""
        property string value: ""
        property string unit: ""
        property string keyboardMode: "english"  // IP addresses use english mode for dots and numbers
        property var keyboardPopup: null

        // ✅ 2026-02-06 [参数持久化]: 添加值变化信号
        signal fieldValueChanged(string newValue)

        Layout.fillWidth: true
        spacing: 10

        Text {
            text: label + "："
            font.pixelSize: 16
            color: "#95a5a6"
            Layout.preferredWidth: 130
        }

        TextField {
            id: inputField
            text: value
            font.pixelSize: 16
            color: "#ecf0f1"
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            inputMethodHints: Qt.ImhFormattedNumbersOnly  // Supports numbers and dots for IP addresses

            background: Rectangle {
                color: "#1a2332"
                border.color: parent.activeFocus ? "#00d4ff" : "#34495e"
                border.width: 1
                radius: 5
            }

            // ✅ 2026-02-06 [参数持久化]: 发送值变化信号
            onTextChanged: {
                fieldValueChanged(text)
            }
        }

        Text {
            visible: unit !== ""
            text: unit
            font.pixelSize: 16
            color: "#7f8c8d"
            Layout.preferredWidth: 50
        }
    }
}
