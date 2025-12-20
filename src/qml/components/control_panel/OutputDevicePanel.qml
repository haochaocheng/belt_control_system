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
    // Channels are numbered 0-15 (对应寄存器10的0-15位)
    // 反馈通道也是0-15 (对应寄存器0的0-15位)
    ListModel {
        id: deviceModel

        ListElement { name: "张紧"; action: 0; channel: 0; feedbackChannel: 0; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "抱闸"; action: 0; channel: 1; feedbackChannel: 1; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "洒水"; action: 0; channel: 2; feedbackChannel: 2; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "1号电机"; action: 0; channel: 3; feedbackChannel: 3; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "2号电机"; action: 0; channel: 4; feedbackChannel: 4; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "破碎机"; action: 0; channel: 5; feedbackChannel: 5; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "转载机"; action: 0; channel: 6; feedbackChannel: 6; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "前刮板"; action: 0; channel: 7; feedbackChannel: 7; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "后刮板"; action: 0; channel: 8; feedbackChannel: 8; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "1号乳化液泵"; action: 0; channel: 9; feedbackChannel: 9; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "2号乳化液泵"; action: 0; channel: 10; feedbackChannel: 10; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "3号乳化液泵"; action: 0; channel: 11; feedbackChannel: 11; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "4号乳化液泵"; action: 0; channel: 12; feedbackChannel: 12; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "1号喷雾泵"; action: 0; channel: 13; feedbackChannel: 13; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "2号喷雾泵"; action: 0; channel: 14; feedbackChannel: 14; useFeedback: true; feedbackDelay: 3 }
        ListElement { name: "3号喷雾泵"; action: 0; channel: 15; feedbackChannel: 15; useFeedback: true; feedbackDelay: 3 }
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
                        // 判断是否为故障设备：检查 runtimeTracker.faultDevices 列表
                        property bool isFaultDevice: runtimeTracker && runtimeTracker.faultDevices.indexOf(model.name) !== -1
                        color: isFaultDevice ? "#ff4757" : (model.action === 1 ? "#00ff88" : "#2c3e50")
                        border.color: isFaultDevice ? "#ff6677" : (model.action === 1 ? "#00ffaa" : "#00d4ff")
                        border.width: 2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: model.name
                                font.pixelSize: 12
                                font.bold: true
                                color: deviceItem.isFaultDevice ? "#ffffff" : (model.action === 1 ? "#003322" : "#00d4ff")
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
        // Auto-assign next available channel (0-15)
        var nextChannel = deviceModel.count
        if (nextChannel > 15) {
            console.warn("最多支持16个输出设备 (通道0-15)")
            return
        }
        deviceModel.append({"name": name, "action": 0, "channel": nextChannel})
    }

    function removeDevice(name) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === name) {
                deviceModel.remove(i)
                break
            }
        }
    }

    // 设置设备状态 (0=停止, 1=运行)
    function setDeviceStatus(deviceName, isRunning) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === deviceName) {
                deviceModel.setProperty(i, "action", isRunning ? 1 : 0)
                console.log("📡 OutputDevicePanel: 设备状态更新 -", deviceName, isRunning ? "运行✅" : "停止⏹️")
                break
            }
        }
    }

    // 获取设备通道号
    function getDeviceChannel(deviceName) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === deviceName) {
                return deviceModel.get(i).channel
            }
        }
        return 0  // Device not found, return default channel 0
    }

    // 获取设备反馈通道号
    function getDeviceFeedbackChannel(deviceName) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === deviceName) {
                return deviceModel.get(i).feedbackChannel
            }
        }
        return 0  // Device not found, return default feedback channel 0
    }

    // 获取设备是否使用反馈
    function getDeviceUseFeedback(deviceName) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === deviceName) {
                return deviceModel.get(i).useFeedback
            }
        }
        return true  // Device not found, return default true
    }

    // 获取设备反馈延时
    function getDeviceFeedbackDelay(deviceName) {
        for (var i = 0; i < deviceModel.count; i++) {
            if (deviceModel.get(i).name === deviceName) {
                return deviceModel.get(i).feedbackDelay
            }
        }
        return 3  // Device not found, return default 3 seconds
    }

    // 获取所有设备信息 (用于数据库保存)
    function getAllDevices() {
        var devices = []
        for (var i = 0; i < deviceModel.count; i++) {
            var device = deviceModel.get(i)
            devices.push({
                name: device.name,
                channel: device.channel,
                feedbackChannel: device.feedbackChannel,
                useFeedback: device.useFeedback,
                feedbackDelay: device.feedbackDelay,
                action: device.action
            })
        }
        return devices
    }
}
