import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制面板 - 水平时间轴流程图
Rectangle {
    id: root
    color: "transparent"

    property var systemConfig: null

    // 当前Tab: 0=启动顺序, 1=停止顺序, 2=全局设置
    property int currentTab: 0

    // 本地编辑数据（保存时才写入systemConfig）
    property var startupSeq: []
    property var stopSeq: []
    property var startupDelays: []
    property var stopDelays: []
    property double defaultDelay: 1.0

    // 当前编辑的序列和延时（根据Tab切换）
    property var currentSeq: currentTab === 0 ? startupSeq : stopSeq
    property var currentDelays: currentTab === 0 ? startupDelays : stopDelays
    property color themeColor: currentTab === 0 ? "#00ff88" : "#ff4757"

    // 设备池分组定义
    readonly property var deviceGroups: [
        { name: "电机", color: "#5dade2", devices: ["1号电机", "2号电机", "3号电机", "4号电机", "5号电机", "6号电机", "7号电机", "8号电机"] },
        { name: "制动器", color: "#f39c12", devices: ["1号制动器", "2号制动器", "3号制动器", "4号制动器", "5号制动器", "6号制动器", "7号制动器", "8号制动器"] },
        { name: "张紧", color: "#00ff88", devices: ["张紧控制"] },
        { name: "洒水", color: "#00d4ff", devices: ["洒水1", "洒水2", "洒水3", "洒水4", "洒水5", "洒水6", "洒水7", "洒水8"] }
    ]

    Component.onCompleted: loadFromConfig()

    function loadFromConfig() {
        if (!systemConfig) return
        startupSeq = systemConfig.startupSequence ? systemConfig.startupSequence.slice() : ["张紧", "抱闸", "1号电机", "2号电机"]
        stopSeq = systemConfig.stopSequence ? systemConfig.stopSequence.slice() : ["2号电机", "1号电机", "抱闸", "张紧"]

        var sDelays = systemConfig.startupDelays
        startupDelays = []
        if (sDelays && sDelays.length > 0) {
            for (var i = 0; i < sDelays.length; i++) startupDelays.push(sDelays[i])
        } else {
            for (var j = 0; j < startupSeq.length; j++) startupDelays.push(1.0)
        }

        var tDelays = systemConfig.stopDelays
        stopDelays = []
        if (tDelays && tDelays.length > 0) {
            for (var k = 0; k < tDelays.length; k++) stopDelays.push(tDelays[k])
        } else {
            for (var l = 0; l < stopSeq.length; l++) stopDelays.push(1.0)
        }

        defaultDelay = systemConfig.defaultDelay > 0 ? systemConfig.defaultDelay : 1.0
        // 确保长度一致
        while (startupDelays.length < startupSeq.length) startupDelays.push(defaultDelay)
        while (stopDelays.length < stopSeq.length) stopDelays.push(defaultDelay)
    }

    function saveToConfig() {
        if (!systemConfig) return
        systemConfig.startupSequence = startupSeq.slice()
        systemConfig.stopSequence = stopSeq.slice()
        systemConfig.startupDelays = startupDelays.slice()
        systemConfig.stopDelays = stopDelays.slice()
        systemConfig.defaultDelay = defaultDelay
        systemConfig.saveConfig()
        console.log("✅ 逻辑控制配置已保存")
    }

    function addDevice(deviceName) {
        var seq = currentTab === 0 ? startupSeq : stopSeq
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (seq.length >= 10) return
        seq.push(deviceName)
        delays.push(defaultDelay)
        if (currentTab === 0) { startupSeq = seq.slice(); startupDelays = delays.slice() }
        else { stopSeq = seq.slice(); stopDelays = delays.slice() }
    }

    function removeDevice(index) {
        var seq = currentTab === 0 ? startupSeq : stopSeq
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (index < 0 || index >= seq.length) return
        seq.splice(index, 1)
        delays.splice(index, 1)
        if (currentTab === 0) { startupSeq = seq.slice(); startupDelays = delays.slice() }
        else { stopSeq = seq.slice(); stopDelays = delays.slice() }
    }

    function updateDelay(index, value) {
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (index < 0 || index >= delays.length) return
        delays[index] = value
        if (currentTab === 0) startupDelays = delays.slice()
        else stopDelays = delays.slice()
    }

    function swapDevices(fromIndex, toIndex) {
        var seq = currentTab === 0 ? startupSeq : stopSeq
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (fromIndex < 0 || fromIndex >= seq.length || toIndex < 0 || toIndex >= seq.length) return
        var tmpName = seq[fromIndex]; seq[fromIndex] = seq[toIndex]; seq[toIndex] = tmpName
        var tmpDelay = delays[fromIndex]; delays[fromIndex] = delays[toIndex]; delays[toIndex] = tmpDelay
        if (currentTab === 0) { startupSeq = seq.slice(); startupDelays = delays.slice() }
        else { stopSeq = seq.slice(); stopDelays = delays.slice() }
    }

    function reverseToStop() {
        stopSeq = startupSeq.slice().reverse()
        stopDelays = startupDelays.slice().reverse()
    }

    function isDeviceInCurrentSeq(deviceName) {
        var seq = currentTab === 0 ? startupSeq : stopSeq
        return seq.indexOf(deviceName) >= 0
    }

    function getTotalTime() {
        var delays = currentTab === 0 ? startupDelays : stopDelays
        var total = 0
        for (var i = 0; i < delays.length; i++) total += delays[i]
        return total.toFixed(1)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // ========== Tab栏 ==========
        Row {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { text: "▶ 启动顺序", color: "#00ff88" },
                    { text: "■ 停止顺序", color: "#ff4757" },
                    { text: "⚙ 全局设置", color: "#00d4ff" }
                ]
                Rectangle {
                    width: 130
                    height: 36
                    radius: 6
                    color: root.currentTab === index ? modelData.color : "#1e3a5f"
                    opacity: root.currentTab === index ? 1.0 : 0.6
                    border.color: modelData.color
                    border.width: root.currentTab === index ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.text
                        font.pixelSize: 14
                        font.bold: root.currentTab === index
                        color: root.currentTab === index ? "#1a2332" : modelData.color
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.currentTab = index
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#00d4ff"; opacity: 0.3 }

        // ========== 内容区 ==========
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Tab 0/1: 时间轴
            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                visible: root.currentTab < 2

                // 标题
                Text {
                    text: root.currentTab === 0 ? "启动流程时间轴" : "停止流程时间轴"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeColor
                }

                // ========== 水平时间轴 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    color: "#0d1520"
                    radius: 8
                    border.color: root.themeColor
                    border.width: 1
                    opacity: 0.9

                    Flickable {
                        id: timelineFlickable
                        anchors.fill: parent
                        anchors.margins: 10
                        contentWidth: timelineRow.width + 20
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: timelineRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Repeater {
                                model: root.currentSeq.length

                                Row {
                                    spacing: 0

                                    // 设备节点卡片
                                    Rectangle {
                                        id: nodeCard
                                        width: 90
                                        height: 100
                                        radius: 8
                                        color: nodeMouseArea.containsMouse ? "#2a5080" : "#1e3a5f"
                                        border.color: root.themeColor
                                        border.width: 2

                                        // 顶部指示条
                                        Rectangle {
                                            width: parent.width - 4
                                            height: 4
                                            anchors.top: parent.top
                                            anchors.topMargin: 2
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            radius: 2
                                            color: root.themeColor
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "(" + (index + 1) + ")"
                                                font.pixelSize: 11
                                                color: "#aaaaaa"
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: root.currentSeq[index] || ""
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: "white"
                                            }
                                            // 上下移动按钮
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 8
                                                Rectangle {
                                                    width: 24; height: 20; radius: 3
                                                    color: leftBtn.containsMouse ? "#3498db" : "#2c3e50"
                                                    visible: index > 0
                                                    Text { anchors.centerIn: parent; text: "◀"; color: "white"; font.pixelSize: 12 }
                                                    MouseArea { id: leftBtn; anchors.fill: parent; hoverEnabled: true; onClicked: root.swapDevices(index, index - 1) }
                                                }
                                                Rectangle {
                                                    width: 24; height: 20; radius: 3
                                                    color: delBtn.containsMouse ? "#e74c3c" : "#2c3e50"
                                                    Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 14; font.bold: true }
                                                    MouseArea { id: delBtn; anchors.fill: parent; hoverEnabled: true; onClicked: root.removeDevice(index) }
                                                }
                                                Rectangle {
                                                    width: 24; height: 20; radius: 3
                                                    color: rightBtn.containsMouse ? "#3498db" : "#2c3e50"
                                                    visible: index < root.currentSeq.length - 1
                                                    Text { anchors.centerIn: parent; text: "▶"; color: "white"; font.pixelSize: 12 }
                                                    MouseArea { id: rightBtn; anchors.fill: parent; hoverEnabled: true; onClicked: root.swapDevices(index, index + 1) }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: nodeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            // 点击弹出编辑
                                            onClicked: {
                                                editPopup.editIndex = index
                                                editPopup.editDelay = root.currentDelays[index] || 1.0
                                                editPopup.open()
                                            }
                                        }
                                    }

                                    // 连接箭头 + 延时标签（最后一个不显示）
                                    Item {
                                        width: 70
                                        height: 100
                                        visible: index < root.currentSeq.length - 1

                                        // 箭头线
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 10
                                            height: 2
                                            x: 5
                                            color: {
                                                var d = root.currentDelays[index] || 1.0
                                                return d <= 2.0 ? "#00ff88" : (d <= 5.0 ? "#f39c12" : "#ff4757")
                                            }
                                        }
                                        // 箭头头
                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "▶"
                                            font.pixelSize: 10
                                            color: {
                                                var d = root.currentDelays[index] || 1.0
                                                return d <= 2.0 ? "#00ff88" : (d <= 5.0 ? "#f39c12" : "#ff4757")
                                            }
                                        }
                                        // 延时标签
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.verticalCenter
                                            anchors.bottomMargin: 4
                                            width: 40
                                            height: 20
                                            radius: 10
                                            color: "#1a2332"
                                            border.color: "#5dade2"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: (root.currentDelays[index] || 1.0).toFixed(1) + "s"
                                                font.pixelSize: 11
                                                color: "#5dade2"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    editPopup.editIndex = index
                                                    editPopup.editDelay = root.currentDelays[index] || 1.0
                                                    editPopup.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 空状态提示
                    Text {
                        anchors.centerIn: parent
                        text: "暂无设备，请从下方设备池添加"
                        font.pixelSize: 14
                        color: "#666666"
                        visible: root.currentSeq.length === 0
                    }
                }

                // ========== 提示栏 ==========
                Text {
                    text: "点击节点编辑延时 │ ◀▶ 调整顺序 │ × 删除设备 │ 点击连线延时标签修改"
                    font.pixelSize: 11
                    color: "#666666"
                }

                // ========== 设备池 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#0d1520"
                    radius: 8
                    border.color: "#2c3e50"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Text {
                            text: "设备池（点击添加到流程，已添加设备灰显）"
                            font.pixelSize: 12
                            color: "#888888"
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: devicePoolColumn.height
                            clip: true

                            ColumnLayout {
                                id: devicePoolColumn
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: root.deviceGroups.length

                                    ColumnLayout {
                                        // ✅ 2026-03-20 [Phase 7.48.57]: 保存外层组索引，防止被内层Repeater的index覆盖
                                        property int groupIndex: index
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            text: root.deviceGroups[parent.groupIndex].name
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: root.deviceGroups[parent.groupIndex].color
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            property int gIdx: parent.groupIndex

                                            Repeater {
                                                model: root.deviceGroups[parent.gIdx].devices

                                                Rectangle {
                                                    property string devName: modelData
                                                    property bool inSeq: root.isDeviceInCurrentSeq(devName)
                                                    property color groupColor: root.deviceGroups[parent.gIdx].color

                                                    width: 72
                                                    height: 28
                                                    radius: 4
                                                    color: inSeq ? "#1a1a2e" : (poolItemMa.containsMouse ? groupColor : "#1e3a5f")
                                                    opacity: inSeq ? 0.4 : 1.0
                                                    border.color: groupColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.devName
                                                        font.pixelSize: 11
                                                        color: parent.inSeq ? "#555555" : "white"
                                                    }

                                                    MouseArea {
                                                        id: poolItemMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !parent.inSeq && root.currentSeq.length < 10
                                                        onClicked: root.addDevice(parent.devName)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ========== 底部状态栏 ==========
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "设备: " + root.currentSeq.length + "/10"
                        font.pixelSize: 13
                        color: "#aaaaaa"
                    }
                    Text {
                        text: "总耗时: " + root.getTotalTime() + "s"
                        font.pixelSize: 13
                        color: "#aaaaaa"
                    }

                    Item { Layout.fillWidth: true }

                    // 一键反转按钮（仅启动Tab显示）
                    Rectangle {
                        width: 140
                        height: 32
                        radius: 6
                        color: reverseBtn.containsMouse ? "#f39c12" : "#2c3e50"
                        border.color: "#f39c12"
                        visible: root.currentTab === 0

                        Text {
                            anchors.centerIn: parent
                            text: "一键反转→停止"
                            font.pixelSize: 13
                            color: "white"
                        }
                        MouseArea {
                            id: reverseBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.reverseToStop()
                        }
                    }

                    // 保存按钮
                    Rectangle {
                        width: 80
                        height: 32
                        radius: 6
                        color: saveBtn.containsMouse ? "#27ae60" : "#1e8449"
                        border.color: "#00ff88"

                        Text {
                            anchors.centerIn: parent
                            text: "保存"
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                        }
                        MouseArea {
                            id: saveBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.saveToConfig()
                        }
                    }
                }
            }

            // ========== Tab 2: 全局设置 ==========
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 16
                visible: root.currentTab === 2

                Text {
                    text: "全局设置"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#00d4ff"
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Text { text: "默认延时（秒）:"; font.pixelSize: 14; color: "#cccccc" }
                    RowLayout {
                        spacing: 8
                        Slider {
                            id: defaultDelaySlider
                            from: 0.5; to: 30.0; stepSize: 0.5
                            value: root.defaultDelay
                            Layout.preferredWidth: 200
                            onValueChanged: root.defaultDelay = value
                        }
                        Text {
                            text: defaultDelaySlider.value.toFixed(1) + "s"
                            font.pixelSize: 14
                            color: "#5dade2"
                        }
                    }

                    Text { text: "预警时间（秒）:"; font.pixelSize: 14; color: "#cccccc" }
                    Text {
                        text: root.systemConfig ? root.systemConfig.warningTimeSeconds + "s" : "N/A"
                        font.pixelSize: 14
                        color: "#5dade2"
                    }

                    Text { text: "预警模式:"; font.pixelSize: 14; color: "#cccccc" }
                    Text {
                        text: root.systemConfig ? (root.systemConfig.warningMode === 0 ? "按时间" : "按次数") : "N/A"
                        font.pixelSize: 14
                        color: "#5dade2"
                    }
                }

                Item { Layout.fillHeight: true }

                // 保存 + 恢复默认
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 100
                        height: 32
                        radius: 6
                        color: resetBtn.containsMouse ? "#c0392b" : "#2c3e50"
                        border.color: "#ff4757"

                        Text { anchors.centerIn: parent; text: "恢复默认"; font.pixelSize: 13; color: "white" }
                        MouseArea {
                            id: resetBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.startupSeq = ["张紧", "抱闸", "1号电机", "2号电机"]
                                root.stopSeq = ["2号电机", "1号电机", "抱闸", "张紧"]
                                root.startupDelays = [1.0, 1.0, 1.0, 1.0]
                                root.stopDelays = [1.0, 1.0, 1.0, 1.0]
                                root.defaultDelay = 1.0
                            }
                        }
                    }

                    Rectangle {
                        width: 80
                        height: 32
                        radius: 6
                        color: saveBtn2.containsMouse ? "#27ae60" : "#1e8449"
                        border.color: "#00ff88"

                        Text { anchors.centerIn: parent; text: "保存"; font.pixelSize: 14; font.bold: true; color: "white" }
                        MouseArea {
                            id: saveBtn2
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.saveToConfig()
                        }
                    }
                }
            }
        }
    }

    // ========== 编辑弹窗 ==========
    Popup {
        id: editPopup
        anchors.centerIn: parent
        width: 260
        height: 180
        modal: true

        property int editIndex: -1
        property double editDelay: 1.0

        background: Rectangle {
            color: "#1a2332"
            radius: 10
            border.color: "#00d4ff"
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "编辑设备 - (" + (editPopup.editIndex + 1) + ") " + (root.currentSeq[editPopup.editIndex] || "")
                font.pixelSize: 14
                font.bold: true
                color: "#00d4ff"
            }

            RowLayout {
                spacing: 8
                Text { text: "延时:"; font.pixelSize: 13; color: "#cccccc" }
                Slider {
                    id: editDelaySlider
                    from: 0.5; to: 30.0; stepSize: 0.5
                    value: editPopup.editDelay
                    Layout.fillWidth: true
                }
                Text {
                    text: editDelaySlider.value.toFixed(1) + "s"
                    font.pixelSize: 13
                    color: "#5dade2"
                    Layout.preferredWidth: 40
                }
            }

            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignRight

                Rectangle {
                    width: 80; height: 30; radius: 6
                    color: delDevBtn.containsMouse ? "#e74c3c" : "#c0392b"
                    Text { anchors.centerIn: parent; text: "删除设备"; font.pixelSize: 12; color: "white" }
                    MouseArea {
                        id: delDevBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { root.removeDevice(editPopup.editIndex); editPopup.close() }
                    }
                }

                Rectangle {
                    width: 60; height: 30; radius: 6
                    color: confirmBtn.containsMouse ? "#27ae60" : "#1e8449"
                    Text { anchors.centerIn: parent; text: "确定"; font.pixelSize: 12; font.bold: true; color: "white" }
                    MouseArea {
                        id: confirmBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { root.updateDelay(editPopup.editIndex, editDelaySlider.value); editPopup.close() }
                    }
                }
            }
        }
    }
}
