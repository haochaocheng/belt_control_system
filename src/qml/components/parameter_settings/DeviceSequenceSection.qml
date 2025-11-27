import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Device Sequence Section Component
Rectangle {
    id: root
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    property var virtualKeyboardPopup: null
    property var flickableParent: null  // Reference to parent Flickable

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Section Title with buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "集控启动顺序列表"
                font.pixelSize: 20
                font.bold: true
                color: "#00d4ff"
            }

            Item { Layout.fillWidth: true }

            Button {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 36

                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : (parent.hovered ? "#2ecc71" : "#00ff88")
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 1
                }

                contentItem: Text {
                    text: "+ 增加"
                    color: "#0a1628"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: deviceListModel.append({
                    deviceNo: deviceListModel.count + 1,
                    deviceName: "设备" + (deviceListModel.count + 1),
                    deviceAddr: "192.168.1." + (100 + deviceListModel.count),
                    startDelay: 5,
                    stopDelay: 3,
                    commFailDelay: 10
                })
            }

            Button {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 36

                background: Rectangle {
                    color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "#ff4757")
                    radius: 5
                    border.color: "#00d4ff"
                    border.width: 1
                }

                contentItem: Text {
                    text: "- 删除"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (deviceTable.currentRow >= 0 && deviceListModel.count > 0) {
                        deviceListModel.remove(deviceTable.currentRow)
                        // Renumber devices after deletion
                        for (var i = 0; i < deviceListModel.count; i++) {
                            deviceListModel.setProperty(i, "deviceNo", i + 1)
                        }
                        // Reset selection
                        if (deviceTable.currentRow >= deviceListModel.count) {
                            deviceTable.currentRow = deviceListModel.count - 1
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#00d4ff"
            opacity: 0.5
        }

        // Table Header
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#1a2332"
            radius: 5
            border.color: "#00d4ff"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 3

                Text {
                    text: "设备号"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 70
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                Text {
                    text: "设备名称"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 120
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                Text {
                    text: "设备地址"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                Text {
                    text: "启动延时(s)"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 90
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                Text {
                    text: "停止延时(s)"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 90
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                Text {
                    text: "通讯失败延时(s)"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00d4ff"
                    Layout.preferredWidth: 120
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Table Content
        ListView {
            id: deviceTable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3

            property int currentRow: -1

            model: ListModel {
                id: deviceListModel
                ListElement { deviceNo: 1; deviceName: "皮带机1"; deviceAddr: "192.168.1.100"; startDelay: 5; stopDelay: 3; commFailDelay: 10 }
                ListElement { deviceNo: 2; deviceName: "皮带机2"; deviceAddr: "192.168.1.101"; startDelay: 8; stopDelay: 3; commFailDelay: 10 }
                ListElement { deviceNo: 3; deviceName: "皮带机3"; deviceAddr: "192.168.1.102"; startDelay: 10; stopDelay: 3; commFailDelay: 10 }
            }

            delegate: Rectangle {
                id: rowDelegate
                width: ListView.view.width
                height: 40
                color: deviceTable.currentRow === index ? "#3a5f74" : (index % 2 === 0 ? "#1a2332" : "#151e2b")
                radius: 5
                border.color: deviceTable.currentRow === index ? "#00d4ff" : "transparent"
                border.width: deviceTable.currentRow === index ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 3

                    // Device No - Read-only, click to select row
                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.fillHeight: true
                        color: "transparent"

                        Text {
                            anchors.fill: parent
                            text: model.deviceNo
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: "#34495e"
                                border.width: 1
                                radius: 3
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                deviceTable.currentRow = index
                            }
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                    // Device Name (with Qt Virtual Keyboard)
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.fillHeight: true
                        color: "transparent"

                        TextField {
                            id: deviceNameField
                            anchors.fill: parent
                            text: model.deviceName || ""
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhNone

                            background: Rectangle {
                                color: "transparent"
                                border.color: deviceNameField.activeFocus ? "#00d4ff" : "#34495e"
                                border.width: 1
                                radius: 3
                            }

                            onTextChanged: {
                                model.deviceName = text
                            }

                            onFocusChanged: {
                                if (focus && root.flickableParent) {
                                    root.flickableParent.ensureVisible(deviceNameField)
                                }
                            }
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                    // Device Address
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        TextField {
                            id: deviceAddrField
                            anchors.fill: parent
                            text: model.deviceAddr
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhFormattedNumbersOnly

                            background: Rectangle {
                                color: "transparent"
                                border.color: deviceAddrField.activeFocus ? "#00d4ff" : "#34495e"
                                border.width: 1
                                radius: 3
                            }

                            onTextChanged: {
                                model.deviceAddr = text
                            }

                            onFocusChanged: {
                                if (focus && root.flickableParent) {
                                    root.flickableParent.ensureVisible(deviceAddrField)
                                }
                            }
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                    // Start Delay
                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.fillHeight: true
                        color: "transparent"

                        TextField {
                            id: startDelayField
                            anchors.fill: parent
                            text: model.startDelay
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhDigitsOnly

                            background: Rectangle {
                                color: "transparent"
                                border.color: startDelayField.activeFocus ? "#00d4ff" : "#34495e"
                                border.width: 1
                                radius: 3
                            }

                            onTextChanged: {
                                model.startDelay = parseInt(text) || 0
                            }

                            onFocusChanged: {
                                if (focus && root.flickableParent) {
                                    root.flickableParent.ensureVisible(startDelayField)
                                }
                            }
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                    // Stop Delay
                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.fillHeight: true
                        color: "transparent"

                        TextField {
                            id: stopDelayField
                            anchors.fill: parent
                            text: model.stopDelay
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhDigitsOnly

                            background: Rectangle {
                                color: "transparent"
                                border.color: stopDelayField.activeFocus ? "#00d4ff" : "#34495e"
                                border.width: 1
                                radius: 3
                            }

                            onTextChanged: {
                                model.stopDelay = parseInt(text) || 0
                            }

                            onFocusChanged: {
                                if (focus && root.flickableParent) {
                                    root.flickableParent.ensureVisible(stopDelayField)
                                }
                            }
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: "#34495e" }

                    // Comm Fail Delay
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.fillHeight: true
                        color: "transparent"

                        TextField {
                            id: commFailDelayField
                            anchors.fill: parent
                            text: model.commFailDelay
                            font.pixelSize: 14
                            color: "#ecf0f1"
                            horizontalAlignment: Text.AlignHCenter
                            inputMethodHints: Qt.ImhDigitsOnly

                            background: Rectangle {
                                color: "transparent"
                                border.color: commFailDelayField.activeFocus ? "#00d4ff" : "#34495e"
                                border.width: 1
                                radius: 3
                            }

                            onTextChanged: {
                                model.commFailDelay = parseInt(text) || 0
                            }

                            onFocusChanged: {
                                if (focus && root.flickableParent) {
                                    root.flickableParent.ensureVisible(commFailDelayField)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
