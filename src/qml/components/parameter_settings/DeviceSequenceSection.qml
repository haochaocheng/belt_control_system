import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Device Startup/Stop Sequence Section Component - Redesigned with Popup Selection
Rectangle {
    id: root
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // 移除 implicit 尺寸，让 GridLayout 完全控制

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Section Title
        Text {
            text: "设备启动/停止顺序"
            font.pixelSize: 20
            font.bold: true
            color: "#00d4ff"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#00d4ff"
            opacity: 0.5
        }

        // Main content area - two columns
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 0

            // Left column - Startup Sequence
            SequenceColumn {
                id: startupColumn
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "启动顺序"
                titleColor: "#00ff88"
                borderColor: "#00ff88"
                buttonColor: "#5dade2"
                buttonHoverColor: "#3498db"
                buttonPressedColor: "#2980b9"
                sequenceList: systemConfig ? systemConfig.startupSequence : []
                onSequenceChanged: function(newSequence) {
                    if (systemConfig) {
                        systemConfig.startupSequence = newSequence
                    }
                }
            }

            // Right column - Stop Sequence
            SequenceColumn {
                id: stopColumn
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "停止顺序"
                titleColor: "#ff4757"
                borderColor: "#ff4757"
                buttonColor: "#ec7063"
                buttonHoverColor: "#e74c3c"
                buttonPressedColor: "#c0392b"
                sequenceList: systemConfig ? systemConfig.stopSequence : []
                onSequenceChanged: function(newSequence) {
                    if (systemConfig) {
                        systemConfig.stopSequence = newSequence
                    }
                }
            }
        }
    }

    // Device Selection Popup (shared by both columns)
    Popup {
        id: deviceSelectionPopup
        width: 500
        height: 600
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: Overlay.overlay

        signal deviceSelected(string deviceName)

        property var availableDevices: [
            "张紧", "抱闸", "洒水", "1号电机", "2号电机",
            "破碎机", "转载机", "前刮板", "后刮板",
            "1号乳化液泵", "2号乳化液泵", "3号乳化液泵", "4号乳化液泵",
            "1号喷雾泵", "2号喷雾泵", "3号喷雾泵", "4号喷雾泵"
        ]

        background: Rectangle {
            color: "#1a2332"
            border.color: "#00d4ff"
            border.width: 3
            radius: 10
        }

        onDeviceSelected: function(deviceName) {
            if (currentEditingColumn) {
                currentEditingColumn.replaceDevice(currentEditingIndex, deviceName)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Text {
                text: "选择设备"
                font.pixelSize: 22
                font.bold: true
                color: "#00d4ff"
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: "#00d4ff"
                opacity: 0.5
            }

            ListView {
                id: deviceListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: deviceSelectionPopup.availableDevices

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 50
                    color: deviceMouseArea.pressed ? "#2a3f54" : (deviceMouseArea.containsMouse ? "#1f2f3f" : "#1a2332")
                    border.color: "#00d4ff"
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 18
                        color: "#ecf0f1"
                    }

                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            deviceSelectionPopup.deviceSelected(modelData)
                            deviceSelectionPopup.close()
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    width: 12
                    contentItem: Rectangle {
                        implicitWidth: 12
                        radius: 6
                        color: parent.pressed ? "#00d4ff" : "#34495e"
                    }
                }
            }

            Button {
                text: "取消"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                Layout.preferredHeight: 45

                background: Rectangle {
                    color: parent.pressed ? "#95a5a6" : (parent.hovered ? "#7f8c8d" : "#34495e")
                    radius: 6
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: deviceSelectionPopup.close()
            }
        }
    }

    property var currentEditingColumn: null
    property int currentEditingIndex: -1

    function openDeviceSelection(column, index) {
        currentEditingColumn = column
        currentEditingIndex = index
        deviceSelectionPopup.open()
    }

    // Component: Sequence Column (Startup or Stop)
    component SequenceColumn: ColumnLayout {
        id: column
        spacing: 8

        property string title: ""
        property color titleColor: "#00d4ff"
        property color borderColor: "#00d4ff"
        property color buttonColor: "#5dade2"
        property color buttonHoverColor: "#3498db"
        property color buttonPressedColor: "#2980b9"
        property var sequenceList: []
        signal sequenceChanged(var newSequence)

        function addDevice() {
            if (sequenceList.length >= 10) {
                console.warn("最多支持10个设备")
                return
            }
            var newSeq = sequenceList.slice()
            newSeq.push("未设置")
            sequenceChanged(newSeq)
        }

        function replaceDevice(index, deviceName) {
            var newSeq = sequenceList.slice()
            newSeq[index] = deviceName
            sequenceChanged(newSeq)
        }

        function deleteDevice(index) {
            var newSeq = sequenceList.slice()
            newSeq.splice(index, 1)
            sequenceChanged(newSeq)
        }

        function moveUp(index) {
            if (index > 0) {
                var newSeq = sequenceList.slice()
                var temp = newSeq[index]
                newSeq[index] = newSeq[index - 1]
                newSeq[index - 1] = temp
                sequenceChanged(newSeq)
            }
        }

        function moveDown(index) {
            if (index < sequenceList.length - 1) {
                var newSeq = sequenceList.slice()
                var temp = newSeq[index]
                newSeq[index] = newSeq[index + 1]
                newSeq[index + 1] = temp
                sequenceChanged(newSeq)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: "#1a2332"
            radius: 5
            border.color: column.borderColor
            border.width: 2

            Text {
                anchors.centerIn: parent
                text: column.title
                font.pixelSize: 18
                font.bold: true
                color: column.titleColor
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: "#0f1821"
            border.color: column.borderColor
            border.width: 1
            radius: 3

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Text {
                    Layout.preferredWidth: 35
                    text: "序号"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#95a5a6"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: "设备名称"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#95a5a6"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.preferredWidth: 70
                    text: "延时(秒)"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#95a5a6"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.preferredWidth: 120
                    text: "操作"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#95a5a6"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        ListView {
            id: deviceListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            interactive: true  // Enable scrolling to view all devices

            model: column.sequenceList

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 10
                contentItem: Rectangle {
                    implicitWidth: 10
                    radius: 5
                    color: parent.pressed ? column.borderColor : "#34495e"
                }
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: 45
                color: "#1a2332"
                radius: 5
                border.color: column.borderColor
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    Rectangle {
                        Layout.preferredWidth: 35
                        Layout.fillHeight: true
                        color: column.titleColor
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: (index + 1).toString()
                            font.pixelSize: 16
                            font.bold: true
                            color: "#1a2332"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        // 判断是否为故障设备
                        property bool isFaultDevice: runtimeTracker && runtimeTracker.faultDevices.indexOf(modelData) !== -1
                        color: isFaultDevice ? "#ff4757" : (deviceNameMouseArea.pressed ? "#2a3f54" : (deviceNameMouseArea.containsMouse ? "#1f2f3f" : "transparent"))
                        radius: 4
                        border.color: isFaultDevice ? "#ff6677" : (deviceNameMouseArea.containsMouse ? column.borderColor : "transparent")
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 15
                            font.bold: parent.isFaultDevice
                            color: parent.isFaultDevice ? "#ffffff" : "#ecf0f1"
                        }

                        MouseArea {
                            id: deviceNameMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.openDeviceSelection(column, index)
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: 70
                        text: "1.0"
                        font.pixelSize: 14
                        color: "#95a5a6"
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.preferredWidth: 120
                        spacing: 3

                        Button {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            visible: index > 0
                            enabled: index > 0

                            background: Rectangle {
                                color: parent.pressed ? column.buttonPressedColor : (parent.hovered ? column.buttonHoverColor : column.buttonColor)
                                radius: 4
                            }

                            contentItem: Text {
                                text: "↑"
                                font.pixelSize: 16
                                font.bold: true
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: column.moveUp(index)
                        }

                        Button {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            visible: index < deviceListView.count - 1
                            enabled: index < deviceListView.count - 1

                            background: Rectangle {
                                color: parent.pressed ? column.buttonPressedColor : (parent.hovered ? column.buttonHoverColor : column.buttonColor)
                                radius: 4
                            }

                            contentItem: Text {
                                text: "↓"
                                font.pixelSize: 16
                                font.bold: true
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: column.moveDown(index)
                        }

                        Button {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            background: Rectangle {
                                color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#95a5a6")
                                radius: 4
                            }

                            contentItem: Text {
                                text: "×"
                                font.pixelSize: 20
                                font.bold: true
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: column.deleteDevice(index)
                        }
                    }
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            enabled: column.sequenceList.length < 10

            background: Rectangle {
                color: parent.pressed ? column.buttonPressedColor : (parent.hovered ? column.buttonHoverColor : column.buttonColor)
                radius: 6
                opacity: parent.enabled ? 1.0 : 0.5
            }

            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: "+"
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "添加设备 (" + column.sequenceList.length + "/10)"
                    font.pixelSize: 15
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            onClicked: column.addDevice()
        }
    }
}
