import QtQuick 6.5
import QtQuick.Controls 6.5

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

                Repeater {
                    model: [
                        "控制面板",
                        "参数设置",
                        "报警页面",
                        "设备信息",
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
        SwipeView {
            id: swipeView
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            currentIndex: 3  // 默认显示第 4 页（设备信息）

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

            // 页面 4: 设备信息 - 电机控制
            Rectangle {
                color: "#1a1f2e"

                Loader {
                    anchors.centerIn: parent
                    width: 1000
                    height: 600
                    source: "components/device_info/pages/MotorControlPage.qml"
                    onLoaded: {
                        console.log("✅ 电机控制页面加载成功")
                    }
                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.log("❌ 电机控制页面加载失败")
                        }
                    }
                }
            }

            // 页面 5: Input1（✅ 2026-01-26 已移除 Input1 模块依赖，可在 QDS 中运行）
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

            // 页面 6: 语音管理
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
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "QDS 预览模式"
                font.pixelSize: 12
                color: "#2196F3"
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
        console.log("========================================")
        console.log("✅ QDS 预览模式已启动")
        console.log("   - 窗口大小:", width, "x", height)
        console.log("   - 模拟后端已加载")
        console.log("   - 使用左右键切换页面")
        console.log("========================================")
    }
}
