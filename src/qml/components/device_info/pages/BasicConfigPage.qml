import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15  // ✅ 2026-03-25 [Phase 7.48.88.16]: Screen.devicePixelRatio

// ✅ 2026-01-24 [设备信息界面重构] Phase 2: 基本配置页面
// 复用现有的 BasicParametersSection 和 NetworkParametersSection 组件
Rectangle {
    id: root
    // ✅ 2026-01-26 [FIX 100.300.25.12]: 明确设置尺寸，确保运行时正确显示
    implicitWidth: 800
    implicitHeight: 600
    color: "transparent"

    // ========== 公开属性 ==========
    property int deviceId: 1
    property string deviceName: ""

    // ✅ 2026-03-23 [Phase 7.48.84.2]: 初始化保护标志
    // 防止组件创建时ComboBox默认值触发onCurrentIndexChanged，覆盖已保存的配置
    property bool __initialized: false

    // ✅ 2026-02-06 [参数持久化]: 基本参数配置对象
    // 旧代码：machineNumber: 1, localDeviceName: "1号皮带" — 固定默认值不随deviceId变化
    // ✅ 2026-03-23 [Phase 7.48.84.3]: 默认值跟随deviceId，未保存配置时显示正确的编号和名称
    property var basicParams: ({
        machineNumber: root.deviceId,
        warningMode: 0,
        warningTimeSeconds: 10,
        warningPlayCount: 3,
        workMode: 0,
        localDeviceName: root.deviceId + "号皮带",
        speedSelection: 0,
        timeSettings: "",
        frontInterlock: 0,
        rearInterlock: 0,
        terminalType: 0,
        terminalEnabled: 0,
        // ✅ 2026-03-20 [Phase 7.48.60]: 皮带音频来源
        // ✅ 2026-03-21 [Phase 7.48.65]: 默认值改为1（TTS合成），原为0（默认预录音频）
        // 原因：用户期望系统默认使用TTS合成路径，而非pre-recorded默认音频
        beltAudioSource: 1
    })

    // ✅ 2026-02-06 [参数持久化]: 网络参数配置对象
    property var networkParams: ({
        ipAddress: "192.168.1.100",
        subnetMask: "255.255.255.0",
        gateway: "192.168.1.1"
    })

    // ========== 内容区域 ==========
    // 旧代码：ScrollView { ... }
    // ✅ 2026-03-25 [Phase 7.48.88.16]: 改为 Flickable，支持虚拟键盘弹出时自动滚动
    Flickable {
        id: scrollView
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 40
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        // ✅ 2026-03-25 [Phase 7.48.88.16]: 虚拟键盘弹出时自动滚动输入框到可见区域
        // 旧代码：用 Flickable 高度减键盘高度计算可见区域 → 滚动量过大
        // 旧代码：mapToGlobal + devicePixelRatio → 坐标系不一致
        // ✅ 2026-03-25 [Phase 7.48.88.16.2]: 使用 mapToItem(null) 获取窗口坐标，直接比较
        function ensureVisible(item) {
            if (!item) return

            // 1. 获取虚拟键盘信息（窗口坐标）
            var keyboardRect = Qt.inputMethod.keyboardRectangle
            if (keyboardRect.height <= 0) return  // 键盘未弹出

            // keyboardRect 是窗口坐标（像素），在嵌入式设备上 devicePixelRatio 通常为1
            var keyboardTopY = keyboardRect.y

            // 2. 获取输入框在窗口中的坐标
            // mapToItem(null) = 映射到窗口根坐标，比 mapToGlobal 更可靠
            var itemInWindow = item.mapToItem(null, 0, 0)
            var itemBottomY = itemInWindow.y + item.height

            // 调试日志
            console.log("📐 [ensureVisible] 输入框窗口Y:", itemInWindow.y,
                        "底部:", itemBottomY,
                        "键盘顶部:", keyboardTopY,
                        "键盘高度:", keyboardRect.height,
                        "当前contentY:", scrollView.contentY,
                        "候选词补偿:", 50)

            // 3. 计算被遮挡距离
            // ✅ 2026-03-25 [Phase 7.48.88.16.3]: 中文拼音输入法有候选词栏，额外增加高度补偿
            // Qt.inputMethod.keyboardRectangle 可能不包含候选词栏高度
            var candidateBarHeight = 50  // 中文候选词栏高度补偿
            var margin = 8  // 输入框与键盘之间预留间距
            var overlap = itemBottomY + margin + candidateBarHeight - keyboardTopY

            // 4. 被遮挡时：向上滚动 overlap 距离
            if (overlap > 0) {
                var targetY = scrollView.contentY + overlap
                targetY = Math.min(targetY, scrollView.contentHeight - scrollView.height)
                targetY = Math.max(0, targetY)
                console.log("📐 [ensureVisible] 需滚动:", overlap, "→ targetY:", targetY)
                scrollAnim.to = targetY
                scrollAnim.start()
            } else {
                console.log("📐 [ensureVisible] 无需滚动，overlap:", overlap)
            }
        }

        // 平滑滚动动画
        NumberAnimation on contentY {
            id: scrollAnim
            duration: 300
            easing.type: Easing.OutCubic
            running: false
        }

        ColumnLayout {
            id: contentColumn
            width: scrollView.width
            spacing: 20

            // 页面标题
            Text {
                text: "基本配置 - " + root.deviceName
                font.pixelSize: 22
                font.bold: true
                color: "#00d4ff"
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.leftMargin: 10
            }

            // ✅ 2026-02-10 [Phase 7.45.2]: 本机角色配置区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                color: "#1a1f2e"
                border.width: 2
                border.color: "#00d4ff"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    // 标题
                    Text {
                        text: "【本机角色配置】"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"
                    }

                    // 本机角色选择
                    RowLayout {
                        spacing: 15

                        Text {
                            text: "本机角色:"
                            font.pixelSize: 16
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                            Layout.preferredWidth: 100
                        }

                        ComboBox {
                            id: stationRoleSelector
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 40

                            // 旧代码：model: ["主站", "分站"]
                            // 旧代码：currentIndex: 0  // 默认主站
                            // ✅ 2026-03-23 [Phase 7.48.84]: 添加独立控制模式，默认独立控制
                            model: ["独立控制", "主站", "分站"]
                            currentIndex: 0  // 默认独立控制

                            onCurrentIndexChanged: {
                                // 旧代码：无初始化保护，组件创建时默认值会覆盖已保存配置
                                // ✅ 2026-03-23 [Phase 7.48.84.2]: 添加初始化保护
                                if (root.__initialized && typeof deviceRoleManager !== 'undefined') {
                                    // 旧代码：deviceRoleManager.setStationRole(currentIndex === 0 ? "master" : "sub")
                                    // ✅ 2026-03-23 [Phase 7.48.84]: 映射三种角色
                                    var roles = ["standalone", "master", "sub"]
                                    deviceRoleManager.setStationRole(roles[currentIndex])
                                }
                            }

                            // 科技风格样式
                            delegate: ItemDelegate {
                                width: stationRoleSelector.width
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? "#00ff00" : "#00d4ff"
                                    font.pixelSize: 16
                                    font.family: "Microsoft YaHei"
                                    verticalAlignment: Text.AlignVCenter
                                }
                                highlighted: stationRoleSelector.highlightedIndex === index
                                background: Rectangle {
                                    color: highlighted ? "#2a3f5f" : "#0a0f1e"
                                }
                            }
                        }
                    }

                    // 本机设备选择
                    RowLayout {
                        spacing: 15

                        Text {
                            text: "本机设备:"
                            font.pixelSize: 16
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                            Layout.preferredWidth: 100
                        }

                        ComboBox {
                            id: localDeviceSelector
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 40

                            model: [
                                "1号皮带", "2号皮带", "3号皮带", "4号皮带",
                                "5号皮带", "6号皮带", "7号皮带", "8号皮带"
                            ]
                            currentIndex: 0  // 默认1号皮带

                            onCurrentIndexChanged: {
                                // 旧代码：无初始化保护，组件创建时默认值(0)覆盖已保存的localDeviceId
                                // ✅ 2026-03-23 [Phase 7.48.84.2]: 添加初始化保护
                                if (root.__initialized && currentIndex >= 0 && typeof deviceRoleManager !== 'undefined') {
                                    deviceRoleManager.setLocalDeviceId(currentIndex + 1)
                                }
                            }

                            // 科技风格样式
                            delegate: ItemDelegate {
                                width: localDeviceSelector.width
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? "#00ff00" : "#00d4ff"
                                    font.pixelSize: 16
                                    font.family: "Microsoft YaHei"
                                    verticalAlignment: Text.AlignVCenter
                                }
                                highlighted: localDeviceSelector.highlightedIndex === index
                                background: Rectangle {
                                    color: highlighted ? "#2a3f5f" : "#0a0f1e"
                                }
                            }
                        }
                    }

                    // 说明文字
                    // 旧代码：text: "💡 说明: 选择本机角色和控制的设备后，只能修改本机设备的参数"
                    // ✅ 2026-03-23 [Phase 7.48.84]: 更新说明文字
                    Text {
                        text: "💡 说明: 独立控制/主站模式可修改所有设备参数，分站模式只能修改本机设备参数"
                        font.pixelSize: 14
                        font.family: "Microsoft YaHei"
                        color: "#5a6f8f"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // ✅ 复用基本参数组件
            Loader {
                id: basicParamsLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 400
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                // ❌ 2026-03-20 [Phase 7.48.60]: QRC绝对路径在QDS预览中Loader静默失败
                // source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/BasicParametersSection.qml"
                // ✅ 2026-03-20 [Phase 7.48.60]: 改用相对路径，QDS和部署环境均可解析
                source: "../../parameter_settings/BasicParametersSection.qml"

                onLoaded: {
                    console.log("✅ [BasicConfigPage] BasicParametersSection 加载成功")
                    // ✅ 2026-02-06 [参数持久化]: 传递配置对象
                    if (item) {
                        item.systemConfig = Qt.binding(function() { return root.basicParams })
                        // ✅ 2026-03-25 [Phase 7.48.88.16]: 传递 Flickable 引用，支持虚拟键盘自动滚动
                        item.flickableParent = scrollView
                    }
                }

                onStatusChanged: {
                    if (basicParamsLoader.status === Loader.Error) {
                        console.error("❌ [BasicConfigPage] BasicParametersSection 加载失败")
                    }
                }
            }

            // ✅ 复用网络参数组件
            Loader {
                id: networkParamsLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                // ❌ 2026-03-20 [Phase 7.48.60]: 同上，QRC绝对路径在QDS预览中失败
                // source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/NetworkParametersSection.qml"
                // ✅ 2026-03-20 [Phase 7.48.60]: 改用相对路径
                source: "../../parameter_settings/NetworkParametersSection.qml"

                onLoaded: {
                    console.log("✅ [BasicConfigPage] NetworkParametersSection 加载成功")
                    // ✅ 2026-02-06 [参数持久化]: 传递配置对象
                    if (item) {
                        item.networkConfig = Qt.binding(function() { return root.networkParams })
                        // ✅ 2026-03-25 [Phase 7.48.88.16.3]: 传递 Flickable 引用，网络参数也支持自动滚动
                        item.flickableParent = scrollView
                    }
                }

                onStatusChanged: {
                    if (networkParamsLoader.status === Loader.Error) {
                        console.error("❌ [BasicConfigPage] NetworkParametersSection 加载失败")
                    }
                }
            }

            // 底部填充空间
            // ✅ 2026-03-25 [Phase 7.48.88.16]: 增加底部填充到350px，确保最后的输入框可以滚动到虚拟键盘上方
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 350
            }
        }
    }

    // ========== 参数保存和加载函数 ==========
    // ✅ 2026-02-06 [参数持久化]: 保存基本参数配置
    function saveBasicParams() {
        console.log("✅ [BasicConfigPage] 开始保存基本参数配置 - 设备ID:", root.deviceId)

        var success = true

        // 保存基本参数（12个参数）
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "machineNumber", basicParams.machineNumber)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "warningMode", basicParams.warningMode)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "warningTimeSeconds", basicParams.warningTimeSeconds)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "warningPlayCount", basicParams.warningPlayCount)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "workMode", basicParams.workMode)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "localDeviceName", basicParams.localDeviceName)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "speedSelection", basicParams.speedSelection)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "timeSettings", basicParams.timeSettings)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "frontInterlock", basicParams.frontInterlock)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "rearInterlock", basicParams.rearInterlock)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "terminalType", basicParams.terminalType)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "terminalEnabled", basicParams.terminalEnabled)
        // ✅ 2026-03-20 [Phase 7.48.60]: 保存皮带音频来源（SQLite + C++ systemConfig + config.ini）
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "beltAudioSource", basicParams.beltAudioSource)
        if (typeof systemConfig !== "undefined" && systemConfig !== null && typeof systemConfig.setBeltAudioSource === "function") {
            // systemConfig 在此处为全局 C++ context property（BasicConfigPage无同名局部属性）
            systemConfig.beltAudioSource = basicParams.beltAudioSource
            systemConfig.saveConfig()
        }

        if (success) {
            console.log("✅ [BasicConfigPage] 基本参数保存成功")
        } else {
            console.error("❌ [BasicConfigPage] 基本参数保存失败")
        }

        return success
    }

    // ✅ 2026-02-06 [参数持久化]: 保存网络参数配置
    function saveNetworkParams() {
        console.log("✅ [BasicConfigPage] 开始保存网络参数配置 - 设备ID:", root.deviceId)

        var success = true

        // 保存网络参数（3个参数）
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "ipAddress", networkParams.ipAddress)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "subnetMask", networkParams.subnetMask)
        success = success && deviceConfigMgr.saveBasicConfig(root.deviceId, "gateway", networkParams.gateway)

        if (success) {
            console.log("✅ [BasicConfigPage] 网络参数保存成功")
        } else {
            console.error("❌ [BasicConfigPage] 网络参数保存失败")
        }

        return success
    }

    // ✅ 2026-02-06 [参数持久化]: 保存所有配置
    function saveAllConfig() {
        console.log("✅ [BasicConfigPage] 开始保存所有配置 - 设备ID:", root.deviceId)

        var basicSuccess = saveBasicParams()
        var networkSuccess = saveNetworkParams()

        if (basicSuccess && networkSuccess) {
            console.log("✅ [BasicConfigPage] 所有配置保存成功")
            return true
        } else {
            console.error("❌ [BasicConfigPage] 配置保存失败")
            return false
        }
    }

    // ✅ 2026-02-06 [参数持久化]: 加载基本参数配置
    function loadBasicParams() {
        console.log("✅ [BasicConfigPage] 开始加载基本参数配置 - 设备ID:", root.deviceId)

        var config = deviceConfigMgr.loadAllBasicConfig(root.deviceId)

        if (!config || Object.keys(config).length === 0) {
            console.log("⚠️ [BasicConfigPage] 没有找到基本参数配置，使用默认值")
            // ✅ 2026-03-20 [Phase 7.48.62]: SQLite无记录时，从C++ systemConfig读取运行时值作为fallback
            // 原因：systemConfig（config.ini）可能已保存用户配置，但SQLite尚未写入时UI会显示默认值0
            if (typeof systemConfig !== "undefined" && systemConfig !== null) {
                // ✅ 2026-03-21 [Phase 7.48.65]: fallback 默认值改为1（TTS），原为 || 0
                basicParams.beltAudioSource = systemConfig.beltAudioSource !== undefined ? systemConfig.beltAudioSource : 1
                console.log("📋 [BasicConfigPage] fallback beltAudioSource from systemConfig:", basicParams.beltAudioSource)
            }
            return false
        }

        // 应用基本参数配置（12个参数）
        if (config.hasOwnProperty("machineNumber")) {
            basicParams.machineNumber = config["machineNumber"]
        }
        if (config.hasOwnProperty("warningMode")) {
            basicParams.warningMode = config["warningMode"]
        }
        if (config.hasOwnProperty("warningTimeSeconds")) {
            basicParams.warningTimeSeconds = config["warningTimeSeconds"]
        }
        if (config.hasOwnProperty("warningPlayCount")) {
            basicParams.warningPlayCount = config["warningPlayCount"]
        }
        if (config.hasOwnProperty("workMode")) {
            basicParams.workMode = config["workMode"]
        }
        if (config.hasOwnProperty("localDeviceName")) {
            basicParams.localDeviceName = config["localDeviceName"]
        }
        if (config.hasOwnProperty("speedSelection")) {
            basicParams.speedSelection = config["speedSelection"]
        }
        if (config.hasOwnProperty("timeSettings")) {
            basicParams.timeSettings = config["timeSettings"]
        }
        if (config.hasOwnProperty("frontInterlock")) {
            basicParams.frontInterlock = config["frontInterlock"]
        }
        if (config.hasOwnProperty("rearInterlock")) {
            basicParams.rearInterlock = config["rearInterlock"]
        }
        if (config.hasOwnProperty("terminalType")) {
            basicParams.terminalType = config["terminalType"]
        }
        if (config.hasOwnProperty("terminalEnabled")) {
            basicParams.terminalEnabled = config["terminalEnabled"]
        }
        // ✅ 2026-03-20 [Phase 7.48.60]: 加载皮带音频来源
        if (config.hasOwnProperty("beltAudioSource")) {
            basicParams.beltAudioSource = config["beltAudioSource"]
            // 同步到 C++ systemConfig（全局 context property）
            if (typeof systemConfig !== "undefined" && systemConfig !== null) {
                systemConfig.beltAudioSource = config["beltAudioSource"]
            }
        }

        console.log("✅ [BasicConfigPage] 基本参数加载成功")
        return true
    }

    // ✅ 2026-02-06 [参数持久化]: 加载网络参数配置
    function loadNetworkParams() {
        console.log("✅ [BasicConfigPage] 开始加载网络参数配置 - 设备ID:", root.deviceId)

        var config = deviceConfigMgr.loadAllBasicConfig(root.deviceId)

        if (!config || Object.keys(config).length === 0) {
            console.log("⚠️ [BasicConfigPage] 没有找到网络参数配置，使用默认值")
            return false
        }

        // 应用网络参数配置（3个参数）
        if (config.hasOwnProperty("ipAddress")) {
            networkParams.ipAddress = config["ipAddress"]
        }
        if (config.hasOwnProperty("subnetMask")) {
            networkParams.subnetMask = config["subnetMask"]
        }
        if (config.hasOwnProperty("gateway")) {
            networkParams.gateway = config["gateway"]
        }

        console.log("✅ [BasicConfigPage] 网络参数加载成功")
        return true
    }

    // ✅ 2026-02-06 [参数持久化]: 加载所有配置
    function loadAllConfig() {
        console.log("✅ [BasicConfigPage] 开始加载所有配置 - 设备ID:", root.deviceId)

        var basicSuccess = loadBasicParams()
        var networkSuccess = loadNetworkParams()

        if (basicSuccess || networkSuccess) {
            console.log("✅ [BasicConfigPage] 配置加载成功")
            return true
        } else {
            console.log("⚠️ [BasicConfigPage] 没有找到配置，使用默认值")
            return false
        }
    }

    // ✅ 2026-02-06 [参数持久化]: 组件初始化时加载配置
    Component.onCompleted: {
        console.log("✅ [BasicConfigPage] 组件初始化 - 设备ID:", root.deviceId)
        loadAllConfig()

        // ✅ 2026-03-23 [Phase 7.48.84]: 回显本机角色下拉框
        if (typeof deviceRoleManager !== 'undefined') {
            var roleMap = {"standalone": 0, "master": 1, "sub": 2}
            var idx = roleMap[deviceRoleManager.stationRole]
            if (idx !== undefined) {
                stationRoleSelector.currentIndex = idx
            }

            // ✅ 2026-03-23 [Phase 7.48.84.2]: 回显本机设备下拉框
            // 旧代码：未回显，每次打开弹窗都默认显示1号皮带，并触发onCurrentIndexChanged重置配置
            localDeviceSelector.currentIndex = deviceRoleManager.localDeviceId - 1
        }

        // ✅ 2026-03-23 [Phase 7.48.84.2]: 初始化完成后才允许ComboBox的onChange生效
        root.__initialized = true
    }

    // ✅ 2026-02-06 [参数持久化]: 设备ID变化时重新加载配置
    onDeviceIdChanged: {
        console.log("✅ [BasicConfigPage] 设备ID变化 - 新设备ID:", root.deviceId)
        // ✅ 2026-03-23 [Phase 7.48.84.3]: 先更新默认值，再加载数据库配置
        // 如果数据库无记录，至少显示正确的编号和名称
        basicParams.machineNumber = root.deviceId
        basicParams.localDeviceName = root.deviceId + "号皮带"
        loadAllConfig()
    }
}
