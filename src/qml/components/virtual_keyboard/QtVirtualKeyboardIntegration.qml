import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.VirtualKeyboard 6.5

// ✅ 2026-01-29 [Qt 虚拟键盘]: Qt Official Virtual Keyboard Integration
// ✅ 2026-02-02 [FIX]: 使用参数设置界面的纯数字键盘设计
Popup {
    id: root
    width: parent.width
    height: 350  // ✅ 增加高度以容纳输入框和按钮
    y: parent.height - height
    modal: false
    // ✅ 2026-01-30 [修复]: 使用 Shortcut 捕获 ESC 键，不需要 focus
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

        // ✅ 2026-02-02 [FIX]: 根据模式显示不同的键盘
        if (mode === "numeric") {
            // 数字模式：使用参数设置界面风格的纯数字键盘
            numericKeyboardLayout.visible = true
            inputPanel.visible = false
            // 初始化输入框内容
            keyboardInput.text = textField.text || ""
            keyboardInput.forceActiveFocus()
        } else {
            // 其他模式：使用 Qt InputPanel
            numericKeyboardLayout.visible = false
            inputPanel.visible = true

            // Set input method hints based on mode
            if (textField) {
                if (mode === "english") {
                    textField.inputMethodHints = Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase
                } else if (mode === "chinese") {
                    textField.inputMethodHints = Qt.ImhNone
                }

                textField.forceActiveFocus()
            }
        }

        root.open()
    }

    background: Rectangle {
        color: "#1a2332"
        border.color: "#00d4ff"
        border.width: 2
    }

    contentItem: Item {
        anchors.fill: parent

        // ✅ 2026-02-02 [FIX]: 参数设置界面风格的纯数字键盘
        ColumnLayout {
            id: numericKeyboardLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12
            visible: false  // 默认隐藏，根据 inputMode 显示

            // 输入显示框
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

            // 数字键盘 (1-0)
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

            // 功能键 (小数点、清除、退格)
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

            // 确定和取消按钮
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
                        console.log("✅ [QtVirtualKeyboard] 确定按钮被点击，输入值:", keyboardInput.text)
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
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        console.log("✅ [QtVirtualKeyboard] 取消按钮被点击")
                        root.close()
                    }
                }
            }
        }

        // Qt 官方虚拟键盘（英文/中文输入）
        InputPanel {
            id: inputPanel
            z: 99
            anchors.fill: parent
            visible: false  // 默认隐藏，根据 inputMode 显示

            // ✅ 2026-01-29 [QDS 兼容]: 移除 KeyboardStyle，使用默认样式
            // style: KeyboardStyle { }
        }
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

    // ✅ 2026-01-30 [修复]: 使用 Shortcut 捕获 ESC 键（不受焦点影响）
    Shortcut {
        enabled: root.visible
        sequence: "Esc"
        onActivated: {
            console.log("✅ [QtVirtualKeyboard] Shortcut ESC 键被按下，关闭虚拟键盘")
            // 保存输入内容
            if (root.targetTextField && root.updateCallback) {
                root.updateCallback(root.targetTextField.text)
            }
            // 关闭虚拟键盘
            root.close()
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
