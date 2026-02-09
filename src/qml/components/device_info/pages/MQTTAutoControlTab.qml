// MQTTAutoControlTab.qml
// MQTT 自动控制界面 - 根据当前模块显示对应数据
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.7]: MQTT自动控制界面实现
// ✅ 2026-02-09 [Phase 7.44.8]: 重新设计 - 根据模块类型显示不同内容

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: 0
    property bool keysEnabled: true
    property var currentModule: null  // 当前选中的模块
    property int currentModuleIndex: 0  // 当前模块索引 (0-7)

    // ========== 信号 ==========
    signal requestReturnToCategory()

    // ========== 辅助函数 ==========
    // 获取模块类型
    function getModuleType() {
        if (currentModuleIndex < 0 || currentModuleIndex >= 8) {
            return "unknown"
        }

        // 模块类型映射
        // 模块1-2: 开关量输入 (DI)
        // 模块3-4: 模拟量输入 (AI)
        // 模块5-6: CS (沿线急停+通讯)
        // 模块7: 语音模块 (Voice)
        // 模块8: 预留 (Reserved)

        if (currentModuleIndex < 2) {
            return "di"  // 开关量
        } else if (currentModuleIndex < 4) {
            return "ai"  // 模拟量
        } else if (currentModuleIndex < 6) {
            return "cs"  // CS模块
        } else if (currentModuleIndex === 6) {
            return "voice"  // 语音模块
        } else {
            return "reserved"  // 预留
        }
    }

    // 获取模块名称
    function getModuleName() {
        var names = [
            "开关量输入1",
            "开关量输入2",
            "模拟量输入1",
            "模拟量输入2",
            "CS1",
            "CS2",
            "语音模块",
            "预留模块"
        ]
        if (currentModuleIndex >= 0 && currentModuleIndex < names.length) {
            return names[currentModuleIndex]
        }
        return "未知模块"
    }

    // 获取连接状态
    function getConnectionStatus() {
        if (!mqttAutoManager || !mqttAutoManager.healthStatus) {
            return false
        }
        var healthStatus = mqttAutoManager.healthStatus
        if (currentModuleIndex >= 0 && currentModuleIndex < healthStatus.length) {
            return healthStatus[currentModuleIndex].connected
        }
        return false
    }

    // 获取健康状态
    function getHealthStatus() {
        if (!mqttAutoManager || !mqttAutoManager.healthStatus) {
            return { status: "未知", reconnectCount: 0 }
        }
        var healthStatus = mqttAutoManager.healthStatus
        if (currentModuleIndex >= 0 && currentModuleIndex < healthStatus.length) {
            return healthStatus[currentModuleIndex]
        }
        return { status: "未知", reconnectCount: 0 }
    }

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // 标题栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#2C3E50"
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // 第一行：模块信息
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    Text {
                        text: "模块 " + (currentModuleIndex + 1) + ": " + getModuleName()
                        font.pixelSize: 24
                        font.bold: true
                        color: "white"
                    }

                    // 连接状态指示
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: getConnectionStatus() ? "#27AE60" : "#E74C3C"

                        SequentialAnimation on opacity {
                            running: getConnectionStatus()
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                        }
                    }

                    Text {
                        text: getConnectionStatus() ? "已连接" : "未连接"
                        font.pixelSize: 18
                        color: getConnectionStatus() ? "#27AE60" : "#E74C3C"
                    }

                    Item { Layout.fillWidth: true }

                    // 健康状态
                    Text {
                        text: "状态: " + getHealthStatus().status
                        font.pixelSize: 16
                        color: "white"
                    }

                    Text {
                        text: "重连: " + getHealthStatus().reconnectCount + "次"
                        font.pixelSize: 16
                        color: "white"
                    }
                }

                // 第二行：控制按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 15

                    // 自动连接开关
                    Row {
                        spacing: 10
                        Text {
                            text: "自动连接:"
                            font.pixelSize: 14
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Switch {
                            id: autoConnectSwitch
                            checked: mqttAutoManager ? mqttAutoManager.autoConnectEnabled : true
                            onToggled: {
                                if (mqttAutoManager) {
                                    mqttAutoManager.autoConnectEnabled = checked
                                }
                            }
                        }
                    }

                    // 数据采集开关
                    Row {
                        spacing: 10
                        Text {
                            text: "数据采集:"
                            font.pixelSize: 14
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Switch {
                            id: pollingSwitch
                            checked: mqttAutoManager ? mqttAutoManager.pollingEnabled : true
                            onToggled: {
                                if (mqttAutoManager) {
                                    mqttAutoManager.pollingEnabled = checked
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // 手动重连按钮
                    Button {
                        text: "重新连接"
                        font.pixelSize: 14
                        onClicked: {
                            if (mqttAutoManager) {
                                mqttAutoManager.reconnectModule(currentModuleIndex)
                            }
                        }
                    }

                    // 启动/停止按钮
                    Button {
                        text: "启动全部"
                        font.pixelSize: 14
                        onClicked: {
                            if (mqttAutoManager) {
                                mqttAutoManager.start()
                            }
                        }
                    }

                    Button {
                        text: "停止全部"
                        font.pixelSize: 14
                        onClicked: {
                            if (mqttAutoManager) {
                                mqttAutoManager.stop()
                            }
                        }
                    }
                }
            }
        }

        // 主内容区域 - 根据模块类型显示不同内容
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StackLayout {
                width: parent.width
                currentIndex: {
                    var type = getModuleType()
                    if (type === "di") return 0
                    if (type === "ai") return 1
                    if (type === "cs") return 2
                    if (type === "voice") return 3
                    return 4  // reserved
                }

                // 开关量显示 (模块1-2)
                DIModulePanel {
                    Layout.fillWidth: true
                    moduleIndex: currentModuleIndex
                    moduleName: getModuleName()
                    bitsData: {
                        if (!diDataManager) return []
                        if (currentModuleIndex === 0) {
                            return diDataManager.module1Data
                        } else if (currentModuleIndex === 1) {
                            return diDataManager.module2Data
                        }
                        return []
                    }
                }

                // 模拟量显示 (模块3-4)
                AIModulePanel {
                    Layout.fillWidth: true
                    moduleIndex: currentModuleIndex
                    moduleName: getModuleName()
                    channelsData: {
                        if (!aiDataManager) return []
                        if (currentModuleIndex === 2) {
                            return aiDataManager.module3Data
                        } else if (currentModuleIndex === 3) {
                            return aiDataManager.module4Data
                        }
                        return []
                    }
                }

                // CS模块显示 (模块5-6)
                CSModulePanel {
                    Layout.fillWidth: true
                    moduleIndex: currentModuleIndex
                    moduleName: getModuleName()
                }

                // 语音模块显示 (模块7)
                VoiceModulePanel {
                    Layout.fillWidth: true
                    moduleIndex: currentModuleIndex
                    moduleName: getModuleName()
                }

                // 预留模块显示 (模块8)
                ReservedModulePanel {
                    Layout.fillWidth: true
                    moduleIndex: currentModuleIndex
                    moduleName: getModuleName()
                }
            }
        }
    }

    // ========== 键盘导航 ==========
    Keys.onPressed: {
        if (!keysEnabled) return

        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            requestReturnToCategory()
            event.accepted = true
        }
    }

    // ========== 监听模块切换 ==========
    onCurrentModuleIndexChanged: {
        console.log("✅ [MQTTAutoControlTab] 切换到模块:", currentModuleIndex, getModuleName())
    }

    Component.onCompleted: {
        console.log("✅ [MQTTAutoControlTab] 初始化完成")
    }
}
