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
    // ✅ 2026-04-09: 修复状态文字硬编码问题——改为读取后端实际状态
    Rectangle {
        id: connectionStatusBar
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: "#1a2033"
        border.color: "#3d4556"
        border.width: 1

        // 定时刷新的状态缓存属性
        property bool portRunning: false
        property string portStatus: "未配置"
        // ✅ 2026-04-10: 用于区分全部监听/部分监听/全部停止
        property bool allListening: false

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
                // ✅ 2026-04-10: 绿=全部监听, 橙=部分监听, 灰=全部停止
                color: connectionStatusBar.allListening ? "#4CAF50" :
                       connectionStatusBar.portRunning ? "#FF9800" : "#757575"
            }

            // 连接状态文字
            Text {
                id: statusText
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13
                // ✅ 2026-04-10: 同步指示灯颜色
                color: connectionStatusBar.allListening ? "#4CAF50" :
                       connectionStatusBar.portRunning ? "#FF9800" : "#9E9E9E"
                text: connectionStatusBar.portStatus
            }

            // 右侧：端口信息
            Item {
                width: parent.width - statusDot.width - statusText.width - 36
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
            // 旧: onTriggered: refreshStatus()  // 2026-04-10: Timer作用域无法直接访问父级函数
            onTriggered: connectionStatusBar.refreshStatus()
        }

        // 端口切换或Tab切换时也刷新
        Connections {
            target: root
            function onCurrentPortIndexChanged() { connectionStatusBar.refreshStatus() }
            function onCurrentTabIndexChanged() { connectionStatusBar.refreshStatus() }
        }

        // 旧: Component.onCompleted: refreshStatus()  // 2026-04-10: 需要通过id访问
        Component.onCompleted: connectionStatusBar.refreshStatus()

        function refreshStatus() {
            if (typeof tcpDataAdapter === "undefined") {
                portRunning = false
                allListening = false
                portStatus = "未配置"
                return
            }

            portRunning = tcpDataAdapter.isPortRunning(root.currentPortIndex)
            portStatus = tcpDataAdapter.getPortStatusText(root.currentPortIndex)
            // ✅ 2026-04-10: 检查状态文字中是否含有"已停止"来判断是否全部监听
            allListening = portRunning && portStatus.indexOf("已停止") < 0

            if (!portRunning) return

            // 追加Tab类型说明
            var tabNames = ["Modbus主站", "Modbus从站", "S7主站", "S7从站"]
            var tabName = tabNames[root.currentTabIndex] || ""
            portStatus = tabName + " · " + portStatus
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
