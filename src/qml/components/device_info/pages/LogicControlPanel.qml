import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制面板 - 水平时间轴流程图
// ✅ 2026-03-20 修复4项问题：默认序列/字体1.5倍/调整顺序/保存确认
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

    // ✅ 2026-03-20 修复：保存提示状态
    property bool saveSuccess: false

    // ✅ 2026-03-21 [Phase 7.48.64]: 时间轴动态模拟属性
    property bool isSimulating: false           // 是否正在模拟播放
    property real simTime: 0.0                  // 当前模拟时间（秒）
    property real simTotalTime: 1.0             // 总模拟时长（秒）
    property int  simActivatedCount: 0          // 已激活设备数
    property var  simActivationTimes: []        // 各设备激活时刻（累计秒数）

    // 设备池分组定义
    readonly property var deviceGroups: [
        { name: "电机", color: "#5dade2", devices: ["1号电机", "2号电机", "3号电机", "4号电机", "5号电机", "6号电机", "7号电机", "8号电机"] },
        { name: "制动器", color: "#f39c12", devices: ["1号制动器", "2号制动器", "3号制动器", "4号制动器", "5号制动器", "6号制动器", "7号制动器", "8号制动��"] },
        { name: "张紧", color: "#00ff88", devices: ["张紧控制"] },
        { name: "洒水", color: "#00d4ff", devices: ["洒水1", "洒水2", "洒水3", "洒水4", "洒水5", "洒水6", "洒水7", "洒水8"] }
    ]

    Component.onCompleted: loadFromConfig()

    // ✅ 2026-03-20 修复：systemConfig由Loader.onLoaded设置，晚于Component.onCompleted
    // 需要在systemConfig变化时重新加载配置
    onSystemConfigChanged: {
        if (systemConfig) loadFromConfig()
    }

    // 旧名称→新名称映射（设备上已有旧配置需要迁移）
    readonly property var nameMapping: ({
        "张紧": "张紧控制",
        "抱闸": "1号制动器"
    })

    function migrateOldNames(seq) {
        var migrated = []
        for (var i = 0; i < seq.length; i++) {
            var name = seq[i]
            migrated.push(nameMapping[name] !== undefined ? nameMapping[name] : name)
        }
        return migrated
    }

    function loadFromConfig() {
        if (!systemConfig) return
        // ✅ 2026-03-20 修复：默认序列使用设备池中的实际名称
        // startupSeq = systemConfig.startupSequence ? systemConfig.startupSequence.slice() : ["张紧", "抱闸", "1号电机", "2号电机"]
        // stopSeq = systemConfig.stopSequence ? systemConfig.stopSequence.slice() : ["2号电机", "1号电机", "抱闸", "张紧"]
        var loadedStartup = systemConfig.startupSequence && systemConfig.startupSequence.length > 0 ? systemConfig.startupSequence.slice() : []
        var loadedStop = systemConfig.stopSequence && systemConfig.stopSequence.length > 0 ? systemConfig.stopSequence.slice() : []
        // ✅ 2026-03-20 修复：迁移旧名称（"张紧"→"张紧控制"，"抱闸"→"1号制动器"）
        startupSeq = loadedStartup.length > 0 ? migrateOldNames(loadedStartup) : ["张紧控制", "1号制动器", "1号电机", "2号电机"]
        stopSeq = loadedStop.length > 0 ? migrateOldNames(loadedStop) : ["2号电机", "1号电机", "1号制动器", "张紧控制"]

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
        // ✅ 2026-03-20 修复：显示保存成功提示
        saveSuccess = true
        saveSuccessTimer.restart()
    }

    // ✅ 2026-03-20 保存成功提示自动隐藏定时器
    Timer {
        id: saveSuccessTimer
        interval: 2000
        onTriggered: root.saveSuccess = false
    }

    // ✅ 2026-03-21 [Phase 7.48.64]: 模拟播放定时器（100ms = 0.1秒精度）
    Timer {
        id: simTimer
        interval: 100
        repeat: true
        onTriggered: {
            root.simTime = Math.round((root.simTime + 0.1) * 10) / 10

            // 检查需要激活的设备
            var times = root.simActivationTimes
            for (var i = 0; i < times.length; i++) {
                if (root.simTime >= times[i] && root.simActivatedCount <= i) {
                    root.simActivatedCount = i + 1
                }
            }

            // 模拟结束（总时间+最后设备留存1秒）
            if (root.simTime >= root.simTotalTime + 1.0) {
                root.stopSimulation()
            }
        }
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

    // ✅ 2026-03-21 [Phase 7.48.64]: 模拟播放控制
    function startSimulation() {
        if (root.currentSeq.length === 0) return
        var delays = root.currentDelays
        var times = [0.0]     // 设备0在t=0激活
        var cumulative = 0.0
        for (var i = 0; i < delays.length - 1; i++) {
            cumulative += delays[i]
            times.push(cumulative)
        }
        // 总时长 = 最后一个激活时刻 + 该设备的延时
        var lastDelay = delays.length > 0 ? (delays[delays.length - 1] || 1.0) : 1.0
        root.simActivationTimes = times
        root.simTotalTime = cumulative + lastDelay
        root.simTime = 0.0
        root.simActivatedCount = 0
        root.isSimulating = true
        simTimer.restart()
    }

    function stopSimulation() {
        simTimer.stop()
        root.isSimulating = false
        root.simTime = 0.0
        root.simActivatedCount = 0
    }

    // 计算游标在 timelineRow 内的 X 坐标（设备i中心 = i*200+60）
    function getCursorX() {
        var n = root.currentSeq.length
        if (n === 0) return -10
        if (n === 1) return 60
        var times = root.simActivationTimes
        if (times.length === 0) return 60
        for (var i = 0; i < n - 1; i++) {
            var t0 = times[i]
            var t1 = times[i + 1]
            if (root.simTime <= t1) {
                var progress = t1 > t0 ? Math.min(1.0, (root.simTime - t0) / (t1 - t0)) : 1.0
                return (i * 200 + 60) + progress * 200
            }
        }
        return (n - 1) * 200 + 60
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
                    // ✅ 2026-03-20 修复：Tab按钮尺寸配合1.5倍字体
                    width: 170
                    height: 44
                    radius: 6
                    color: root.currentTab === index ? modelData.color : "#1e3a5f"
                    opacity: root.currentTab === index ? 1.0 : 0.6
                    border.color: modelData.color
                    border.width: root.currentTab === index ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.text
                        font.pixelSize: 21
                        font.bold: root.currentTab === index
                        color: root.currentTab === index ? "#1a2332" : modelData.color
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.stopSimulation()  // 切换Tab时停止模拟
                            root.currentTab = index
                        }
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

                // 标题 + 模拟播放控制
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.currentTab === 0 ? "启动流程时间轴" : "停止流程时间轴"
                        font.pixelSize: 24
                        font.bold: true
                        color: root.themeColor
                    }

                    // ✅ 2026-03-21 [Phase 7.48.64]: 模拟播放按钮
                    Rectangle {
                        width: 120; height: 34; radius: 17
                        color: root.isSimulating ? "#c0392b" : "#1a4a72"
                        border.color: root.isSimulating ? "#ff4757" : "#00aaff"
                        border.width: 2
                        visible: root.currentSeq.length > 0

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: root.isSimulating ? "⏹" : "▶"
                                font.pixelSize: 16; color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.isSimulating ? "停止" : "模拟"
                                font.pixelSize: 18; color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.isSimulating ? root.stopSimulation() : root.startSimulation()
                        }
                    }

                    // 时间显示
                    Text {
                        visible: root.isSimulating
                        text: "⏱ " + root.simTime.toFixed(1) + "s / " + root.simTotalTime.toFixed(1) + "s"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ffdd00"
                    }

                    Item { Layout.fillWidth: true }
                }

                // ========== 水平时间轴 ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
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
                                        width: 120
                                        height: 140
                                        radius: 8
                                        // ✅ 2026-03-20 修复：nodeMouseArea移到最前声明，z值最低，不会遮挡按钮
                                        // ✅ 2026-03-21 [Phase 7.48.64]: 模拟激活状态颜色
                                        color: {
                                            if (root.isSimulating && index < root.simActivatedCount) {
                                                return index === root.simActivatedCount - 1
                                                    ? "#004d22"  // 刚激活（当前设备）
                                                    : "#002211"  // 已激活（前序设备）
                                            }
                                            return nodeMouseArea.containsMouse ? "#2a5080" : "#1e3a5f"
                                        }
                                        border.color: root.isSimulating && index < root.simActivatedCount
                                            ? "#00ff88" : root.themeColor
                                        border.width: root.isSimulating && index === root.simActivatedCount - 1 ? 3 : 2

                                        // 背景点击区域 - 声明在最前，z值最低，按钮可以正常接收事件
                                        MouseArea {
                                            id: nodeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            z: 0
                                            // 点击弹出编辑
                                            onClicked: {
                                                editPopup.editIndex = index
                                                editPopup.editDelay = root.currentDelays[index] || 1.0
                                                editPopup.open()
                                            }
                                        }

                                        // 顶部指示条
                                        Rectangle {
                                            width: parent.width - 4
                                            height: 4
                                            anchors.top: parent.top
                                            anchors.topMargin: 2
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            radius: 2
                                            color: root.themeColor
                                            z: 1
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            z: 2

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "(" + (index + 1) + ")"
                                                font.pixelSize: 16
                                                color: "#aaaaaa"
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: root.currentSeq[index] || ""
                                                font.pixelSize: 21
                                                font.bold: true
                                                color: "white"
                                            }
                                            // ✅ 2026-03-20 修复：◀×▶按钮z值高于nodeMouseArea，可正常点击
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 8
                                                Rectangle {
                                                    width: 32; height: 28; radius: 3
                                                    color: leftBtn.containsMouse ? "#3498db" : "#2c3e50"
                                                    visible: index > 0
                                                    Text { anchors.centerIn: parent; text: "◀"; color: "white"; font.pixelSize: 18 }
                                                    MouseArea { id: leftBtn; anchors.fill: parent; hoverEnabled: true; onClicked: root.swapDevices(index, index - 1) }
                                                }
                                                Rectangle {
                                                    width: 32; height: 28; radius: 3
                                                    color: delBtn.containsMouse ? "#e74c3c" : "#2c3e50"
                                                    Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 21; font.bold: true }
                                                    MouseArea { id: delBtn; anchors.fill: parent; hoverEnabled: true; onClicked: root.removeDevice(index) }
                                                }
                                                Rectangle {
                                                    width: 32; height: 28; radius: 3
                                                    color: rightBtn.containsMouse ? "#3498db" : "#2c3e50"
                                                    visible: index < root.currentSeq.length - 1
                                                    Text { anchors.centerIn: parent; text: "▶"; color: "white"; font.pixelSize: 18 }
                                                    MouseArea { id: rightBtn; anchors.fill: parent; hoverEnabled: true; onClicked: root.swapDevices(index, index + 1) }
                                                }
                                            }
                                        }
                                    }

                                    // 连接箭头 + 延时标签（最后一个不显示）
                                    Item {
                                        id: arrowItem
                                        width: 80
                                        height: 140
                                        visible: index < root.currentSeq.length - 1
                                        clip: true

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
                                            font.pixelSize: 15
                                            color: {
                                                var d = root.currentDelays[index] || 1.0
                                                return d <= 2.0 ? "#00ff88" : (d <= 5.0 ? "#f39c12" : "#ff4757")
                                            }
                                        }
                                        // ✅ 2026-03-21 [Phase 7.48.64]: 时间流子弹（沿箭头移动的亮块）
                                        Rectangle {
                                            id: timeBullet
                                            width: 14; height: 6; radius: 3
                                            color: "#ffffff"
                                            opacity: {
                                                // 仅在该箭头的"流动时间段"内显示（设备i已激活但i+1未激活）
                                                return root.isSimulating && root.simActivatedCount === index + 1 ? 0.9 : 0.0
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: {
                                                var lineWidth = arrowItem.width - 10  // 70px
                                                var t0 = root.simActivationTimes.length > index ? root.simActivationTimes[index] : 0
                                                var delay = root.currentDelays[index] || 1.0
                                                var progress = delay > 0
                                                    ? Math.min(1.0, Math.max(0.0, (root.simTime - t0) / delay))
                                                    : 1.0
                                                return 5 + progress * (lineWidth - timeBullet.width)
                                            }
                                        }
                                        // 延时标签
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.verticalCenter
                                            anchors.bottomMargin: 4
                                            width: 52
                                            height: 26
                                            radius: 13
                                            color: "#1a2332"
                                            border.color: "#5dade2"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: (root.currentDelays[index] || 1.0).toFixed(1) + "s"
                                                font.pixelSize: 16
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

                        // ✅ 2026-03-21 [Phase 7.48.64]: 时间游标（跟随模拟时间移动的垂直指示线）
                        Item {
                            id: timeCursor
                            y: 0
                            width: 2
                            // 游标高度 = Flickable可见高度（减去margin）
                            height: timelineFlickable.height
                            // x = 该时刻设备节点的中心位置（节点i中心 = i*200+60，行offset=0）
                            // 注意：必须在绑定中直接引用 root.simTime，才能触发重新求值
                            x: { var _t = root.simTime; var _n = root.simActivatedCount; return root.getCursorX() - 1 }
                            z: 20
                            visible: root.isSimulating

                            // 主竖线
                            Rectangle {
                                anchors.fill: parent
                                color: "#ffdd00"
                                opacity: 0.85
                            }

                            // 顶部菱形指示器
                            Rectangle {
                                width: 12; height: 12
                                rotation: 45
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                color: "#ffdd00"
                            }

                            // 底部菱形
                            Rectangle {
                                width: 8; height: 8
                                rotation: 45
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                color: "#ffdd00"
                            }
                        }
                    }

                    // 自动跟随游标滚动
                    Connections {
                        target: root
                        function onSimTimeChanged() {
                            if (root.isSimulating) {
                                var cx = root.getCursorX()
                                var visibleLeft = timelineFlickable.contentX
                                var visibleRight = visibleLeft + timelineFlickable.width
                                // 若游标超出右侧可见区，自动滚动
                                if (cx > visibleRight - 40) {
                                    timelineFlickable.contentX = Math.min(
                                        cx - timelineFlickable.width / 2,
                                        timelineFlickable.contentWidth - timelineFlickable.width
                                    )
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "暂无设备，请从下方设备池添加"
                        font.pixelSize: 21
                        color: "#666666"
                        visible: root.currentSeq.length === 0
                    }
                }

                // ========== 提示栏 ==========
                Text {
                    text: "点击节点编辑延时 │ ◀▶ 调整顺序 │ × 删除设备 │ 点击连线延时标签修改"
                    font.pixelSize: 16
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
                            font.pixelSize: 18
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
                                            font.pixelSize: 18
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

                                                    width: 96
                                                    height: 36
                                                    radius: 4
                                                    color: inSeq ? "#1a1a2e" : (poolItemMa.containsMouse ? groupColor : "#1e3a5f")
                                                    opacity: inSeq ? 0.4 : 1.0
                                                    border.color: groupColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.devName
                                                        font.pixelSize: 16
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
                        font.pixelSize: 20
                        color: "#aaaaaa"
                    }
                    Text {
                        text: "总耗时: " + root.getTotalTime() + "s"
                        font.pixelSize: 20
                        color: "#aaaaaa"
                    }

                    // ✅ 2026-03-20 修复：保存成功提示
                    Text {
                        text: "已保存"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#00ff88"
                        visible: root.saveSuccess
                    }

                    Item { Layout.fillWidth: true }

                    // 一键反转按钮（仅启动Tab显示）
                    Rectangle {
                        width: 170
                        height: 38
                        radius: 6
                        color: reverseBtn.containsMouse ? "#f39c12" : "#2c3e50"
                        border.color: "#f39c12"
                        visible: root.currentTab === 0

                        Text {
                            anchors.centerIn: parent
                            text: "一键反转→停止"
                            font.pixelSize: 20
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
                        width: 100
                        height: 38
                        radius: 6
                        color: saveBtn.containsMouse ? "#27ae60" : "#1e8449"
                        border.color: "#00ff88"

                        Text {
                            anchors.centerIn: parent
                            text: "保存"
                            font.pixelSize: 21
                            font.bold: true
                            color: "white"
                        }
                        MouseArea {
                            id: saveBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            // ✅ 2026-03-20 修复：点击保存弹出确认对话框
                            onClicked: saveConfirmPopup.open()
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
                    font.pixelSize: 24
                    font.bold: true
                    color: "#00d4ff"
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Text { text: "默认延时（秒）:"; font.pixelSize: 21; color: "#cccccc" }
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
                            font.pixelSize: 21
                            color: "#5dade2"
                        }
                    }

                    Text { text: "预警时间（秒）:"; font.pixelSize: 21; color: "#cccccc" }
                    Text {
                        text: root.systemConfig ? root.systemConfig.warningTimeSeconds + "s" : "N/A"
                        font.pixelSize: 21
                        color: "#5dade2"
                    }

                    Text { text: "预警模式:"; font.pixelSize: 21; color: "#cccccc" }
                    Text {
                        text: root.systemConfig ? (root.systemConfig.warningMode === 0 ? "按时间" : "按次数") : "N/A"
                        font.pixelSize: 21
                        color: "#5dade2"
                    }
                }

                Item { Layout.fillHeight: true }

                // 保存 + 恢复默认
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // ✅ 2026-03-20 修复：保存成功提示
                    Text {
                        text: "已保存"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#00ff88"
                        visible: root.saveSuccess
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 120
                        height: 38
                        radius: 6
                        color: resetBtn.containsMouse ? "#c0392b" : "#2c3e50"
                        border.color: "#ff4757"

                        Text { anchors.centerIn: parent; text: "恢复默认"; font.pixelSize: 20; color: "white" }
                        MouseArea {
                            id: resetBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // ✅ 2026-03-20 修复：恢复默认使用设备池中的实际名称
                                // root.startupSeq = ["张紧", "抱闸", "1号电机", "2号电机"]
                                // root.stopSeq = ["2号电机", "1号电机", "抱闸", "张紧"]
                                root.startupSeq = ["张紧控制", "1号制动器", "1号电机", "2号电机"]
                                root.stopSeq = ["2号电机", "1号电机", "1号制动器", "张紧控制"]
                                root.startupDelays = [1.0, 1.0, 1.0, 1.0]
                                root.stopDelays = [1.0, 1.0, 1.0, 1.0]
                                root.defaultDelay = 1.0
                            }
                        }
                    }

                    Rectangle {
                        width: 100
                        height: 38
                        radius: 6
                        color: saveBtn2.containsMouse ? "#27ae60" : "#1e8449"
                        border.color: "#00ff88"

                        Text { anchors.centerIn: parent; text: "保存"; font.pixelSize: 21; font.bold: true; color: "white" }
                        MouseArea {
                            id: saveBtn2
                            anchors.fill: parent
                            hoverEnabled: true
                            // ✅ 2026-03-20 修复：点击保存弹出确认对话框
                            onClicked: saveConfirmPopup.open()
                        }
                    }
                }
            }
        }
    }

    // ========== 保存确认弹窗 ==========
    Popup {
        id: saveConfirmPopup
        anchors.centerIn: parent
        width: 320
        height: 180
        modal: true

        background: Rectangle {
            color: "#1a2332"
            radius: 10
            border.color: "#00d4ff"
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Text {
                text: "确认保存当前配置？"
                font.pixelSize: 21
                font.bold: true
                color: "#00d4ff"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "启动: " + root.startupSeq.length + "个设备 │ 停止: " + root.stopSeq.length + "个设备"
                font.pixelSize: 16
                color: "#aaaaaa"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: 20
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    width: 100; height: 36; radius: 6
                    color: cancelSaveBtn.containsMouse ? "#555555" : "#2c3e50"
                    border.color: "#666666"
                    Text { anchors.centerIn: parent; text: "取消"; font.pixelSize: 18; color: "white" }
                    MouseArea {
                        id: cancelSaveBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: saveConfirmPopup.close()
                    }
                }

                Rectangle {
                    width: 100; height: 36; radius: 6
                    color: doSaveBtn.containsMouse ? "#27ae60" : "#1e8449"
                    border.color: "#00ff88"
                    Text { anchors.centerIn: parent; text: "确认保存"; font.pixelSize: 18; font.bold: true; color: "white" }
                    MouseArea {
                        id: doSaveBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.saveToConfig()
                            saveConfirmPopup.close()
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
        width: 320
        height: 220
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
                font.pixelSize: 21
                font.bold: true
                color: "#00d4ff"
            }

            RowLayout {
                spacing: 8
                Text { text: "延时:"; font.pixelSize: 20; color: "#cccccc" }
                Slider {
                    id: editDelaySlider
                    from: 0.5; to: 30.0; stepSize: 0.5
                    value: editPopup.editDelay
                    Layout.fillWidth: true
                }
                Text {
                    text: editDelaySlider.value.toFixed(1) + "s"
                    font.pixelSize: 20
                    color: "#5dade2"
                    Layout.preferredWidth: 50
                }
            }

            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignRight

                Rectangle {
                    width: 100; height: 36; radius: 6
                    color: delDevBtn.containsMouse ? "#e74c3c" : "#c0392b"
                    Text { anchors.centerIn: parent; text: "删除设备"; font.pixelSize: 18; color: "white" }
                    MouseArea {
                        id: delDevBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { root.removeDevice(editPopup.editIndex); editPopup.close() }
                    }
                }

                Rectangle {
                    width: 80; height: 36; radius: 6
                    color: confirmBtn.containsMouse ? "#27ae60" : "#1e8449"
                    Text { anchors.centerIn: parent; text: "确定"; font.pixelSize: 18; font.bold: true; color: "white" }
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
