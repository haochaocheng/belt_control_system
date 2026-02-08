// MQTTMonitorTab.qml
// MQTT 数据监控 Tab
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.4]: 重构布局，参照 ModbusTCPMasterTab.qml
// ✅ 2026-02-08 [Phase 7.43.6]: 修复QML语法错误
// ✅ 2026-02-08 [Phase 7.43.11]: 完善与MQTTController的绑定

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../" as DeviceInfo

Rectangle {
    id: root
    color: "transparent"

    property var currentModule: null
    property int focusParamIndex: -1
    property var virtualKeyboard: null

    signal requestFocusParamIndex(int paramIndex)

    // 内部属性
    property bool isPaused: false
    property int messageCount: 0
    property int filteredCount: 0
    property string filterText: ""
    property bool autoScroll: true

    // ✅ 2026-02-08 [Phase 7.43.11]: 连接状态
    property bool isConnected: mqttController ? mqttController.connected : false

    function getParamFieldCount() { return 5 }

    function triggerParamInput(paramIndex) {
        console.log("✅ [MQTTMonitorTab] triggerParamInput:", paramIndex)
        if (paramIndex === 0) {
            if (filterField.activateVirtualKeyboard) filterField.activateVirtualKeyboard()
            else filterField.forceActiveFocus()
        } else if (paramIndex === 1) {
            doPauseResume()
        } else if (paramIndex === 2) {
            doClear()
        } else if (paramIndex === 3) {
            doExport()
        } else if (paramIndex === 4) {
            root.autoScroll = !root.autoScroll
        }
    }

    function handleEnterKey() {
        if (focusParamIndex === 1) {
            doPauseResume()
            return true
        }
        if (focusParamIndex === 2) {
            doClear()
            return true
        }
        if (focusParamIndex === 3) {
            doExport()
            return true
        }
        if (focusParamIndex === 4) {
            root.autoScroll = !root.autoScroll
            return true
        }
        return false
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 暂停/继续函数
    function doPauseResume() {
        isPaused = !isPaused
        console.log("✅ [MQTTMonitorTab] 监控状态:", isPaused ? "暂停" : "继续")
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 清空函数
    function doClear() {
        messageModel.clear()
        messageCount = 0
        filteredCount = 0
        console.log("✅ [MQTTMonitorTab] 清空消息")
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 导出函数
    function doExport() {
        console.log("✅ [MQTTMonitorTab] 导出消息（待实现）")
        // TODO: 实现导出功能
    }

    // 添加消息函数
    function addMessage(topic, payload, qos, retained) {
        if (isPaused) return

        var timestamp = new Date().toLocaleTimeString()
        var filter = filterText.toLowerCase()

        // 检查过滤器
        if (filter.length > 0) {
            if (!topic.toLowerCase().includes(filter) && !payload.toLowerCase().includes(filter)) {
                filteredCount++
                return
            }
        }

        messageModel.insert(0, { topic: topic, payload: payload, qos: qos, retained: retained, timestamp: timestamp })
        messageCount++

        // 限制消息数量（最多保留 1000 条）
        while (messageModel.count > 1000) {
            messageModel.remove(messageModel.count - 1)
        }

        // 自动滚动到顶部
        if (autoScroll) {
            messageListView.positionViewAtBeginning()
        }
    }

    // ✅ 2026-02-08 [Phase 7.43.11]: 监听控制器的消息接收
    Connections {
        target: mqttController
        enabled: mqttController !== null

        function onMessageReceived(moduleIndex, topic, payload) {
            console.log("✅ [MQTTMonitorTab] 收到消息 - 模块:", moduleIndex, "主题:", topic)
            // 将 QByteArray 转换为字符串
            var payloadStr = payload.toString()
            addMessage(topic, payloadStr, 1, false)
        }

        function onReceivedMessagesChanged() {
            // 可以在这里同步控制器的消息列表
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ========== 工具栏 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#252b3d"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // 索引 0: 过滤器
                Text {
                    text: "过滤:"
                    font.pixelSize: 21
                    color: "#9E9E9E"
                }

                Item {
                    Layout.preferredWidth: 250
                    Layout.preferredHeight: 50

                    DeviceInfo.CustomTextField {
                        id: filterField
                        anchors.fill: parent
                        text: root.filterText
                        onTextChanged: root.filterText = text
                        placeholderText: "输入主题或内容关键字"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(0)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 0 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 0 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 分隔符
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: "#3d4556"
                }

                // 索引 1: 暂停/继续按钮
                Item {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 50

                    Button {
                        id: pauseButton
                        anchors.fill: parent
                        text: root.isPaused ? "继续" : "暂停"

                        background: Rectangle {
                            color: root.focusParamIndex === 1 ? (root.isPaused ? "#4CAF50" : "#FF9800") : (root.isPaused ? "#388E3C" : "#F57C00")
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            doPauseResume()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(1)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 1 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 1 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 索引 2: 清空按钮
                Item {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 50

                    Button {
                        id: clearButton
                        anchors.fill: parent
                        text: "清空"

                        background: Rectangle {
                            color: root.focusParamIndex === 2 ? "#e74c3c" : "#d32f2f"
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            doClear()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(2)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 2 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 2 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 索引 3: 导出按钮
                Item {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 50

                    Button {
                        id: exportButton
                        anchors.fill: parent
                        text: "导出"

                        background: Rectangle {
                            color: root.focusParamIndex === 3 ? "#2196F3" : "#1976D2"
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            doExport()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(3)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 3 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 3 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 弹性空间
                Item {
                    Layout.fillWidth: true
                }

                // 索引 4: 自动滚动开关
                Item {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 50

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        Text {
                            text: "自动滚动"
                            font.pixelSize: 16
                            color: "#9E9E9E"
                        }

                        Switch {
                            id: autoScrollSwitch
                            checked: root.autoScroll
                            onCheckedChanged: root.autoScroll = checked

                            indicator: Rectangle {
                                implicitWidth: 50
                                implicitHeight: 26
                                x: autoScrollSwitch.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 13
                                color: autoScrollSwitch.checked ? "#4CAF50" : "#3d4556"

                                Rectangle {
                                    x: autoScrollSwitch.checked ? parent.width - width - 3 : 3
                                    y: 3
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "#FFFFFF"

                                    Behavior on x {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.requestFocusParamIndex(4)
                            mouse.accepted = false
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: root.focusParamIndex === 4 ? "#2196F3" : "transparent"
                        border.width: root.focusParamIndex === 4 ? 3 : 0
                        radius: 4
                        z: 1000
                        enabled: false
                    }
                }

                // 统计信息
                Text {
                    text: "消息: " + root.messageCount + " | 过滤: " + root.filteredCount
                    font.pixelSize: 14
                    color: "#808080"
                }
            }
        }

        // ========== 消息列表 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#252b3d"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // 表头
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    color: "#1a1f2e"
                    radius: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 15

                        Text {
                            text: "时间"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#B0B0B0"
                            Layout.preferredWidth: 100
                        }

                        Text {
                            text: "主题"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#B0B0B0"
                            Layout.preferredWidth: 250
                        }

                        Text {
                            text: "QoS"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#B0B0B0"
                            Layout.preferredWidth: 50
                        }

                        Text {
                            text: "消息内容"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#B0B0B0"
                            Layout.fillWidth: true
                        }
                    }
                }

                // 消息列表
                ListView {
                    id: messageListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2

                    model: ListModel {
                        id: messageModel

                        ListElement {
                            topic: "belt_control/module1/status"
                            payload: "{\"speed\": 120, \"tension\": 85}"
                            qos: 1
                            retained: false
                            timestamp: "10:30:45"
                        }
                    }

                    delegate: Rectangle {
                        width: messageListView.width
                        height: 45
                        color: index % 2 === 0 ? "#2a3142" : "#252b3d"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15
                            spacing: 15

                            Text {
                                text: model.timestamp
                                font.pixelSize: 13
                                color: "#808080"
                                Layout.preferredWidth: 100
                            }

                            Text {
                                text: model.topic
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#4CAF50"
                                Layout.preferredWidth: 250
                                elide: Text.ElideRight
                            }

                            Row {
                                Layout.preferredWidth: 50
                                spacing: 5

                                Text {
                                    text: model.qos.toString()
                                    font.pixelSize: 13
                                    color: "#2196F3"
                                }

                                Text {
                                    text: model.retained ? "R" : ""
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: "#FF9800"
                                }
                            }

                            Text {
                                text: model.payload
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: console.log("✅ [MQTTMonitorTab] 点击消息:", model.topic, model.payload)
                        }
                    }

                    // 空状态提示
                    Text {
                        anchors.centerIn: parent
                        text: root.isPaused ? "监控已暂停" : "等待消息..."
                        font.pixelSize: 16
                        color: "#606060"
                        visible: messageModel.count === 0 || (messageModel.count === 1 && messageModel.get(0).topic === "belt_control/module1/status")
                    }
                }
            }
        }

        // ========== 状态栏 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#1a1f2e"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 25

                // 连接状态
                Row {
                    spacing: 8

                    // ✅ 2026-02-08 [Phase 7.43.11]: 使用isConnected属性
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.isConnected ? "#4CAF50" : "#9E9E9E"
                    }

                    Text {
                        text: root.isConnected ? "已连接" : "未连接"
                        font.pixelSize: 14
                        color: "#B0B0B0"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 监控状态
                Text {
                    text: root.isPaused ? "⏸ 已暂停" : "▶ 监控中"
                    font.pixelSize: 14
                    color: root.isPaused ? "#FF9800" : "#4CAF50"
                }

                // 弹性空间
                Item {
                    Layout.fillWidth: true
                }

                // 消息统计
                Text {
                    text: "总消息: " + root.messageCount + " | 已过滤: " + root.filteredCount
                    font.pixelSize: 14
                    color: "#808080"
                }
            }
        }
    }
}
