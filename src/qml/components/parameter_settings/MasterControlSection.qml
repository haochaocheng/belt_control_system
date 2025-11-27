import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Master Control Section Component
Rectangle {
    id: root
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    property var virtualKeyboardPopup: null
    property var flickableParent: null  // Reference to parent Flickable

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "集控主站设置"
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
                label: "起车预警延时"
                value: "15"
                unit: "秒"
                keyboardPopup: root.virtualKeyboardPopup
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "停车预警延时"
                value: "10"
                unit: "秒"
                keyboardPopup: root.virtualKeyboardPopup
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "集控总线标识"
                value: "1"
                unit: ""
                keyboardPopup: root.virtualKeyboardPopup
            }

            ParameterRow {
                Layout.fillWidth: true
                label: "集控台数"
                value: "5"
                unit: "台"
                keyboardPopup: root.virtualKeyboardPopup
            }

            Item { Layout.fillHeight: true }
        }
    }

    component ParameterRow: RowLayout {
        property string label: ""
        property string value: ""
        property string unit: ""
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
            inputMethodHints: Qt.ImhDigitsOnly

            background: Rectangle {
                color: "#1a2332"
                border.color: parent.activeFocus ? "#00d4ff" : "#34495e"
                border.width: 1
                radius: 5
            }

            onFocusChanged: {
                if (focus && root.flickableParent) {
                    root.flickableParent.ensureVisible(inputField)
                }
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
