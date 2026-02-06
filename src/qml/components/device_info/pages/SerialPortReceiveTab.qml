// SerialPortReceiveTab.qml
// 串口接收 Tab
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 3]: 从 SerialPortReceiveSection.qml 重命名
// 原因：采用 Tab 架构，每个 Tab 内部独立管理滚动
// ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 添加导航支持
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
    property bool isPaused: false         // 是否暂停接收
    property int focusParamIndex: 0       // 当前焦点参数索引
    property var virtualKeyboard: null    // 虚拟键盘引用

    // ========== 信号 ==========
    signal requestFocusParamIndex(int paramIndex)

    // ========== 导航索引映射 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.8]: 调整索引映射，让格式成为索引0（和发送区一致）
    // 行0：[0] 格式（右上角，120px宽）  [1] （空，保留用于对齐）
    // 行1：[2] 接收数据（大文本框，跨2列，270px高）
    // 行2：[3] 清空按钮                  [4] 暂停/继续按钮
    // 参数数量：5个（索引0-4）

    // ========== 焦点管理函数 ==========
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 添加 triggerParamInput() 函数
    // 参考 SerialPortSendTab 的实现
    function triggerParamInput(paramIndex) {
        console.log("✅ [SerialPortReceiveTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // 空（保留，用于对齐）
            console.log("⚠️ [SerialPortReceiveTab] 索引0为空，保持焦点")
            return
        case 1:  // 接收格式
            inputField = receiveFormat
            console.log("✅ [SerialPortReceiveTab] 接收格式")
            break
        case 2:  // 接收数据
            inputField = receiveArea
            console.log("✅ [SerialPortReceiveTab] 接收数据")
            break
        case 3:  // 清空按钮
            inputField = clearButton
            console.log("✅ [SerialPortReceiveTab] 清空按钮")
            break
        case 4:  // 暂停/继续按钮
            inputField = pauseButton
            console.log("✅ [SerialPortReceiveTab] 暂停/继续按钮")
            break
        default:
            console.log("⚠️ [SerialPortReceiveTab] 未知参数索引:", paramIndex)
            return
        }

        // ✅ 2026-02-05: 参考 SerialPortSendTab，不调用 forceActiveFocus()
        // 接收区没有可编辑字段，不需要激活虚拟键盘
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 添加 getParamFieldCount() 函数
    function getParamFieldCount() {
        return 5  // 5个参数（0-4）
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.5]: 添加 handleEnterKey() 函数
    // 处理回车键，根据当前焦点控件执行不同的操作
    // 参考 SerialPortSendTab 的实现
    function handleEnterKey() {
        console.log("✅ [SerialPortReceiveTab] 处理回车键 - 当前焦点索引:", focusParamIndex)

        switch(focusParamIndex) {
        case 0:  // 接收格式ComboBox
            // 循环切换选项（HEX ↔ ASCII）
            var newIndex = (receiveFormat.currentIndex + 1) % receiveFormat.model.length
            console.log("✅ [SerialPortReceiveTab] 格式切换:", receiveFormat.currentIndex, "→", newIndex)
            receiveFormat.currentIndex = newIndex
            return true  // 表示已处理

        case 2:  // 接收数据TextArea
            // 接收数据是只读的，不需要处理
            console.log("⚠️ [SerialPortReceiveTab] 接收数据是只读的，不处理回车键")
            return false

        case 3:  // 清空按钮
            // 执行清空操作
            console.log("✅ [SerialPortReceiveTab] 执行清空操作")
            clearButton.clicked()
            return true  // 表示已处理

        case 4:  // 暂停/继续按钮
            // 执行暂停/继续操作
            console.log("✅ [SerialPortReceiveTab] 执行暂停/继续操作")
            pauseButton.clicked()
            return true  // 表示已处理

        default:
            console.log("⚠️ [SerialPortReceiveTab] 未知焦点索引:", focusParamIndex)
            return false
        }
    }

    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.8]: 自定义导航处理（调整索引）
    // 接收区的布局特殊，需要自定义导航逻辑
    // 行0：[0] 格式（右上角）    [1] （空）
    // 行1：[2] 接收数据（跨2列）
    // 行2：[3] 清空按钮          [4] 暂停/继续按钮
    function handleDirectionKey(direction) {
        console.log("✅ [SerialPortReceiveTab] 自定义导航 - 方向:", direction, "当前索引:", focusParamIndex)

        var newIndex = focusParamIndex

        switch(direction) {
        case "Down":
            // 下键导航
            if (focusParamIndex === 0) {
                // 格式 → 接收数据
                newIndex = 2
            } else if (focusParamIndex === 2) {
                // 接收数据 → 清空按钮（左侧按钮）
                newIndex = 3
            }
            // 清空按钮和暂停按钮：保持不变（已经在最底部）
            break

        case "Up":
            // 上键导航
            if (focusParamIndex === 3 || focusParamIndex === 4) {
                // 清空按钮或暂停按钮 → 接收数据
                newIndex = 2
            } else if (focusParamIndex === 2) {
                // 接收数据 → 格式
                newIndex = 0
            }
            // 格式：保持不变（已经在最顶部）
            break

        case "Left":
            // 左键导航
            if (focusParamIndex === 4) {
                // 暂停按钮 → 清空按钮
                newIndex = 3
            }
            // 其他位置：保持不变
            break

        case "Right":
            // 右键导航
            if (focusParamIndex === 3) {
                // 清空按钮 → 暂停按钮
                newIndex = 4
            }
            // 其他位置：保持不变
            break
        }

        if (newIndex !== focusParamIndex) {
            console.log("✅ [SerialPortReceiveTab] 导航索引变化:", focusParamIndex, "→", newIndex)
            requestFocusParamIndex(newIndex)
            return true  // 导航成功
        }

        console.log("⚠️ [SerialPortReceiveTab] 导航无变化，返回false")
        return false  // 导航无变化
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortReceiveTab] Component.onCompleted 开始")

        // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 初始化接收缓冲区显示
        updateReceiveDisplay()

        console.log("✅ [SerialPortReceiveTab] Component.onCompleted 完成")
    }

    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 监听 serialPortController 接收数据
    Connections {
        target: serialPortController

        // 监听接收缓冲区变化
        function onReceiveBufferChanged() {
            if (!root.isPaused) {
                console.log("✅ [SerialPortReceiveTab] 接收缓冲区更新")
                updateReceiveDisplay()
            }
        }

        // 监听接收模式变化
        function onReceiveHexModeChanged() {
            console.log("✅ [SerialPortReceiveTab] 接收模式变化:", serialPortController.receiveHexMode ? "HEX" : "ASCII")
            updateReceiveDisplay()
        }

        // 监听错误信号
        function onErrorOccurred(error) {
            console.error("❌ [SerialPortReceiveTab] 串口错误:", error)
            // TODO: 显示错误提示
        }
    }

    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 更新接收显示
    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.11]: 添加自动滚动到底部
    function updateReceiveDisplay() {
        receiveArea.text = serialPortController.receiveBuffer

        // 自动滚动到底部
        Qt.callLater(function() {
            if (receiveScrollView.contentItem) {
                receiveScrollView.contentItem.contentY = Math.max(0, receiveScrollView.contentItem.contentHeight - receiveScrollView.height)
            }
        })
    }

    // ========== 主布局 ==========
    GridLayout {
        anchors.fill: parent
        anchors.margins: 16
        columns: 2
        columnSpacing: 16
        rowSpacing: 12

        // ========== 行0：标题和格式选择 ==========
        // 左侧：标题
        Text {
            text: "接收区"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            Layout.columnSpan: 1
            Layout.fillWidth: true
        }

        // 右侧：格式选择（索引1）
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
                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.13.5.1]: 增加宽度到150px
                // 原因：120px不足以完整显示ASCII文本（5个字符）
                // 参考：SerialPortSendTab的格式ComboBox宽度（150px）
                Layout.preferredWidth: 150
                implicitHeight: receiveFormat.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: receiveFormat
                    anchors.fill: parent
                    model: ["HEX", "ASCII"]
                    currentIndex: 0

                    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 监听格式切换，更新 serialPortController
                    onCurrentIndexChanged: {
                        console.log("✅ [SerialPortReceiveTab] 显示格式切换:", currentText)
                        var isHex = (currentText === "HEX")
                        if (serialPortController.receiveHexMode !== isHex) {
                            serialPortController.receiveHexMode = isHex
                        }
                    }
                }

                // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.8]: 焦点指示器（索引0=格式）
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

        // ========== 行1：接收数据显示区（索引2，跨2列）==========
        Item {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 270

            // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.11]: 添加 ScrollView 支持自动滚动
            ScrollView {
                id: receiveScrollView
                anchors.fill: parent
                clip: true

                TextArea {
                    id: receiveArea
                    width: receiveScrollView.width
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    font.family: "Consolas"
                    font.pixelSize: 14
                    color: "#E0E0E0"
                    background: Rectangle {
                        color: "#1e2838"
                        border.color: "#3d4556"
                        border.width: 1
                        radius: 4
                    }

                    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 文本由 serialPortController.receiveBuffer 提供
                    text: ""
                }
            }

            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 焦点指示器（外层）
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
        // 清空按钮（索引3）
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
                        if (root.focusParamIndex === 3) {
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
                    // ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.5]: 调用 serialPortController 清空接收缓冲区
                    serialPortController.clearReceiveBuffer()
                    console.log("✅ [SerialPortReceiveTab] 清空接收区")
                }
            }

            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 焦点指示器（外层）
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                border.width: (root.focusParamIndex === 3) ? 3 : 0
                radius: 4
                z: 11
            }
        }

        // 暂停/继续按钮（索引4）
        Item {
            Layout.columnSpan: 1
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            Button {
                id: pauseButton
                anchors.fill: parent
                text: root.isPaused ? "继续" : "暂停"

                background: Rectangle {
                    color: {
                        if (root.focusParamIndex === 4) {
                            return "#f39c12"  // 焦点时：亮橙色
                        } else if (parent.pressed) {
                            return "#d68910"
                        } else if (parent.hovered) {
                            return "#f39c12"
                        } else {
                            return "#d68910"
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
                    root.isPaused = !root.isPaused
                    console.log("✅ [SerialPortReceiveTab] 接收状态:", root.isPaused ? "暂停" : "继续")
                }
            }

            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.9.7]: 焦点指示器（外层）
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
