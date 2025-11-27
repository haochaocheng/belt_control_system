import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

Item {
    id: root
    width: 1920
    height: 80

    property bool motorRunning: false

    Image {
        id: headerImage
        anchors.fill: parent
        source: "../../images/header.png"
        fillMode: Image.Stretch

        // Fallback if image not found
        onStatusChanged: {
            if (status === Image.Error) {
                fallbackRect.visible = true
            }
        }
    }

    // Time and Version Info overlay on header right side
    ColumnLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 20
        spacing: 5

        Text {
            id: currentTime
            text: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
            font.pixelSize: 14
            font.bold: true
            color: "#00d4ff"
            Layout.alignment: Qt.AlignRight

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: currentTime.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
            }
        }

        Text {
            text: "版本: V1.0.0"
            font.pixelSize: 11
            color: "#95a5a6"
            Layout.alignment: Qt.AlignRight
        }
    }

    // Fallback rectangle if image fails to load
    Rectangle {
        id: fallbackRect
        anchors.fill: parent
        visible: false
        color: "#0a1628"
        radius: 10
        border.color: "#00d4ff"
        border.width: 2

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 15

            Text {
                text: "Belt Control System"
                font.pixelSize: 24
                font.bold: true
                color: "#00d4ff"
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.fillHeight: true
                color: root.motorRunning ? "#00ff88" : "#ff4757"
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: root.motorRunning ? "Running" : "Stopped"
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                }
            }
        }
    }

}
