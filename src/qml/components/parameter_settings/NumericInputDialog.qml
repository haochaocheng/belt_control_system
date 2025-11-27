import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Numeric Input Dialog - Popup for entering numeric values
Popup {
    id: root
    width: 400
    height: 500
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    property var targetField: null
    property var callback: null
    property string currentValue: ""

    anchors.centerIn: Overlay.overlay

    background: Rectangle {
        color: "#1a2332"
        border.color: "#00d4ff"
        border.width: 2
        radius: 10
    }

    function openForField(field, callbackFunc) {
        targetField = field
        callback = callbackFunc
        currentValue = field.text
        displayField.text = currentValue
        open()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: "数字输入"
            font.pixelSize: 20
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        // Display field
        TextField {
            id: displayField
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            font.pixelSize: 24
            color: "#ecf0f1"
            horizontalAlignment: Text.AlignRight
            readOnly: true

            background: Rectangle {
                color: "#0d1117"
                border.color: "#00d4ff"
                border.width: 2
                radius: 5
            }
        }

        // Number pad
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
                model: ["7", "8", "9", "4", "5", "6", "1", "2", "3", ".", "0", "⌫"]

                Button {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: modelData

                    background: Rectangle {
                        color: parent.pressed ? "#34495e" : "#2c3e50"
                        border.color: "#00d4ff"
                        border.width: 1
                        radius: 5
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 24
                        font.bold: true
                        color: "#ecf0f1"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (modelData === "⌫") {
                            // Backspace
                            if (displayField.text.length > 0) {
                                displayField.text = displayField.text.slice(0, -1)
                            }
                        } else if (modelData === ".") {
                            // Decimal point - only add if not already present
                            if (displayField.text.indexOf(".") === -1) {
                                displayField.text += modelData
                            }
                        } else {
                            // Number
                            displayField.text += modelData
                        }
                    }
                }
            }
        }

        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "取消"
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                background: Rectangle {
                    color: parent.pressed ? "#c0392b" : "#e74c3c"
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    displayField.text = currentValue
                    root.close()
                }
            }

            Button {
                text: "清空"
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                background: Rectangle {
                    color: parent.pressed ? "#d68910" : "#f39c12"
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    displayField.text = ""
                }
            }

            Button {
                text: "确定"
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : "#2ecc71"
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 5
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (callback) {
                        callback(displayField.text)
                    }
                    root.close()
                }
            }
        }
    }
}
