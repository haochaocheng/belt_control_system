// CANSendTab.qml
// CAN 发送区 Tab
// 创建日期: 2026-02-07
// ✅ 2026-02-07 [Phase 7.39.23]: 添加导航支持、虚拟键盘支持

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: 0
    property var virtualKeyboard: null

    // ========== 信号 ==========
    // ✅ 2026-02-07 [Phase 7.39.23]: 添加焦点请求信号
    signal requestFocusParamIndex(int paramIndex)

    // ========== 导航索引映射 ==========
    // ✅ 2026-02-07 [Phase 7.39.23]: 参数索引映射
    // [0] CAN ID 输入框
    // [1] 数据输入框
    // [2] 发送按钮
    // 参数数量：3个（索引0-2）

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 3  // CAN ID、数据、发送按钮
    }

    // ✅ 2026-02-07 [Phase 7.39.23]: 完善 triggerParamInput 函数
    // 参考 SerialPortSendTab 的实现
    function triggerParamInput(paramIndex) {
        console.log("✅ [CANSendTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // CAN ID 输入框
            inputField = canIdInput
            console.log("✅ [CANSendTab] CAN ID 输入框")
            break
        case 1:  // 数据输入框
            inputField = dataInput
            console.log("✅ [CANSendTab] 数据输入框")
            break
        case 2:  // 发送按钮
            inputField = sendButton
            console.log("✅ [CANSendTab] 发送按钮")
            break
        default:
            console.log("⚠️ [CANSendTab] 未知参数索引:", paramIndex)
            return
        }

        // ✅ triggerParamInput 不应该自动打开虚拟键盘
        // triggerParamInput 只负责移动焦点，不打开虚拟键盘
        // 只有按回车键（handleEnterKey）时才打开虚拟键盘
        if (inputField) {
            console.log("✅ [CANSendTab] 参数索引已更新，焦点指示器已显示")
        }
    }

    // ✅ 2026-02-07 [Phase 7.39.23]: 完善 handleEnterKey 函数
    // 功能：根据当前焦点控件，执行不同的回车键操作
    // - CAN ID 输入框：弹出虚拟键盘
    // - 数据输入框：弹出虚拟键盘
    // - 发送按钮：执行发送操作
    function handleEnterKey() {
        console.log("✅ [CANSendTab] 处理回车键 - 当前焦点索引:", focusParamIndex)

        switch(focusParamIndex) {
        case 0:  // CAN ID 输入框
            console.log("✅ [CANSendTab] 尝试激活虚拟键盘 - CAN ID")
            canIdInput.forceActiveFocus()
            Qt.inputMethod.show()  // ✅ 2026-02-07 [Phase 7.39.23.3]: 手动显示虚拟键盘
            console.log("✅ [CANSendTab] 调用 Qt.inputMethod.show()")
            return true

        case 1:  // 数据输入框
            console.log("✅ [CANSendTab] 尝试激活虚拟键盘 - 数据")
            dataInput.forceActiveFocus()
            Qt.inputMethod.show()  // ✅ 2026-02-07 [Phase 7.39.23.3]: 手动显示虚拟键盘
            console.log("✅ [CANSendTab] 调用 Qt.inputMethod.show()")
            return true

        case 2:  // 发送按钮
            console.log("✅ [CANSendTab] 执行发送操作")
            sendButton.clicked()
            return true

        default:
            console.log("⚠️ [CANSendTab] 当前焦点不在可处理的控件上")
            return false
        }
    }

    // ✅ 2026-02-07 [Phase 7.39.23]: 添加自定义导航处理
    // CAN 发送区的布局：
    // 行0：[0] CAN ID 输入框
    // 行1：[1] 数据输入框
    // 行2：[2] 发送按钮
    function handleDirectionKey(direction) {
        console.log("✅ [CANSendTab] 自定义导航 - 方向:", direction, "当前索引:", focusParamIndex)

        var newIndex = focusParamIndex

        switch(direction) {
        case "Down":
            // 下键导航
            if (focusParamIndex < 2) {
                newIndex = focusParamIndex + 1
            }
            break

        case "Up":
            // 上键导航
            if (focusParamIndex > 0) {
                newIndex = focusParamIndex - 1
            }
            break

        case "Left":
        case "Right":
            // 左右键：保持不变（单列布局）
            break
        }

        if (newIndex !== focusParamIndex) {
            console.log("✅ [CANSendTab] 导航索引变化:", focusParamIndex, "→", newIndex)
            requestFocusParamIndex(newIndex)
            return true  // 导航成功
        }

        console.log("⚠️ [CANSendTab] 导航无变化，返回false")
        return false  // 导航无变化
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [CANSendTab] Component.onCompleted")
        console.log("   - virtualKeyboard:", virtualKeyboard)
    }

    // ========== 滚动视图 ==========
    ScrollView {
        id: sendScrollView
        anchors.fill: parent
        clip: true

        // ✅ 2026-02-07 [Phase 7.39.23.1]: 使用 GridLayout 参考 CANParamsTab 布局
        GridLayout {
            width: sendScrollView.width * 0.95
            columns: 2
            columnSpacing: 10
            rowSpacing: 16

            // ========== 行0：CAN ID 输入 ==========
            // 索引 0: CAN ID
            Text {
                text: "CAN ID (HEX):"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 140
                horizontalAlignment: Text.AlignRight
            }

            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.preferredHeight: 60

                // ✅ 2026-02-07 [Phase 7.39.23.1]: 添加背景图片，参考 CANParamsTab
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: "../images/034.png"
                        fillMode: Image.Stretch
                        z: -1
                    }
                }

                TextField {
                    id: canIdInput
                    anchors.fill: parent
                    placeholderText: "例如: 123"
                    placeholderTextColor: "#5E6E7E"
                    font.pixelSize: 21
                    font.family: "Consolas"
                    color: "#E0E0E0"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 15

                    background: Rectangle {
                        color: "transparent"
                        border.width: 0
                    }

                    // 只允许输入十六进制字符
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{0,8}/
                    }

                    // ✅ 2026-02-07 [Phase 7.39.23.1]: 焦点指示器（内层）
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 0) ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行1：数据输入 ==========
            // 索引 1: 数据
            Text {
                text: "数据 (HEX):"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 140
                horizontalAlignment: Text.AlignRight
            }

            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.preferredHeight: 60

                // ✅ 2026-02-07 [Phase 7.39.23.1]: 添加背景图片，参考 CANParamsTab
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: "../images/034.png"
                        fillMode: Image.Stretch
                        z: -1
                    }
                }

                TextField {
                    id: dataInput
                    anchors.fill: parent
                    placeholderText: "例如: DEADBEEF"
                    placeholderTextColor: "#5E6E7E"
                    font.pixelSize: 21
                    font.family: "Consolas"
                    color: "#E0E0E0"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 15

                    background: Rectangle {
                        color: "transparent"
                        border.width: 0
                    }

                    // 只允许输入十六进制字符，最多16个字符（8字节）
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9A-Fa-f]{0,16}/
                    }

                    // ✅ 2026-02-07 [Phase 7.39.23.1]: 焦点指示器（内层）
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                        border.width: (root.focusParamIndex === 1) ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行2：发送按钮 ==========
            // 索引 2: 发送按钮
            Item {
                Layout.column: 0
                Layout.row: 2
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                Layout.topMargin: 10

                Button {
                    id: sendButton
                    anchors.centerIn: parent
                    width: 200
                    height: 50
                    text: "发送"
                    enabled: canIdInput.text.length > 0 && dataInput.text.length > 0

                    background: Rectangle {
                        color: {
                            if (!parent.enabled) {
                                return "#555555"  // 禁用时：灰色
                            } else if (root.focusParamIndex === 2) {
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
                        font.pixelSize: 18
                        font.bold: true
                        color: parent.enabled ? "white" : "#888888"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("✅ [CANSendTab] 发送 CAN 数据")
                        console.log("   - CAN ID:", canIdInput.text)
                        console.log("   - 数据:", dataInput.text)

                        // 验证输入
                        if (canIdInput.text.length === 0) {
                            console.error("❌ [CANSendTab] CAN ID 不能为空")
                            return
                        }

                        if (dataInput.text.length === 0) {
                            console.error("❌ [CANSendTab] 数据不能为空")
                            return
                        }

                        // ✅ 2026-02-07 [Phase 7.39.23]: 调用 canController 发送数据
                        if (typeof canController !== 'undefined') {
                            var success = canController.sendData(canIdInput.text, dataInput.text)
                            if (success) {
                                console.log("✅ [CANSendTab] 数据发送成功")
                            } else {
                                console.error("❌ [CANSendTab] 数据发送失败")
                            }
                        } else {
                            console.error("❌ [CANSendTab] canController 未定义")
                        }
                    }
                }

                // ✅ 2026-02-07 [Phase 7.39.23.1]: 焦点指示器（外层）
                Rectangle {
                    anchors.centerIn: parent
                    width: sendButton.width + 8
                    height: sendButton.height + 8
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 6
                    z: 11
                }
            }

            // ========== 行3：使用说明 ==========
            Rectangle {
                Layout.column: 0
                Layout.row: 3
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.topMargin: 20
                color: "#34495e"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "使用说明："
                        font.pixelSize: 14
                        font.bold: true
                        color: "#00d4ff"
                    }

                    Text {
                        text: "• CAN ID: 十六进制，标准帧 11 位（0x000-0x7FF），扩展帧 29 位"
                        font.pixelSize: 12
                        color: "#ecf0f1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "• 数据: 十六进制，最多 8 字节（16 个字符）"
                        font.pixelSize: 12
                        color: "#ecf0f1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "• 示例: CAN ID=123, 数据=DEADBEEF"
                        font.pixelSize: 12
                        color: "#ecf0f1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
