import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import "../components/common"

/**
 * 设备运行信息页面
 *
 * 功能:
 * - 显示所有设备运行日志记录
 * - 使用数据库永久保存
 * - 记录工作模式、触发方式、预警时间、设备启动时间等
 * - 最新记录在最上面
 * - 支持滚动查看历史记录
 */
Item {
    id: root
    // ✅ 2026-02-11 [Phase 7.45.25]: 移除固定尺寸，避免与SwipeView冲突导致polish()循环
    // width: 1920   // ❌ 注释掉，SwipeView会自动管理尺寸
    // height: 1080  // ❌ 注释掉，SwipeView会自动管理尺寸
    // ✅ SwipeView 子页由 SwipeView 自动管理几何，不要在根节点设置 anchors

    // 监听数据库新日志添加信号
    Connections {
        target: operationLogDB
        function onLogAdded(timestamp, workMode, triggerType, operation, deviceName, detail) {
            console.log("📥 DeviceOperationLog: 收到新日志 -", timestamp, workMode, operation, deviceName)
            // 刷新日志列表
            refreshLogs()
        }
    }

    // 页面加载完成时刷新日志
    Component.onCompleted: {
        refreshLogs()
    }

    // 刷新日志列表
    function refreshLogs() {
        if (operationLogDB) {
            logListModel.clear()
            var logs = operationLogDB.getRecentLogs(500)  // 获取最近500条记录
            for (var i = 0; i < logs.length; i++) {
                logListModel.append(logs[i])
            }
            console.log("✅ DeviceOperationLog: 已加载", logs.length, "条日志记录")
        }
    }

    // Background
    Rectangle {
        anchors.fill: parent
        color: "#0a1628"
    }

    // Header
    Header {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // Main content area
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10
        color: "#dd1a2332"
        radius: 10
        border.color: "#00d4ff"
        border.width: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            // Title and controls row
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Text {
                    text: "设备运行信息"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#00d4ff"
                }

                Item { Layout.fillWidth: true }

                // Log count
                Text {
                    text: "总记录数: " + logListModel.count
                    font.pixelSize: 16
                    color: "#95a5a6"
                }

                // Refresh button
                Button {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40

                    background: Rectangle {
                        color: parent.pressed ? "#16a085" : (parent.hovered ? "#1abc9c" : "#00d4ff")
                        radius: 5
                    }

                    contentItem: Text {
                        text: "刷新"
                        color: "#0a1628"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        refreshLogs()
                    }
                }

                // Clear old logs button
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40

                    background: Rectangle {
                        color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#ff4757")
                        radius: 5
                    }

                    contentItem: Text {
                        text: "清理30天前"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (operationLogDB) {
                            operationLogDB.clearOldLogs(30)
                            refreshLogs()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 2
                color: "#00d4ff"
                opacity: 0.5
            }

            // Table header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "#1a2332"
                radius: 5

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        text: "时间"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.preferredWidth: 180
                    }

                    Text {
                        text: "工作模式"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.preferredWidth: 100
                    }

                    Text {
                        text: "触发方式"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.preferredWidth: 100
                    }

                    Text {
                        text: "操作"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.preferredWidth: 120
                    }

                    Text {
                        text: "设备名称"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.preferredWidth: 120
                    }

                    Text {
                        text: "详细信息"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.fillWidth: true
                    }
                }
            }

            // Scrollable log list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ListView {
                    id: logListView
                    anchors.fill: parent
                    spacing: 5

                    model: ListModel {
                        id: logListModel
                    }

                    delegate: Rectangle {
                        width: logListView.width
                        height: 50
                        color: index % 2 === 0 ? "#0f1a2a" : "#1a2332"
                        radius: 5

                        // Hover effect
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = "#2a3f54"
                            onExited: parent.color = index % 2 === 0 ? "#0f1a2a" : "#1a2332"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5

                            Text {
                                text: model.timestamp || ""
                                font.pixelSize: 14
                                color: "#ecf0f1"
                                Layout.preferredWidth: 180
                                elide: Text.ElideRight
                            }

                            Text {
                                text: model.workMode || ""
                                font.pixelSize: 14
                                color: getWorkModeColor(model.workMode)
                                font.bold: true
                                Layout.preferredWidth: 100
                            }

                            Text {
                                text: model.triggerType || ""
                                font.pixelSize: 14
                                color: "#95a5a6"
                                Layout.preferredWidth: 100
                            }

                            Text {
                                text: model.operation || ""
                                font.pixelSize: 14
                                color: getOperationColor(model.operation)
                                font.bold: true
                                Layout.preferredWidth: 120
                            }

                            Text {
                                text: model.deviceName || "-"
                                font.pixelSize: 14
                                color: "#00d4ff"
                                Layout.preferredWidth: 120
                                elide: Text.ElideRight
                            }

                            Text {
                                text: model.detail || "-"
                                font.pixelSize: 14
                                color: "#7f8c8d"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Status bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "#1a2332"
                radius: 5

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 20

                    Text {
                        text: "💡 提示: 最新记录显示在最上面"
                        font.pixelSize: 14
                        color: "#95a5a6"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "数据库: operation_logs.db"
                        font.pixelSize: 12
                        color: "#7f8c8d"
                    }
                }
            }
        }
    }

    // Helper functions for colors
    function getWorkModeColor(workMode) {
        switch (workMode) {
            case "检修": return "#ff9800"  // Orange
            case "就地": return "#4caf50"  // Green
            case "点动": return "#2196f3"  // Blue
            case "集控": return "#9c27b0"  // Purple
            default: return "#95a5a6"
        }
    }

    function getOperationColor(operation) {
        if (operation.includes("启动") || operation.includes("开始")) {
            return "#00ff88"  // Green
        } else if (operation.includes("停止") || operation.includes("结束")) {
            return "#ff4757"  // Red
        } else if (operation.includes("预警")) {
            return "#ffa502"  // Orange
        }
        return "#ecf0f1"  // White
    }
}
