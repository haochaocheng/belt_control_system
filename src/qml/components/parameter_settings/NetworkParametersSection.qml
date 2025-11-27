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
                value: "192.168.1.100"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "子网掩码"
                value: "255.255.255.0"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "网关"
                value: "192.168.1.1"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
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
