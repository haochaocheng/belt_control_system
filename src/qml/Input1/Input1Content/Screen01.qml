import QtQuick
import QtQuick.Controls
import Input1
// ✅ 2026-01-31 [FIX 100.300.112.8.10]: 删除 Input1Content 导入（模块不存在）
// import Input1Content  // ❌ 此模块未在 CMakeLists.txt 中定义

// ✅ 2026-01-27 [FIX 100.300.54]: Screen01 包装器 - 添加键盘导航功能
// ✅ 2026-01-27 [FIX 100.300.56]: 添加 Input1Content 导入以加载 Screen01Form
// ✅ 2026-01-27 [FIX 100.300.58]: 增强焦点管理和调试信息
// ✅ 2026-01-28 [FIX 100.300.60]: 添加 dataItems 空值检查，修复 QDS 中 undefined 错误
// ✅ 2026-01-28 [FIX 100.300.62]: 改用直接访问组件方式，修复 QDS 中 dataItems 未定义问题
// ✅ 2026-01-28 [FIX 100.300.67]: 添加鼠标单击选中和双击打开弹窗功能
// ✅ 2026-01-28 [FIX 100.300.68]: 修复闭包陷阱，使用立即执行函数（IIFE）捕获索引
Item {
    id: root
    width: 1920
    height: 1080

    property int currentPageIndex: 0
    property int selectedIndex: 0

    // ✅ 2026-03-22 [Phase 7.48.82.2]: 区分QDS独立预览与设备SwipeView运行
    // QDS独立运行时保持true（需要焦点），通过Input1Page.onLoaded设为false（设备模式）
    property bool autoFocusOnLoad: true

    readonly property int rows: 3
    readonly property int cols: 4
    readonly property int totalItems: 12
    readonly property int beltCardCount: 8

    property var beltSensorMappings: ({})

    // ✅ 2026-03-28 [Phase 7.48.88.50]: 飞行动画状态
    property int flyingCardIndex: -1  // 当前飞行中的卡片索引（-1=无）

    focus: true
    activeFocusOnTab: true

    // ✅ 2026-01-30 [调试]: 详细追踪焦点变化
    onActiveFocusChanged: {
        console.log("🔍 [Screen01] ========== 焦点状态变化 ==========")
        console.log("🔍 [Screen01] activeFocus:", activeFocus ? "✅ 获得焦点" : "❌ 失去焦点")
        console.log("🔍 [Screen01] focus 属性:", focus)
        console.log("🔍 [Screen01] parent:", parent)
        console.log("🔍 [Screen01] parent.objectName:", parent ? parent.objectName : "无")
        console.log("🔍 [Screen01] =====================================")
    }

    onFocusChanged: {
        console.log("🔍 [Screen01] focus 属性变化:", focus)
    }

    // ✅ 2026-01-28 [FIX 100.300.65]: 添加双击事件打开设备设置对话框
    // ✅ 2026-01-28 [FIX 100.300.67]: 修改为仅处理空白区域点击，不阻止子组件鼠标事件
    MouseArea {
        anchors.fill: parent
        z: -1  // 放在最底层，只处理空白区域
        onClicked: {
            console.log("[Screen01] 🖱️ 点击空白区域，强制获取焦点")
            root.forceActiveFocus()
        }
    }

    Screen01Form {
        id: screen01Form
        anchors.fill: parent
        currentPageIndex: root.currentPageIndex

        Component.onCompleted: {
            console.log("[Screen01Form] ✅ 组件加载完成")
        }
    }

    // ❌ 2026-02-10 [Phase 7.45.7]: 移除设备监控按钮和对话框
    // 原因：设备监控已改为独立页面，在 main_qds.qml 的 SwipeView 中
    // 用户可通过导航栏切换到设备监控页面
    /*
    // ✅ 2026-02-10 [Phase 7.45.5]: 设备监控按钮
    Button {
        id: deviceMonitorButton
        ...
    }

    // ✅ 2026-02-10 [Phase 7.45.5]: 设备监控对话框
    Loader {
        id: deviceMonitorDialogLoader
        ...
    }
    */

    // ========== 页面内设备卡片点击处理 ==========

    // ✅ 2026-01-28 [FIX 100.300.62]: 直接访问 Screen01Form 的子组件
    function getDataItems() {
        return [
            screen01Form.data_row1_col1,
            screen01Form.data_row1_col2,
            screen01Form.data_row1_col3,
            screen01Form.data_row1_col4,
            screen01Form.data_row2_col1,
            screen01Form.data_row2_col2,
            screen01Form.data_row2_col3,
            screen01Form.data_row2_col4,
            screen01Form.data_row3_col1,
            screen01Form.data_row3_col2,
            screen01Form.data_row3_col3,
            screen01Form.data_row3_col4
        ]
    }

    function getLocalDeviceId() {
        if (typeof deviceRoleManager !== "undefined" && deviceRoleManager && deviceRoleManager.localDeviceId > 0) {
            return deviceRoleManager.localDeviceId
        }
        if (typeof systemConfig !== "undefined" && systemConfig && systemConfig.machineNumber > 0) {
            return systemConfig.machineNumber
        }
        return 1
    }

    function getLocalDeviceName() {
        var localDeviceId = getLocalDeviceId()

        if (typeof deviceConfigMgr !== "undefined" && deviceConfigMgr && localDeviceId > 0) {
            var sqlName = deviceConfigMgr.loadBasicConfig(localDeviceId, "localDeviceName")
            if (sqlName && sqlName !== "") {
                return sqlName
            }
        }

        if (typeof systemConfig !== "undefined" && systemConfig && systemConfig.localDeviceName) {
            return systemConfig.localDeviceName
        }

        return localDeviceId + "号皮带"
    }

    // ✅ 2026-03-28 [Phase 7.48.88.48]: 从DB加载启动序列+洒水设备到本机卡片的outputDevices
    function loadOutputDeviceList() {
        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) return
        var deviceId = getLocalDeviceId()
        var localIdx = deviceId - 1
        if (localIdx < 0 || localIdx >= beltCardCount) return
        var dataItems = getDataItems()
        if (!dataItems[localIdx]) return

        // 读取启动序列
        var config = deviceConfigMgr.loadDeviceLogicConfig(deviceId)
        var startupStr = config["startup_sequence"] || "[]"
        var devices = JSON.parse(startupStr)
        if (devices.length === 0) devices = ["张紧控制", "1号制动器", "1号电机", "2号电机"]

        // 追加已启用的洒水设备（不重复）
        for (var si = 1; si <= 8; si++) {
            var cfg = deviceConfigMgr.loadSprinklerConfig(si)
            if (cfg && Number(cfg["enabled"]) === 1) {
                var spName = "洒水" + si
                if (devices.indexOf(spName) === -1) devices.push(spName)
            }
        }

        dataItems[localIdx].outputDevices = devices
        console.log("[Screen01] 📋 输出设备列表:", JSON.stringify(devices))
    }

    // ✅ 2026-03-28 [Phase 7.48.88.50]: 飞行动画函数
    // ✅ 2026-03-28 [Phase 7.48.88.51]: 冲突处理增强
    //   P0: 心跳超时3秒，无信号强制飞回
    //   P1: 停车预警也触发飞回；飞回动画期间允许新飞行
    //   P2: 最后启动的卡片优��飞出，前一个自动退回

    property int flyCleanupIndex: -1  // 等待清理的卡片索引

    // 初始化：保存每张卡片的原始位置
    function initCardOriginalPositions() {
        var dataItems = getDataItems()
        for (var i = 0; i < dataItems.length; i++) {
            if (dataItems[i]) {
                dataItems[i].originalX = dataItems[i].x
                dataItems[i].originalY = dataItems[i].y
            }
        }
        console.log("[Screen01] 📐 卡片原始位置已保存")
    }

    // 卡片飞到中央（P2: 如有其他卡片在飞，自动退回前一个）
    function flyCardToCenter(cardIndex) {
        // 同一张卡片重复飞出 → 忽略
        if (flyingCardIndex === cardIndex) return

        var dataItems = getDataItems()
        var card = dataItems[cardIndex]
        if (!card) return

        // P2: 如果有其他卡片在飞行，先强制退回
        if (flyingCardIndex >= 0) {
            var oldCard = dataItems[flyingCardIndex]
            if (oldCard) {
                console.log("[Screen01] ✈️ 卡片", flyingCardIndex + 1, "被新启动抢占，强制退回")
                oldCard.x = oldCard.originalX
                oldCard.y = oldCard.originalY
                oldCard.scale = 1
                scheduleCardCleanup(flyingCardIndex)
            }
        }

        flyingCardIndex = cardIndex

        // 启用动画 → 改变属性
        card.flyAnimating = true
        card.z = 100

        // 目标位置：屏幕中央（scale从center展开，只需中心点对齐）
        var targetX = (1920 - card.width) / 2
        var targetY = (1080 - card.height) / 2
        card.x = targetX
        card.y = targetY
        card.scale = 2

        // 显示遮罩
        screen01Form.flyDimOverlay.opacity = 0.6

        // P0: 心跳计时由调用方控制（起车预警不启动，设备阶段才启动）
        // ✅ 2026-03-28 [Phase 7.48.88.52]: 移除此处的heartbeat启动
        // 原因：起车预警期间音频播放约9秒，3秒心跳超时会导致卡片提前飞回
        // flyHeartbeatTimer.restart()  // 已移至onBeltSequenceProgress的设备阶段分支

        console.log("[Screen01] ✈️ 卡片", cardIndex + 1, "飞到中央 →",
                    "x:", targetX, "y:", targetY, "scale: 2")
    }

    // 卡片飞回原位（P1: 立即释放flyingCardIndex，允许新飞行）
    function flyCardBack() {
        if (flyingCardIndex < 0) return
        var dataItems = getDataItems()
        var card = dataItems[flyingCardIndex]
        if (!card) return

        console.log("[Screen01] ✈️ 卡片", flyingCardIndex + 1, "飞回原位 →",
                    "x:", card.originalX, "y:", card.originalY)

        // 恢复位置和缩放
        card.x = card.originalX
        card.y = card.originalY
        card.scale = 1

        // 隐藏遮罩
        screen01Form.flyDimOverlay.opacity = 0

        // P0: 停止心跳计时
        flyHeartbeatTimer.stop()

        // P1: 立即释放flyingCardIndex（不等cleanup），允许新飞行
        scheduleCardCleanup(flyingCardIndex)
        flyingCardIndex = -1
    }

    // 延迟清理卡片动画状态（等Behavior动画播完再重置z和flyAnimating）
    function scheduleCardCleanup(cardIndex) {
        // 如果有上一个还没清理的卡片，先立即清理（动画肯定已播完）
        if (flyCleanupIndex >= 0 && flyCleanupIndex !== flyingCardIndex) {
            var prevCard = getDataItems()[flyCleanupIndex]
            if (prevCard) {
                prevCard.flyAnimating = false
                prevCard.z = 0
            }
        }
        flyCleanupIndex = cardIndex
        flyBackCleanupTimer.restart()
    }

    // 飞回动画结束后的清理定时器
    Timer {
        id: flyBackCleanupTimer
        interval: 650  // 略大于动画时长600ms
        repeat: false
        onTriggered: {
            if (flyCleanupIndex >= 0 && flyCleanupIndex !== flyingCardIndex) {
                var dataItems = getDataItems()
                var card = dataItems[flyCleanupIndex]
                if (card) {
                    card.flyAnimating = false
                    card.z = 0
                }
                console.log("[Screen01] ✈️ 卡片", flyCleanupIndex + 1, "飞行动画清理完成")
            }
            flyCleanupIndex = -1
        }
    }

    // P0: 心跳超时定时器（动态interval，默认3秒，设备阶段根据delayMs调整）
    // ✅ 2026-03-28 [Phase 7.48.88.52]: interval由设备阶段动态设置
    Timer {
        id: flyHeartbeatTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (flyingCardIndex >= 0) {
                console.warn("[Screen01] ⏰ 飞行心跳超时(" + interval + "ms无信号)，卡片", flyingCardIndex + 1, "强制飞回")
                flyCardBack()
            }
        }
    }

    function qmlModuleIndex(moduleType) {
        if (moduleType === "模拟量模块1") return 2
        if (moduleType === "模拟量模块2") return 3
        return -1
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(1, value || 0))
    }

    function computeEngineeringValue(adValue, rangeValue, inputType) {
        var range = Number(rangeValue) || 0
        var adc = Number(adValue) || 0
        if (range <= 0) return 0

        var normalized = adc / 65535.0
        if (inputType && (inputType.indexOf("4-20mA") >= 0 || inputType.indexOf("1-5V") >= 0)) {
            var zeroPoint = 65535.0 * 0.2
            if (adc <= zeroPoint) return 0
            normalized = (adc - zeroPoint) / (65535.0 - zeroPoint)
        }

        return Math.max(0, normalized * range)
    }

    function buildAnalogMapping(config, valueKey) {
        if (!config) return null

        var moduleIndex = qmlModuleIndex(config.module_type)
        var channelIndex = Number(config.register_address)
        if (moduleIndex < 0 || channelIndex < 0) return null

        return {
            moduleIndex: moduleIndex,
            channelIndex: channelIndex,
            rangeValue: Number(config.range_value) || Number(config.rated_value) || 0,
            inputType: config.input_type || "4-20mA电流型",
            unit: config.unit || "",
            valueKey: valueKey
        }
    }

    function buildTensionMapping(config) {
        if (!config) return null

        var moduleIndex = qmlModuleIndex(config.module_type)
        var channelIndex = Number(config.channel_number)
        if (moduleIndex < 0 || channelIndex < 0) return null

        return {
            moduleIndex: moduleIndex,
            channelIndex: channelIndex,
            rangeValue: Number(config.range_value) || Number(config.rated_value) || 0,
            inputType: config.input_type || "4-20mA电流型",
            unit: config.unit || "kN",
            valueKey: "param4"
        }
    }

    function rebuildBeltSensorMappings() {
        var mappings = {}

        if (typeof deviceConfigMgr === "undefined" || !deviceConfigMgr) {
            console.log("[Screen01] ⚠️ deviceConfigMgr 不可用, 无法构建传感器映射")
            beltSensorMappings = mappings
            return
        }

        for (var beltNumber = 1; beltNumber <= beltCardCount; beltNumber++) {
            var analogProtections = deviceConfigMgr.loadAllAnalogProtections(beltNumber)
            var speedMapping = null

            // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 添加调试日志，排查速度数据绑定
            console.log("[Screen01] 📊 皮带", beltNumber, "加载保护配置:", analogProtections.length, "项")

            for (var i = 0; i < analogProtections.length; i++) {
                var protection = analogProtections[i]
                if (protection.protection_name === "速度") {
                    speedMapping = buildAnalogMapping(protection, "param1")
                    console.log("[Screen01] ✅ 皮带", beltNumber, "速度映射: moduleIndex=",
                        speedMapping ? speedMapping.moduleIndex : "null",
                        "channelIndex=", speedMapping ? speedMapping.channelIndex : "null",
                        "rangeValue=", speedMapping ? speedMapping.rangeValue : "null")
                    break
                }
            }

            var tensionConfig = deviceConfigMgr.loadTensionConfig(beltNumber, 0)
            var tensionMapping = buildTensionMapping(tensionConfig)

            if (!speedMapping) {
                console.log("[Screen01] ⚠️ 皮带", beltNumber, "没有速度保护配置")
            }

            mappings[beltNumber - 1] = {
                speed: speedMapping,
                tension: tensionMapping
            }
        }

        beltSensorMappings = mappings
    }

    function applyMappedValue(item, mapping, data) {
        if (!item || !mapping || !data || !data.valid) return

        var engineeringValue = computeEngineeringValue(data.adValue, mapping.rangeValue, mapping.inputType)
        var percent = mapping.rangeValue > 0 ? clampPercent(engineeringValue / mapping.rangeValue) : 0
        var valueText = engineeringValue.toFixed(mapping.valueKey === "param1" ? 2 : 1)
        var percentKey = mapping.valueKey + "Percent"

        // ✅ 2026-03-26 [Phase 7.48.88.27]: 移除高频调试日志
        // 原因：每次AI数据更新都打印，日志文件中重复上万次
        // console.log("[Screen01] 📈", mapping.valueKey, "AD:", data.adValue,
        //     "→ 工程值:", valueText, mapping.unit, "percent:", percent.toFixed(2))

        item[mapping.valueKey + "Value"] = valueText
        item[mapping.valueKey + "Unit"] = mapping.unit
        item[percentKey] = percent
    }

    // ✅ 2026-03-27 [Phase 7.48.88.41]: AI模拟量数据来自本机传感器，只更新本机卡片
    // 旧代码：遍历所有8个卡片匹配通道，导致所有卡片显示相同数据
    function applyAnalogChannelUpdate(moduleIndex, channelIndex, data) {
        var dataItems = getDataItems()
        var localIdx = getLocalDeviceId() - 1
        if (localIdx < 0 || localIdx >= beltCardCount) return
        var item = dataItems[localIdx]
        var mappingGroup = beltSensorMappings[localIdx]
        if (!item || !mappingGroup) return

        if (mappingGroup.speed &&
            mappingGroup.speed.moduleIndex === moduleIndex &&
            mappingGroup.speed.channelIndex === channelIndex) {
            applyMappedValue(item, mappingGroup.speed, data)
        }

        if (mappingGroup.tension &&
            mappingGroup.tension.moduleIndex === moduleIndex &&
            mappingGroup.tension.channelIndex === channelIndex) {
            applyMappedValue(item, mappingGroup.tension, data)
        }
    }

    // ✅ 2026-03-27 [Phase 7.48.88.41]: 只刷新本机卡片的模拟量
    // 旧代码：遍历所有8个卡片刷新，导致非本机卡片也显示数据
    function refreshMappedAnalogValues() {
        if (typeof aiDataManager === "undefined" || !aiDataManager) return
        var localIdx = getLocalDeviceId() - 1
        if (localIdx < 0 || localIdx >= beltCardCount) return
        var mappingGroup = beltSensorMappings[localIdx]
        if (!mappingGroup) return

        if (mappingGroup.speed) {
            var speedData = aiDataManager.getChannel(mappingGroup.speed.moduleIndex, mappingGroup.speed.channelIndex)
            applyAnalogChannelUpdate(mappingGroup.speed.moduleIndex, mappingGroup.speed.channelIndex, speedData)
        }

        if (mappingGroup.tension) {
            var tensionData = aiDataManager.getChannel(mappingGroup.tension.moduleIndex, mappingGroup.tension.channelIndex)
            applyAnalogChannelUpdate(mappingGroup.tension.moduleIndex, mappingGroup.tension.channelIndex, tensionData)
        }
    }

    function applyDeviceMetadata() {
        var dataItems = getDataItems()
        var localDeviceId = getLocalDeviceId()
        var localDeviceName = getLocalDeviceName()
        var deviceNames = [
            "1号皮带", "2号皮带", "3号皮带", "4号皮带",
            "5号皮带", "6号皮带", "7号皮带", "8号皮带",
            "转载机", "破碎机", "前刮板", "后刮板"
        ]

        if (localDeviceId >= 1 && localDeviceId <= beltCardCount) {
            deviceNames[localDeviceId - 1] = localDeviceName
        }

        for (var j = 0; j < dataItems.length; j++) {
            if (dataItems[j]) {
                dataItems[j].deviceName = deviceNames[j]
                dataItems[j].deviceIndex = j
                dataItems[j].isLocalDevice = (j === localDeviceId - 1)
            }
        }

        // ✅ 2026-03-27 [Phase 7.48.88.34]: 设置工作模式和连锁状态
        var currentWorkMode = (typeof systemConfig !== "undefined" && systemConfig) ? systemConfig.workMode : 1
        for (var k = 0; k < beltCardCount; k++) {
            if (dataItems[k]) {
                dataItems[k].workMode = currentWorkMode
                dataItems[k].interlockActive = (currentWorkMode !== 0)  // 检修模式=解锁
            }
        }
    }

    function refreshDeviceCards() {
        applyDeviceMetadata()
        rebuildBeltSensorMappings()
        refreshMappedAnalogValues()
    }

    // ✅ 2026-01-28 [FIX 100.300.67]: 为每个数据组件添加鼠标交互
    // 功能：单击选中，双击打开设备设置对话框
    // ✅ 2026-01-28 [FIX 100.300.68]: 修复闭包陷阱，使用立即执行函数捕获索引
    function setupMouseInteraction() {
        var dataItems = getDataItems()
        console.log("[Screen01] 🖱️ 开始设置鼠标交互...")

        for (var i = 0; i < dataItems.length; i++) {
            var item = dataItems[i]
            if (!item) {
                console.warn("[Screen01] ⚠️ 组件", i, "为 null，跳过鼠标交互设置")
                continue
            }

            // 使用立即执行函数（IIFE）捕获当前索引，避免闭包陷阱
            (function(currentIndex, currentItem) {
                // 为每个组件创建 MouseArea
                var mouseAreaComponent = Qt.createQmlObject(
                    'import QtQuick 2.15; MouseArea { anchors.fill: parent; hoverEnabled: true }',
                    currentItem,
                    "dynamicMouseArea_" + currentIndex
                )

                if (mouseAreaComponent) {
                    // 单击选中
                    mouseAreaComponent.clicked.connect(function() {
                        console.log("[Screen01] 🖱️ 单击组件", currentIndex)
                        root.selectedIndex = currentIndex
                        root.updateSelection()
                        root.forceActiveFocus()
                    })

                    // 双击打开设备设置
                    mouseAreaComponent.doubleClicked.connect(function() {
                        console.log("[Screen01] 🖱️🖱️ 双击组件", currentIndex, "- 打开设备设置对话框")
                        root.selectedIndex = currentIndex
                        root.updateSelection()
                        root.openDeviceSettings()
                    })

                    // 鼠标悬停效果（可选）
                    mouseAreaComponent.onEntered.connect(function() {
                        console.log("[Screen01] 🖱️ 鼠标悬停在组件", currentIndex)
                    })

                    console.log("[Screen01] ✅ 组件", currentIndex, "鼠标交互已设置")
                } else {
                    console.error("[Screen01] ❌ 无法为组件", currentIndex, "创建 MouseArea")
                }
            })(i, item)  // 立即执行，传入当前索引和组件
        }

        console.log("[Screen01] 🖱️ 鼠标交互设置完成")
    }

    function updateSelection() {
        // ✅ 2026-01-28 [FIX 100.300.62]: 使用 getDataItems() 直接访问
        var dataItems = getDataItems()

        // 检查是否有有效组件
        var validCount = 0
        for (var i = 0; i < dataItems.length; i++) {
            if (dataItems[i]) validCount++
        }

        if (validCount === 0) {
            console.warn("[Screen01] ⚠️ 没有有效的 dataItems，跳过更新")
            return
        }

        console.log("[Screen01] 🔄 updateSelection 开始，selectedIndex:", selectedIndex, "有效组件:", validCount)
        var successCount = 0
        for (var i = 0; i < dataItems.length; i++) {
            var item = dataItems[i]
            if (item) {
                item.selected = (i === selectedIndex)
                if (item.selected) {
                    console.log("[Screen01] ✅ 组件", i, "已选中")
                }
                successCount++
            } else {
                console.warn("[Screen01] ⚠️ 组件", i, "为 null")
            }
        }
        console.log("[Screen01] 🔄 updateSelection 完成，成功更新", successCount, "个组件")
    }

    // ✅ 2026-01-28 [FIX 100.300.65]: 添加打开设备设置对话框函数
    // ✅ 2026-01-28 [FIX 100.300.66]: 修复 open() 不是函数错误，使用 visible 属性
    // ✅ 2026-01-30 [修复]: 使用 root 作为父容器，以便对话框关闭后焦点返回到 Screen01
    // ✅ 2026-01-30 [调试]: 添加详细的焦点追踪日志
    // ✅ 2026-01-30 [修复]: 传递 parentContainer 引用，解决 FocusScope 层级问题
    function openDeviceSettings() {
        console.log("🔍 [Screen01] ========== 打开对话框 ==========")
        console.log("🔍 [Screen01] 当前选中索引:", selectedIndex)
        console.log("🔍 [Screen01] 打开前 - activeFocus:", activeFocus)
        console.log("🔍 [Screen01] 打开前 - focus:", focus)

        // ✅ 2026-03-22 [Phase 7.48.82.5]: 前8个为1-8号皮带，后4个未定义不可打开
        if (selectedIndex >= 8) {
            console.log("⚠️ [Screen01] 设备", selectedIndex + 1, "未定义，跳过打开设置")
            return
        }

        // 创建并显示 DeviceSettingsDialog
        var component = Qt.createComponent("../../components/device_info/DeviceSettingsDialog.qml")
        if (component.status === Component.Ready) {
            // ✅ 2026-03-22 [Phase 7.48.82.4]: 根据选中索引传递不同的deviceId和deviceName
            // 原因：12个设备卡片都使用默认deviceId=1，导致修改一个设备的参数影响所有设备
            var deviceIndex = selectedIndex + 1  // 设备编号从1开始
            var dialog = component.createObject(root, {
                // ✅ 2026-01-30 [修复]: 传递 parentContainer 引用，用于焦点恢复
                parentContainer: root,
                deviceId: deviceIndex,
                deviceName: deviceIndex + "号皮带"
            })
            if (dialog) {
                console.log("🔍 [Screen01] 对话框创建成功")
                console.log("🔍 [Screen01] dialog.parent === root:", dialog.parent === root)
                console.log("🔍 [Screen01] dialog.parent:", dialog.parent)
                console.log("🔍 [Screen01] dialog.parentContainer === root:", dialog.parentContainer === root)

                // ✅ 2026-01-28 [FIX 100.300.66]: DeviceSettingsDialog 是 Rectangle，使用 visible 而不是 open()
                dialog.visible = true
                dialog.z = 1000  // 确保在最上层

                console.log("🔍 [Screen01] 对话框已显示")
                console.log("🔍 [Screen01] 打开后 - activeFocus:", activeFocus)
                console.log("🔍 [Screen01] 打开后 - focus:", focus)
                console.log("🔍 [Screen01] =====================================")
            } else {
                console.error("[Screen01] ❌ 无法创建 DeviceSettingsDialog 对象")
            }
        } else if (component.status === Component.Error) {
            console.error("[Screen01] ❌ DeviceSettingsDialog 加载失败:", component.errorString())
        }
    }

    Component.onCompleted: {
        console.log("[Screen01] ✅ 组件加载完成")

        // ✅ 2026-01-28 [FIX 100.300.62]: 延迟初始化，等待 Screen01Form 的子组件加载
        Qt.callLater(function() {
            var dataItems = getDataItems()
            var validCount = 0
            for (var i = 0; i < dataItems.length; i++) {
                if (dataItems[i]) validCount++
            }

            console.log("[Screen01] 📊 dataItems 有效数量:", validCount, "/ 12")

            if (validCount > 0) {
                console.log("[Screen01] 🔄 初始化选中状态...")
                updateSelection()
                applyDeviceMetadata()
                rebuildBeltSensorMappings()
                refreshMappedAnalogValues()

                // ✅ 2026-03-23 [Phase 7.48.84.4]: 设置每个卡片的设备名称
                // ✅ 2026-03-26 [Phase 7.48.88.26.2]: 从systemConfig读取本机名称
                // 旧代码：12个卡片硬编码"N号皮带"，不使用基本参数设置中的"本机名称"
                var deviceNames = [
                    "1号皮带", "2号皮带", "3号皮带", "4号皮带",
                    "5号皮带", "6号皮带", "7号皮带", "8号皮带",
                    "转载机", "破碎机", "前刮板", "后刮板"
                ]
                // 用systemConfig的本机名称覆盖对应皮带卡片
                if (typeof systemConfig !== "undefined" && systemConfig) {
                    var machineIdx = systemConfig.machineNumber - 1  // machineNumber从1开始，数组从0开始
                    if (machineIdx >= 0 && machineIdx < 8) {
                        deviceNames[machineIdx] = systemConfig.localDeviceName
                        console.log("[Screen01] 📋 本机名称:", systemConfig.localDeviceName,
                                    "编号:", systemConfig.machineNumber)
                    }
                }
                for (var j = 0; j < dataItems.length; j++) {
                    if (dataItems[j]) {
                        dataItems[j].deviceName = deviceNames[j]
                        dataItems[j].deviceIndex = j
                    }
                }
                console.log("[Screen01] ✅ 设备名称已设置")

                // ✅ 2026-03-28 [Phase 7.48.88.47]: 初始化本机卡片的今日运行时间
                // ✅ 2026-03-29 [Phase 7.48.88.54]: 同时初始化开机率
                var localIdx = getLocalDeviceId() - 1
                if (localIdx >= 0 && localIdx < beltCardCount && dataItems[localIdx]) {
                    if (typeof runtimeTracker !== "undefined" && runtimeTracker) {
                        dataItems[localIdx].dailyRuntime = runtimeTracker.dailyRuntime
                        dataItems[localIdx].dailyUptime = runtimeTracker.dailyUptime
                    }
                }

                // ✅ 2026-03-28 [Phase 7.48.88.48]: 加载输出设备列表到本机卡片
                loadOutputDeviceList()

                // ✅ 2026-03-28 [Phase 7.48.88.50]: 保存每张卡片的原始位置（飞行动画用）
                initCardOriginalPositions()

                // ✅ 2026-01-28 [FIX 100.300.67]: 设置鼠标交互
                console.log("[Screen01] 🖱️ 设置鼠标交互...")
                refreshDeviceCards()
                console.log("[Screen01] refreshDeviceCards after legacy initialization")
                setupMouseInteraction()
            } else {
                console.warn("[Screen01] ⚠️ dataItems 仍未定义，跳过初始化")
            }
        })

        // ✅ 2026-03-22 [Phase 7.48.82.2]: 延迟检查焦点模式
        // QDS独立预览: autoFocusOnLoad保持true → 获取焦点（导航键可用）
        // 设备SwipeView: Input1Page.onLoaded 已将 autoFocusOnLoad 设为 false → 不抢焦点
        // 旧代码：root.forceActiveFocus()  // 无条件抢夺导致设备启动时右键被拦截
        Qt.callLater(function() {
            if (root.autoFocusOnLoad) {
                console.log("[Screen01] 🎯 QDS独立模式，获取焦点")
                root.forceActiveFocus()
            } else {
                console.log("[Screen01] 🎯 SwipeView模式，跳过焦点获取（由App.qml管理）")
            }
        })
    }

    onSelectedIndexChanged: {
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols
        console.log("[Screen01] 📍 selectedIndex 变化:", selectedIndex, "→ 行", row, "列", col)
    }

    Keys.onPressed: function(event) {
        console.log("[Screen01] ⌨️ 按键事件 - Key:", event.key, "焦点:", activeFocus ? "✅" : "❌")

        if (!activeFocus) {
            console.warn("[Screen01] ⚠️ 无焦点，按键被忽略！请点击屏幕获取焦点")
            return
        }

        var oldIndex = selectedIndex
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols

        var keyName = ""
        if (event.key === Qt.Key_Up) {
            keyName = "↑ 上"
            if (row > 0) {
                selectedIndex = (row - 1) * cols + col
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在第一行，无法向上")
            }
        } else if (event.key === Qt.Key_Down) {
            keyName = "↓ 下"
            if (row < rows - 1) {
                selectedIndex = (row + 1) * cols + col
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在最后一行，无法向下")
            }
        } else if (event.key === Qt.Key_Left) {
            keyName = "← 左"
            if (col > 0) {
                selectedIndex = row * cols + (col - 1)
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在第一列，无法向左")
            }
        } else if (event.key === Qt.Key_Right) {
            keyName = "→ 右"
            if (col < cols - 1) {
                selectedIndex = row * cols + (col + 1)
                event.accepted = true
            } else {
                console.log("[Screen01] 🚫 已在最后一列，无法向右")
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // ✅ 2026-01-28 [FIX 100.300.65]: 添加回车键打开设备设置对话框
            console.log("[Screen01] ⏎ 回车键 - 打开设备设置对话框，索引:", selectedIndex)
            openDeviceSettings()
            event.accepted = true
        } else {
            console.log("[Screen01] ℹ️ 未处理的按键:", event.key)
        }

        if (oldIndex !== selectedIndex) {
            console.log("[Screen01] 🎯 导航成功:", keyName, "- 索引", oldIndex, "→", selectedIndex)
            updateSelection()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.activeFocus ? "yellow" : "red"
        border.width: 3
        z: 1000
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        width: 300
        height: 120
        color: "#80000000"
        z: 999

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Text {
                text: "焦点: " + (root.activeFocus ? "✅ 有" : "❌ 无")
                color: root.activeFocus ? "#00FF00" : "#FF0000"
                font.pixelSize: 18
                font.bold: true
            }

            Text {
                text: "选中: " + selectedIndex
                color: "white"
                font.pixelSize: 16
            }

            Text {
                text: "行" + Math.floor(selectedIndex / cols) + " 列" + (selectedIndex % cols)
                color: "white"
                font.pixelSize: 16
            }

            Text {
                text: "点击屏幕获取焦点"
                color: "#FFFF00"
                font.pixelSize: 12
            }
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.25]: 监听序列进度信号，更新卡片状态显示
    Connections {
        target: typeof commonControl !== "undefined" ? commonControl : null
        enabled: target !== null

        function onBeltSequenceProgress(beltNumber, phase, current, total, delayMs) {
            var idx = beltNumber - 1
            if (idx < 0 || idx >= 12) return
            var dataItems = getDataItems()
            var item = dataItems[idx]
            if (!item) return

            item.sequencePhase = phase
            item.sequenceCurrent = current
            item.sequenceTotal = total
            item.sequenceDelayMs = delayMs

            // 更新运行状态文字
            if (phase === "运行") {
                item.deviceStatus = "运行"
            } else if (phase === "停止") {
                item.deviceStatus = "停止"
                item.sequencePhase = ""  // 清空阶段，回到参数显示
                // ✅ 2026-03-28 [Phase 7.48.88.52]: 停止时清空所有输出设备LED状态
                // 原因：其他皮带的deviceStatusChanged信号会污染本机卡片LED
                // 修复：停止时强制清空，确保所有LED变为灰色
                item.outputDeviceStates = {}
            } else if (phase === "起车预警" || phase === "停车预警") {
                item.deviceStatus = phase
            } else if (phase === "故障停止") {
                // ✅ 2026-03-28 [Phase 7.48.88.46]: 故障停止时直接设为"停止中"
                // 原因：故障停止跳过停车预警，deviceStatus可能仍为"启动中"
                item.deviceStatus = "停止中"
            } else {
                // ✅ 2026-03-27 [Phase 7.48.88.37]: 修复故障停止时卡片仍显示"启动中"
                // 原因：故障停止跳过停车预警，deviceStatus为"运行"而非"停车预警"/"停止中"
                //       导致isStopSequence=false，停止序列进度误显示为"启动中"
                // 旧代码：var isStopSequence = (item.deviceStatus === "停车预警" || item.deviceStatus === "停止中")
                // 修复：当前状态为"运行"时，收到序列进度也说明正在停止（故障停车场景）
                var isStopSequence = (item.deviceStatus === "停车预警" || item.deviceStatus === "停止中" || item.deviceStatus === "运行")
                item.deviceStatus = current > 0 ? (isStopSequence ? "停止中" : "启动中") : item.deviceStatus
            }

            console.log("[Screen01] 📊 卡片", beltNumber, "阶段:", phase,
                        "进度:", current + "/" + total, "倒计时:", delayMs + "ms")

            // ✅ 2026-03-28 [Phase 7.48.88.52]: 飞行动画触发（冲突处理增强版v2）
            // 修复：起车预警阶段不启动心跳计时器（音频播放约9秒，3秒超时会提前飞回）
            // 修复：设备阶段心跳超时=delayMs+3000ms（适配不同设备延时）
            if (phase === "起车预警") {
                flyCardToCenter(idx)
                // 起车预警期间不启动心跳（音频可能播放多次，时间不确定）
                flyHeartbeatTimer.stop()
            }
            // P1: 停车预警/运行/停止/故障 → 飞回
            else if ((phase === "运行" || phase === "停止" || phase === "故障停止" || phase === "停车预警")
                       && flyingCardIndex === idx) {
                flyCardBack()
            }
            // P0: 飞行中收到设备阶段信号 → 设置心跳超时=设备延时+3秒
            else if (flyingCardIndex === idx) {
                // 设备延时可能5-8秒，心跳超时 = max(delayMs + 3000, 5000)
                var heartbeatMs = Math.max((delayMs || 0) + 3000, 5000)
                flyHeartbeatTimer.interval = heartbeatMs
                flyHeartbeatTimer.restart()
            }
        }

        function onBeltRunningChanged(beltNumber, running) {
            var idx = beltNumber - 1
            if (idx < 0 || idx >= 12) return
            var dataItems = getDataItems()
            var item = dataItems[idx]
            if (!item) return
            item.deviceStatus = running ? "运行" : "停止"
        }

        // ✅ 2026-03-28 [Phase 7.48.88.52]: 监听设备激活/停用信号，更新本机卡片输出设备LED
        // 修复：增加beltNumber参数，仅更新对应皮带的卡片LED
        function onDeviceStatusChanged(beltNumber, deviceName, isRunning) {
            var dataItems = getDataItems()
            var localIdx = getLocalDeviceId() - 1
            if (localIdx < 0 || localIdx >= beltCardCount || !dataItems[localIdx]) return

            // ✅ 仅接受本机皮带的设备状态信号
            if (beltNumber !== getLocalDeviceId()) return

            // 必须创建新对象才能触发QML的property binding更新
            var oldStates = dataItems[localIdx].outputDeviceStates || {}
            var newStates = {}
            for (var key in oldStates) {
                newStates[key] = oldStates[key]
            }
            newStates[deviceName] = isRunning
            dataItems[localIdx].outputDeviceStates = newStates
        }
    }

    // ✅ 2026-03-27 [Phase 7.48.88.34]: 监听工作模式变化，更新卡片模式/连锁显示
    Connections {
        target: typeof systemConfig !== "undefined" ? systemConfig : null
        enabled: target !== null

        function onWorkModeChanged() {
            var dataItems = getDataItems()
            var mode = systemConfig.workMode
            for (var i = 0; i < beltCardCount; i++) {
                if (dataItems[i]) {
                    dataItems[i].workMode = mode
                    dataItems[i].interlockActive = (mode !== 0)
                }
            }
            console.log("[Screen01] 📋 工作模式变化:", mode, "连锁:", (mode !== 0))
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.25]: 监听DI开关量保护状态
    // ✅ 2026-03-27 [Phase 7.48.88.39]: DI保护只应用于本机设备卡片（不是所有8张）
    Connections {
        target: typeof diDataManager !== "undefined" ? diDataManager : null
        enabled: target !== null

        function onBitChanged(moduleIndex, bitIndex, value) {
            if (moduleIndex < 0 || moduleIndex >= 2) return
            var dataItems = getDataItems()
            var localIdx = getLocalDeviceId() - 1
            // DI数据来自本机物理模块，只应用于本机设备对应的卡片
            // 旧代码：for (var i = 0; i < 8; i++) 应用到所有卡片
            if (localIdx < 0 || localIdx >= beltCardCount) return
            var item = dataItems[localIdx]
            if (item && moduleIndex === 0) {
                if (value) {
                    item.protectionBits = item.protectionBits | (1 << bitIndex)
                    // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护触发时同时设置锁存位
                    item.latchedProtectionBits = item.latchedProtectionBits | (1 << bitIndex)
                } else {
                    // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护物理恢复时只清实时位，保留锁存位
                    item.protectionBits = item.protectionBits & ~(1 << bitIndex)
                }
                // ✅ 2026-03-27 [Phase 7.48.88.38]: 保护位变化时更新允许运行状态
                var hasFault = (typeof runtimeTracker !== "undefined" && runtimeTracker && runtimeTracker.isFault)
                item.allowRun = !hasFault && (item.protectionBits === 0)
            }
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.27]: 监听F键复位信号，清除所有卡片的锁存保护位
    Connections {
        target: typeof protectionLogicController !== "undefined" ? protectionLogicController : null
        enabled: target !== null
        ignoreUnknownSignals: true

        function onAllProtectionsReset() {
            console.log("[Screen01] 🔄 F键复位：清除所有卡片保护锁存状态")
            var dataItems = getDataItems()
            for (var i = 0; i < dataItems.length; i++) {
                if (dataItems[i]) {
                    dataItems[i].latchedProtectionBits = 0
                    // ✅ 2026-03-27 [Phase 7.48.88.38]: F键复位时更新允许运行
                    dataItems[i].allowRun = (dataItems[i].protectionBits === 0)
                }
            }
        }
    }

    // ✅ 2026-03-27 [Phase 7.48.88.38]: 监听故障状态变化，更新卡片故障详情和允许运行
    Connections {
        target: typeof runtimeTracker !== "undefined" ? runtimeTracker : null
        enabled: target !== null

        function onIsFaultChanged() {
            updateFaultDisplay()
        }

        function onFaultDevicesChanged() {
            updateFaultDisplay()
        }

        // ❌ 2026-03-28 [Phase 7.48.88.48]: 改用Timer轮询更新今日运行时间
        // 原因：onDailyRuntimeChanged信号方式在某些情况下不触发更新，Timer更可靠
        // ❌ 2026-03-29 [Phase 7.48.88.54]: 信号方式恢复，Timer作为备份
        // function onDailyRuntimeChanged() { ... }
    }

    // ✅ 2026-03-29 [Phase 7.48.88.55]: 运行时间+开机率更新函数
    function updateRuntimeDisplay() {
        if (typeof runtimeTracker === "undefined" || !runtimeTracker) return
        var dataItems = getDataItems()
        var localIdx = getLocalDeviceId() - 1
        if (localIdx >= 0 && localIdx < beltCardCount && dataItems[localIdx]) {
            var rt = runtimeTracker.dailyRuntime
            var ut = runtimeTracker.dailyUptime
            dataItems[localIdx].dailyRuntime = rt
            dataItems[localIdx].dailyUptime = ut
        }
    }

    // ✅ 2026-03-29 [Phase 7.48.88.54]: Connections 直接监听 runtimeTracker 信号
    // 原因：Phase 7.48.88.48 的 Timer 轮询方式在某些设备上不可靠
    Connections {
        target: (typeof runtimeTracker !== "undefined" && runtimeTracker) ? runtimeTracker : null

        function onDailyRuntimeChanged() {
            updateRuntimeDisplay()
        }

        function onDailyUptimeChanged() {
            updateRuntimeDisplay()
        }
    }

    // ✅ 2026-03-29 [Phase 7.48.88.54]: Timer 作为备份保障（每2秒轮询一次）
    // ❌ 2026-03-28 旧代码：每秒轮询，running条件有时不触发
    // 原因：双保险 - 如果 Connections 信号丢失，Timer 作为兜底
    Timer {
        interval: 2000
        repeat: true
        // ❌ 2026-03-29: 旧代码 running: typeof runtimeTracker !== "undefined" && runtimeTracker !== null
        // 修复：使用布尔属性绑定，避免 typeof 在 QML 中行为不一致
        running: true
        onTriggered: {
            updateRuntimeDisplay()
        }
    }

    // ✅ 2026-03-27 [Phase 7.48.88.39]: 更新故障显示到卡片（仅本机卡片）
    // 修复：故障/允许运行只应用于本机设备对应的卡片，而非所有8张卡片
    // 修复：faultDetail不显示皮带号（卡片本身已标识皮带）
    function updateFaultDisplay() {
        var dataItems = getDataItems()
        var localIdx = getLocalDeviceId() - 1
        var hasFault = (typeof runtimeTracker !== "undefined" && runtimeTracker && runtimeTracker.isFault)
        var faultList = hasFault ? runtimeTracker.faultDevices : []
        // ✅ 2026-03-27 [Phase 7.48.88.40]: 去掉"N号皮带 "前缀（卡片已标识皮带）
        // runtimeTracker.faultDevices 可能包含 "2号皮带 急停" 等格式
        var cleanList = []
        for (var fi = 0; fi < faultList.length; fi++) {
            var name = faultList[fi].replace(/^\d+号皮带\s*/, "")
            if (name !== "") cleanList.push(name)
        }
        var faultText = cleanList.length > 0 ? cleanList.join(" ") : ""

        for (var i = 0; i < beltCardCount; i++) {
            if (dataItems[i]) {
                if (i === localIdx) {
                    // 本机卡片：显示故障详情和允许运行状态
                    dataItems[i].faultDetail = faultText
                    dataItems[i].allowRun = !hasFault && (dataItems[i].protectionBits === 0)
                } else {
                    // 非本机卡片：不显示本机的故障信息
                    dataItems[i].faultDetail = ""
                    dataItems[i].allowRun = true  // 远程设备状态未知，默认允许
                }
            }
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.25]: 监听MQTT通讯状态
    // ✅ 2026-03-27 [Phase 7.48.88.39]: MQTT通讯状态只应用于本机卡片
    Connections {
        target: typeof mqttAutoManager !== "undefined" ? mqttAutoManager : null
        enabled: target !== null

        function onModuleStatusChanged(moduleIndex, status) {
            var dataItems = getDataItems()
            var localIdx = getLocalDeviceId() - 1
            var online = (status === "正常" || status === "已连接")
            // 旧代码：所有卡片都设置commOnline（本机MQTT状态不代表远程设备状态）
            if (localIdx >= 0 && localIdx < beltCardCount && dataItems[localIdx]) {
                dataItems[localIdx].commOnline = online
            }
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.26]: 监听电机保护实时数据（Modbus寄存器→工程量）
    // motorIndex 0-7 → 卡片 0-7（1号~8号皮带）
    // tabIndex: 1=电流, 2=前轴承温, 3=后轴承温, 4=电机温, 5=甲绕组温, 6=乙绕组温, 7=丙绕组温, 8=X振动, 9=Y振动
    Connections {
        target: typeof deviceRoleManager !== "undefined" ? deviceRoleManager : null
        enabled: target !== null

        function onLocalDeviceIdChanged() {
            refreshDeviceCards()
        }

        function onLocalDeviceNameChanged() {
            refreshDeviceCards()
        }
    }

    Connections {
        target: typeof deviceConfigMgr !== "undefined" ? deviceConfigMgr : null
        enabled: target !== null

        function onDeviceConfigChanged(deviceId) {
            if (deviceId >= 1 && deviceId <= beltCardCount) {
                refreshDeviceCards()
            }
        }
    }

    Connections {
        target: typeof systemConfig !== "undefined" ? systemConfig : null
        enabled: target !== null

        function onMachineNumberChanged() {
            refreshDeviceCards()
        }

        function onLocalDeviceNameChanged() {
            refreshDeviceCards()
        }
    }

    Connections {
        target: typeof mqttProtectionMonitor !== "undefined" ? mqttProtectionMonitor : null
        enabled: target !== null

        // ✅ 2026-03-27 [Phase 7.48.88.41]: 电机数据来自本机Modbus，只更新本机卡片
        // 旧代码：用motorIndex当卡片索引 dataItems[motorIndex]，导致数据写到错误卡片
        function onMotorValueUpdated(motorIndex, tabIndex, engineeringValue, unit, protectionName, exceeded) {
            if (motorIndex < 0 || motorIndex >= 8) return
            var dataItems = getDataItems()
            var localIdx = getLocalDeviceId() - 1
            if (localIdx < 0 || localIdx >= beltCardCount) return
            var item = dataItems[localIdx]
            if (!item) return

            // 根据tabIndex映射到卡片参数
            var valueStr = engineeringValue.toFixed(1)
            if (tabIndex === 1) {
                // 电流 → param2
                item.param2Value = valueStr
                item.param2Unit = unit
                item.param2Percent = clampPercent(engineeringValue / 100.0)
            } else if (tabIndex === 4) {
                // 电机温度 → param3
                item.param3Value = valueStr
                item.param3Unit = unit
                item.param3Percent = clampPercent(engineeringValue / 120.0)
            } else if (tabIndex === 2) {
                // 前轴承温度 → 暂时不显示（param3已被电机温度占用）
            }
        }

        // ✅ 2026-03-28 [Phase 7.48.88.49.4]: 洒水设备状态变化→更新卡片LED
        function onSprinklerStatusChanged(deviceName, active) {
            var dataItems = getDataItems()
            var localIdx = getLocalDeviceId() - 1
            if (localIdx < 0 || localIdx >= beltCardCount || !dataItems[localIdx]) return
            var oldStates = dataItems[localIdx].outputDeviceStates || {}
            var newStates = {}
            for (var key in oldStates) {
                newStates[key] = oldStates[key]
            }
            newStates[deviceName] = active
            dataItems[localIdx].outputDeviceStates = newStates
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.26.3]: 改用channelUpdatedMap信号（QVariantMap）
    // 原因：原channelChanged传递ChannelData结构体，QML无法解析导致后续更新不生效
    Connections {
        target: typeof aiDataManager !== "undefined" ? aiDataManager : null
        enabled: target !== null

        function onChannelUpdatedMap(moduleIndex, channelIndex, data) {
            if (!data || !data.valid) return
            applyAnalogChannelUpdate(moduleIndex, channelIndex, data)
        }
    }
}
