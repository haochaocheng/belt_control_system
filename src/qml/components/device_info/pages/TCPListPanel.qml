// TCPListPanel.qml
// TCP 端口列表面板
// 创建日期: 2026-02-08
// ✅ 2026-02-08 [Phase 7.42]: TCP控制功能实现

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
    property var tcpPorts: []
    property int currentPortIndex: 0
    property int focusItemIndex: -1
    property int focusSubArea: 0

    // ========== 信号 ==========
    signal portSelected(int index)

    // ========== 标题 ==========
    Rectangle {
        id: header
        width: parent.width
        height: 60
        color: "#2c3e50"
        anchors.top: parent.top

        Text {
            text: "端口列表"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    // ========== 端口列表 ==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0

        model: root.tcpPorts.length
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
                        when: root.currentPortIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentPortIndex !== index
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
                visible: root.currentPortIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ========== 端口名称和端口号显示 ==========
            Column {
                anchors.centerIn: parent
                spacing: 2

                // 端口名称
                Text {
                    text: root.tcpPorts[index] ? root.tcpPorts[index].name : ""
                    font.pixelSize: 14
                    font.weight: root.currentPortIndex === index ? Font.Bold : Font.Normal
                    color: root.currentPortIndex === index ? "#E0E0E0" : "#9E9E9E"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 端口号
                Text {
                    text: root.tcpPorts[index] ? "Port: " + root.tcpPorts[index].port : ""
                    font.pixelSize: 11
                    color: root.currentPortIndex === index ? "#B0B0B0" : "#707070"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // ========== 鼠标点击 ==========
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("🔍 [TCPListPanel] 鼠标点击端口:", index)
                    root.portSelected(index)
                }
            }
        }
    }
}
