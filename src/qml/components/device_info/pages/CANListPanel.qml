// CANListPanel.qml
// CAN 列表面板
// 创建日期: 2026-02-07

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1a1f2e"

    // ========== 公开属性 ==========
    property var canInterfaces: []
    property int currentCanIndex: 0
    property int focusItemIndex: -1
    property int focusSubArea: 0

    // ========== 信号 ==========
    signal canInterfaceSelected(int index)

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#252d3d"

        Text {
            anchors.centerIn: parent
            text: "CAN 接口"
            font.pixelSize: 16
            font.bold: true
            color: "#00d4ff"
        }

        // 底部分隔线
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: "#3d4556"
        }
    }

    // ========== CAN 列表 ==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 8
        clip: true

        model: root.canInterfaces

        delegate: Rectangle {
            width: listView.width
            height: 60
            radius: 6

            // 背景色：选中、焦点、悬停、默认
            color: {
                if (index === root.currentCanIndex && root.focusSubArea === 0 && index === root.focusItemIndex) {
                    return "#2196F3"  // 选中且焦点：蓝色
                } else if (index === root.currentCanIndex) {
                    return "#34495e"  // 选中但无焦点：深灰色
                } else if (mouseArea.containsMouse) {
                    return "#2c3e50"  // 悬停：中灰色
                } else {
                    return "#1e2838"  // 默认：暗灰色
                }
            }

            // 边框：焦点时显示
            border.width: (root.focusSubArea === 0 && index === root.focusItemIndex) ? 3 : 0
            border.color: "#00d4ff"

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    console.log("✅ [CANListPanel] 点击 CAN:", index)
                    root.canInterfaceSelected(index)
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                // CAN 名称
                Text {
                    text: modelData.name
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                    Layout.fillWidth: true
                }

                // CAN 接口路径
                Text {
                    text: modelData.path
                    font.pixelSize: 12
                    color: "#95a5a6"
                    Layout.fillWidth: true
                }

                // 波特率
                Text {
                    text: "波特率: " + modelData.bitrate
                    font.pixelSize: 11
                    color: "#7f8c8d"
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ========== 空状态提示 ==========
    Text {
        anchors.centerIn: parent
        text: "无 CAN 接口"
        font.pixelSize: 14
        color: "#7f8c8d"
        visible: root.canInterfaces.length === 0
    }
}
