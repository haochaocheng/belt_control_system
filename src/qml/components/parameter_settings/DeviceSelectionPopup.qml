import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5

// Device Selection Popup - for selecting devices from available list
Popup {
    id: root

    width: 500
    height: 600
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Centering
    anchors.centerIn: Overlay.overlay

    signal deviceSelected(string deviceName)

    // Available devices list (reference from OutputDevicePanel)
    property var availableDevices: [
        "张紧", "抱闸", "洒水", "1号电机", "2号电机",
        "破碎机", "转载机", "前刮板", "后刮板",
        "1号乳化液泵", "2号乳化液泵", "3号乳化液泵", "4号乳化液泵",
        "1号喷雾泵", "2号喷雾泵", "3号喷雾泵", "4号喷雾泵"
    ]

    background: Rectangle {
        color: "#1a2332"
        border.color: "#00d4ff"
        border.width: 3
        radius: 10
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: "选择设备"
            font.pixelSize: 22
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

        // Device list
        ListView {
            id: deviceListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8

            model: root.availableDevices

            delegate: Rectangle {
                width: ListView.view.width
                height: 50
                color: deviceMouseArea.pressed ? "#2a3f54" : (deviceMouseArea.containsMouse ? "#1f2f3f" : "#1a2332")
                border.color: "#00d4ff"
                border.width: 1
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 18
                    color: "#ecf0f1"
                }

                MouseArea {
                    id: deviceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.deviceSelected(modelData)
                        root.close()
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOn
                width: 12

                contentItem: Rectangle {
                    implicitWidth: 12
                    radius: 6
                    color: parent.pressed ? "#00d4ff" : "#34495e"
                }
            }
        }

        // Cancel button
        Button {
            text: "取消"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 150
            Layout.preferredHeight: 45

            background: Rectangle {
                color: parent.pressed ? "#95a5a6" : (parent.hovered ? "#7f8c8d" : "#34495e")
                radius: 6
            }

            contentItem: Text {
                text: parent.text
                font.pixelSize: 16
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: root.close()
        }
    }
}
