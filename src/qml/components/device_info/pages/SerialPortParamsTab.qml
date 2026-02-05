// SerialPortParamsTab.qml
// 串口参数配置 Tab
// ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 从 SerialPortParamsSection.qml 重命名
// 原因：采用 Tab 架构，每个 Tab 内部独立管理滚动
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

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 新增属性
    property int focusParamIndex: 0  // 参数焦点索引
    property var virtualKeyboard: null  // 虚拟键盘引用

    // ========== 信号 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 添加焦点请求信号
    signal requestFocusParamIndex(int paramIndex)

    // ========== 焦点函数（10个参数）==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.31]: 添加所有焦点函数（参考 SwitchInputPage）
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.36]: 简化焦点函数，移除 ScrollView 控制
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: ScrollView 只包裹单个 Tab，不会触发自动滚动

    // 索引 0: 串口名称（只读）
    function focusSerialName() {
        console.log("✅ [SerialPortParamsTab] 串口名称获得焦点")
        serialNameText.forceActiveFocus()
    }

    // 索引 1: 波特率（可编辑）
    function focusBaudRate() {
        console.log("✅ [SerialPortParamsTab] 波特率获得焦点")
        baudRateCombo.forceActiveFocus()
    }

    // 索引 2: 设备路径（只读）
    function focusDevicePath() {
        console.log("✅ [SerialPortParamsTab] 设备路径获得焦点")
        devicePathText.forceActiveFocus()
    }

    // 索引 3: 数据位（可编辑）
    function focusDataBits() {
        console.log("✅ [SerialPortParamsTab] 数据位获得焦点")
        dataBitsCombo.forceActiveFocus()
    }

    // 索引 4: 串口类型（只读）
    function focusSerialType() {
        console.log("✅ [SerialPortParamsTab] 串口类型获得焦点")
        serialTypeText.forceActiveFocus()
    }

    // 索引 5: 停止位（可编辑）
    function focusStopBits() {
        console.log("✅ [SerialPortParamsTab] 停止位获得焦点")
        stopBitsCombo.forceActiveFocus()
    }

    // 索引 6: 校验位（可编辑）
    function focusParity() {
        console.log("✅ [SerialPortParamsTab] 校验位获得焦点")
        parityCombo.forceActiveFocus()
    }

    // 索引 7: 状态（只读）
    function focusStatus() {
        console.log("✅ [SerialPortParamsTab] 状态获得焦点")
        statusText.forceActiveFocus()
    }

    // 索引 8: 打开串口按钮
    function focusOpenButton() {
        console.log("✅ [SerialPortParamsTab] 打开串口按钮获得焦点")
        openButton.forceActiveFocus()
    }

    // 索引 9: 关闭串口按钮
    function focusCloseButton() {
        console.log("✅ [SerialPortParamsTab] 关闭串口按钮获得焦点")
        closeButton.forceActiveFocus()
    }

    // ========== 新增函数 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 添加 triggerParamInput() 函数
    // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 更新参数索引映射（2列布局）
    // 参数索引映射（2列布局）：
    // 行0：[0] 串口名称（只读） [1] 波特率（可编辑）
    // 行1：[2] 设备路径（只读） [3] 数据位（可编辑）
    // 行2：[4] 串口类型（只读） [5] 停止位（可编辑）
    // 行3：[6] 状态（只读）     [7] 校验位（可编辑）
    // 行4：[8] 打开串口按钮     [9] 关闭串口按钮
    function triggerParamInput(paramIndex) {
        console.log("✅ [SerialPortParamsTab] 触发参数输入 - 索引:", paramIndex)

        var inputField = null

        switch(paramIndex) {
        case 0:  // 串口名称（只读）
            inputField = serialNameText
            break
        case 1:  // 波特率（可编辑）
            inputField = baudRateCombo
            break
        case 2:  // 设备路径（只读）
            inputField = devicePathText
            break
        case 3:  // 数据位（可编辑）
            inputField = dataBitsCombo
            break
        case 4:  // 串口类型（只读）
            inputField = serialTypeText
            break
        case 5:  // 停止位（可编辑）
            inputField = stopBitsCombo
            break
        case 6:  // 状态（只读）
            inputField = statusText
            break
        case 7:  // 校验位（可编辑）
            inputField = parityCombo
            break
        case 8:  // 打开串口按钮
            inputField = openButton
            break
        case 9:  // 关闭串口按钮
            inputField = closeButton
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                inputField.forceActiveFocus()
            }
        }
    }

    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 添加 getParamFieldCount() 函数
    function getParamFieldCount() {
        return 10  // 10个参数
    }

    // ========== 组件加载完成 ==========
    Component.onCompleted: {
        console.log("✅ [SerialPortParamsTab] Component.onCompleted 开始")
        if (currentSerialPort) {
            console.log("✅ [SerialPortParamsTab] 当前串口:", currentSerialPort.name)
        }
        console.log("✅ [SerialPortParamsTab] Component.onCompleted 完成")
    }

    // ========== 监听串口变化 ==========
    onCurrentSerialPortChanged: {
        if (currentSerialPort) {
            console.log("✅ [SerialPortParamsTab] 串口切换:", currentSerialPort.name)
            // 更新显示
            serialNameText.text = currentSerialPort.name
            devicePathText.text = currentSerialPort.path
            serialTypeText.text = currentSerialPort.type
        }
    }

    // ========== 主布局 ==========
    // ✅ 2026-02-04 [FIX 100.300.113 Phase 7.37 - Phase 2]: 添加 ScrollView 包裹参数区域
    // 原因：每个 Tab 内部独立管理滚动，不会触发 Qt 的 ensureVisible() 导致焦点丢失
    ScrollView {
        id: paramScrollView
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.5]: 简化布局，直接使用GridLayout
        // 原因：Item包裹层导致宽度计算问题（parent.width为0）
        // 解决：直接使用GridLayout，通过implicitWidth自动计算宽度
        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.6]: 修复宽度绑定问题
        // 原因：width: Math.max(paramScrollView.width - 40, 100) 在Component.onCompleted时评估为100（paramScrollView.width=0）
        // 解决：使用Qt.binding()动态绑定宽度，确保paramScrollView.width变化时GridLayout宽度也更新
        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.7]: 回退到Phase 7.37 Phase 2的成功方案
        // 原因：Qt.binding() + Math.max() 仍然失败（width=16），日志显示paramScrollView.width=0
        // 解决：使用之前成功的方案 width: paramScrollView.width * 0.9（参考docs/2026-02-04/63-FIX100.300.113-Phase7.37-Phase2完成-创建SerialPortParamsTab.md）
        // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.8]: 移除anchors.horizontalCenter
        // 原因：anchors.horizontalCenter破坏了width的动态绑定，导致width固定为0
        // 解决：参考BasicConfigTab，移除anchors.horizontalCenter，让GridLayout自然居中
        GridLayout {
            id: gridLayout
            width: paramScrollView.width * 0.9  // 90% 宽度（Phase 7.37 Phase 2 成功方案）
            // anchors.horizontalCenter: parent.horizontalCenter  // ❌ 2026-02-05: 移除，破坏width绑定

            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 改为2列布局
            // 原因：NavigationManager假设2列布局（下键：paramIndex + 2）
            // 4列布局导致导航失败（下键无法移动到下一个参数）
            columns: 2
            columnSpacing: 16
            rowSpacing: 12

            Component.onCompleted: {
                console.log("✅ [SerialPortParamsTab] GridLayout 加载完成")
                console.log("   - columns:", columns)
                console.log("   - width:", width)
                console.log("   - paramScrollView.width:", paramScrollView.width)
                console.log("   - columnSpacing:", columnSpacing)
                console.log("   - rowSpacing:", rowSpacing)
            }

            // ========== 行0：串口名称（左列，索引0） | 波特率（右列，索引1） ==========
            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 调整为2列布局
            // NavigationManager参数索引：行0 = [0, 1]

            // 索引0：串口名称（只读，左列）
            Item {
                Layout.column: 0
                Layout.row: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Component.onCompleted: {
                    console.log("✅ [SerialPortParamsTab] 索引0（串口名称）Item 加载完成")
                    console.log("   - Layout.column:", Layout.column)
                    console.log("   - Layout.row:", Layout.row)
                    console.log("   - width:", width)
                    console.log("   - height:", height)
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "串口名称:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        Layout.preferredHeight: 40

                        TextField {
                            id: serialNameText
                            anchors.fill: parent
                            text: currentSerialPort ? currentSerialPort.name : ""
                            font.pixelSize: 21
                            color: "#E0E0E0"
                            verticalAlignment: Text.AlignVCenter

                            readOnly: true
                            focus: true
                            activeFocusOnTab: true
                            inputMethodHints: Qt.ImhNone
                            autoScroll: false

                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }

                            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8.1]: 修复焦点指示器布局冲突
                            // 原因：焦点指示器使用anchors.fill，但父元素在RowLayout中，导致布局冲突
                            // 解决：将TextField包裹在Item中，焦点指示器使用anchors.fill Item
                            Rectangle {
                                id: serialNameFocusIndicator
                                anchors.fill: parent
                                anchors.margins: -4
                                color: "transparent"
                                border.color: parent.activeFocus ? "#2196F3" : "transparent"
                                border.width: parent.activeFocus ? 3 : 0
                                radius: 4
                                z: 10
                            }

                            Component.onCompleted: {
                                console.log("✅ [SerialPortParamsTab] serialNameText 加载完成 - text:", text)
                            }
                        }
                    }
                }
            }

            // 索引1：波特率（可编辑，右列）
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                implicitHeight: baudRateCombo.implicitHeight

                Component.onCompleted: {
                    console.log("✅ [SerialPortParamsTab] 索引1（波特率）Item 加载完成")
                    console.log("   - Layout.column:", Layout.column)
                    console.log("   - Layout.row:", Layout.row)
                    console.log("   - width:", width)
                    console.log("   - height:", height)
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "波特率:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    DeviceInfo.CustomComboBox {
                        id: baudRateCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                        currentIndex: 3  // 默认9600

                        Component.onCompleted: {
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

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: baudRateCombo
                        color: "transparent"
                        border.color: baudRateCombo.activeFocus ? "#2196F3" : "transparent"
                        border.width: baudRateCombo.activeFocus ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行1：设备路径（左列，索引2） | 数据位（右列，索引3） ==========
            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 调整为2列布局
            // NavigationManager参数索引：行1 = [2, 3]

            // 索引2：设备路径（只读，左列）
            Item {
                Layout.column: 0
                Layout.row: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "设备路径:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    TextField {
                        id: devicePathText
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        text: currentSerialPort ? currentSerialPort.path : ""
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        verticalAlignment: Text.AlignVCenter

                        readOnly: true
                        focus: true
                        activeFocusOnTab: true
                        autoScroll: false

                        background: Rectangle {
                            color: "transparent"
                            border.width: 0
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
                            z: 10
                        }
                    }
                }
            }

            // 索引3：数据位（可编辑，右列）
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                implicitHeight: dataBitsCombo.implicitHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "数据位:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    DeviceInfo.CustomComboBox {
                        id: dataBitsCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        model: ["5", "6", "7", "8"]
                        currentIndex: 3  // 默认8

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

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: dataBitsCombo
                        color: "transparent"
                        border.color: dataBitsCombo.activeFocus ? "#2196F3" : "transparent"
                        border.width: dataBitsCombo.activeFocus ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行2：串口类型（左列，索引4） | 停止位（右列，索引5） ==========
            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 调整为2列布局
            // NavigationManager参数索引：行2 = [4, 5]

            // 索引4：串口类型（只读，左列）
            Item {
                Layout.column: 0
                Layout.row: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "串口类型:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    TextField {
                        id: serialTypeText
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        text: currentSerialPort ? currentSerialPort.type : ""
                        font.pixelSize: 21
                        color: "#E0E0E0"
                        verticalAlignment: Text.AlignVCenter

                        readOnly: true
                        focus: true
                        activeFocusOnTab: true
                        autoScroll: false

                        background: Rectangle {
                            color: "transparent"
                            border.width: 0
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
                            z: 10
                        }
                    }
                }
            }

            // 索引5：停止位（可编辑，右列）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                implicitHeight: stopBitsCombo.implicitHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "停止位:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    DeviceInfo.CustomComboBox {
                        id: stopBitsCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        model: ["1", "1.5", "2"]
                        currentIndex: 0  // 默认1

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

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: stopBitsCombo
                        color: "transparent"
                        border.color: stopBitsCombo.activeFocus ? "#2196F3" : "transparent"
                        border.width: stopBitsCombo.activeFocus ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行3：状态（左列，索引6） | 校验位（右列，索引7） ==========
            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 调整为2列布局
            // NavigationManager参数索引：行3 = [6, 7]
            // 原来的布局是"空白 | 校验位"，现在改为"状态 | 校验位"

            // 索引6：状态（只读，左列）
            Item {
                Layout.column: 0
                Layout.row: 3
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "状态:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    Row {
                        id: statusText
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300

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

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: statusText
                        anchors.margins: -4
                        color: "transparent"
                        border.color: statusText.activeFocus ? "#2196F3" : "transparent"
                        border.width: statusText.activeFocus ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // 索引7：校验位（可编辑，右列）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                implicitHeight: parityCombo.implicitHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "校验位:"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }

                    DeviceInfo.CustomComboBox {
                        id: parityCombo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        model: ["None", "Odd", "Even", "Mark", "Space"]
                        currentIndex: 0  // 默认None

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

                    // ✅ 焦点指示器
                    Rectangle {
                        anchors.fill: parityCombo
                        color: "transparent"
                        border.color: parityCombo.activeFocus ? "#2196F3" : "transparent"
                        border.width: parityCombo.activeFocus ? 3 : 0
                        radius: 4
                        z: 10
                    }
                }
            }

            // ========== 行4：打开串口（左列，索引8） | 关闭串口（右列，索引9） ==========
            // ✅ 2026-02-05 [FIX 100.300.113 Phase 7.37.8]: 调整为2列布局
            // NavigationManager参数索引：行4 = [8, 9]

            // 索引8：打开串口按钮（左列）
            Item {
                Layout.column: 0
                Layout.row: 4
                Layout.fillWidth: true
                implicitHeight: openButton.implicitHeight
                z: 100

                Button {
                    id: openButton
                    anchors.fill: parent
                    text: "打开串口"
                    font.pixelSize: 21
                    enabled: true  // Phase 2 实现后连接到后端
                    onClicked: {
                        console.log("✅ [SerialPortParamsTab] 打开串口:", currentSerialPort.name)
                        // TODO: Phase 2 - 调用后端打开串口
                    }
                }

                // ✅ 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    color: "transparent"
                    border.color: openButton.activeFocus ? "#2196F3" : "transparent"
                    border.width: openButton.activeFocus ? 3 : 0
                    radius: 4
                    z: 200
                }
            }

            // 索引9：关闭串口按钮（右列）
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.fillWidth: true
                implicitHeight: closeButton.implicitHeight
                z: 100

                Button {
                    id: closeButton
                    anchors.fill: parent
                    text: "关闭串口"
                    font.pixelSize: 21
                    enabled: false  // Phase 2 实现后连接到后端
                    onClicked: {
                        console.log("✅ [SerialPortParamsTab] 关闭串口:", currentSerialPort.name)
                        // TODO: Phase 2 - 调用后端关闭串口
                    }
                }

                // ✅ 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    color: "transparent"
                    border.color: closeButton.activeFocus ? "#2196F3" : "transparent"
                    border.width: closeButton.activeFocus ? 3 : 0
                    radius: 4
                    z: 200
                }
            }
        }  // GridLayout
    }  // ScrollView
}  // Rectangle root
