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

    // ✅ 2026-03-30 [Phase 7.48.88.75]: 洒水状态数组（从父组件传入）
    // 每个元素: { enabled: bool, outputChannel: int }
    property var sprinklerStatusList: []

    // ✅ 2026-03-30 [Phase 7.48.88.75]: 洒水运行状态数组
    property var sprinklerRunningStates: [false,false,false,false,false,false,false,false]

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
            ListElement { name: "洒水1" }
            ListElement { name: "洒水2" }
            ListElement { name: "洒水3" }
            ListElement { name: "洒水4" }
            ListElement { name: "洒水5" }
            ListElement { name: "洒水6" }
            ListElement { name: "洒水7" }
            ListElement { name: "洒水8" }
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

            // 洒水名称（居中偏左，给右侧状态留空间）
            Text {
                text: model.name
                font.pixelSize: 14
                font.weight: root.currentSprinklerIndex === index ? Font.Bold : Font.Normal
                color: root.currentSprinklerIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -12
            }

            // ✅ 2026-03-30 [Phase 7.48.88.75]: 动态状态指示（参照 BrakeListPanel）
            // 旧代码: 硬编码 model.status "待配置"
            Row {
                spacing: 4
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: sprinklerStatusLed
                    width: 8
                    height: 8
                    radius: 4
                    property bool isRunning: index < root.sprinklerRunningStates.length ? root.sprinklerRunningStates[index] : false
                    color: {
                        if (sprinklerStatusLed.isRunning) return "#00E676"  // 亮绿：运行中
                        if (index < root.sprinklerStatusList.length) {
                            var status = root.sprinklerStatusList[index]
                            if (status && status.outputChannel >= 0 && status.enabled) return "#4CAF50"  // 绿色：已停止（启用）
                            if (status && status.outputChannel >= 0 && !status.enabled) return "#FF5722"  // 红色：禁用
                        }
                        return "#555555"  // 暗灰：未配置
                    }
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: sprinklerStatusLed.isRunning
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    }
                    onIsRunningChanged: if (!isRunning) opacity = 1.0
                }

                Text {
                    text: {
                        if (index < root.sprinklerRunningStates.length && root.sprinklerRunningStates[index]) return "运行中"
                        if (index < root.sprinklerStatusList.length) {
                            var status = root.sprinklerStatusList[index]
                            if (status && status.outputChannel >= 0 && status.enabled) return "已停止"
                            if (status && status.outputChannel >= 0 && !status.enabled) return "禁用"
                        }
                        return "未配置"
                    }
                    font.pixelSize: 11
                    color: (index < root.sprinklerRunningStates.length && root.sprinklerRunningStates[index]) ? "#00E676" : "#9E9E9E"
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

    // 旧代码: updateSprinklerStatus() 和 Component.onCompleted 已移至 SprinklerControlPage
    // ✅ 2026-03-30 [Phase 7.48.88.75]: 状态由父组件 SprinklerControlPage 通过 sprinklerStatusList 传入
}
