// SerialPortListPanel.qml
// 串口列表面板
// 创建日期: 2026-02-04

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
    property var serialPorts: []            // 串口列表
    property int currentSerialIndex: 0      // 当前选中的串口索引 (0-5)
    property int focusItemIndex: -1         // 导航焦点索引
    property int focusSubArea: 0            // 焦点子区域

    // ========== 信号 ==========
    signal serialPortSelected(int index)    // 串口被选中时发出信号

    // ========== 标题 ==========
    Rectangle {
        id: header
        width: parent.width
        height: 60
        color: "#2c3e50"
        anchors.top: parent.top

        Text {
            text: "串口列表"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "#E0E0E0"
            anchors.centerIn: parent
        }
    }

    // ========== 串口列表 ==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0

        model: root.serialPorts.length
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
                // 使用相对路径，便于QDS预览（向上三级到qml目录）
                source: "../../../images/bhNameBK.png"

                states: [
                    State {
                        name: "selected"
                        when: root.currentSerialIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentSerialIndex !== index
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
                visible: root.currentSerialIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ========== 串口名称居中显示 ==========
            Text {
                text: root.serialPorts[index] ? root.serialPorts[index].name : ""
                font.pixelSize: 16
                font.weight: root.currentSerialIndex === index ? Font.Bold : Font.Normal
                color: root.currentSerialIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
            }

            // ========== 鼠标点击 ==========
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("🔍 [SerialPortListPanel] 鼠标点击串口:", index)
                    // ✅ 2026-02-04: 发射信号，由父组件处理
                    root.serialPortSelected(index)
                }
            }
        }
    }
}
