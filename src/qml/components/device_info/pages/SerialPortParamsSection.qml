// SerialPortParamsSection.qml
// 串口参数配置区域
// 创建日期: 2026-02-04
// ✅ 2026-02-04: 使用与 SwitchInputPage 一致的样式（21px字体，#9E9E9E颜色，120px标签宽度）

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentSerialPort: null  // 当前串口信息

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 添加所有焦点函数（参考 SwitchInputPage）
    // 索引 0: 串口名称（只读）
    function focusSerialName() {
        console.log("🔍 [SerialPortParamsSection] focusSerialName 开始")
        console.log("   - serialNameText.activeFocus (调用前):", serialNameText.activeFocus)

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.8]: 找到 ScrollView 并记录滚动状态
        var scrollView = serialNameText
        while (scrollView && scrollView.toString().indexOf("ScrollView") === -1) {
            scrollView = scrollView.parent
        }
        if (scrollView) {
            console.log("🔍 [SerialPortParamsSection] 找到 ScrollView")
            console.log("   - ScrollView.contentItem.contentY (设置焦点前):", scrollView.contentItem.contentY)
            console.log("   - ScrollView.contentHeight:", scrollView.contentHeight)
            console.log("   - ScrollView.height:", scrollView.height)
            console.log("   - ScrollView.contentItem.interactive:", scrollView.contentItem.interactive)

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.9]: 手动滚动到顶部
            // 确保 serialNameText 在可见区域内，防止 Qt 触发自动滚动
            console.log("🔍 [SerialPortParamsSection] 手动滚动到顶部 (contentY = 0)")
            scrollView.contentItem.contentY = 0

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.8]: 暂时禁用 ScrollView 交互
            // 防止用户交互滚动
            console.log("🔍 [SerialPortParamsSection] 禁用 ScrollView 交互")
            scrollView.contentItem.interactive = false
        }

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.5]: 先禁用 DeviceSettingsDialog root 的 focus
        // 防止 root 抢夺焦点
        var dialog = serialNameText
        while (dialog && dialog.objectName !== "deviceSettingsDialog") {
            dialog = dialog.parent
        }
        if (dialog) {
            console.log("🔍 [SerialPortParamsSection] 找到 DeviceSettingsDialog，禁用 root.focus")
            dialog.focus = false
        }

        serialNameText.forceActiveFocus()
        console.log("   - serialNameText.activeFocus (调用后):", serialNameText.activeFocus)
        console.log("✅ [SerialPortParamsSection] 串口名称获得焦点")

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.9]: 记录 ScrollView 滚动状态（设置焦点后）
        if (scrollView) {
            console.log("🔍 [SerialPortParamsSection] ScrollView.contentItem.contentY (设置焦点后):", scrollView.contentItem.contentY)
        }

        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.6]: 使用 Qt.callLater 延迟检查焦点
        // 如果焦点丢失，重新设置焦点
        Qt.callLater(function() {
            console.log("🔍 [SerialPortParamsSection] Qt.callLater 检查焦点")
            console.log("   - serialNameText.activeFocus:", serialNameText.activeFocus)

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.9]: 记录 ScrollView 滚动状态（Qt.callLater）
            if (scrollView) {
                console.log("   - ScrollView.contentItem.contentY (Qt.callLater):", scrollView.contentItem.contentY)
            }

            if (!serialNameText.activeFocus) {
                console.log("⚠️ [SerialPortParamsSection] 焦点丢失，重新设置焦点")
                serialNameText.forceActiveFocus()
                console.log("   - serialNameText.activeFocus (重新设置后):", serialNameText.activeFocus)
            }

            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.9]: 保持 ScrollView 交互禁用状态
            // 不重新启用，防止滚动
            if (scrollView) {
                console.log("🔍 [SerialPortParamsSection] 保持 ScrollView 交互禁用状态")
                console.log("   - ScrollView.contentItem.contentY (最终):", scrollView.contentItem.contentY)
                console.log("   - ScrollView.contentItem.interactive (最终):", scrollView.contentItem.interactive)
            }
        })
    }

    // 索引 1: 波特率（可编辑）
    function focusBaudRate() {
        baudRateCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 波特率获得焦点")
    }

    // 索引 2: 设备路径（只读）
    function focusDevicePath() {
        devicePathText.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 设备路径获得焦点")
    }

    // 索引 3: 数据位（可编辑）
    function focusDataBits() {
        dataBitsCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 数据位获得焦点")
    }

    // 索引 4: 串口类型（只读）
    function focusSerialType() {
        serialTypeText.forceActiveFocus()  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 改为Text
        console.log("✅ [SerialPortParamsSection] 串口类型获得焦点")
    }

    // 索引 5: 停止位（可编辑）
    function focusStopBits() {
        stopBitsCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 停止位获得焦点")
    }

    // 索引 6: 校验位（可编辑）
    function focusParity() {
        parityCombo.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 校验位获得焦点")
    }

    // 索引 7: 状态（只读）
    function focusStatus() {
        statusText.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 状态获得焦点")
    }

    // 索引 8: 打开串口按钮
    function focusOpenButton() {
        openButton.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 打开串口按钮获得焦点")
    }

    // 索引 9: 关闭串口按钮
    function focusCloseButton() {
        closeButton.forceActiveFocus()
        console.log("✅ [SerialPortParamsSection] 关闭串口按钮获得焦点")
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortParamsSection] Component.onCompleted 开始")
        if (currentSerialPort) {
            console.log("✅ [SerialPortParamsSection] 当前串口:", currentSerialPort.name)
        }
        console.log("✅ [SerialPortParamsSection] Component.onCompleted 完成")
    }

    // ========== 监听串口变化 ==========
    onCurrentSerialPortChanged: {
        if (currentSerialPort) {
            console.log("✅ [SerialPortParamsSection] 串口切换:", currentSerialPort.name)
            // 更新显示
            serialNameText.text = currentSerialPort.name
            devicePathText.text = currentSerialPort.path
            serialTypeText.text = currentSerialPort.type  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 改为Text
        }
    }

    // ========== 主布局 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.19]: 移除 ScrollView，直接使用 GridLayout
    // 原因：用户反馈波特率界面有滑动窗口，不需要
    GridLayout {
        anchors.fill: parent
        anchors.margins: 16
        columns: 4
        columnSpacing: 16
        rowSpacing: 12

            // ========== 第1行：串口名称 | 波特率 ==========

            // 串口名称标签
            Text {
                text: "串口名称:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 串口名称值（只读）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.preferredHeight: 40  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 使用固定高度

                Text {
                    id: serialNameText
                    anchors.fill: parent
                    text: currentSerialPort ? currentSerialPort.name : ""
                    font.pixelSize: 21
                    color: "#E0E0E0"
                    verticalAlignment: Text.AlignVCenter

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 允许接收焦点（参考 SwitchInputPage）
                    focus: true
                    activeFocusOnTab: true

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.10]: 禁用输入法支持
                    // Text 是只读元素，不需要虚拟键盘
                    // 禁用输入法可以防止 Qt 虚拟键盘系统触发滚动
                    Keys.enabled: false
                    inputMethodHints: Qt.ImhNone

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.1]: 添加焦点变化调试
                    onActiveFocusChanged: {
                        console.log("🔍 [串口名称] activeFocus 变化:", activeFocus)
                        console.log("   - Text 宽度:", width, "高度:", height)
                        console.log("   - Text 颜色:", color)
                        console.log("   - 焦点指示器应该显示:", activeFocus ? "是" : "否")
                    }

                    // ✅ 焦点指示器
                    Rectangle {
                        id: serialNameFocusIndicator
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        border.color: parent.activeFocus ? "#2196F3" : "transparent"
                        border.width: parent.activeFocus ? 3 : 0
                        radius: 4
                        z: 10  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35]: 改为10，确保边框在Text上面

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.1]: 添加边框调试
                        Component.onCompleted: {
                            console.log("🔍 [串口名称焦点指示器] 初始化")
                            console.log("   - z值:", z)
                            console.log("   - 宽度:", width, "高度:", height)
                            console.log("   - margins:", anchors.margins)
                            console.log("   - color:", color)
                            console.log("   - border.color:", border.color)
                            console.log("   - border.width:", border.width)
                        }

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.2]: 移除无效的信号处理器
                        // QML Rectangle 没有 onBorderColorChanged 和 onBorderWidthChanged 信号
                        // 改用 Connections 监听 parent.activeFocus 变化
                        Connections {
                            target: serialNameText
                            function onActiveFocusChanged() {
                                console.log("🔍 [串口名称焦点指示器] 边框状态变化")
                                console.log("   - border.color:", serialNameFocusIndicator.border.color)
                                console.log("   - border.width:", serialNameFocusIndicator.border.width)
                            }
                        }
                    }
                }
            }

            // 波特率标签
            Text {
                text: "波特率:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 波特率下拉框
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: baudRateCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: baudRateCombo
                    anchors.fill: parent
                    model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                    currentIndex: 3  // 默认9600

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 设置父组件引用
                    Component.onCompleted: {
                        // 向上查找 DeviceSettingsDialog
                        var parent = baudRateCombo.parent
                        while (parent) {
                            if (parent.objectName === "deviceSettingsDialog") {
                                baudRateCombo.parentDialog = parent
                                console.log("✅ [CustomComboBox] 找到 DeviceSettingsDialog，设置 parentDialog")
                                break
                            }
                            parent = parent.parent
                        }

                        if (!baudRateCombo.parentDialog) {
                            console.log("⚠️ [CustomComboBox] 未找到 DeviceSettingsDialog")
                        }
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: baudRateCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: baudRateCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第2行：设备路径 | 数据位 ==========

            // 设备路径标签
            Text {
                text: "设备路径:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 设备路径值（只读）
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.preferredHeight: 40  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 使用固定高度

                Text {
                    id: devicePathText
                    anchors.fill: parent
                    text: currentSerialPort ? currentSerialPort.path : ""
                    font.pixelSize: 21
                    color: "#9E9E9E"
                    verticalAlignment: Text.AlignVCenter

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 允许接收焦点（参考 SwitchInputPage）
                    focus: true
                    activeFocusOnTab: true

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.1]: 添加焦点变化调试
                    onActiveFocusChanged: {
                        console.log("🔍 [设备路径] activeFocus 变化:", activeFocus)
                        console.log("   - Text 宽度:", width, "高度:", height)
                        console.log("   - Text 颜色:", color)
                        console.log("   - 焦点指示器应该显示:", activeFocus ? "是" : "否")
                    }

                    // ✅ 焦点指示器
                    Rectangle {
                        id: devicePathFocusIndicator
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        border.color: parent.activeFocus ? "#2196F3" : "transparent"
                        border.width: parent.activeFocus ? 3 : 0
                        radius: 4
                        z: 10  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35]: 改为10，确保边框在Text上面

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.1]: 添加边框调试
                        Component.onCompleted: {
                            console.log("🔍 [设备路径焦点指示器] 初始化")
                            console.log("   - z值:", z)
                            console.log("   - 宽度:", width, "高度:", height)
                            console.log("   - margins:", anchors.margins)
                            console.log("   - color:", color)
                            console.log("   - border.color:", border.color)
                            console.log("   - border.width:", border.width)
                        }

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.2]: 移除无效的信号处理器
                        Connections {
                            target: devicePathText
                            function onActiveFocusChanged() {
                                console.log("🔍 [设备路径焦点指示器] 边框状态变化")
                                console.log("   - border.color:", devicePathFocusIndicator.border.color)
                                console.log("   - border.width:", devicePathFocusIndicator.border.width)
                            }
                        }
                    }
                }
            }

            // 数据位标签
            Text {
                text: "数据位:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 数据位下拉框
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: dataBitsCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: dataBitsCombo
                    anchors.fill: parent
                    model: ["5", "6", "7", "8"]
                    currentIndex: 3  // 默认8

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 设置父组件引用
                    Component.onCompleted: {
                        var parent = dataBitsCombo.parent
                        while (parent) {
                            if (parent.objectName === "deviceSettingsDialog") {
                                dataBitsCombo.parentDialog = parent
                                console.log("✅ [CustomComboBox] dataBitsCombo 找到 DeviceSettingsDialog")
                                break
                            }
                            parent = parent.parent
                        }
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: dataBitsCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: dataBitsCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第3行：串口类型 | 停止位 ==========

            // 串口类型标签
            Text {
                text: "串口类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 串口类型值（只读）
            // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 改为Text，和串口名称一致
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.preferredHeight: 40  // ✅ 使用固定高度

                Text {
                    id: serialTypeText
                    anchors.fill: parent
                    text: currentSerialPort ? currentSerialPort.type : ""
                    font.pixelSize: 21
                    color: "#E0E0E0"
                    verticalAlignment: Text.AlignVCenter

                    // ✅ 允许接收焦点
                    focus: true
                    activeFocusOnTab: true

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.1]: 添加焦点变化调试
                    onActiveFocusChanged: {
                        console.log("🔍 [串口类型] activeFocus 变化:", activeFocus)
                        console.log("   - Text 宽度:", width, "高度:", height)
                        console.log("   - Text 颜色:", color)
                        console.log("   - 焦点指示器应该显示:", activeFocus ? "是" : "否")
                    }

                    // ✅ 焦点指示器
                    Rectangle {
                        id: serialTypeFocusIndicator
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        border.color: parent.activeFocus ? "#2196F3" : "transparent"
                        border.width: parent.activeFocus ? 3 : 0
                        radius: 4
                        z: 10  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35]: 改为10，确保边框在Text上面

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.1]: 添加边框调试
                        Component.onCompleted: {
                            console.log("🔍 [串口类型焦点指示器] 初始化")
                            console.log("   - z值:", z)
                            console.log("   - 宽度:", width, "高度:", height)
                            console.log("   - margins:", anchors.margins)
                            console.log("   - color:", color)
                            console.log("   - border.color:", border.color)
                            console.log("   - border.width:", border.width)
                        }

                        // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.35.2]: 移除无效的信号处理器
                        Connections {
                            target: serialTypeText
                            function onActiveFocusChanged() {
                                console.log("🔍 [串口类型焦点指示器] 边框状态变化")
                                console.log("   - border.color:", serialTypeFocusIndicator.border.color)
                                console.log("   - border.width:", serialTypeFocusIndicator.border.width)
                            }
                        }
                    }
                }
            }

            // 停止位标签
            Text {
                text: "停止位:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 停止位下拉框
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: stopBitsCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: stopBitsCombo
                    anchors.fill: parent
                    model: ["1", "1.5", "2"]
                    currentIndex: 0  // 默认1

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 设置父组件引用
                    Component.onCompleted: {
                        var parent = stopBitsCombo.parent
                        while (parent) {
                            if (parent.objectName === "deviceSettingsDialog") {
                                stopBitsCombo.parentDialog = parent
                                console.log("✅ [CustomComboBox] stopBitsCombo 找到 DeviceSettingsDialog")
                                break
                            }
                            parent = parent.parent
                        }
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: stopBitsCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: stopBitsCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第4行：校验位 | 状态 ==========

            // 校验位标签
            Text {
                text: "校验位:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 校验位下拉框
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: parityCombo.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: parityCombo
                    anchors.fill: parent
                    model: ["None", "Odd", "Even", "Mark", "Space"]
                    currentIndex: 0  // 默认None

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.29]: 设置父组件引用
                    Component.onCompleted: {
                        var parent = parityCombo.parent
                        while (parent) {
                            if (parent.objectName === "deviceSettingsDialog") {
                                parityCombo.parentDialog = parent
                                console.log("✅ [CustomComboBox] parityCombo 找到 DeviceSettingsDialog")
                                break
                            }
                            parent = parent.parent
                        }
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.6.1]: 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: parityCombo.activeFocus ? "#2196F3" : "transparent"
                    border.width: parityCombo.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // 状态标签
            Text {
                text: "状态:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }

            // 状态指示器
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.preferredHeight: 40  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 使用固定高度

                Row {
                    id: statusText  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 添加 ID 以支持焦点
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 允许接收焦点
                    focus: true
                    activeFocusOnTab: true

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#9E9E9E"  // 默认关闭状态
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "已关闭"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 焦点指示器（在Item外部，不在Row内部）
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    color: "transparent"
                    border.color: statusText.activeFocus ? "#2196F3" : "transparent"
                    border.width: statusText.activeFocus ? 3 : 0
                    radius: 4
                    z: 10
                }
            }

            // ========== 第5行：操作按钮 ==========

            // 空白占位（左侧两列）
            Item {
                Layout.column: 0
                Layout.row: 4
                Layout.columnSpan: 2
            }

            // 打开串口按钮
            Item {
                Layout.column: 2
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: openButton.implicitHeight
                z: 100  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.23]: 提高 z-index 避免被遮挡

                Button {
                    id: openButton
                    anchors.fill: parent
                    text: "打开串口"
                    font.pixelSize: 21
                    enabled: true  // Phase 2 实现后连接到后端
                    onClicked: {
                        console.log("✅ [SerialPortParamsSection] 打开串口:", currentSerialPort.name)
                        // TODO: Phase 2 - 调用后端打开串口
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 焦点指示器（在按钮外部）
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4  // ✅ 边框在按钮外部
                    color: "transparent"
                    border.color: openButton.activeFocus ? "#2196F3" : "transparent"
                    border.width: openButton.activeFocus ? 3 : 0
                    radius: 4
                    z: 200  // ✅ 确保边框在最上层
                }
            }

            // 关闭串口按钮
            Item {
                Layout.column: 3
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: closeButton.implicitHeight
                z: 100  // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.23]: 提高 z-index 避免被遮挡

                Button {
                    id: closeButton
                    anchors.fill: parent
                    text: "关闭串口"
                    font.pixelSize: 21
                    enabled: false  // Phase 2 实现后连接到后端
                    onClicked: {
                        console.log("✅ [SerialPortParamsSection] 关闭串口:", currentSerialPort.name)
                        // TODO: Phase 2 - 调用后端关闭串口
                    }
                }

                // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.32]: 焦点指示器（在按钮外部）
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4  // ✅ 边框在按钮外部
                    color: "transparent"
                    border.color: closeButton.activeFocus ? "#2196F3" : "transparent"
                    border.width: closeButton.activeFocus ? 3 : 0
                    radius: 4
                    z: 200  // ✅ 确保边框在最上层
                }
            }
    }
}

