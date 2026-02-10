import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

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

    // ✅ 2026-02-06 [参数持久化]: 基本参数配置对象
    property var basicParams: ({
        machineNumber: 1,
        warningMode: 0,
        warningTimeSeconds: 10,
        warningPlayCount: 3,
        workMode: 0,
        localDeviceName: "1号皮带",
        speedSelection: 0,
        timeSettings: "",
        frontInterlock: 0,
        rearInterlock: 0,
        terminalType: 0,
        terminalEnabled: 0
    })

    // ✅ 2026-02-06 [参数持久化]: 网络参数配置对象
    property var networkParams: ({
        ipAddress: "192.168.1.100",
        subnetMask: "255.255.255.0",
        gateway: "192.168.1.1"
    })

    // ========== 内容区域 ==========
    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        // 滚动条样式
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
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

                            model: ["主站", "分站"]
                            currentIndex: 0  // 默认主站

                            onCurrentIndexChanged: {
                                if (typeof deviceRoleManager !== 'undefined') {
                                    deviceRoleManager.setStationRole(
                                        currentIndex === 0 ? "master" : "sub"
                                    )
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
                                if (currentIndex >= 0 && typeof deviceRoleManager !== 'undefined') {
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
                    Text {
                        text: "💡 说明: 选择本机角色和控制的设备后，只能修改本机设备的参数"
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

                source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/BasicParametersSection.qml"

                onLoaded: {
                    console.log("✅ [BasicConfigPage] BasicParametersSection 加载成功")
                    // ✅ 2026-02-06 [参数持久化]: 传递配置对象
                    if (item) {
                        item.systemConfig = Qt.binding(function() { return root.basicParams })
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

                source: "qrc:/qt/qml/BeltControlQml/components/parameter_settings/NetworkParametersSection.qml"

                onLoaded: {
                    console.log("✅ [BasicConfigPage] NetworkParametersSection 加载成功")
                    // ✅ 2026-02-06 [参数持久化]: 传递配置对象
                    if (item) {
                        item.networkConfig = Qt.binding(function() { return root.networkParams })
                    }
                }

                onStatusChanged: {
                    if (networkParamsLoader.status === Loader.Error) {
                        console.error("❌ [BasicConfigPage] NetworkParametersSection 加载失败")
                    }
                }
            }

            // 底部填充空间
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 20
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
    }

    // ✅ 2026-02-06 [参数持久化]: 设备ID变化时重新加载配置
    onDeviceIdChanged: {
        console.log("✅ [BasicConfigPage] 设备ID变化 - 新设备ID:", root.deviceId)
        loadAllConfig()
    }
}
