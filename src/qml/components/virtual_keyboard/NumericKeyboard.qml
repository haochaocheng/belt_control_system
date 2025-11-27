import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Numeric keyboard layout
ColumnLayout {
    id: root
    spacing: 6

    property var targetInput: null

    // Number pad grid
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: ["7", "8", "9", "4", "5", "6", "1", "2", "3"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 55
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
                    font.pixelSize: 22
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.targetInput) {
                        root.targetInput.text += modelData
                    }
                }
            }
        }
    }

    // Bottom row: 0, decimal point, backspace
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 55
            text: "0"
            background: Rectangle {
                color: parent.pressed ? "#2a3f54" : "#34495e"
                radius: 5
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "#ecf0f1"
                font.pixelSize: 22
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.targetInput) {
                    root.targetInput.text += "0"
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 55
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
                font.pixelSize: 22
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.targetInput) {
                    root.targetInput.text += "."
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 55
            text: "←"
            background: Rectangle {
                color: parent.pressed ? "#d68910" : "#f39c12"
                radius: 5
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 22
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.targetInput && root.targetInput.text.length > 0) {
                    root.targetInput.text = root.targetInput.text.slice(0, -1)
                }
            }
        }
    }

    // Clear button
    Button {
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        text: "清除全部"
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
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
            if (root.targetInput) {
                root.targetInput.text = ""
            }
        }
    }
}
