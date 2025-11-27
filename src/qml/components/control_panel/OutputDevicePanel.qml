import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Output Device Panel - Shows output device status
// Click to configure parameters
Rectangle {
    id: root
    width: 280
    height: 400
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    // Signals
    signal deviceClicked(string deviceName, var sourceItem)
    signal addDeviceClicked(var sourceItem)

    // Output device items model
    ListModel {
        id: deviceModel

        ListElement { name: "张紧"; action: 0 }
        ListElement { name: "抱闸"; action: 0 }
        ListElement { name: "洒水"; action: 0 }
        ListElement { name: "电机1"; action: 0 }
        ListElement { name: "电机2"; action: 0 }
        ListElement { name: "破碎机"; action: 0 }
        ListElement { name: "转载机"; action: 0 }
        ListElement { name: "前刮板"; action: 0 }
        ListElement { name: "后刮板"; action: 0 }
        ListElement { name: "1号乳化液泵"; action: 0 }
        ListElement { name: "2号乳化液泵"; action: 0 }
        ListElement { name: "3号乳化液泵"; action: 0 }
        ListElement { name: "4号乳化液泵"; action: 0 }
        ListElement { name: "1号喷雾泵"; action: 0 }
        ListElement { name: "2号喷雾泵"; action: 0 }
        ListElement { name: "3号喷雾泵"; action: 0 }
        ListElement { name: "4号喷雾泵"; action: 0 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Title
        Text {
            text: "输出设备信息"
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

        // Device items grid
        ScrollView {
            id: deviceScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Flow {
                width: deviceScrollView.width
                spacing: 10

                Repeater {
                    model: deviceModel

                    Rectangle {
                        id: deviceItem
                        width: 70
                        height: 60
                        radius: 8
                        color: model.action === 1 ? "#00ff88" : "#2c3e50"
                        border.color: model.action === 1 ? "#00ffaa" : "#00d4ff"
                        border.width: 2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: model.name
                                font.pixelSize: 12
                                font.bold: true
                                color: model.action === 1 ? "#003322" : "#00d4ff"
                                Layout.alignment: Qt.AlignHCenter
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: 60
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deviceClicked(model.name, deviceItem)

                            hoverEnabled: true
                            onEntered: parent.scale = 1.05
                            onExited: parent.scale = 1.0
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }

                // Add new device button
                Rectangle {
                    id: addDeviceButton
                    width: 70
                    height: 60
                    radius: 8
                    color: "#34495e"
                    border.color: "#00ff88"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 32
                        font.bold: true
                        color: "#00ff88"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addDeviceClicked(addDeviceButton)

                        hoverEnabled: true
                        onEntered: parent.scale = 1.05
                        onExited: parent.scale = 1.0
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                }
            }
        }
    }

    // Public functions
    function setDeviceAction(deviceName, action) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === deviceName) {
                deviceModel.setProperty(i, "action", action)
                break
            }
        }
    }

    function getDeviceCount() {
        return deviceModel.count
    }

    function getDeviceAt(index) {
        if (index >= 0 && index < deviceModel.count) {
            return deviceModel.get(index)
        }
        return null
    }

    function addDevice(name) {
        deviceModel.append({"name": name, "action": 0})
    }

    function removeDevice(name) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === name) {
                deviceModel.remove(i)
                break
            }
        }
    }
}
