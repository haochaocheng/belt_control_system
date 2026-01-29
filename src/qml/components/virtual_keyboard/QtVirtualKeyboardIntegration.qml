import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.VirtualKeyboard 6.5

// ✅ 2026-01-29 [Qt 虚拟键盘]: Qt Official Virtual Keyboard Integration
// ✅ 2026-01-29 [QDS 兼容]: 移除 KeyboardStyle 以支持 QDS 预览
Popup {
    id: root
    width: parent.width
    height: 300
    y: parent.height - height
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose

    property var targetTextField: null
    property var updateCallback: null
    property string inputMode: "numeric"

    // Show keyboard for specific field
    function openForField(textField, callback, mode) {
        targetTextField = textField
        updateCallback = callback
        inputMode = mode || "numeric"

        // Set input method hints based on mode
        if (textField) {
            if (mode === "numeric") {
                textField.inputMethodHints = Qt.ImhDigitsOnly
            } else if (mode === "english") {
                textField.inputMethodHints = Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase
            } else if (mode === "chinese") {
                textField.inputMethodHints = Qt.ImhNone
            }

            textField.forceActiveFocus()
        }

        root.open()
    }

    background: Rectangle {
        color: "#1a2332"
        border.color: "#00d4ff"
        border.width: 2
    }

    contentItem: InputPanel {
        id: inputPanel
        z: 99
        anchors.fill: parent

        // ✅ 2026-01-29 [QDS 兼容]: 移除 KeyboardStyle，使用默认样式
        // style: KeyboardStyle { }
    }

    // Close button
    Button {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 5
        width: 40
        height: 40
        text: "×"
        z: 100

        background: Rectangle {
            color: parent.pressed ? "#c0392b" : "#e74c3c"
            radius: 20
        }

        contentItem: Text {
            text: parent.text
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            if (root.targetTextField && root.updateCallback) {
                root.updateCallback(root.targetTextField.text)
            }
            root.close()
        }
    }
}
