// MQTTAutoControlTab.qml
// MQTT 自动控制界面 - 显示8个模块的实时数据
// 创建日期: 2026-02-09
// ✅ 2026-02-09 [Phase 7.44.7]: MQTT自动控制界面实现

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property int focusParamIndex: 0
    property bool keysEnabled: true

    // ========== 信号 ==========
    signal requestReturnToCategory()

    // ========== 布局 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // 标题栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#2C3E50"
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20

                Text {
                    text: "MQTT 自动控制"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"
                }

                Item { Layout.fillWidth: true }

                // 自动连接开关
                Row {
                    spacing: 10
                    Text {
                        text: "自动连接:"
                        font.pixelSize: 16
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
                        font.pixelSize: 16
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

                // 启动/停止按钮
                Button {
                    text: "启动"
                    font.pixelSize: 16
                    onClicked: {
                        if (mqttAutoManager) {
                            mqttAutoManager.start()
                        }
                    }
                }

                Button {
                    text: "停止"
                    font.pixelSize: 16
                    onClicked: {
                        if (mqttAutoManager) {
                            mqttAutoManager.stop()
                        }
                    }
                }
            }
        }

        // 主内容区域
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 20

                // 开关量模块（模块1和模块2）
                GroupBox {
                    Layout.fillWidth: true
                    title: "开关量输入模块"
                    font.pixelSize: 18
                    font.bold: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 15

                        // 模块1
                        DIModulePanel {
                            Layout.fillWidth: true
                            moduleIndex: 0
                            moduleName: "开关量输入1"
                            bitsData: diDataManager ? diDataManager.module1Data : []
                        }

                        // 模块2
                        DIModulePanel {
                            Layout.fillWidth: true
                            moduleIndex: 1
                            moduleName: "开关量输入2"
                            bitsData: diDataManager ? diDataManager.module2Data : []
                        }
                    }
                }

                // 模拟量模块（模块3和模块4）
                GroupBox {
                    Layout.fillWidth: true
                    title: "模拟量输入模块"
                    font.pixelSize: 18
                    font.bold: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 15

                        // 模块3
                        AIModulePanel {
                            Layout.fillWidth: true
                            moduleIndex: 2
                            moduleName: "模拟量输入1"
                            channelsData: aiDataManager ? aiDataManager.module3Data : []
                        }

                        // 模块4
                        AIModulePanel {
                            Layout.fillWidth: true
                            moduleIndex: 3
                            moduleName: "模拟量输入2"
                            channelsData: aiDataManager ? aiDataManager.module4Data : []
                        }
                    }
                }

                // 健康状态监控
                GroupBox {
                    Layout.fillWidth: true
                    title: "模块健康状态"
                    font.pixelSize: 18
                    font.bold: true

                    GridLayout {
                        anchors.fill: parent
                        columns: 4
                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: mqttAutoManager ? mqttAutoManager.healthStatus : []

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 80
                                color: modelData.connected ? "#27AE60" : "#E74C3C"
                                radius: 8
                                border.width: 2
                                border.color: modelData.connected ? "#229954" : "#C0392B"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 5

                                    Text {
                                        text: "模块 " + (modelData.moduleIndex + 1)
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: modelData.status
                                        font.pixelSize: 14
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: "重连: " + modelData.reconnectCount + "次"
                                        font.pixelSize: 12
                                        color: "white"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
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

    Component.onCompleted: {
        console.log("✅ [MQTTAutoControlTab] 初始化完成")
    }
}
