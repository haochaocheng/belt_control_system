import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Runtime Info Panel Component
// Responsibilities: Display system status, speed, runtime
// Developer: Team Member C
Rectangle {
    id: root
    width: 280
    height: 180
    color: "#34495e"
    radius: 10

    // Public properties - data binding interface
    property bool isRunning: false
    property real currentSpeed: 0.0
    property string runTime: "00:00:00"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        Text {
            text: "Runtime Info"
            font.pixelSize: 18
            font.bold: true
            color: "#3498db"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#3498db"
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 15

            Text {
                text: "Status:"
                color: "#ecf0f1"
                font.pixelSize: 14
            }
            Text {
                text: root.isRunning ? "Running" : "Stopped"
                color: root.isRunning ? "#2ecc71" : "#e74c3c"
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                text: "Speed:"
                color: "#ecf0f1"
                font.pixelSize: 14
            }
            Text {
                text: root.currentSpeed.toFixed(2) + " m/s"
                color: "#f39c12"
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                text: "Runtime:"
                color: "#ecf0f1"
                font.pixelSize: 14
            }
            Text {
                text: root.runTime
                color: "#3498db"
                font.pixelSize: 14
                font.bold: true
            }
        }
    }

    // Public functions
    function updateRuntime(hours, minutes, seconds) {
        root.runTime = Qt.formatTime(new Date(0, 0, 0, hours, minutes, seconds), "hh:mm:ss")
    }
}
