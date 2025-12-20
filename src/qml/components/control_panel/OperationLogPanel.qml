import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Operation Log Panel - Shows system operation events from database
// Right side, above the chart
Rectangle {
    id: root
    width: 400
    height: 300
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // Monitor database log additions
    Connections {
        target: operationLogDB
        function onLogAdded(timestamp, workMode, triggerType, operation, deviceName, detail) {
            console.log("📥 OperationLogPanel: 收到新日志 -", timestamp, operation, deviceName)
            refreshLogs()
        }
    }

    // Load logs when component is ready
    Component.onCompleted: {
        refreshLogs()
    }

    // Refresh logs from database
    function refreshLogs() {
        if (operationLogDB) {
            logModel.clear()
            var logs = operationLogDB.getRecentLogs(50)  // Get 50 most recent logs
            for (var i = 0; i < logs.length; i++) {
                var log = logs[i]
                // Format the event text from database fields
                var eventText = formatEventText(log)
                // Determine level based on operation type
                var level = getLogLevel(log.operation)

                logModel.append({
                    timestamp: log.timestamp,
                    event: eventText,
                    level: level
                })
            }
            console.log("✅ OperationLogPanel: 已加载", logs.length, "条日志记录")
        }
    }

    // Format event text from database log entry
    function formatEventText(log) {
        var text = ""
        if (log.deviceName) {
            text = log.operation + ": " + log.deviceName
        } else {
            text = log.operation
        }
        if (log.detail) {
            text += " (" + log.detail + ")"
        }
        return text
    }

    // Determine log level based on operation type
    function getLogLevel(operation) {
        if (operation.includes("启动") || operation.includes("开始")) {
            return "success"
        } else if (operation.includes("停止") || operation.includes("结束")) {
            return "info"
        } else if (operation.includes("预警") || operation.includes("警告")) {
            return "warning"
        } else if (operation.includes("错误") || operation.includes("失败")) {
            return "error"
        }
        return "info"
    }

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

    // Public function to add log entry (for UI operations)
    // This will write to database, which will trigger onLogAdded and refresh the view
    function addLog(event, level) {
        level = level || "info"

        if (operationLogDB && systemConfig) {
            // Get current work mode
            var workModeName = "未知"
            var workMode = systemConfig.workMode
            switch (workMode) {
                case 0: workModeName = "检修"; break
                case 1: workModeName = "就地"; break
                case 2: workModeName = "点动"; break
                case 3: workModeName = "集控"; break
            }

            // Write to database (this will trigger refreshLogs via onLogAdded signal)
            operationLogDB.logOperation(workModeName, "界面操作", event, "", "")
        }
    }
}
