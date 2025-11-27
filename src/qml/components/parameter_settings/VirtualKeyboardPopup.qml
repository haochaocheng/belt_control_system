import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Virtual Keyboard Popup Component
Popup {
    id: root
    width: 500
    height: 320
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay

    property var targetTextField: null
    property var updateCallback: null

    function openForField(textField, callback) {
        targetTextField = textField
        updateCallback = callback
        keyboardInput.text = textField.text
        root.open()
        keyboardInput.forceActiveFocus()
    }

    background: Rectangle {
        color: "#1a2332"
        radius: 10
        border.color: "#00d4ff"
        border.width: 2
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: "虚拟键盘"
            font.pixelSize: 20
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.5
        }

        TextField {
            id: keyboardInput
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            font.pixelSize: 18
            color: "#ecf0f1"
            background: Rectangle {
                color: "#0a1628"
                border.color: "#00d4ff"
                border.width: 1
                radius: 5
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 10
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    text: modelData
                    background: Rectangle {
                        color: parent.pressed ? "#2a3f54" : "#34495e"
                        radius: 5
                        border.color: "#00d4ff"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ecf0f1"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: keyboardInput.text += modelData
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "."
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: keyboardInput.text += "."
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "清除"
                background: Rectangle {
                    color: parent.pressed ? "#c0392b" : "#e74c3c"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: keyboardInput.text = ""
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "退格"
                background: Rectangle {
                    color: parent.pressed ? "#d68910" : "#f39c12"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: keyboardInput.text = keyboardInput.text.slice(0, -1)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "确定"
                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : "#2ecc71"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.targetTextField && root.updateCallback) {
                        root.targetTextField.text = keyboardInput.text
                        root.updateCallback(keyboardInput.text)
                    }
                    root.close()
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: "取消"
                background: Rectangle {
                    color: parent.pressed ? "#7f8c8d" : "#95a5a6"
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.close()
            }
        }
    }
}
