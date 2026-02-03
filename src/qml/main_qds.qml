import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.VirtualKeyboard 6.5  // ✅ 2026-02-02 [FIX 100.300.112.8.25.7.4]: 添加虚拟键盘支持

// ✅ 2026-01-25 [QDS专用入口] 简化版 main.qml，用于 QDS 运行
// 用途：在 QDS 中运行应用程序，不依赖 C++ 后端
ApplicationWindow {
    id: root
    visible: true
    width: 1920
    height: 1080
    title: "Belt Control System - QDS Preview"

    // ========== 加载模拟后端 ==========
    MockBackend {
        id: mockBackend
    }

    // ========== 暴露模拟后端为全局属性 ==========
    property alias commonControl: mockBackend.commonControl
    property alias deviceInfoController: mockBackend.deviceInfoController
    property alias sipPhoneManager: mockBackend.sipPhoneManager
    property alias audioManagementController: mockBackend.audioManagementController
    // ✅ 2026-01-28 [FIX 100.300.62]: 添加缺失的全局属性
    property alias systemConfig: mockBackend.systemConfig
    property alias operationLogDB: mockBackend.operationLogDB
    // ✅ 2026-01-28 [FIX 100.300.66]: 添加 runtimeTracker 和 deviceConfigMgr
    property alias runtimeTracker: mockBackend.runtimeTracker
    property alias deviceConfigMgr: mockBackend.deviceConfigMgr

    // ✅ 2026-02-03 [FIX 100.300.112.8.25.7.12.3]: 暴露虚拟键盘高度为全局属性
    // 让CustomSpinBox可以获取实际的虚拟键盘高度，而不是估算
    property real virtualKeyboardHeight: virtualKeyboard.height

    // ========== 主界面 ==========
    Rectangle {
        anchors.fill: parent
        color: "#1a1f2e"

        // ========== 顶部导航栏 ==========
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            color: "#252b3d"
            border.color: "#3d4556"
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 20

                // ✅ 2026-01-28 [FIX 100.300.65]: 移除"设备信息"页面，保留 5 个主界面
                Repeater {
                    model: [
                        "控制面板",
                        "参数设置",
                        "报警页面",
                        "Input1",
                        "语音管理"
                    ]

                    Rectangle {
                        width: 150
                        height: 40
                        color: swipeView.currentIndex === index ? "#2196F3" : "transparent"
                        border.color: "#2196F3"
                        border.width: 1
                        radius: 5

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 14
                            color: swipeView.currentIndex === index ? "#FFFFFF" : "#E0E0E0"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: swipeView.currentIndex = index
                        }
                    }
                }
            }
        }

        // ========== 页面切换视图 ==========
        // ✅ 2026-01-28 [FIX 100.300.65]: 移除第 4 页（设备信息），默认显示第 3 页（Input1）
        SwipeView {
            id: swipeView
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            currentIndex: 3  // 默认显示第 4 页（Input1，索引从 0 开始）

            // 页面 1: 控制面板
            Loader {
                source: "pages/ControlPanel.qml"
                onLoaded: {
                    console.log("✅ 控制面板加载成功")
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.log("❌ 控制面板加载失败")
                    }
                }
            }

            // 页面 2: 参数设置
            Loader {
                source: "pages/ParameterSettings.qml"
                onLoaded: {
                    console.log("✅ 参数设置加载成功")
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.log("❌ 参数设置加载失败")
                    }
                }
            }

            // 页面 3: 报警页面
            Loader {
                source: "pages/AlarmPage.qml"
                onLoaded: {
                    console.log("✅ 报警页面加载成功")
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.log("❌ 报警页面加载失败")
                    }
                }
            }

            // ✅ 2026-01-28 [FIX 100.300.65]: 移除第 4 页（设备信息 - 电机控制）
            // 原因：用户不需要在主界面显示设备信息，改为通过 Input1 页面的回车键或双击打开

            // 页面 4: Input1（✅ 2026-01-26 已移除 Input1 模块依赖，可在 QDS 中运行）
            Loader {
                source: "pages/Input1Page.qml"
                onLoaded: {
                    console.log("✅ Input1 页面加载成功")
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.log("❌ Input1 页面加载失败")
                    }
                }
            }

            // 页面 5: 语音管理
            Loader {
                source: "pages/VoiceManagement.qml"
                onLoaded: {
                    console.log("✅ 语音管理加载成功")
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.log("❌ 语音管理加载失败")
                    }
                }
            }
        }

        // ========== 底部状态栏 ==========
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            color: "#252b3d"
            border.color: "#3d4556"
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "设备: " + mockBackend.commonControl.deviceName
                    font.pixelSize: 12
                    color: "#E0E0E0"
                }

                Text {
                    text: "状态: " + (mockBackend.commonControl.isRunning ? "运行中" : "已停止")
                    font.pixelSize: 12
                    color: mockBackend.commonControl.isRunning ? "#4CAF50" : "#9E9E9E"
                }

                Text {
                    text: "速度: " + mockBackend.commonControl.currentSpeed.toFixed(2) + " m/s"
                    font.pixelSize: 12
                    color: "#E0E0E0"
                }
            }

            Text {
                anchors.right: testField.left
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "QDS 预览模式"
                font.pixelSize: 12
                color: "#2196F3"
            }

            // ✅ 2026-02-02 [调试]: 添加测试TextField，验证鼠标点击是否能触发虚拟键盘
            TextField {
                id: testField
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 30
                placeholderText: "测试虚拟键盘"
                inputMethodHints: Qt.ImhDigitsOnly
                font.pixelSize: 12

                onActiveFocusChanged: {
                    console.log("========================================")
                    console.log("🔍 [测试TextField] activeFocus changed:", activeFocus)
                    console.log("   - Qt.inputMethod.visible:", Qt.inputMethod.visible)
                    console.log("   - virtualKeyboard.active:", virtualKeyboard.active)
                    console.log("========================================")
                }
            }
        }
    }

    // ========== 键盘导航 ==========
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            if (swipeView.currentIndex > 0) {
                swipeView.currentIndex--
            } else {
                swipeView.currentIndex = swipeView.count - 1
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (swipeView.currentIndex < swipeView.count - 1) {
                swipeView.currentIndex++
            } else {
                swipeView.currentIndex = 0
            }
            event.accepted = true
        }
    }

    Component.onCompleted: {
        // ❌ 2026-02-03 [FIX 100.300.112.8.25.7.13]: 移除失败的键盘导航代码
        // 原因：Qt.application.setEnvironmentVariable() 在 QML 中不存在（C++ API）
        // 结论：Qt Virtual Keyboard 的方向键导航需要编译时启用，无法在运行时配置
        // 决议：不实施键盘导航方案，继续使用 Qt Virtual Keyboard + 自动滚动
        // Qt.application.setEnvironmentVariable("QT_VIRTUALKEYBOARD_DESKTOP_DISABLE", "0")

        console.log("========================================")
        console.log("✅ QDS 预览模式已启动")
        console.log("   - 窗口大小:", width, "x", height)
        console.log("   - 模拟后端已加载")
        console.log("   - 使用左右键切换页面")
        console.log("========================================")
    }

    // ✅ 2026-02-02 [FIX 100.300.112.8.25.7.7]: 使用 inputPanel.active（参考Qt官方示例）
    // Qt官方示例绑定到 inputPanel.active，不是 Qt.inputMethod.visible
    InputPanel {
        id: virtualKeyboard
        z: 99
        x: 0
        width: root.width

        // ❌ 2026-02-03 [FIX 100.300.112.8.25.7.14]: 移除 activeFocusOnTab
        // 原因：Tab键导航也需要 Qt Virtual Keyboard 编译时启用，无法在运行时配置
        // activeFocusOnTab: true

        property real yPositionWhenHidden: root.height
        y: yPositionWhenHidden

        states: State {
            name: "visible"
            when: virtualKeyboard.active  // ✅ 绑定到 active（Qt官方方式）
            PropertyChanges {
                target: virtualKeyboard
                y: root.height - virtualKeyboard.height
            }
        }

        transitions: Transition {
            from: ""
            to: "visible"
            reversible: true
            NumberAnimation {
                properties: "y"
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }

        Component.onCompleted: {
            console.log("========================================")
            console.log("⌨️ [QDS InputPanel] Virtual keyboard initialized")
            console.log("   - Width:", width)
            console.log("   - Height:", height)
            console.log("   - Z-index:", z)
            console.log("   - 绑定方式: inputPanel.active（Qt官方方式）")
            console.log("========================================")
        }

        onActiveChanged: {
            console.log("⌨️ [QDS InputPanel] Active changed:", active)
            if (active) {
                console.log("   - 虚拟键盘高度:", height)
                console.log("   - 虚拟键盘Y位置:", y)
                console.log("   - 屏幕高度:", root.height)
            }
        }

        onHeightChanged: {
            console.log("⌨️ [QDS InputPanel] Height changed:", height)
        }

        // ✅ 2026-02-03 [FIX]: 添加ESC键处理，只关闭虚拟键盘，不关闭对话框
        Shortcut {
            enabled: virtualKeyboard.active
            sequence: "Esc"
            onActivated: {
                console.log("⌨️ [QDS InputPanel] ESC键被按下，关闭虚拟键盘")
                Qt.inputMethod.hide()
            }
        }
    }
}
