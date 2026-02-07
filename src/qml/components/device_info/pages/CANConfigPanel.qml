// CANConfigPanel.qml
// CAN 配置面板（包含 Tab）
// 创建日期: 2026-02-07
// ✅ 2026-02-07 [修复]: 使用与串口控制一致的Tab样式

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 公开属性 ==========
    property var currentCanInterface: null
    property int focusSubArea: 0
    property int focusTabIndex: -1
    property int focusParamIndex: 0
    property var virtualKeyboard: null

    // ========== Tab 管理 ==========
    property int currentTabIndex: 0

    // ========== 信号 ==========
    signal requestFocusParamIndex(int paramIndex)

    // ========== 函数 ==========
    // 获取当前 Tab 的引用
    function getCurrentTab() {
        return getCurrentTabItem()
    }

    function getCurrentTabItem() {
        switch(currentTabIndex) {
        case 0:
            return paramsTabLoader.item
        case 1:
            return sendTabLoader.item
        case 2:
            return receiveTabLoader.item
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

        // 背景图片
        Image {
            anchors.fill: parent
            source: "../images/059.png"
            fillMode: Image.Stretch
            z: -1
        }

        Text {
            anchors.centerIn: parent
            text: "CAN 配置"
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
                model: ["参数配置", "发送区", "接收区"]

                Rectangle {
                    width: 120
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
                        anchors.leftMargin: 45
                        font.pixelSize: 14
                        font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
                        color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("✅ [CANConfigPanel] 切换到 Tab:", index)
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

            // Tab 0: 参数配置
            Loader {
                id: paramsTabLoader
                source: "CANParamsTab.qml"

                onLoaded: {
                    console.log("✅ [CANConfigPanel] CANParamsTab 加载成功")
                    item.currentCanInterface = Qt.binding(function() { return root.currentCanInterface })
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                }
            }

            // Tab 1: 发送区
            Loader {
                id: sendTabLoader
                source: "CANSendTab.qml"

                onLoaded: {
                    console.log("✅ [CANConfigPanel] CANSendTab 加载成功")
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                    item.virtualKeyboard = Qt.binding(function() { return root.virtualKeyboard })
                }
            }

            // Tab 2: 接收区
            Loader {
                id: receiveTabLoader
                source: "CANReceiveTab.qml"

                onLoaded: {
                    console.log("✅ [CANConfigPanel] CANReceiveTab 加载成功")
                    item.focusParamIndex = Qt.binding(function() { return root.focusParamIndex })
                }
            }
        }
    }
}
