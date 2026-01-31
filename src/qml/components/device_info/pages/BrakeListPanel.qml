import QtQuick 2.15

// ✅ 2026-01-27 [制动器控制-左侧面板] 制动器列表面板
// 设计风格与电机列表完全一样
Rectangle {
    id: root
    // ✅ 改为透明，使用 33.png 作为整体背景
    color: "transparent"
    // ✅ 添加 clip 防止背景色超出弹窗底部
    clip: true

    // ✅ 添加整体背景图片 33.png
    Image {
        anchors.fill: parent
        source: "../images/33.png"
        fillMode: Image.Stretch
        z: -1  // 放在最底层
    }

    // ========== 公开属性 ==========
    property int currentBrakeIndex: 0  // 当前选中的制动器索引 (0-7)
    // ✅ 2026-01-31 [FIX 100.300.112.1]: 导航焦点索引（从父页面传递）
    property int focusItemIndex: -1  // -1 表示无焦点

    // ========== 信号 ==========
    signal brakeSelected(int brakeIndex)  // 制动器被选中时发出信号

    // ========== 键盘导航支持 ==========
    focus: true

    Keys.onUpPressed: {
        if (root.currentBrakeIndex > 0) {
            root.currentBrakeIndex--
            brakeSelected(root.currentBrakeIndex)
        }
    }

    Keys.onDownPressed: {
        if (root.currentBrakeIndex < 7) {
            root.currentBrakeIndex++
            brakeSelected(root.currentBrakeIndex)
        }
    }

    // ========== 标题 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        // ✅ 改为透明，显示背景图片
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        Text {
            anchors.centerIn: parent
            text: "制动器列表"
            font.pixelSize: 16
            anchors.verticalCenterOffset: -6
            anchors.horizontalCenterOffset: -16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 制动器列表（使用ListView，QDS支持）==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0
        clip: true

        model: 8  // 8个制动器
        currentIndex: root.currentBrakeIndex

        delegate: Rectangle {
            width: listView.width
            // ✅ 调整高度，使二级标题比一级标题小
            height: 45
            color: "transparent"
            // ✅ 移除边框
            border.color: "transparent"
            border.width: 0

            // ✅ 2026-01-31 [FIX 100.300.112.1]: 焦点指示器
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: (root.focusItemIndex === index) ? "#2196F3" : "transparent"
                border.width: (root.focusItemIndex === index) ? 3 : 0
                radius: 4
                z: 10
            }

            // ✅ 添加背景图片
            Image {
                id: backgroundImage
                anchors.fill: parent
                fillMode: Image.Stretch
                z: -1  // 放在最底层

                // 使用相对路径，便于QDS预览（向上三级到qml目录）
                source: "../../../images/bhNameBK.png"

                states: [
                    State {
                        name: "selected"
                        when: root.currentBrakeIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentBrakeIndex !== index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK.png"
                        }
                    }
                ]
            }

            // ✅ 左侧激活指示条
            Rectangle {
                visible: root.currentBrakeIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ✅ 制动器名称居中显示
            Text {
                text: (index + 1) + "号制动器"
                // ✅ 调整字体，使二级标题比一级标题小
                font.pixelSize: 14
                font.weight: root.currentBrakeIndex === index ? Font.Bold : Font.Normal
                color: root.currentBrakeIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
            }

            // ✅ 状态指示放在最右侧
            Row {
                spacing: 8
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#4CAF50"  // 绿色表示投入
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "投入"
                    font.pixelSize: 12
                    color: "#9E9E9E"
                }
            }

            // ✅ 鼠标点击
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentBrakeIndex = index
                    root.brakeSelected(index)
                    root.focus = true  // 获取焦点以支持键盘操作
                }
            }
        }
    }
}
