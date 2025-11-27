import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

Rectangle {
    id: root
    color: "#34495e"
    radius: 10

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 15

        Text {
            id: timeText
            text: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
            color: "#ecf0f1"
            font.pixelSize: 12

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: timeText.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "Swipe left/right to switch pages"
            color: "#95a5a6"
            font.pixelSize: 11
        }

        Rectangle { width: 1; height: parent.height * 0.6; color: "#95a5a6" }

        Text {
            text: "v1.0.0"
            color: "#95a5a6"
            font.pixelSize: 12
        }
    }
}
