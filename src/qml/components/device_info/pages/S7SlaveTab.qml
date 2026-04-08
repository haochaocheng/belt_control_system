// S7SlaveTab.qml
// S7 从站（服务器）配置Tab
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
    property int portIndex: 0  // ✅ 2026-04-07 [Phase 7.48.88.84]: 端口索引

    // ✅ 2026-04-07 [Phase 7.48.88.84]: 数据映射可视化
    property int mapCategory: 0   // 0=DB1(状态区), 1=DB2(控制区)
    property var currentMapData: []

    // ✅ 2026-04-07 [Phase 7.48.88.88]: 配置/数据视图切换
    property int viewMode: 0  // 0=配置视图, 1=数据视图

    // ✅ 2026-02-08 [Phase 7.42.13]: 信号 - 请求更新焦点索引
    signal requestFocusParamIndex(int paramIndex)

    // ========== 参数数据 ==========
    property int portNumber: 102  // S7 标准端口
    property bool isEnabled: false
    property string bindIP: "0.0.0.0"
    property int maxConnections: 8
    property int dbCount: 10
    property int dbSize: 1024
    property int merkerSize: 256
    property int inputSize: 128
    property int outputSize: 128

    // ========== 函数 ==========
    function getParamFieldCount() {
        return 9
    }

    // ✅ 2026-04-08 [Phase 7.48.88.90]: 键盘切换视图模式
    function toggleViewMode() {
        root.viewMode = (root.viewMode === 0) ? 1 : 0
        console.log("✅ [S7SlaveTab] 切换视图:", root.viewMode === 0 ? "参数配置" : "映射表")
        if (root.viewMode === 1) loadMapData()
    }

    // ✅ 2026-04-08 [Phase 7.48.88.94]: 数据视图键盘导航（类别切换+滚动）
    function handleDataViewKey(direction) {
        if (root.viewMode !== 1) return false
        var scrollStep = 84  // 3行 × 28px
        switch(direction) {
        case "Left":
        case "Right":
            root.mapCategory = root.mapCategory === 0 ? 1 : 0
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

    // ✅ 2026-02-08 [Phase 7.42.13]: 重构虚拟键盘支持
    function triggerParamInput(index) {
        console.log("✅ [S7SlaveTab] triggerParamInput:", index)

        var inputField = null

        switch(index) {
        case 0:  // 端口号（CustomSpinBox）
            inputField = portNumberField
            break
        case 1:  // 状态（CustomComboBox）
            console.log("✅ [S7SlaveTab] 切换状态")
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return
        case 2:  // 绑定IP（CustomTextField）
            inputField = bindIPField
            break
        case 3:  // 最大连接数（CustomSpinBox）
            inputField = maxConnectionsField
            break
        case 4:  // DB数量（CustomSpinBox）
            inputField = dbCountField
            break
        case 5:  // DB大小（CustomSpinBox）
            inputField = dbSizeField
            break
        case 6:  // M区大小（CustomSpinBox）
            inputField = merkerSizeField
            break
        case 7:  // I区大小（CustomSpinBox）
            inputField = inputSizeField
            break
        case 8:  // Q区大小（CustomSpinBox）
            inputField = outputSizeField
            break
        }

        // 激活虚拟键盘
        if (inputField) {
            console.log("✅ [S7SlaveTab] 激活虚拟键盘 - 控件:", inputField)
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
        console.log("✅ [S7SlaveTab] handleEnterKey - focusParamIndex:", focusParamIndex)

        // 如果是 ComboBox，切换选项
        if (focusParamIndex === 1) {  // 状态（ComboBox）
            statusField.currentIndex = (statusField.currentIndex + 1) % statusField.model.length
            return true  // 已处理，不需要弹出虚拟键盘
        }

        // 其他输入框返回 false，让 DeviceSettingsDialog 调用 triggerParamInput
        return false
    }

    // ✅ 2026-04-07 [Phase 7.48.88.84]: 加载S7数据映射
    function loadMapData() {
        if (typeof tcpDataAdapter === "undefined") {
            console.log("⚠️ [S7SlaveTab] tcpDataAdapter 未注册")
            root.currentMapData = []
            return
        }
        switch(root.mapCategory) {
        case 0:
            root.currentMapData = tcpDataAdapter.getS7DB1Map(root.portIndex)
            break
        case 1:
            root.currentMapData = tcpDataAdapter.getS7DB2Map(root.portIndex)
            break
        default:
            root.currentMapData = []
        }
        console.log("✅ [S7SlaveTab] 加载映射数据 - 类别:", root.mapCategory, "数量:", root.currentMapData.length)
    }

    onMapCategoryChanged: loadMapData()
    onPortIndexChanged: loadMapData()
    Component.onCompleted: Qt.callLater(loadMapData)

    // ✅ 2026-04-08 [Phase 7.48.88.92]: 映射表数据定时刷新（仅在数据视图可见时运行）
    Timer {
        id: mapRefreshTimer
        interval: 1000
        running: root.viewMode === 1
        repeat: true
        onTriggered: root.loadMapData()
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
                    onValueChanged: root.portNumber = value
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7SlaveTab] 鼠标点击端口号，发射信号: requestFocusParamIndex(0)")
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
                        console.log("✅ [S7SlaveTab] 鼠标点击状态，发射信号: requestFocusParamIndex(1)")
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

            // ========== 第二行：绑定IP（左侧，索引2）、最大连接数（右侧，索引3）==========

            // 绑定IP标签
            Text {
                text: "绑定IP:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 1
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // 绑定IP输入
            Item {
                Layout.column: 1
                Layout.row: 1
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: bindIPField.implicitHeight

                DeviceInfo.CustomTextField {
                    id: bindIPField
                    anchors.fill: parent
                    text: root.bindIP
                    onTextChanged: root.bindIP = text
                    placeholderText: "0.0.0.0"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: function(mouse) {
                        console.log("✅ [S7SlaveTab] 鼠标点击绑定IP，发射信号: requestFocusParamIndex(2)")
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
                        to: 32
                        value: root.maxConnections
                        onValueChanged: root.maxConnections = value
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
                        console.log("✅ [S7SlaveTab] 鼠标点击最大连接数，发射信号: requestFocusParamIndex(3)")
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

            // ========== 第三行：DB数量（左侧，索引4）、DB大小（右侧，索引5）==========

            // DB数量标签
            Text {
                text: "DB数量:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // DB数量输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: dbCountRow.implicitHeight

                Row {
                    id: dbCountRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: dbCountField
                        width: parent.width - 30
                        height: 60
                        from: 1
                        to: 100
                        value: root.dbCount
                        onValueChanged: root.dbCount = value
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
                        console.log("✅ [S7SlaveTab] 鼠标点击DB数量，发射信号: requestFocusParamIndex(4)")
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

            // DB大小标签
            Text {
                text: "DB大小:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 2
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // DB大小输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 2
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: dbSizeRow.implicitHeight

                Row {
                    id: dbSizeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: dbSizeField
                        width: parent.width - 60
                        height: 60
                        from: 64
                        to: 65535
                        value: root.dbSize
                        onValueChanged: root.dbSize = value
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
                        console.log("✅ [S7SlaveTab] 鼠标点击DB大小，发射信号: requestFocusParamIndex(5)")
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

            // ========== 第四行：M区大小（左侧，索引6）、I区大小（右侧，索引7）==========

            // M区大小标签
            Text {
                text: "M区大小:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // M区大小输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: merkerSizeRow.implicitHeight

                Row {
                    id: merkerSizeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: merkerSizeField
                        width: parent.width - 60
                        height: 60
                        from: 32
                        to: 65535
                        value: root.merkerSize
                        onValueChanged: root.merkerSize = value
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
                        console.log("✅ [S7SlaveTab] 鼠标点击M区大小，发射信号: requestFocusParamIndex(6)")
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

            // I区大小标签
            Text {
                text: "I区大小:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 2
                Layout.row: 3
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // I区大小输入（带单位）
            Item {
                Layout.column: 3
                Layout.row: 3
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: inputSizeRow.implicitHeight

                Row {
                    id: inputSizeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: inputSizeField
                        width: parent.width - 60
                        height: 60
                        from: 32
                        to: 65535
                        value: root.inputSize
                        onValueChanged: root.inputSize = value
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
                        console.log("✅ [S7SlaveTab] 鼠标点击I区大小，发射信号: requestFocusParamIndex(7)")
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

            // ========== 第五行：Q区大小（左侧，索引8）==========

            // Q区大小标签
            Text {
                text: "Q区大小:"
                font.pixelSize: 21
                color: "#9E9E9E"
                Layout.column: 0
                Layout.row: 4
                Layout.preferredWidth: 160
                horizontalAlignment: Text.AlignRight
            }

            // Q区大小输入（带单位）
            Item {
                Layout.column: 1
                Layout.row: 4
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                implicitHeight: outputSizeRow.implicitHeight

                Row {
                    id: outputSizeRow
                    width: parent.width
                    height: 60
                    spacing: 5

                    DeviceInfo.CustomSpinBox {
                        id: outputSizeField
                        width: parent.width - 60
                        height: 60
                        from: 32
                        to: 65535
                        value: root.outputSize
                        onValueChanged: root.outputSize = value
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
                        console.log("✅ [S7SlaveTab] 鼠标点击Q区大小，发射信号: requestFocusParamIndex(8)")
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
                Row {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Layout.topMargin: 5

                    Repeater {
                        model: ["DB1 状态区(256B)", "DB2 控制区(64B)"]

                        Rectangle {
                            width: 160
                            height: 32
                            radius: 4
                            color: root.mapCategory === index ? "#2196F3" : "#353b4d"
                            // ✅ 2026-04-08 [Phase 7.48.88.94]: 当前类别焦点橙色高亮
                            border.color: root.focusSubArea === 2 && root.focusParamIndex >= 0 && root.mapCategory === index ? "#FF9800" : (root.mapCategory === index ? "#64B5F6" : "#4a5068")
                            border.width: root.focusSubArea === 2 && root.focusParamIndex >= 0 && root.mapCategory === index ? 3 : 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                // ✅ 2026-04-08 [Phase 7.48.88.90]: 统一类别按钮字体大小
                                font.pixelSize: 13
                                color: root.mapCategory === index ? "#FFFFFF" : "#9E9E9E"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.mapCategory = index
                            }
                        }
                    }
                }

                // ========== 映射表头 ==========
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
                            // ✅ 2026-04-08 [Phase 7.48.88.90]: 统一映射表字体大小为14px
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
                            width: 180
                            text: "名称"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        // ✅ 2026-04-08 [Phase 7.48.88.90]: 新增当前值列
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
                            width: parent.width - 408
                            text: "类型/说明"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#64B5F6"
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                    }
                }

                // ========== 映射数据列表 ==========
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
                                // ✅ 2026-04-08 [Phase 7.48.88.90]: 统一映射表字体大小为13px
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
                                width: 180
                                text: modelData.name || ""
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                                elide: Text.ElideRight
                            }
                            // ✅ 2026-04-08 [Phase 7.48.88.90]: 新增当前值列
                            Text {
                                width: 80
                                text: modelData.value !== undefined ? String(modelData.value) : "--"
                                font.pixelSize: 13
                                font.family: "Consolas"
                                color: "#81D4FA"
                                verticalAlignment: Text.AlignVCenter
                                height: parent.height
                            }
                            Text {
                                width: parent.width - 408
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
