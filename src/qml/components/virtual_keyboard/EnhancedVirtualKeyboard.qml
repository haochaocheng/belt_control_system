import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Enhanced Virtual Keyboard with multiple input modes
Popup {
    id: root
    width: 700
    height: keyboardModeSelector.currentMode === "numeric" ? 380 : 450
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay

    property var targetTextField: null
    property var updateCallback: null

    // Input mode: "numeric", "english", "chinese"
    property string inputMode: "numeric"

    function openForField(textField, callback, mode) {
        targetTextField = textField
        updateCallback = callback
        inputMode = mode || "numeric"
        keyboardModeSelector.currentMode = inputMode

        // ✅ 2026-01-29 [FIX 100.300.102 Phase 2.32.1]: 修复 SpinBox 的 text 属性访问
        // SpinBox 使用 value 属性，TextField 使用 text 属性
        if (textField.hasOwnProperty("value")) {
            // SpinBox - 转换为字符串
            keyboardInput.text = textField.value.toString()
        } else if (textField.hasOwnProperty("text")) {
            // TextField / ComboBox
            keyboardInput.text = textField.text || ""
        } else {
            keyboardInput.text = ""
        }

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
        spacing: 10

        // Header with mode selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "虚拟键盘"
                font.pixelSize: 20
                font.bold: true
                color: "#00d4ff"
                Layout.fillWidth: true
            }

            KeyboardModeSelector {
                id: keyboardModeSelector
                Layout.preferredWidth: 300
                Layout.preferredHeight: 35
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.5
        }

        // Input display
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

        // Keyboard layout - changes based on mode
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: keyboardModeSelector.currentMode === "numeric" ? 0 :
                         (keyboardModeSelector.currentMode === "english" ? 1 : 2)

            // Numeric keyboard
            NumericKeyboard {
                id: numericKeyboard
                targetInput: keyboardInput
            }

            // English keyboard
            EnglishKeyboard {
                id: englishKeyboard
                targetInput: keyboardInput
            }

            // Chinese keyboard (Pinyin input)
            ChineseKeyboard {
                id: chineseKeyboard
                targetInput: keyboardInput
            }
        }

        // Bottom buttons
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
