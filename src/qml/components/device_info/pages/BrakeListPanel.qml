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
    // ✅ 2026-01-31 [FIX 100.300.112.6]: 导航子区域（从父页面传递）
    property int focusSubArea: 0  // 0:列表区域 1:参数区域 2:按钮区域

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 制动器状态数组（从父组件 BrakeControlPage 传入）
    // 每个元素: { enabled: bool, releaseOutputChannel: int }
    // enabled=true: 启用（绿色）, enabled=false: 禁用（红色）
    // releaseOutputChannel=-1: 未配置（暗灰色）
    property var brakeStatusList: []

    // ✅ 2026-03-30 [Phase 7.48.88.74]: 制动器运行状态数组（全局关联，从BrakeControlPage传入）
    // true=运行中（亮绿闪烁）, false=已停止
    property var brakeRunningStates: [false,false,false,false,false,false,false,false]

    // ✅ 2026-02-03 [DEBUG]: 添加调试日志
    onCurrentBrakeIndexChanged: {
        console.log("🔍 [BrakeListPanel] currentBrakeIndex 变化:", currentBrakeIndex)
    }

    onFocusItemIndexChanged: {
        console.log("🔍 [BrakeListPanel] focusItemIndex 变化:", focusItemIndex)
    }

    // ========== 信号 ==========
    signal brakeSelected(int brakeIndex)  // 制动器被选中时发出信号

    // ========== 键盘导航支持 ==========
    focus: true

    // ✅ 2026-02-04 [FIX 100.300.112.8.25.17]: 移除直接赋值，避免破坏 Qt.binding()
    // 注意：这些键盘事件处理已经不再使用，因为 BrakeControlPage 使用 NavigationManager
    // 但为了保险起见，也修复它们
    Keys.onUpPressed: {
        // 旧代码：
        // if (root.currentBrakeIndex > 0) {
        //     root.currentBrakeIndex--  // ❌ 这会破坏绑定！
        //     brakeSelected(root.currentBrakeIndex)
        // }
        // 新方案：只发射信号，不直接修改 currentBrakeIndex
        if (root.currentBrakeIndex > 0) {
            brakeSelected(root.currentBrakeIndex - 1)
        }
    }

    Keys.onDownPressed: {
        // 旧代码：
        // if (root.currentBrakeIndex < 7) {
        //     root.currentBrakeIndex++  // ❌ 这会破坏绑定！
        //     brakeSelected(root.currentBrakeIndex)
        // }
        // 新方案：只发射信号，不直接修改 currentBrakeIndex
        if (root.currentBrakeIndex < 7) {
            brakeSelected(root.currentBrakeIndex + 1)
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
            // ✅ 2026-01-31 [FIX 100.300.112.6]: 只在列表区域（focusSubArea === 0）时显示
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

            // ✅ 制动器名称（居中偏左，给右侧状态留空间）
            // 旧：anchors.centerIn: parent  // 2026-03-30 居中布局导致与右侧状态文字重叠
            // 旧：anchors.left + leftMargin: 16  // 2026-03-30 左对齐与背景图片尖角重叠
            Text {
                text: (index + 1) + "号制动器"
                // ✅ 调整字体，使二级标题比一级标题小
                font.pixelSize: 14
                font.weight: root.currentBrakeIndex === index ? Font.Bold : Font.Normal
                color: root.currentBrakeIndex === index ? "#E0E0E0" : "#9E9E9E"
                anchors.centerIn: parent
                // 旧：anchors.horizontalCenterOffset: -20  // 2026-03-30 偏移太大，左侧仍靠近背景边缘
                anchors.horizontalCenterOffset: -12
            }

            // ✅ 2026-03-30 [Phase 7.48.88.74]: 动态状态指示（参照 MyMotorListPanel）
            // 旧代码: 硬编码 color: "#4CAF50" text: "投入"
            Row {
                spacing: 4
                anchors.right: parent.right
                // 旧：anchors.rightMargin: 20  // 2026-03-30 缩小右边距，避免与名称重叠
                // 旧：anchors.rightMargin: 6  // 2026-03-30 太小，右侧状态文字靠近背景边缘
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                // ✅ 2026-04-07 [Phase 7.48.88.81]: 修复状态颜色区分+圆形放大+文字对齐
                // 旧：8x8圆形，已停止=绿色#4CAF50（与运行中难以区分），文字宽度不固定导致圆形不对齐
                // 新：10x10圆形，已停止=橙色#FFA726，文字固定宽度38确保圆形对齐
                Rectangle {
                    id: brakeStatusLed
                    width: 10
                    height: 10
                    radius: 5
                    property bool isRunning: index < root.brakeRunningStates.length ? root.brakeRunningStates[index] : false
                    color: {
                        if (brakeStatusLed.isRunning) return "#00E676"  // 亮绿：运行中
                        if (index < root.brakeStatusList.length) {
                            var status = root.brakeStatusList[index]
                            if (status && status.releaseOutputChannel >= 0 && status.enabled) return "#FFA726"  // 橙色：已停止（启用）
                            if (status && status.releaseOutputChannel >= 0 && !status.enabled) return "#FF5722"  // 红色：禁用
                        }
                        return "#555555"  // 暗灰：未配置
                    }
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: brakeStatusLed.isRunning
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    }
                    onIsRunningChanged: if (!isRunning) opacity = 1.0
                }

                Text {
                    text: {
                        if (index < root.brakeRunningStates.length && root.brakeRunningStates[index]) return "运行中"
                        if (index < root.brakeStatusList.length) {
                            var status = root.brakeStatusList[index]
                            if (status && status.releaseOutputChannel >= 0 && status.enabled) return "已停止"
                            if (status && status.releaseOutputChannel >= 0 && !status.enabled) return "禁用"
                        }
                        return "未配置"
                    }
                    width: 38  // 固定宽度确保圆形对齐
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignLeft
                    color: {
                        if (index < root.brakeRunningStates.length && root.brakeRunningStates[index]) return "#00E676"  // 运行中=亮绿
                        if (index < root.brakeStatusList.length) {
                            var status = root.brakeStatusList[index]
                            if (status && status.releaseOutputChannel >= 0 && status.enabled) return "#FFA726"  // 已停止=橙色
                            if (status && status.releaseOutputChannel >= 0 && !status.enabled) return "#FF5722"  // 禁用=红色
                        }
                        return "#9E9E9E"  // 未配置=灰色
                    }
                }
            }

            // ✅ 鼠标点击
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // ✅ 2026-02-04 [FIX 100.300.112.8.25.17]: 移除直接赋值，避免破坏 Qt.binding()
                    // 旧代码：root.currentBrakeIndex = index  // ❌ 这会破坏绑定！
                    // 新方案：只发射信号，让 BrakeControlPage 更新 navigationManager.brakeListIndex
                    //        然后通过绑定自动更新 currentBrakeIndex
                    root.brakeSelected(index)
                    root.focus = true  // 获取焦点以支持键盘操作
                }
            }
        }
    }
}
