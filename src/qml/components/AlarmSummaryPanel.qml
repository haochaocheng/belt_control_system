import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Alarm Summary Panel Component
// Responsibilities: Display current alarm status
// Developer: Team Member D
Rectangle {
    id: root
    width: 280
    height: 200
    color: "#34495e"
    radius: 10

    // Public properties
    property int alarmCount: 0
    property string alarmMessage: "No Alarms"
    property string alarmLevel: "Info"  // "Info", "Warning", "Error"

    // Signals
    signal alarmClicked()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        Text {
            text: "Alarms"
            font.pixelSize: 18
            font.bold: true
            color: "#3498db"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#3498db"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2c3e50"
            radius: 5

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.alarmCount > 0 ? root.alarmCount + " Active" : root.alarmMessage
                    color: {
                        if (root.alarmLevel === "Error") return "#e74c3c"
                        if (root.alarmLevel === "Warning") return "#f39c12"
                        return "#2ecc71"
                    }
                    font.pixelSize: 14
                    font.bold: root.alarmCount > 0
                }

                Text {
                    visible: root.alarmCount > 0
                    Layout.alignment: Qt.AlignHCenter
                    text: "Click for details"
                    color: "#95a5a6"
                    font.pixelSize: 11
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.alarmCount > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.alarmCount > 0) {
                        root.alarmClicked()
                    }
                }
            }
        }
    }

    // Public functions
    function setAlarm(count, message, level) {
        root.alarmCount = count
        root.alarmMessage = message
        root.alarmLevel = level
    }

    function clearAlarms() {
        root.alarmCount = 0
        root.alarmMessage = "No Alarms"
        root.alarmLevel = "Info"
    }
}
