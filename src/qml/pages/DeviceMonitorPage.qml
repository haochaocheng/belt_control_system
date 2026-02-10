import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components/device_monitor"  // ✅ 2026-02-10 [Phase 7.45.7]: 导入设备监控组件
import "../Input1/Input1Content"  // ✅ 2026-02-10 [Phase 7.45.8]: 导入统一背景和头部组件

// ✅ 2026-02-10 [Phase 7.45.7]: 设备监控页面
// 显示所有设备和集控设备的实时状态
// 作为独立页面，而不是Dialog弹窗
// ✅ 2026-02-10 [Phase 7.45.8]: 使用统一的 Back 和 Head 组件
Item {
    id: root

    // ✅ 2026-02-10 [QDS设计尺寸]: 设置固定设计尺寸，便于在QDS中设计
    // 运行时会自动填充父容器（通过 anchors.fill）
    width: 1920
    height: 1080

    // 运行时填充父容器
    anchors.fill: parent

    // ✅ 2026-02-10 [Phase 7.45.8]: 使用统一的 Back 背景组件（与其他页面一致）
    Back {
        anchors.fill: parent
        z: 0  // 确保在最底层
        enabled: false  // 不接收鼠标事件，只作为视觉背景
    }

    // ✅ 2026-02-10 [Phase 7.45.8]: 使用统一的 Head 头部组件（与其他页面一致）
    // 使用 Item 容器包裹 Head，应用缩放变换
    Item {
        id: headerContainer
        anchors.top: parent.top
        anchors.left: parent.left
        width: 1920
        height: 80
        clip: true
        z: 10  // 确保在内容之上

        transform: Scale {
            property real scaleFactor: root.width / 1920  // 缩放比例
            xScale: scaleFactor
            yScale: scaleFactor  // 等比缩放
            origin.x: 0
            origin.y: 0
        }

        Head {
            id: header
            width: 1920
            height: 80
            currentPageIndex: 1  // 设备监控是第2个页面（索引从0开始）
        }
    }

    // ========== 主内容区域 ==========
    // ✅ 2026-02-10 [Phase 7.45.8]: 调整布局，为 Head 组件留出空间
    // 2026-02-10: 注释掉原来的自定义标题栏，改用统一的 Head 组件
    // Rectangle {
    //     Layout.fillWidth: true
    //     Layout.preferredHeight: 80
    //     color: "#1a1f2e"
    //     ...
    // }
    ColumnLayout {
        anchors.top: headerContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 20

        // ========== 滚动内容区域 ==========
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 20

                // 本机信息栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    Layout.margins: 10

                    // ✅ 科技感：渐变背景
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f1e" }
                        GradientStop { position: 1.0; color: "#0a1f0e" }
                    }

                    border.width: 3
                    border.color: "#00ff00"
                    radius: 8

                    // ✅ 科技感：外层发光效果
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        color: "transparent"
                        border.width: 2
                        border.color: "#00ff00"
                        radius: 11
                        opacity: 0.4
                    }

                    // ✅ 科技感：内层光晕
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#00ff00"
                        radius: 6
                        opacity: 0.6
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 30

                        // 本机角色
                        RowLayout {
                            spacing: 10

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: "#0080ff"

                                // ✅ 科技感：呼吸灯效果
                                SequentialAnimation on opacity {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                                }

                                // ✅ 科技感：光晕效果
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 8
                                    height: parent.height + 8
                                    radius: (parent.width + 8) / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: "#0080ff"
                                    opacity: 0.3
                                }
                            }

                            Text {
                                text: "本机角色: " + (typeof deviceRoleManager !== 'undefined' ? deviceRoleManager.stationName : "主站")
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "Microsoft YaHei"
                                color: "#00ff00"
                            }
                        }

                        Rectangle {
                            width: 2
                            Layout.fillHeight: true

                            // ✅ 科技感：分隔线渐变
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: "#2a3f5f" }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // 本机设备
                        Text {
                            text: "本机设备: " + (typeof deviceRoleManager !== 'undefined' ? deviceRoleManager.localDeviceName : "1号皮带")
                            font.pixelSize: 18
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00ff00"
                        }

                        Rectangle { width: 2; Layout.fillHeight: true; color: "#2a3f5f" }

                        // 在线集控
                        Text {
                            text: "在线集控: 3/5"
                            font.pixelSize: 16
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
                        }

                        Item { Layout.fillWidth: true }

                        // 最后更新时间
                        Text {
                            id: updateTimeText
                            text: "更新: " + Qt.formatTime(new Date(), "hh:mm:ss")
                            font.pixelSize: 14
                            font.family: "Consolas"
                            color: "#5a6f8f"
                        }
                    }
                }

                // 集控设备区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 280
                    Layout.margins: 10

                    // ✅ 科技感：深色渐变背景
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#0f1a2e" }
                        GradientStop { position: 1.0; color: "#0a0f1e" }
                    }

                    border.width: 2
                    border.color: "#00d4ff"
                    radius: 8

                    // ✅ 科技感：外层发光
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        border.width: 1
                        border.color: "#00d4ff"
                        radius: 10
                        opacity: 0.3
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        // ✅ 科技感：标题带下划线
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "【集控设备】"
                                font.pixelSize: 20
                                font.bold: true
                                font.family: "Microsoft YaHei"
                                color: "#00d4ff"
                            }

                            Rectangle {
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 2
                                color: "#00d4ff"
                                opacity: 0.5
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 4
                            rowSpacing: 15
                            columnSpacing: 15

                            // 主站
                            StationCard {
                                stationId: 1
                                stationRole: "master"
                                stationName: "主站"
                                controlDevice: "1号皮带"
                                controlDeviceId: 1
                                ip: "192.168.10.188"
                                isOnline: true
                                isLocal: true
                                status: "运行中"
                            }

                            // 分站1
                            StationCard {
                                stationId: 2
                                stationRole: "sub"
                                stationName: "分站1"
                                controlDevice: "2号皮带"
                                controlDeviceId: 2
                                ip: "192.168.10.189"
                                isOnline: true
                                isLocal: false
                                status: "运行中"
                            }

                            // 分站2
                            StationCard {
                                stationId: 3
                                stationRole: "sub"
                                stationName: "分站2"
                                controlDevice: "3号皮带"
                                controlDeviceId: 3
                                ip: "192.168.10.190"
                                isOnline: true
                                isLocal: false
                                status: "停止"
                            }

                            // 分站3（离线）
                            StationCard {
                                stationId: 4
                                stationRole: "sub"
                                stationName: "分站3"
                                controlDevice: "4号皮带"
                                controlDeviceId: 4
                                ip: ""
                                isOnline: false
                                isLocal: false
                                status: ""
                            }
                        }
                    }
                }

                // 皮带输送机区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 450
                    Layout.margins: 10

                    // ✅ 科技感：深色渐变背景
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#0f1a2e" }
                        GradientStop { position: 1.0; color: "#0a0f1e" }
                    }

                    border.width: 2
                    border.color: "#00d4ff"
                    radius: 8

                    // ✅ 科技感：外层发光
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        border.width: 1
                        border.color: "#00d4ff"
                        radius: 10
                        opacity: 0.3
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        // ✅ 科技感：标题带下划线
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "【皮带输送机】"
                                font.pixelSize: 20
                                font.bold: true
                                font.family: "Microsoft YaHei"
                                color: "#00d4ff"
                            }

                            Rectangle {
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 2
                                color: "#00d4ff"
                                opacity: 0.5
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 4
                            rowSpacing: 15
                            columnSpacing: 15

                            Repeater {
                                model: 8

                                DeviceStatusCard {
                                    deviceId: index + 1
                                    deviceName: (index + 1) + "号皮带"
                                    deviceType: "Belt"
                                    controlStation: index === 0 ? "主站" : ("分站" + index)
                                    isLocal: index === 0
                                    isOnline: index < 3
                                    status: index === 0 ? "运行中" : (index === 1 ? "运行中" : "停止")
                                    speed: index === 0 ? 1.2 : (index === 1 ? 1.3 : 0.0)
                                }
                            }
                        }
                    }
                }

                // 辅助设备区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 250
                    Layout.margins: 10

                    // ✅ 科技感：深色渐变背景
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#0f1a2e" }
                        GradientStop { position: 1.0; color: "#0a0f1e" }
                    }

                    border.width: 2
                    border.color: "#00d4ff"
                    radius: 8

                    // ✅ 科技感：外层发光
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        border.width: 1
                        border.color: "#00d4ff"
                        radius: 10
                        opacity: 0.3
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        // ✅ 科技感：标题带下划线
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: "【辅助设备】"
                                font.pixelSize: 20
                                font.bold: true
                                font.family: "Microsoft YaHei"
                                color: "#00d4ff"
                            }

                            Rectangle {
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 2
                                color: "#00d4ff"
                                opacity: 0.5
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 4
                            rowSpacing: 15
                            columnSpacing: 15

                            // 转载机
                            DeviceStatusCard {
                                deviceId: 9
                                deviceName: "转载机"
                                deviceType: "Loader"
                                controlStation: "主站"
                                isLocal: false
                                isOnline: true
                                status: "运行中"
                                speed: 0.8
                            }

                            // 破碎机
                            DeviceStatusCard {
                                deviceId: 10
                                deviceName: "破碎机"
                                deviceType: "Crusher"
                                controlStation: "主站"
                                isLocal: false
                                isOnline: true
                                status: "停止"
                                speed: 0.0
                            }

                            // 前刮板
                            DeviceStatusCard {
                                deviceId: 11
                                deviceName: "前刮板"
                                deviceType: "FrontScraper"
                                controlStation: "分站1"
                                isLocal: false
                                isOnline: false
                                status: ""
                                speed: 0.0
                            }

                            // 后刮板
                            DeviceStatusCard {
                                deviceId: 12
                                deviceName: "后刮板"
                                deviceType: "RearScraper"
                                controlStation: "分站1"
                                isLocal: false
                                isOnline: true
                                status: "运行中"
                                speed: 0.9
                            }
                        }
                    }
                }

                // 连锁关系图
                InterlockDiagram {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    Layout.margins: 10
                }

                // 底部填充
                Item {
                    Layout.fillHeight: true
                    Layout.preferredHeight: 20
                }
            }
        }
    }

    // ========== 定时刷新 ==========
    Timer {
        id: refreshTimer
        interval: 1000  // 1秒刷新一次
        running: true
        repeat: true
        onTriggered: {
            updateTimeText.text = "更新: " + Qt.formatTime(new Date(), "hh:mm:ss")
            // TODO: 更新设备状态
        }
    }

    // ========== 函数 ==========
    function refreshDeviceStatus() {
        console.log("🔄 [DeviceMonitorPage] 刷新所有设备状态")
        // TODO: 从 deviceRoleManager 获取最新状态
    }

    Component.onCompleted: {
        console.log("✅ [DeviceMonitorPage] 设备监控页面已加载")
    }
}
