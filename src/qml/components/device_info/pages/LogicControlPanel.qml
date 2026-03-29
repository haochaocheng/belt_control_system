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
    // ✅ 2026-03-21 [Phase 7.48.70]: 新增 rtPhase=4 停止序列运行中
    property int  rtPhase: 0                    // 0=空闲, 1=预警中, 2=启动序列运行中, 3=故障, 4=停止序列运行中
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

    // ✅ 2026-03-29 [Phase 7.48.88.67]: 禁用设备列表（设备池中灰显+不可拖入）
    // 从数据库加载电机/制动器的运行状态（"禁用"的设备名列表）
    property var disabledDevices: []

    // ✅ 2026-03-29 [Phase 7.48.88.68]: 通道未配置设备列表（设备池中琥珀色警告+不可拖入）
    // 从数据库加载各设备的输出通道状态（未配置通道的设备名列表）
    property var unconfiguredDevices: []

    // ✅ 2026-03-29 [Phase 7.48.88.67]: 判断设备是否被禁用
    function isDeviceDisabled(deviceName) {
        return disabledDevices.indexOf(deviceName) >= 0
    }

    // ✅ 2026-03-29 [Phase 7.48.88.68]: 判断设备通道是否未配置
    function isDeviceUnconfigured(deviceName) {
        return unconfiguredDevices.indexOf(deviceName) >= 0
    }

    // ✅ 2026-03-29 [Phase 7.48.88.67]: 从数据库加载禁用设备列表
    // ✅ 2026-03-29 [Phase 7.48.88.68]: 同时加载通道未配置设备列表
    function loadDisabledDevices() {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var disabled = []
        var unconfigured = []
        // 检查8个电机：禁用状态 + 输出通道未配置(output_channel < 0)
        for (var i = 0; i < 8; i++) {
            var motorCfg = deviceConfigMgr.loadMotorConfig(root.deviceId, i, 0)
            var motorName = (i + 1) + "号电机"
            if (motorCfg && motorCfg["running_state"] === "禁用") {
                disabled.push(motorName)
            } else {
                // 非禁用时检查通道是否配置（output_channel为-1表示未配置）
                var motorCh = (motorCfg && motorCfg["output_channel"] !== undefined) ? motorCfg["output_channel"] : -1
                if (motorCh < 0) unconfigured.push(motorName)
            }
        }
        // 检查8个制动器：禁用状态 + 松闸输出通道未配置(release_output_channel <= 0)
        for (var j = 0; j < 8; j++) {
            var brakeCfg = deviceConfigMgr.loadBrakeConfig(root.deviceId, j)
            var brakeName = (j + 1) + "号制动器"
            if (brakeCfg && brakeCfg["running_state"] === "禁用") {
                disabled.push(brakeName)
            } else {
                var brakeCh = (brakeCfg && brakeCfg["release_output_channel"] !== undefined) ? brakeCfg["release_output_channel"] : 0
                if (brakeCh <= 0) unconfigured.push(brakeName)
            }
        }
        // 检查张紧控制：输出通道未配置(output_channel <= 0)
        var tensionCfg = deviceConfigMgr.loadTensionConfig(root.deviceId, 0)
        if (tensionCfg) {
            var tensionCh = (tensionCfg["output_channel"] !== undefined) ? tensionCfg["output_channel"] : 0
            if (tensionCh <= 0) unconfigured.push("张紧控制")
        }
        // 检查8个洒水：通道未配置(channel < 0)
        for (var k = 0; k < 8; k++) {
            var sprinklerCfg = deviceConfigMgr.loadSprinklerConfig(k + 1)
            var sprinklerName = "洒水" + (k + 1)
            if (sprinklerCfg) {
                var sprinklerCh = (sprinklerCfg["channel"] !== undefined) ? sprinklerCfg["channel"] : -1
                if (sprinklerCh < 0) unconfigured.push(sprinklerName)
            }
        }
        disabledDevices = disabled
        unconfiguredDevices = unconfigured
        console.log("✅ LogicControlPanel: 禁用设备:", JSON.stringify(disabled), "未配置通道:", JSON.stringify(unconfigured))
    }

    // ✅ 2026-03-24 [Phase 7.48.88.9]: 不在Component.onCompleted中加载配置
    // 旧代码：Component.onCompleted: { loadFromConfig(); syncStateFromTracker() }
    // 问题1：Component.onCompleted时deviceId仍是默认值1（Loader.onLoaded尚未设置）
    //        对2-8号皮带，会先误加载1号皮带的配置（虽然onLoaded后会修正，但存在隐患）
    // 问题2：如果打开的恰好是1号皮带，onDeviceIdChanged不触发（1→1无变化），
    //        但如果onLoaded不显式调用loadFromConfig，配置不会加载
    // 修复：配置加载由Loader.onLoaded显式触发（设置deviceId后立即调用loadFromConfig）
    //       syncStateFromTracker也移到onLoaded确保在正确配置加载后执行
    Component.onCompleted: {
        // 不在这里调用loadFromConfig()，由Loader.onLoaded确保正确deviceId后加载
        // syncStateFromTracker()也移至onLoaded，确保在正确的设备配置加载后执行
    }

    // ✅ 2026-03-21 [Phase 7.48.68]: deviceId由Loader.onLoaded设置，变化时重新加载
    // ✅ 2026-03-24 [Phase 7.48.88.9]: deviceId变化时重新加载
    // 旧代码：onSystemConfigChanged: { if (systemConfig) loadFromConfig() }
    // 注意：Loader.onLoaded已经显式调用loadFromConfig()，这里处理动态deviceId变化场景
    onDeviceIdChanged: {
        console.log("🔄 LogicControlPanel: deviceId changed to", deviceId)
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
        // ✅ 2026-03-24 [Phase 7.48.88.9]: 增强诊断日志
        // 旧代码：只打印设备ID和序列长度，无法定位保存后加载为空的问题
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) {
            console.warn("⚠️ LogicControlPanel: deviceConfigMgr 未初始化")
            return
        }
        console.log("📖 LogicControlPanel: loadFromConfig - deviceId:", root.deviceId)
        var config = deviceConfigMgr.loadDeviceLogicConfig(root.deviceId)
        var startupStr = config["startup_sequence"] || "[]"
        var stopStr = config["stop_sequence"] || "[]"
        // ✅ 2026-03-24 [Phase 7.48.88.9]: 打印原始DB值，用于诊断保存是否生效
        console.log("📖 LogicControlPanel: DB原始值 - startup:", startupStr, "stop:", stopStr)
        var loadedStartup = JSON.parse(startupStr)
        var loadedStop = JSON.parse(stopStr)
        // 迁移旧名称
        startupSeq = loadedStartup.length > 0 ? migrateOldNames(loadedStartup) : ["张紧控制", "1号制动器", "1号电机", "2号电机"]
        stopSeq = loadedStop.length > 0 ? migrateOldNames(loadedStop) : ["2号电机", "1号电机", "1号制动器", "张紧控制"]

        defaultDelay = config["default_delay"] || 1.0
        // ✅ 2026-03-21 [Phase 7.48.69]: 修复延时显示1.0s问题
        // 根因：startupDelays = [] 然后 push() 不会触发 QML property binding 重新求值
        //       Text 绑定在 startupDelays=[] 时求值，读到 undefined → 默认1.0
        // 修复：先构建临时数组，再一次性赋值给 property（触发 binding 更新）
        var tmpStartup = []
        for (var i = 0; i < startupSeq.length; i++) {
            tmpStartup.push(readDeviceStartupDelay(startupSeq[i]))
        }
        startupDelays = tmpStartup

        var tmpStop = []
        for (var j = 0; j < stopSeq.length; j++) {
            // ✅ 2026-03-21 [Phase 7.48.70]: 停止延时独立读取（制动器用brake_startup_delay）
            // 旧代码：tmpStop.push(readDeviceStartupDelay(stopSeq[j]))
            tmpStop.push(readDeviceStopDelay(stopSeq[j]))
        }
        stopDelays = tmpStop

        console.log("✅ 逻辑控制配置已加载 - 设备ID:", root.deviceId, "启动:", startupSeq.length, "停止:", stopSeq.length)

        // ✅ 2026-03-29 [Phase 7.48.88.67]: 加载禁用设备列表
        loadDisabledDevices()
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
        // ✅ 2026-03-22 [Phase 7.48.74]: 洒水：从 sprinkler_output_config 读取 startup_delay
        var sprinklerMatch = deviceName.match(/(\d+)号洒水/)
        if (sprinklerMatch) {
            var sprinklerIdx = parseInt(sprinklerMatch[1])
            var sprinklerCfg = deviceConfigMgr.loadSprinklerConfig(sprinklerIdx)
            if (sprinklerCfg && sprinklerCfg["startup_delay"] !== undefined) return Number(sprinklerCfg["startup_delay"])
            return 1  // 洒水默认1秒
        }
        return defaultDelay
    }

    // ✅ 2026-03-21 [Phase 7.48.70]: 根据设备名读取其停止延时（与启动延时独立）
    // 区别：制动器启动=松闸(release_startup_delay)，停止=抱闸(brake_startup_delay)
    // ✅ 2026-03-22 [Phase 7.48.74]: 改为读取独立stop_delay字段（不再复用startup_delay）
    function readDeviceStopDelay(deviceName) {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return defaultDelay
        // 电机：读取独立 stop_delay 字段
        var motorMatch = deviceName.match(/(\d+)号电机/)
        if (motorMatch) {
            var motorIdx = parseInt(motorMatch[1]) - 1
            var motorCfg = deviceConfigMgr.loadMotorConfig(root.deviceId, motorIdx, 0)
            // 旧：读 startup_delay（复用）
            // 新：读 stop_delay（独立字段）
            if (motorCfg && motorCfg["stop_delay"] !== undefined) return Number(motorCfg["stop_delay"])
            return 8
        }
        // 制动器：读取独立 release_stop_delay / brake_stop_delay
        var brakeMatch = deviceName.match(/(\d+)号制动器/)
        if (brakeMatch) {
            var brakeIdx = parseInt(brakeMatch[1]) - 1
            var brakeCfg = deviceConfigMgr.loadBrakeConfig(root.deviceId, brakeIdx)
            // 旧：读 brake_startup_delay（抱闸启动延时复用）
            // 新：读 release_stop_delay（松闸停止延时，对应停止时需要松闸再抱闸）
            if (brakeCfg && brakeCfg["release_stop_delay"] !== undefined) return Number(brakeCfg["release_stop_delay"])
            return 1.0
        }
        // 张紧控制：读取独立 stop_delay 字段
        if (deviceName === "张紧控制" || deviceName === "张紧") {
            var tensionCfg = deviceConfigMgr.loadTensionConfig(root.deviceId, 0)
            // 旧：读 startup_delay（复用）
            // 新：读 stop_delay（独立字段）
            if (tensionCfg && tensionCfg["stop_delay"] !== undefined) return Number(tensionCfg["stop_delay"])
            return 5
        }
        // ✅ 2026-03-22 [Phase 7.48.74]: 洒水：读取独立 stop_delay 字段
        var sprinklerMatch = deviceName.match(/(\d+)号洒水/)
        if (sprinklerMatch) {
            var sprinklerIdx = parseInt(sprinklerMatch[1])
            var sprinklerCfg = deviceConfigMgr.loadSprinklerConfig(sprinklerIdx)
            if (sprinklerCfg && sprinklerCfg["stop_delay"] !== undefined) return Number(sprinklerCfg["stop_delay"])
            return 1  // 洒水默认1秒
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
        // ✅ 2026-03-22 [Phase 7.48.74]: 洒水启动延时写回
        var sprinklerMatch = deviceName.match(/(\d+)号洒水/)
        if (sprinklerMatch) {
            deviceConfigMgr.updateSprinklerStartupDelay(parseInt(sprinklerMatch[1]), value)
            return
        }
    }

    // ✅ 2026-03-22 [Phase 7.48.74]: 写回设备停止延时（独立字段）
    function writeDeviceStopDelay(deviceName, value) {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var motorMatch = deviceName.match(/(\d+)号电机/)
        if (motorMatch) {
            deviceConfigMgr.updateMotorStopDelay(root.deviceId, parseInt(motorMatch[1]) - 1, value)
            return
        }
        var brakeMatch = deviceName.match(/(\d+)号制动器/)
        if (brakeMatch) {
            deviceConfigMgr.updateBrakeStopDelay(root.deviceId, parseInt(brakeMatch[1]) - 1, value, "release")
            return
        }
        if (deviceName === "张紧控制" || deviceName === "张紧") {
            deviceConfigMgr.updateTensionStopDelay(root.deviceId, 0, value)
            return
        }
        var sprinklerMatch2 = deviceName.match(/(\d+)号洒水/)
        if (sprinklerMatch2) {
            deviceConfigMgr.updateSprinklerStopDelay(parseInt(sprinklerMatch2[1]), value)
            return
        }
    }

    function saveToConfig() {
        // ✅ 2026-03-24 [Phase 7.48.88.9]: 增强保存验证
        // 旧代码：不检查返回值，保存失败时仍显示"已保存"
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var startupJson = JSON.stringify(startupSeq)
        var stopJson = JSON.stringify(stopSeq)
        console.log("💾 LogicControlPanel: saveToConfig - deviceId:", root.deviceId,
                     "startup:", startupJson, "stop:", stopJson)
        var config = {
            "startup_sequence": startupJson,
            "stop_sequence": stopJson,
            "warning_time": 10.0,
            "default_delay": defaultDelay
        }
        var success = deviceConfigMgr.saveDeviceLogicConfig(root.deviceId, config)
        if (success) {
            // 回读验证：确认数据确实写入数据库
            var verify = deviceConfigMgr.loadDeviceLogicConfig(root.deviceId)
            var verifyStartup = verify["startup_sequence"] || "[]"
            if (verifyStartup === startupJson) {
                console.log("✅ 逻辑控制配置已保存并验证 - 设备ID:", root.deviceId)
            } else {
                console.error("❌ 保存验证失败！写入:", startupJson, "回读:", verifyStartup)
            }
            saveSuccess = true
            saveSuccessTimer.restart()
        } else {
            console.error("❌ LogicControlPanel: saveToConfig失败 - deviceId:", root.deviceId)
            // 不显示"已保存"，保持saveSuccess=false
        }
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
            if (root.rtPhase === 1 || root.rtPhase === 5) {
                // 预警阶段（启动预警或停车预警）：计算预警已过时间
                root.rtElapsed = (Date.now() - root.rtWarningStart) / 1000.0
            } else if (root.rtPhase === 2 || root.rtPhase === 4) {
                // 设备序列阶段（启动or停止）：计算序列已过时间
                root.rtElapsed = (Date.now() - root.rtSequenceStart) / 1000.0
            }
        }
    }

    // ✅ 2026-03-21 [Phase 7.48.66]: 监听 CommonControl 实时信号
    Connections {
        target: typeof commonControl !== "undefined" ? commonControl : null

        function onWarningStarted() {
            console.log("📡 LogicControlPanel: 收到预警开始信号")
            // ✅ 2026-03-21 [Phase 7.48.73]: 取消之前序列的延迟重置定时器
            // 修复：第二次启动后进度条在1.6s停住，原因是之前停止序列的rtStopTimer
            // 在新启动预警期间触发了rtRefreshTimer.stop()
            rtStopTimer.stop()
            // ✅ 2026-03-21 [Phase 7.48.71]: 自动切换到启动顺序Tab
            root.currentTab = 0
            root.rtWarningStart = Date.now()
            root.rtSequenceStart = 0
            root.rtDeviceStartTimes = []
            root.rtActivatedCount = 0
            root.rtPhase = 1
            root.rtElapsed = 0
            root.rtFaultDevice = ""
            root.isRealtimeActive = true
            rtRefreshTimer.start()
        }

        function onWarningPlaybackFinished() {
            console.log("📡 LogicControlPanel: 收到预警结束信号")
            root.rtPhase = 2
            root.rtSequenceStart = Date.now()
            root.rtElapsed = 0
        }

        // ✅ 2026-03-21 [Phase 7.48.72]: 监听停车预警开始信号（S键按下时立即触发）
        // 修复问题3：按S立即切换到停止顺序Tab
        // 修复问题4：停止顺序进度条含停车预警进度
        function onStopWarningStarted() {
            console.log("📡 LogicControlPanel: 收到停车预警开始信号")
            // ✅ 2026-03-21 [Phase 7.48.73]: 取消之前序列的延迟重置定时器
            rtStopTimer.stop()
            root.currentTab = 1      // 立即切换到停止顺序Tab
            root.rtPhase = 5         // 5=停车预警中（新增状态）
            root.rtWarningStart = Date.now()
            root.rtSequenceStart = 0
            root.rtDeviceStartTimes = []
            root.rtActivatedCount = 0
            root.rtElapsed = 0
            root.rtFaultDevice = ""
            root.isRealtimeActive = true
            rtRefreshTimer.start()
        }

        // ✅ 2026-03-21 [Phase 7.48.70]: 监听停止序列开始信号
        // 停车音频播完后触发，从rtPhase=5切换到rtPhase=4
        function onStopSequenceStarted() {
            console.log("📡 LogicControlPanel: 收到停止序列开始信号")
            rtStopTimer.stop()  // 取消之前可能残留的延迟重置
            // 旧代码：root.currentTab = 1  // 已在onStopWarningStarted中切换
            root.rtPhase = 4     // 4=停止序列运行中
            root.rtActivatedCount = 0
            root.rtSequenceStart = Date.now()
            root.rtDeviceStartTimes = []
            root.rtElapsed = 0
            root.isRealtimeActive = true
            rtRefreshTimer.start()
        }

        // ✅ 2026-03-28 [Phase 7.48.88.52]: 增加beltNumber参数
        // ��签名：function onDeviceStatusChanged(deviceName, isRunning)
        function onDeviceStatusChanged(beltNumber, deviceName, isRunning) {
            if (!root.isRealtimeActive || root.rtPhase < 2) return
            if (!isRunning) {
                // ✅ 2026-03-21 [Phase 7.48.70]: 处理停止序列设备停用事件
                // 旧代码：直接 return，导致停车顺序无可视化
                if (root.rtPhase !== 4) return  // 4=停止序列运行中
                // 在停止序列中查找设备
                var stopIdx = root.stopSeq.indexOf(deviceName)
                if (stopIdx < 0) {
                    var reverseMap2 = { "张紧": "张紧控制", "抱闸": "1号制动器" }
                    var mappedName2 = reverseMap2[deviceName]
                    if (mappedName2) stopIdx = root.stopSeq.indexOf(mappedName2)
                    var forwardMap2 = { "张紧控制": "张紧", "1号制动器": "抱闸" }
                    var fwName2 = forwardMap2[deviceName]
                    if (stopIdx < 0 && fwName2) stopIdx = root.stopSeq.indexOf(fwName2)
                }
                if (stopIdx < 0) return

                var times2 = root.rtDeviceStartTimes.slice()
                while (times2.length <= stopIdx) times2.push(0)
                times2[stopIdx] = Date.now()
                root.rtDeviceStartTimes = times2
                root.rtActivatedCount = stopIdx + 1
                console.log("📡 LogicControlPanel: 设备停用 -", deviceName, "序号:", stopIdx + 1)

                // 最后一个设备停用后，3秒后结束跟踪并重置
                if (stopIdx === root.stopSeq.length - 1) {
                    rtStopTimer.restart()
                }
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

    // 延迟停止实时跟踪（最后设备激活/停用后3秒）
    Timer {
        id: rtStopTimer
        interval: 3000
        onTriggered: {
            rtRefreshTimer.stop()
            // ✅ 2026-03-21 [Phase 7.48.70]: 停止序列完成后重置所有颜色
            // 旧代码：保持最终状态显示，不重置（用户切换Tab时重置）
            // 修复问题3：停止后设备方框还是浅蓝/绿色填充
            if (root.rtPhase === 4) {
                // 停止序列完成，完全重置
                root.isRealtimeActive = false
                root.rtPhase = 0
                root.rtActivatedCount = 0
                root.rtDeviceStartTimes = []
                root.rtElapsed = 0
                root.rtFaultDevice = ""
                root.currentTab = 0  // 切回启动顺序Tab
                console.log("📡 LogicControlPanel: 停止序列完成，已重置所有状态")
            }
            // 启动序列完成后保持显示（用户切换Tab时重置）
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
        if (currentTab === 0) {
            startupSeq = seq.slice(); startupDelays = delays.slice()
            // ✅ 2026-03-25 [Phase 7.48.88.10]: 启动序列变更自动同步停止序列（反转）
            reverseToStop()
        }
        else { stopSeq = seq.slice(); stopDelays = delays.slice() }
    }

    function removeDevice(index) {
        var seq = currentTab === 0 ? startupSeq : stopSeq
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (index < 0 || index >= seq.length) return
        seq.splice(index, 1)
        delays.splice(index, 1)
        if (currentTab === 0) {
            startupSeq = seq.slice(); startupDelays = delays.slice()
            // ✅ 2026-03-25 [Phase 7.48.88.10]: 启动序列变更自动同步停止序列（反转）
            reverseToStop()
        }
        else { stopSeq = seq.slice(); stopDelays = delays.slice() }
    }

    function updateDelay(index, value) {
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (index < 0 || index >= delays.length) return
        delays[index] = value
        if (currentTab === 0) startupDelays = delays.slice()
        else stopDelays = delays.slice()
        // ✅ 2026-03-21 [Phase 7.48.68]: 同步写回设备配置表
        // ✅ 2026-03-22 [Phase 7.48.74]: 区分启动/停止延时写回（旧：统一用writeDeviceStartupDelay）
        var seq = currentTab === 0 ? startupSeq : stopSeq
        if (index < seq.length) {
            if (currentTab === 0) writeDeviceStartupDelay(seq[index], value)
            else writeDeviceStopDelay(seq[index], value)
        }
    }

    function swapDevices(fromIndex, toIndex) {
        var seq = currentTab === 0 ? startupSeq : stopSeq
        var delays = currentTab === 0 ? startupDelays : stopDelays
        if (fromIndex < 0 || fromIndex >= seq.length || toIndex < 0 || toIndex >= seq.length) return
        var tmpName = seq[fromIndex]; seq[fromIndex] = seq[toIndex]; seq[toIndex] = tmpName
        var tmpDelay = delays[fromIndex]; delays[fromIndex] = delays[toIndex]; delays[toIndex] = tmpDelay
        if (currentTab === 0) {
            startupSeq = seq.slice(); startupDelays = delays.slice()
            // ✅ 2026-03-25 [Phase 7.48.88.10]: 启动序列变更自动同步停止序列（反转）
            reverseToStop()
        }
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

    // ✅ 2026-03-24 [Phase 7.48.88.8]: 面板加载时同步runtimeTracker当前状态
    // 问题：用户在电机控制页按R键启动，启动过程中的信号(warningStarted/deviceStatusChanged)
    //       全部丢失（LogicControlPanel尚未加载），切换过来时时间轴显示默认状态
    // 修复：加载时查询runtimeTracker.currentStatus + commonControl.getSequenceState()还原当前阶段
    function syncStateFromTracker() {
        if (typeof runtimeTracker === "undefined" || !runtimeTracker) return

        var status = runtimeTracker.currentStatus
        var detail = runtimeTracker.detailedStatus

        // 从CommonControl获取精确的序列执行状态
        var seqState = null
        if (typeof commonControl !== "undefined" && commonControl) {
            seqState = commonControl.getSequenceState()
        }

        console.log("📡 LogicControlPanel: syncStateFromTracker - status:", status,
                     "detail:", detail, "seqState:", JSON.stringify(seqState))

        if (status === "故障") {
            // 故障状态：显示故障时间轴
            root.currentTab = 0
            root.isRealtimeActive = true
            root.rtPhase = 3  // 3=故障
            root.rtActivatedCount = root.startupSeq.length
            var faultList = runtimeTracker.faultDevices
            if (faultList && faultList.length > 0) {
                root.rtFaultDevice = faultList[0]
            }
            console.log("📡 LogicControlPanel: 同步故障状态，故障设备:", root.rtFaultDevice)

        } else if (status === "启动中") {
            root.currentTab = 0
            root.isRealtimeActive = true
            root.rtFaultDevice = ""

            if (detail === "起车预警" || (seqState && seqState.isWarning)) {
                // 预警阶段
                root.rtPhase = 1
                root.rtWarningStart = Date.now()
                root.rtActivatedCount = 0
                rtRefreshTimer.start()
                console.log("📡 LogicControlPanel: 同步启动中-预警阶段")
            } else {
                // 设备序列阶段：用getSequenceState()获取精确的已激活设备数
                root.rtPhase = 2
                root.rtSequenceStart = Date.now()
                var activatedCount = 0
                if (seqState && seqState.isRunning) {
                    // currentIndex是"下一个要激活的设备索引"，已激活数=currentIndex
                    activatedCount = seqState.currentIndex || 0
                }
                root.rtActivatedCount = activatedCount
                // 填充已激活设备的时间戳（全部设为当前时间，表示已完成）
                var times = []
                for (var i = 0; i < activatedCount; i++) {
                    times.push(Date.now())
                }
                root.rtDeviceStartTimes = times
                rtRefreshTimer.start()
                console.log("📡 LogicControlPanel: 同步启动中-设备序列, 已激活:", activatedCount)
            }

        } else if (status === "运行") {
            // 皮带已在运行：所有设备已激活，进度条全满
            root.currentTab = 0
            root.isRealtimeActive = true
            root.rtPhase = 2
            root.rtActivatedCount = root.startupSeq.length
            var allTimes = []
            for (var j = 0; j < root.startupSeq.length; j++) {
                allTimes.push(Date.now())
            }
            root.rtDeviceStartTimes = allTimes
            root.rtElapsed = 0
            root.rtFaultDevice = ""
            console.log("📡 LogicControlPanel: 同步运行状态，设备数:", root.startupSeq.length)
            rtStopTimer.restart()

        } else if (status === "停止中") {
            root.currentTab = 1
            root.isRealtimeActive = true
            root.rtFaultDevice = ""

            if (detail === "停车预警" || (seqState && seqState.isStopAudio)) {
                root.rtPhase = 5
                root.rtWarningStart = Date.now()
                root.rtActivatedCount = 0
                rtRefreshTimer.start()
                console.log("📡 LogicControlPanel: 同步停止中-停车预警阶段")
            } else {
                // 停止设备序列：用getSequenceState()获取精确进度
                root.rtPhase = 4
                root.rtSequenceStart = Date.now()
                var stopActivated = 0
                if (seqState && seqState.isRunning) {
                    stopActivated = seqState.currentIndex || 0
                }
                root.rtActivatedCount = stopActivated
                var stopTimes = []
                for (var k = 0; k < stopActivated; k++) {
                    stopTimes.push(Date.now())
                }
                root.rtDeviceStartTimes = stopTimes
                rtRefreshTimer.start()
                console.log("📡 LogicControlPanel: 同步停止中-设备停止, 已停止:", stopActivated)
            }
        }
        // status === "停止" → 默认空闲状态，无需处理
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
        // ✅ 2026-03-21 [Phase 7.48.72]: "前等待"语义
        // 箭头在设备deviceIndex和deviceIndex+1之间，延时属于即将激活的设备deviceIndex+1
        var delay = root.currentDelays[deviceIndex + 1] || 1.0
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
                            // ✅ 2026-03-21 [Phase 7.48.71]: Tab切换不再重置实时跟踪状态
                            // 旧代码：root.resetRealtimeTracking()
                            // 修复问题1：切换Tab后再切回启动顺序，时间轴状态丢失
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
                    // ✅ 2026-03-21 [Phase 7.48.71]: 停止序列状态文字
                    // ✅ 2026-03-21 [Phase 7.48.72]: 增加停车预警状态（rtPhase=5）
                    Text {
                        visible: root.isRealtimeActive && root.currentTab === 1 && (root.rtPhase === 4 || root.rtPhase === 5)
                        text: root.rtPhase === 5
                            ? "停车预警 " + root.rtElapsed.toFixed(1) + "s"
                            : "停止中 " + root.rtElapsed.toFixed(1) + "s  设备 " + root.rtActivatedCount + "/" + root.stopSeq.length
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ff4757"
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
                            // ✅ 2026-03-21 [Phase 7.48.72]: "前等待"语义 - 显示第一个设备的延时和进度
                            // 含义：预警结束后，等待第一个设备的延时，再激活第一个设备
                            Item {
                                width: 90; height: 140
                                visible: root.currentTab === 0 && root.currentSeq.length > 0

                                property color prefixDelayColor: {
                                    var d = root.currentDelays[0] || 1.0
                                    return d <= 2.0 ? "#00ff88" : (d <= 5.0 ? "#f39c12" : "#ff4757")
                                }

                                // 进度条轨道
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    width: parent.width - 14; height: 8; x: 4
                                    radius: 4
                                    color: "#1a2332"
                                    border.color: "#2c3e50"; border.width: 1

                                    // 填充：等待第一个设备的延时进度
                                    Rectangle {
                                        anchors.left: parent.left; anchors.leftMargin: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - 2; radius: 3
                                        width: {
                                            var _e = root.rtElapsed  // 强制绑定刷新
                                            if (!root.isRealtimeActive || root.rtPhase < 2) return 0
                                            // 第一个设备已激活，填满
                                            if (root.rtActivatedCount > 0) return parent.width - 2
                                            // 正在等待第一个设备的延时
                                            if (root.rtPhase === 2) {
                                                var firstDelay = root.currentDelays[0] || 1.0
                                                var progress = firstDelay > 0 ? Math.min(1.0, root.rtElapsed / firstDelay) : 1.0
                                                return progress * (parent.width - 2)
                                            }
                                            return 0
                                        }
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

                                // 延时标签（第一个设备的延时 - 前等待语义）
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -14
                                    width: 56; height: 24; radius: 12
                                    color: "#0d1520"
                                    border.color: parent.prefixDelayColor; border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.currentDelays[0] || 1.0).toFixed(1) + "s"
                                        font.pixelSize: 14; font.bold: true
                                        color: parent.parent.prefixDelayColor
                                    }
                                }
                            }

                            // ✅ 2026-03-21 [Phase 7.48.71]: 停止顺序前缀节点 - "停止键开始"
                            // ✅ 2026-03-21 [Phase 7.48.72]: 支持rtPhase=5（停车预警）实时状态
                            Rectangle {
                                width: 100; height: 140; radius: 8
                                visible: root.currentTab === 1
                                color: root.isRealtimeActive && (root.rtPhase === 5 || root.rtPhase === 4) ? "#006633" : "#1e3a5f"
                                border.color: root.isRealtimeActive && (root.rtPhase === 5 || root.rtPhase === 4) ? "#00ff88" : "#ff4757"
                                border.width: root.isRealtimeActive && root.rtPhase === 5 ? 3 : 2

                                Rectangle {
                                    width: parent.width - 4; height: 4; radius: 2
                                    anchors.top: parent.top; anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "#ff4757"; z: 1
                                }
                                Column {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "■"; font.pixelSize: 24; color: "#ff4757" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "停止键"; font.pixelSize: 20; font.bold: true; color: "white" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "开始"; font.pixelSize: 20; font.bold: true; color: "white" }
                                }
                            }

                            // ✅ 2026-03-21 [Phase 7.48.71]: 停止顺序前缀进度条1：停止键→停车预警
                            // ✅ 2026-03-21 [Phase 7.48.72]: 实时停车预警进度（rtPhase=5时显示进度）
                            Item {
                                width: 90; height: 140
                                visible: root.currentTab === 1

                                // 进度条轨道
                                Rectangle {
                                    id: stopWarnTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    width: parent.width - 14; height: 8; x: 4
                                    radius: 4
                                    color: "#1a2332"
                                    border.color: "#2c3e50"; border.width: 1

                                    // 填充：停车预警进度（rtPhase=5时实时更新，rtPhase=4时填满）
                                    Rectangle {
                                        anchors.left: parent.left; anchors.leftMargin: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - 2; radius: 3
                                        width: {
                                            var _e = root.rtElapsed  // 强制绑定刷新
                                            if (!root.isRealtimeActive) return 0
                                            if (root.rtPhase === 4) return parent.width - 2  // 停车音频已播完
                                            if (root.rtPhase === 5) {
                                                // 停车预警进度（停车音频通常很短，用5秒估计）
                                                var progress = Math.min(1.0, root.rtElapsed / 5.0)
                                                return progress * (parent.width - 2)
                                            }
                                            return 0
                                        }
                                        color: "#ff4757"
                                        opacity: 0.9
                                        Behavior on width { NumberAnimation { duration: 100 } }
                                    }

                                    // 发光边框（停车预警进行中）
                                    Rectangle {
                                        anchors.fill: parent; radius: parent.radius
                                        color: "transparent"
                                        border.color: "#ff4757"
                                        border.width: root.isRealtimeActive && root.rtPhase === 5 ? 1 : 0
                                        opacity: 0.6
                                    }
                                }

                                // 右端方向指示三角
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    text: "▸"; font.pixelSize: 14; color: "#ff4757"
                                }
                            }

                            // ✅ 2026-03-21 [Phase 7.48.71]: 停止顺序前缀节点 - "停车预警"
                            // ✅ 2026-03-21 [Phase 7.48.72]: 支持rtPhase=5实时状态
                            Rectangle {
                                width: 100; height: 140; radius: 8
                                visible: root.currentTab === 1
                                color: root.isRealtimeActive && root.rtPhase === 4 ? "#006633" : "#1e3a5f"
                                border.color: root.isRealtimeActive && root.rtPhase === 4 ? "#00ff88" : "#ff4757"
                                border.width: 2

                                Rectangle {
                                    width: parent.width - 4; height: 4; radius: 2
                                    anchors.top: parent.top; anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "#ff4757"; z: 1
                                }
                                Column {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⚠"; font.pixelSize: 24; color: "#ff4757" }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "停车预警"; font.pixelSize: 20; font.bold: true; color: "white" }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.getWarningTime() + "s"
                                        font.pixelSize: 18; color: "#ff4757"
                                    }
                                }
                            }

                            // ✅ 2026-03-21 [Phase 7.48.71]: 停止顺序前缀进度条2：停车预警→第一个停止设备
                            // ✅ 2026-03-21 [Phase 7.48.72]: "前等待"语义 - 显示第一个停止设备的延时
                            Item {
                                width: 90; height: 140
                                visible: root.currentTab === 1 && root.currentSeq.length > 0

                                property color stopPrefixDelayColor: {
                                    var d = root.currentDelays[0] || 1.0
                                    return d <= 2.0 ? "#00ff88" : (d <= 5.0 ? "#f39c12" : "#ff4757")
                                }

                                // 进度条轨道
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                    width: parent.width - 14; height: 8; x: 4
                                    radius: 4
                                    color: "#1a2332"
                                    border.color: "#2c3e50"; border.width: 1

                                    // 填充：等待第一个停止设备的延时进度
                                    Rectangle {
                                        anchors.left: parent.left; anchors.leftMargin: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - 2; radius: 3
                                        width: {
                                            var _e = root.rtElapsed
                                            if (!root.isRealtimeActive || root.rtPhase !== 4) return 0
                                            if (root.rtActivatedCount > 0) return parent.width - 2
                                            var firstDelay = root.currentDelays[0] || 1.0
                                            var progress = firstDelay > 0 ? Math.min(1.0, root.rtElapsed / firstDelay) : 1.0
                                            return progress * (parent.width - 2)
                                        }
                                        color: root.themeColor
                                        opacity: 0.9
                                        Behavior on width { NumberAnimation { duration: 100 } }
                                    }
                                }

                                // 延时标签（第一个停止设备的延时）
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -14
                                    width: 56; height: 24; radius: 12
                                    color: "#0d1520"
                                    border.color: parent.stopPrefixDelayColor; border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.currentDelays[0] || 1.0).toFixed(1) + "s"
                                        font.pixelSize: 14; font.bold: true
                                        color: parent.parent.stopPrefixDelayColor
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
                                        // ✅ 2026-03-21 [Phase 7.48.69]: 故障时所有设备恢复为停止颜色（不保留绿色）
                                        color: {
                                            // 故障状态：故障设备显示红色，其余已激活设备恢复默认（非绿色）
                                            if (root.rtPhase === 3) {
                                                var deviceName = root.currentSeq[index] || ""
                                                if (root.rtFaultDevice !== "" && deviceName === root.rtFaultDevice)
                                                    return "#4a0000"  // 故障设备红色背景
                                                // 故障后所有设备恢复默认颜色，不再显示绿色
                                                return nodeMouseArea.containsMouse ? "#2a5080" : "#1e3a5f"
                                            }
                                            // ✅ 2026-03-21 [Phase 7.48.70]: 停止序列用红色调，启动序列用绿色调
                                            if (root.isRealtimeActive && root.rtPhase === 4 && root.currentTab === 1 && index < root.rtActivatedCount) {
                                                return index === root.rtActivatedCount - 1
                                                    ? "#663300"  // 刚停用（当前设备）- 暗橙色
                                                    : "#442200"  // 已停用（前序设备）- 更暗
                                            }
                                            if (root.isRealtimeActive && root.currentTab === 0 && index < root.rtActivatedCount) {
                                                return index === root.rtActivatedCount - 1
                                                    ? "#006633"  // 刚激活（当前设备）- 从#004d22调亮
                                                    : "#004422"  // 已激活（前序设备）- 从#002211调亮
                                            }
                                            return nodeMouseArea.containsMouse ? "#2a5080" : "#1e3a5f"
                                        }
                                        border.color: {
                                            // ✅ 2026-03-21 [Phase 7.48.69]: 故障时所有设备恢复为默认边框
                                            if (root.rtPhase === 3) {
                                                var dn = root.currentSeq[index] || ""
                                                if (root.rtFaultDevice !== "" && dn === root.rtFaultDevice)
                                                    return "#ff4757"
                                                return root.themeColor
                                            }
                                            // ✅ 2026-03-21 [Phase 7.48.70]: 停止序列边框也要高亮
                                            if (root.isRealtimeActive && root.rtPhase === 4 && root.currentTab === 1 && index < root.rtActivatedCount)
                                                return "#ff4757"  // 红色边框表示已停用
                                            return root.isRealtimeActive && root.currentTab === 0 && index < root.rtActivatedCount
                                                ? "#00ff88" : root.themeColor
                                        }
                                        border.width: {
                                            // ✅ 2026-03-21 [Phase 7.48.69]: 故障时只有故障设备加粗边框
                                            if (root.rtPhase === 3 && root.rtFaultDevice === (root.currentSeq[index] || "")) return 3
                                            if (root.rtPhase === 3) return 2  // 非故障设备恢复正常边框
                                            // ✅ 2026-03-21 [Phase 7.48.70]: 停止序列当前设备加粗边框
                                            if (root.isRealtimeActive && root.rtPhase === 4 && root.currentTab === 1 && index === root.rtActivatedCount - 1) return 3
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
                                            spacing: 4
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
                                            // ✅ 2026-03-21 [Phase 7.48.69]: 每个设备卡片显示其启动延时
                                            // 原因：用户反馈张紧控制前面没有显示启动延时
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "延时 " + (root.currentDelays[index] || 1.0).toFixed(1) + "s"
                                                font.pixelSize: 14
                                                color: {
                                                    var d = root.currentDelays[index] || 1.0
                                                    return d <= 2.0 ? "#66ccff" : (d <= 5.0 ? "#f39c12" : "#ff6b6b")
                                                }
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
                                        // ✅ 2026-03-21 [Phase 7.48.72]: "前等待"语义
                                        // 箭头在设备index和index+1之间，延时属于即将激活的设备index+1（等多久才激活下一个）
                                        property color delayColor: {
                                            var d = root.currentDelays[index + 1] || 1.0
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

                                            // 进度条填充（实时设备激活/停用进度）
                                            Rectangle {
                                                id: progressFill
                                                anchors.left: parent.left; anchors.leftMargin: 1
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: parent.height - 2; radius: 3
                                                width: {
                                                    var _e = root.rtElapsed  // 强制绑定刷新
                                                    // ✅ 2026-03-21 [Phase 7.48.70]: 同时支持启动(tab0)和停止(tab1)序列
                                                    // 旧代码：if (!root.isRealtimeActive || root.currentTab !== 0) return 0
                                                    if (!root.isRealtimeActive) return 0
                                                    var isActiveTab = (root.currentTab === 0 && root.rtPhase === 2) ||
                                                                      (root.currentTab === 1 && root.rtPhase === 4)
                                                    if (!isActiveTab) return 0
                                                    // 设备已通过此箭头（下一设备已激活/停用）
                                                    if (index + 1 < root.rtActivatedCount) return parent.width - 2
                                                    // 当前设备已激活/停用，等待下一设备
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
                                                // ✅ 2026-03-21 [Phase 7.48.70]: 同时支持启动和停止序列发光
                                                border.width: {
                                                    if (!root.isRealtimeActive || root.rtActivatedCount !== index + 1) return 0
                                                    if (root.currentTab === 0 && root.rtPhase === 2 && root.rtActivatedCount < root.startupSeq.length) return 1
                                                    if (root.currentTab === 1 && root.rtPhase === 4 && root.rtActivatedCount < root.stopSeq.length) return 1
                                                    return 0
                                                }
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
                                                // ✅ 2026-03-21 [Phase 7.48.72]: "前等待"语义 - 显示下一个设备的延时
                                                text: (root.currentDelays[index + 1] || 1.0).toFixed(1) + "s"
                                                font.pixelSize: 14; font.bold: true
                                                color: arrowItem.delayColor
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    // ✅ 2026-03-21 [Phase 7.48.72]: 编辑下一个设备的延时（前等待语义）
                                                    editPopup.editIndex = index + 1
                                                    editPopup.editDelay = root.currentDelays[index + 1] || 1.0
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

                    // ✅ 2026-03-21 [Phase 7.48.71]: 滚动提示（设备>4个时内容超出可视区）
                    // 修复问题6：设备超过4个时宽度不够，提示用户可滑动
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 60; radius: 14
                        color: "#1a2332"
                        border.color: root.themeColor; border.width: 1
                        opacity: timelineFlickable.contentWidth > timelineFlickable.width ? 0.8 : 0.0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "◀"; font.pixelSize: 10; color: timelineFlickable.atXBeginning ? "#555" : root.themeColor; rotation: 180 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "☰"; font.pixelSize: 12; color: root.themeColor }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "▶"; font.pixelSize: 10; color: timelineFlickable.atXEnd ? "#555" : root.themeColor }
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
                    // ✅ 2026-03-21 [Phase 7.48.71]: 设备>4个时提示可左右滑动
                    text: "点击节点编辑延时 │ ◀▶ 调整顺序 │ × 删除设备 │ 点击连线延时标签修改"
                        + (timelineFlickable.contentWidth > timelineFlickable.width ? " │ ← 左右滑动查看 →" : "")
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
                                                    // ✅ 2026-03-29 [Phase 7.48.88.67]: 禁用设备灰显
                                                    property bool isDisabled: root.isDeviceDisabled(devName)
                                                    // ✅ 2026-03-29 [Phase 7.48.88.68]: 通道未配置设备琥珀色警告
                                                    property bool isUnconfigured: !isDisabled && root.isDeviceUnconfigured(devName)
                                                    property color groupColor: root.deviceGroups[parent.gIdx].color

                                                    width: 96
                                                    height: 36
                                                    radius: 4
                                                    // ✅ 2026-03-29 [Phase 7.48.88.68]: 三态样式：禁用(红) > 未配置(琥珀) > 已入序列(���) > 正常(蓝)
                                                    // 旧代码: color: isDisabled ? "#1a1a1a" : (inSeq ? "#1a1a2e" : (poolItemMa.containsMouse ? groupColor : "#1e3a5f"))
                                                    color: isDisabled ? "#1a1a1a" : (isUnconfigured ? "#2a2000" : (inSeq ? "#1a1a2e" : (poolItemMa.containsMouse ? groupColor : "#1e3a5f")))
                                                    // 旧代码: opacity: isDisabled ? 0.5 : (inSeq ? 0.4 : 1.0)
                                                    opacity: isDisabled ? 0.5 : (isUnconfigured ? 0.6 : (inSeq ? 0.4 : 1.0))
                                                    // 旧代码: border.color: isDisabled ? "#FF5722" : groupColor
                                                    border.color: isDisabled ? "#FF5722" : (isUnconfigured ? "#FFC107" : groupColor)
                                                    border.width: 1

                                                    // ✅ 2026-03-29 [Phase 7.48.88.67]: 禁用标记斜线
                                                    Canvas {
                                                        anchors.fill: parent
                                                        visible: parent.isDisabled
                                                        onPaint: {
                                                            var ctx = getContext("2d")
                                                            ctx.clearRect(0, 0, width, height)
                                                            ctx.strokeStyle = "#FF5722"
                                                            ctx.lineWidth = 1.5
                                                            ctx.globalAlpha = 0.6
                                                            // 左上到右下斜线
                                                            ctx.beginPath()
                                                            ctx.moveTo(4, 4)
                                                            ctx.lineTo(width - 4, height - 4)
                                                            ctx.stroke()
                                                        }
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.devName
                                                        font.pixelSize: 16
                                                        // ✅ 2026-03-29 [Phase 7.48.88.68]: 三态文字颜色：禁用(红) > 未配置(琥珀) > 已入序列(灰) > 正常(白)
                                                        // 旧代码: color: parent.isDisabled ? "#FF5722" : (parent.inSeq ? "#555555" : "white")
                                                        color: parent.isDisabled ? "#FF5722" : (parent.isUnconfigured ? "#FFC107" : (parent.inSeq ? "#555555" : "white"))
                                                        font.strikeout: parent.isDisabled
                                                    }

                                                    // ✅ 2026-03-29 [Phase 7.48.88.67]: 禁用设备右上角"禁"标签
                                                    Rectangle {
                                                        visible: parent.isDisabled
                                                        anchors.right: parent.right
                                                        anchors.top: parent.top
                                                        anchors.rightMargin: -2
                                                        anchors.topMargin: -2
                                                        width: 16; height: 16; radius: 8
                                                        color: "#FF5722"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "禁"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: "white"
                                                        }
                                                    }

                                                    // ✅ 2026-03-29 [Phase 7.48.88.68]: 通道未配置设备右上角"未"标签
                                                    Rectangle {
                                                        visible: parent.isUnconfigured
                                                        anchors.right: parent.right
                                                        anchors.top: parent.top
                                                        anchors.rightMargin: -2
                                                        anchors.topMargin: -2
                                                        width: 16; height: 16; radius: 8
                                                        color: "#FFC107"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "未"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: "#1a1a1a"
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: poolItemMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        // ✅ 2026-03-29 [Phase 7.48.88.68]: 禁用和未配置通道设备均不可点击添加
                                                        // 旧代码: enabled: !parent.inSeq && !parent.isDisabled && root.currentSeq.length < 10
                                                        enabled: !parent.inSeq && !parent.isDisabled && !parent.isUnconfigured && root.currentSeq.length < 10
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
