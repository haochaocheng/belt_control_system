import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Device Status Panel - Left Top Corner
// Shows: Mode, Status, Runtime Statistics, Communication Status
Rectangle {
    id: root
    width: 280
    height: 320
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // Public properties - driven by backend
    property string operationMode: "集控"  // 就地/检修/集控/点动
    property string deviceName: "1号皮带"  // Device name (configurable)
    property string deviceStatus: "运行"   // 停止/运行/故障
    property string dailyRuntime: "18:32:15"
    property string weeklyRuntime: "125:45:30"
    property string monthlyRuntime: "520:12:45"
    property real dailyUptime: 85.5      // percentage
    property real weeklyUptime: 82.3
    property real monthlyUptime: 88.7
    property real yearlyUptime: 86.2
    property bool mainStationConnected: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // Title
        Text {
            text: "设备信息"
            font.pixelSize: 18
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#00d4ff"
            opacity: 0.5
        }

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

        // Status and Device Status - Side by side
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // Left column - Status (original)
            RowLayout {
                spacing: 10

                Text {
                    text: "状态："
                    font.pixelSize: 14
                    color: "#95a5a6"
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 28
                    radius: 5
                    color: getStatusColor(root.deviceStatus)
                    border.color: "#00d4ff"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.deviceStatus
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                    }
                }
            }

            // Right column - Device (same as deviceStatus)
            RowLayout {
                spacing: 10

                Text {
                    text: "设备："
                    font.pixelSize: 14
                    color: "#95a5a6"
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 28
                    radius: 5
                    color: getStatusColor(root.deviceStatus)
                    border.color: "#00d4ff"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.deviceStatus
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                    }
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
}
