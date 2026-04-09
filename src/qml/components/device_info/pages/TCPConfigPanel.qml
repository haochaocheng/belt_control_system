// TCPConfigPanel.qml
// TCP 配置面板（包含 Tab）
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentPort: null
    property int currentPortIndex: 0  // ✅ 2026-04-07 [Phase 7.48.88.84]: 端口索引传递
    property int focusSubArea: 0
    property int focusTabIndex: -1
    property int focusParamIndex: 0
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
            return modbusMasterTabLoader.item
        case 1:
            return modbusSlaveTabLoader.item
        case 2:
            return s7MasterTabLoader.item
        case 3:
            return s7SlaveTabLoader.item
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
            text: "TCP 配置"
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
                model: ["Modbus主站", "Modbus从站", "S7主站", "S7从站"]

                Rectangle {
                    // 旧：width: 110  // 2026-04-09 问题4：Tab按钮宽度增加1.3倍
                    width: 143
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

                    // ✅ 2026-04-09: 问题3+4修复——文字居中显示，避免S7文字被背景图片遮挡
                    Text {
                        text: modelData
                        anchors.centerIn: parent
                        font.pixelSize: 14
                        font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
                        color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("✅ [TCPConfigPanel] 切换到 Tab:", index)
                            root.currentTabIndex = index
                        }
                    }
                }
            }
        }
    }

    // ========== 连接状态栏 ==========
    // ✅ 2026-04-09: 问题1修复——添加端口连接状态显示，区分主站/从站
    Rectangle {
        id: connectionStatusBar
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: "#1a2033"
        border.color: "#3d4556"
        border.width: 1

        Row {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 12

            // 运行状态指示灯
            Rectangle {
                id: statusDot
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (typeof tcpDataAdapter !== "undefined" && tcpDataAdapter.isPortRunning(root.currentPortIndex)) {
                        return "#4CAF50"  // 绿色 = 运行中
                    }
                    return "#757575"  // 灰色 = 未启动
                }
            }

            // 连接状态文字
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13
                color: {
                    if (typeof tcpDataAdapter !== "undefined" && tcpDataAdapter.isPortRunning(root.currentPortIndex)) {
                        return "#4CAF50"
                    }
                    return "#9E9E9E"
                }
                text: {
                    var isRunning = (typeof tcpDataAdapter !== "undefined" && tcpDataAdapter.isPortRunning(root.currentPortIndex))
                    if (!isRunning) return "未启动"

                    switch(root.currentTabIndex) {
                    case 0:  // Modbus主站
                        return "Modbus主站 · 运行中 · 轮询目标设备"
                    case 1:  // Modbus从站
                        return "Modbus从站 · 监听中 · 等待外部设备连接"
                    case 2:  // S7主站
                        return "S7主站 · 运行中 · 连接目标PLC"
                    case 3:  // S7从站
                        return "S7从站 · 监听中 · 等待PLC连接"
                    default:
                        return "运行中"
                    }
                }
            }

            // 右侧：端口信息
            Item {
                Layout.fillWidth: true
                width: parent.width - statusDot.width - 300
                height: parent.height

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 12
                    color: "#757575"
                    text: "端口 " + (root.currentPortIndex + 1) + " · Port " + (502 + root.currentPortIndex)
                }
            }
        }

        // 定时刷新状态（每2秒）
        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: {
                // 触发重新评估绑定
                statusDot.color = Qt.binding(function() {
                    if (typeof tcpDataAdapter !== "undefined" && tcpDataAdapter.isPortRunning(root.currentPortIndex)) {
                        return "#4CAF50"
                    }
                    return "#757575"
                })
            }
        }
    }

    // ========== 内容区域 ==========
    Rectangle {
        id: contentArea
        anchors.top: connectionStatusBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        StackLayout {
            anchors.fill: parent
            currentIndex: root.currentTabIndex

            // Tab 0: Modbus主站
            Loader {
                id: modbusMasterTabLoader
                source: "ModbusTCPMasterTab.qml"

                onLoaded: {
                    console.log("✅ [TCPConfigPanel] ModbusTCPMasterTab 加载成功")
                    item.currentPort = Qt.binding(function() { return root.currentPort })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })  // ✅ 2026-04-08 [Phase 7.48.88.92]
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.portIndex = Qt.binding(function() { return root.currentPortIndex })  // ✅ 2026-04-07 [Phase 7.48.88.85]
                }
            }

            // Tab 1: Modbus从站
            Loader {
                id: modbusSlaveTabLoader
                source: "ModbusTCPSlaveTab.qml"

                onLoaded: {
                    console.log("✅ [TCPConfigPanel] ModbusTCPSlaveTab 加载成功")
                    item.currentPort = Qt.binding(function() { return root.currentPort })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })  // ✅ 2026-04-08 [Phase 7.48.88.92]
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.portIndex = Qt.binding(function() { return root.currentPortIndex })  // ✅ 2026-04-07 [Phase 7.48.88.84]
                }
            }

            // Tab 2: S7主站
            Loader {
                id: s7MasterTabLoader
                source: "S7MasterTab.qml"

                onLoaded: {
                    console.log("✅ [TCPConfigPanel] S7MasterTab 加载成功")
                    item.currentPort = Qt.binding(function() { return root.currentPort })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })  // ✅ 2026-04-08 [Phase 7.48.88.92]
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.portIndex = Qt.binding(function() { return root.currentPortIndex })  // ✅ 2026-04-07 [Phase 7.48.88.85]
                }
            }

            // Tab 3: S7从站
            Loader {
                id: s7SlaveTabLoader
                source: "S7SlaveTab.qml"

                onLoaded: {
                    console.log("✅ [TCPConfigPanel] S7SlaveTab 加载成功")
                    item.currentPort = Qt.binding(function() { return root.currentPort })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.focusSubArea = Qt.binding(function() { return root.focusSubArea })  // ✅ 2026-04-08 [Phase 7.48.88.92]
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.portIndex = Qt.binding(function() { return root.currentPortIndex })  // ✅ 2026-04-07 [Phase 7.48.88.84]
                }
            }
        }
    }
}
