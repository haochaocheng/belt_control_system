// ModbusTCPSlaveTab.qml
// Modbus TCP 从站配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现
// ✅ 2026-02-08 [Phase 7.42.13]: 重构布局，参照 CurrentProtectionTab.qml
// ✅ 2026-04-07 [Phase 7.48.88.84]: 添加数据映射可视化

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentPort: null
    property int focusParamIndex: -1
    property int focusSubArea: 0  // ✅ 2026-04-08 [Phase 7.48.88.92]: 焦点子区域
    property var virtualKeyboard: null

    // ✅ 2026-02-08 [Phase 7.42.13]: 信号 - 请求更新焦点索引
    signal requestFocusParamIndex(int paramIndex)

    // ========== 参数数据 ==========
    // ✅ 2026-04-09: 问题2修复——参数从后端读取实际配置值
    property int portNumber: {
        if (typeof tcpDataAdapter !== "undefined") {
            return tcpDataAdapter.getModbusSlavePort(root.portIndex)
        }
        return currentPort ? currentPort.port : 502
    }
    property bool isEnabled: {
        if (typeof tcpDataAdapter !== "undefined") {
            return tcpDataAdapter.isPortRunning(root.portIndex)
        }
        return false
    }
    property int slaveAddress: {
        if (typeof tcpDataAdapter !== "undefined") {
            return tcpDataAdapter.getModbusSlaveAddress(root.portIndex)
        }
        return 1
    }
    property int maxConnections: {
        if (typeof tcpDataAdapter !== "undefined") {
            return tcpDataAdapter.getModbusMaxConnections(root.portIndex)
        }
        return 5
    }
    property int holdingRegisterCount: 100
    property int inputRegisterCount: 100
    property int coilCount: 100
    property int discreteInputCount: 100

    // ✅ 2026-04-07 [Phase 7.48.88.84]: 端口索引（用于查询数据映射）
    property int portIndex: 0

    // ✅ 2026-04-07 [Phase 7.48.88.84]: 数据映射区当前类别
    property int mapCategory: 0  // 0=离散输入 1=输入寄存器 2=线圈 3=保持寄存器
    property var currentMapData: []

    // ✅ 2026-04-07 [Phase 7.48.88.88]: 配置/数据视图切换
    property int viewMode: 0  // 0=配置视图, 1=数据视图

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 8
    }

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 键盘切换视图模式
    function toggleViewMode() {
        root.viewMode = (root.viewMode === 0) ? 1 : 0
        console.log("✅ [ModbusTCPSlaveTab] 切换视图:", root.viewMode === 0 ? "参数配置" : "映射表")
        if (root.viewMode === 1) loadMapData()
    }

    // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图键盘导航（类别切换+滚动）
    function handleDataViewKey(direction) {
        console.log("🔍 [ModbusTCPSlaveTab.handleDataViewKey]", direction, "viewMode:", root.viewMode, "mapCategory:", root.mapCategory)
        if (root.viewMode !== 1) return false
        var scrollStep = 84  // 3行 × 28px
        switch(direction) {
        case "Left":
            root.mapCategory = (root.mapCategory - 1 + 4) % 4
            console.log("🔍 [ModbusTCPSlaveTab] Left → mapCategory:", root.mapCategory)
            return true
        case "Right":
            root.mapCategory = (root.mapCategory + 1) % 4
            console.log("🔍 [ModbusTCPSlaveTab] Right → mapCategory:", root.mapCategory)
            return true
        case "Down":
            if (dataScrollView.contentHeight > dataScrollView.height) {
                dataScrollView.contentY = Math.min(dataScrollView.contentY + scrollStep,
                    dataScrollView.contentHeight - dataScrollView.height)
            }
            return true
        case "Up":
            if (dataScrollView.contentY > 0) {
                dataScrollView.contentY = Math.max(dataScrollView.contentY - scrollStep, 0)
                return true
            }
            return false  // 已在顶部，让NavigationManager处理（回到视图切换行-1）
        }
        return false
    }

    // ✅ 2026-04-07 [Phase 7.48.88.84]: 加载数据映射
    function loadMapData() {
        if (typeof tcpDataAdapter === "undefined") return
        switch(mapCategory) {
        case 0: currentMapData = tcpDataAdapter.getDiscreteInputMap(portIndex); break
        case 1: currentMapData = tcpDataAdapter.getInputRegisterMap(portIndex); break
        case 2: currentMapData = tcpDataAdapter.getCoilMap(portIndex); break
        case 3: currentMapData = tcpDataAdapter.getHoldingRegisterMap(portIndex); break
        }
    }

    onMapCategoryChanged: loadMapData()
    Component.onCompleted: loadMapData()

    // ✅ 2026-04-08 [Phase 7.48.88.92]: 映射表数据定时刷新（仅在数据视图可见时运行）
    Timer {
        id: mapRefreshTimer
        interval: 1000  // 1秒刷新一次
        running: root.viewMode === 1  // 仅映射表视图可见时运行
        repeat: true
        onTriggered: root.loadMapData()
    }

    // ✅ 2026-04-09: 问题2修复——定时刷新端口运行状态，使状态字段和参数保持同步
    Timer {
        id: statusRefreshTimer
        interval: 2000  // 2秒刷新一次
        running: true
        repeat: true
        onTriggered: {
            if (typeof tcpDataAdapter !== "undefined") {
                root.isEnabled = tcpDataAdapter.isPortRunning(root.portIndex)
            }
        }
    }

    // ✅ 2026-02-08 [Phase 7.42.13]: 重构虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [ModbusTCPSlaveTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号（CustomSpinBox）
            inputField = portNumberField
            break
        case 1:  // 状态（CustomComboBox）
            // ✅ 2026-04-09: 问题2修复——按Enter键实际启停端口服务
            console.log("✅ [ModbusTCPSlaveTab] 切换状态 → 实际启停端口")
            if (typeof tcpDataAdapter !== "undefined") {
                if (root.isEnabled) {
                    tcpDataAdapter.stopPortServices(root.portIndex)
                } else {
                    tcpDataAdapter.startPortServices(root.portIndex)
                }
            }
            // 旧：statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length  // 2026-04-09 改为实际启停
            return
        case 2:  // 从站地址（CustomSpinBox）
            inputField = slaveAddressField
            break
        case 3:  // 最大连接数（CustomSpinBox）
            inputField = maxConnectionsField
            break
        case 4:  // 保持寄存器数量（CustomSpinBox）
            inputField = holdingRegisterCountField
            break
        case 5:  // 输入寄存器数量（CustomSpinBox）
            inputField = inputRegisterCountField
            break
        case 6:  // 线圈数量（CustomSpinBox）
            inputField = coilCountField
            break
        case 7:  // 离散输入数量（CustomSpinBox）
            inputField = discreteInputCountField
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [ModbusTCPSlaveTab] 激活虚拟键盘 - 控件:", inputField)
            if (inputField.activateVirtualKeyboard) {
                inputField.activateVirtualKeyboard()
            } else {
                inputField.forceActiveFocus()
            }
        }
    }

    // ✅ 2026-02-08 [Phase 7.42]: 完善回车键处理
    // ✅ 2026-02-08 [Phase 7.42.15]: 修复返回值逻辑
    function handleEnterKey() {
        console.log("✅ [ModbusTCPSlaveTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，启停端口
        if (focusParamIndex === 1) {  // 状态（ComboBox）
            // ✅ 2026-04-09: 问题2修复——按Enter键实际启停端口服务
            if (typeof tcpDataAdapter !== "undefined") {
                if (root.isEnabled) {
                    tcpDataAdapter.stopPortServices(root.portIndex)
                } else {
                    tcpDataAdapter.startPortServices(root.portIndex)
                }
            }
            // 旧：statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length  // 2026-04-09
            return true  // 已处理，不需要弹出虚拟键盘
        }

        // 其他输入框返回 false，让 DeviceSettingsDialog 调用 triggerParamInput
        return false
    }

    // ========== 主布局 ==========
    // ✅ 2026-04-07 [Phase 7.48.88.88]: 使用ColumnLayout，顶部视图切换按钮
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 视图切换栏 ==========
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.leftMargin: 10
            spacing: 8

            Rectangle {
                width: 80
                height: 30
                radius: 4
                color: root.viewMode === 0 ? "#2196F3" : "#353b4d"
                // ✅ 2026-04-08 [Phase 7.48.88.93]: 修复焦点高亮方向——橙色跟随当前活跃按钮
                border.color: root.focusSubArea === 2 && root.focusParamIndex === -1 && root.viewMode === 0 ? "#FF9800" : (root.viewMode === 0 ? "#64B5F6" : "#4a5068")
                border.width: root.focusSubArea === 2 && root.focusParamIndex === -1 && root.viewMode === 0 ? 3 : 1

                Text {
                    anchors.centerIn: parent
                    text: "参数配置"
                    font.pixelSize: 13
                    color: root.viewMode === 0 ? "#FFFFFF" : "#9E9E9E"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewMode = 0
                }
            }

            Rectangle {
                width: 80
                height: 30
                radius: 4
                color: root.viewMode === 1 ? "#2196F3" : "#353b4d"
                // ✅ 2026-04-08 [Phase 7.48.88.93]: 修复焦点高亮方向——橙色跟随当前活跃按钮
                border.color: root.focusSubArea === 2 && root.focusParamIndex === -1 && root.viewMode === 1 ? "#FF9800" : (root.viewMode === 1 ? "#64B5F6" : "#4a5068")
                border.width: root.focusSubArea === 2 && root.focusParamIndex === -1 && root.viewMode === 1 ? 3 : 1

                Text {
                    anchors.centerIn: parent
                    text: "映射表"
                    font.pixelSize: 13
                    color: root.viewMode === 1 ? "#FFFFFF" : "#9E9E9E"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.viewMode = 1
                }
            }
        }

        // ========== 配置视图 ==========
        ScrollView {
            id: paramScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.viewMode === 0

        // ✅ 2026-02-08 [Phase 7.42.13]: 改为 4 列 GridLayout，参考 CurrentProtectionTab
        GridLayout {
            width: paramScrollView.width * 0.9
            columns: 4  // 4列：标签1、输入框1、标签2、输入框2
            columnSpacing: 10
            rowSpacing: 12

            // ========== 第一行：端口号（左侧，索引0）、状态（右侧，索引1）==========

            // 端口号标签
            Text {
                text: "端口号:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 端口号输入
            Item {
                Layout.column: 1
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: portNumberField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: portNumberField
                    anchors.fill: parent
                    from: 1
                    to: 65535
                    value: root.portNumber
                    // ✅ 2026-04-09: 问题2修复——写回后端
                    onValueChanged: {
                        root.portNumber = value
                        if (typeof tcpDataAdapter !== "undefined") {
                            tcpDataAdapter.setModbusSlavePort(root.portIndex, value)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击端口号，发射信号: requestFocusParamIndex(0)")
                        root.requestFocusParamIndex(0)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 0) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 0) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 状态标签
            Text {
                text: "状态:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 0
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 状态输入（下拉框）
            Item {
                Layout.column: 3
                Layout.row: 0
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: statusField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: statusField
                    anchors.fill: parent
                    model: ["关闭", "打开"]
                    // ✅ 2026-04-09: 问题2修复——状态显示后端实际运行状态（只读）
                    currentIndex: root.isEnabled ? 1 : 0
                    // 旧：onCurrentIndexChanged: root.isEnabled = (currentIndex === 1)  // 2026-04-09 状态由后端控制，不允许直接切换
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击状态，发射信号: requestFocusParamIndex(1)")
                        root.requestFocusParamIndex(1)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 1) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 1) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第二行：从站地址（左侧，索引2）、最大连接数（右侧，索引3）==========

            // 从站地址标签
            Text {
                text: "从站地址:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 从站地址输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: slaveAddressField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: slaveAddressField
                    anchors.fill: parent
                    from: 1
                    to: 247
                    value: root.slaveAddress
                    // ✅ 2026-04-09: 问题2修复——写回后端
                    onValueChanged: {
                        root.slaveAddress = value
                        if (typeof tcpDataAdapter !== "undefined") {
                            tcpDataAdapter.setModbusSlaveAddress(root.portIndex, value)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击从站地址，发射信号: requestFocusParamIndex(2)")
                        root.requestFocusParamIndex(2)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 2) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 2) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 最大连接数标签
            Text {
                text: "最大连接数:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 最大连接数输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: maxConnectionsRow.implicitHeight

                Row {
                    id: maxConnectionsRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: maxConnectionsField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 100
                        value: root.maxConnections
                        // ✅ 2026-04-09: 问题2修复——写回后端
                        onValueChanged: {
                            root.maxConnections = value
                            if (typeof tcpDataAdapter !== "undefined") {
                                tcpDataAdapter.setModbusMaxConnections(root.portIndex, value)
                            }
                        }
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击最大连接数，发射信号: requestFocusParamIndex(3)")
                        root.requestFocusParamIndex(3)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 3) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 3) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第三行：保持寄存器数量（左侧，索引4）、输入寄存器数量（右侧，索引5）==========

            // 保持寄存器数量标签
            Text {
                text: "保持寄存器:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 保持寄存器数量输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: holdingRegisterCountRow.implicitHeight

                Row {
                    id: holdingRegisterCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: holdingRegisterCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.holdingRegisterCount
                        onValueChanged: root.holdingRegisterCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击保持寄存器数量，发射信号: requestFocusParamIndex(4)")
                        root.requestFocusParamIndex(4)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 4) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 4) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 输入寄存器数量标签
            Text {
                text: "输入寄存器:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 输入寄存器数量输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: inputRegisterCountRow.implicitHeight

                Row {
                    id: inputRegisterCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: inputRegisterCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.inputRegisterCount
                        onValueChanged: root.inputRegisterCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击输入寄存器数量，发射信号: requestFocusParamIndex(5)")
                        root.requestFocusParamIndex(5)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 5) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 5) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第四行：线圈数量（左侧，索引6）、离散输入数量（右侧，索引7）==========

            // 线圈数量标签
            Text {
                text: "线圈数量:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 线圈数量输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: coilCountRow.implicitHeight

                Row {
                    id: coilCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: coilCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.coilCount
                        onValueChanged: root.coilCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击线圈数量，发射信号: requestFocusParamIndex(6)")
                        root.requestFocusParamIndex(6)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 6) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 6) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 离散输入数量标签
            Text {
                text: "离散输入:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 离散输入数量输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: discreteInputCountRow.implicitHeight

                Row {
                    id: discreteInputCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: discreteInputCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 65535
                        value: root.discreteInputCount
                        onValueChanged: root.discreteInputCount = value
                    }

                    Text {
                        text: "个"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [ModbusTCPSlaveTab] 鼠标点击离散输入数量，发射信号: requestFocusParamIndex(7)")
                        root.requestFocusParamIndex(7)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 7) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 7) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }
            // ✅ 2026-04-07 [Phase 7.48.88.88]: 配置视图中不再显示映射数据，移到数据视图
        }  // GridLayout 结束
    }  // ScrollView（配置视图）结束

        // ========== 数据视图（映射表）==========
        // ✅ 2026-04-07 [Phase 7.48.88.88]: 独立数据视图
        // ✅ 2026-04-08 [Phase 7.48.88.91]: 改为Flickable支持触摸拖拽和键盘滚动
        Flickable {
            id: dataScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.viewMode === 1
            contentWidth: width
            contentHeight: dataColumnLayout.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: dataColumnLayout
                width: dataScrollView.width * 0.95
                spacing: 8

                // ========== 映射类别切换 ==========
                // ✅ 2026-04-09: 问题2修复——区分只读状态区和可写控制区
                Row {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Layout.topMargin: 5

                    Repeater {
                        // 格式: [显示名, 读写标记]
                        model: [
                            { label: "离散输入(1x)", rw: "只读" },
                            { label: "输入寄存器(3x)", rw: "只读" },
                            { label: "线圈(0x)", rw: "读写" },
                            { label: "保持寄存器(4x)", rw: "读写" }
                        ]

                        Rectangle {
                            width: 145
                            height: 32
                            radius: 4
                            color: root.mapCategory === index ? "#2196F3" : "#353b4d"
                            // ✅ 2026-04-08 [Phase 7.48.88.94]: 当前类别焦点橙色高亮
                            border.color: root.focusSubArea === 2 && root.focusParamIndex >= 0 && root.mapCategory === index ? "#FF9800" : (root.mapCategory === index ? "#64B5F6" : "#4a5068")
                            border.width: root.focusSubArea === 2 && root.focusParamIndex >= 0 && root.mapCategory === index ? 3 : 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: modelData.label
                                    font.pixelSize: 12
                                    color: root.mapCategory === index ? "#FFFFFF" : "#9E9E9E"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // 读写标记
                                Rectangle {
                                    width: 28
                                    height: 14
                                    radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.rw === "读写" ? "#FF980033" : "#4CAF5033"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.rw
                                        font.pixelSize: 9
                                        color: modelData.rw === "读写" ? "#FF9800" : "#4CAF50"
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.mapCategory = index
                            }
                        }
                    }
                }

                // ========== 映射表头 ==========
                // ✅ 2026-04-09: 问题2修复——新增"访问"列区分读写
                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    color: "#2a3042"
                    radius: 2

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8

                        Text {
                            width: 80
                            text: "地址"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 160
                            text: "名称"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 60
                            text: "类型"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 50
                            text: "访问"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        // ✅ 2026-04-08 [Phase 7.48.88.90]: 当前值列
                        Text {
                            width: 80
                            text: "当前值"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: parent.width - 438
                            text: "数据来源"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                    }
                }

                // ========== 映射数据列表 ==========
                // ✅ 2026-04-09: 问题2修复——新增"访问"列，区分R/W
                Repeater {
                    model: root.currentMapData

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        color: index % 2 === 0 ? "#1e2433" : "#252b3d"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8

                            Text {
                                width: 80
                                text: modelData.address || ""
                                font.pixelSize: 13
                                font.family: "Consolas"
                                color: "#81D4FA"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                            Text {
                                width: 160
                                text: modelData.name || ""
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 60
                                text: modelData.type || ""
                                font.pixelSize: 13
                                font.family: "Consolas"
                                color: "#FFB74D"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                            // 访问权限列：根据mapCategory判断
                            Text {
                                width: 50
                                text: {
                                    // 离散输入(0)和输入寄存器(1)是只读，线圈(2)和保持寄存器(3)是读写
                                    if (root.mapCategory <= 1) return "R"
                                    return "R/W"
                                }
                                font.pixelSize: 12
                                font.family: "Consolas"
                                color: root.mapCategory <= 1 ? "#4CAF50" : "#FF9800"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                            Text {
                                width: 80
                                text: modelData.value !== undefined ? String(modelData.value) : "--"
                                font.pixelSize: 13
                                font.family: "Consolas"
                                color: {
                                    if (modelData.type === "BOOL") {
                                        return modelData.value === 1 || modelData.value === true ? "#4CAF50" : "#757575"
                                    }
                                    return "#81D4FA"
                                }
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                            Text {
                                width: parent.width - 438
                                text: modelData.source || modelData.target || modelData.description || ""
                                font.pixelSize: 13
                                color: "#9E9E9E"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // ========== 统计信息 ==========
                Text {
                    Layout.fillWidth: true
                    text: "共 " + root.currentMapData.length + " 条映射"
                    // ✅ 2026-04-08 [Phase 7.48.88.90]: 统一字体大小
                    font.pixelSize: 13
                    color: "#757575"
                    horizontalAlignment: Text.AlignRight
                    Layout.topMargin: 4
                    Layout.rightMargin: 10
                }
            }  // ColumnLayout 结束
        }  // Flickable（数据视图）结束
    }  // ColumnLayout（主布局）结束
}
