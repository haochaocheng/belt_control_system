import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Window 2.15

// Independent SIP Phone Window
Window {
    id: sipWindow
    width: 800
    height: 900
    title: "SIP 语音电话"
    color: "#1a1a2e"

    // Normal window with standard controls
    flags: Qt.Window

    // Center on screen
    Component.onCompleted: {
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
    }

    // Main container
    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Custom title bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "#0f3460"
                z: 100

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Title
                    Text {
                        text: "📞 SIP 语音电话"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#00d4ff"
                        Layout.fillWidth: true
                    }

                    // Minimize button
                    Button {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        background: Rectangle {
                            color: parent.pressed ? "#34495e" : (parent.hovered ? "#2c3e50" : "transparent")
                            radius: 5
                        }

                        contentItem: Text {
                            text: "━"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            sipWindow.showMinimized()
                        }
                    }

                    // Close button
                    Button {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        background: Rectangle {
                            color: parent.pressed ? "#c0392b" : (parent.hovered ? "#e74c3c" : "transparent")
                            radius: 5
                        }

                        contentItem: Text {
                            text: "✕"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            sipWindow.close()
                        }
                    }
                }

                // Make title bar draggable
                MouseArea {
                    anchors.fill: parent
                    property point lastMousePos: Qt.point(0, 0)

                    onPressed: {
                        lastMousePos = Qt.point(mouseX, mouseY)
                    }

                    onMouseXChanged: {
                        if (pressed) {
                            sipWindow.x += (mouseX - lastMousePos.x)
                        }
                    }

                    onMouseYChanged: {
                        if (pressed) {
                            sipWindow.y += (mouseY - lastMousePos.y)
                        }
                    }
                }
            }

            // Load the main SIP page
            SipMainPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
