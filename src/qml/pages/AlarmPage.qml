import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

Item {
    id: root
    // ✅ 2026-02-11 [Phase 7.45.25]: 移除固定尺寸，避免与SwipeView冲突导致polish()循环
    // width: 1920   // ❌ 注释掉，SwipeView会自动管理尺寸
    // height: 1080  // ❌ 注释掉，SwipeView会自动管理尺寸
    anchors.fill: parent  // ✅ 使用anchors.fill自动填充

    // Main container
    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        color: "#1a1a2e"
        radius: 15

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // Header section
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                // Title
                Text {
                    text: "报警记录"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#00d4ff"
                    Layout.fillWidth: true
                }

                // Export button
                Button {
                    id: exportButton
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 45

                    property bool isHovered: false

                    background: Rectangle {
                        color: exportButton.pressed ? "#1e7e34" : (exportButton.isHovered ? "#28a745" : "#218838")
                        radius: 8
                        border.color: "#00ff88"
                        border.width: 2

                        // Glow effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            color: "transparent"
                            border.color: "#00ff88"
                            border.width: 1
                            radius: 10
                            opacity: 0.3
                            z: -1
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8

                        Text {
                            text: "📊"
                            font.pixelSize: 18
                            color: "white"
                        }

                        Text {
                            text: "导出Excel"
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    onClicked: {
                        console.log("Export to Excel clicked")
                        // TODO: Implement Excel export functionality
                    }

                    HoverHandler {
                        onHoveredChanged: exportButton.isHovered = hovered
                    }
                }

                // Refresh button
                Button {
                    id: refreshButton
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 45

                    property bool isHovered: false

                    background: Rectangle {
                        color: refreshButton.pressed ? "#1565c0" : (refreshButton.isHovered ? "#1e88e5" : "#1976d2")
                        radius: 8
                        border.color: "#00d4ff"
                        border.width: 2

                        // Glow effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            color: "transparent"
                            border.color: "#00d4ff"
                            border.width: 1
                            radius: 10
                            opacity: 0.3
                            z: -1
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8

                        Text {
                            text: "🔄"
                            font.pixelSize: 18
                            color: "white"
                        }

                        Text {
                            text: "刷新"
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    onClicked: {
                        console.log("Refresh clicked")
                        // TODO: Implement refresh functionality
                    }

                    HoverHandler {
                        onHoveredChanged: refreshButton.isHovered = hovered
                    }
                }

                // Clear button
                Button {
                    id: clearButton
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 45

                    property bool isHovered: false

                    background: Rectangle {
                        color: clearButton.pressed ? "#c62828" : (clearButton.isHovered ? "#e53935" : "#d32f2f")
                        radius: 8
                        border.color: "#ff5555"
                        border.width: 2

                        // Glow effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            color: "transparent"
                            border.color: "#ff5555"
                            border.width: 1
                            radius: 10
                            opacity: 0.3
                            z: -1
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8

                        Text {
                            text: "🗑️"
                            font.pixelSize: 18
                            color: "white"
                        }

                        Text {
                            text: "清空"
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    onClicked: {
                        console.log("Clear clicked")
                        // TODO: Implement clear functionality with confirmation
                    }

                    HoverHandler {
                        onHoveredChanged: clearButton.isHovered = hovered
                    }
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                height: 2
                color: "#00d4ff"
                opacity: 0.5
            }

            // Table container
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#16213e"
                radius: 10
                border.color: "#00d4ff"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 0

                    // Table header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 50
                        color: "#0f3460"
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15
                            spacing: 10

                            // 序号
                            Text {
                                text: "序号"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 80
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 2
                                Layout.fillHeight: true
                                color: "#00d4ff"
                                opacity: 0.3
                            }

                            // 报警日期
                            Text {
                                text: "报警日期"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 150
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 2
                                Layout.fillHeight: true
                                color: "#00d4ff"
                                opacity: 0.3
                            }

                            // 报警时间
                            Text {
                                text: "报警时间"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#00d4ff"
                                Layout.preferredWidth: 120
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 2
                                Layout.fillHeight: true
                                color: "#00d4ff"
                                opacity: 0.3
                            }

                            // 报警内容
                            Text {
                                text: "报警内容"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#00d4ff"
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                leftPadding: 20
                            }
                        }
                    }

                    // Table content with scrollable list
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        ScrollView {
                            id: scrollView
                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                width: 12

                                contentItem: Rectangle {
                                    implicitWidth: 8
                                    radius: 4
                                    color: parent.pressed ? "#00d4ff" : (parent.hovered ? "#00a8cc" : "#0f3460")
                                    opacity: parent.pressed || parent.hovered ? 1.0 : 0.6

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                background: Rectangle {
                                    color: "#1a1a2e"
                                    radius: 4
                                    opacity: 0.3
                                }
                            }

                            ListView {
                                id: alarmListView
                                width: parent.width
                                spacing: 2
                                clip: true

                                // Sample data model - replace with database connection later
                                model: ListModel {
                                    id: alarmModel

                                    // Sample data (最新的在最上面)
                                    ListElement {
                                        index: 1
                                        date: "2025-11-25"
                                        time: "14:35:22"
                                        content: "皮带速度超过上限，当前速度 5.2 m/s"
                                        level: "error"
                                    }
                                    ListElement {
                                        index: 2
                                        date: "2025-11-25"
                                        time: "14:30:15"
                                        content: "皮带张力异常，张力值 850 N"
                                        level: "warning"
                                    }
                                    ListElement {
                                        index: 3
                                        date: "2025-11-25"
                                        time: "14:25:08"
                                        content: "电机温度偏高，当前温度 78°C"
                                        level: "warning"
                                    }
                                    ListElement {
                                        index: 4
                                        date: "2025-11-25"
                                        time: "14:20:33"
                                        content: "系统启动完成"
                                        level: "info"
                                    }
                                    ListElement {
                                        index: 5
                                        date: "2025-11-25"
                                        time: "13:45:19"
                                        content: "通讯超时，模块地址 192.168.1.100"
                                        level: "error"
                                    }
                                    ListElement {
                                        index: 6
                                        date: "2025-11-25"
                                        time: "12:30:42"
                                        content: "皮带跑偏检测到异常"
                                        level: "warning"
                                    }
                                    ListElement {
                                        index: 7
                                        date: "2025-11-25"
                                        time: "11:15:27"
                                        content: "保护装置测试完成"
                                        level: "info"
                                    }
                                    ListElement {
                                        index: 8
                                        date: "2025-11-25"
                                        time: "10:00:00"
                                        content: "日常维护提醒"
                                        level: "info"
                                    }
                                    ListElement {
                                        index: 9
                                        date: "2025-11-24"
                                        time: "18:30:55"
                                        content: "急停按钮被触发"
                                        level: "error"
                                    }
                                    ListElement {
                                        index: 10
                                        date: "2025-11-24"
                                        time: "16:45:12"
                                        content: "速度传感器信号弱"
                                        level: "warning"
                                    }
                                }

                                delegate: Rectangle {
                                    width: alarmListView.width
                                    height: 55
                                    color: {
                                        if (model.level === "error") return "#3d1f1f"
                                        if (model.level === "warning") return "#3d331f"
                                        return index % 2 === 0 ? "#1e2a3a" : "#16213e"
                                    }
                                    radius: 4

                                    // Hover effect
                                    HoverHandler {
                                        id: rowHoverHandler
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#00d4ff"
                                        opacity: rowHoverHandler.hovered ? 0.1 : 0
                                        radius: 4

                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }

                                    // Left indicator bar
                                    Rectangle {
                                        x: 0
                                        y: 5
                                        width: 4
                                        height: parent.height - 10
                                        radius: 2
                                        color: {
                                            if (model.level === "error") return "#ff5555"
                                            if (model.level === "warning") return "#ffaa00"
                                            return "#00ff88"
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 15
                                        anchors.rightMargin: 15
                                        spacing: 10

                                        // 序号
                                        Text {
                                            text: model.index
                                            font.pixelSize: 15
                                            font.bold: true
                                            color: {
                                                if (model.level === "error") return "#ff5555"
                                                if (model.level === "warning") return "#ffaa00"
                                                return "#00d4ff"
                                            }
                                            Layout.preferredWidth: 80
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: "#00d4ff"
                                            opacity: 0.2
                                        }

                                        // 报警日期
                                        Text {
                                            text: model.date
                                            font.pixelSize: 14
                                            color: "#ecf0f1"
                                            Layout.preferredWidth: 150
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: "#00d4ff"
                                            opacity: 0.2
                                        }

                                        // 报警时间
                                        Text {
                                            text: model.time
                                            font.pixelSize: 14
                                            color: "#ecf0f1"
                                            Layout.preferredWidth: 120
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: "#00d4ff"
                                            opacity: 0.2
                                        }

                                        // 报警内容
                                        Text {
                                            text: model.content
                                            font.pixelSize: 14
                                            color: "#ffffff"
                                            Layout.fillWidth: true
                                            leftPadding: 20
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Status bar at bottom
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: "#0f3460"
                radius: 8
                border.color: "#00d4ff"
                border.width: 1
                opacity: 0.8

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 20

                    Text {
                        text: "📊 总记录数: " + alarmModel.count
                        font.pixelSize: 13
                        color: "#00d4ff"
                        font.bold: true
                    }

                    Rectangle {
                        width: 2
                        height: 20
                        color: "#00d4ff"
                        opacity: 0.3
                    }

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            color: "#ff5555"
                        }
                        Text {
                            text: "严重"
                            font.pixelSize: 12
                            color: "#ecf0f1"
                        }
                    }

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            color: "#ffaa00"
                        }
                        Text {
                            text: "警告"
                            font.pixelSize: 12
                            color: "#ecf0f1"
                        }
                    }

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            color: "#00ff88"
                        }
                        Text {
                            text: "信息"
                            font.pixelSize: 12
                            color: "#ecf0f1"
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "💾 数据库连接: 未连接"
                        font.pixelSize: 12
                        color: "#95a5a6"
                        font.italic: true
                    }
                }
            }
        }
    }
}
