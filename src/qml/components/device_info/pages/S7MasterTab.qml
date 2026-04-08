// S7MasterTab.qml
// S7 主站（客户端）配置Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现
// ✅ 2026-02-08 [Phase 7.42.13]: 重构布局，参照 CurrentProtectionTab.qml
// 使用 Snap7 库实现西门子 S7 协议

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
    property int portIndex: 0  // ✅ 2026-04-07 [Phase 7.48.88.85]: 端口索引

    // ✅ 2026-04-07 [Phase 7.48.88.85]: 轮询数据展示
    property int pollDbNumber: 1   // 轮询的DB编号
    property int pollDbStart: 0     // 轮询起始偏移
    property int pollDbSize: 140    // 轮询字节数
    property var pollDataList: []

    // ✅ 2026-04-07 [Phase 7.48.88.88]: 配置/数据视图切换
    property int viewMode: 0  // 0=配置视图, 1=数据视图

    // ✅ 2026-02-08 [Phase 7.42.13]: 信号 - 请求更新焦点索引
    signal requestFocusParamIndex(int paramIndex)

    // ========== 参数数据 ==========
    property int portNumber: 102  // S7 标准端口
    property bool isEnabled: false
    property string targetIP: "192.168.0.1"
    property int rack: 0
    property int slot: 2
    property string connectionType: "PG"  // PG/OP/Basic
    property string localTSAP: "0x0100"
    property string remoteTSAP: "0x0302"
    property int pduSize: 480
    property real pollInterval: 10  // 0.1秒单位
    property int timeout: 5000

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 11
    }

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 键盘切换视图模式
    function toggleViewMode() {
        root.viewMode = (root.viewMode === 0) ? 1 : 0
        console.log("✅ [S7MasterTab] 切换视图:", root.viewMode === 0 ? "参数配置" : "数据概览")
        if (root.viewMode === 1) loadPollConfig()
    }

    // ✅ 2026-02-08 [Phase 7.42.13]: 重构虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [S7MasterTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号（CustomSpinBox）
            inputField = portNumberField
            break
        case 1:  // 状态（CustomComboBox）
            console.log("✅ [S7MasterTab] 切换状态")
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return
        case 2:  // 目标IP（CustomTextField）
            inputField = targetIPField
            break
        case 3:  // Rack（CustomSpinBox）
            inputField = rackField
            break
        case 4:  // Slot（CustomSpinBox）
            inputField = slotField
            break
        case 5:  // 连接类型（CustomComboBox）
            console.log("✅ [S7MasterTab] 切换连接类型")
            connectionTypeField.currentIndex = (connectionTypeField.currentIndex + 1) % connectionTypeField.model.length
            return
        case 6:  // Local TSAP（CustomTextField）
            inputField = localTSAPField
            break
        case 7:  // Remote TSAP（CustomTextField）
            inputField = remoteTSAPField
            break
        case 8:  // PDU大小（CustomSpinBox）
            inputField = pduSizeField
            break
        case 9:  // 轮询时间（CustomSpinBox）
            inputField = pollIntervalField
            break
        case 10:  // 超时时间（CustomSpinBox）
            inputField = timeoutField
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [S7MasterTab] 激活虚拟键盘 - 控件:", inputField)
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
        console.log("✅ [S7MasterTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，切换选项
        if (focusParamIndex === 1) {  // 状态（ComboBox）
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return true  // 已处理，不需要弹出虚拟键盘
        } else if (focusParamIndex === 5) {  // 连接类型（ComboBox）
            connectionTypeField.currentIndex = (connectionTypeField.currentIndex + 1) % connectionTypeField.model.length
            return true  // 已处理，不需要弹出虚拟键盘
        }

        // 其他输入框返回 false，让 DeviceSettingsDialog 调用 triggerParamInput
        return false
    }

    // ✅ 2026-04-07 [Phase 7.48.88.85]: 加载S7轮询数据概览
    function loadPollConfig() {
        if (typeof tcpDataAdapter === "undefined") {
            root.pollDataList = []
            return
        }
        // 使用S7 DB映射来展示轮询数据概览
        if (root.pollDbNumber === 1) {
            root.pollDataList = tcpDataAdapter.getS7DB1Map(root.portIndex)
        } else if (root.pollDbNumber === 2) {
            root.pollDataList = tcpDataAdapter.getS7DB2Map(root.portIndex)
        } else {
            root.pollDataList = []
        }
        console.log("✅ [S7MasterTab] 加载轮询配置 - DB:", root.pollDbNumber, "数量:", root.pollDataList.length)
    }

    onPollDbNumberChanged: loadPollConfig()
    onPortIndexChanged: loadPollConfig()
    Component.onCompleted: Qt.callLater(loadPollConfig)

    // ✅ 2026-04-08 [Phase 7.48.88.92]: 数据概览定时刷新（仅在数据视图可见时运行）
    Timer {
        id: pollRefreshTimer
        interval: 1000
        running: root.viewMode === 1
        repeat: true
        onTriggered: root.loadPollConfig()
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
                    text: "数据概览"
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
                    onValueChanged: root.portNumber = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击端口号，发射信号: requestFocusParamIndex(0)")
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
                    currentIndex: root.isEnabled ? 1 : 0
                    onCurrentIndexChanged: root.isEnabled = (currentIndex === 1)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击状态，发射信号: requestFocusParamIndex(1)")
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

            // ========== 第二行：目标IP（左侧，索引2）、连接类型（右侧，索引5）==========

            // 目标IP标签
            Text {
                text: "目标IP:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 目标IP输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: targetIPField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: targetIPField
                    anchors.fill: parent
                    text: root.targetIP
                    onTextChanged: root.targetIP = text
                    placeholderText: "192.168.0.1"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击目标IP，发射信号: requestFocusParamIndex(2)")
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

            // 连接类型标签
            Text {
                text: "连接类型:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 连接类型输入（下拉框）
            Item {
                Layout.column: 3
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: connectionTypeField.implicitHeight

                DeviceInfo.CustomComboBox {
                    id: connectionTypeField
                    anchors.fill: parent
                    model: ["PG", "OP", "Basic"]
                    currentIndex: {
                        switch(root.connectionType) {
                        case "PG": return 0
                        case "OP": return 1
                        case "Basic": return 2
                        default: return 0
                        }
                    }
                    onCurrentIndexChanged: {
                        switch(currentIndex) {
                        case 0: root.connectionType = "PG"; break
                        case 1: root.connectionType = "OP"; break
                        case 2: root.connectionType = "Basic"; break
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击连接类型，发射信号: requestFocusParamIndex(5)")
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

            // ========== 第三行：Rack（左侧，索引3）、Slot（右侧，索引4）==========

            // Rack标签
            Text {
                text: "Rack:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Rack输入
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: rackField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: rackField
                    anchors.fill: parent
                    from: 0
                    to: 7
                    value: root.rack
                    onValueChanged: root.rack = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击Rack，发射信号: requestFocusParamIndex(3)")
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

            // Slot标签
            Text {
                text: "Slot:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Slot输入
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: slotField.implicitHeight

                DeviceInfo.CustomSpinBox {
                    id: slotField
                    anchors.fill: parent
                    from: 0
                    to: 31
                    value: root.slot
                    onValueChanged: root.slot = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击Slot，发射信号: requestFocusParamIndex(4)")
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

            // ========== 第四行：Local TSAP（左侧，索引6）、Remote TSAP（右侧，索引7）==========

            // Local TSAP标签
            Text {
                text: "Local TSAP:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Local TSAP输入
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: localTSAPField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: localTSAPField
                    anchors.fill: parent
                    text: root.localTSAP
                    onTextChanged: root.localTSAP = text
                    placeholderText: "0x0100"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击Local TSAP，发射信号: requestFocusParamIndex(6)")
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

            // Remote TSAP标签
            Text {
                text: "Remote TSAP:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Remote TSAP输入
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: remoteTSAPField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: remoteTSAPField
                    anchors.fill: parent
                    text: root.remoteTSAP
                    onTextChanged: root.remoteTSAP = text
                    placeholderText: "0x0302"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击Remote TSAP，发射信号: requestFocusParamIndex(7)")
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

            // ========== 第五行：PDU大小（左侧，索引8）、轮询时间（右侧，索引9）==========

            // PDU大小标签
            Text {
                text: "PDU大小:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // PDU大小输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: pduSizeRow.implicitHeight

                Row {
                    id: pduSizeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: pduSizeField
                        width: parent.width - 60
                        height: 60
                        from: 240
                        to: 960
                        value: root.pduSize
                        onValueChanged: root.pduSize = value
                    }

                    Text {
                        text: "字节"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击PDU大小，发射信号: requestFocusParamIndex(8)")
                        root.requestFocusParamIndex(8)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 8) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 8) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // 轮询时间标签
            Text {
                text: "轮询时间:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 轮询时间输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: pollIntervalRow.implicitHeight

                Row {
                    id: pollIntervalRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: pollIntervalField
                        width: parent.width - 60
                        height: 60
                        from: 1
                        to: 1000
                        value: root.pollInterval
                        onValueChanged: root.pollInterval = value
                    }

                    Text {
                        text: "0.1秒"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击轮询时间，发射信号: requestFocusParamIndex(9)")
                        root.requestFocusParamIndex(9)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 9) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 9) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }

            // ========== 第六行：超时时间（左侧，索引10）==========

            // 超时时间标签
            Text {
                text: "超时时间:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 5
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 超时时间输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 5
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: timeoutRow.implicitHeight

                Row {
                    id: timeoutRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: timeoutField
                        width: parent.width - 40
                        height: 60
                        from: 100
                        to: 30000
                        value: root.timeout
                        onValueChanged: root.timeout = value
                    }

                    Text {
                        text: "ms"
                        font.pixelSize: 21
                        color: "#9E9E9E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7MasterTab] 鼠标点击超时时间，发射信号: requestFocusParamIndex(10)")
                        root.requestFocusParamIndex(10)
                        mouse.accepted = false
                    }
                }

                // 焦点指示器
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (root.focusParamIndex === 10) ? "#2196F3" : "transparent"
                    border.width: (root.focusParamIndex === 10) ? 3 : 0
                    radius: 4
                    z: 1000
                    enabled: false
                }
            }
            // ✅ 2026-04-07 [Phase 7.48.88.88]: 配置视图中不再显示轮询数据，移到数据视图
        }  // GridLayout 结束
    }  // ScrollView（配置视图）结束

        // ========== 数据视图 ==========
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

                // ========== DB选择 ==========
                Row {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Layout.topMargin: 5

                    Repeater {
                        model: [
                            { dbNum: 1, label: "DB1 状态区(256B)" },
                            { dbNum: 2, label: "DB2 控制区(64B)" }
                        ]

                        Rectangle {
                            width: 160
                            height: 32
                            radius: 4
                            color: root.pollDbNumber === modelData.dbNum ? "#2196F3" : "#353b4d"
                            border.color: root.pollDbNumber === modelData.dbNum ? "#64B5F6" : "#4a5068"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                // ✅ 2026-04-08 [Phase 7.48.88.90]: 统一类别按钮字体大小
                                font.pixelSize: 13
                                color: root.pollDbNumber === modelData.dbNum ? "#FFFFFF" : "#9E9E9E"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.pollDbNumber = modelData.dbNum
                            }
                        }
                    }
                }

                // ========== 轮询配置信息 ==========
                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    color: "#1e2433"
                    radius: 2

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 20

                        Text {
                            text: "目标: " + root.targetIP + ":" + root.portNumber
                            // ✅ 2026-04-08 [Phase 7.48.88.90]: 统一数据视图字体大小
                            font.pixelSize: 13
                            color: "#81D4FA"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            text: "Rack: " + root.rack + " Slot: " + root.slot
                            font.pixelSize: 13
                            color: "#81D4FA"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            text: "DB" + root.pollDbNumber + " [" + root.pollDbStart + "..." + (root.pollDbStart + root.pollDbSize - 1) + "]"
                            font.pixelSize: 13
                            color: "#81D4FA"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            text: "间隔: " + (root.pollInterval * 100) + "ms"
                            font.pixelSize: 13
                            color: "#81D4FA"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                    }
                }

                // ========== 数据表头 ==========
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
                            text: "偏移"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 60
                            text: "长度"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 200
                            text: "名称"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: parent.width - 348
                            text: "当前值"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                    }
                }

                // ========== 轮询数据列表 ==========
                Repeater {
                    model: root.pollDataList

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
                                width: 60
                                text: modelData.type || ""
                                font.pixelSize: 13
                                font.family: "Consolas"
                                color: "#FFB74D"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                            Text {
                                width: 200
                                text: modelData.name || ""
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width - 348
                                text: "--"
                                font.pixelSize: 13
                                font.family: "Consolas"
                                color: "#4CAF50"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                        }
                    }
                }

                // ========== 统计信息 ==========
                Text {
                    Layout.fillWidth: true
                    text: "共 " + root.pollDataList.length + " 项数据（连接后自动刷新）"
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
