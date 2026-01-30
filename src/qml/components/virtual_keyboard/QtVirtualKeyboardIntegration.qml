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
    // ✅ 2026-01-30 [修复]: 允许接收键盘事件，以便处理 ESC 键
    focus: true
    closePolicy: Popup.NoAutoClose

    property var targetTextField: null
    property var updateCallback: null
    property string inputMode: "numeric"
    // ✅ 2026-01-30 [修复]: 保存父页面引用，用于恢复焦点
    property var parentPage: null

    // Show keyboard for specific field
    function openForField(textField, callback, mode, parentPageRef) {
        targetTextField = textField
        updateCallback = callback
        inputMode = mode || "numeric"
        parentPage = parentPageRef || null

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

    // ✅ 2026-01-30 [修复]: 虚拟键盘关闭时恢复焦点
    onClosed: {
        console.log("✅ [QtVirtualKeyboard] 虚拟键盘已关闭，恢复焦点")
        // 移除输入框的焦点
        if (targetTextField) {
            targetTextField.focus = false
        }
        // ✅ 2026-01-30 [修复]: 主动将焦点返回到父页面
        if (parentPage) {
            console.log("✅ [QtVirtualKeyboard] 恢复焦点到父页面")
            parentPage.forceActiveFocus()
        }
        // 清空引用
        targetTextField = null
        updateCallback = null
        parentPage = null
    }

    // ✅ 2026-01-30 [修复]: 处理 ESC 键关闭虚拟键盘
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            console.log("✅ [QtVirtualKeyboard] ESC 键被按下，关闭虚拟键盘")
            // 保存输入内容
            if (root.targetTextField && root.updateCallback) {
                root.updateCallback(root.targetTextField.text)
            }
            // 关闭虚拟键盘
            root.close()
            // 阻止事件继续传播到父容器
            event.accepted = true
        }
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
            console.log("✅ [QtVirtualKeyboard] 关闭按钮被点击")
            if (root.targetTextField && root.updateCallback) {
                root.updateCallback(root.targetTextField.text)
            }
            root.close()
        }
    }
}
