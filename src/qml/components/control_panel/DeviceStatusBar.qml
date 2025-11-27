import QtQuick 6.5
import QtQuick.Controls 6.5

// Device Status Bar - Shows 32 devices along the belt line
// Bottom center of the screen
Rectangle {
    id: root
    width: 1200
    height: 80
    color: "#dd1a2332"
    radius: 10
    border.color: "#00d4ff"
    border.width: 2

    property int deviceCount: 32

    // Device status model (0=normal, 1=warning, 2=alarm)
    property var deviceStatuses: {
        var arr = []
        for (var i = 0; i < deviceCount; i++) {
            arr.push(0)  // All normal initially
        }
        return arr
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.deviceCount

            Item {
                width: 28
                height: 50

                // Device circle
                Rectangle {
                    id: deviceCircle
                    width: 24
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    color: getDeviceColor(index)
                    border.color: "#00d4ff"
                    border.width: 1

                    // Status indicator animation
                    SequentialAnimation on opacity {
                        running: root.deviceStatuses[index] > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }

                    // Device number
                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        font.pixelSize: 12
                        font.bold: true
                        color: root.deviceStatuses[index] > 0 ? "white" : "#003344"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            deviceCircle.scale = 1.2
                            tooltip.visible = true
                        }
                        onExited: {
                            deviceCircle.scale = 1.0
                            tooltip.visible = false
                        }
                        onClicked: {
                            console.log("Device", index + 1, "clicked")
                        }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }

                    // Tooltip
                    Rectangle {
                        id: tooltip
                        visible: false
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tooltipText.width + 16
                        height: 24
                        radius: 5
                        color: "#2c3e50"
                        border.color: "#00d4ff"
                        border.width: 1
                        z: 100

                        Text {
                            id: tooltipText
                            anchors.centerIn: parent
                            text: "设备 " + (index + 1) + " - " + getStatusText(index)
                            font.pixelSize: 11
                            color: "#00d4ff"
                        }
                    }
                }

                // Connection line to next device
                Rectangle {
                    visible: index < root.deviceCount - 1
                    width: 8
                    height: 2
                    color: "#00d4ff"
                    opacity: 0.6
                    anchors.left: deviceCircle.right
                    anchors.verticalCenter: deviceCircle.verticalCenter
                }

                // Device status label
                Text {
                    anchors.top: deviceCircle.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: getStatusLabel(index)
                    font.pixelSize: 8
                    color: getDeviceColor(index)
                }
            }
        }
    }

    // Helper functions
    function getDeviceColor(index) {
        if (!root.deviceStatuses || index >= root.deviceStatuses.length) {
            return "#00ff88"  // Normal - green
        }

        switch(root.deviceStatuses[index]) {
            case 0: return "#00ff88"  // Normal - green
            case 1: return "#f39c12"  // Warning - orange
            case 2: return "#ff4757"  // Alarm - red
            default: return "#95a5a6"  // Unknown - gray
        }
    }

    function getStatusText(index) {
        if (!root.deviceStatuses || index >= root.deviceStatuses.length) {
            return "正常"
        }

        switch(root.deviceStatuses[index]) {
            case 0: return "正常"
            case 1: return "预警"
            case 2: return "报警"
            default: return "未知"
        }
    }

    function getStatusLabel(index) {
        if (!root.deviceStatuses || index >= root.deviceStatuses.length) {
            return "●"
        }

        switch(root.deviceStatuses[index]) {
            case 0: return "●"
            case 1: return "!"
            case 2: return "X"
            default: return "?"
        }
    }

    // Public functions
    function setDeviceStatus(deviceIndex, status) {
        if (deviceIndex >= 0 && deviceIndex < root.deviceCount) {
            var newStatuses = root.deviceStatuses.slice()
            newStatuses[deviceIndex] = status
            root.deviceStatuses = newStatuses
        }
    }

    function resetAllDevices() {
        var newStatuses = []
        for (var i = 0; i < root.deviceCount; i++) {
            newStatuses.push(0)
        }
        root.deviceStatuses = newStatuses
    }
}
