// MQTTListPanel.qml
// MQTT 模块列表面板
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.43]: MQTT通讯控制功能实现

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    // ========== 背景图片 ==========
    Image {
        anchors.fill: parent
        source: "../images/33.png"
        fillMode: Image.Stretch
        z: -1
    }

    // ========== 公开属性 ==========
    property var mqttModules: []
    property int currentModuleIndex: 0
    property int focusItemIndex: -1
    property int focusSubArea: 0

    // ========== 信号 ==========
    signal moduleSelected(int index)

    // ========== 标题 ==========
    Rectangle {
        id: header
        width: parent.width
        height: 60
        color: "#2c3e50"
        anchors.top: parent.top

        Text {
            text: "模块列表"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    // ========== 模块列表 ==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0

        model: 8  // 固定 8 个模块
        spacing: 0
        clip: true

        delegate: Rectangle {
            width: listView.width
            height: 50
            color: "transparent"

            // ========== 背景图片 ==========
            Image {
                id: backgroundImage
                anchors.fill: parent
                source: "../../../images/bhNameBK.png"

                states: [
                    State {
                        name: "selected"
                        when: root.currentModuleIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentModuleIndex !== index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK.png"
                        }
                    }
                ]
            }

            // ========== 蓝色边框（焦点指示器）==========
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: (root.focusSubArea === 0 && root.focusItemIndex === index) ? "#2196F3" : "transparent"
                border.width: (root.focusSubArea === 0 && root.focusItemIndex === index) ? 3 : 0
            }

            // ========== 左侧激活指示条 ==========
            Rectangle {
                visible: root.currentModuleIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ========== 连接状态指示器 ==========
            Rectangle {
                id: statusIndicator
                width: 10
                height: 10
                radius: 5
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    var module = root.mqttModules[index]
                    if (module && module.connected) {
                        return "#4CAF50"  // 绿色 - 已连接
                    }
                    return "#9E9E9E"  // 灰色 - 未连接
                }
            }

            // ========== 模块名称和状态显示 ==========
            Column {
                anchors.centerIn: parent
                spacing: 2

                // 模块名称
                Text {
                    text: "模块" + (index + 1)
                    font.pixelSize: 14
                    font.weight: root.currentModuleIndex === index ? Font.Bold : Font.Normal
                    color: root.currentModuleIndex === index ? "#E0E0E0" : "#9E9E9E"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 连接状态
                Text {
                    text: {
                        var module = root.mqttModules[index]
                        if (module) {
                            return module.connectionState || "未连接"
                        }
                        return "未连接"
                    }
                    font.pixelSize: 11
                    color: root.currentModuleIndex === index ? "#B0B0B0" : "#707070"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // ========== 鼠标点击 ==========
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("🔍 [MQTTListPanel] 鼠标点击模块:", index)
                    root.moduleSelected(index)
                }
            }
        }
    }
}
