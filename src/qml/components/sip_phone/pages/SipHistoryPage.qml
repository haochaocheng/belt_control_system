import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Call history page
Page {
    id: root

    signal callNumber(string number)

    // Inline RisipButton component
    component RisipButton: Button {
        id: control
        property color buttonColor: "#2c3e50"
        property color hoverColor: "#34495e"
        property color pressColor: "#2980b9"
        property color textColor: "#ffffff"
        property color borderColor: "#00d4ff"
        property int borderWidth: 2
        property int buttonRadius: 10
        property bool isHovered: false

        background: Rectangle {
            color: control.pressed ? control.pressColor : (control.isHovered ? control.hoverColor : control.buttonColor)
            radius: control.buttonRadius
            border.color: control.borderColor
            border.width: control.borderWidth
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        HoverHandler {
            onHoveredChanged: control.isHovered = hovered
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Toolbar with filters and clear button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RisipButton {
                id: allCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "全部"
                buttonColor: historyList.currentFilter === "all" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "all"
                }
            }

            RisipButton {
                id: missedCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "未接"
                buttonColor: historyList.currentFilter === "missed" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "missed"
                }
            }

            RisipButton {
                id: outgoingCallsBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                text: "已拨"
                buttonColor: historyList.currentFilter === "outgoing" ? "#2980b9" : "#34495e"

                onClicked: {
                    historyList.currentFilter = "outgoing"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RisipButton {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                text: "清空记录"
                buttonColor: "#e74c3c"

                onClicked: {
                    historyListModel.clear()
                }
            }
        }

        // History list header
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#0f3460"
            radius: 5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10

                Text {
                    text: "类型"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 60
                }

                Text {
                    text: "号码/姓名"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.fillWidth: true
                }

                Text {
                    text: "时间"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 150
                }

                Text {
                    text: "时长"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 80
                }

                Text {
                    text: "操作"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 50
                }
            }
        }

        // Original data model
        ListModel {
            id: historyListModel
            Component.onCompleted: {
                // Sample data - will be populated from C++ in real implementation
                append({type: "outgoing", name: "张三", number: "1001", date: "2025-01-15", time: "14:30", duration: 125})
                append({type: "incoming", name: "李四", number: "1002", date: "2025-01-15", time: "13:45", duration: 300})
                append({type: "missed", name: "王五", number: "1003", date: "2025-01-15", time: "12:20", duration: 0})
                append({type: "outgoing", name: "赵六", number: "1004", date: "2025-01-14", time: "16:10", duration: 85})
                append({type: "incoming", name: "钱七", number: "1005", date: "2025-01-14", time: "11:30", duration: 240})
                append({type: "missed", name: "孙八", number: "1006", date: "2025-01-14", time: "09:15", duration: 0})
                append({type: "outgoing", name: "周九", number: "1007", date: "2025-01-13", time: "15:25", duration: 180})
                append({type: "incoming", name: "吴十", number: "1008", date: "2025-01-13", time: "10:50", duration: 420})

                // Initialize filtered model
                updateFilteredModel()
            }
        }

        // Filtered model based on current filter
        ListModel {
            id: filteredHistoryModel
        }

        // Update filtered model when filter changes
        function updateFilteredModel() {
            filteredHistoryModel.clear()
            for (var i = 0; i < historyListModel.count; i++) {
                var item = historyListModel.get(i)
                if (historyList.currentFilter === "all" || item.type === historyList.currentFilter) {
                    filteredHistoryModel.append({
                        type: item.type,
                        name: item.name,
                        number: item.number,
                        date: item.date,
                        time: item.time,
                        duration: item.duration
                    })
                }
            }
        }

        // History list
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5

            property string currentFilter: "all"

            onCurrentFilterChanged: {
                root.updateFilteredModel()
            }

            // Use filtered model
            model: filteredHistoryModel

            delegate: Rectangle {
                width: historyList.width
                height: 60
                color: index % 2 === 0 ? "#1e2a3a" : "#16213e"
                radius: 5

                property bool isHovered: false

                Rectangle {
                    anchors.fill: parent
                    color: "#00d4ff"
                    opacity: parent.isHovered ? 0.1 : 0
                    radius: 5

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 10

                    // Call type icon
                    Text {
                        text: {
                            if (model.type === "outgoing") return "📤"
                            if (model.type === "incoming") return "📥"
                            if (model.type === "missed") return "❌"
                            return "📞"
                        }
                        font.pixelSize: 24
                        Layout.preferredWidth: 60
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Number and name
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.name
                            font.pixelSize: 16
                            font.bold: true
                            color: model.type === "missed" ? "#e74c3c" : "#ffffff"
                        }

                        Text {
                            text: model.number
                            font.pixelSize: 12
                            color: "#95a5a6"
                        }
                    }

                    // Date and time
                    ColumnLayout {
                        Layout.preferredWidth: 150
                        spacing: 2

                        Text {
                            text: model.date
                            font.pixelSize: 12
                            color: "#00d4ff"
                        }

                        Text {
                            text: model.time
                            font.pixelSize: 12
                            color: "#95a5a6"
                        }
                    }

                    // Duration
                    Text {
                        text: formatDuration(model.duration)
                        font.pixelSize: 14
                        color: "#ffffff"
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignRight
                    }

                    // Call back button
                    RisipButton {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 40
                        buttonRadius: 20
                        buttonColor: "#27ae60"
                        hoverColor: "#229954"
                        borderWidth: 1

                        contentItem: Text {
                            text: "📞"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            root.callNumber(model.number)
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: parent.isHovered = hovered
                }
            }

            // Custom scrollbar
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: 4
                    color: parent.pressed ? "#00d4ff" : "#34495e"
                    opacity: parent.active ? 1.0 : 0.5
                }
            }
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#0f3460"
            radius: 5

            Text {
                anchors.centerIn: parent
                text: "显示 " + filteredHistoryModel.count + " / " + historyListModel.count + " 条通话记录"
                font.pixelSize: 12
                color: "#95a5a6"
            }
        }
    }

    // Format duration from seconds to MM:SS
    function formatDuration(seconds) {
        if (seconds === 0) return "--:--"
        var mins = Math.floor(seconds / 60)
        var secs = seconds % 60
        return mins.toString().padStart(2, '0') + ":" + secs.toString().padStart(2, '0')
    }
}
