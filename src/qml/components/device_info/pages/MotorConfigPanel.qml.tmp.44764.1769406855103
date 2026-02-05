import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-01-25 [电机控制-右侧面板] 电机配置面板（Tab切换）
Rectangle {
    id: root
    width: 800  // 默认宽度（用于QDS预览）
    height: 600  // 默认高度（用于QDS预览）
    color: "#1a1f2e"

    // ========== 公开属性 ==========
    property int motorIndex: 0  // 当前电机索引 (0-7)
    property int currentTabIndex: 0  // 当前Tab索引

    // ========== 键盘导航支持 ==========
    focus: true

    Keys.onLeftPressed: {
        if (root.currentTabIndex > 0) {
            root.currentTabIndex--
        }
    }

    Keys.onRightPressed: {
        if (root.currentTabIndex < 9) {  // 10个Tab (0-9)
            root.currentTabIndex++
        }
    }

    // ========== 标题栏 ==========
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#252b3d"
        border.color: "#3d4556"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: (root.motorIndex + 1) + "号电机配置"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#E0E0E0"
        }
    }

    // ========== Tab栏 ==========
    Rectangle {
        id: tabBar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#252b3d"
        border.color: "#3d4556"
        border.width: 1

        // ✅ 使用 ScrollView 支持横向滚动（Tab较多时）
        // ✅ 2026-01-26 [FIX 100.300.21]: 启用横向滚动，禁用纵向滚动
        ScrollView {
            anchors.fill: parent
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff  // 禁用纵向滚动条
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded  // 需要时显示横向滚动条
            contentWidth: tabRow.width  // ✅ 明确指定内容宽度

            Row {
                id: tabRow
                spacing: 0
                // ✅ 2026-01-26 [FIX]: 明确设置宽度，确保 ScrollView 知道需要滚动
                width: childrenRect.width

                Repeater {
                    model: ["基本配置", "电流保护", "前轴承温度", "后轴承温度", "A相绕组", "B相绕组", "C相绕组", "电机温度", "X轴振动", "Y轴振动"]

                    Rectangle {
                        width: 120
                        height: 50
                        color: root.currentTabIndex === index ? "#1a1f2e" : "transparent"
                        border.color: root.currentTabIndex === index ? "#2196F3" : "transparent"
                        border.width: root.currentTabIndex === index ? 2 : 0

                        // ✅ 底部激活指示条
                        Rectangle {
                            visible: root.currentTabIndex === index
                            width: parent.width
                            height: 3
                            color: "#2196F3"
                            anchors.bottom: parent.bottom
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 14
                            font.weight: root.currentTabIndex === index ? Font.Bold : Font.Normal
                            color: root.currentTabIndex === index ? "#E0E0E0" : "#9E9E9E"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.currentTabIndex = index
                                root.focus = true  // 获取焦点以支持键盘操作
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 内容区域 ==========
    Rectangle {
        id: contentArea
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"

        StackLayout {
            anchors.fill: parent
            currentIndex: root.currentTabIndex

            // 0: 基本配置
            Loader {
                id: basicConfigLoader
                active: root.currentTabIndex === 0
                source: "BasicConfigTab.qml"

                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                    }
                }
            }

            // 1: 电流保护
            Loader {
                id: currentProtectionLoader
                active: root.currentTabIndex === 1
                source: "CurrentProtectionTab.qml"

                onLoaded: {
                    if (item) {
                        item.motorIndex = root.motorIndex
                    }
                }
            }

            // 2: 前轴承温度
            Loader {
                active: root.currentTabIndex === 2
                source: "FrontBearingTempTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 3: 后轴承温度
            Loader {
                active: root.currentTabIndex === 3
                source: "RearBearingTempTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 4: A相绕组
            Loader {
                active: root.currentTabIndex === 4
                source: "PhaseAWindingTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 5: B相绕组
            Loader {
                active: root.currentTabIndex === 5
                source: "PhaseBWindingTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 6: C相绕组
            Loader {
                active: root.currentTabIndex === 6
                source: "PhaseCWindingTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 7: 电机温度
            Loader {
                active: root.currentTabIndex === 7
                source: "MotorTempTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 8: X轴振动
            Loader {
                active: root.currentTabIndex === 8
                source: "XAxisVibrationTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }

            // 9: Y轴振动
            Loader {
                active: root.currentTabIndex === 9
                source: "YAxisVibrationTab.qml"
                onLoaded: { if (item) item.motorIndex = root.motorIndex }
            }
        }
    }
}
