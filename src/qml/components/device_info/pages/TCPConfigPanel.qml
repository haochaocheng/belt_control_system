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
                            console.log("✅ [TCPConfigPanel] 切换到 Tab:", index)
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

            // Tab 0: Modbus主站
            Loader {
                id: modbusMasterTabLoader
                source: "ModbusTCPMasterTab.qml"

                onLoaded: {
                    console.log("✅ [TCPConfigPanel] ModbusTCPMasterTab 加载成功")
                    item.currentPort = Qt.binding(function() { return root.currentPort })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
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
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
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
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                    item.portIndex = Qt.binding(function() { return root.currentPortIndex })  // ✅ 2026-04-07 [Phase 7.48.88.84]
                }
            }
        }
    }
}
