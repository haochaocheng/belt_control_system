import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ✅ 2026-02-10 [Phase 7.45.7]: 设备监控页面
// 显示所有设备和集控设备的实时状态
// 作为独立页面，而不是Dialog弹窗
Rectangle {
    id: root
    anchors.fill: parent
    color: "#0a0f1e"

    // ========== 主内容区域 ==========
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // ========== 标题栏 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1a1f2e"
            border.width: 3
            border.color: "#00d4ff"
            radius: 10

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20

                Text {
                    text: "【设备监控】"
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "Microsoft YaHei"
                    color: "#00d4ff"
                    style: Text.Outline
                    styleColor: "#00d4ff"
                }

                Item { Layout.fillWidth: true }

                // 刷新按钮
                Button {
                    text: "🔄 刷新"
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.pressed ? "#2a3f5f" : (parent.hovered ? "#1a2f4f" : "#0a0f1e")
                        border.width: 2
                        border.color: "#00d4ff"
                        radius: 5
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 18
                        font.family: "Microsoft YaHei"
                        color: "#00d4ff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("🔄 [DeviceMonitorPage] 刷新设备状态")
                        refreshDeviceStatus()
                    }
                }
            }
        }

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
                    color: "#1a1f2e"
                    border.width: 3
                    border.color: "#00ff00"
                    radius: 8

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

                                SequentialAnimation on opacity {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
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

                        Rectangle { width: 2; Layout.fillHeight: true; color: "#2a3f5f" }

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
                    color: "transparent"
                    border.width: 2
                    border.color: "#00d4ff"
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        Text {
                            text: "【集控设备】"
                            font.pixelSize: 20
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
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
                    color: "transparent"
                    border.width: 2
                    border.color: "#00d4ff"
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        Text {
                            text: "【皮带输送机】"
                            font.pixelSize: 20
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
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
                    color: "transparent"
                    border.width: 2
                    border.color: "#00d4ff"
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        Text {
                            text: "【辅助设备】"
                            font.pixelSize: 20
                            font.bold: true
                            font.family: "Microsoft YaHei"
                            color: "#00d4ff"
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
