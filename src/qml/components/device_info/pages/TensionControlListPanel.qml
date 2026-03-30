import QtQuick 2.15

// ✅ 2026-01-27 [张紧控制-左侧面板] 控制列表面板
// 设计风格与电机列表、制动器列表完全一样
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
    // 2026-03-17 [Phase 7.48.51]: 改为0=张力传感器, 1=张紧控制（分离两个功能）
    property int currentControlIndex: 0  // 当前选中的控制索引 (0=张力传感器, 1=张紧控制)
    // ✅ 2026-01-31 [FIX 100.300.112.8.2]: 导航焦点索引（从父页面传递）
    property int focusItemIndex: -1  // -1 表示无焦点
    // ✅ 2026-01-31 [FIX 100.300.112.8.2]: 导航子区域（从父页面传递）
    property int focusSubArea: 0  // 0:列表区域 1:使用状态 2:参数区域 3:按钮区域

    // ✅ 2026-03-30 [Phase 7.48.88.75]: 张紧控制状态数组（从父组件传入）
    // 每个元素: { enabled: bool, outputChannel: int }
    // index 0=张力传感器, 1=张紧控制
    property var tensionStatusList: []

    // ✅ 2026-03-30 [Phase 7.48.88.75]: 张紧运行状态数组
    // true=运行中（亮绿闪烁）, false=已停止
    property var tensionRunningStates: [false, false]

    // ========== 信号 ==========
    signal controlSelected(int controlIndex)  // 控制被选中时发出信号

    // ========== 键盘导航支持 ==========
    focus: true

    // ✅ 2026-02-04 [FIX 100.300.112.8.25.18]: 移除直接赋值，避免破坏 Qt.binding()
    // 注意：这些键盘事件处理已经不再使用，因为 TensionControlPage 使用 NavigationManager
    // 但为了保险起见，也修复它们
    Keys.onUpPressed: {
        // 旧代码：
        // if (root.currentControlIndex > 0) {
        //     root.currentControlIndex--  // ❌ 这会破坏绑定！
        //     controlSelected(root.currentControlIndex)
        // }
        // 新方案：只发射信号，不直接修改 currentControlIndex
        if (root.currentControlIndex > 0) {
            controlSelected(root.currentControlIndex - 1)
        }
    }

    Keys.onDownPressed: {
        // 旧代码：
        // if (root.currentControlIndex < 1) {  // 只有2个选项
        //     root.currentControlIndex++  // ❌ 这会破坏绑定！
        //     controlSelected(root.currentControlIndex)
        // }
        // 新方案：只发射信号，不直接修改 currentControlIndex
        if (root.currentControlIndex < 1) {  // 只有2个选项
            controlSelected(root.currentControlIndex + 1)
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
            text: "控制列表"
            font.pixelSize: 16
            anchors.verticalCenterOffset: -6
            anchors.horizontalCenterOffset: -16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== 控制列表（使用ListView，QDS支持）==========
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0
        clip: true

        model: ListModel {
            ListElement { name: "张力传感器" }
            // 2026-03-17 [Phase 7.48.51]: 旧名"独立张紧控制"→"张紧控制"
            ListElement { name: "张紧控制" }
        }
        currentIndex: root.currentControlIndex

        delegate: Rectangle {
            width: listView.width
            // ✅ 调整高度，使二级标题比一级标题小
            height: 45
            color: "transparent"
            // ✅ 移除边框
            border.color: "transparent"
            border.width: 0

            // ✅ 2026-01-31 [FIX 100.300.112.8.2]: 焦点指示器
            // ✅ 只在列表区域（focusSubArea === 0）时显示
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: (root.focusSubArea === 0 && root.focusItemIndex === index) ? "#2196F3" : "transparent"
                border.width: (root.focusSubArea === 0 && root.focusItemIndex === index) ? 3 : 0
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
                        when: root.currentControlIndex === index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK1.png"
                        }
                    },
                    State {
                        name: "normal"
                        when: root.currentControlIndex !== index
                        PropertyChanges {
                            target: backgroundImage
                            source: "../../../images/bhNameBK.png"
                        }
                    }
                ]
            }

            // ✅ 左侧激活指示条
            Rectangle {
                visible: root.currentControlIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ✅ 控制名称（居中偏左，给右侧状态留空间）
            Text {
                text: model.name
                // ✅ 调整字体，使二级标题比一级标题小
                font.pixelSize: 14
                font.weight: root.currentControlIndex === index ? Font.Bold : Font.Normal
                color: root.currentControlIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -12
            }

            // ✅ 2026-03-30 [Phase 7.48.88.75]: 动态状态指示（参照 BrakeListPanel）
            // 旧代码: 硬编码 model.status "投入"
            Row {
                spacing: 4
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: tensionStatusLed
                    width: 8
                    height: 8
                    radius: 4
                    property bool isRunning: index < root.tensionRunningStates.length ? root.tensionRunningStates[index] : false
                    color: {
                        if (tensionStatusLed.isRunning) return "#00E676"  // 亮绿：运行中
                        if (index < root.tensionStatusList.length) {
                            var status = root.tensionStatusList[index]
                            if (status && status.outputChannel >= 0 && status.enabled) return "#4CAF50"  // 绿色：已停止（启用）
                            if (status && status.outputChannel >= 0 && !status.enabled) return "#FF5722"  // 红色：禁用
                        }
                        return "#555555"  // 暗灰：未配置
                    }
                    anchors.verticalCenter: parent.verticalCenter

                    // ✅ 运行中闪烁动画
                    SequentialAnimation on opacity {
                        running: tensionStatusLed.isRunning
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    }
                    onIsRunningChanged: if (!isRunning) opacity = 1.0
                }

                Text {
                    text: {
                        if (index < root.tensionRunningStates.length && root.tensionRunningStates[index]) return "运行中"
                        if (index < root.tensionStatusList.length) {
                            var status = root.tensionStatusList[index]
                            if (status && status.outputChannel >= 0 && status.enabled) return "已停止"
                            if (status && status.outputChannel >= 0 && !status.enabled) return "禁用"
                        }
                        return "未配置"
                    }
                    font.pixelSize: 11
                    color: (index < root.tensionRunningStates.length && root.tensionRunningStates[index]) ? "#00E676" : "#9E9E9E"
                }
            }

            // ✅ 鼠标点击
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // ✅ 2026-02-04 [FIX 100.300.112.8.25.18]: 移除直接赋值，避免破坏 Qt.binding()
                    // 旧代码：root.currentControlIndex = index  // ❌ 这会破坏绑定！
                    // 新方案：只发射信号，让 TensionControlPage 更新 navigationManager.controlListIndex
                    //        然后通过绑定自动更新 currentControlIndex
                    root.controlSelected(index)
                    root.focus = true  // 获取焦点以支持键盘操作
                }
            }
        }
    }
}
