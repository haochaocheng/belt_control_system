import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

Rectangle {
    id: root
    color: "#34495e"
    radius: 10

    property int currentIndex: 0
    property var tabNames: ["Control Panel", "Parameters", "Alarms"]

    signal tabClicked(int index)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 5

        Repeater {
            model: root.tabNames

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.currentIndex === index ? "#3498db" : "transparent"
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 16
                    font.bold: root.currentIndex === index
                    color: root.currentIndex === index ? "white" : "#95a5a6"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = index
                        root.tabClicked(index)
                    }
                }
            }
        }
    }
}
