import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// English keyboard layout (QWERTY)
ColumnLayout {
    id: root
    spacing: 5

    property var targetInput: null
    property bool capsLock: false
    property bool shift: false

    function getCharacter(baseChar) {
        return (capsLock || shift) ? baseChar.toUpperCase() : baseChar.toLowerCase()
    }

    // Row 1: QWERTYUIOP
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: root.getCharacter(modelData)
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.targetInput) {
                        root.targetInput.text += text
                        if (root.shift && !root.capsLock) {
                            root.shift = false
                        }
                    }
                }
            }
        }
    }

    // Row 2: ASDFGHJKL
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Item { Layout.preferredWidth: 20 }
        Repeater {
            model: ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: root.getCharacter(modelData)
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.targetInput) {
                        root.targetInput.text += text
                        if (root.shift && !root.capsLock) {
                            root.shift = false
                        }
                    }
                }
            }
        }
        Item { Layout.preferredWidth: 20 }
    }

    // Row 3: Shift + ZXCVBNM + Backspace
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Button {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 45
            text: "⇧"
            background: Rectangle {
                color: (root.capsLock || root.shift) ? "#00d4ff" : (parent.pressed ? "#2a3f54" : "#34495e")
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: (root.capsLock || root.shift) ? "#0a1628" : "#ecf0f1"
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                root.shift = !root.shift
            }
            onPressAndHold: {
                root.capsLock = !root.capsLock
                root.shift = false
            }
        }

        Repeater {
            model: ["z", "x", "c", "v", "b", "n", "m"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: root.getCharacter(modelData)
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.targetInput) {
                        root.targetInput.text += text
                        if (root.shift && !root.capsLock) {
                            root.shift = false
                        }
                    }
                }
            }
        }

        Button {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 45
            text: "←"
            background: Rectangle {
                color: parent.pressed ? "#d68910" : "#f39c12"
                radius: 3
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
                if (root.targetInput && root.targetInput.text.length > 0) {
                    root.targetInput.text = root.targetInput.text.slice(0, -1)
                }
            }
        }
    }

    // Row 4: Numbers and special characters
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: modelData
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 14
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

    // Row 5: Space, special chars, clear
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: ["-", "_", ".", "@", "/"]
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: modelData
                background: Rectangle {
                    color: parent.pressed ? "#2a3f54" : "#34495e"
                    radius: 3
                    border.color: "#00d4ff"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ecf0f1"
                    font.pixelSize: 14
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

        Button {
            Layout.fillWidth: true
            Layout.preferredWidth: 200
            Layout.preferredHeight: 40
            text: "空格"
            background: Rectangle {
                color: parent.pressed ? "#2a3f54" : "#34495e"
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "#ecf0f1"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (root.targetInput) {
                    root.targetInput.text += " "
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            text: "清除"
            background: Rectangle {
                color: parent.pressed ? "#c0392b" : "#e74c3c"
                radius: 3
                border.color: "#00d4ff"
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 14
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
}
