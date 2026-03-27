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

    function applyAnalogChannelUpdate(moduleIndex, channelIndex, data) {
        var dataItems = getDataItems()

        for (var cardIndex = 0; cardIndex < beltCardCount; cardIndex++) {
            var item = dataItems[cardIndex]
            var mappingGroup = beltSensorMappings[cardIndex]
            if (!item || !mappingGroup) continue

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
    }

    function refreshMappedAnalogValues() {
        if (typeof aiDataManager === "undefined" || !aiDataManager) return

        for (var cardIndex = 0; cardIndex < beltCardCount; cardIndex++) {
            var mappingGroup = beltSensorMappings[cardIndex]
            if (!mappingGroup) continue

            if (mappingGroup.speed) {
                var speedData = aiDataManager.getChannel(mappingGroup.speed.moduleIndex, mappingGroup.speed.channelIndex)
                applyAnalogChannelUpdate(mappingGroup.speed.moduleIndex, mappingGroup.speed.channelIndex, speedData)
            }

            if (mappingGroup.tension) {
                var tensionData = aiDataManager.getChannel(mappingGroup.tension.moduleIndex, mappingGroup.tension.channelIndex)
                applyAnalogChannelUpdate(mappingGroup.tension.moduleIndex, mappingGroup.tension.channelIndex, tensionData)
            }
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
            } else if (phase === "起车预警" || phase === "停车预警") {
                item.deviceStatus = phase
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
        }

        function onBeltRunningChanged(beltNumber, running) {
            var idx = beltNumber - 1
            if (idx < 0 || idx >= 12) return
            var dataItems = getDataItems()
            var item = dataItems[idx]
            if (!item) return
            item.deviceStatus = running ? "运行" : "停止"
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
    Connections {
        target: typeof diDataManager !== "undefined" ? diDataManager : null
        enabled: target !== null

        function onBitChanged(moduleIndex, bitIndex, value) {
            // DI模块0对应1号皮带的保护，DI模块1对应2号皮带的保护（简化映射）
            // 实际映射需要根据保护配置来确定，这里先用模块索引
            if (moduleIndex < 0 || moduleIndex >= 2) return
            var dataItems = getDataItems()
            // 暂时将DI模块0映射给所有皮带卡片（后续可按保护配置精确映射）
            for (var i = 0; i < 8; i++) {
                var item = dataItems[i]
                if (item && moduleIndex === 0) {
                    if (value) {
                        item.protectionBits = item.protectionBits | (1 << bitIndex)
                        // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护触发时同时设置锁存位
                        item.latchedProtectionBits = item.latchedProtectionBits | (1 << bitIndex)
                    } else {
                        // ✅ 2026-03-26 [Phase 7.48.88.27]: 保护物理恢复时只清实时位，保留锁存位
                        // 锁存位仅在F键复位时清除
                        item.protectionBits = item.protectionBits & ~(1 << bitIndex)
                    }
                }
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
                }
            }
        }
    }

    // ✅ 2026-03-26 [Phase 7.48.88.25]: 监听MQTT通讯状态
    Connections {
        target: typeof mqttAutoManager !== "undefined" ? mqttAutoManager : null
        enabled: target !== null

        function onModuleStatusChanged(moduleIndex, status) {
            // 只要有任一模块在线，卡片就显示在线
            var dataItems = getDataItems()
            var online = (status === "正常" || status === "已连接")
            for (var i = 0; i < dataItems.length; i++) {
                if (dataItems[i]) {
                    dataItems[i].commOnline = online
                }
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

        function onMotorValueUpdated(motorIndex, tabIndex, engineeringValue, unit, protectionName, exceeded) {
            if (motorIndex < 0 || motorIndex >= 8) return
            var dataItems = getDataItems()
            var item = dataItems[motorIndex]
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
