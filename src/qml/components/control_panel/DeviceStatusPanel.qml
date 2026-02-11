import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Device Status Panel - Left Top Corner
// Shows: Mode, Status, Runtime Statistics, Communication Status
// 2026-02-11: 使用图片作为背景，移除原有的矩形边框和颜色
Item {
    id: root
    width: 280
    height: 320

    // 背景图片
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "../../images/info_lift.png"
        fillMode: Image.PreserveAspectFit
    }

    // 2026-02-11: 注释掉原有的矩形背景和边框
    // Rectangle {
    //     id: root
    //     width: 280
    //     height: 320
    //     color: "#dd1a2332"
    //     radius: 10
    //     border.color: "#00d4ff"
    //     border.width: 2
    // }

    // 从SystemConfig和RuntimeTracker获取数据
    property string operationMode: getWorkModeName()
    property string deviceName: systemConfig ? systemConfig.localDeviceName : "1号皮带"
    property string deviceStatus: runtimeTracker ? runtimeTracker.currentStatus : "停止"
    property string detailedStatus: runtimeTracker ? runtimeTracker.detailedStatus : "停车"
    property bool isRunning: runtimeTracker ? runtimeTracker.isRunning : false
    property bool isFault: runtimeTracker ? runtimeTracker.isFault : false

    // 运行时间统计
    property string dailyRuntime: runtimeTracker ? runtimeTracker.dailyRuntime : "00:00:00"
    property string weeklyRuntime: runtimeTracker ? runtimeTracker.weeklyRuntime : "00:00:00"
    property string monthlyRuntime: runtimeTracker ? runtimeTracker.monthlyRuntime : "00:00:00"

    // 开机率统计
    property real dailyUptime: runtimeTracker ? runtimeTracker.dailyUptime : 0.0
    property real weeklyUptime: runtimeTracker ? runtimeTracker.weeklyUptime : 0.0
    property real monthlyUptime: runtimeTracker ? runtimeTracker.monthlyUptime : 0.0

    property bool mainStationConnected: true

    // 获取工作模式名称
    function getWorkModeName() {
        if (!systemConfig) return "集控"
        switch (systemConfig.workMode) {
            case 0: return "检修"
            case 1: return "就地"
            case 2: return "点动"
            case 3: return "集控"
            default: return "集控"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // 2026-02-11: 注释掉标题和分隔线，图片背景已包含
        // // Title
        // Text {
        //     text: "设备信息"
        //     font.pixelSize: 18
        //     font.bold: true
        //     color: "#00d4ff"
        //     Layout.alignment: Qt.AlignHCenter
        // }

        // Rectangle {
        //     Layout.fillWidth: true
        //     height: 2
        //     color: "#00d4ff"
        //     opacity: 0.5
        // }

        // Mode and Name - Side by side
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // Left column - Mode
            RowLayout {
                spacing: 10

                Text {
                    text: "模式："
                    font.pixelSize: 14
                    color: "#95a5a6"
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 28
                    radius: 5
                    color: getModeColor(root.operationMode)
                    border.color: "#00d4ff"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.operationMode
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                    }
                }
            }

            // Right column - Device Name
            RowLayout {
                spacing: 10

                Text {
                    text: "名称："
                    font.pixelSize: 14
                    color: "#95a5a6"
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 28
                    radius: 5
                    color: "#3498db"
                    border.color: "#00d4ff"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.deviceName
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                    }
                }
            }
        }

        // 状态显示（完整宽度，显示详细状态）
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "状态："
                font.pixelSize: 14
                color: "#95a5a6"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 5
                color: getDetailedStatusColor()
                border.color: "#00d4ff"
                border.width: 2

                // 根据状态添加动画效果
                SequentialAnimation on opacity {
                    running: root.isRunning && !root.isFault
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.7; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.detailedStatus
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#34495e"
        }

        // Runtime Statistics - Side by side layout
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 130
                spacing: 5

                Text {
                    text: "开机时间累计"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#00ff88"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 3
                    columnSpacing: 5

                    Text { text: "日："; font.pixelSize: 10; color: "#95a5a6" }
                    Text { text: root.dailyRuntime; font.pixelSize: 10; color: "#00d4ff"; font.bold: true }

                    Text { text: "周："; font.pixelSize: 10; color: "#95a5a6" }
                    Text { text: root.weeklyRuntime; font.pixelSize: 10; color: "#00d4ff"; font.bold: true }

                    Text { text: "月："; font.pixelSize: 10; color: "#95a5a6" }
                    Text { text: root.monthlyRuntime; font.pixelSize: 10; color: "#00d4ff"; font.bold: true }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: "#34495e"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 100
                spacing: 5

                Text {
                    text: "开机率统计"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#00ff88"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 3
                    columnSpacing: 5

                    Text { text: "日："; font.pixelSize: 10; color: "#95a5a6" }
                    Text { text: root.dailyUptime.toFixed(1) + "%"; font.pixelSize: 10; color: "#00d4ff"; font.bold: true }

                    Text { text: "周："; font.pixelSize: 10; color: "#95a5a6" }
                    Text { text: root.weeklyUptime.toFixed(1) + "%"; font.pixelSize: 10; color: "#00d4ff"; font.bold: true }

                    Text { text: "月："; font.pixelSize: 10; color: "#95a5a6" }
                    Text { text: root.monthlyUptime.toFixed(1) + "%"; font.pixelSize: 10; color: "#00d4ff"; font.bold: true }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#34495e"
        }

        // Communication Status
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "主站通讯："
                font.pixelSize: 13
                color: "#95a5a6"
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: root.mainStationConnected ? "#00ff88" : "#ff4757"

                SequentialAnimation on opacity {
                    running: root.mainStationConnected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }

            Text {
                text: root.mainStationConnected ? "在线" : "离线"
                font.pixelSize: 13
                color: root.mainStationConnected ? "#00ff88" : "#ff4757"
                font.bold: true
            }
        }
    }

    // Helper functions
    function getModeColor(mode) {
        switch(mode) {
            case "集控": return "#3498db"
            case "就地": return "#f39c12"
            case "检修": return "#e74c3c"
            case "点动": return "#9b59b6"
            default: return "#95a5a6"
        }
    }

    function getStatusColor(status) {
        switch(status) {
            case "运行": return "#00ff88"
            case "停止": return "#95a5a6"
            case "故障": return "#ff4757"
            default: return "#95a5a6"
        }
    }

    function getDetailedStatusColor() {
        if (root.isFault) {
            return "#ff4757"  // 红色 - 故障停止
        } else if (root.isRunning) {
            return "#00ff88"  // 绿色 - 运行
        } else if (root.deviceStatus === "启动中") {
            return "#ffa502"  // 橙色 - 启动中
        } else if (root.deviceStatus === "停止中") {
            return "#3498db"  // 蓝色 - 停止中
        } else {
            return "#95a5a6"  // 灰色 - 停止
        }
    }
}
