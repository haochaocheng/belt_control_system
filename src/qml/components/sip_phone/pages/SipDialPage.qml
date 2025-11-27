import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import BeltControl.SipPhone 1.0

// Dial page with number pad
Page {
    id: root

    // Local number state as fallback
    property string localNumber: ""

    // Monitor C++ property changes
    Connections {
        target: SipPhoneManager
        function onCurrentNumberChanged(number) {
            console.log("C++ currentNumberChanged signal received:", number)
            root.localNumber = number
        }
    }

    // Inline RisipButton component
    component RisipButton: Button {
        id: control
        property color buttonColor: "#2c3e50"
        property color hoverColor: "#34495e"
        property color pressColor: "#2980b9"
        property color textColor: "#ffffff"
        property color borderColor: "#00d4ff"
        property int borderWidth: 2
        property int buttonRadius: 10
        property bool isHovered: false

        // Make sure the button is clickable
        enabled: true

        background: Rectangle {
            color: control.pressed ? control.pressColor : (control.isHovered ? control.hoverColor : control.buttonColor)
            radius: control.buttonRadius
            border.color: control.borderColor
            border.width: control.borderWidth
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        HoverHandler {
            onHoveredChanged: control.isHovered = hovered
        }
    }

    background: Rectangle {
        color: "transparent"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Phone number display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#0f3460"
            radius: 10
            border.color: "#00d4ff"
            border.width: 2

            Text {
                id: numberDisplay
                anchors.centerIn: parent
                text: root.localNumber || "请输入号码"
                font.pixelSize: 32
                font.bold: true
                color: root.localNumber ? "#ffffff" : "#7f8c8d"

                // Debug output
                onTextChanged: {
                    console.log("Number display text changed to:", text)
                }
            }

            // Backspace button
            RisipButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 15
                width: 50
                height: 50
                visible: root.localNumber.length > 0

                buttonColor: "transparent"
                hoverColor: "#c0392b"
                borderColor: "#e74c3c"

                contentItem: Text {
                    text: "⌫"
                    font.pixelSize: 24
                    color: "#e74c3c"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (root.localNumber.length > 0) {
                        root.localNumber = root.localNumber.slice(0, -1)
                        SipPhoneManager.setCurrentNumber(root.localNumber)
                    }
                }
            }
        }

        // Call status panel (like risip CallPage)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#0f3460"
            radius: 10
            border.color: {
                if (SipPhoneManager.callStatus === "通话中") return "#27ae60"
                if (SipPhoneManager.callStatus === "拨号中") return "#f39c12"
                return "#00d4ff"
            }
            border.width: 2
            visible: SipPhoneManager.isInCall

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                // Status label (Connecting.., Ringing.., Connected!)
                Text {
                    text: {
                        if (SipPhoneManager.callStatus === "通话中") return "✓ 通话中"
                        if (SipPhoneManager.callStatus === "拨号中") return "📞 拨号中..."
                        return SipPhoneManager.callStatus
                    }
                    font.pixelSize: 18
                    font.bold: true
                    color: {
                        if (SipPhoneManager.callStatus === "通话中") return "#27ae60"
                        if (SipPhoneManager.callStatus === "拨号中") return "#f39c12"
                        return "#00d4ff"
                    }
                    Layout.alignment: Qt.AlignHCenter
                }

                // Call duration
                Text {
                    text: formatDuration(SipPhoneManager.callDuration)
                    font.pixelSize: 32
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                    visible: SipPhoneManager.callStatus === "通话中"
                }

                // Mute microphone button
                RisipButton {
                    Layout.preferredWidth: 45
                    Layout.preferredHeight: 45
                    Layout.alignment: Qt.AlignHCenter
                    buttonRadius: 22
                    buttonColor: micMuted ? "#e74c3c" : "#34495e"
                    borderWidth: 1

                    property bool micMuted: false

                    contentItem: Text {
                        text: micMuted ? "🔇" : "🎤"
                        font.pixelSize: 20
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        micMuted = !micMuted
                        SipPhoneManager.muteMicrophone(micMuted)
                    }
                }
            }
        }

        // Dial pad
        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            spacing: 15

            Repeater {
                model: [
                    {num: "1", text: ""},
                    {num: "2", text: "ABC"},
                    {num: "3", text: "DEF"},
                    {num: "4", text: "GHI"},
                    {num: "5", text: "JKL"},
                    {num: "6", text: "MNO"},
                    {num: "7", text: "PQRS"},
                    {num: "8", text: "TUV"},
                    {num: "9", text: "WXYZ"},
                    {num: "*", text: ""},
                    {num: "0", text: "+"},
                    {num: "#", text: ""}
                ]

                delegate: Rectangle {
                    width: 100
                    height: 80
                    color: mouseArea.pressed ? "#2980b9" : (mouseArea.containsMouse ? "#34495e" : "#2c3e50")
                    radius: 10
                    border.color: "#00d4ff"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Text {
                            text: modelData.num
                            font.pixelSize: 28
                            font.bold: true
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: modelData.text
                            font.pixelSize: 10
                            color: "#95a5a6"
                            Layout.alignment: Qt.AlignHCenter
                            visible: modelData.text !== ""
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            console.log("Dial pad button clicked:", modelData.num)
                            // Update local state immediately for responsive UI
                            root.localNumber = root.localNumber + modelData.num
                            // Also update C++ backend
                            SipPhoneManager.setCurrentNumber(root.localNumber)
                            console.log("Number updated to:", root.localNumber)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            // Call button
            RisipButton {
                id: callButton
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                enabled: SipPhoneManager.currentNumber.length > 0 && !SipPhoneManager.isInCall

                buttonColor: "#27ae60"
                hoverColor: "#229954"
                pressColor: "#1e7e34"
                borderColor: "#00ff88"

                contentItem: RowLayout {
                    spacing: 10

                    Text {
                        text: "📞"
                        font.pixelSize: 24
                        color: "white"
                    }

                    Text {
                        text: "拨号"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                onClicked: {
                    SipPhoneManager.makeCall(SipPhoneManager.currentNumber)
                }
            }

            // Hang up button
            RisipButton {
                id: hangUpButton
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                enabled: SipPhoneManager.isInCall

                buttonColor: "#e74c3c"
                hoverColor: "#cb4335"
                pressColor: "#c0392b"
                borderColor: "#ff5555"

                contentItem: RowLayout {
                    spacing: 10

                    Text {
                        text: "📵"
                        font.pixelSize: 24
                        color: "white"
                    }

                    Text {
                        text: "挂断"
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                onClicked: {
                    SipPhoneManager.hangupCall()
                }
            }
        }
    }

    // Format duration from seconds to MM:SS
    function formatDuration(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = seconds % 60
        return mins.toString().padStart(2, '0') + ":" + secs.toString().padStart(2, '0')
    }
}
