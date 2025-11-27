import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Speed Control Panel Component
// Responsibilities: Speed slider, display, and control
// Developer: Team Member A
Rectangle {
    id: root
    width: 280
    height: 220
    color: "#34495e"
    radius: 10

    // Public properties - interface for parent component
    property real speedValue: 2.5
    property real minSpeed: 0.0
    property real maxSpeed: 5.0

    // Signals - notify parent of changes
    signal speedChanged(real newSpeed)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Text {
            text: "Speed Control"
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

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: speedSlider.value.toFixed(1) + " m/s"
            font.pixelSize: 42
            font.bold: true
            color: "#e74c3c"
        }

        Slider {
            id: speedSlider
            Layout.fillWidth: true
            from: root.minSpeed
            to: root.maxSpeed
            value: root.speedValue
            stepSize: 0.1

            onValueChanged: {
                root.speedValue = value
                root.speedChanged(value)
            }

            background: Rectangle {
                x: speedSlider.leftPadding
                y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                width: speedSlider.availableWidth
                height: 8
                radius: 4
                color: "#95a5a6"

                Rectangle {
                    width: speedSlider.visualPosition * parent.width
                    height: parent.height
                    color: "#3498db"
                    radius: 4
                }
            }

            handle: Rectangle {
                x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                width: 24
                height: 24
                radius: 12
                color: speedSlider.pressed ? "#2980b9" : "#3498db"
                border.color: "white"
                border.width: 2
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: root.minSpeed.toFixed(0); color: "#95a5a6"; font.pixelSize: 12 }
            Item { Layout.fillWidth: true }
            Text { text: root.maxSpeed.toFixed(0) + " m/s"; color: "#95a5a6"; font.pixelSize: 12 }
        }

        Item { Layout.fillHeight: true }
    }

    // Public functions - external control interface
    function setSpeed(speed) {
        speedSlider.value = speed
    }

    function resetSpeed() {
        speedSlider.value = 0
    }
}
