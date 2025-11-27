import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Motor Control Panel Component
// Responsibilities: Motor start/stop, emergency stop
// Developer: Team Member B
Rectangle {
    id: root
    width: 280
    height: 300
    color: "#34495e"
    radius: 10

    // Public properties
    property bool motorRunning: false

    // Signals
    signal motorStarted()
    signal motorStopped()
    signal emergencyStopPressed()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Text {
            text: "Motor Control"
            font.pixelSize: 20
            font.bold: true
            color: "#3498db"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#3498db"
        }

        Item { Layout.fillHeight: true }

        Button {
            id: startButton
            Layout.fillWidth: true
            Layout.preferredHeight: 70

            background: Rectangle {
                color: root.motorRunning ?
                    (startButton.pressed ? "#c0392b" : "#e74c3c") :
                    (startButton.pressed ? "#27ae60" : "#2ecc71")
                radius: 10
                border.color: "white"
                border.width: 2
            }

            contentItem: Text {
                text: root.motorRunning ? "STOP" : "START"
                font.pixelSize: 22
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.motorRunning = !root.motorRunning
                if (root.motorRunning) {
                    root.motorStarted()
                } else {
                    root.motorStopped()
                }
            }
        }

        Button {
            id: emergencyButton
            Layout.fillWidth: true
            Layout.preferredHeight: 70

            background: Rectangle {
                color: emergencyButton.pressed ? "#8e44ad" : "#9b59b6"
                radius: 10
                border.color: "white"
                border.width: 2
            }

            contentItem: Text {
                text: "EMERGENCY STOP"
                font.pixelSize: 18
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.motorRunning = false
                root.emergencyStopPressed()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Public functions
    function stopMotor() {
        root.motorRunning = false
    }

    function startMotor() {
        root.motorRunning = true
    }
}
