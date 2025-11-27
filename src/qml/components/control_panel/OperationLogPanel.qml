import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Operation Log Panel - Shows system operation events
// Right side, above the chart
Rectangle {
    id: root
    width: 400
    height: 300
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Title
        Text {
            text: "运行信息"
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

        // Log list
        ListView {
            id: logListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4

            model: ListModel {
                id: logModel

                Component.onCompleted: {
                    // Sample data
                    append({
                        timestamp: "2025-11-21 14:32:15",
                        event: "按键总起按下",
                        level: "info"
                    })
                    append({
                        timestamp: "2025-11-21 14:32:18",
                        event: "电机1启动",
                        level: "success"
                    })
                    append({
                        timestamp: "2025-11-21 14:35:42",
                        event: "速度参数修改: 2.5 → 3.0 m/s",
                        level: "info"
                    })
                    append({
                        timestamp: "2025-11-21 14:38:10",
                        event: "保护投入: 速度保护",
                        level: "info"
                    })
                    append({
                        timestamp: "2025-11-21 14:40:22",
                        event: "温度报警: 85°C",
                        level: "warning"
                    })
                }
            }

            delegate: Rectangle {
                width: logListView.width
                height: 34
                color: index % 2 === 0 ? "#2c3e50" : "#34495e"
                radius: 5

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = "#3d566e"
                    onExited: parent.color = index % 2 === 0 ? "#2c3e50" : "#34495e"
                }

                RowLayout {
                    id: logContent
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 8

                    // Level indicator
                    Rectangle {
                        width: 4
                        height: parent.height
                        radius: 2
                        color: getLevelColor(model.level)
                    }

                    // Timestamp
                    Text {
                        text: model.timestamp
                        font.pixelSize: 10
                        font.family: "Consolas"
                        color: "#95a5a6"
                        Layout.preferredWidth: 125
                    }

                    // Event description
                    Text {
                        text: model.event
                        font.pixelSize: 11
                        color: "#ecf0f1"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 8

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: 4
                    color: "#00d4ff"
                    opacity: 0.6
                }
            }
        }
    }

    // Helper function
    function getLevelColor(level) {
        switch(level) {
            case "success": return "#00ff88"
            case "info": return "#3498db"
            case "warning": return "#f39c12"
            case "error": return "#ff4757"
            default: return "#95a5a6"
        }
    }

    // Public function to add log entry
    function addLog(event, level) {
        level = level || "info"
        var now = new Date()
        var timestamp = Qt.formatDateTime(now, "yyyy-MM-dd hh:mm:ss")

        logModel.insert(0, {
            timestamp: timestamp,
            event: event,
            level: level
        })

        // Keep only last 100 entries
        if (logModel.count > 100) {
            logModel.remove(100, logModel.count - 100)
        }
    }
}
