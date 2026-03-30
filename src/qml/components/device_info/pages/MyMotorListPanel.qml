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

    // ✅ 2026-03-29 [Phase 7.48.88.56]: 电机状态数组（从父组件 MotorControlPage 传入）
    // 每个元素: { enabled: bool, outputChannel: int }
    // enabled=true: 投入（绿色）, enabled=false: 禁用（灰色）
    // outputChannel=-1: 未配置（暗灰色）
    property var motorStatusList: []

    // ✅ 2026-03-30 [Phase 7.48.88.71]: 电机运行状态数组（全局关联，从MotorControlPage传入）
    // true=运行中（亮绿闪烁）, false=已停止
    property var motorRunningStates: [false,false,false,false,false,false,false,false]

    // ✅ 2026-03-29 [Phase 7.48.88.57]: 参数已修改的电机索引（-1=无修改）
    // 当某电机参数被修改但未保存时，在其名称左侧显示 ● 标记
    // ✅ 2026-03-29 [Phase 7.48.88.57]: 修改标记索引
    // ✅ 2026-03-29 [Phase 7.48.88.60]: 改为数组，支持多电机同时显示修改标记
    // 旧代码: property int modifiedMotorIndex: -1
    property var modifiedMotorIndices: []

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.19]: 添加调试日志
    onCurrentMotorIndexChanged: {
        console.log("🔍 [DEBUG] MyMotorListPanel.currentMotorIndex 变化:", currentMotorIndex)
    }

    // ✅ 2026-01-30 [FIX 100.300.106]: 导航焦点索引（从父页面传递）
    property int focusItemIndex: -1  // -1 表示无焦点

    // ========== 信号 ==========
    signal motorSelected(int motorIndex)  // 电机被选中时发出信号

    // ========== 键盘导航支持 ==========
    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.18]: 注释掉旧的键盘事件处理器
    // 导航现在由 NavigationManager 统一管理，不需要在这里处理键盘事件
    // 保留这些代码会与 NavigationManager 冲突，导致背景图片和蓝色边框不同步
    // focus: true

    // Keys.onUpPressed: {
    //     if (root.currentMotorIndex > 0) {
    //         root.currentMotorIndex--
    //         motorSelected(root.currentMotorIndex)
    //     }
    // }

    // Keys.onDownPressed: {
    //     if (root.currentMotorIndex < 7) {
    //         root.currentMotorIndex++
    //         motorSelected(root.currentMotorIndex)
    //     }
    // }

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
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.22]: 添加必需的属性声明
            required property int index  // ListView 自动提供的索引

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
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.21]: 改用直接绑定替代 State
            // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.22]: 添加更详细的调试信息
            Image {
                id: backgroundImage
                anchors.fill: parent
                fillMode: Image.Stretch
                z: -1  // 放在最底层

                // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.21]: 直接绑定 source，不使用 State
                // 使用相对路径，便于QDS预览（向上三级到qml目录）
                source: root.currentMotorIndex === index ? "../../../images/bhNameBK1.png" : "../../../images/bhNameBK.png"

                // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.22]: 添加详细调试日志
                Component.onCompleted: {
                    console.log("🔍 [DEBUG] 背景图片组件创建 - 电机", index + 1, "初始 source:", source)
                }

                onSourceChanged: {
                    console.log("🔍 [DEBUG] 背景图片切换 - 电机", index + 1, "source:", source, "currentMotorIndex:", root.currentMotorIndex)
                }

                // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.22]: 监听 currentMotorIndex 变化
                Connections {
                    target: root
                    function onCurrentMotorIndexChanged() {
                        console.log("🔍 [DEBUG] Connections 监听到 currentMotorIndex 变化 - 电机", index + 1, "新值:", root.currentMotorIndex, "当前 source:", backgroundImage.source)
                    }
                }
            }

            // ✅ 左侧激活指示条
            Rectangle {
                visible: root.currentMotorIndex === index
                width: 4
                height: parent.height
                color: "#2196F3"
                anchors.left: parent.left
            }

            // ✅ 2026-03-29 [Phase 7.48.88.57]: 参数已修改标记（未保存时显示）
            Text {
                text: "●"
                font.pixelSize: 12
                color: "#FFC107"  // 黄色警示
                // ✅ 2026-03-29 [Phase 7.48.88.60]: 改为数组查找，支持多电机修改标记
                // 旧代码: visible: root.modifiedMotorIndex === index
                visible: root.modifiedMotorIndices.indexOf(index) >= 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: motorNameText.left
                anchors.rightMargin: 4
                z: 5
            }

            // ✅ 2026-01-26 [FIX 100.300.25.5]: 电机名称居中显示
            Text {
                id: motorNameText
                text: (index + 1) + "号电机"
                // ✅ 2026-01-26 [FIX 100.300.25.14]: 调整字体，使二级标题比一级标题小
                font.pixelSize: 14  // 从 16 改为 14（与一级标题相同）
                font.weight: root.currentMotorIndex === index ? Font.Bold : Font.Normal
                color: root.currentMotorIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
            }

            // ✅ 2026-03-29 [Phase 7.48.88.56]: 状态指示（从 motorStatusList 获取实际状态）
            // ✅ 2026-03-30 [Phase 7.48.88.71]: 增加运行状态全局关联（亮绿闪烁=运行中）
            // ❌ 旧代码: 硬编码 color: "#4CAF50" text: "运行中"
            Row {
                spacing: 8
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: statusLed
                    width: 8
                    height: 8
                    radius: 4
                    // ✅ 2026-03-30 [Phase 7.48.88.71]: 运行中=亮绿, 投入(已停止)=绿色, 禁用=红色, 未配置=暗灰
                    // 旧代码：只有投入/禁用/未配置三种状态
                    property bool isRunning: index < root.motorRunningStates.length ? root.motorRunningStates[index] : false
                    color: {
                        if (statusLed.isRunning) return "#00E676"  // 亮绿：运行中
                        if (index < root.motorStatusList.length) {
                            var status = root.motorStatusList[index]
                            if (status && status.outputChannel >= 0 && status.enabled) return "#4CAF50"  // 绿色：已停止（投入）
                            if (status && status.outputChannel >= 0 && !status.enabled) return "#FF5722"  // 红色：禁用
                        }
                        return "#555555"  // 暗灰：未配置
                    }
                    anchors.verticalCenter: parent.verticalCenter

                    // ✅ 2026-03-30 [Phase 7.48.88.71]: 运行中闪烁动画
                    SequentialAnimation on opacity {
                        running: statusLed.isRunning
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    }
                    // 非运行时恢复完全不透明
                    onIsRunningChanged: if (!isRunning) opacity = 1.0
                }

                Text {
                    // ✅ 2026-03-30 [Phase 7.48.88.71]: 增加运行中文本显示
                    // 旧代码：只有投入/禁用/未配置
                    text: {
                        if (index < root.motorRunningStates.length && root.motorRunningStates[index]) return "运行中"
                        if (index < root.motorStatusList.length) {
                            var status = root.motorStatusList[index]
                            if (status && status.outputChannel >= 0 && status.enabled) return "已停止"
                            if (status && status.outputChannel >= 0 && !status.enabled) return "禁用"
                        }
                        return "未配置"
                    }
                    font.pixelSize: 12
                    // ✅ 2026-03-30 [Phase 7.48.88.71]: 运行中文字颜色也用亮绿
                    color: (index < root.motorRunningStates.length && root.motorRunningStates[index]) ? "#00E676" : "#9E9E9E"
                }
            }

            // ✅ 鼠标点击
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.23]: 移除直接赋值，避免破坏 Qt.binding()
                    // root.currentMotorIndex = index  // ❌ 这会破坏 Qt.binding()，导致后续导航键操作时绑定失效
                    root.motorSelected(index)  // ✅ 只发送信号，让父组件通过绑定更新
                    // root.focus = true  // ❌ 不需要，焦点由父组件管理
                }
            }
        }
    }
}
