import QtQuick 2.15

// ✅ 2026-03-09 [洒水控制-左侧面板] 洒水列表面板
// 显示洒水1-洒水8列表
// 设计风格与电机列表、制动器列表、张紧控制列表完全一样
Rectangle {
    id: root
    color: "transparent"
    clip: true

    // 整体背景图片
    Image {
        anchors.fill: parent
        source: "../images/33.png"
        fillMode: Image.Stretch
        z: -1
    }

    // ========== 公开属性 ==========
    property int currentSprinklerIndex: 0  // 当前选中的洒水索引 (0-7)
    property int focusItemIndex: -1  // -1 表示无焦点
    property int focusSubArea: 0  // 0:列表区域 1:参数区域 2:按钮区域

    // ========== 信号 ==========
    signal sprinklerSelected(int sprinklerIndex)

    // ========== 键盘导航支持 ==========
    focus: true

    Keys.onUpPressed: {
        if (root.currentSprinklerIndex > 0) {
            sprinklerSelected(root.currentSprinklerIndex - 1)
        }
    }

    Keys.onDownPressed: {
        if (root.currentSprinklerIndex < 7) {
            sprinklerSelected(root.currentSprinklerIndex + 1)
        }
    }

    // ========== 标题 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        Text {
            anchors.centerIn: parent
            text: "洒水列表"
            font.pixelSize: 16
            anchors.verticalCenterOffset: -6
            anchors.horizontalCenterOffset: -16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 洒水列表 ==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0
        clip: true

        model: ListModel {
            ListElement { name: "洒水1"; status: "待配置" }
            ListElement { name: "洒水2"; status: "待配置" }
            ListElement { name: "洒水3"; status: "待配置" }
            ListElement { name: "洒水4"; status: "待配置" }
            ListElement { name: "洒水5"; status: "待配置" }
            ListElement { name: "洒水6"; status: "待配置" }
            ListElement { name: "洒水7"; status: "待配置" }
            ListElement { name: "洒水8"; status: "待配置" }
        }
        currentIndex: root.currentSprinklerIndex

        delegate: Rectangle {
            width: listView.width
            height: 45
            color: "transparent"
            border.color: "transparent"
            border.width: 0

            // 焦点指示器（仅在列表区域时显示）
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: (root.focusSubArea === 0 && root.focusItemIndex === index) ? "#2196F3" : "transparent"
                border.width: (root.focusSubArea === 0 && root.focusItemIndex === index) ? 3 : 0
                radius: 4
                z: 10
            }

            // 背景图片
            Image {
                id: backgroundImage
                anchors.fill: parent
                fillMode: Image.Stretch
                z: -1
                source: "../../../images/bhNameBK.png"

                states: [
                    State {
                        name: "selected"
                        when: root.currentSprinklerIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentSprinklerIndex !== index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK.png"
                        }
                    }
                ]
            }

            // 左侧激活指示条
            Rectangle {
                visible: root.currentSprinklerIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // 洒水名称居中显示
            Text {
                text: model.name
                font.pixelSize: 14
                font.weight: root.currentSprinklerIndex === index ? Font.Bold : Font.Normal
                color: root.currentSprinklerIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
            }

            // 状态指示
            Row {
                spacing: 8
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#95a5a6"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: model.status
                    font.pixelSize: 12
                    color: "#9E9E9E"
                }
            }

            // 鼠标点击
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.sprinklerSelected(index)
                    root.focus = true
                }
            }
        }
    }

    // 加载洒水配置状态（从数据库读取启用状态更新列表显示）
    function updateSprinklerStatus() {
        if (typeof deviceConfigMgr === "undefined") return
        var configs = deviceConfigMgr.loadAllSprinklerConfigs()
        for (var i = 0; i < configs.length && i < listView.model.count; i++) {
            var config = configs[i]
            var statusText = config.enabled ? "已启用" : "已禁用"
            listView.model.setProperty(i, "status", statusText)
        }
    }

    Component.onCompleted: {
        updateSprinklerStatus()
    }
}
