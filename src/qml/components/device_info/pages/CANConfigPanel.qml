// CANConfigPanel.qml
// CAN 配置面板（包含 Tab）
// 创建日期: 2026-02-07

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1a1f2e"

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

    // ========== 主布局 ==========
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ========== Tab 栏 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#252d3d"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Tab 按钮：参数配置
                Button {
                    id: paramsTabButton
                    text: "参数配置"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35

                    background: Rectangle {
                        color: {
                            if (root.currentTabIndex === 0 && root.focusSubArea === 1 && root.focusTabIndex === 0) {
                                return "#2196F3"  // 选中且焦点：蓝色
                            } else if (root.currentTabIndex === 0) {
                                return "#34495e"  // 选中但无焦点：深灰色
                            } else if (parent.hovered) {
                                return "#2c3e50"  // 悬停：中灰色
                            } else {
                                return "#1e2838"  // 默认：暗灰色
                            }
                        }
                        radius: 4
                        border.width: (root.focusSubArea === 1 && root.focusTabIndex === 0) ? 3 : 0
                        border.color: "#00d4ff"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        font.bold: root.currentTabIndex === 0
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("✅ [CANConfigPanel] 切换到参数配置 Tab")
                        root.currentTabIndex = 0
                    }
                }

                // Tab 按钮：发送区
                Button {
                    id: sendTabButton
                    text: "发送区"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35

                    background: Rectangle {
                        color: {
                            if (root.currentTabIndex === 1 && root.focusSubArea === 1 && root.focusTabIndex === 1) {
                                return "#2196F3"
                            } else if (root.currentTabIndex === 1) {
                                return "#34495e"
                            } else if (parent.hovered) {
                                return "#2c3e50"
                            } else {
                                return "#1e2838"
                            }
                        }
                        radius: 4
                        border.width: (root.focusSubArea === 1 && root.focusTabIndex === 1) ? 3 : 0
                        border.color: "#00d4ff"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        font.bold: root.currentTabIndex === 1
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("✅ [CANConfigPanel] 切换到发送区 Tab")
                        root.currentTabIndex = 1
                    }
                }

                // Tab 按钮：接收区
                Button {
                    id: receiveTabButton
                    text: "接收区"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35

                    background: Rectangle {
                        color: {
                            if (root.currentTabIndex === 2 && root.focusSubArea === 1 && root.focusTabIndex === 2) {
                                return "#2196F3"
                            } else if (root.currentTabIndex === 2) {
                                return "#34495e"
                            } else if (parent.hovered) {
                                return "#2c3e50"
                            } else {
                                return "#1e2838"
                            }
                        }
                        radius: 4
                        border.width: (root.focusSubArea === 1 && root.focusTabIndex === 2) ? 3 : 0
                        border.color: "#00d4ff"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        font.bold: root.currentTabIndex === 2
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("✅ [CANConfigPanel] 切换到接收区 Tab")
                        root.currentTabIndex = 2
                    }
                }
            }

            // 底部分隔线
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                color: "#3d4556"
            }
        }

        // ========== Tab 内容区域 ==========
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
