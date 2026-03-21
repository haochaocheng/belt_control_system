import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// ✅ 2026-03-20 [Phase 7.48.57]: 逻辑控制面板 - 水平时间轴流程图
// ✅ 2026-03-20 修复4项问题：默认序列/字体1.5倍/调整顺序/保存确认
Rectangle {
    id: root
    color: "transparent"

    // ✅ 2026-03-21 [Phase 7.48.68]: 改为per-device配置，不再使用systemConfig
    // 旧代码：property var systemConfig: null
    property int deviceId: 1              // 从DeviceSettingsDialog传入的设备ID

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

    // ✅ 2026-03-21 [Phase 7.48.66]: 实时时间轴跟踪属性（替代原模拟播放）
    // 原因：用户要求时间轴根据实际设备启动信号实时显示，不是模拟播放
    property bool isRealtimeActive: false       // 是否正在实时跟踪
    property int  rtPhase: 0                    // 0=空闲, 1=预警中, 2=设备序列运行中
    property int  rtActivatedCount: 0           // 已激活设备数
    property double rtWarningStart: 0           // 预警开始时间戳(ms)
    property double rtSequenceStart: 0          // 设备序列开始时间戳(ms)
    property var  rtDeviceStartTimes: []        // 各设备激活时间戳列表(ms)
    property double rtElapsed: 0                // 当前阶段已经过的时间(秒)，由刷新定时器更新

    // ✅ 2026-03-21 [Phase 7.48.68]: 故障状态跟踪
    // 原因：设备故障后时间轴仍显示运行中，需要监听runtimeTracker故障信号
    property string rtFaultDevice: ""            // 故障设备名（空=无故障）

    // 设备池分组定义
    readonly property var deviceGroups: [
        { name: "电机", color: "#5dade2", devices: ["1号电机", "2号电机", "3号电机", "4号电机", "5号电机", "6号电机", "7号电机", "8号电机"] },
        { name: "制动器", color: "#f39c12", devices: ["1号制动器", "2号制动器", "3号制动器", "4号制动器", "5号制动器", "6号制动器", "7号制动器", "8号制动��"] },
        { name: "张紧", color: "#00ff88", devices: ["张紧控制"] },
        { name: "洒水", color: "#00d4ff", devices: ["洒水1", "洒水2", "洒水3", "洒水4", "洒水5", "洒水6", "洒水7", "洒水8"] }
    ]

    Component.onCompleted: loadFromConfig()

    // ✅ 2026-03-21 [Phase 7.48.68]: deviceId由Loader.onLoaded设置，变化时重新加载
    // 旧代码：onSystemConfigChanged: { if (systemConfig) loadFromConfig() }
    onDeviceIdChanged: {
        if (deviceId > 0) loadFromConfig()
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
        // ✅ 2026-03-21 [Phase 7.48.68]: 从 device_logic_configs 表读取per-device配置
        // 旧代码：从 systemConfig 读取全局配置
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) {
            console.warn("⚠️ LogicControlPanel: deviceConfigMgr 未初始化")
            return
        }
        var config = deviceConfigMgr.loadDeviceLogicConfig(root.deviceId)
        var startupStr = config["startup_sequence"] || "[]"
        var stopStr = config["stop_sequence"] || "[]"
        var loadedStartup = JSON.parse(startupStr)
        var loadedStop = JSON.parse(stopStr)
        // 迁移旧名称
        startupSeq = loadedStartup.length > 0 ? migrateOldNames(loadedStartup) : ["张紧控制", "1号制动器", "1号电机", "2号电机"]
        stopSeq = loadedStop.length > 0 ? migrateOldNames(loadedStop) : ["2号电机", "1号电机", "1号制动器", "张紧控制"]

        defaultDelay = config["default_delay"] || 1.0
        // ✅ 延时从各子设备配置表读取
        startupDelays = []
        for (var i = 0; i < startupSeq.length; i++) {
            startupDelays.push(readDeviceStartupDelay(startupSeq[i]))
        }
        stopDelays = []
        for (var j = 0; j < stopSeq.length; j++) {
            stopDelays.push(readDeviceStartupDelay(stopSeq[j]))
        }

        console.log("✅ 逻辑控制配置已加载 - 设备ID:", root.deviceId, "启动:", startupSeq.length, "停止:", stopSeq.length)
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 根据设备名读取其启动延时
    function readDeviceStartupDelay(deviceName) {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return defaultDelay
        // 电机：从 device_motor_config 读取 startup_delay
        var motorMatch = deviceName.match(/(\d+)号电机/)
        if (motorMatch) {
            var motorIdx = parseInt(motorMatch[1]) - 1
            var motorCfg = deviceConfigMgr.loadMotorConfig(root.deviceId, motorIdx, 0)
            if (motorCfg && motorCfg["startup_delay"] !== undefined) return Number(motorCfg["startup_delay"])
            return 8  // 电机默认8秒
        }
        // 制动器：从 device_brake_config 读取 release_startup_delay
        var brakeMatch = deviceName.match(/(\d+)号制动器/)
        if (brakeMatch) {
            var brakeIdx = parseInt(brakeMatch[1]) - 1
            var brakeCfg = deviceConfigMgr.loadBrakeConfig(root.deviceId, brakeIdx)
            if (brakeCfg && brakeCfg["release_startup_delay"] !== undefined) return Number(brakeCfg["release_startup_delay"])
            return 1.0  // 制动器默认1秒
        }
        // 张紧控制：从 device_tension_config 读取 startup_delay
        if (deviceName === "张紧控制" || deviceName === "张紧") {
            var tensionCfg = deviceConfigMgr.loadTensionConfig(root.deviceId, 0)
            if (tensionCfg && tensionCfg["startup_delay"] !== undefined) return Number(tensionCfg["startup_delay"])
            return 5  // 张紧默认5秒
        }
        return defaultDelay
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 写回设备启动延时
    function writeDeviceStartupDelay(deviceName, value) {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var motorMatch = deviceName.match(/(\d+)号电机/)
        if (motorMatch) {
            deviceConfigMgr.updateMotorStartupDelay(root.deviceId, parseInt(motorMatch[1]) - 1, value)
            return
        }
        var brakeMatch = deviceName.match(/(\d+)号制动器/)
        if (brakeMatch) {
            deviceConfigMgr.updateBrakeStartupDelay(root.deviceId, parseInt(brakeMatch[1]) - 1, value, "release")
            return
        }
        if (deviceName === "张紧控制" || deviceName === "张紧") {
            deviceConfigMgr.updateTensionStartupDelay(root.deviceId, 0, value)
            return
        }
    }

    function saveToConfig() {
        // ✅ 2026-03-21 [Phase 7.48.68]: 保存到 device_logic_configs 表
        // 旧代码：保存到 systemConfig
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var config = {
            "startup_sequence": JSON.stringify(startupSeq),
            "stop_sequence": JSON.stringify(stopSeq),
            "warning_time": 10.0,
            "default_delay": defaultDelay
        }
        deviceConfigMgr.saveDeviceLogicConfig(root.deviceId, config)
        console.log("✅ 逻辑控制配置已保存 - 设备ID:", root.deviceId)
        // 显示保存成功提示
        saveSuccess = true
        saveSuccessTimer.restart()
    }

    // ✅ 2026-03-20 保存成功提示自动隐藏定时器
    Timer {
        id: saveSuccessTimer
        interval: 2000
        onTriggered: root.saveSuccess = false
    }

    // ✅ 2026-03-21 [Phase 7.48.66]: 实时显示刷新定时器（仅用于更新UI动画，不驱动逻辑）
    Timer {
        id: rtRefreshTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (root.rtPhase === 1) {
                // 预警阶段：计算预警已过时间
                root.rtElapsed = (Date.now() - root.rtWarningStart) / 1000.0
            } else if (root.rtPhase === 2) {
                // 设备序列阶段：计算序列已过时间
                root.rtElapsed = (Date.now() - root.rtSequenceStart) / 1000.0
            }
        }
    }

    // ✅ 2026-03-21 [Phase 7.48.66]: 监听 CommonControl 实时信号
    Connections {
        target: typeof commonControl !== "undefined" ? commonControl : null

        function onWarningStarted() {
            console.log("📡 LogicControlPanel: 收到预警开始信号")
            root.rtWarningStart = Date.now()
            root.rtSequenceStart = 0
            root.rtDeviceStartTimes = []
            root.rtActivatedCount = 0
            root.rtPhase = 1
            root.rtElapsed = 0
            root.isRealtimeActive = true
            rtRefreshTimer.start()
        }

        function onWarningPlaybackFinished() {
            console.log("📡 LogicControlPanel: 收到预警结束信号")
            root.rtPhase = 2
            root.rtSequenceStart = Date.now()
            root.rtElapsed = 0
        }

        function onDeviceStatusChanged(deviceName, isRunning) {
            if (!root.isRealtimeActive || root.rtPhase < 2) return
            if (!isRunning) {
                // 设备停止时（停止序列或故障停止），结束实时跟踪
                // 仅在所有设备都停止时才结束
                return
            }
            // 检查设备是否在当前启动序列中
            var seq = root.startupSeq
            var idx = seq.indexOf(deviceName)
            // 名称映射：启动序列可能用旧名称
            if (idx < 0) {
                // 尝试反向映射："张紧" → "张紧控制"
                var reverseMap = { "张紧": "张紧控制", "抱闸": "1号制动器" }
                var mappedName = reverseMap[deviceName]
                if (mappedName) idx = seq.indexOf(mappedName)
                // 也尝试正向映射："张紧控制" → "张紧"
                var forwardMap = { "张紧控制": "张紧", "1号制动器": "抱闸" }
                var fwName = forwardMap[deviceName]
                if (idx < 0 && fwName) idx = seq.indexOf(fwName)
            }
            if (idx < 0) return

            var times = root.rtDeviceStartTimes.slice()
            while (times.length <= idx) times.push(0)
            times[idx] = Date.now()
            root.rtDeviceStartTimes = times
            root.rtActivatedCount = idx + 1
            console.log("📡 LogicControlPanel: 设备激活 -", deviceName, "序号:", idx + 1)

            // 最后一个设备激活后，3秒后停止实时跟踪
            if (idx === seq.length - 1) {
                rtStopTimer.restart()
            }
        }
    }

    // 延迟停止实时跟踪（最后设备激活后3秒）
    Timer {
        id: rtStopTimer
        interval: 3000
        onTriggered: {
            rtRefreshTimer.stop()
            // 保持最终状态显示，不重置（用户切换Tab时重置）
        }
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: 监听 runtimeTracker 故障信号
    // 原因：设备故障后时间轴仍显示"运行中"，需要在故障时停止跟踪并显示红色
    Connections {
        target: typeof runtimeTracker !== "undefined" ? runtimeTracker : null

        function onIsFaultChanged() {
            if (runtimeTracker.isFault && root.isRealtimeActive) {
                console.log("❌ LogicControlPanel: 检测到设备故障，停止时间轴跟踪")
                rtRefreshTimer.stop()
                rtStopTimer.stop()
                root.rtPhase = 3  // 3=故障状态
                // 获取故障设备名
                var faultList = runtimeTracker.faultDevices
                if (faultList && faultList.length > 0) {
                    root.rtFaultDevice = faultList[0]
                    console.log("❌ LogicControlPanel: 故障设备:", root.rtFaultDevice)
                }
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
        // ✅ 2026-03-21 [Phase 7.48.68]: 同步写回设备配置表
        var seq = currentTab === 0 ? startupSeq : stopSeq
        if (index < seq.length) writeDeviceStartupDelay(seq[index], value)
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

    // ✅ 2026-03-21 [Phase 7.48.66]: 重置实时跟踪状态
    function resetRealtimeTracking() {
        rtRefreshTimer.stop()
        rtStopTimer.stop()
        root.isRealtimeActive = false
        root.rtPhase = 0
        root.rtActivatedCount = 0
        root.rtWarningStart = 0
        root.rtSequenceStart = 0
        root.rtDeviceStartTimes = []
        root.rtElapsed = 0
    }

    // 获取预警时间（秒）
    function getWarningTime() {
        return root.systemConfig ? (root.systemConfig.warningTimeSeconds || 10) : 10
    }

    // 计算设备i的箭头进度（0.0~1.0），用于实时箭头动画
    function getArrowProgress(deviceIndex) {
        if (!root.isRealtimeActive || root.rtPhase < 2) return 0.0
        if (deviceIndex >= root.rtActivatedCount) return 0.0
        // 如果下一个设备已激活，箭头进度=1.0
        if (deviceIndex + 1 < root.rtActivatedCount) return 1.0
        // 当前设备已激活，下一个未激活：计算进度
        var startT = root.rtDeviceStartTimes.length > deviceIndex ? root.rtDeviceStartTimes[deviceIndex] : 0
        if (startT <= 0) return 0.0
        var elapsed = (Date.now() - startT) / 1000.0
        var delay = root.currentDelays[deviceIndex] || 1.0
        return Math.min(1.0, elapsed / delay)
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
                            root.resetRealtimeTracking()  // 切换Tab时重置实时跟踪
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

                    // ✅ 2026-03-21 [Phase 7.48.66]: 实时状态指示灯（替代原模拟按钮）
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        color: root.isRealtimeActive ? (root.rtPhase === 1 ? "#f39c12" : "#00ff88") : "#555555"
                        visible: root.currentTab === 0
                        // 预警中闪烁
                        SequentialAnimation on opacity {
                            running: root.rtPhase === 1
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                    Text {
                        visible: root.isRealtimeActive && root.currentTab === 0
                        // ✅ 2026-03-21 [Phase 7.48.68]: 故障状态显示红色错误文字
                        text: root.rtPhase === 3
                            ? "❌ 运行失败 - " + root.rtFaultDevice
                            : (root.rtPhase === 1
                                ? "预警中 " + root.rtElapsed.toFixed(1) + "s / " + root.getWarningTime() + "s"
                                : "运行中 " + root.rtElapsed.toFixed(1) + "s  设备 " + root.rtActivatedCount + "/" + root.startupSeq.length)
                        font.pixelSize: 20
                        font.bold: true
                        color: root.rtPhase === 3 ? "#ff4757" : (root.rtPhase === 1 ? "#f39c12" : "#00ff88")
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

                            // ✅ 2026-03-21 [Phase 7.48.66]: 前缀节点 - "运行键开始"
                            // 仅在启动流程Tab显示
                            Rectangle {
                                width: 100; height: 140; radius: 8
                                visible: root.currentTab === 0
                                // ✅ 2026-03-21 [Phase 7.48.68]: 调亮激活绿色，从#004d22→#006633
                                color: root.isRealtimeActive && root.rtPhase >= 1 ? "#006633" : "#1e3a5f"
                                border.color: root.isRealtimeActive && root.rtPhase >= 1 ? "#00ff88" : "#f39c12"
                                border.width: root.isRealtimeActive && root.rtPhase === 1 ? 3 : 2

                                Rectangle {
                                    width: parent.width - 4; height: 4; radius: 2
                                    anchors.top: parent.top; anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "#f39c12"; z: 1
                                }
                                Column {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "▶"; font.pixelSize: 24; color: "#f39c12" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "运行键"; font.pixelSize: 20; font.bold: true; color: "white" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "开始"; font.pixelSize: 20; font.bold: true; color: "white" }
                                }
                            }

                            // ✅ 2026-03-21 [Phase 7.48.67]: 前缀进度条1：运行键→启车预警（预警进度条）
                            // 原箭头改为进度条样式
                            Item {
                                width: 90; height: 140
                                visible: root.currentTab === 0

                                // 进度条轨道（背景）
                                Rectangle {
                                    id: warnTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    width: parent.width - 14; height: 8; x: 4
                                    radius: 4
                                    color: "#1a2332"
                                    border.color: "#2c3e50"; border.width: 1

                                    // 进度条填充（实时预警进度）
                                    Rectangle {
                                        anchors.left: parent.left; anchors.leftMargin: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - 2; radius: 3
                                        width: {
                                            var _e = root.rtElapsed
                                            if (!root.isRealtimeActive || root.rtPhase < 1) return 0
                                            if (root.rtPhase >= 2) return parent.width - 2
                                            var warnTime = root.getWarningTime()
                                            var progress = warnTime > 0 ? Math.min(1.0, root.rtElapsed / warnTime) : 1.0
                                            return progress * (parent.width - 2)
                                        }
                                        color: root.rtPhase >= 2 ? "#f39c12" : "#f39c12"
                                        opacity: root.isRealtimeActive && root.rtPhase >= 1 ? 0.9 : 0.0

                                        Behavior on width { NumberAnimation { duration: 100 } }
                                    }

                                    // 进度条发光效果（实时激活时）
                                    Rectangle {
                                        anchors.fill: parent; radius: parent.radius
                                        color: "transparent"
                                        border.color: "#f39c12"
                                        border.width: root.isRealtimeActive && root.rtPhase === 1 ? 1 : 0
                                        opacity: 0.6
                                    }
                                }

                                // 右端方向指示三角
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    text: "▸"; font.pixelSize: 14; color: "#f39c12"
                                }

                                // 延时标签（悬浮在进度条上方）
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -14
                                    width: 56; height: 24; radius: 12
                                    color: "#0d1520"
                                    border.color: "#f39c12"; border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.getWarningTime() + "s"
                                        font.pixelSize: 14; font.bold: true; color: "#f39c12"
                                    }
                                }
                            }

                            // 前缀节点 - "启车预警"
                            Rectangle {
                                width: 100; height: 140; radius: 8
                                visible: root.currentTab === 0
                                // ✅ 2026-03-21 [Phase 7.48.68]: 调亮激活绿色
                                color: root.isRealtimeActive && root.rtPhase >= 2 ? "#006633" : "#1e3a5f"
                                border.color: root.isRealtimeActive && root.rtPhase >= 2 ? "#00ff88" : "#f39c12"
                                border.width: root.isRealtimeActive && root.rtPhase === 2 && root.rtActivatedCount === 0 ? 3 : 2

                                Rectangle {
                                    width: parent.width - 4; height: 4; radius: 2
                                    anchors.top: parent.top; anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "#f39c12"; z: 1
                                }
                                Column {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⚠"; font.pixelSize: 24; color: "#f39c12" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "启车预警"; font.pixelSize: 20; font.bold: true; color: "white" }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.getWarningTime() + "s"
                                        font.pixelSize: 18; color: "#f39c12"
                                    }
                                }
                            }

                            // ✅ 2026-03-21 [Phase 7.48.67]: 前缀进度条2：启车预警→第一个设备
                            Item {
                                width: 90; height: 140
                                visible: root.currentTab === 0 && root.currentSeq.length > 0

                                // 进度条轨道
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    width: parent.width - 14; height: 8; x: 4
                                    radius: 4
                                    color: "#1a2332"
                                    border.color: "#2c3e50"; border.width: 1

                                    // 填充（预警完成后立即填满）
                                    Rectangle {
                                        anchors.left: parent.left; anchors.leftMargin: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - 2; radius: 3
                                        width: root.isRealtimeActive && root.rtPhase >= 2 ? parent.width - 2 : 0
                                        color: root.themeColor
                                        opacity: 0.9
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                    }
                                }

                                // 右端方向指示三角
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    text: "▸"; font.pixelSize: 14; color: root.themeColor
                                }
                            }

                            // ========== 设备节点 Repeater ==========

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
                                        // ✅ 2026-03-21 [Phase 7.48.66]: 实时激活状态颜色（替代原模拟状态）
                                        // ✅ 2026-03-21 [Phase 7.48.68]: 调亮绿色填充 + 故障红色显示
                                        color: {
                                            // 故障状态：故障设备显示红色
                                            if (root.rtPhase === 3 && root.rtFaultDevice !== "") {
                                                var deviceName = root.currentSeq[index] || ""
                                                if (deviceName === root.rtFaultDevice) return "#4a0000"  // 故障设备红色背景
                                            }
                                            if (root.isRealtimeActive && root.currentTab === 0 && index < root.rtActivatedCount) {
                                                return index === root.rtActivatedCount - 1
                                                    ? "#006633"  // 刚激活（当前设备）- 从#004d22调亮
                                                    : "#004422"  // 已激活（前序设备）- 从#002211调亮
                                            }
                                            return nodeMouseArea.containsMouse ? "#2a5080" : "#1e3a5f"
                                        }
                                        border.color: {
                                            // ✅ 2026-03-21 [Phase 7.48.68]: 故障设备红色边框
                                            if (root.rtPhase === 3 && root.rtFaultDevice !== "") {
                                                var dn = root.currentSeq[index] || ""
                                                if (dn === root.rtFaultDevice) return "#ff4757"
                                            }
                                            return root.isRealtimeActive && root.currentTab === 0 && index < root.rtActivatedCount
                                                ? "#00ff88" : root.themeColor
                                        }
                                        border.width: {
                                            if (root.rtPhase === 3 && root.rtFaultDevice === (root.currentSeq[index] || "")) return 3
                                            return root.isRealtimeActive && root.currentTab === 0 && index === root.rtActivatedCount - 1 ? 3 : 2
                                        }

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

                                    // ✅ 2026-03-21 [Phase 7.48.67]: 连接进度条 + 延时标签（最后一个不显示）
                                    // 原箭头改为进度条样式，实时进度可视化更直观
                                    Item {
                                        id: arrowItem
                                        width: 90
                                        height: 140
                                        visible: index < root.currentSeq.length - 1

                                        // 延时颜色计算函数
                                        property color delayColor: {
                                            var d = root.currentDelays[index] || 1.0
                                            return d <= 2.0 ? "#00ff88" : (d <= 5.0 ? "#f39c12" : "#ff4757")
                                        }

                                        // 进度条轨道（背景）
                                        Rectangle {
                                            id: progressTrack
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.verticalCenterOffset: 6
                                            width: parent.width - 14; height: 8; x: 4
                                            radius: 4
                                            color: "#1a2332"
                                            border.color: "#2c3e50"; border.width: 1

                                            // 进度条填充（实时设备激活进度）
                                            Rectangle {
                                                id: progressFill
                                                anchors.left: parent.left; anchors.leftMargin: 1
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: parent.height - 2; radius: 3
                                                width: {
                                                    var _e = root.rtElapsed  // 强制绑定刷新
                                                    if (!root.isRealtimeActive || root.currentTab !== 0) return 0
                                                    // 设备已通过此箭头（下一设备已激活）
                                                    if (index + 1 < root.rtActivatedCount) return parent.width - 2
                                                    // 当前设备已激活，等待下一设备
                                                    if (index < root.rtActivatedCount) {
                                                        var progress = root.getArrowProgress(index)
                                                        return progress * (parent.width - 2)
                                                    }
                                                    return 0
                                                }
                                                color: arrowItem.delayColor
                                                opacity: 0.9

                                                Behavior on width { NumberAnimation { duration: 100 } }
                                            }

                                            // 进度条发光边框（进行中时）
                                            Rectangle {
                                                anchors.fill: parent; radius: parent.radius
                                                color: "transparent"
                                                border.color: arrowItem.delayColor
                                                border.width: root.isRealtimeActive && root.currentTab === 0
                                                    && root.rtActivatedCount === index + 1
                                                    && root.rtActivatedCount < root.startupSeq.length ? 1 : 0
                                                opacity: 0.6
                                            }
                                        }

                                        // 右端方向指示三角
                                        Text {
                                            anchors.right: parent.right; anchors.rightMargin: 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.verticalCenterOffset: 6
                                            text: "▸"; font.pixelSize: 14
                                            color: arrowItem.delayColor
                                        }

                                        // 延时标签（悬浮在进度条上方）
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.verticalCenterOffset: -14
                                            width: 56; height: 24; radius: 12
                                            color: "#0d1520"
                                            border.color: arrowItem.delayColor; border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: (root.currentDelays[index] || 1.0).toFixed(1) + "s"
                                                font.pixelSize: 14; font.bold: true
                                                color: arrowItem.delayColor
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

                        // ✅ 2026-03-21 [Phase 7.48.66]: 移除旧的模拟时间游标（已改为实时跟踪方式）
                        // 原模拟游标（黄色竖线+菱形）不再需要，实时可视化通过设备卡片颜色和箭头子弹表示
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
