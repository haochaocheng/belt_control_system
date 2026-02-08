// MQTTConfigPanel.qml
// MQTT 配置面板（包含 Tab）
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现
// ✅ 2026-02-08 [Phase 7.43.5]: 重构布局，参照 TCPConfigPanel.qml

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentModule: null
    property int focusSubArea: 0
    property int focusTabIndex: -1
    property int focusParamIndex: -1
    property var virtualKeyboard: null

    // ========== Tab 管理 ==========
    property int currentTabIndex: 0

    // ========== 信号 ==========
    signal requestFocusParamIndex(int paramIndex)

    // ========== 函数 ==========
    function getCurrentTab() {
        return getCurrentTabItem()
    }

    function getCurrentTabItem() {
        switch(currentTabIndex) {
        case 0:
            return connectionTabLoader.item
        case 1:
            return subscribeTabLoader.item
        case 2:
            return publishTabLoader.item
        case 3:
            return monitorTabLoader.item
        default:
            return null
        }
    }

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "transparent"

        Image {
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch
            z: -1
        }

        Text {
            anchors.centerIn: parent
            text: "MQTT 配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== Tab栏 ==========
    Rectangle {
        id: tabBar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#252b3d"
        border.color: "#3d4556"
        border.width: 1

        Row {
            id: tabRow
            spacing: 0
            height: parent.height
            width: childrenRect.width

            Repeater {
                model: ["连接配置", "订阅主题", "发布消息", "数据监控"]

                Rectangle {
                    width: 110
                    height: 50
                    color: "transparent"

                    // 焦点指示器
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: (root.focusSubArea === 1 && root.focusTabIndex === index)
                                      ? "#2196F3" : "transparent"
                        border.width: (root.focusSubArea === 1 && root.focusTabIndex === index) ? 3 : 0
                        radius: 4
                        z: 11
                    }

                    // 背景图片
                    Image {
                        anchors.fill: parent
                        fillMode: Image.Stretch
                        z: -1
                        source: root.currentTabIndex === index
                                ? "../images/DJHeadbutton2.png"
                                : "../images/DJHeadbutton1.png"
                    }

                    // 底部激活指示条
                    Rectangle {
                        visible: root.currentTabIndex === index
                        width: parent.width
                        height: 3
                        color: "#2196F3"
                        anchors.bottom: parent.bottom
                    }

                    Text {
                        text: modelData
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        font.pixelSize: 13
                        font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
                        color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("✅ [MQTTConfigPanel] 切换到 Tab:", index)
                            root.currentTabIndex = index
                        }
                    }
                }
            }
        }
    }

    // ========== 内容区域 ==========
    Rectangle {
        id: contentArea
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        StackLayout {
            anchors.fill: parent
            currentIndex: root.currentTabIndex

            // Tab 0: 连接配置
            Loader {
                id: connectionTabLoader
                source: "MQTTConnectionTab.qml"

                onLoaded: {
                    console.log("✅ [MQTTConfigPanel] MQTTConnectionTab 加载成功")
                    item.currentModule = Qt.binding(function() { return root.currentModule })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        root.requestFocusParamIndex(paramIndex)
                    })
                }
            }

            // Tab 1: 订阅主题
            Loader {
                id: subscribeTabLoader
                source: "MQTTSubscribeTab.qml"

                onLoaded: {
                    console.log("✅ [MQTTConfigPanel] MQTTSubscribeTab 加载成功")
                    item.currentModule = Qt.binding(function() { return root.currentModule })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        root.requestFocusParamIndex(paramIndex)
                    })
                }
            }

            // Tab 2: 发布消息
            Loader {
                id: publishTabLoader
                source: "MQTTPublishTab.qml"

                onLoaded: {
                    console.log("✅ [MQTTConfigPanel] MQTTPublishTab 加载成功")
                    item.currentModule = Qt.binding(function() { return root.currentModule })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        root.requestFocusParamIndex(paramIndex)
                    })
                }
            }

            // Tab 3: 数据监控
            Loader {
                id: monitorTabLoader
                source: "MQTTMonitorTab.qml"

                onLoaded: {
                    console.log("✅ [MQTTConfigPanel] MQTTMonitorTab 加载成功")
                    item.currentModule = Qt.binding(function() { return root.currentModule })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.requestFocusParamIndex.connect(function(paramIndex) {
                        root.requestFocusParamIndex(paramIndex)
                    })
                }
            }
        }
    }
}
