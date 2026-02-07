// CANListPanel.qml
// CAN 列表面板
// 创建日期: 2026-02-07
// ✅ 2026-02-07 [修复]: 使用与串口列表一致的样式

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
        z: -1  // 放在最底层
    }

    // ========== 公开属性 ==========
    property var canInterfaces: []
    property int currentCanIndex: 0
    property int focusItemIndex: -1
    property int focusSubArea: 0

    // ========== 信号 ==========
    signal canInterfaceSelected(int index)

    // ========== 标题 ==========
    Rectangle {
        id: header
        width: parent.width
        height: 60
        color: "#2c3e50"
        anchors.top: parent.top

        Text {
            text: "CAN 接口"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    // ========== CAN 列表 ==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0

        model: root.canInterfaces.length
        spacing: 0
        clip: true

        delegate: Rectangle {
            width: listView.width
            height: 60
            color: "transparent"

            // ========== 背景图片 ==========
            Image {
                id: backgroundImage
                anchors.fill: parent
                source: "../../../images/bhNameBK.png"

                states: [
                    State {
                        name: "selected"
                        when: root.currentCanIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentCanIndex !== index
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
                visible: root.currentCanIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ========== CAN 名称和设备路径显示 ==========
            // ✅ 2026-02-07 [Phase 7.39.13]: 添加设备路径显示
            Column {
                anchors.centerIn: parent
                spacing: 4

                // CAN 名称
                Text {
                    text: root.canInterfaces[index] ? root.canInterfaces[index].name : ""
                    font.pixelSize: 16
                    font.weight: root.currentCanIndex === index ? Font.Bold : Font.Normal
                    color: root.currentCanIndex === index ? "#E0E0E0" : "#9E9E9E"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 设备路径（简化显示）
                Text {
                    text: {
                        if (!root.canInterfaces[index] || !root.canInterfaces[index].devicePath) {
                            return ""
                        }
                        var fullPath = root.canInterfaces[index].devicePath
                        // 提取最后一部分：fea50000.can
                        var parts = fullPath.split("/")
                        for (var i = parts.length - 1; i >= 0; i--) {
                            if (parts[i].indexOf(".can") !== -1) {
                                return parts[i]
                            }
                        }
                        return fullPath
                    }
                    font.pixelSize: 12
                    color: root.currentCanIndex === index ? "#B0B0B0" : "#707070"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // ========== 鼠标点击 ==========
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("🔍 [CANListPanel] 鼠标点击 CAN:", index)
                    root.canInterfaceSelected(index)
                }
            }
        }
    }
}
