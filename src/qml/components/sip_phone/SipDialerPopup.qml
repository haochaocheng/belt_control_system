import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// SIP Phone Dialer Popup - Updated to use new multi-page structure
Popup {
    id: root
    width: 650
    height: 850
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose  // 防止点击外部或内部空白处关闭
    z: 2000

    // Center positioning
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    background: Rectangle {
        color: "#1a1a2e"
        radius: 15
        border.color: "#00d4ff"
        border.width: 3

        // Outer glow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            color: "transparent"
            border.color: "#00d4ff"
            border.width: 1
            radius: 17
            opacity: 0.3
            z: -1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top bar with close button
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: "transparent"
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15

                Item {
                    Layout.fillWidth: true
                }

                // Close button
                Button {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40

                    background: Rectangle {
                        color: parent.pressed ? "#c0392b" : "#e74c3c"
                        radius: 20
                    }

                    contentItem: Text {
                        text: "×"
                        font.pixelSize: 24
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.close()
                }
            }
        }

        // Main content area with SipMainPage
        SipMainPage {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
