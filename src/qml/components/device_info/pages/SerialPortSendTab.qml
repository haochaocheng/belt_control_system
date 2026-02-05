// SerialPortSendTab.qml
// 串口发送 Tab
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 从 SerialPortSendSection.qml 重命名
// 原因：采用 Tab 架构，每个 Tab 内部独立管理滚动
// ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9]: 添加导航支持
// 创建日期: 2026-02-04

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息
    property int focusParamIndex: 0       // 当前焦点参数索引
    property var virtualKeyboard: null    // 虚拟键盘引用

    // ========== 信号 ==========
    signal requestFocusParamIndex(int paramIndex)

    // ========== 导航索引映射 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9]: 参数索引映射（2列布局）
    // 行0：[0] 发送格式（右上角）    [1] （空，保留用于对齐）
    // 行1：[2] 发送数据（大文本框，跨2列）
    // 行2：[3] 发送按钮              [4] 清空按钮
    // 参数数量：5个（索引0-4）

    // ========== 焦点管理函数 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9]: 添加 triggerParamInput() 函数
    // 参考 SerialPortParamsTab 的实现
    function triggerParamInput(paramIndex) {
        console.log("✅ [SerialPortSendTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // 发送格式
            inputField = sendFormat
            console.log("✅ [SerialPortSendTab] 发送格式")
            break
        case 1:  // 空（保留）
            console.log("⚠️ [SerialPortSendTab] 索引1为空，保持焦点")
            return
        case 2:  // 发送数据
            inputField = sendInput
            console.log("✅ [SerialPortSendTab] 发送数据")
            break
        case 3:  // 发送按钮
            inputField = sendButton
            console.log("✅ [SerialPortSendTab] 发送按钮")
            break
        case 4:  // 清空按钮
            inputField = clearButton
            console.log("✅ [SerialPortSendTab] 清空按钮")
            break
        default:
            console.log("⚠️ [SerialPortSendTab] 未知参数索引:", paramIndex)
            return
        }

        // ✅ 2026-02-05: 参考 SerialPortParamsTab，不调用 forceActiveFocus()
        // 只对可编辑字段调用 activateVirtualKeyboard()
        if (inputField) {
            if (paramIndex === 2) {
                // 发送数据：激活虚拟键盘
                if (virtualKeyboard && typeof virtualKeyboard.activateVirtualKeyboard === "function") {
                    console.log("✅ [SerialPortSendTab] 激活虚拟键盘 - 控件:", inputField)
                    virtualKeyboard.activateVirtualKeyboard(inputField)
                } else {
                    console.log("⚠️ [SerialPortSendTab] 虚拟键盘不可用")
                }
            }
        }
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9]: 添加 getParamFieldCount() 函数
    function getParamFieldCount() {
        return 5  // 5个参数（0-4）
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.3]: 自定义导航处理
    // 发送区的布局特殊，需要自定义导航逻辑
    // 行0：[0] 格式（右上角）
    // 行1：[2] 发送数据（跨2列）
    // 行2：[3] 发送按钮    [4] 清空按钮
    function handleDirectionKey(direction) {
        console.log("✅ [SerialPortSendTab] 自定义导航 - 方向:", direction, "当前索引:", focusParamIndex)

        var newIndex = focusParamIndex

        switch(direction) {
        case "Down":
            // 下键导航
            if (focusParamIndex === 0) {
                // 格式 → 发送数据
                newIndex = 2
            } else if (focusParamIndex === 2) {
                // 发送数据 → 发送按钮（左侧按钮）
                newIndex = 3
            }
            // 发送按钮和清空按钮：保持不变（已经在最底部）
            break

        case "Up":
            // 上键导航
            if (focusParamIndex === 3 || focusParamIndex === 4) {
                // 发送按钮或清空按钮 → 发送数据
                newIndex = 2
            } else if (focusParamIndex === 2) {
                // 发送数据 → 格式
                newIndex = 0
            }
            // 格式：保持不变（已经在最顶部）
            break

        case "Left":
            // 左键导航
            if (focusParamIndex === 4) {
                // 清空按钮 → 发送按钮
                newIndex = 3
            }
            // 其他位置：保持不变
            break

        case "Right":
            // 右键导航
            if (focusParamIndex === 3) {
                // 发送按钮 → 清空按钮
                newIndex = 4
            }
            // 其他位置：保持不变
            break
        }

        if (newIndex !== focusParamIndex) {
            console.log("✅ [SerialPortSendTab] 导航索引变化:", focusParamIndex, "→", newIndex)
            requestFocusParamIndex(newIndex)
            return true  // 导航成功
        }

        console.log("⚠️ [SerialPortSendTab] 导航无变化，返回false")
        return false  // 导航无变化
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortSendTab] Component.onCompleted 开始")
        console.log("✅ [SerialPortSendTab] Component.onCompleted 完成")
    }

    // ========== 滚动区域 ==========
    ScrollView {
        id: sendScrollView
        anchors.fill: parent
        clip: true

        // ========== 主布局 ==========
        GridLayout {
            width: sendScrollView.width * 0.9
            columns: 2
            columnSpacing: 16
            rowSpacing: 12

            // ========== 行0：标题和格式选择 ==========
            // 左侧：标题
            Text {
                text: "发送区"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#E0E0E0"
                Layout.columnSpan: 1
                Layout.fillWidth: true
            }

            // 右侧：格式选择（索引0）
            RowLayout {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "格式:"
                    font.pixelSize: 14
                    color: "#9E9E9E"
                }

                Item {
                    Layout.preferredWidth: 120  // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.1]: 增加宽度从100到120
                    implicitHeight: sendFormat.implicitHeight

                    DeviceInfo.CustomComboBox {
                        id: sendFormat
                        anchors.fill: parent
                        model: ["HEX", "ASCII"]
                        currentIndex: 0
                    }

                    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9]: 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 0) ? 3 : 0
                        radius: 4
                        z: 11
                    }
                }
            }

            // ========== 行1：发送数据输入框（索引2，跨2列）==========
            Item {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 225

                TextArea {
                    id: sendInput
                    anchors.fill: parent
                    wrapMode: TextArea.Wrap
                    font.family: "Consolas"
                    font.pixelSize: 14
                    color: "#E0E0E0"
                    placeholderText: "输入要发送的数据..."
                    placeholderTextColor: "#5E6E7E"
                    background: Rectangle {
                        color: "#1e2838"
                        border.color: "#3d4556"
                        border.width: 1
                        radius: 4
                    }

                    // Ctrl+Enter 发送
                    Keys.onPressed: function(event) {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                            (event.modifiers & Qt.ControlModifier)) {
                            sendButton.clicked()
                            event.accepted = true
                        }
                    }
                }

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.1]: 焦点指示器（外层）
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 11
                }
            }

            // ========== 行2：操作按钮 ==========
            // 发送按钮（索引3）
            Item {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Button {
                    id: sendButton
                    anchors.fill: parent
                    text: "发送 (Ctrl+Enter)"
                    enabled: sendInput.text.length > 0

                    background: Rectangle {
                        color: {
                            if (root.focusParamIndex === 3) {
                                return "#2ecc71"  // 焦点时：亮绿色
                            } else if (parent.pressed) {
                                return "#27ae60"
                            } else if (parent.hovered) {
                                return "#2ecc71"
                            } else {
                                return "#27ae60"
                            }
                        }
                        radius: 4
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("✅ [SerialPortSendTab] 发送数据")
                        console.log("   - 格式:", sendFormat.currentText)
                        console.log("   - 数据:", sendInput.text)

                        // TODO: Phase 2 - 调用后端发送数据
                        if (sendFormat.currentText === "HEX") {
                            // serialPortController.sendHex(sendInput.text)
                        } else {
                            // serialPortController.sendAscii(sendInput.text)
                        }
                    }
                }

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.1]: 焦点指示器（外层）
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 11
                }
            }

            // 清空按钮（索引4）
            Item {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Button {
                    id: clearButton
                    anchors.fill: parent
                    text: "清空"

                    background: Rectangle {
                        color: {
                            if (root.focusParamIndex === 4) {
                                return "#e74c3c"  // 焦点时：亮红色
                            } else if (parent.pressed) {
                                return "#c0392b"
                            } else if (parent.hovered) {
                                return "#e74c3c"
                            } else {
                                return "#c0392b"
                            }
                        }
                        radius: 4
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        sendInput.text = ""
                        console.log("✅ [SerialPortSendTab] 清空发送数据")
                    }
                }

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.1]: 焦点指示器（外层）
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 11
                }
            }
        }
    }
}
