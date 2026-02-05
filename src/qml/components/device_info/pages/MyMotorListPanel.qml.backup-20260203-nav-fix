import QtQuick 2.15

Rectangle {
    id: root
    // ✅ 2026-01-26 [FIX 100.300.25.28]: 改为透明，使用 33.png 作为整体背景
    color: "transparent"
    // ✅ 2026-01-26 [FIX 100.300.25.18]: 添加 clip 防止背景色超出弹窗底部
    clip: true

    // ✅ 2026-01-26 [FIX 100.300.25.28]: 添加整体背景图片 33.png
    Image {
        anchors.fill: parent
        source: "../images/33.png"
        fillMode: Image.Stretch
        z: -1  // 放在最底层
    }

    // ========== 公开属性 ==========
    property int currentMotorIndex: 0  // 当前选中的电机索引 (0-7)

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusItemIndex: -1  // -1 表示无焦点

    // ========== 信号 ==========
    signal motorSelected(int motorIndex)  // 电机被选中时发出信号

    // ========== 键盘导航支持 ==========
    focus: true

    Keys.onUpPressed: {
        if (root.currentMotorIndex > 0) {
            root.currentMotorIndex--
            motorSelected(root.currentMotorIndex)
        }
    }

    Keys.onDownPressed: {
        if (root.currentMotorIndex < 7) {
            root.currentMotorIndex++
            motorSelected(root.currentMotorIndex)
        }
    }

    // ========== 标题 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        // ✅ 2026-01-26 [FIX 100.300.25.28]: 改为透明，显示背景图片
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        Text {
            anchors.centerIn: parent
            text: "电机列表"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 电机列表（使用ListView，QDS支持）==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0
        clip: true

        model: 8  // 8个电机
        currentIndex: root.currentMotorIndex

        delegate: Rectangle {
            width: listView.width
            // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整高度，使二级标题比一级标题小
            height: 45  // 从 60 改为 45（一级标题是 40）
            color: "transparent"
            // ✅ 2026-01-26 [FIX 100.300.25.28]: 移除边框
            border.color: "transparent"
            border.width: 0

            // ✅ 2026-01-30 [FIX 100.300.106]: 焦点指示器
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: (root.focusItemIndex === index) ? "#2196F3" : "transparent"
                border.width: (root.focusItemIndex === index) ? 3 : 0
                radius: 4
                z: 10
            }

            // ✅ 2026-01-26 [FIX 100.300.25.5]: 添加背景图片
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
                        when: root.currentMotorIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentMotorIndex !== index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK.png"
                        }
                    }
                ]
            }

            // ✅ 左侧激活指示条
            Rectangle {
                visible: root.currentMotorIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ✅ 2026-01-26 [FIX 100.300.25.5]: 电机名称居中显示
            Text {
                text: (index + 1) + "号电机"
                // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整字体，使二级标题比一级标题小
                font.pixelSize: 14  // 从 16 改为 14（与一级标题相同）
                font.weight: root.currentMotorIndex === index ? Font.Bold : Font.Normal
                color: root.currentMotorIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
            }

            // ✅ 2026-01-26 [FIX 100.300.25.5]: 状态指示放在最右侧
            Row {
                spacing: 8
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#4CAF50"  // 绿色表示运行中
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "运行中"
                    font.pixelSize: 12
                    color: "#9E9E9E"
                }
            }

            // ✅ 鼠标点击
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentMotorIndex = index
                    root.motorSelected(index)
                    root.focus = true  // 获取焦点以支持键盘操作
                }
            }
        }
    }
}
